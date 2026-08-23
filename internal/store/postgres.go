package store

import (
	"context"
	"crypto/rand"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"nodecontrol.local/node-control/internal/protocol"
)

type Store struct {
	pool *pgxpool.Pool
}

var (
	ErrIdempotencyConflict = errors.New("idempotency key reused with different request")
	ErrResultMismatch      = errors.New("result does not match an executable operation")
)

func Open(ctx context.Context, databaseURL string) (*Store, error) {
	pool, err := pgxpool.New(ctx, databaseURL)
	if err != nil {
		return nil, err
	}
	if err := pool.Ping(ctx); err != nil {
		pool.Close()
		return nil, err
	}
	store := &Store{pool: pool}
	if err := store.migrate(ctx); err != nil {
		pool.Close()
		return nil, err
	}
	return store, nil
}

func (s *Store) Close() { s.pool.Close() }

func (s *Store) Ping(ctx context.Context) error { return s.pool.Ping(ctx) }

func (s *Store) migrate(ctx context.Context) error {
	_, err := s.pool.Exec(ctx, `
CREATE TABLE IF NOT EXISTS node_observations (
  node_id text PRIMARY KEY,
  sequence bigint NOT NULL,
  observed_at timestamptz NOT NULL,
  capabilities jsonb NOT NULL,
  facts jsonb NOT NULL DEFAULT '{}'::jsonb
);
ALTER TABLE node_observations ADD COLUMN IF NOT EXISTS facts jsonb NOT NULL DEFAULT '{}'::jsonb;
CREATE TABLE IF NOT EXISTS operations (
  id text PRIMARY KEY,
  target text NOT NULL,
  action text NOT NULL,
  idempotency_key text NOT NULL UNIQUE,
  state text NOT NULL,
  policy_reason text NOT NULL,
  result jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);`)
	return err
}

func (s *Store) UpsertHeartbeat(ctx context.Context, heartbeat protocol.Heartbeat) error {
	capabilities, err := json.Marshal(heartbeat.Capabilities)
	if err != nil {
		return err
	}
	if len(heartbeat.Facts) == 0 || !json.Valid(heartbeat.Facts) {
		return fmt.Errorf("heartbeat facts must be valid JSON")
	}
	_, err = s.pool.Exec(ctx, `
INSERT INTO node_observations (node_id, sequence, observed_at, capabilities, facts)
VALUES ($1, $2, $3, $4, $5)
ON CONFLICT (node_id) DO UPDATE SET
  sequence = EXCLUDED.sequence,
  observed_at = EXCLUDED.observed_at,
  capabilities = EXCLUDED.capabilities,
  facts = EXCLUDED.facts
WHERE node_observations.observed_at <= EXCLUDED.observed_at`,
		heartbeat.NodeID, heartbeat.Sequence, heartbeat.ObservedAt, capabilities, heartbeat.Facts)
	return err
}

func (s *Store) ListNodes(ctx context.Context) ([]protocol.NodeObservation, error) {
	rows, err := s.pool.Query(ctx, `
SELECT node_id, sequence, observed_at, capabilities, facts
FROM node_observations ORDER BY node_id`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var nodes []protocol.NodeObservation
	for rows.Next() {
		var node protocol.NodeObservation
		if err := rows.Scan(&node.NodeID, &node.Sequence, &node.ObservedAt, &node.Capabilities, &node.Facts); err != nil {
			return nil, err
		}
		nodes = append(nodes, node)
	}
	return nodes, rows.Err()
}

func (s *Store) CreatePlan(ctx context.Context, request protocol.PlanRequest, reason string) (protocol.Operation, error) {
	id, err := randomID()
	if err != nil {
		return protocol.Operation{}, err
	}
	_, err = s.pool.Exec(ctx, `
INSERT INTO operations (id, target, action, idempotency_key, state, policy_reason)
VALUES ($1, $2, $3, $4, 'auto-authorized', $5)
ON CONFLICT (idempotency_key) DO NOTHING`,
		id, request.Target, request.Action, request.IdempotencyKey, reason)
	if err != nil {
		return protocol.Operation{}, err
	}
	operation, err := s.GetOperationByKey(ctx, request.IdempotencyKey)
	if err != nil {
		return protocol.Operation{}, err
	}
	if operation.Target != request.Target || operation.Action != request.Action {
		return protocol.Operation{}, fmt.Errorf("%w: %s", ErrIdempotencyConflict, request.IdempotencyKey)
	}
	return operation, nil
}

func (s *Store) GetOperation(ctx context.Context, id string) (protocol.Operation, error) {
	return s.scanOperation(s.pool.QueryRow(ctx, `
SELECT id, target, action, idempotency_key, state, policy_reason,
       COALESCE(result, 'null'::jsonb), created_at, updated_at
FROM operations WHERE id = $1`, id))
}

func (s *Store) GetOperationByKey(ctx context.Context, key string) (protocol.Operation, error) {
	return s.scanOperation(s.pool.QueryRow(ctx, `
SELECT id, target, action, idempotency_key, state, policy_reason,
       COALESCE(result, 'null'::jsonb), created_at, updated_at
FROM operations WHERE idempotency_key = $1`, key))
}

type rowScanner interface {
	Scan(dest ...any) error
}

func (s *Store) scanOperation(row rowScanner) (protocol.Operation, error) {
	var operation protocol.Operation
	if err := row.Scan(
		&operation.ID,
		&operation.Target,
		&operation.Action,
		&operation.IdempotencyKey,
		&operation.State,
		&operation.PolicyReason,
		&operation.Result,
		&operation.CreatedAt,
		&operation.UpdatedAt,
	); err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return protocol.Operation{}, fmt.Errorf("operation not found")
		}
		return protocol.Operation{}, err
	}
	return operation, nil
}

func (s *Store) MarkDispatched(ctx context.Context, id string) (protocol.Operation, bool, error) {
	command, err := s.pool.Exec(ctx, `
UPDATE operations SET state = 'leased', updated_at = now()
WHERE id = $1 AND state = 'auto-authorized'`, id)
	if err != nil {
		return protocol.Operation{}, false, err
	}
	operation, err := s.GetOperation(ctx, id)
	return operation, command.RowsAffected() == 1, err
}

func (s *Store) RecordResult(ctx context.Context, result protocol.Result) error {
	encoded, err := json.Marshal(result)
	if err != nil {
		return err
	}
	state := "verified"
	if !result.Success {
		state = "failed"
	}
	command, err := s.pool.Exec(ctx, `
UPDATE operations SET state = $2, result = $3, updated_at = now()
WHERE id = $1 AND target = $4
  AND state IN ('auto-authorized', 'leased', 'running', 'verified', 'failed')`,
		result.OperationID, state, encoded, result.Target)
	if err != nil {
		return err
	}
	if command.RowsAffected() != 1 {
		return ErrResultMismatch
	}
	return nil
}

func randomID() (string, error) {
	bytes := make([]byte, 16)
	if _, err := rand.Read(bytes); err != nil {
		return "", err
	}
	return hex.EncodeToString(bytes), nil
}

func WaitForPostgres(ctx context.Context, databaseURL string, timeout time.Duration) (*Store, error) {
	deadline := time.Now().Add(timeout)
	var lastErr error
	for time.Now().Before(deadline) {
		store, err := Open(ctx, databaseURL)
		if err == nil {
			return store, nil
		}
		lastErr = err
		select {
		case <-ctx.Done():
			return nil, ctx.Err()
		case <-time.After(time.Second):
		}
	}
	return nil, fmt.Errorf("postgres unavailable: %w", lastErr)
}

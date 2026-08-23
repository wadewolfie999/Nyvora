package protocol

import (
	"encoding/json"
	"time"
)

const APIVersion = "nodecontrol.io/v1alpha1"

var canonicalNodes = map[string]struct{}{
	"mac-node":  {},
	"vps-node":  {},
	"asus-node": {},
}

func IsCanonicalNode(id string) bool {
	_, ok := canonicalNodes[id]
	return ok
}

type Heartbeat struct {
	APIVersion   string          `json:"api_version"`
	NodeID       string          `json:"node_id"`
	Sequence     int64           `json:"sequence"`
	ObservedAt   time.Time       `json:"observed_at"`
	Capabilities map[string]bool `json:"capabilities"`
	Facts        json.RawMessage `json:"facts"`
}

type Command struct {
	APIVersion  string          `json:"api_version"`
	OperationID string          `json:"operation_id"`
	Target      string          `json:"target"`
	Action      string          `json:"action"`
	Payload     json.RawMessage `json:"payload,omitempty"`
}

type Result struct {
	APIVersion  string          `json:"api_version"`
	OperationID string          `json:"operation_id"`
	Target      string          `json:"target"`
	Success     bool            `json:"success"`
	ObservedAt  time.Time       `json:"observed_at"`
	Evidence    json.RawMessage `json:"evidence"`
	Error       string          `json:"error,omitempty"`
}

type PlanRequest struct {
	Target         string `json:"target"`
	Action         string `json:"action"`
	IdempotencyKey string `json:"idempotency_key"`
}

type Operation struct {
	ID             string          `json:"id"`
	Target         string          `json:"target"`
	Action         string          `json:"action"`
	IdempotencyKey string          `json:"idempotency_key"`
	State          string          `json:"state"`
	PolicyReason   string          `json:"policy_reason"`
	Result         json.RawMessage `json:"result,omitempty"`
	CreatedAt      time.Time       `json:"created_at"`
	UpdatedAt      time.Time       `json:"updated_at"`
}

type NodeObservation struct {
	NodeID       string          `json:"node_id"`
	Sequence     int64           `json:"sequence"`
	ObservedAt   time.Time       `json:"observed_at"`
	Capabilities json.RawMessage `json:"capabilities"`
	Facts        json.RawMessage `json:"facts"`
}

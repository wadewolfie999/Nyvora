package controller

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"html/template"
	"io"
	"log/slog"
	"net/http"
	"strings"
	"time"

	"github.com/nats-io/nats.go"

	"nodecontrol.local/node-control/internal/policy"
	"nodecontrol.local/node-control/internal/protocol"
	"nodecontrol.local/node-control/internal/runtimeconfig"
	"nodecontrol.local/node-control/internal/store"
	"nodecontrol.local/node-control/internal/transportauth"
)

type Server struct {
	store  *store.Store
	nats   *nats.Conn
	js     nats.JetStreamContext
	logger *slog.Logger
	mux    *http.ServeMux
	mode   runtimeconfig.Mode
}

func New(ctx context.Context, dataStore *store.Store, natsURL, credentialsFile string, mode runtimeconfig.Mode, logger *slog.Logger) (*Server, error) {
	if err := transportauth.ValidateNATSURL(mode, "asus-node", natsURL); err != nil {
		return nil, err
	}
	credentials, err := transportauth.NATSOptions(mode, credentialsFile)
	if err != nil {
		return nil, err
	}
	options := []nats.Option{
		nats.Name("node-control-controller"),
		nats.Timeout(5 * time.Second),
		nats.MaxReconnects(-1),
	}
	options = append(options, credentials...)
	nc, err := nats.Connect(natsURL, options...)
	if err != nil {
		return nil, err
	}
	js, err := nc.JetStream()
	if err != nil {
		nc.Close()
		return nil, err
	}
	if err := ensureStream(js); err != nil {
		nc.Close()
		return nil, err
	}

	server := &Server{store: dataStore, nats: nc, js: js, logger: logger, mux: http.NewServeMux(), mode: mode}
	if err := server.subscribe(ctx); err != nil {
		nc.Close()
		return nil, err
	}
	server.routes()
	return server, nil
}

func (s *Server) Close() {
	s.nats.Drain() //nolint:errcheck
	s.nats.Close()
}

func (s *Server) Handler() http.Handler { return s.mux }

func ensureStream(js nats.JetStreamContext) error {
	_, err := js.StreamInfo("NC_V1")
	if err == nil {
		return nil
	}
	if !errors.Is(err, nats.ErrStreamNotFound) {
		return err
	}
	_, err = js.AddStream(&nats.StreamConfig{
		Name:      "NC_V1",
		Subjects:  []string{"nc.v1.>"},
		Storage:   nats.FileStorage,
		Retention: nats.LimitsPolicy,
		MaxAge:    24 * time.Hour,
		MaxBytes:  128 << 20,
	})
	return err
}

func (s *Server) subscribe(ctx context.Context) error {
	heartbeatSub, err := s.js.Subscribe("nc.v1.node.*.heartbeat", func(message *nats.Msg) {
		var heartbeat protocol.Heartbeat
		if err := json.Unmarshal(message.Data, &heartbeat); err != nil {
			s.logger.Error("invalid heartbeat", "error", err)
			message.Term() //nolint:errcheck
			return
		}
		expectedSubject := "nc.v1.node." + heartbeat.NodeID + ".heartbeat"
		if heartbeat.APIVersion != protocol.APIVersion ||
			!protocol.IsCanonicalNode(heartbeat.NodeID) || message.Subject != expectedSubject {
			s.logger.Warn("rejected heartbeat", "node", heartbeat.NodeID, "api_version", heartbeat.APIVersion)
			message.Term() //nolint:errcheck
			return
		}
		if err := s.store.UpsertHeartbeat(ctx, heartbeat); err != nil {
			s.logger.Error("store heartbeat", "error", err)
			message.Nak() //nolint:errcheck
			return
		}
		message.Ack() //nolint:errcheck
	}, nats.Durable("controller-heartbeats"), nats.ManualAck(), nats.DeliverAll())
	if err != nil {
		return err
	}
	_ = heartbeatSub

	resultSub, err := s.js.Subscribe("nc.v1.node.*.result", func(message *nats.Msg) {
		var result protocol.Result
		if err := json.Unmarshal(message.Data, &result); err != nil {
			s.logger.Error("invalid result", "error", err)
			message.Term() //nolint:errcheck
			return
		}
		expectedSubject := "nc.v1.node." + result.Target + ".result"
		if result.APIVersion != protocol.APIVersion ||
			!protocol.IsCanonicalNode(result.Target) || message.Subject != expectedSubject {
			s.logger.Warn("rejected result", "target", result.Target)
			message.Term() //nolint:errcheck
			return
		}
		if err := s.store.RecordResult(ctx, result); err != nil {
			if errors.Is(err, store.ErrResultMismatch) {
				s.logger.Warn("rejected unmatched result", "operation_id", result.OperationID, "target", result.Target)
				message.Term() //nolint:errcheck
				return
			}
			s.logger.Error("store result", "error", err)
			message.Nak() //nolint:errcheck
			return
		}
		message.Ack() //nolint:errcheck
	}, nats.Durable("controller-results"), nats.ManualAck(), nats.DeliverAll())
	_ = resultSub
	return err
}

func (s *Server) routes() {
	s.mux.HandleFunc("GET /api/v1alpha1/healthz", s.health)
	s.mux.HandleFunc("GET /api/v1alpha1/nodes", s.nodes)
	s.mux.HandleFunc("POST /api/v1alpha1/operations/plan", s.plan)
	s.mux.HandleFunc("GET /api/v1alpha1/operations/{id}", s.operation)
	s.mux.HandleFunc("POST /api/v1alpha1/operations/{id}/apply", s.apply)
	s.mux.HandleFunc("GET /fragments/nodes", s.nodeFragment)
	s.mux.HandleFunc("GET /", s.portal)
}

func (s *Server) health(w http.ResponseWriter, r *http.Request) {
	if err := s.store.Ping(r.Context()); err != nil {
		writeError(w, http.StatusServiceUnavailable, err)
		return
	}
	if !s.nats.IsConnected() {
		writeError(w, http.StatusServiceUnavailable, errors.New("nats disconnected"))
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"status": "ok", "api_version": protocol.APIVersion, "runtime": s.mode})
}

func (s *Server) nodes(w http.ResponseWriter, r *http.Request) {
	nodes, err := s.store.ListNodes(r.Context())
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"items": nodes})
}

func (s *Server) plan(w http.ResponseWriter, r *http.Request) {
	var request protocol.PlanRequest
	decoder := json.NewDecoder(http.MaxBytesReader(w, r.Body, 1<<20))
	decoder.DisallowUnknownFields()
	if err := decoder.Decode(&request); err != nil {
		writeError(w, http.StatusBadRequest, fmt.Errorf("invalid request: %w", err))
		return
	}
	if err := decoder.Decode(&struct{}{}); !errors.Is(err, io.EOF) {
		writeError(w, http.StatusBadRequest, errors.New("request must contain exactly one JSON object"))
		return
	}
	if len(request.IdempotencyKey) < 8 || len(request.IdempotencyKey) > 128 {
		writeError(w, http.StatusBadRequest, errors.New("idempotency_key must contain 8 to 128 characters"))
		return
	}
	decision, err := policy.Evaluate(request.Target, request.Action)
	if err != nil {
		writeError(w, http.StatusBadRequest, err)
		return
	}
	operation, err := s.store.CreatePlan(r.Context(), request, decision.Reason)
	if err != nil {
		if errors.Is(err, store.ErrIdempotencyConflict) {
			writeError(w, http.StatusConflict, err)
			return
		}
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	writeJSON(w, http.StatusOK, operation)
}

func (s *Server) operation(w http.ResponseWriter, r *http.Request) {
	operation, err := s.store.GetOperation(r.Context(), r.PathValue("id"))
	if err != nil {
		writeError(w, http.StatusNotFound, err)
		return
	}
	writeJSON(w, http.StatusOK, operation)
}

func (s *Server) apply(w http.ResponseWriter, r *http.Request) {
	operation, err := s.store.GetOperation(r.Context(), r.PathValue("id"))
	if err != nil {
		writeError(w, http.StatusNotFound, err)
		return
	}
	if operation.State == "auto-authorized" {
		command := protocol.Command{
			APIVersion:  protocol.APIVersion,
			OperationID: operation.ID,
			Target:      operation.Target,
			Action:      operation.Action,
		}
		encoded, err := json.Marshal(command)
		if err != nil {
			writeError(w, http.StatusInternalServerError, err)
			return
		}
		message := nats.NewMsg("nc.v1.node." + operation.Target + ".command")
		message.Header.Set(nats.MsgIdHdr, operation.ID)
		message.Data = encoded
		if _, err := s.js.PublishMsg(message); err != nil {
			writeError(w, http.StatusServiceUnavailable, err)
			return
		}
		if _, _, err := s.store.MarkDispatched(r.Context(), operation.ID); err != nil {
			writeError(w, http.StatusInternalServerError, err)
			return
		}
	}
	operation, err = s.store.GetOperation(r.Context(), operation.ID)
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	writeJSON(w, http.StatusOK, operation)
}

var portalTemplate = template.Must(template.New("portal").Parse(`<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width">
<title>Node Control</title>
<style>body{font:16px system-ui;max-width:900px;margin:3rem auto;padding:0 1rem}table{border-collapse:collapse;width:100%}td,th{padding:.6rem;border-bottom:1px solid #ccc;text-align:left}code{background:#eee;padding:.15rem .3rem}</style></head>
<body><h1>Node Control</h1><p>{{.Description}}</p>
<section id="nodes">Loading node observations…</section>
<script>async function refresh(){const r=await fetch('/fragments/nodes');if(r.ok)document.getElementById('nodes').innerHTML=await r.text()}refresh();setInterval(refresh,2000)</script>
</body></html>`))

func (s *Server) portal(w http.ResponseWriter, _ *http.Request) {
	w.Header().Set("Content-Type", "text/html; charset=utf-8")
	description := "Authenticated three-node observation and operation surface."
	if s.mode == runtimeconfig.Tracer {
		description = "NC-M2 local evidence surface. No live-node actions."
	}
	portalTemplate.Execute(w, map[string]string{"Description": description}) //nolint:errcheck
}

func (s *Server) nodeFragment(w http.ResponseWriter, r *http.Request) {
	nodes, err := s.store.ListNodes(r.Context())
	if err != nil {
		writeError(w, http.StatusInternalServerError, err)
		return
	}
	var builder strings.Builder
	builder.WriteString("<table><thead><tr><th>Node</th><th>Sequence</th><th>Observed</th></tr></thead><tbody>")
	for _, node := range nodes {
		fmt.Fprintf(&builder, "<tr><td><code>%s</code></td><td>%d</td><td>%s</td></tr>",
			template.HTMLEscapeString(node.NodeID), node.Sequence, node.ObservedAt.UTC().Format(time.RFC3339))
	}
	builder.WriteString("</tbody></table>")
	w.Header().Set("Content-Type", "text/html; charset=utf-8")
	w.WriteHeader(http.StatusOK)
	w.Write([]byte(builder.String())) //nolint:errcheck
}

func writeJSON(w http.ResponseWriter, status int, value any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	json.NewEncoder(w).Encode(value) //nolint:errcheck
}

func writeError(w http.ResponseWriter, status int, err error) {
	writeJSON(w, status, map[string]string{"error": err.Error()})
}

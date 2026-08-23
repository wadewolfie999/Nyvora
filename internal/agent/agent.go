package agent

import (
	"context"
	"encoding/json"
	"fmt"
	"log/slog"
	"time"

	"github.com/nats-io/nats.go"

	"nodecontrol.local/node-control/internal/observation"
	"nodecontrol.local/node-control/internal/protocol"
	"nodecontrol.local/node-control/internal/runtimeconfig"
	"nodecontrol.local/node-control/internal/transportauth"
)

type Agent struct {
	nodeID string
	nats   *nats.Conn
	js     nats.JetStreamContext
	mode   runtimeconfig.Mode
	logger *slog.Logger
}

func New(nodeID, natsURL, credentialsFile string, mode runtimeconfig.Mode, logger *slog.Logger) (*Agent, error) {
	if !protocol.IsCanonicalNode(nodeID) {
		return nil, fmt.Errorf("invalid canonical node %q", nodeID)
	}
	if err := transportauth.ValidateNATSURL(mode, nodeID, natsURL); err != nil {
		return nil, err
	}
	credentials, err := transportauth.NATSOptions(mode, credentialsFile)
	if err != nil {
		return nil, err
	}
	options := []nats.Option{
		nats.Name("node-control-agent-" + nodeID),
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
	return &Agent{nodeID: nodeID, nats: nc, js: js, mode: mode, logger: logger}, nil
}

func (a *Agent) Close() {
	a.nats.Drain() //nolint:errcheck
	a.nats.Close()
}

func (a *Agent) Run(ctx context.Context) error {
	commandSubject := "nc.v1.node." + a.nodeID + ".command"
	_, err := a.js.Subscribe(commandSubject, a.handleCommand,
		nats.Durable("agent-"+a.nodeID),
		nats.ManualAck(),
		nats.DeliverAll(),
	)
	if err != nil {
		return err
	}

	ticker := time.NewTicker(2 * time.Second)
	defer ticker.Stop()
	var sequence int64
	for {
		select {
		case <-ctx.Done():
			return ctx.Err()
		case now := <-ticker.C:
			sequence++
			facts := observation.Collect(a.nodeID, now)
			heartbeat := protocol.Heartbeat{
				APIVersion: protocol.APIVersion,
				NodeID:     a.nodeID,
				Sequence:   sequence,
				ObservedAt: now.UTC(),
				Capabilities: map[string]bool{
					"simulated":        a.mode == runtimeconfig.Tracer,
					"host_observation": a.mode == runtimeconfig.Live,
					"observe_commands": true,
				},
				Facts: facts,
			}
			encoded, _ := json.Marshal(heartbeat)
			if _, err := a.js.Publish("nc.v1.node."+a.nodeID+".heartbeat", encoded); err != nil {
				a.logger.Error("publish heartbeat", "error", err)
			}
		}
	}
}

func (a *Agent) handleCommand(message *nats.Msg) {
	var command protocol.Command
	if err := json.Unmarshal(message.Data, &command); err != nil {
		a.logger.Error("invalid command", "error", err)
		message.Term() //nolint:errcheck
		return
	}
	result := protocol.Result{
		APIVersion:  command.APIVersion,
		OperationID: command.OperationID,
		Target:      a.nodeID,
		ObservedAt:  time.Now().UTC(),
	}
	if command.APIVersion != protocol.APIVersion || command.Target != a.nodeID || command.Action != "observe" {
		result.Success = false
		result.Error = "command outside agent tracer contract"
	} else {
		facts := observation.Collect(a.nodeID, result.ObservedAt)
		result.Success = true
		result.Evidence = json.RawMessage(fmt.Sprintf(
			`{"node_id":%q,"mode":"OBSERVE","simulated":%t,"facts":%s}`,
			a.nodeID,
			a.mode == runtimeconfig.Tracer,
			facts,
		))
	}
	encoded, _ := json.Marshal(result)
	if _, err := a.js.Publish("nc.v1.node."+a.nodeID+".result", encoded); err != nil {
		a.logger.Error("publish result", "error", err)
		message.Nak() //nolint:errcheck
		return
	}
	message.Ack() //nolint:errcheck
}

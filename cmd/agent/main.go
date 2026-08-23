package main

import (
	"context"
	"errors"
	"log/slog"
	"os"
	"os/signal"
	"syscall"

	"nodecontrol.local/node-control/internal/agent"
	"nodecontrol.local/node-control/internal/runtimeconfig"
)

func main() {
	logger := slog.New(slog.NewJSONHandler(os.Stdout, nil))
	ctx, cancel := signal.NotifyContext(context.Background(), syscall.SIGINT, syscall.SIGTERM)
	defer cancel()

	nodeID := os.Getenv("NODE_ID")
	if nodeID == "" {
		logger.Error("NODE_ID is required")
		os.Exit(2)
	}
	natsURL := os.Getenv("NATS_URL")
	mode, err := runtimeconfig.FromEnvironment()
	if err != nil {
		logger.Error("runtime mode", "error", err)
		os.Exit(2)
	}
	if natsURL == "" && mode == runtimeconfig.Tracer {
		natsURL = "nats://127.0.0.1:4222"
	}
	if natsURL == "" {
		logger.Error("NATS_URL is required in live mode")
		os.Exit(2)
	}

	nodeAgent, err := agent.New(nodeID, natsURL, os.Getenv("NATS_CREDS_FILE"), mode, logger)
	if err != nil {
		logger.Error("create agent", "error", err)
		os.Exit(1)
	}
	defer nodeAgent.Close()

	logger.Info("agent started", "node_id", nodeID, "runtime", mode)
	if err := nodeAgent.Run(ctx); err != nil && !errors.Is(err, context.Canceled) {
		logger.Error("run agent", "error", err)
		os.Exit(1)
	}
}

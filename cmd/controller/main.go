package main

import (
	"context"
	"log/slog"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"nodecontrol.local/node-control/internal/controller"
	"nodecontrol.local/node-control/internal/dbconfig"
	"nodecontrol.local/node-control/internal/httpauth"
	"nodecontrol.local/node-control/internal/runtimeconfig"
	"nodecontrol.local/node-control/internal/store"
)

func main() {
	logger := slog.New(slog.NewJSONHandler(os.Stdout, nil))
	ctx, cancel := signal.NotifyContext(context.Background(), syscall.SIGINT, syscall.SIGTERM)
	defer cancel()

	mode, err := runtimeconfig.FromEnvironment()
	if err != nil {
		logger.Error("runtime mode", "error", err)
		os.Exit(2)
	}
	databaseURL := os.Getenv("DATABASE_URL")
	natsURL := os.Getenv("NATS_URL")
	if mode == runtimeconfig.Tracer {
		databaseURL = envOr("DATABASE_URL", "postgres://nodecontrol@127.0.0.1:5432/nodecontrol?sslmode=disable")
		natsURL = envOr("NATS_URL", "nats://127.0.0.1:4222")
	}
	if databaseURL == "" || natsURL == "" {
		logger.Error("DATABASE_URL and NATS_URL are required in live mode")
		os.Exit(2)
	}
	if err := dbconfig.Validate(mode, databaseURL, os.Getenv("PGPASSFILE")); err != nil {
		logger.Error("database configuration", "error", err)
		os.Exit(2)
	}
	listen := envOr("LISTEN_ADDR", ":8080")

	dataStore, err := store.WaitForPostgres(ctx, databaseURL, 30*time.Second)
	if err != nil {
		logger.Error("open postgres", "error", err)
		os.Exit(1)
	}
	defer dataStore.Close()

	controlServer, err := controller.New(ctx, dataStore, natsURL, os.Getenv("NATS_CREDS_FILE"), mode, logger)
	if err != nil {
		logger.Error("create controller", "error", err)
		os.Exit(1)
	}
	defer controlServer.Close()
	authenticator, err := httpauth.FromFiles(
		mode,
		os.Getenv("CONTROLLER_SERVICE_TOKEN_FILE"),
		os.Getenv("CONTROLLER_PROXY_TOKEN_FILE"),
		os.Getenv("CONTROLLER_ALLOWED_USER"),
	)
	if err != nil {
		logger.Error("configure HTTP authentication", "error", err)
		os.Exit(1)
	}

	httpServer := &http.Server{
		Addr:              listen,
		Handler:           authenticator.Protect(controlServer.Handler()),
		ReadHeaderTimeout: 5 * time.Second,
		IdleTimeout:       60 * time.Second,
	}
	go func() {
		<-ctx.Done()
		shutdownCtx, shutdownCancel := context.WithTimeout(context.Background(), 5*time.Second)
		defer shutdownCancel()
		httpServer.Shutdown(shutdownCtx) //nolint:errcheck
	}()

	logger.Info("controller listening", "address", listen, "runtime", mode)
	if err := httpServer.ListenAndServe(); err != nil && err != http.ErrServerClosed {
		logger.Error("serve", "error", err)
		os.Exit(1)
	}
}

func envOr(name, fallback string) string {
	if value := os.Getenv(name); value != "" {
		return value
	}
	return fallback
}

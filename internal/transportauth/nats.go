package transportauth

import (
	"fmt"
	"net/url"
	"os"
	"path/filepath"

	"github.com/nats-io/nats.go"

	"nodecontrol.local/node-control/internal/runtimeconfig"
)

func ValidateNATSURL(mode runtimeconfig.Mode, nodeID, rawURL string) error {
	parsed, err := url.Parse(rawURL)
	if err != nil || parsed.Host == "" {
		return fmt.Errorf("NATS_URL must be an absolute NATS URL")
	}
	if parsed.User != nil {
		return fmt.Errorf("NATS_URL must not contain inline credentials")
	}
	if parsed.Scheme != "nats" && parsed.Scheme != "tls" && parsed.Scheme != "ws" && parsed.Scheme != "wss" {
		return fmt.Errorf("unsupported NATS_URL scheme %q", parsed.Scheme)
	}
	if mode == runtimeconfig.Live && parsed.Scheme == "ws" {
		return fmt.Errorf("live NATS transport must not use plaintext WebSocket")
	}
	if mode == runtimeconfig.Live && nodeID != "asus-node" &&
		parsed.Scheme != "tls" && parsed.Scheme != "wss" {
		return fmt.Errorf("live %s agent requires NATS over tls or wss", nodeID)
	}
	return nil
}

func NATSOptions(mode runtimeconfig.Mode, credentialsFile string) ([]nats.Option, error) {
	if mode == runtimeconfig.Tracer && credentialsFile == "" {
		return nil, nil
	}
	if credentialsFile == "" {
		return nil, fmt.Errorf("NATS_CREDS_FILE is required outside the NC-M2 tracer")
	}
	if !filepath.IsAbs(credentialsFile) {
		return nil, fmt.Errorf("NATS_CREDS_FILE must be an absolute path")
	}
	info, err := os.Stat(credentialsFile)
	if err != nil {
		return nil, fmt.Errorf("inspect NATS credentials: %w", err)
	}
	if !info.Mode().IsRegular() {
		return nil, fmt.Errorf("NATS credentials path is not a regular file")
	}
	return []nats.Option{nats.UserCredentials(credentialsFile)}, nil
}

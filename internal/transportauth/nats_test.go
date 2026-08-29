package transportauth

import (
	"os"
	"path/filepath"
	"testing"

	"nodecontrol.local/node-control/internal/runtimeconfig"
)

func TestNATSOptions(t *testing.T) {
	if options, err := NATSOptions(runtimeconfig.Tracer, ""); err != nil || len(options) != 0 {
		t.Fatalf("tracer options = %d, error = %v", len(options), err)
	}
	if _, err := NATSOptions(runtimeconfig.Live, ""); err == nil {
		t.Fatal("live mode accepted missing credentials")
	}
	if _, err := NATSOptions(runtimeconfig.Live, "relative.creds"); err == nil {
		t.Fatal("live mode accepted relative credentials path")
	}

	path := filepath.Join(t.TempDir(), "agent.creds")
	if err := os.WriteFile(path, []byte("test-only-placeholder"), 0o600); err != nil {
		t.Fatal(err)
	}
	options, err := NATSOptions(runtimeconfig.Live, path)
	if err != nil || len(options) != 1 {
		t.Fatalf("live options = %d, error = %v", len(options), err)
	}
}

func TestValidateNATSURL(t *testing.T) {
	tests := []struct {
		name    string
		mode    runtimeconfig.Mode
		node    string
		url     string
		wantErr bool
	}{
		{name: "tracer internal", mode: runtimeconfig.Tracer, node: "mac-node", url: "nats://nats:4222"},
		{name: "live external wss", mode: runtimeconfig.Live, node: "mac-node", url: "wss://bus.example.test"},
		{name: "live private tls", mode: runtimeconfig.Live, node: "mac-node", url: "tls://asus-node:7422"},
		{name: "live vps rejects plain NATS", mode: runtimeconfig.Live, node: "vps-node", url: "nats://127.0.0.1:4222", wantErr: true},
		{name: "live asus internal", mode: runtimeconfig.Live, node: "asus-node", url: "nats://127.0.0.1:4222"},
		{name: "inline credential", mode: runtimeconfig.Live, node: "asus-node", url: "nats://user:secret@nats:4222", wantErr: true},
		{name: "relative", mode: runtimeconfig.Live, node: "asus-node", url: "nats", wantErr: true},
	}
	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			err := ValidateNATSURL(test.mode, test.node, test.url)
			if (err != nil) != test.wantErr {
				t.Fatalf("ValidateNATSURL() error = %v, wantErr %v", err, test.wantErr)
			}
		})
	}
}

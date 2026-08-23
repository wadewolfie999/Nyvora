package dbconfig

import (
	"os"
	"path/filepath"
	"testing"

	"nodecontrol.local/node-control/internal/runtimeconfig"
)

func TestValidate(t *testing.T) {
	passwordFile := filepath.Join(t.TempDir(), "pgpass")
	if err := os.WriteFile(passwordFile, []byte("db:5432:nodecontrol:nodecontrol:test-only\n"), 0o600); err != nil {
		t.Fatal(err)
	}
	tests := []struct {
		name    string
		mode    runtimeconfig.Mode
		url     string
		file    string
		wantErr bool
	}{
		{name: "tracer trust", mode: runtimeconfig.Tracer, url: "postgres://nodecontrol@postgres:5432/nodecontrol?sslmode=disable"},
		{name: "live passfile", mode: runtimeconfig.Live, url: "postgresql://nodecontrol@postgres:5432/nodecontrol?sslmode=disable", file: passwordFile},
		{name: "live missing passfile", mode: runtimeconfig.Live, url: "postgres://nodecontrol@postgres:5432/nodecontrol", wantErr: true},
		{name: "inline password", mode: runtimeconfig.Live, url: "postgres://nodecontrol:secret@postgres:5432/nodecontrol", file: passwordFile, wantErr: true},
		{name: "relative URL", mode: runtimeconfig.Live, url: "postgres", file: passwordFile, wantErr: true},
	}
	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			err := Validate(test.mode, test.url, test.file)
			if (err != nil) != test.wantErr {
				t.Fatalf("Validate() error = %v, wantErr %v", err, test.wantErr)
			}
		})
	}
}

package dbconfig

import (
	"fmt"
	"net/url"
	"os"
	"path/filepath"

	"nodecontrol.local/node-control/internal/runtimeconfig"
)

func Validate(mode runtimeconfig.Mode, databaseURL, passwordFile string) error {
	parsed, err := url.Parse(databaseURL)
	if err != nil || parsed.Host == "" || (parsed.Scheme != "postgres" && parsed.Scheme != "postgresql") {
		return fmt.Errorf("DATABASE_URL must be an absolute PostgreSQL URL")
	}
	if _, present := parsed.User.Password(); present {
		return fmt.Errorf("DATABASE_URL must not contain an inline password")
	}
	if mode == runtimeconfig.Tracer {
		return nil
	}
	if passwordFile == "" || !filepath.IsAbs(passwordFile) {
		return fmt.Errorf("PGPASSFILE must be an absolute file path in live mode")
	}
	info, err := os.Stat(passwordFile)
	if err != nil {
		return fmt.Errorf("inspect PGPASSFILE: %w", err)
	}
	if !info.Mode().IsRegular() {
		return fmt.Errorf("PGPASSFILE is not a regular file")
	}
	if info.Mode().Perm()&0o077 != 0 {
		return fmt.Errorf("PGPASSFILE must not be readable by group or other")
	}
	return nil
}

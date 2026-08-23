package httpauth

import (
	"crypto/sha256"
	"crypto/subtle"
	"fmt"
	"net/http"
	"os"
	"strings"

	"nodecontrol.local/node-control/internal/runtimeconfig"
)

const ProxyTokenHeader = "X-Node-Control-Proxy-Token"

type Authenticator struct {
	enabled       bool
	serviceDigest [sha256.Size]byte
	proxyDigest   [sha256.Size]byte
	allowedUser   string
}

func FromFiles(
	mode runtimeconfig.Mode,
	serviceTokenFile string,
	proxyTokenFile string,
	allowedUser string,
) (*Authenticator, error) {
	if mode == runtimeconfig.Tracer {
		return &Authenticator{}, nil
	}
	if allowedUser != "vahid" {
		return nil, fmt.Errorf("CONTROLLER_ALLOWED_USER must be the canonical v1 principal %q", "vahid")
	}
	serviceToken, err := readToken("CONTROLLER_SERVICE_TOKEN_FILE", serviceTokenFile)
	if err != nil {
		return nil, err
	}
	proxyToken, err := readToken("CONTROLLER_PROXY_TOKEN_FILE", proxyTokenFile)
	if err != nil {
		return nil, err
	}
	return &Authenticator{
		enabled:       true,
		serviceDigest: sha256.Sum256(serviceToken),
		proxyDigest:   sha256.Sum256(proxyToken),
		allowedUser:   allowedUser,
	}, nil
}

func readToken(variable, path string) ([]byte, error) {
	if path == "" {
		return nil, fmt.Errorf("%s is required in live mode", variable)
	}
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, fmt.Errorf("read %s: %w", variable, err)
	}
	data = []byte(strings.TrimSpace(string(data)))
	if len(data) < 32 {
		return nil, fmt.Errorf("%s must contain at least 32 non-whitespace bytes", variable)
	}
	if strings.ContainsAny(string(data), "\r\n") {
		return nil, fmt.Errorf("%s must contain exactly one token", variable)
	}
	return data, nil
}

func (a *Authenticator) Protect(next http.Handler) http.Handler {
	if !a.enabled {
		return next
	}
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path == "/api/v1alpha1/healthz" {
			next.ServeHTTP(w, r)
			return
		}
		if a.serviceAuthorized(r) || a.proxyAuthorized(r) {
			next.ServeHTTP(w, r)
			return
		}
		w.Header().Set("WWW-Authenticate", `Bearer realm="node-control"`)
		http.Error(w, "authentication required", http.StatusUnauthorized)
	})
}

func (a *Authenticator) serviceAuthorized(r *http.Request) bool {
	header := r.Header.Get("Authorization")
	if !strings.HasPrefix(header, "Bearer ") {
		return false
	}
	credential := strings.TrimPrefix(header, "Bearer ")
	if credential == "" || strings.ContainsAny(credential, " \t\r\n") {
		return false
	}
	digest := sha256.Sum256([]byte(credential))
	return subtle.ConstantTimeCompare(digest[:], a.serviceDigest[:]) == 1
}

func (a *Authenticator) proxyAuthorized(r *http.Request) bool {
	if r.Header.Get("X-Authentik-Username") != a.allowedUser {
		return false
	}
	credential := r.Header.Get(ProxyTokenHeader)
	if credential == "" || strings.ContainsAny(credential, " \t\r\n") {
		return false
	}
	digest := sha256.Sum256([]byte(credential))
	return subtle.ConstantTimeCompare(digest[:], a.proxyDigest[:]) == 1
}

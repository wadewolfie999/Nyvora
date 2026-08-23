package httpauth

import (
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"testing"

	"nodecontrol.local/node-control/internal/runtimeconfig"
)

const (
	testServiceToken = "service-token-used-only-by-this-unit-test"
	testProxyToken   = "proxy-token-used-only-by-this-unit-test-value"
)

func TestTracerDoesNotRequireAuthentication(t *testing.T) {
	authenticator, err := FromFiles(runtimeconfig.Tracer, "", "", "")
	if err != nil {
		t.Fatal(err)
	}
	request := httptest.NewRequest(http.MethodGet, "/", nil)
	response := httptest.NewRecorder()
	authenticator.Protect(okHandler()).ServeHTTP(response, request)
	if response.Code != http.StatusNoContent {
		t.Fatalf("status = %d", response.Code)
	}
}

func TestLiveModeFailsClosed(t *testing.T) {
	if _, err := FromFiles(runtimeconfig.Live, "", "", "vahid"); err == nil {
		t.Fatal("live mode accepted absent token files")
	}
	servicePath, proxyPath := tokenFiles(t)
	if _, err := FromFiles(runtimeconfig.Live, servicePath, proxyPath, "admin"); err == nil {
		t.Fatal("live mode accepted a non-canonical human principal")
	}
}

func TestLiveAuthenticationPaths(t *testing.T) {
	servicePath, proxyPath := tokenFiles(t)
	authenticator, err := FromFiles(runtimeconfig.Live, servicePath, proxyPath, "vahid")
	if err != nil {
		t.Fatal(err)
	}
	handler := authenticator.Protect(okHandler())

	tests := []struct {
		name    string
		path    string
		headers map[string]string
		want    int
	}{
		{name: "health is narrow and public", path: "/api/v1alpha1/healthz", want: http.StatusNoContent},
		{name: "missing", path: "/api/v1alpha1/nodes", want: http.StatusUnauthorized},
		{name: "wrong bearer", path: "/api/v1alpha1/nodes", headers: map[string]string{"Authorization": "Bearer wrong"}, want: http.StatusUnauthorized},
		{name: "service bearer", path: "/api/v1alpha1/nodes", headers: map[string]string{"Authorization": "Bearer " + testServiceToken}, want: http.StatusNoContent},
		{name: "proxy without user", path: "/", headers: map[string]string{ProxyTokenHeader: testProxyToken}, want: http.StatusUnauthorized},
		{name: "proxy wrong user", path: "/", headers: map[string]string{ProxyTokenHeader: testProxyToken, "X-Authentik-Username": "other"}, want: http.StatusUnauthorized},
		{name: "authentik proxy", path: "/", headers: map[string]string{ProxyTokenHeader: testProxyToken, "X-Authentik-Username": "vahid"}, want: http.StatusNoContent},
	}
	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			request := httptest.NewRequest(http.MethodGet, test.path, nil)
			for name, value := range test.headers {
				request.Header.Set(name, value)
			}
			response := httptest.NewRecorder()
			handler.ServeHTTP(response, request)
			if response.Code != test.want {
				t.Fatalf("status = %d, want %d", response.Code, test.want)
			}
		})
	}
}

func tokenFiles(t *testing.T) (string, string) {
	t.Helper()
	directory := t.TempDir()
	servicePath := filepath.Join(directory, "service.token")
	proxyPath := filepath.Join(directory, "proxy.token")
	if err := os.WriteFile(servicePath, []byte(testServiceToken+"\n"), 0o600); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(proxyPath, []byte(testProxyToken+"\n"), 0o600); err != nil {
		t.Fatal(err)
	}
	return servicePath, proxyPath
}

func okHandler() http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		w.WriteHeader(http.StatusNoContent)
	})
}

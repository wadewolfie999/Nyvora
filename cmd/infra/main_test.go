package main

import (
	"io"
	"net/http"
	"os"
	"path/filepath"
	"testing"
)

type captureTransport struct {
	header http.Header
}

func (t *captureTransport) RoundTrip(request *http.Request) (*http.Response, error) {
	t.header = request.Header.Clone()
	return &http.Response{
		StatusCode: http.StatusNoContent,
		Body:       io.NopCloser(http.NoBody),
		Header:     make(http.Header),
		Request:    request,
	}, nil
}

func TestBearerTransportAddsCredentialWithoutMutatingRequest(t *testing.T) {
	base := &captureTransport{}
	transport := bearerTransport{credential: "test-only-credential", base: base}
	request, err := http.NewRequest(http.MethodGet, "https://controller.example.test/", nil)
	if err != nil {
		t.Fatal(err)
	}
	if _, err := transport.RoundTrip(request); err != nil {
		t.Fatal(err)
	}
	if request.Header.Get("Authorization") != "" {
		t.Fatal("original request was mutated")
	}
	if base.header.Get("Authorization") != "Bearer test-only-credential" {
		t.Fatalf("authorization header = %q", base.header.Get("Authorization"))
	}
}

func TestAuthenticatedTransportFileRules(t *testing.T) {
	if _, err := authenticatedTransport(""); err != nil {
		t.Fatal(err)
	}
	if _, err := authenticatedTransport("relative"); err == nil {
		t.Fatal("relative credential path accepted")
	}
	path := filepath.Join(t.TempDir(), "controller.credential")
	if err := os.WriteFile(path, []byte("test-only-controller-credential-value\n"), 0o600); err != nil {
		t.Fatal(err)
	}
	if _, err := authenticatedTransport(path); err != nil {
		t.Fatal(err)
	}
}

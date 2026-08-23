package main

import (
	"bytes"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"time"

	"nodecontrol.local/node-control/internal/protocol"
)

func main() {
	if len(os.Args) < 2 {
		usage()
		os.Exit(2)
	}
	controllerURL := strings.TrimRight(envOr("CONTROLLER_URL", "http://127.0.0.1:18080"), "/")
	transport, err := authenticatedTransport(os.Getenv("CONTROLLER_TOKEN_FILE"))
	if err != nil {
		fmt.Fprintln(os.Stderr, "infra:", err)
		os.Exit(2)
	}
	client := &http.Client{Timeout: 5 * time.Second, Transport: transport}

	switch os.Args[1] {
	case "health":
		err = health(client, controllerURL)
	case "status":
		err = status(client, controllerURL)
	case "dispatch":
		err = dispatch(client, controllerURL, os.Args[2:])
	default:
		usage()
		err = fmt.Errorf("unknown command %q", os.Args[1])
	}
	if err != nil {
		fmt.Fprintln(os.Stderr, "infra:", err)
		os.Exit(1)
	}
}

func health(client *http.Client, controllerURL string) error {
	response, err := requestJSON(client, http.MethodGet, controllerURL+"/api/v1alpha1/healthz", nil)
	if err != nil {
		return err
	}
	var payload struct {
		Status string `json:"status"`
	}
	if err := json.Unmarshal(response, &payload); err != nil {
		return err
	}
	if payload.Status != "ok" {
		return fmt.Errorf("controller health is %q", payload.Status)
	}
	return nil
}

func status(client *http.Client, controllerURL string) error {
	return printResponse(client, http.MethodGet, controllerURL+"/api/v1alpha1/nodes", nil)
}

func dispatch(client *http.Client, controllerURL string, args []string) error {
	if len(args) != 2 || args[0] != "--node" {
		return errors.New("usage: infra dispatch --node <canonical-node>")
	}
	nodeID := args[1]
	request := protocol.PlanRequest{
		Target:         nodeID,
		Action:         "observe",
		IdempotencyKey: fmt.Sprintf("cli-%s-%d", nodeID, time.Now().UnixNano()),
	}
	encoded, _ := json.Marshal(request)
	response, err := requestJSON(client, http.MethodPost, controllerURL+"/api/v1alpha1/operations/plan", encoded)
	if err != nil {
		return err
	}
	var operation protocol.Operation
	if err := json.Unmarshal(response, &operation); err != nil {
		return err
	}
	if _, err := requestJSON(client, http.MethodPost, controllerURL+"/api/v1alpha1/operations/"+operation.ID+"/apply", nil); err != nil {
		return err
	}
	deadline := time.Now().Add(10 * time.Second)
	for time.Now().Before(deadline) {
		response, err = requestJSON(client, http.MethodGet, controllerURL+"/api/v1alpha1/operations/"+operation.ID, nil)
		if err != nil {
			return err
		}
		if err := json.Unmarshal(response, &operation); err != nil {
			return err
		}
		if operation.State == "verified" || operation.State == "failed" {
			var pretty bytes.Buffer
			json.Indent(&pretty, response, "", "  ") //nolint:errcheck
			fmt.Println(pretty.String())
			if operation.State != "verified" {
				return errors.New("operation failed")
			}
			return nil
		}
		time.Sleep(250 * time.Millisecond)
	}
	return errors.New("operation did not finish before deadline")
}

func printResponse(client *http.Client, method, url string, body []byte) error {
	response, err := requestJSON(client, method, url, body)
	if err != nil {
		return err
	}
	var pretty bytes.Buffer
	if err := json.Indent(&pretty, response, "", "  "); err != nil {
		return err
	}
	fmt.Println(pretty.String())
	return nil
}

func requestJSON(client *http.Client, method, url string, body []byte) ([]byte, error) {
	request, err := http.NewRequest(method, url, bytes.NewReader(body))
	if err != nil {
		return nil, err
	}
	if body != nil {
		request.Header.Set("Content-Type", "application/json")
	}
	response, err := client.Do(request)
	if err != nil {
		return nil, err
	}
	defer response.Body.Close()
	data, err := io.ReadAll(io.LimitReader(response.Body, 1<<20))
	if err != nil {
		return nil, err
	}
	if response.StatusCode < 200 || response.StatusCode >= 300 {
		return nil, fmt.Errorf("controller returned %s: %s", response.Status, strings.TrimSpace(string(data)))
	}
	return data, nil
}

func usage() {
	fmt.Fprintln(os.Stderr, "usage: infra health | infra status | infra dispatch --node <canonical-node>")
}

func envOr(name, fallback string) string {
	if value := os.Getenv(name); value != "" {
		return value
	}
	return fallback
}

type bearerTransport struct {
	credential string
	base       http.RoundTripper
}

func (t bearerTransport) RoundTrip(request *http.Request) (*http.Response, error) {
	clone := request.Clone(request.Context())
	clone.Header = request.Header.Clone()
	clone.Header.Set("Authorization", "Bearer "+t.credential)
	return t.base.RoundTrip(clone)
}

func authenticatedTransport(path string) (http.RoundTripper, error) {
	if path == "" {
		return http.DefaultTransport, nil
	}
	if !filepath.IsAbs(path) {
		return nil, fmt.Errorf("CONTROLLER_TOKEN_FILE must be an absolute path")
	}
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, fmt.Errorf("read CONTROLLER_TOKEN_FILE: %w", err)
	}
	credential := strings.TrimSpace(string(data))
	if len(credential) < 32 || strings.ContainsAny(credential, " \t\r\n") {
		return nil, fmt.Errorf("CONTROLLER_TOKEN_FILE must contain exactly one token of at least 32 bytes")
	}
	return bearerTransport{credential: credential, base: http.DefaultTransport}, nil
}

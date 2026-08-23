package observation

import (
	"encoding/json"
	"testing"
	"time"
)

func TestParseMemInfo(t *testing.T) {
	total, available, err := parseMemInfo("MemTotal: 8000000 kB\nMemFree: 1 kB\nMemAvailable: 3000000 kB\n")
	if err != nil {
		t.Fatal(err)
	}
	if total != 8_192_000_000 || available != 3_072_000_000 {
		t.Fatalf("total=%d available=%d", total, available)
	}
}

func TestParseMemInfoRequiresBothValues(t *testing.T) {
	if _, _, err := parseMemInfo("MemTotal: 8000000 kB\n"); err == nil {
		t.Fatal("missing MemAvailable was accepted")
	}
}

func TestCollectProducesBoundedTypedEvidence(t *testing.T) {
	observedAt := time.Date(2026, 8, 21, 12, 0, 0, 0, time.UTC)
	encoded := Collect("mac-node", observedAt)
	var snapshot Snapshot
	if err := json.Unmarshal(encoded, &snapshot); err != nil {
		t.Fatal(err)
	}
	if snapshot.NodeID != "mac-node" || snapshot.Source != "node-agent-local-observation" {
		t.Fatalf("unexpected snapshot: %#v", snapshot)
	}
	if snapshot.ObservedAt != "2026-08-21T12:00:00Z" || snapshot.CPUCount < 1 {
		t.Fatalf("unexpected observation fields: %#v", snapshot)
	}
}

package policy

import (
	"testing"

	"nodecontrol.local/node-control/internal/topology"
)

func TestEvaluate(t *testing.T) {
	tests := []struct {
		name    string
		target  string
		action  string
		wantErr bool
	}{
		{name: "mac observe", target: "mac-node", action: "observe"},
		{name: "vps observe", target: "vps-node", action: "observe"},
		{name: "asus observe", target: "asus-node", action: "observe"},
		{name: "retired target", target: "comp-node", action: "observe", wantErr: true},
		{name: "unknown target", target: "server", action: "observe", wantErr: true},
		{name: "mutation", target: "asus-node", action: "deploy", wantErr: true},
	}
	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			decision, err := EvaluateAs(topology.AuthorityNode, test.target, test.action)
			if (err != nil) != test.wantErr {
				t.Fatalf("Evaluate() error = %v, wantErr %v", err, test.wantErr)
			}
			if err == nil && (!decision.Authorized || !decision.Automatic) {
				t.Fatalf("unexpected decision: %#v", decision)
			}
		})
	}
}

func TestNonAuthorityCannotEvaluateControlPolicy(t *testing.T) {
	if _, err := EvaluateAs("asus-node", "vps-node", "observe"); err == nil {
		t.Fatal("supporting node was accepted as policy authority")
	}
	if _, err := EvaluateAs("vps-node", "asus-node", "observe"); err == nil {
		t.Fatal("relay node was accepted as policy authority")
	}
}

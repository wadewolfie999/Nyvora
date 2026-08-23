package policy

import "testing"

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
			decision, err := Evaluate(test.target, test.action)
			if (err != nil) != test.wantErr {
				t.Fatalf("Evaluate() error = %v, wantErr %v", err, test.wantErr)
			}
			if err == nil && (!decision.Authorized || !decision.Automatic) {
				t.Fatalf("unexpected decision: %#v", decision)
			}
		})
	}
}

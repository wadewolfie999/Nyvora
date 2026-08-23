package policy

import (
	"fmt"

	"nodecontrol.local/node-control/internal/protocol"
)

type Decision struct {
	Authorized bool   `json:"authorized"`
	Automatic  bool   `json:"automatic"`
	Reason     string `json:"reason"`
}

func Evaluate(target, action string) (Decision, error) {
	if target == "comp-node" {
		return Decision{}, fmt.Errorf("retired target; use asus-node")
	}
	if !protocol.IsCanonicalNode(target) {
		return Decision{}, fmt.Errorf("unknown target %q", target)
	}
	if action != "observe" {
		return Decision{}, fmt.Errorf("action %q is outside the current read-only policy envelope", action)
	}
	return Decision{
		Authorized: true,
		Automatic:  true,
		Reason:     "read-only observation is inside permanent Node Control policy",
	}, nil
}

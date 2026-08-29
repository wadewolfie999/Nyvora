package topology

import "testing"

func TestApprovedRoles(t *testing.T) {
	if err := RequireController("mac-node"); err != nil {
		t.Fatal(err)
	}
	if err := RequireLiveAgent("asus-node"); err != nil {
		t.Fatal(err)
	}
	if err := RequireLiveAgent("vps-node"); err != nil {
		t.Fatal(err)
	}
	if err := RequireController("asus-node"); err == nil {
		t.Fatal("asus-node was accepted as controller")
	}
	if err := RequireLiveAgent("mac-node"); err == nil {
		t.Fatal("mac-node was accepted as a live agent")
	}
	if err := RequireLiveAgent("comp-node"); err == nil {
		t.Fatal("retired node was accepted as a live agent")
	}
}

func TestOnlyMacCanAuthorizeAuthorityActions(t *testing.T) {
	actions := []string{
		"create-authority",
		"change-policy",
		"enroll-node",
		"grant-capability",
		"authorize-execution",
	}
	for _, action := range actions {
		if !CanAuthorize("mac-node", action) {
			t.Fatalf("mac-node cannot authorize %s", action)
		}
		for _, nodeID := range []string{"asus-node", "vps-node", "comp-node", "unknown"} {
			if CanAuthorize(nodeID, action) {
				t.Fatalf("%s can authorize %s", nodeID, action)
			}
		}
	}
	if CanAuthorize("mac-node", "unknown-action") {
		t.Fatal("unknown action was authorized")
	}
}

func TestSubjectDirectionIsScoped(t *testing.T) {
	tests := []struct {
		name    string
		nodeID  string
		subject string
		publish bool
		want    bool
	}{
		{name: "mac command", nodeID: "mac-node", subject: "nc.v1.node.asus-node.command", publish: true, want: true},
		{name: "asus heartbeat", nodeID: "asus-node", subject: "nc.v1.node.asus-node.heartbeat", publish: true, want: true},
		{name: "vps result", nodeID: "vps-node", subject: "nc.v1.node.vps-node.result", publish: true, want: true},
		{name: "asus cannot command", nodeID: "asus-node", subject: "nc.v1.node.vps-node.command", publish: true, want: false},
		{name: "vps cannot authority", nodeID: "vps-node", subject: "nc.v1.authority.policy", publish: true, want: false},
		{name: "mac cannot publish heartbeat", nodeID: "mac-node", subject: "nc.v1.node.mac-node.heartbeat", publish: true, want: false},
		{name: "mac receives heartbeat", nodeID: "mac-node", subject: "nc.v1.node.*.heartbeat", publish: false, want: true},
		{name: "asus receives own command", nodeID: "asus-node", subject: "nc.v1.node.asus-node.command", publish: false, want: true},
		{name: "asus receives other command", nodeID: "asus-node", subject: "nc.v1.node.vps-node.command", publish: false, want: false},
	}
	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			got := CanPublish(test.nodeID, test.subject)
			if !test.publish {
				got = CanSubscribe(test.nodeID, test.subject)
			}
			if got != test.want {
				t.Fatalf("authorization = %v, want %v", got, test.want)
			}
		})
	}
}

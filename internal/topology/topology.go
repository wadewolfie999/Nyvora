package topology

import (
	"fmt"
	"strings"
)

const AuthorityNode = "mac-node"

type Node struct {
	ID                    string
	Role                  string
	CanCreateAuthority    bool
	CanChangePolicy       bool
	CanEnrollNodes        bool
	CanGrantCapabilities  bool
	CanAuthorizeExecution bool
}

var nodes = map[string]Node{
	"mac-node": {
		ID:                    "mac-node",
		Role:                  "authoritative-controller",
		CanCreateAuthority:    true,
		CanChangePolicy:       true,
		CanEnrollNodes:        true,
		CanGrantCapabilities:  true,
		CanAuthorizeExecution: true,
	},
	"asus-node": {
		ID:                    "asus-node",
		Role:                  "supporting-services-host",
		CanCreateAuthority:    false,
		CanChangePolicy:       false,
		CanEnrollNodes:        false,
		CanGrantCapabilities:  false,
		CanAuthorizeExecution: false,
	},
	"vps-node": {
		ID:                    "vps-node",
		Role:                  "private-topology-member",
		CanCreateAuthority:    false,
		CanChangePolicy:       false,
		CanEnrollNodes:        false,
		CanGrantCapabilities:  false,
		CanAuthorizeExecution: false,
	},
}

func Lookup(nodeID string) (Node, bool) {
	node, ok := nodes[nodeID]
	return node, ok
}

func IsCanonical(nodeID string) bool {
	_, ok := Lookup(nodeID)
	return ok
}

func RequireController(nodeID string) error {
	if nodeID != AuthorityNode {
		return fmt.Errorf("controller must declare sole authority node %q, got %q", AuthorityNode, nodeID)
	}
	return nil
}

func RequireLiveAgent(nodeID string) error {
	if nodeID != "asus-node" && nodeID != "vps-node" {
		return fmt.Errorf("live agent must be an approved supporting node, got %q", nodeID)
	}
	return nil
}

func CanAuthorize(nodeID, action string) bool {
	node, ok := Lookup(nodeID)
	if !ok {
		return false
	}
	switch action {
	case "create-authority":
		return node.CanCreateAuthority
	case "change-policy":
		return node.CanChangePolicy
	case "enroll-node":
		return node.CanEnrollNodes
	case "grant-capability":
		return node.CanGrantCapabilities
	case "authorize-execution":
		return node.CanAuthorizeExecution
	default:
		return false
	}
}

func CanPublish(nodeID, subject string) bool {
	if !IsCanonical(nodeID) {
		return false
	}
	if strings.HasPrefix(subject, "nc.v1.authority.") {
		return nodeID == AuthorityNode
	}
	parts := strings.Split(subject, ".")
	if len(parts) != 5 || parts[0] != "nc" || parts[1] != "v1" || parts[2] != "node" {
		return false
	}
	target, kind := parts[3], parts[4]
	if kind == "command" {
		return nodeID == AuthorityNode &&
			(target == "asus-node" || target == "vps-node")
	}
	if target != nodeID {
		return false
	}
	return (nodeID == "asus-node" || nodeID == "vps-node") &&
		(kind == "heartbeat" || kind == "result")
}

func CanSubscribe(nodeID, subject string) bool {
	if nodeID == AuthorityNode {
		return subject == "nc.v1.node.*.heartbeat" ||
			subject == "nc.v1.node.*.result" ||
			strings.HasPrefix(subject, "nc.v1.authority.")
	}
	if nodeID != "asus-node" && nodeID != "vps-node" {
		return false
	}
	return subject == "nc.v1.node."+nodeID+".command"
}

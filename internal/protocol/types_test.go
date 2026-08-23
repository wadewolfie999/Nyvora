package protocol

import "testing"

func TestCanonicalNodes(t *testing.T) {
	tests := []struct {
		id   string
		want bool
	}{
		{id: "mac-node", want: true},
		{id: "vps-node", want: true},
		{id: "asus-node", want: true},
		{id: "comp-node", want: false},
		{id: "", want: false},
	}
	for _, test := range tests {
		t.Run(test.id, func(t *testing.T) {
			if got := IsCanonicalNode(test.id); got != test.want {
				t.Fatalf("IsCanonicalNode(%q) = %v, want %v", test.id, got, test.want)
			}
		})
	}
}

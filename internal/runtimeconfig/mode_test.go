package runtimeconfig

import "testing"

func TestFromEnvironment(t *testing.T) {
	tests := []struct {
		name    string
		value   string
		want    Mode
		wantErr bool
	}{
		{name: "default is fail-closed live", want: Live},
		{name: "live", value: "live", want: Live},
		{name: "tracer", value: "tracer", want: Tracer},
		{name: "unknown", value: "development", wantErr: true},
	}
	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			t.Setenv("NODE_CONTROL_RUNTIME", test.value)
			got, err := FromEnvironment()
			if (err != nil) != test.wantErr {
				t.Fatalf("FromEnvironment() error = %v, wantErr %v", err, test.wantErr)
			}
			if err == nil && got != test.want {
				t.Fatalf("FromEnvironment() = %q, want %q", got, test.want)
			}
		})
	}
}

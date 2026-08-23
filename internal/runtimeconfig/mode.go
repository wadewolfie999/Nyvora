package runtimeconfig

import (
	"fmt"
	"os"
)

type Mode string

const (
	Live   Mode = "live"
	Tracer Mode = "tracer"
)

func FromEnvironment() (Mode, error) {
	value := os.Getenv("NODE_CONTROL_RUNTIME")
	if value == "" {
		return Live, nil
	}
	mode := Mode(value)
	if mode != Live && mode != Tracer {
		return "", fmt.Errorf("NODE_CONTROL_RUNTIME must be %q or %q", Live, Tracer)
	}
	return mode, nil
}

func (m Mode) IsLive() bool { return m == Live }

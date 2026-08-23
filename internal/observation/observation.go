package observation

import (
	"bufio"
	"encoding/json"
	"fmt"
	"os"
	"runtime"
	"strconv"
	"strings"
	"time"
)

type Snapshot struct {
	NodeID               string   `json:"node_id"`
	Source               string   `json:"source"`
	ObservedAt           string   `json:"observed_at"`
	Hostname             string   `json:"hostname,omitempty"`
	OS                   string   `json:"os"`
	Architecture         string   `json:"architecture"`
	CPUCount             int      `json:"cpu_count"`
	LoadOneMinute        *float64 `json:"load_one_minute,omitempty"`
	MemoryTotalBytes     *uint64  `json:"memory_total_bytes,omitempty"`
	MemoryAvailableBytes *uint64  `json:"memory_available_bytes,omitempty"`
	UptimeSeconds        *float64 `json:"uptime_seconds,omitempty"`
	Unavailable          []string `json:"unavailable,omitempty"`
}

func Collect(nodeID string, observedAt time.Time) json.RawMessage {
	snapshot := Snapshot{
		NodeID:       nodeID,
		Source:       "node-agent-local-observation",
		ObservedAt:   observedAt.UTC().Format(time.RFC3339Nano),
		OS:           runtime.GOOS,
		Architecture: runtime.GOARCH,
		CPUCount:     runtime.NumCPU(),
	}
	if hostname, err := os.Hostname(); err == nil {
		snapshot.Hostname = hostname
	} else {
		snapshot.Unavailable = append(snapshot.Unavailable, "hostname")
	}
	if runtime.GOOS == "linux" {
		collectLinux(&snapshot)
	} else {
		snapshot.Unavailable = append(snapshot.Unavailable, "load", "memory", "uptime")
	}
	encoded, err := json.Marshal(snapshot)
	if err != nil {
		return json.RawMessage(`{"source":"node-agent-local-observation","unavailable":["encoding"]}`)
	}
	return encoded
}

func collectLinux(snapshot *Snapshot) {
	loadData, err := os.ReadFile("/proc/loadavg")
	if err == nil {
		if load, parseErr := firstFloat(string(loadData)); parseErr == nil {
			snapshot.LoadOneMinute = &load
		} else {
			snapshot.Unavailable = append(snapshot.Unavailable, "load")
		}
	} else {
		snapshot.Unavailable = append(snapshot.Unavailable, "load")
	}

	memoryData, err := os.ReadFile("/proc/meminfo")
	if err == nil {
		total, available, parseErr := parseMemInfo(string(memoryData))
		if parseErr == nil {
			snapshot.MemoryTotalBytes = &total
			snapshot.MemoryAvailableBytes = &available
		} else {
			snapshot.Unavailable = append(snapshot.Unavailable, "memory")
		}
	} else {
		snapshot.Unavailable = append(snapshot.Unavailable, "memory")
	}

	uptimeData, err := os.ReadFile("/proc/uptime")
	if err == nil {
		if uptime, parseErr := firstFloat(string(uptimeData)); parseErr == nil {
			snapshot.UptimeSeconds = &uptime
		} else {
			snapshot.Unavailable = append(snapshot.Unavailable, "uptime")
		}
	} else {
		snapshot.Unavailable = append(snapshot.Unavailable, "uptime")
	}
}

func firstFloat(content string) (float64, error) {
	fields := strings.Fields(content)
	if len(fields) == 0 {
		return 0, fmt.Errorf("numeric source is empty")
	}
	return strconv.ParseFloat(fields[0], 64)
}

func parseMemInfo(content string) (uint64, uint64, error) {
	values := make(map[string]uint64)
	scanner := bufio.NewScanner(strings.NewReader(content))
	for scanner.Scan() {
		fields := strings.Fields(scanner.Text())
		if len(fields) < 2 {
			continue
		}
		name := strings.TrimSuffix(fields[0], ":")
		if name != "MemTotal" && name != "MemAvailable" {
			continue
		}
		value, err := strconv.ParseUint(fields[1], 10, 64)
		if err != nil {
			return 0, 0, fmt.Errorf("parse %s: %w", name, err)
		}
		if len(fields) >= 3 && fields[2] != "kB" {
			return 0, 0, fmt.Errorf("unexpected %s unit %q", name, fields[2])
		}
		values[name] = value * 1024
	}
	if err := scanner.Err(); err != nil {
		return 0, 0, err
	}
	total, hasTotal := values["MemTotal"]
	available, hasAvailable := values["MemAvailable"]
	if !hasTotal || !hasAvailable {
		return 0, 0, fmt.Errorf("MemTotal and MemAvailable are required")
	}
	return total, available, nil
}

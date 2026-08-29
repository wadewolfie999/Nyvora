#!/usr/bin/env ruby
# frozen_string_literal: true

require "digest"
require "fileutils"
require "ipaddr"
require "json"
require "open3"
require "optparse"
require "shellwords"
require "thread"
require "time"
require "timeout"
require "yaml"
require_relative "lib/nc_m3_config"

module NodeControl
  module NCM3Preflight
    VERSION = "1"
    CANONICAL_NODES = %w[mac-node vps-node asus-node].freeze
    DNS_LABELS = %w[control auth bus tunnel].freeze
    REQUIRED_CONFIRMATIONS = %w[
      wildcard_dns_control
      vps_provider_console_recovery
      vps_firewall_control
      asus_interactive_sudo
      asus_no_critical_simulation
      age_offline_recovery_copy
      asus_42665_owner_resolved
      nats_credentials_generated
    ].freeze

    CommandResult = Struct.new(
      :stdout, :stderr, :exit_code, :timed_out, :duration_ms,
      keyword_init: true
    )

    Probe = Struct.new(:id, :category, :description, :command, keyword_init: true)

    class Redactor
      REDACTED = "[REDACTED]"

      def self.call(value)
        text = value.to_s.dup
        text.gsub!(/-----BEGIN (?:RSA |OPENSSH |EC )?PRIVATE KEY-----.*?-----END (?:RSA |OPENSSH |EC )?PRIVATE KEY-----/m, REDACTED)
        text.gsub!(/-----BEGIN NATS USER JWT-----.*?-----END NATS USER JWT-----/m, REDACTED)
        text.gsub!(/-----BEGIN USER NKEY SEED-----.*?-----END USER NKEY SEED-----/m, REDACTED)
        text.gsub!(/AGE-SECRET-KEY-[A-Z0-9-]+/, REDACTED)
        text.gsub!(/\bS[UOAC][A-Z2-7]{40,}\b/, REDACTED)
        text.gsub!(/\beyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\b/, REDACTED)
        text.gsub!(/(?i)\b(authorization\s*:\s*(?:bearer|basic))\s+\S+/, "\\1 #{REDACTED}")
        text.gsub!(/(?i)\b(password|passwd|token|secret|credential)\s*([=:])\s*[^\s,;]+/, "\\1\\2#{REDACTED}")
        text.gsub!(%r{([a-z][a-z0-9+.-]*://)[^/@\s:]+:[^/@\s]+@}i, "\\1#{REDACTED}@")
        text.gsub!(/(?i)([?&](?:access_token|token|password|secret)=)[^&\s]+/, "\\1#{REDACTED}")
        text
      end
    end

    class CommandRunner
      MAX_CAPTURE_BYTES = 256 * 1024

      def run(argv, stdin_data: nil, timeout_seconds: 20)
        started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        stdout_text = +""
        stderr_text = +""
        status = nil
        timed_out = false

        Open3.popen3(*argv, pgroup: true) do |stdin, stdout, stderr, wait_thread|
          if stdin_data
            stdin.write(stdin_data)
          end
          stdin.close

          stdout_reader = Thread.new { drain(stdout, stdout_text) }
          stderr_reader = Thread.new { drain(stderr, stderr_text) }
          begin
            Timeout.timeout(timeout_seconds) { status = wait_thread.value }
          rescue Timeout::Error
            timed_out = true
            terminate_group(wait_thread.pid)
            status = wait_thread.value
          ensure
            stdout_reader.join
            stderr_reader.join
          end
        end

        elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
        CommandResult.new(
          stdout: stdout_text,
          stderr: stderr_text,
          exit_code: status && status.exitstatus,
          timed_out: timed_out,
          duration_ms: (elapsed * 1000).round
        )
      rescue Errno::ENOENT => error
        elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
        CommandResult.new(
          stdout: "",
          stderr: error.message,
          exit_code: 127,
          timed_out: false,
          duration_ms: (elapsed * 1000).round
        )
      end

      private

      def drain(io, destination)
        loop do
          chunk = io.readpartial(16 * 1024)
          remaining = MAX_CAPTURE_BYTES - destination.bytesize
          destination << chunk.byteslice(0, remaining) if remaining.positive?
        end
      rescue EOFError, IOError
        destination << "\n[OUTPUT TRUNCATED]\n" if destination.bytesize >= MAX_CAPTURE_BYTES
      end

      def terminate_group(pid)
        Process.kill("TERM", -pid)
        sleep 0.1
        Process.kill("KILL", -pid)
      rescue Errno::ESRCH
        nil
      end
    end

    class RepositoryInputs
      attr_reader :root, :inventory_path, :bootstrap_path, :artifacts_path,
                  :ports_path, :nats_config_path, :encrypted_secrets_path,
                  :capacity_path, :inventory, :bootstrap, :artifacts, :ports,
                  :capacity

      def initialize(root)
        @root = root
        @inventory_path = File.join(root, "inventory/nodes.yml")
        @bootstrap_path = File.join(root, "config/nc-m3/bootstrap.yml")
        @artifacts_path = File.join(root, "config/nc-m3/artifacts.yml")
        @ports_path = File.join(root, "config/nc-m3/ports.yml")
        @capacity_path = File.join(root, "config/nc-m3/capacity.yml")
        @nats_config_path = File.join(root, "config/nc-m3/nats/server.conf")
        @encrypted_secrets_path = File.join(root, "secrets/nc-m3.enc.yml")
        @inventory = load_yaml(inventory_path)
        @bootstrap = load_yaml(bootstrap_path) if File.file?(bootstrap_path)
        @artifacts = load_yaml(artifacts_path)
        @ports = load_yaml(ports_path)
        @capacity = load_yaml(capacity_path)
        validate_inventory!
      end

      def node(node_id)
        inventory.fetch("spec").fetch("canonical_nodes").fetch(node_id)
      end

      def aliases(node_id)
        Array(node(node_id).dig("access", "aliases")).map do |candidate|
          unless candidate.match?(/\A[a-zA-Z0-9_.-]+\z/)
            raise ArgumentError, "unsafe SSH alias in inventory for #{node_id}"
          end
          candidate
        end
      end

      def expected_hostname(node_id)
        node(node_id).dig("observed", "hostname") || node(node_id).dig("observed_hints", "hostname")
      end

      def expected_user(node_id)
        node(node_id).fetch("account_mapping").fetch("vahid")
      end

      def base_domain
        value = bootstrap && bootstrap.dig("spec", "base_domain")
        domain = value.to_s.downcase
        return nil unless valid_domain?(domain)

        domain
      end

      def confirmations
        preconditions = bootstrap && bootstrap.dig("spec", "preconditions") || {}
        REQUIRED_CONFIRMATIONS.map do |name|
          confirmed = preconditions[name] == true
          {
            "id" => name,
            "classification" => confirmed ? "user_confirmation" : "unavailable",
            "status" => confirmed ? "confirmed" : "missing",
            "source" => relative(bootstrap_path),
            "detail" => confirmed ? "recorded true in the real bootstrap input" : "not recorded true"
          }
        end
      end

      def planned_caddy_version
        artifacts.dig("spec", "native_artifacts", "caddy_linux_amd64", "version").to_s
      end

      def capacity_minimum(name)
        capacity.fetch("spec").fetch("asus-node").fetch("minimum").fetch(name)
      end

      def asus_package_locks
        artifacts.fetch("spec").fetch("asus_packages")
      end

      def repository_blockers
        configuration = NCM3Config.new(
          bootstrap_path: bootstrap_path,
          artifacts_path: artifacts_path,
          ports_path: ports_path,
          nats_config_path: nats_config_path,
          encrypted_secrets_path: encrypted_secrets_path
        )
        configuration.blockers
      rescue StandardError => error
        ["repository readiness inputs could not be validated: #{Redactor.call(error.message)}"]
      end

      def relative(path)
        path.delete_prefix(root + "/")
      end

      private

      def load_yaml(path)
        YAML.safe_load(File.read(path), aliases: false)
      end

      def validate_inventory!
        nodes = inventory.dig("spec", "canonical_nodes") || {}
        unless nodes.keys.sort == CANONICAL_NODES.sort
          raise ArgumentError, "inventory canonical node set is invalid"
        end
      end

      def valid_domain?(domain)
        return false unless domain.match?(/\A(?=.{4,253}\z)(?:[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z]{2,63}\z/)
        return false if domain.end_with?(".invalid", ".example", ".test", ".localhost")

        begin
          IPAddr.new(domain)
          false
        rescue IPAddr::InvalidAddressError
          true
        end
      end
    end

    class ProbeCatalog
      FORBIDDEN_REMOTE_PATTERNS = [
        /\bsystemctl\s+(?:start|stop|restart|reload|enable|disable|mask|unmask|daemon-reload)\b/,
        /\b(?:apt|apt-get|dnf|yum|brew|snap|flatpak)\s+(?:install|remove|upgrade|update)\b/,
        /\b(?:rm|mv|cp|install|chmod|chown|touch|mkdir|rmdir|truncate|dd|mount|umount|kill|pkill|reboot|shutdown)\b/,
        /(?:^|[;&|])\s*(?:iptables|nft|ufw|route\s+(?:add|delete)|ip\s+(?:route|rule|address|link)\s+(?:add|delete|replace|set))\b/,
        /\b(?:ssh-keygen|age-keygen|nsc|nats)\s+(?:generate|add|issue|create)\b/
      ].freeze

      def initialize(domain, caddy_admin_port: 2019)
        @domain = domain
        @caddy_admin_port = Integer(caddy_admin_port)
        raise ArgumentError, "invalid Caddy admin port" unless @caddy_admin_port.between?(1, 65_535)
      end

      def local
        probes = [
          probe("identity", "identity", "hostname, operator, and UTC clock", <<~'SH'),
            printf 'hostname=%s\n' "$(hostname)"
            printf 'user=%s\n' "$(id -un)"
            printf 'utc=%s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
          SH
          probe("os", "os", "macOS and kernel identity", <<~'SH'),
            sw_vers 2>&1
            uname -a 2>&1
          SH
          probe("cpu", "cpu", "CPU model and logical/physical counts", <<~'SH'),
            for key in hw.ncpu hw.physicalcpu hw.logicalcpu machdep.cpu.brand_string; do
              value=$(sysctl -n "$key" 2>/dev/null || true)
              printf '%s=%s\n' "$key" "${value:-unavailable}"
            done
          SH
          probe("memory_swap", "memory", "physical memory and swap state", <<~'SH'),
            printf 'memory_bytes=%s\n' "$(sysctl -n hw.memsize 2>/dev/null || printf unavailable)"
            sysctl vm.swapusage 2>&1 || true
            vm_stat 2>&1 || true
          SH
          probe("gpu", "gpu", "display/GPU hardware", <<~'SH'),
            if command -v system_profiler >/dev/null 2>&1; then
              system_profiler SPDisplaysDataType 2>&1
            else
              printf 'system_profiler=absent\n'
            fi
          SH
          probe("disk", "disk", "root filesystem and non-secret device health", <<~'SH'),
            df -k -P / 2>&1
            if command -v diskutil >/dev/null 2>&1; then
              diskutil info / 2>/dev/null | awk -F: '/Device Node|File System Personality|Disk Size|Volume Free Space|SMART Status/ {gsub(/^[ \t]+/, "", $2); print $1 "=" $2}'
            fi
          SH
          probe("cgroup", "cgroup", "cgroup applicability", "printf 'cgroup=not-applicable-macos\\n'"),
          probe("runtime", "podman", "Podman client and local machine state", <<~'SH'),
            if command -v podman >/dev/null 2>&1; then
              printf 'podman=present\n'
              podman --version 2>&1
              podman machine inspect node-control --format '{{.State}}' 2>&1 || true
            else
              printf 'podman=absent\n'
            fi
          SH
          probe("tools", "tools", "operator-side required tools", tool_probe(%w[ssh curl ruby sops age age-keygen podman])),
          probe("privilege", "privilege", "noninteractive administrative capability", <<~'SH'),
            if sudo -n true >/dev/null 2>&1; then
              printf 'sudo_noninteractive=available\n'
            else
              printf 'sudo_noninteractive=unavailable\n'
            fi
          SH
          probe("services", "services", "operator VPN and Podman process presence", <<~'SH'),
            for process in V2Box PacketTunnel; do
              if pgrep -x "$process" >/dev/null 2>&1; then
                printf 'process.%s=running\n' "$process"
              else
                printf 'process.%s=not-running\n' "$process"
              fi
            done
          SH
          probe("sockets", "sockets", "listening TCP/UDP sockets", <<~'SH'),
            if command -v lsof >/dev/null 2>&1; then
              lsof -nP -iTCP -sTCP:LISTEN 2>&1 || true
              lsof -nP -iUDP 2>&1 || true
            else
              netstat -anv 2>&1 | awk '/LISTEN|udp/ {print}'
            fi
          SH
          probe("vpn", "vpn", "observed default route, tunnel interfaces, and VPN registrations", <<~'SH'),
            route -n get default 2>&1 || true
            ifconfig 2>&1 | awk '/^[a-zA-Z0-9]+:/{name=$1; sub(/:$/, "", name)} name ~ /^(utun|tun|tap|ppp)/ {print}'
            scutil --nc list 2>&1 || true
            if lsof -nP -iTCP:1087 -sTCP:LISTEN >/dev/null 2>&1; then
              printf 'v2box_socks_1087=listening\n'
            else
              printf 'v2box_socks_1087=not-listening\n'
            fi
          SH
        ]
        probes << dns_probe(:mac)
        validate_read_only!(probes)
        probes
      end

      def linux(node_id)
        service_units = if node_id == "asus-node"
          %w[ssh.service docker.service containerd.service jellyfin.service asus-reverse-tunnel.service reverse-ssh.service caddy.service frpc.service]
        else
          %w[ssh.service caddy.service frps.service docker.service containerd.service]
        end
        user_units = node_id == "asus-node" ? %w[tracker.service tracker-edge-tunnel.service node-control-frpc.service node-control-core.target] : []

        probes = [
          probe("identity", "identity", "hostname, operator, and UTC clock", <<~'SH'),
            printf 'hostname=%s\n' "$(hostname)"
            printf 'user=%s\n' "$(id -un)"
            printf 'utc=%s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
          SH
          probe("os", "os", "Linux distribution and kernel identity", <<~'SH'),
            if [ -r /etc/os-release ]; then
              awk -F= '/^(ID|VERSION_ID|PRETTY_NAME)=/ {print}' /etc/os-release
            fi
            uname -a 2>&1
          SH
          probe("cpu", "cpu", "CPU model, architecture, and online count", <<~'SH'),
            printf 'architecture=%s\n' "$(uname -m)"
            printf 'cpu_count=%s\n' "$(getconf _NPROCESSORS_ONLN 2>/dev/null || printf unavailable)"
            awk -F: '/model name/ {gsub(/^[ \t]+/, "", $2); print "model=" $2; exit}' /proc/cpuinfo 2>/dev/null || true
            awk '{print "loadavg=" $1 "," $2 "," $3}' /proc/loadavg 2>/dev/null || true
          SH
          probe("memory_swap", "memory", "RAM and swap capacity", <<~'SH'),
            free -b 2>&1 || awk '/MemTotal|MemAvailable|SwapTotal|SwapFree/ {print}' /proc/meminfo 2>&1
          SH
          probe("gpu", "gpu", "display/GPU hardware and driver visibility", <<~'SH'),
            if command -v lspci >/dev/null 2>&1; then
              lspci 2>&1 | awk 'BEGIN{IGNORECASE=1} /VGA|3D controller|Display controller/ {print}'
            else
              printf 'lspci=absent\n'
            fi
            if command -v nvidia-smi >/dev/null 2>&1; then
              nvidia-smi --query-gpu=name,driver_version,memory.total --format=csv,noheader 2>&1 || true
            else
              printf 'nvidia-smi=absent\n'
            fi
          SH
          probe("disk", "disk", "mounted filesystem capacity and device shape", <<~'SH'),
            df -B1 -P / 2>&1
            if [ -d /mnt/storage ]; then df -B1 -P /mnt/storage 2>&1; else printf 'storage_path./mnt/storage=absent\n'; fi
            if command -v lsblk >/dev/null 2>&1; then lsblk -b -dn -o NAME,SIZE,ROTA,TYPE,MODEL 2>&1; fi
          SH
          probe("cgroup", "cgroup", "cgroup version and current membership", <<~'SH'),
            printf 'cgroup_filesystem=%s\n' "$(stat -fc %T /sys/fs/cgroup 2>/dev/null || printf unavailable)"
            awk '{print "self_cgroup=" $0}' /proc/self/cgroup 2>/dev/null || true
          SH
          probe("runtime", "podman", "rootless Podman prerequisites", <<~'SH'),
            for tool in podman newuidmap newgidmap fuse-overlayfs slirp4netns pasta; do
              if command -v "$tool" >/dev/null 2>&1; then
                printf 'tool.%s=present\n' "$tool"
              else
                printf 'tool.%s=absent\n' "$tool"
              fi
            done
            user=$(id -un)
            if awk -F: -v user="$user" '$1 == user {found=1} END {exit !found}' /etc/subuid 2>/dev/null; then printf 'subuid=present\n'; else printf 'subuid=absent\n'; fi
            if awk -F: -v user="$user" '$1 == user {found=1} END {exit !found}' /etc/subgid 2>/dev/null; then printf 'subgid=present\n'; else printf 'subgid=absent\n'; fi
            if command -v unshare >/dev/null 2>&1 && unshare -Ur true >/dev/null 2>&1; then printf 'userns_probe=pass\n'; else printf 'userns_probe=fail\n'; fi
            linger=$(loginctl show-user "$user" -p Linger --value 2>/dev/null || true)
            printf 'linger=%s\n' "${linger:-unavailable}"
            for package in podman uidmap fuse-overlayfs slirp4netns; do
              installed=$(dpkg-query -W -f='${db:Status-Status}' "$package" 2>/dev/null || true)
              version=$(dpkg-query -W -f='${Version}' "$package" 2>/dev/null || true)
              candidate=$(apt-cache policy "$package" 2>/dev/null | awk '/Candidate:/ {print $2; exit}')
              printf 'package.%s.status=%s\n' "$package" "${installed:-absent}"
              printf 'package.%s.version=%s\n' "$package" "${version:-absent}"
              printf 'package.%s.candidate=%s\n' "$package" "${candidate:-unavailable}"
            done
          SH
          probe("tools", "tools", "bootstrap and diagnostic tool presence", tool_probe(%w[ssh curl systemctl ss lsof fuser podman sops age age-keygen caddy frps frpc nats-server psql docker])),
          probe("privilege", "privilege", "noninteractive administrative capability", <<~'SH'),
            if sudo -n true >/dev/null 2>&1; then
              printf 'sudo_noninteractive=available\n'
            else
              printf 'sudo_noninteractive=unavailable\n'
            fi
          SH
          probe("services", "services", "selected system and user unit state plus bounded HTTP health", service_probe(service_units, user_units, node_id)),
          probe("sockets", "sockets", "listening TCP/UDP sockets without payload inspection", <<~'SH'),
            if command -v ss >/dev/null 2>&1; then
              ss -H -lntu 2>&1 || true
            elif command -v netstat >/dev/null 2>&1; then
              netstat -lntu 2>&1 || true
            else
              printf 'socket_tool=unavailable\n'
            fi
          SH
          probe("vpn", "vpn", "observed default routes, policy rules, and tunnel interfaces", <<~'SH'),
            ip route show default 2>&1 || true
            ip rule show 2>&1 || true
            ip -brief address 2>&1 | awk '$1 ~ /^(tun|tap|wg|tailscale|ppp)/ {print}' || true
          SH
        ]
        probes << probe("port_42665", "port_owner", "unprivileged ownership evidence for TCP/42665", port_owner_probe) if node_id == "asus-node"
        probes << probe("caddy_runtime", "services", "Caddy service ownership, version, and admin health", caddy_runtime_probe) if node_id == "vps-node"
        probes << dns_probe(:linux)
        validate_read_only!(probes)
        probes
      end

      def all
        local + linux("vps-node") + linux("asus-node")
      end

      def validate_read_only!(probes)
        probes.each do |current|
          FORBIDDEN_REMOTE_PATTERNS.each do |pattern|
            if current.command.match?(pattern)
              raise "non-read-only command in probe #{current.id}: #{pattern.inspect}"
            end
          end
          without_privilege_probe = current.command.gsub("sudo -n true", "")
          if without_privilege_probe.match?(/\bsudo\b/)
            raise "privileged command outside the noninteractive capability check in probe #{current.id}"
          end
          if current.command.match?(/\bcurl\b.*(?:--request|-X|--data|-d)\s*(?:POST|PUT|PATCH|DELETE|@|\S)/i)
            raise "non-GET curl command in probe #{current.id}"
          end
          if current.command.match?(/\b(?:podman|docker)\s+(?:run|start|stop|restart|rm|rmi|create|build|pull|push|exec|cp|login|logout|system\s+reset)\b/)
            raise "state-changing container command in probe #{current.id}"
          end
        end
      end

      private

      def probe(id, category, description, command)
        Probe.new(id: id, category: category, description: description, command: command.strip + "\n")
      end

      def tool_probe(tools)
        quoted = tools.map { |tool| Shellwords.escape(tool) }.join(" ")
        <<~SH
          for tool in #{quoted}; do
            if command -v "$tool" >/dev/null 2>&1; then
              printf 'tool.%s=present\\n' "$tool"
            else
              printf 'tool.%s=absent\\n' "$tool"
            fi
          done
        SH
      end

      def service_probe(system_units, user_units, node_id)
        system_list = system_units.map { |unit| Shellwords.escape(unit) }.join(" ")
        user_list = user_units.map { |unit| Shellwords.escape(unit) }.join(" ")
        health = if node_id == "asus-node"
          <<~'SH'
            if command -v curl >/dev/null 2>&1; then
              tracker_code=$(curl --noproxy '*' --silent --show-error --output /dev/null --write-out '%{http_code}' --max-time 4 http://127.0.0.1:3000/ 2>/dev/null || true)
              jellyfin_code=$(curl --noproxy '*' --silent --show-error --output /dev/null --write-out '%{http_code}' --max-time 4 http://127.0.0.1:8096/ 2>/dev/null || true)
              printf 'health.tracker.http=%s\n' "${tracker_code:-unavailable}"
              printf 'health.jellyfin.http=%s\n' "${jellyfin_code:-unavailable}"
            else
              printf 'health.tracker.http=unavailable\nhealth.jellyfin.http=unavailable\n'
            fi
          SH
        else
          ""
        end
        <<~SH
          if command -v systemctl >/dev/null 2>&1; then
            for unit in #{system_list}; do
              load=$(systemctl show "$unit" --property=LoadState --value 2>/dev/null || true)
              active=$(systemctl show "$unit" --property=ActiveState --value 2>/dev/null || true)
              enabled=$(systemctl show "$unit" --property=UnitFileState --value 2>/dev/null || true)
              printf 'system.%s.load=%s\\n' "$unit" "${load:-unavailable}"
              printf 'system.%s.active=%s\\n' "$unit" "${active:-unavailable}"
              printf 'system.%s.enabled=%s\\n' "$unit" "${enabled:-unavailable}"
            done
            for unit in #{user_list}; do
              load=$(systemctl --user show "$unit" --property=LoadState --value 2>/dev/null || true)
              active=$(systemctl --user show "$unit" --property=ActiveState --value 2>/dev/null || true)
              enabled=$(systemctl --user show "$unit" --property=UnitFileState --value 2>/dev/null || true)
              printf 'user.%s.load=%s\\n' "$unit" "${load:-unavailable}"
              printf 'user.%s.active=%s\\n' "$unit" "${active:-unavailable}"
              printf 'user.%s.enabled=%s\\n' "$unit" "${enabled:-unavailable}"
            done
          else
            printf 'systemctl=absent\\n'
          fi
          #{health}
        SH
      end

      def port_owner_probe
        <<~'SH'
          if command -v ss >/dev/null 2>&1; then
            ss -H -ltn 'sport = :42665' 2>&1 || true
            ss -H -ltnp 'sport = :42665' 2>&1 || true
          fi
          if command -v lsof >/dev/null 2>&1; then
            lsof -nP -iTCP:42665 -sTCP:LISTEN 2>&1 || true
          fi
          if command -v fuser >/dev/null 2>&1; then
            fuser -v -n tcp 42665 2>&1 || true
          fi
        SH
      end

      def caddy_runtime_probe
        <<~SH
          if command -v systemctl >/dev/null 2>&1; then
            printf 'service.active=%s\n' "$(systemctl show caddy.service --property=ActiveState --value 2>/dev/null || printf unavailable)"
            printf 'service.main_pid=%s\n' "$(systemctl show caddy.service --property=MainPID --value 2>/dev/null || printf unavailable)"
            printf 'service.fragment_path=%s\n' "$(systemctl show caddy.service --property=FragmentPath --value 2>/dev/null || printf unavailable)"
          fi
          if command -v caddy >/dev/null 2>&1; then
            version=$(caddy version 2>/dev/null | awk 'NR == 1 {print $1}' | sed 's/^v//')
            printf 'binary.version=%s\n' "${version:-unavailable}"
          else
            printf 'binary.version=unavailable\n'
          fi
          if command -v dpkg-query >/dev/null 2>&1; then
            package_version=$(dpkg-query -W -f='${Version}' caddy 2>/dev/null || true)
            printf 'package.version=%s\n' "${package_version:-unavailable}"
          else
            printf 'package.version=unavailable\n'
          fi
          if command -v curl >/dev/null 2>&1; then
            admin_code=$(curl --noproxy '*' --silent --show-error --output /dev/null --write-out '%{http_code}' --max-time 4 http://127.0.0.1:#{@caddy_admin_port}/config/ 2>/dev/null || true)
            printf 'admin.http=%s\n' "${admin_code:-unavailable}"
          else
            printf 'admin.http=unavailable\n'
          fi
        SH
      end

      def hostnames
        [@domain] + DNS_LABELS.map { |label| "#{label}.#{@domain}" }
      end

      def dns_probe(platform)
        unless @domain
          return probe(
            "dns", "dns", "platform endpoint DNS resolution",
            "printf 'configured_domain=unavailable\\n'; exit 4"
          )
        end

        command = platform == :mac ? mac_dns_probe : linux_dns_probe
        probe("dns", "dns", "platform endpoint DNS resolution", command)
      end

      def mac_dns_probe
        hostnames.map do |hostname|
          quoted = Shellwords.escape(hostname)
          <<~SH
            addresses=$(dscacheutil -q host -a name #{quoted} 2>/dev/null | awk '/^ip_address:/ {print $2}' | sort -u | paste -sd, -)
            printf 'dns.#{quoted}=%s\\n' "${addresses:-unresolved}"
          SH
        end.join
      end

      def linux_dns_probe
        hostnames.map do |hostname|
          quoted = Shellwords.escape(hostname)
          <<~SH
            addresses=$(getent ahosts #{quoted} 2>/dev/null | awk '{print $1}' | sort -u | paste -sd, -)
            printf 'dns.#{quoted}=%s\\n' "${addresses:-unresolved}"
          SH
        end.join
      end
    end

    class Collector
      SSH_OPTIONS = [
        "-T",
        "-o", "BatchMode=yes",
        "-o", "ClearAllForwardings=yes",
        "-o", "ForwardAgent=no",
        "-o", "PermitLocalCommand=no",
        "-o", "RequestTTY=no",
        "-o", "ConnectTimeout=8",
        "-o", "ConnectionAttempts=1",
        "-o", "ServerAliveInterval=5",
        "-o", "ServerAliveCountMax=1"
      ].freeze
      BEGIN_MARKER = "__NODE_CONTROL_NC_M3_PROBE_BEGIN__"
      END_MARKER = "__NODE_CONTROL_NC_M3_PROBE_END__"

      attr_reader :inputs, :runner, :catalog

      def initialize(inputs:, runner: CommandRunner.new, clock: -> { Time.now.utc })
        @inputs = inputs
        @runner = runner
        @clock = clock
        caddy_admin_port = inputs.ports.dig("spec", "vps-node", "loopback_tcp", "caddy_admin")
        @catalog = ProbeCatalog.new(inputs.base_domain, caddy_admin_port: caddy_admin_port)
      end

      def plan
        {
          "mode" => "OBSERVE",
          "canonical_nodes" => CANONICAL_NODES,
          "inventory" => inputs.relative(inputs.inventory_path),
          "bootstrap" => inputs.relative(inputs.bootstrap_path),
          "configured_domain" => inputs.base_domain,
          "ssh_options" => SSH_OPTIONS,
          "access_paths" => {
            "mac-node" => ["local"],
            "vps-node" => inputs.aliases("vps-node"),
            "asus-node" => inputs.aliases("asus-node")
          },
          "probes" => {
            "mac-node" => plan_probes(catalog.local),
            "vps-node" => plan_probes(catalog.linux("vps-node")),
            "asus-node" => plan_probes(catalog.linux("asus-node"))
          },
          "forbidden_effects" => [
            "package changes", "DNS/firewall changes", "VPN toggles",
            "service lifecycle changes", "credential creation", "deployment",
            "provider API traffic", "live-node writes"
          ]
        }
      end

      def collect
        collected_at = @clock.call.utc
        node_results = {}
        node_results["mac-node"] = collect_local(catalog.local)
        %w[vps-node asus-node].each do |node_id|
          node_results[node_id] = collect_remote(node_id, catalog.linux(node_id))
        end

        evidence = {
          "api_version" => "nodecontrol.io/v1alpha1",
          "kind" => "NC-M3PreflightEvidence",
          "metadata" => {
            "collected_at" => collected_at.iso8601,
            "collector_version" => VERSION,
            "mode" => "OBSERVE",
            "live_mutation_authorized" => false
          },
          "classification_definitions" => {
            "observed" => "returned directly by a bounded local or SSH probe",
            "unavailable" => "probe failed, was skipped, or lacked permission/data",
            "user_confirmation" => "recorded true in the real repository bootstrap input",
            "inferred" => "derived from named observed evidence or repository policy"
          },
          "inputs" => {
            "inventory" => inputs.relative(inputs.inventory_path),
            "inventory_sha256" => Digest::SHA256.file(inputs.inventory_path).hexdigest,
            "bootstrap" => inputs.relative(inputs.bootstrap_path),
            "bootstrap_present" => File.file?(inputs.bootstrap_path),
            "configured_domain" => inputs.base_domain,
            "ports" => inputs.relative(inputs.ports_path),
            "ports_sha256" => Digest::SHA256.file(inputs.ports_path).hexdigest
          },
          "nodes" => node_results,
          "user_confirmations" => inputs.confirmations,
          "security" => {
            "outputs_redacted" => true,
            "plaintext_private_key_or_credential_files_read" => false,
            "encrypted_sops_envelope_format_checked" => File.file?(inputs.encrypted_secrets_path),
            "secret_contents_emitted" => false,
            "provider_apis_contacted" => false,
            "vpn_toggled" => false,
            "remote_mutation_commands_executed" => false
          }
        }
        evidence["readiness"] = Readiness.new(inputs, evidence).evaluate
        evidence
      end

      private

      def plan_probes(probes)
        probes.map do |current|
          {"id" => current.id, "category" => current.category, "description" => current.description}
        end
      end

      def collect_local(probes)
        records = probes.map do |current|
          result = runner.run(["/bin/sh", "-c", current.command], timeout_seconds: timeout_for(current))
          record(current, result)
        end
        {
          "access" => {
            "type" => "local",
            "selected_path" => "local",
            "attempts" => [{"path" => "local", "classification" => "observed", "status" => "succeeded"}]
          },
          "probes" => records
        }
      end

      def collect_remote(node_id, probes)
        attempts = inputs.aliases(node_id).map { |ssh_alias| probe_path(node_id, ssh_alias) }
        selected = attempts.find { |attempt| attempt["status"] == "succeeded" }
        unless selected
          return {
            "access" => {"type" => "ssh", "selected_path" => nil, "attempts" => attempts},
            "probes" => probes.map { |current| unavailable_record(current, "no configured SSH path authenticated") }
          }
        end

        script = remote_script(probes)
        argv = ["ssh"] + SSH_OPTIONS + [selected.fetch("path"), "sh", "-s"]
        result = runner.run(argv, stdin_data: script, timeout_seconds: 90)
        records = parse_remote_records(probes, result)
        {
          "access" => {
            "type" => "ssh",
            "selected_path" => selected.fetch("path"),
            "attempts" => attempts,
            "collection_exit_code" => result.exit_code,
            "collection_timed_out" => result.timed_out,
            "collection_stderr" => Redactor.call(result.stderr).strip
          },
          "probes" => records
        }
      end

      def probe_path(node_id, ssh_alias)
        command = "printf 'hostname=%s\\n' \"$(hostname)\"; printf 'user=%s\\n' \"$(id -un)\""
        argv = ["ssh"] + SSH_OPTIONS + [ssh_alias, command]
        result = runner.run(argv, timeout_seconds: 15)
        authenticated = result.exit_code == 0 && !result.timed_out
        values = key_values(result.stdout)
        identity_matches = authenticated &&
          normalize_hostname(values["hostname"]) == normalize_hostname(inputs.expected_hostname(node_id)) &&
          values["user"] == inputs.expected_user(node_id)
        {
          "path" => ssh_alias,
          "classification" => authenticated ? "observed" : "unavailable",
          "status" => identity_matches ? "succeeded" : (authenticated ? "identity-mismatch" : "failed"),
          "exit_code" => result.exit_code,
          "timed_out" => result.timed_out,
          "duration_ms" => result.duration_ms,
          "output" => Redactor.call([result.stdout, result.stderr].reject(&:empty?).join("\n")).strip
        }
      end

      def remote_script(probes)
        body = ["set +e"]
        probes.each do |current|
          body << "printf '#{BEGIN_MARKER} #{current.id}\\n'"
          body << "sh -c #{Shellwords.escape(current.command)} 2>&1"
          body << "probe_status=$?"
          body << "printf '\\n#{END_MARKER} #{current.id} %s\\n' \"$probe_status\""
        end
        body << "exit 0"
        body.join("\n") + "\n"
      end

      def parse_remote_records(probes, result)
        return probes.map { |current| unavailable_record(current, "SSH collection timed out") } if result.timed_out

        sections = {}
        current_id = nil
        buffer = []
        result.stdout.each_line do |line|
          if (match = line.match(/\A#{Regexp.escape(BEGIN_MARKER)} ([a-z0-9_]+)\s*\z/))
            current_id = match[1]
            buffer = []
          elsif current_id && (match = line.match(/\A#{Regexp.escape(END_MARKER)} ([a-z0-9_]+) (\d+)\s*\z/))
            sections[current_id] = {"output" => buffer.join.strip, "exit_code" => match[2].to_i}
            current_id = nil
            buffer = []
          elsif current_id
            buffer << line
          end
        end

        probes.map do |current|
          section = sections[current.id]
          unless section
            next unavailable_record(current, "probe output was absent or incomplete")
          end
          succeeded = section.fetch("exit_code") == 0
          {
            "id" => current.id,
            "category" => current.category,
            "description" => current.description,
            "classification" => succeeded ? "observed" : "unavailable",
            "status" => succeeded ? "succeeded" : "failed",
            "exit_code" => section.fetch("exit_code"),
            "timed_out" => false,
            "output" => Redactor.call(section.fetch("output"))
          }
        end
      end

      def record(current, result)
        succeeded = result.exit_code == 0 && !result.timed_out
        output = [result.stdout, result.stderr].reject(&:empty?).join("\n").strip
        {
          "id" => current.id,
          "category" => current.category,
          "description" => current.description,
          "classification" => succeeded ? "observed" : "unavailable",
          "status" => succeeded ? "succeeded" : "failed",
          "exit_code" => result.exit_code,
          "timed_out" => result.timed_out,
          "duration_ms" => result.duration_ms,
          "output" => Redactor.call(output)
        }
      end

      def unavailable_record(current, reason)
        {
          "id" => current.id,
          "category" => current.category,
          "description" => current.description,
          "classification" => "unavailable",
          "status" => "skipped",
          "exit_code" => nil,
          "timed_out" => false,
          "output" => reason
        }
      end

      def timeout_for(probe)
        probe.id == "gpu" ? 30 : 15
      end

      def key_values(output)
        output.to_s.each_line.each_with_object({}) do |line, values|
          key, value = line.strip.split("=", 2)
          values[key] = value if key && value
        end
      end

      def normalize_hostname(value)
        value.to_s.strip.downcase.sub(/\.local\z/, "")
      end
    end

    class Readiness
      def initialize(inputs, evidence)
        @inputs = inputs
        @evidence = evidence
        @results = []
        @blockers = []
        @warnings = []
      end

      def evaluate
        repository_rules
        access_and_identity_rules
        dns_rules
        privilege_and_runtime_rules
        capacity_rules
        port_rules
        preservation_rules
        vpn_rules
        confirmation_rules
        {
          "status" => @blockers.empty? ? "READY" : "BLOCKED",
          "classification" => "inferred",
          "blockers" => @blockers.uniq.sort,
          "warnings" => @warnings.uniq.sort,
          "results" => @results
        }
      end

      private

      def repository_rules
        @inputs.repository_blockers.each do |message|
          add("repository.#{stable_id(message)}", false, message, ["repository configuration"])
        end
      end

      def access_and_identity_rules
        CANONICAL_NODES.each do |node_id|
          node = @evidence.fetch("nodes").fetch(node_id)
          selected = node.dig("access", "selected_path")
          add("#{node_id}.access", !selected.nil?, "no configured access path succeeded for #{node_id}", ["#{node_id}.access"])
          next unless selected

          identity = probe(node_id, "identity")
          values = key_values(identity && identity["output"])
          expected_host = normalize_hostname(@inputs.expected_hostname(node_id))
          actual_host = normalize_hostname(values["hostname"])
          expected_user = @inputs.expected_user(node_id)
          add("#{node_id}.hostname", actual_host == expected_host, "#{node_id} hostname did not match inventory", ["#{node_id}.identity"])
          add("#{node_id}.operator", values["user"] == expected_user, "#{node_id} operator account did not match inventory", ["#{node_id}.identity"])
        end
      end

      def dns_rules
        domain = @inputs.base_domain
        unless domain
          add("dns.domain", false, "configured platform domain is absent or not routable", ["config/nc-m3/bootstrap.yml"])
          return
        end

        expected_hosts = [domain] + DNS_LABELS.map { |label| "#{label}.#{domain}" }
        CANONICAL_NODES.each do |node_id|
          output = probe_output(node_id, "dns")
          expected_hosts.each do |hostname|
            value = key_values(output)["dns.#{hostname}"]
            add("#{node_id}.dns.#{hostname}", value && value != "unresolved", "#{hostname} did not resolve on #{node_id}", ["#{node_id}.dns"])
          end
        end
      end

      def privilege_and_runtime_rules
        vps_privilege = key_values(probe_output("vps-node", "privilege"))["sudo_noninteractive"]
        add("vps-node.privilege", vps_privilege == "available", "vps-node noninteractive administrative path is unavailable", ["vps-node.privilege"])

        runtime = key_values(probe_output("asus-node", "runtime"))
        required = {
          "tool.podman" => "present",
          "tool.newuidmap" => "present",
          "tool.newgidmap" => "present",
          "tool.fuse-overlayfs" => "present",
          "subuid" => "present",
          "subgid" => "present",
          "userns_probe" => "pass",
          "linger" => "yes"
        }
        required.each do |key, expected|
          add("asus-node.runtime.#{key}", runtime[key] == expected, "asus-node rootless runtime prerequisite #{key}=#{expected} is not observed", ["asus-node.runtime"])
        end
        network_ready = runtime["tool.slirp4netns"] == "present" || runtime["tool.pasta"] == "present"
        add("asus-node.runtime.network", network_ready, "asus-node lacks a rootless network helper", ["asus-node.runtime"])
        @inputs.asus_package_locks.each do |package, locked_version|
          installed = runtime["package.#{package}.version"]
          candidate = runtime["package.#{package}.candidate"]
          add(
            "asus-node.package.#{package}.candidate",
            candidate == locked_version,
            "asus-node package #{package} candidate #{candidate || 'unavailable'} differs from lock #{locked_version}",
            ["asus-node.runtime", "config/nc-m3/artifacts.yml"]
          )
          next if installed.nil? || installed == "absent"

          add(
            "asus-node.package.#{package}.installed",
            installed == locked_version,
            "asus-node installed package #{package} #{installed} differs from lock #{locked_version}",
            ["asus-node.runtime", "config/nc-m3/artifacts.yml"]
          )
        end

        local_tools = key_values(probe_output("mac-node", "tools"))
        %w[ssh curl ruby sops age age-keygen].each do |tool|
          add("mac-node.tool.#{tool}", local_tools["tool.#{tool}"] == "present", "mac-node required tool #{tool} is absent", ["mac-node.tools"])
        end

        %w[vps-node asus-node].each do |node_id|
          tools = key_values(probe_output(node_id, "tools"))
          %w[ssh curl systemctl ss].each do |tool|
            add("#{node_id}.tool.#{tool}", tools["tool.#{tool}"] == "present", "#{node_id} diagnostic tool #{tool} is absent", ["#{node_id}.tools"])
          end
        end

        vps_tools = key_values(probe_output("vps-node", "tools"))
        %w[caddy frps].each do |tool|
          unless vps_tools["tool.#{tool}"] == "present"
            warn_result("vps-node.tool.#{tool}", "vps-node #{tool} is not installed; installation remains a separate APPLY step", ["vps-node.tools"])
          end
        end
      end

      def capacity_rules
        memory = linux_memory_values(probe_output("asus-node", "memory_swap"))
        disk = linux_root_available_bytes(probe_output("asus-node", "disk"))
        checks = {
          "memory_available_bytes" => memory["memory_available_bytes"],
          "swap_free_bytes" => memory["swap_free_bytes"],
          "root_free_bytes" => disk
        }
        checks.each do |name, observed|
          minimum = @inputs.capacity_minimum(name)
          add(
            "asus-node.capacity.#{name}",
            observed && observed >= minimum,
            "asus-node #{name} is below the NC-M3 admission minimum of #{minimum} bytes",
            [name == "root_free_bytes" ? "asus-node.disk" : "asus-node.memory_swap"]
          )
        end
      end

      def port_rules
        allocations = @inputs.ports.fetch("spec")
        %w[vps-node asus-node].each do |node_id|
          output = probe_output(node_id, "sockets")
          allocations.fetch(node_id).fetch("loopback_tcp").each do |name, port|
            if node_id == "vps-node" && name == "caddy_admin"
              evaluate_caddy_admin_port(output, port)
              next
            end

            free = !listening_port?(output, port)
            if free
              port_result("#{node_id}.port.#{port}", "satisfied", "free_candidate", "#{node_id} candidate #{name} TCP/#{port} is free", ["#{node_id}.sockets"])
            else
              blocker = "#{node_id} candidate #{name} TCP/#{port} is already listening"
              @blockers << blocker
              port_result("#{node_id}.port.#{port}", "blocked", "collision", blocker, ["#{node_id}.sockets"])
            end
          end
        end

        owner_output = probe_output("asus-node", "port_42665")
        present = listening_port?(owner_output, 42_665)
        if present
          port_result("asus-node.port.42665.present", "satisfied", "protected_listener", "asus-node protected TCP/42665 remains present", ["asus-node.port_42665"])
        else
          blocker = "asus-node protected TCP/42665 is no longer observed; baseline drift requires review"
          @blockers << blocker
          port_result("asus-node.port.42665.present", "blocked", "missing_expected_listener", blocker, ["asus-node.port_42665"])
        end
        owner_visible = owner_output.match?(/users:\(\(|\bCOMMAND\s+PID\b|\bpid=\d+|\bcontainerd\b/i)
        if owner_visible
          pass_result("asus-node.port.42665.process", "asus-node TCP/42665 process-level ownership evidence was visible", ["asus-node.port_42665"])
        else
          warn_result("asus-node.port.42665.process", "asus-node TCP/42665 process owner was unavailable at current permissions", ["asus-node.port_42665"])
        end
      end

      def evaluate_caddy_admin_port(sockets, port)
        runtime = key_values(probe_output("vps-node", "caddy_runtime"))
        listening = listening_port?(sockets, port)
        active = runtime["service.active"] == "active"
        main_pid = runtime["service.main_pid"].to_s.match?(/\A[1-9]\d*\z/)
        admin_healthy = runtime["admin.http"].to_s.match?(/\A2\d\d\z/)
        owned = listening && active && main_pid && admin_healthy

        if owned
          port_result(
            "vps-node.port.#{port}", "satisfied", "expected_listener",
            "vps-node Caddy admin TCP/#{port} is an expected healthy listener",
            ["vps-node.sockets", "vps-node.caddy_runtime"]
          )
        else
          disposition = listening ? "collision" : "missing_expected_listener"
          blocker = if listening
            "vps-node TCP/#{port} is listening without verified active Caddy ownership and admin health"
          else
            "vps-node expected Caddy admin TCP/#{port} listener is absent"
          end
          @blockers << blocker
          port_result("vps-node.port.#{port}", "blocked", disposition, blocker, ["vps-node.sockets", "vps-node.caddy_runtime"])
        end

        observed_version = runtime["binary.version"].to_s
        planned_version = @inputs.planned_caddy_version
        if observed_version.empty? || observed_version == "unavailable"
          warn_result("vps-node.caddy.version", "vps-node Caddy binary version was unavailable", ["vps-node.caddy_runtime"])
        elsif observed_version == planned_version
          pass_result("vps-node.caddy.version", "vps-node Caddy binary matches planned #{planned_version}", ["vps-node.caddy_runtime"])
        else
          warn_result(
            "vps-node.caddy.version",
            "vps-node Caddy binary #{observed_version} differs from planned #{planned_version}; preserve the live binary until side-by-side validation succeeds",
            ["vps-node.caddy_runtime", "config/nc-m3/artifacts.yml"]
          )
        end
      end

      def preservation_rules
        vps_services = key_values(probe_output("vps-node", "services"))
        vps_caddy = key_values(probe_output("vps-node", "caddy_runtime"))
        add("preserve.vps.caddy.unit", vps_services["system.caddy.service.active"] == "active", "VPS Caddy service is not observed active", ["vps-node.services"])
        add("preserve.vps.caddy.enabled", vps_services["system.caddy.service.enabled"] == "enabled", "VPS Caddy service is not observed enabled", ["vps-node.services"])
        add("preserve.vps.caddy.admin", vps_caddy["admin.http"].to_s.match?(/\A2\d\d\z/), "VPS Caddy admin health is unavailable or failing", ["vps-node.caddy_runtime"])

        services = key_values(probe_output("asus-node", "services"))
        sockets = probe_output("asus-node", "sockets")

        add("preserve.tracker.unit", services["user.tracker.service.active"] == "active", "Tracker user service is not observed active", ["asus-node.services"])
        add("preserve.tracker.enabled", services["user.tracker.service.enabled"] == "enabled", "Tracker user service is not observed enabled", ["asus-node.services"])
        tracker_code = services["health.tracker.http"].to_s
        add("preserve.tracker.http", tracker_code.match?(/\A[23]\d\d\z/), "Tracker loopback HTTP health is unavailable or failing", ["asus-node.services"])
        add("preserve.tracker.port", listening_port?(sockets, 3000), "Tracker protected TCP/3000 listener is absent", ["asus-node.sockets"])
        add("preserve.tracker_edge_tunnel.unit", services["user.tracker-edge-tunnel.service.active"] == "active", "Tracker edge-tunnel user service is not observed active", ["asus-node.services"])
        add("preserve.tracker_edge_tunnel.enabled", services["user.tracker-edge-tunnel.service.enabled"] == "enabled", "Tracker edge-tunnel user service is not observed enabled", ["asus-node.services"])

        add("preserve.docker", services["system.docker.service.active"] == "active", "Docker service is not observed active", ["asus-node.services"])
        add("preserve.docker.enabled", services["system.docker.service.enabled"] == "enabled", "Docker service is not observed enabled", ["asus-node.services"])
        add("preserve.containerd", services["system.containerd.service.active"] == "active", "containerd service is not observed active", ["asus-node.services"])
        add("preserve.containerd.enabled", services["system.containerd.service.enabled"] == "enabled", "containerd service is not observed enabled", ["asus-node.services"])
        jellyfin_code = services["health.jellyfin.http"].to_s
        jellyfin_http = jellyfin_code.match?(/\A[234]\d\d\z/)
        add("preserve.jellyfin.http", jellyfin_http, "Jellyfin loopback HTTP health is unavailable or failing", ["asus-node.services"])
        add("preserve.jellyfin.tcp", listening_port?(sockets, 8096), "Jellyfin TCP/8096 listener is absent", ["asus-node.sockets"])
        add("preserve.jellyfin.udp", listening_port?(sockets, 7359), "Jellyfin UDP/7359 listener is absent", ["asus-node.sockets"])

        add("preserve.asus_tunnel", services["system.asus-reverse-tunnel.service.active"] == "active", "asus reverse-tunnel service is not observed active", ["asus-node.services"])
        add("preserve.asus_tunnel.enabled", services["system.asus-reverse-tunnel.service.enabled"] == "enabled", "asus reverse-tunnel service is not observed enabled", ["asus-node.services"])
        legacy_loaded = services["system.reverse-ssh.service.load"] && services["system.reverse-ssh.service.load"] != "not-found"
        add("preserve.legacy_tunnel", legacy_loaded, "legacy reverse-ssh service is not present", ["asus-node.services"])
        add("preserve.legacy_tunnel.active", services["system.reverse-ssh.service.active"] == "active", "legacy reverse-ssh service is not observed active", ["asus-node.services"])
        add("preserve.legacy_tunnel.enabled", services["system.reverse-ssh.service.enabled"] == "enabled", "legacy reverse-ssh service is not observed enabled", ["asus-node.services"])
      end

      def vpn_rules
        output = probe_output("mac-node", "vpn")
        if output.empty?
          warn_result("mac-node.vpn.current", "mac-node current VPN state was unavailable", ["mac-node.vpn"])
        elsif output.match?(/interface:\s*(?:utun|tun|tap|ppp)|^utun\d+:/m)
          pass_result("mac-node.vpn.current", "mac-node current route is inferred VPN-enabled-like from a tunnel interface", ["mac-node.vpn"])
        else
          pass_result("mac-node.vpn.current", "mac-node current route is inferred VPN-disabled-like because no tunnel interface was observed as default", ["mac-node.vpn"])
        end
        warn_result("mac-node.vpn.alternate", "one collection observes only the current VPN mode; the alternate mode remains unverified", ["mac-node.vpn"])
      end

      def confirmation_rules
        @inputs.confirmations.each do |confirmation|
          confirmed = confirmation["status"] == "confirmed"
          add("confirmation.#{confirmation.fetch("id")}", confirmed, "explicit confirmation #{confirmation.fetch("id")} is missing", [confirmation.fetch("source")])
        end
      end

      def probe(node_id, probe_id)
        @evidence.fetch("nodes").fetch(node_id).fetch("probes").find { |candidate| candidate["id"] == probe_id }
      end

      def probe_output(node_id, probe_id)
        current = probe(node_id, probe_id)
        current ? current["output"].to_s : ""
      end

      def key_values(output)
        output.to_s.each_line.each_with_object({}) do |line, values|
          key, value = line.strip.split("=", 2)
          values[key] = value if key && value
        end
      end

      def listening_port?(output, port)
        output.to_s.each_line.any? do |line|
          line.match?(/(?:\[.*\]|\*|[0-9a-fA-F:.]+):#{port}(?:\s|$)/)
        end
      end

      def linux_memory_values(output)
        values = {}
        output.to_s.each_line do |line|
          fields = line.split
          values["memory_available_bytes"] = Integer(fields[6], exception: false) if fields[0] == "Mem:" && fields.length >= 7
          values["swap_free_bytes"] = Integer(fields[3], exception: false) if fields[0] == "Swap:" && fields.length >= 4
        end
        values
      end

      def linux_root_available_bytes(output)
        line = output.to_s.each_line.find { |candidate| candidate.split.last == "/" }
        fields = line.to_s.split
        Integer(fields[3], exception: false) if fields.length >= 6
      end

      def normalize_hostname(value)
        value.to_s.strip.downcase.sub(/\.local\z/, "")
      end

      def add(id, satisfied, blocker, evidence_refs)
        if satisfied
          pass_result(id, "condition satisfied; see referenced evidence", evidence_refs)
        else
          @blockers << blocker
          @results << result(id, "blocked", blocker, evidence_refs)
        end
      end

      def pass_result(id, detail, evidence_refs)
        @results << result(id, "satisfied", detail, evidence_refs)
      end

      def port_result(id, status, disposition, detail, evidence_refs)
        @results << result(id, status, detail, evidence_refs).merge("port_disposition" => disposition)
      end

      def warn_result(id, detail, evidence_refs)
        @warnings << detail
        @results << result(id, "warning", detail, evidence_refs)
      end

      def result(id, status, detail, evidence_refs)
        {
          "id" => id,
          "classification" => "inferred",
          "status" => status,
          "detail" => detail,
          "evidence_refs" => evidence_refs
        }
      end

      def stable_id(value)
        Digest::SHA256.hexdigest(value)[0, 12]
      end
    end

    class BundleWriter
      attr_reader :root

      def initialize(root)
        @root = root
      end

      def write(evidence)
        timestamp = Time.iso8601(evidence.fetch("metadata").fetch("collected_at")).strftime("%Y%m%dT%H%M%SZ")
        destination = File.join(root, timestamp)
        raise ArgumentError, "evidence bundle already exists: #{destination}" if File.exist?(destination)

        partial = "#{destination}.partial-#{Process.pid}"
        raise ArgumentError, "partial evidence bundle already exists: #{partial}" if File.exist?(partial)

        FileUtils.mkdir_p(partial, mode: 0o700)
        write_file(File.join(partial, "evidence.json"), JSON.pretty_generate(evidence) + "\n")
        write_file(File.join(partial, "REPORT.md"), markdown(evidence))
        manifest = %w[evidence.json REPORT.md].map do |name|
          "#{Digest::SHA256.file(File.join(partial, name)).hexdigest}  #{name}"
        end.join("\n") + "\n"
        write_file(File.join(partial, "MANIFEST.sha256"), manifest)
        File.rename(partial, destination)
        destination
      rescue StandardError
        FileUtils.remove_entry_secure(partial) if defined?(partial) && File.directory?(partial)
        raise
      end

      private

      def write_file(path, content)
        File.open(path, File::WRONLY | File::CREAT | File::EXCL, 0o600) { |file| file.write(content) }
      end

      def markdown(evidence)
        readiness = evidence.fetch("readiness")
        lines = [
          "# NC-M3 Read-only Preflight Report",
          "",
          "Collected: `#{evidence.dig("metadata", "collected_at")}`",
          "",
          "Result: **#{readiness.fetch("status")}**",
          "",
          "This bundle is OBSERVE evidence only. It does not authorize or prove any live change.",
          "",
          "## Access and collection",
          "",
          "| Node | Selected path | Observed probes | Unavailable probes |",
          "| --- | --- | ---: | ---: |"
        ]
        CANONICAL_NODES.each do |node_id|
          node = evidence.fetch("nodes").fetch(node_id)
          observed = node.fetch("probes").count { |probe| probe["classification"] == "observed" }
          unavailable = node.fetch("probes").count { |probe| probe["classification"] == "unavailable" }
          lines << "| `#{node_id}` | `#{node.dig("access", "selected_path") || "unavailable"}` | #{observed} | #{unavailable} |"
        end
        lines.concat(["", "## Blockers", ""])
        if readiness.fetch("blockers").empty?
          lines << "- None."
        else
          readiness.fetch("blockers").each { |blocker| lines << "- #{blocker}" }
        end
        lines.concat(["", "## Warnings", ""])
        if readiness.fetch("warnings").empty?
          lines << "- None."
        else
          readiness.fetch("warnings").each { |warning| lines << "- #{warning}" }
        end
        port_results = readiness.fetch("results", []).select { |result| result.key?("port_disposition") }
        lines.concat(["", "## Port disposition", "", "| Check | Disposition | Status | Detail |", "| --- | --- | --- | --- |"])
        port_results.each do |result|
          detail = result.fetch("detail").gsub("|", "\\|")
          lines << "| `#{result.fetch("id")}` | `#{result.fetch("port_disposition")}` | `#{result.fetch("status")}` | #{detail} |"
        end
        lines.concat(["", "## User confirmations", "", "| Confirmation | Classification | Status |", "| --- | --- | --- |"])
        evidence.fetch("user_confirmations").each do |confirmation|
          lines << "| `#{confirmation.fetch("id")}` | `#{confirmation.fetch("classification")}` | `#{confirmation.fetch("status")}` |"
        end
        unavailable = evidence.fetch("nodes").flat_map do |node_id, node|
          node.fetch("probes").select { |probe| probe["classification"] == "unavailable" }.map do |probe|
            "#{node_id}.#{probe.fetch("id")}: #{probe.fetch("output")}"
          end
        end
        lines.concat(["", "## Unavailable facts", ""])
        if unavailable.empty?
          lines << "- None."
        else
          unavailable.each { |item| lines << "- #{item}" }
        end
        lines.concat([
          "", "## Evidence semantics", "",
          "- `observed`: direct bounded command output.",
          "- `unavailable`: failed, skipped, missing, or permission-limited evidence.",
          "- `user_confirmation`: a true value in the real NC-M3 bootstrap input.",
          "- `inferred`: a readiness conclusion derived from named evidence.",
          "", "All captured command output passed through the collector redactor. No plaintext key or credential file was read, no secret content was emitted, and no provider API was contacted. An existing encrypted SOPS envelope may be read locally only for format validation.",
          ""
        ])
        lines.join("\n")
      end
    end

    class CLI
      def self.run(argv, root: File.expand_path("..", __dir__), runner: CommandRunner.new, stdout: $stdout, stderr: $stderr)
        options = {plan: false}
        parser = OptionParser.new do |current|
          current.banner = "usage: scripts/collect_nc_m3_preflight.rb [--plan]"
          current.on("--plan", "Print the read-only collection plan; contact no nodes and write no bundle") { options[:plan] = true }
          current.on("-h", "--help", "Show this help") do
            stdout.puts current
            return 0
          end
        end
        parser.parse!(argv)
        raise OptionParser::InvalidOption, "unexpected arguments: #{argv.join(' ')}" unless argv.empty?

        inputs = RepositoryInputs.new(root)
        collector = Collector.new(inputs: inputs, runner: runner)
        if options[:plan]
          stdout.puts JSON.pretty_generate(collector.plan)
          return 0
        end

        evidence = collector.collect
        bundle_root = File.join(root, "artifacts/nc-m3-preflight")
        destination = BundleWriter.new(bundle_root).write(evidence)
        stdout.puts "NC-M3 preflight: #{evidence.dig("readiness", "status")}"
        stdout.puts "evidence bundle: #{destination}"
        evidence.dig("readiness", "status") == "READY" ? 0 : 3
      rescue OptionParser::ParseError, ArgumentError, KeyError, Psych::Exception => error
        stderr.puts "preflight error: #{Redactor.call(error.message)}"
        2
      end
    end
  end
end

if $PROGRAM_NAME == __FILE__
  exit NodeControl::NCM3Preflight::CLI.run(ARGV)
end

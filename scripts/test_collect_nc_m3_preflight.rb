#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"
require "minitest/autorun"
require "stringio"
require "tmpdir"
require_relative "collect_nc_m3_preflight"

class NCM3PreflightTest < Minitest::Test
  ROOT = File.expand_path("..", __dir__)
  Preflight = NodeControl::NCM3Preflight

  def test_inventory_resolves_only_canonical_nodes_and_configured_paths
    inputs = Preflight::RepositoryInputs.new(ROOT)
    assert_equal %w[arvan-vps], inputs.aliases("vps-node")
    assert_equal %w[asus asus-remote], inputs.aliases("asus-node")
    assert_equal "vaheedgorgeen", inputs.expected_user("mac-node")
    assert_raises(KeyError) { inputs.node("comp-node") }
  end

  def test_ssh_options_disable_forwarding_and_bound_connections
    options = Preflight::Collector::SSH_OPTIONS
    assert_includes options, "BatchMode=yes"
    assert_includes options, "ClearAllForwardings=yes"
    assert_includes options, "ForwardAgent=no"
    assert_includes options, "PermitLocalCommand=no"
    assert_includes options, "ConnectTimeout=8"
    refute options.any? { |item| item.match?(/LocalForward|RemoteForward|DynamicForward/) }
  end

  def test_probe_catalog_contains_required_categories_and_rejects_mutation_patterns
    catalog = Preflight::ProbeCatalog.new("infra.example.org")
    mac_categories = catalog.local.map(&:category)
    asus_categories = catalog.linux("asus-node").map(&:category)
    %w[os cpu memory gpu disk cgroup podman services sockets vpn dns privilege tools].each do |category|
      assert_includes mac_categories, category
      assert_includes asus_categories, category
    end
    assert_includes asus_categories, "port_owner"
    caddy_probe = catalog.linux("vps-node").find { |probe| probe.id == "caddy_runtime" }
    assert_includes caddy_probe.command, "http://127.0.0.1:2019/config/"
    refute_includes caddy_probe.command, '#{@caddy_admin_port}'

    dangerous = Preflight::Probe.new(
      id: "bad", category: "bad", description: "bad", command: "systemctl restart ssh"
    )
    assert_raises(RuntimeError) { catalog.validate_read_only!([dangerous]) }
    privileged = Preflight::Probe.new(
      id: "bad_sudo", category: "bad", description: "bad", command: "sudo ss -ltnp"
    )
    assert_raises(RuntimeError) { catalog.validate_read_only!([privileged]) }
    mutating_http = Preflight::Probe.new(
      id: "bad_http", category: "bad", description: "bad", command: "curl -X POST https://example.invalid"
    )
    assert_raises(RuntimeError) { catalog.validate_read_only!([mutating_http]) }
  end

  def test_redactor_removes_common_secret_forms
    private_key_label = %w[OPENSSH PRIVATE KEY].join(" ")
    input = <<~TEXT
      password=hunter2
      Authorization: Bearer bearer-value
      postgresql://user:pass@example.org/db
      token=opaque-token
      AGE-SECRET-KEY-1ABCDEF
      -----BEGIN #{private_key_label}-----
      private-material
      -----END #{private_key_label}-----
    TEXT
    output = Preflight::Redactor.call(input)
    refute_includes output, "hunter2"
    refute_includes output, "bearer-value"
    refute_includes output, "user:pass"
    refute_includes output, "opaque-token"
    refute_includes output, "AGE-SECRET-KEY"
    refute_includes output, "private-material"
    assert_includes output, "[REDACTED]"
  end

  def test_plan_mode_contacts_no_nodes_and_writes_no_bundle
    runner = FailingRunner.new
    stdout = StringIO.new
    stderr = StringIO.new
    status = Preflight::CLI.run(["--plan"], root: ROOT, runner: runner, stdout: stdout, stderr: stderr)
    plan = JSON.parse(stdout.string)
    assert_equal 0, status
    assert_equal "OBSERVE", plan.fetch("mode")
    assert_equal %w[mac-node vps-node asus-node], plan.fetch("canonical_nodes")
    assert_equal 0, runner.calls
    assert_empty stderr.string
  end

  def test_authenticated_wrong_host_is_not_selected_for_broader_collection
    inputs = Preflight::RepositoryInputs.new(ROOT)
    runner = StaticRunner.new("hostname=wrong-host\nuser=wade\n")
    collector = Preflight::Collector.new(inputs: inputs, runner: runner)
    attempt = collector.send(:probe_path, "asus-node", "asus")
    assert_equal "observed", attempt.fetch("classification")
    assert_equal "identity-mismatch", attempt.fetch("status")

    runner = StaticRunner.new("hostname=wolfski\nuser=wade\n")
    collector = Preflight::Collector.new(inputs: inputs, runner: runner)
    attempt = collector.send(:probe_path, "asus-node", "asus-remote")
    assert_equal "succeeded", attempt.fetch("status")
  end

  def test_readiness_labels_missing_evidence_as_inferred_blockers
    inputs = Preflight::RepositoryInputs.new(ROOT)
    evidence = {
      "nodes" => %w[mac-node vps-node asus-node].each_with_object({}) do |node_id, nodes|
        nodes[node_id] = {"access" => {"selected_path" => nil}, "probes" => []}
      end
    }
    readiness = Preflight::Readiness.new(inputs, evidence).evaluate
    assert_equal "BLOCKED", readiness.fetch("status")
    assert readiness.fetch("blockers").any? { |item| item.include?("configured platform domain") }
    assert readiness.fetch("blockers").any? { |item| item.include?("no configured access path") }
    assert readiness.fetch("results").all? { |item| item.fetch("classification") == "inferred" }
  end

  def test_caddy_admin_listener_is_expected_when_service_and_admin_are_healthy
    readiness = evaluate_readiness(
      vps_sockets: "tcp LISTEN 0 4096 127.0.0.1:2019 0.0.0.0:*\n",
      vps_services: "system.caddy.service.active=active\n",
      caddy_runtime: caddy_runtime(version: "2.6.2")
    )
    result = readiness.fetch("results").find { |item| item["id"] == "vps-node.port.2019" }
    assert_equal "satisfied", result.fetch("status")
    assert_equal "expected_listener", result.fetch("port_disposition")
  end

  def test_caddy_admin_listener_blocks_when_ownership_is_not_verified
    readiness = evaluate_readiness(
      vps_sockets: "tcp LISTEN 0 4096 127.0.0.1:2019 0.0.0.0:*\n",
      vps_services: "system.caddy.service.active=inactive\n",
      caddy_runtime: caddy_runtime(active: "inactive", main_pid: "0", admin: "200")
    )
    result = readiness.fetch("results").find { |item| item["id"] == "vps-node.port.2019" }
    assert_equal "blocked", result.fetch("status")
    assert_equal "collision", result.fetch("port_disposition")
    assert_includes readiness.fetch("blockers"), "vps-node TCP/2019 is listening without verified active Caddy ownership and admin health"
  end

  def test_caddy_version_drift_is_explicit_warning_not_a_collision
    readiness = evaluate_readiness(
      vps_sockets: "tcp LISTEN 0 4096 127.0.0.1:2019 0.0.0.0:*\n",
      vps_services: "system.caddy.service.active=active\n",
      caddy_runtime: caddy_runtime(version: "2.6.2")
    )
    result = readiness.fetch("results").find { |item| item["id"] == "vps-node.caddy.version" }
    assert_equal "warning", result.fetch("status")
    assert_includes result.fetch("detail"), "2.6.2"
    assert_includes result.fetch("detail"), "2.11.4"
  end

  def test_preservation_failures_block_readiness
    readiness = evaluate_readiness(
      vps_sockets: "tcp LISTEN 0 4096 127.0.0.1:2019 0.0.0.0:*\n",
      vps_services: "system.caddy.service.active=inactive\n",
      caddy_runtime: caddy_runtime(active: "inactive", main_pid: "0", admin: "000"),
      asus_services: <<~TEXT,
        user.tracker.service.active=inactive
        health.tracker.http=000
        system.docker.service.active=inactive
        health.jellyfin.http=000
        system.asus-reverse-tunnel.service.active=inactive
        system.reverse-ssh.service.load=not-found
      TEXT
      asus_sockets: ""
    )
    expected = [
      "VPS Caddy service is not observed active",
      "Tracker user service is not observed active",
      "Docker service is not observed active",
      "Jellyfin TCP/8096 listener is absent",
      "asus reverse-tunnel service is not observed active",
      "legacy reverse-ssh service is not present"
    ]
    expected.each { |blocker| assert_includes readiness.fetch("blockers"), blocker }
  end

  def test_asus_capacity_admission_uses_repository_thresholds
    readiness = evaluate_readiness(
      asus_memory: "Mem: 8205926400 800000000 0 0 0 6442450944\nSwap: 4294967296 0 3758096384\n",
      asus_disk: "/dev/mapper/root 61075263488 20000000000 21474836480 50% /\n"
    )
    %w[memory_available_bytes swap_free_bytes root_free_bytes].each do |name|
      result = readiness.fetch("results").find { |item| item["id"] == "asus-node.capacity.#{name}" }
      assert_equal "satisfied", result.fetch("status")
    end
  end

  def test_asus_package_candidate_drift_blocks_before_install
    readiness = evaluate_readiness(
      asus_runtime: <<~TEXT
        package.podman.candidate=9.9.9-drift
        package.uidmap.candidate=1:4.13+dfsg1-4ubuntu3.2
        package.fuse-overlayfs.candidate=1.13-1
        package.slirp4netns.candidate=1.2.1-1build2
      TEXT
    )
    blocker = "asus-node package podman candidate 9.9.9-drift differs from lock 4.9.3+ds1-1ubuntu0.2"
    assert_includes readiness.fetch("blockers"), blocker
  end

  def test_remote_probe_parser_classifies_failures_and_redacts_output
    inputs = Preflight::RepositoryInputs.new(ROOT)
    collector = Preflight::Collector.new(inputs: inputs, runner: FailingRunner.new)
    probes = [
      Preflight::Probe.new(id: "ok", category: "fixture", description: "ok", command: "true"),
      Preflight::Probe.new(id: "denied", category: "fixture", description: "denied", command: "false")
    ]
    stdout = <<~TEXT
      #{Preflight::Collector::BEGIN_MARKER} ok
      token=do-not-store
      #{Preflight::Collector::END_MARKER} ok 0
      #{Preflight::Collector::BEGIN_MARKER} denied
      permission denied
      #{Preflight::Collector::END_MARKER} denied 1
    TEXT
    result = Preflight::CommandResult.new(
      stdout: stdout, stderr: "", exit_code: 0, timed_out: false, duration_ms: 1
    )
    records = collector.send(:parse_remote_records, probes, result)
    assert_equal "observed", records.fetch(0).fetch("classification")
    assert_includes records.fetch(0).fetch("output"), "[REDACTED]"
    refute_includes records.fetch(0).fetch("output"), "do-not-store"
    assert_equal "unavailable", records.fetch(1).fetch("classification")
    assert_equal "failed", records.fetch(1).fetch("status")
  end

  def test_bundle_is_private_structured_and_checksummed
    tmp_root = File.join(ROOT, "tmp")
    FileUtils.mkdir_p(tmp_root)
    Dir.mktmpdir("nc-m3-preflight-test", tmp_root) do |directory|
      evidence = sample_evidence
      destination = Preflight::BundleWriter.new(directory).write(evidence)
      assert File.file?(File.join(destination, "evidence.json"))
      assert File.file?(File.join(destination, "REPORT.md"))
      assert File.file?(File.join(destination, "MANIFEST.sha256"))
      assert_equal 0o700, File.stat(destination).mode & 0o777
      assert_equal 0o600, File.stat(File.join(destination, "evidence.json")).mode & 0o777
      parsed = JSON.parse(File.read(File.join(destination, "evidence.json")))
      assert_equal "BLOCKED", parsed.dig("readiness", "status")
      manifest = File.read(File.join(destination, "MANIFEST.sha256"))
      assert_includes manifest, "evidence.json"
      assert_includes manifest, "REPORT.md"
      report = File.read(File.join(destination, "REPORT.md"))
      assert_includes report, "## Port disposition"
      assert_includes report, "`free_candidate`"
    end
  end

  private

  class FailingRunner
    attr_reader :calls

    def initialize
      @calls = 0
    end

    def run(*)
      @calls += 1
      raise "runner must not be called in plan mode"
    end
  end

  class StaticRunner
    def initialize(stdout)
      @stdout = stdout
    end

    def run(*)
      Preflight::CommandResult.new(
        stdout: @stdout, stderr: "", exit_code: 0, timed_out: false, duration_ms: 1
      )
    end
  end

  def evaluate_readiness(
    vps_sockets: "", vps_services: "", caddy_runtime: "", asus_services: "",
    asus_sockets: "", asus_memory: "", asus_disk: "", asus_runtime: ""
  )
    nodes = %w[mac-node vps-node asus-node].each_with_object({}) do |node_id, result|
      result[node_id] = {"access" => {"selected_path" => nil}, "probes" => []}
    end
    nodes["vps-node"]["probes"] = [
      observed_probe("sockets", vps_sockets),
      observed_probe("services", vps_services),
      observed_probe("caddy_runtime", caddy_runtime)
    ]
    nodes["asus-node"]["probes"] = [
      observed_probe("sockets", asus_sockets),
      observed_probe("services", asus_services),
      observed_probe("memory_swap", asus_memory),
      observed_probe("disk", asus_disk),
      observed_probe("runtime", asus_runtime),
      observed_probe("port_42665", asus_sockets)
    ]
    Preflight::Readiness.new(Preflight::RepositoryInputs.new(ROOT), {"nodes" => nodes}).evaluate
  end

  def observed_probe(id, output)
    {
      "id" => id,
      "classification" => "observed",
      "status" => "succeeded",
      "output" => output,
      "category" => "fixture",
      "description" => "fixture"
    }
  end

  def caddy_runtime(active: "active", main_pid: "123", admin: "200", version: "2.11.4")
    <<~TEXT
      service.active=#{active}
      service.main_pid=#{main_pid}
      admin.http=#{admin}
      binary.version=#{version}
      package.version=2.6.2-14
    TEXT
  end

  def sample_evidence
    nodes = %w[mac-node vps-node asus-node].each_with_object({}) do |node_id, result|
      result[node_id] = {
        "access" => {"selected_path" => node_id == "mac-node" ? "local" : "test"},
        "probes" => [{
          "id" => "identity", "classification" => "observed", "status" => "succeeded",
          "output" => "hostname=test", "category" => "identity", "description" => "fixture"
        }]
      }
    end
    {
      "metadata" => {"collected_at" => "2026-08-23T00:00:00Z"},
      "nodes" => nodes,
      "user_confirmations" => [],
      "readiness" => {
        "status" => "BLOCKED",
        "blockers" => ["fixture blocker"],
        "warnings" => [],
        "results" => [{
          "id" => "vps-node.port.17000",
          "classification" => "inferred",
          "status" => "satisfied",
          "detail" => "fixture port is free",
          "evidence_refs" => ["vps-node.sockets"],
          "port_disposition" => "free_candidate"
        }]
      }
    }
  end
end

#!/usr/bin/env ruby
# frozen_string_literal: true

require "minitest/autorun"
require "tmpdir"
require "yaml"
require_relative "lib/nc_m3_config"
require_relative "lib/nc_m3_renderer"

class NCM3ConfigTest < Minitest::Test
  ROOT = File.expand_path("..", __dir__)

  def test_current_configuration_reports_only_real_blockers
    configuration = NodeControl::NCM3Config.new(
      bootstrap_path: File.join(ROOT, "config/nc-m3/bootstrap.yml"),
      artifacts_path: File.join(ROOT, "config/nc-m3/artifacts.yml"),
      ports_path: File.join(ROOT, "config/nc-m3/ports.yml"),
      nats_config_path: File.join(ROOT, "config/nc-m3/nats/server.conf"),
      encrypted_secrets_path: File.join(ROOT, "secrets/nc-m3.enc.yml")
    )
    assert_equal [
      "image controller_agent_cli lacks an immutable digest",
      "image langgraph lacks an immutable digest",
      "missing config/nc-m3/bootstrap.yml",
      "missing config/nc-m3/nats/server.conf",
      "missing secrets/nc-m3.enc.yml"
    ], configuration.blockers
  end

  def test_ready_fixture_derives_hosts_ports_and_immutable_references
    Dir.mktmpdir("nc-m3-config") do |directory|
      bootstrap_path = File.join(directory, "bootstrap.yml")
      artifacts_path = File.join(directory, "artifacts.yml")
      ports_path = File.join(directory, "ports.yml")
      nats_config_path = File.join(directory, "server.conf")
      encrypted_secrets_path = File.join(directory, "nc-m3.enc.yml")
      File.write(bootstrap_path, YAML.dump(valid_bootstrap))

      artifacts = YAML.safe_load(File.read(File.join(ROOT, "config/nc-m3/artifacts.yml")), aliases: false)
      artifacts.fetch("spec").fetch("repository_images").fetch("controller_agent_cli")["digest"] = "sha256:#{'a' * 64}"
      artifacts.fetch("spec").fetch("repository_images").fetch("langgraph")["digest"] = "sha256:#{'b' * 64}"
      File.write(artifacts_path, YAML.dump(artifacts))
      File.write(ports_path, File.read(File.join(ROOT, "config/nc-m3/ports.yml")))
      File.write(nats_config_path, "operator: eyJtest\nsystem_account: ATESTACCOUNT\nresolver {\n  type: full\n}\n")
      File.write(encrypted_secrets_path, "value: ENC[AES256_GCM,data:test]\nsops:\n  version: 3.10.2\n")

      configuration = NodeControl::NCM3Config.new(
        bootstrap_path: bootstrap_path,
        artifacts_path: artifacts_path,
        ports_path: ports_path,
        nats_config_path: nats_config_path,
        encrypted_secrets_path: encrypted_secrets_path
      )
      assert_empty configuration.blockers
      assert configuration.ready?
      assert_equal "control.infra.example.org", configuration.endpoint("control")
      assert_equal 18100, configuration.port("asus-node", "loopback_tcp", "controller")
      assert_equal "localhost/node-control-go@sha256:#{'a' * 64}", configuration.image_reference("controller_agent_cli")
      assert_match(/postgres@sha256:[0-9a-f]{64}\z/, configuration.image_reference("postgres"))

      output = File.join(directory, "rendered")
      renderer = NodeControl::NCM3Renderer.new(
        configuration: configuration,
        templates_dir: File.join(ROOT, "deploy/nc-m3/templates"),
        nats_config_path: nats_config_path
      )
      renderer.render(output)
      assert File.file?(File.join(output, "MANIFEST.sha256"))
      assert File.file?(File.join(output, "vps/Caddyfile"))
      assert File.file?(File.join(output, "asus/quadlet/nc-controller.container"))
      caddyfile = File.read(File.join(output, "vps/Caddyfile"))
      assert_includes caddyfile, "control.infra.example.org"
      refute_includes caddyfile, "unresolved"
      manifest = File.read(File.join(output, "MANIFEST.sha256"))
      assert_includes manifest, "asus/quadlet/nc-controller.container"
    end
  end

  private

  def valid_bootstrap
    {
      "api_version" => "nodecontrol.io/v1alpha1",
      "kind" => "NC-M3Bootstrap",
      "metadata" => {"name" => "primary"},
      "spec" => {
        "placement_profile" => "split-edge",
        "base_domain" => "infra.example.org",
        "operator" => "vahid",
        "age_recipients" => ["age1#{'q' * 40}"],
        "preconditions" => {
          "wildcard_dns_control" => true,
          "vps_provider_console_recovery" => true,
          "vps_firewall_control" => true,
          "asus_interactive_sudo" => true,
          "age_offline_recovery_copy" => true,
          "asus_42665_owner_resolved" => true,
          "nats_credentials_generated" => true
        },
        "records" => {
          "dns_evidence" => "test fixture",
          "recovery_evidence" => "test fixture",
          "secret_custody_evidence" => "test fixture",
          "nats_evidence" => "test fixture"
        }
      }
    }
  end
end

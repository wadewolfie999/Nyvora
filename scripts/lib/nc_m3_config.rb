# frozen_string_literal: true

require "ipaddr"
require "yaml"

module NodeControl
  class NCM3Config
    attr_reader :bootstrap, :artifacts, :ports

    def initialize(bootstrap_path:, artifacts_path:, ports_path:, nats_config_path:, encrypted_secrets_path:)
      @bootstrap_path = bootstrap_path
      @artifacts_path = artifacts_path
      @ports_path = ports_path
      @nats_config_path = nats_config_path
      @encrypted_secrets_path = encrypted_secrets_path
      @bootstrap = load_yaml(bootstrap_path) if File.file?(bootstrap_path)
      @artifacts = load_yaml(artifacts_path)
      @ports = load_yaml(ports_path)
    end

    def blockers
      findings = []
      if bootstrap.nil?
        findings << "missing config/nc-m3/bootstrap.yml"
      else
        validate_bootstrap(findings)
      end
      validate_artifacts(findings)
      validate_ports(findings)
      validate_nats_config(findings)
      validate_encrypted_secrets(findings)
      findings.sort
    end

    def ready?
      blockers.empty?
    end

    def spec
      bootstrap.fetch("spec")
    end

    def base_domain
      spec.fetch("base_domain").downcase
    end

    def endpoint(label)
      "#{label}.#{base_domain}"
    end

    def port(node, visibility, name)
      ports.fetch("spec").fetch(node).fetch(visibility).fetch(name)
    end

    def image_reference(name)
      groups = artifacts.fetch("spec")
      artifact = groups.fetch("external_images").merge(groups.fetch("repository_images")).fetch(name)
      candidate = artifact.fetch("candidate")
      tag_separator = candidate.rindex(":")
      slash = candidate.rindex("/") || -1
      repository = tag_separator && tag_separator > slash ? candidate[0...tag_separator] : candidate
      "#{repository}@#{artifact.fetch("digest")}"
    end

    def native_artifact(name)
      artifacts.fetch("spec").fetch("native_artifacts").fetch(name)
    end

    private

    def load_yaml(path)
      YAML.safe_load(File.read(path), aliases: false)
    end

    def validate_bootstrap(findings)
      current = bootstrap.fetch("spec", {})
      findings << "placement_profile is not split-edge" unless current["placement_profile"] == "split-edge"
      findings << "operator is not vahid" unless current["operator"] == "vahid"

      domain = current["base_domain"].to_s.downcase
      valid_domain = domain.match?(/\A(?=.{4,253}\z)(?:[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z]{2,63}\z/)
      begin
        IPAddr.new(domain)
        valid_domain = false
      rescue IPAddr::InvalidAddressError
        nil
      end
      valid_domain = false if domain.end_with?(".invalid", ".example", ".test", ".localhost")
      findings << "base_domain is not a controlled routable domain" unless valid_domain

      recipients = current.fetch("age_recipients", [])
      valid_recipients = recipients.is_a?(Array) && !recipients.empty? &&
        recipients.all? { |recipient| recipient.match?(/\Aage1[0-9a-z]{20,}\z/) }
      findings << "public age recipient set is absent or malformed" unless valid_recipients

      preconditions = current.fetch("preconditions", {})
      %w[
        wildcard_dns_control vps_provider_console_recovery vps_firewall_control
        asus_interactive_sudo age_offline_recovery_copy asus_42665_owner_resolved
        nats_credentials_generated
      ].each do |name|
        findings << "precondition #{name} is not recorded true" unless preconditions[name] == true
      end

      records = current.fetch("records", {})
      %w[dns_evidence recovery_evidence secret_custody_evidence nats_evidence].each do |name|
        value = records[name].to_s.strip
        findings << "record #{name} is absent" if value.empty? || value == "pending"
      end
    end

    def validate_artifacts(findings)
      current = artifacts.fetch("spec")
      current.fetch("native_artifacts").each do |name, artifact|
        findings << "native artifact #{name} lacks a SHA-256" unless artifact.fetch("sha256", "").match?(/\A[0-9a-f]{64}\z/)
      end
      current.fetch("external_images").each do |name, artifact|
        findings << "image #{name} lacks an immutable digest" unless immutable_digest?(artifact)
        platforms = artifact.fetch("platforms_verified", [])
        findings << "image #{name} lacks verified linux/amd64" unless platforms.include?("linux/amd64")
      end
      current.fetch("repository_images").each do |name, artifact|
        findings << "image #{name} lacks an immutable digest" unless immutable_digest?(artifact)
      end
    end

    def immutable_digest?(artifact)
      artifact.fetch("candidate", "").match?(/\A[a-z0-9][a-z0-9._:\/-]+\z/) &&
        artifact.fetch("digest", "").match?(/\Asha256:[0-9a-f]{64}\z/)
    end

    def validate_ports(findings)
      current = ports.fetch("spec")
      unless current.dig("vps-node", "public_tcp").values.sort == [22, 80, 443]
        findings << "VPS public TCP allocation drifted"
      end
      findings << "asus public TCP allocation is non-empty" unless current.dig("asus-node", "public_tcp") == {}

      asus_allocated = current.dig("asus-node", "loopback_tcp").values
      asus_protected = current.dig("asus-node", "protected_existing_tcp").values
      findings << "asus allocation overlaps protected listeners" unless (asus_allocated & asus_protected).empty?

      vps_allocated = current.dig("vps-node", "loopback_tcp").values
      vps_protected = current.dig("vps-node", "protected_existing_tcp").values
      findings << "VPS allocation overlaps protected listeners" unless (vps_allocated & vps_protected).empty?
    end

    def validate_nats_config(findings)
      unless File.file?(@nats_config_path)
        findings << "missing config/nc-m3/nats/server.conf"
        return
      end
      content = File.read(@nats_config_path)
      findings << "NATS server config lacks operator JWT" unless content.match?(/^operator:\s+eyJ/m)
      findings << "NATS server config lacks system account" unless content.match?(/^system_account:\s+A[A-Z0-9]+/m)
      findings << "NATS server config lacks full resolver" unless content.include?("type: full")
      if content.include?("BEGIN USER NKEY SEED") || content.match?(/^\s*S[UOAC][A-Z0-9]{40,}\s*$/)
        findings << "NATS server config contains private seed material"
      end
    end

    def validate_encrypted_secrets(findings)
      unless File.file?(@encrypted_secrets_path)
        findings << "missing secrets/nc-m3.enc.yml"
        return
      end
      content = File.read(@encrypted_secrets_path)
      unless content.include?("ENC[AES256_GCM") && content.match?(/^sops:\s*$/)
        findings << "NC-M3 secrets file is not SOPS-encrypted"
      end
    end
  end
end

#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative "lib/nc_m3_config"

ROOT = File.expand_path("..", __dir__)
BOOTSTRAP = ARGV.fetch(0, File.join(ROOT, "config/nc-m3/bootstrap.yml"))
ARTIFACTS = File.join(ROOT, "config/nc-m3/artifacts.yml")
PORTS = File.join(ROOT, "config/nc-m3/ports.yml")
NATS_CONFIG = File.join(ROOT, "config/nc-m3/nats/server.conf")
ENCRYPTED_SECRETS = File.join(ROOT, "secrets/nc-m3.enc.yml")

configuration = NodeControl::NCM3Config.new(
  bootstrap_path: BOOTSTRAP,
  artifacts_path: ARTIFACTS,
  ports_path: PORTS,
  nats_config_path: NATS_CONFIG,
  encrypted_secrets_path: ENCRYPTED_SECRETS
)
blockers = configuration.blockers

if blockers.empty?
  puts "NC-M3 readiness: READY"
  exit 0
end

puts "NC-M3 readiness: BLOCKED"
blockers.sort.each { |blocker| puts "- #{blocker}" }
exit 3

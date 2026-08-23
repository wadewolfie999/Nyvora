#!/usr/bin/env ruby
# frozen_string_literal: true

require "optparse"
require_relative "lib/nc_m3_config"
require_relative "lib/nc_m3_renderer"

root = File.expand_path("..", __dir__)
options = {
  bootstrap: File.join(root, "config/nc-m3/bootstrap.yml"),
  artifacts: File.join(root, "config/nc-m3/artifacts.yml"),
  ports: File.join(root, "config/nc-m3/ports.yml"),
  nats_config: File.join(root, "config/nc-m3/nats/server.conf"),
  encrypted_secrets: File.join(root, "secrets/nc-m3.enc.yml")
}

OptionParser.new do |parser|
  parser.banner = "usage: scripts/render_nc_m3.rb --output DIR [options]"
  parser.on("--output DIR") { |value| options[:output] = File.expand_path(value) }
  parser.on("--bootstrap FILE") { |value| options[:bootstrap] = File.expand_path(value) }
  parser.on("--artifacts FILE") { |value| options[:artifacts] = File.expand_path(value) }
  parser.on("--ports FILE") { |value| options[:ports] = File.expand_path(value) }
  parser.on("--nats-config FILE") { |value| options[:nats_config] = File.expand_path(value) }
  parser.on("--encrypted-secrets FILE") { |value| options[:encrypted_secrets] = File.expand_path(value) }
end.parse!

abort "--output is required" unless options[:output]

configuration = NodeControl::NCM3Config.new(
  bootstrap_path: options.fetch(:bootstrap),
  artifacts_path: options.fetch(:artifacts),
  ports_path: options.fetch(:ports),
  nats_config_path: options.fetch(:nats_config),
  encrypted_secrets_path: options.fetch(:encrypted_secrets)
)
renderer = NodeControl::NCM3Renderer.new(
  configuration: configuration,
  templates_dir: File.join(root, "deploy/nc-m3/templates"),
  nats_config_path: options.fetch(:nats_config)
)
renderer.render(options.fetch(:output))
puts "NC-M3 render: PASS (#{options.fetch(:output)})"

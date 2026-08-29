#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"
require "yaml"

ROOT = File.expand_path("..", __dir__)

def fail_check(message)
  warn "validation error: #{message}"
  exit 1
end

required = %w[
  AGENTS.md INDEX.md PLANS.md ROADMAP.md DECISIONS.md
  docs/architecture.md docs/baseline.md
  inventory/nodes.yml policies/change-contract.md interface/CLI.md
  runbooks/collect-nc-m3-preflight.md scripts/collect_nc_m3_preflight.rb
  scripts/test_collect_nc_m3_preflight.rb
  config/nc-m3/capacity.yml
  config/placement-profiles/mac-authority.yml
  config/placement-profiles/vps-core.yml
  config/placement-profiles/split-edge.yml
  schemas/node-inventory.schema.json
  schemas/placement-profile.schema.json
  schemas/nc-m3-bootstrap.schema.json
  schemas/operation.schema.json schemas/agent-task.schema.json
]
required.each do |relative|
  fail_check("missing #{relative}") unless File.file?(File.join(ROOT, relative))
end

Dir.glob(File.join(ROOT, "schemas", "*.json")).sort.each do |path|
  JSON.parse(File.read(path))
end

inventory = YAML.safe_load(File.read(File.join(ROOT, "inventory/nodes.yml")), aliases: false)
nodes = inventory.dig("spec", "canonical_nodes") || {}
expected_nodes = %w[asus-node mac-node vps-node]
fail_check("canonical node set is #{nodes.keys.sort.inspect}") unless nodes.keys.sort == expected_nodes

legacy = inventory.dig("spec", "legacy_identifiers", "comp-node")
fail_check("retired node mapping is missing") unless legacy
fail_check("retired node remains targetable") unless legacy["accepted_as_target"] == false
fail_check("retired node replacement is not asus-node") unless legacy["replacement"] == "asus-node"

profiles = Dir.glob(File.join(ROOT, "config/placement-profiles/*.yml")).sort.map do |path|
  YAML.safe_load(File.read(path), aliases: false)
end
profile_names = profiles.map { |profile| profile.dig("metadata", "name") }.sort
fail_check("placement profiles are #{profile_names.inspect}") unless profile_names == %w[mac-authority split-edge vps-core]

approved = profiles.find { |profile| profile.dig("metadata", "name") == "mac-authority" }
fail_check("approved mac-authority profile is not marked approved") unless approved.dig("metadata", "approved") == true
fail_check("approved profile does not place controller on mac-node") unless approved.dig("spec", "fixed_services", "mac-node").include?("controller")
fail_check("approved profile does not place PostgreSQL on asus-node") unless approved.dig("spec", "fixed_services", "asus-node").include?("postgres")
fail_check("approved profile does not place NATS on asus-node") unless approved.dig("spec", "fixed_services", "asus-node").include?("nats")
fail_check("approved profile does not include vps-node agent") unless approved.dig("spec", "fixed_services", "vps-node").include?("node-agent")

profiles.each do |profile|
  if %w[split-edge vps-core].include?(profile.dig("metadata", "name"))
    fail_check("historical profile is not marked historical") unless profile.dig("metadata", "historical") == true
  end
  ports = profile.dig("spec", "public_tcp_ports") || {}
  fail_check("VPS public ports drifted") unless ports["vps-node"] == [22, 80, 443]
  fail_check("asus has public ports") unless ports["asus-node"] == []
end

ports = YAML.safe_load(File.read(File.join(ROOT, "config/nc-m3/ports.yml")), aliases: false).fetch("spec")
fail_check("VPS NC-M3 public ports drifted") unless ports.dig("vps-node", "public_tcp").values.sort == [22, 80, 443]
fail_check("asus NC-M3 public ports are non-empty") unless ports.dig("asus-node", "public_tcp") == {}
asus_allocated = ports.dig("asus-node", "loopback_tcp").values
asus_protected = ports.dig("asus-node", "protected_existing_tcp").values
fail_check("asus NC-M3 ports overlap protected listeners") unless (asus_allocated & asus_protected).empty?
caddy_admin = ports.dig("vps-node", "expected_owned_tcp", "caddy_admin") || {}
fail_check("VPS Caddy admin ownership contract drifted") unless
  caddy_admin == {"port" => 2019, "service" => "caddy.service", "health" => "caddy_admin_http_2xx"}

capacity = YAML.safe_load(File.read(File.join(ROOT, "config/nc-m3/capacity.yml")), aliases: false)
minimum = capacity.dig("spec", "asus-node", "minimum") || {}
expected_minimum = {
  "memory_available_bytes" => 6 * 1024**3,
  "swap_free_bytes" => (3.5 * 1024**3).to_i,
  "root_free_bytes" => 20 * 1024**3
}
fail_check("asus NC-M3 capacity admission drifted") unless minimum == expected_minimum
declared_limit = capacity.dig("spec", "asus-node", "rendered_core_limits", "memory_mebibytes")
rendered_limit = Dir.glob(File.join(ROOT, "deploy/nc-m3/templates/asus/quadlet/*.container.erb")).sum do |path|
  match = File.read(path).match(/^Memory=(\d+)m$/)
  match ? match[1].to_i : 0
end
fail_check("asus rendered memory limit total drifted") unless rendered_limit == declared_limit

skill_dirs = Dir.glob(File.join(ROOT, ".agents/skills/node-control-*"), File::FNM_DOTMATCH).sort
fail_check("expected four repository skills") unless skill_dirs.length == 4

skill_dirs.each do |dir|
  skill_file = File.join(dir, "SKILL.md")
  ui_file = File.join(dir, "agents/openai.yaml")
  fail_check("missing #{skill_file.delete_prefix(ROOT + "/")}") unless File.file?(skill_file)
  fail_check("missing #{ui_file.delete_prefix(ROOT + "/")}") unless File.file?(ui_file)

  content = File.read(skill_file)
  match = content.match(/\A---\n(.*?)\n---/m)
  fail_check("invalid skill frontmatter in #{File.basename(dir)}") unless match
  frontmatter = YAML.safe_load(match[1], aliases: false)
  expected_name = File.basename(dir)
  fail_check("skill name mismatch in #{expected_name}") unless frontmatter["name"] == expected_name
  fail_check("missing skill description in #{expected_name}") unless frontmatter["description"].is_a?(String) && !frontmatter["description"].empty?
  fail_check("unexpected skill frontmatter in #{expected_name}") unless (frontmatter.keys - %w[name description license allowed-tools metadata]).empty?
  fail_check("unfinished skill placeholder in #{expected_name}") if content.include?("[TODO:")

  ui = YAML.safe_load(File.read(ui_file), aliases: false)
  interface = ui["interface"] || {}
  %w[display_name short_description default_prompt].each do |field|
    fail_check("missing #{field} in #{expected_name}") unless interface[field].is_a?(String) && !interface[field].empty?
  end
  length = interface["short_description"].length
  fail_check("short_description length invalid in #{expected_name}") unless length.between?(25, 64)
  fail_check("default_prompt does not invoke $#{expected_name}") unless interface["default_prompt"].include?("$#{expected_name}")
end

forbidden_patterns = [
  /BEGIN (RSA|OPENSSH|EC) PRIVATE KEY/,
  /^\s*["']?password["']?\s*:\s*[^<\s][^\n]*/i,
  /^\s*["']?token["']?\s*:\s*[^<\s][^\n]*/i
]

Dir.glob(File.join(ROOT, "**", "*"), File::FNM_DOTMATCH).sort.each do |path|
  next unless File.file?(path)
  next if path.include?("/.git/")
  next if path.include?("/__pycache__/")
  next if path == __FILE__
  content = File.binread(path).force_encoding(Encoding::UTF_8)
  next unless content.valid_encoding?
  forbidden_patterns.each do |pattern|
    fail_check("possible plaintext secret in #{path.delete_prefix(ROOT + "/")}") if content.match?(pattern)
  end
end

puts "node-control repository validation: PASS"

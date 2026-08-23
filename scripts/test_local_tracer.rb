#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"
require "net/http"
require "open3"
require "securerandom"
require "time"
require "uri"
require "yaml"

profile = ARGV.fetch(0)
repo_dir = File.expand_path("..", __dir__)
profile_data = YAML.safe_load(File.read(File.join(repo_dir, "config/placement-profiles", "#{profile}.yml")))
core_matches = profile_data.fetch("spec").fetch("fixed_services").select do |_node, services|
  %w[controller postgres nats langgraph].all? { |service| services.include?(service) }
end
raise "profile must assign one complete control core" unless core_matches.length == 1

expected_core = core_matches.keys.first
controller = URI("http://127.0.0.1:18080")
workflow = URI("http://127.0.0.1:18081")

def request_json(base, method, path, payload = nil)
  uri = base + path
  request_class = { get: Net::HTTP::Get, post: Net::HTTP::Post }.fetch(method)
  request = request_class.new(uri)
  if payload
    request["Content-Type"] = "application/json"
    request.body = JSON.generate(payload)
  end
  http = Net::HTTP.new(uri.host, uri.port, nil, nil)
  http.open_timeout = 2
  http.read_timeout = 20
  response = http.request(request)
  body = response.body.to_s.empty? ? {} : JSON.parse(response.body)
  [response.code.to_i, body]
end

def assert(condition, message)
  raise message unless condition
end

def wait_until(timeout: 30)
  deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + timeout
  loop do
    value = yield
    return value if value
    raise "timed out waiting for condition" if Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline

    sleep 0.25
  end
end

def plan(base, node, key)
  code, operation = request_json(base, :post, "/api/v1alpha1/operations/plan", {
    target: node, action: "observe", idempotency_key: key
  })
  assert(code == 200, "plan failed: #{code} #{operation}")
  operation
end

def apply_and_wait(base, operation)
  code, body = request_json(base, :post, "/api/v1alpha1/operations/#{operation.fetch("id")}/apply")
  assert(code == 200, "apply failed: #{code} #{body}")
  wait_until do
    code, current = request_json(base, :get, "/api/v1alpha1/operations/#{operation.fetch("id")}")
    assert(code == 200, "get operation failed: #{code} #{current}")
    current if %w[verified failed].include?(current["state"])
  end
end

def podman(*args)
  stdout, stderr, status = Open3.capture3("podman", *args)
  raise "podman #{args.join(' ')} failed: #{stderr}" unless status.success?

  stdout.strip
end

code, health = request_json(controller, :get, "/api/v1alpha1/healthz")
assert(code == 200 && health["status"] == "ok" && health["runtime"] == "tracer", "controller health failed")
code, workflow_health = request_json(workflow, :get, "/healthz")
assert(
  code == 200 && workflow_health["checkpoint"] == "sqlite" && workflow_health["runtime"] == "tracer",
  "LangGraph health failed"
)

nodes = wait_until do
  code, body = request_json(controller, :get, "/api/v1alpha1/nodes")
  next unless code == 200

  ids = (body["items"] || []).map { |node| node.fetch("node_id") }.sort
  body if ids == %w[asus-node mac-node vps-node]
end
nodes.fetch("items").each do |node|
  assert(node.dig("capabilities", "simulated") == true, "tracer node was not marked simulated: #{node}")
  assert(node.dig("capabilities", "host_observation") == false, "tracer claimed live host observation: #{node}")
  assert(node.dig("facts", "source") == "node-agent-local-observation", "node facts source missing: #{node}")
  assert(node.dig("facts", "node_id") == node.fetch("node_id"), "node facts target mismatch: #{node}")
end

core_containers = %w[nc-m2-postgres nc-m2-nats nc-m2-controller nc-m2-langgraph]
labels = core_containers.to_h do |name|
  output = podman("inspect", "--format", "{{ index .Config.Labels \"io.nodecontrol.profile\" }}|{{ index .Config.Labels \"io.nodecontrol.simulated-node\" }}", name)
  [name, output]
end
assert(labels.values.all? { |value| value == "#{profile}|#{expected_core}" }, "placement labels mismatch: #{labels}")

verified = %w[mac-node vps-node asus-node].to_h do |node|
  key = "#{profile}-#{node}-#{SecureRandom.hex(8)}"
  operation = plan(controller, node, key)
  duplicate = plan(controller, node, key)
  assert(operation["id"] == duplicate["id"], "idempotency did not return the original operation")
  result = apply_and_wait(controller, operation)
  assert(result["state"] == "verified", "#{node} operation failed: #{result}")
  assert(result.dig("result", "evidence", "simulated") == true, "tracer result was not marked simulated")
  [node, result.fetch("id")]
end

shared_key = "#{profile}-conflict-#{SecureRandom.hex(8)}"
plan(controller, "mac-node", shared_key)
code, = request_json(controller, :post, "/api/v1alpha1/operations/plan", {
  target: "vps-node", action: "observe", idempotency_key: shared_key
})
assert(code == 409, "idempotency semantic conflict did not fail with 409")

code, = request_json(controller, :post, "/api/v1alpha1/operations/plan", {
  target: "comp-node", action: "observe", idempotency_key: "#{profile}-retired-node"
})
assert(code == 400, "retired comp-node target did not fail closed")
code, = request_json(controller, :post, "/api/v1alpha1/operations/plan", {
  target: "asus-node", action: "deploy", idempotency_key: "#{profile}-mutation"
})
assert(code == 400, "mutation outside NC-M2 did not fail closed")

podman("stop", "nc-m2-agent-asus-node")
offline_operation = plan(controller, "asus-node", "#{profile}-offline-#{SecureRandom.hex(8)}")
code, leased = request_json(controller, :post, "/api/v1alpha1/operations/#{offline_operation.fetch("id")}/apply")
assert(code == 200 && leased["state"] == "leased", "offline operation was not retained for replay")
sleep 1
code, still_leased = request_json(controller, :get, "/api/v1alpha1/operations/#{offline_operation.fetch("id")}")
assert(code == 200 && still_leased["state"] == "leased", "offline operation changed without an agent")
podman("start", "nc-m2-agent-asus-node")
replayed = wait_until do
  code, current = request_json(controller, :get, "/api/v1alpha1/operations/#{offline_operation.fetch("id")}")
  current if code == 200 && %w[verified failed].include?(current["state"])
end
assert(replayed["state"] == "verified", "durable replay failed: #{replayed}")

persisted_id = verified.fetch("mac-node")
podman("restart", "nc-m2-controller")
wait_until do
  code, body = request_json(controller, :get, "/api/v1alpha1/healthz") rescue [0, {}]
  code == 200 && body["status"] == "ok"
end
code, persisted = request_json(controller, :get, "/api/v1alpha1/operations/#{persisted_id}")
assert(code == 200 && persisted["state"] == "verified", "operation did not survive controller restart")
code, persisted_nodes = request_json(controller, :get, "/api/v1alpha1/nodes")
assert(code == 200 && persisted_nodes.fetch("items").length == 3, "node observations did not survive restart")

workflow_key = "#{profile}-langgraph-#{SecureRandom.hex(8)}"
code, workflow_operation = request_json(workflow, :post, "/dispatch", {
  target: "vps-node", idempotency_key: workflow_key
})
assert(code == 200 && workflow_operation["state"] == "verified", "LangGraph dispatch failed: #{workflow_operation}")
code, workflow_duplicate = request_json(workflow, :post, "/dispatch", {
  target: "vps-node", idempotency_key: workflow_key
})
assert(code == 200 && workflow_duplicate["id"] == workflow_operation["id"], "LangGraph idempotency failed")

puts JSON.pretty_generate({
  status: "PASS",
  profile: profile,
  simulated_core_node: expected_core,
  node_count: nodes.fetch("items").length,
  verified_operations: verified,
  offline_replay_operation: replayed.fetch("id"),
  controller_restart_operation: persisted.fetch("id"),
  langgraph_operation: workflow_operation.fetch("id"),
  langgraph_version: workflow_health.fetch("langgraph_version")
})

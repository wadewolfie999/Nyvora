#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
action=${1:-}
profile=${2:-split-edge}
controller_port=${NC_TRACER_CONTROLLER_PORT:-18080}
workflow_port=${NC_TRACER_WORKFLOW_PORT:-18081}

for port in "$controller_port" "$workflow_port"; do
  if [[ ! "$port" =~ ^[0-9]+$ ]] || (( port < 1024 || port > 65535 )); then
    echo "invalid tracer loopback port: $port" >&2
    exit 2
  fi
done
if [[ "$controller_port" == "$workflow_port" ]]; then
  echo "tracer controller and workflow ports must differ" >&2
  exit 2
fi

case "$profile" in
  split-edge|vps-core) ;;
  *) echo "unsupported placement profile: $profile" >&2; exit 2 ;;
esac
profile_file="$repo_dir/config/placement-profiles/$profile.yml"
core_node=$(ruby -ryaml -e '
  profile = YAML.safe_load(File.read(ARGV.fetch(0)))
  matches = profile.fetch("spec").fetch("fixed_services").select do |_node, services|
    %w[controller postgres nats langgraph].all? { |service| services.include?(service) }
  end
  abort "profile must assign one complete control core" unless matches.length == 1
  puts matches.keys.first
' "$profile_file")

network=nc-m2-network
go_image=localhost/node-control-go:nc-m2
workflow_image=localhost/node-control-langgraph:nc-m2
containers=(
  nc-m2-langgraph
  nc-m2-agent-mac-node
  nc-m2-agent-vps-node
  nc-m2-agent-asus-node
  nc-m2-controller
  nc-m2-nats
  nc-m2-postgres
)

usage() {
  echo "usage: scripts/local_tracer.sh up|down|status [split-edge|vps-core]" >&2
}

remove_containers() {
  local name
  for name in "${containers[@]}"; do
    if podman container exists "$name"; then
      podman rm --force "$name" >/dev/null
    fi
  done
}

ensure_volume() {
  local name=$1
  if ! podman volume exists "$name"; then
    podman volume create "$name" >/dev/null
  fi
}

wait_for_log() {
  local name=$1 pattern=$2 deadline=$((SECONDS + 60))
  local logs=
  while true; do
    logs=$(podman logs "$name" 2>&1 || true)
    if [[ "$logs" == *"$pattern"* ]]; then
      return 0
    fi
    if (( SECONDS >= deadline )); then
      printf '%s\n' "$logs" >&2
      echo "$name did not become ready" >&2
      return 1
    fi
    sleep 1
  done
}

wait_for_http() {
  local url=$1 deadline=$((SECONDS + 60))
  until curl --fail --silent --max-time 2 "$url" >/dev/null 2>&1; do
    if (( SECONDS >= deadline )); then
      echo "$url did not become ready" >&2
      return 1
    fi
    sleep 1
  done
}

common_labels=(
  --label io.nodecontrol.milestone=NC-M2
  --label "io.nodecontrol.profile=$profile"
)

case "$action" in
  up)
    command -v podman >/dev/null
    command -v curl >/dev/null
    command -v ruby >/dev/null
    podman machine inspect node-control >/dev/null

    remove_containers
    if podman network exists "$network"; then
      podman network rm "$network" >/dev/null
    fi
    podman network create --internal "$network" >/dev/null

    podman build --pull=missing --tag "$go_image" --file "$repo_dir/Containerfile" "$repo_dir"
    podman build --pull=missing --tag "$workflow_image" --file "$repo_dir/workflow/Containerfile" "$repo_dir"

    postgres_volume="nc-m2-${profile}-postgres"
    nats_volume="nc-m2-${profile}-nats"
    workflow_volume="nc-m2-${profile}-workflow"
    ensure_volume "$postgres_volume"
    ensure_volume "$nats_volume"
    ensure_volume "$workflow_volume"

    podman run --detach --name nc-m2-postgres \
      "${common_labels[@]}" --label "io.nodecontrol.simulated-node=$core_node" \
      --network "$network" --security-opt=no-new-privileges \
      --env POSTGRES_USER=nodecontrol --env POSTGRES_DB=nodecontrol \
      --env POSTGRES_HOST_AUTH_METHOD=trust \
      --volume "$postgres_volume:/var/lib/postgresql/data" \
      docker.io/library/postgres@sha256:18cfe3ef5e6815560c98237d6216d1e5119702fb0f3894c8785dd58b8bbe5d73 >/dev/null

    podman run --detach --name nc-m2-nats \
      "${common_labels[@]}" --label "io.nodecontrol.simulated-node=$core_node" \
      --network "$network" --security-opt=no-new-privileges \
      --volume "$nats_volume:/data" \
      docker.io/library/nats@sha256:e4bf19f15fd3218814a4e3c9e0064e1334bd8aa20d5984b9f1a0afd084f8cc00 -js -sd /data >/dev/null

    wait_for_log nc-m2-postgres "database system is ready to accept connections"
    wait_for_log nc-m2-nats "Server is ready"

    podman run --detach --name nc-m2-controller \
      "${common_labels[@]}" --label "io.nodecontrol.simulated-node=$core_node" \
      --network "$network" --read-only --cap-drop=all \
      --security-opt=no-new-privileges --tmpfs /tmp:rw,size=16m,mode=1777 \
      --publish "127.0.0.1:${controller_port}:8080" \
      --env NODE_CONTROL_RUNTIME=tracer \
      --env DATABASE_URL=postgres://nodecontrol@nc-m2-postgres:5432/nodecontrol?sslmode=disable \
      --env NATS_URL=nats://nc-m2-nats:4222 \
      "$go_image" >/dev/null
    wait_for_http "http://127.0.0.1:${controller_port}/api/v1alpha1/healthz"

    local_node=
    for local_node in mac-node vps-node asus-node; do
      podman run --detach --name "nc-m2-agent-$local_node" \
        "${common_labels[@]}" --label "io.nodecontrol.simulated-node=$local_node" \
        --network "$network" --read-only --cap-drop=all \
        --security-opt=no-new-privileges --tmpfs /tmp:rw,size=8m,mode=1777 \
        --entrypoint /usr/local/bin/agent \
        --env NODE_CONTROL_RUNTIME=tracer \
        --env "NODE_ID=$local_node" --env NATS_URL=nats://nc-m2-nats:4222 \
        "$go_image" >/dev/null
    done

    podman run --detach --name nc-m2-langgraph \
      "${common_labels[@]}" --label "io.nodecontrol.simulated-node=$core_node" \
      --network "$network" --read-only --cap-drop=all \
      --security-opt=no-new-privileges --tmpfs /tmp:rw,size=16m,mode=1777 \
      --publish "127.0.0.1:${workflow_port}:8081" \
      --env NODE_CONTROL_RUNTIME=tracer \
      --env CONTROLLER_URL=http://nc-m2-controller:8080 \
      --volume "$workflow_volume:/state" \
      "$workflow_image" >/dev/null
    wait_for_http "http://127.0.0.1:${workflow_port}/healthz"
    ;;
  down)
    remove_containers
    if podman network exists "$network"; then
      podman network rm "$network" >/dev/null
    fi
    ;;
  status)
    podman ps --all --filter label=io.nodecontrol.milestone=NC-M2 \
      --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'
    ;;
  *)
    usage
    exit 2
    ;;
esac

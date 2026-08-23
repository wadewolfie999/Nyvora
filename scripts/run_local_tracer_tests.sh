#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
active_profile=split-edge

cleanup() {
  "$repo_dir/scripts/local_tracer.sh" down "$active_profile" || true
}
trap cleanup EXIT

for active_profile in vps-core split-edge; do
  "$repo_dir/scripts/local_tracer.sh" down "$active_profile"
  "$repo_dir/scripts/local_tracer.sh" up "$active_profile"
  ruby "$repo_dir/scripts/test_local_tracer.rb" "$active_profile"
  "$repo_dir/scripts/local_tracer.sh" down "$active_profile"
done

trap - EXIT

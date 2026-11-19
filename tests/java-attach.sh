#!/usr/bin/env bash
set -euo pipefail

image="${1:-europe-north1-docker.pkg.dev/nais-io/nais/images/debug:latest}"
script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
target_id=""

cleanup() {
  if [[ -n "$target_id" ]]; then
    docker rm --force "$target_id" >/dev/null
  fi
}
trap cleanup EXIT

restricted=(
  --network none
  --read-only
  --cap-drop=ALL
  --security-opt=no-new-privileges
  --tmpfs "/tmp:rw,mode=1777"
)

target_id="$(
  docker run --detach --rm "${restricted[@]}" \
    --user 1069:1069 \
    --mount "type=bind,src=$script_dir/AttachTarget.java,dst=/test/AttachTarget.java,readonly" \
    --entrypoint java "$image" /test/AttachTarget.java
)"

for attempt in {1..30}; do
  if docker logs "$target_id" | grep -q '^READY$'; then
    break
  fi
  if [[ "$attempt" -eq 30 ]]; then
    docker logs "$target_id"
    echo "Java target did not become ready" >&2
    exit 1
  fi
  sleep 1
done

# Use the image's default identity and a separate /tmp, sharing only the PID namespace.
docker run --rm "${restricted[@]}" \
  --pid="container:$target_id" \
  --entrypoint bash "$image" -euo pipefail -c '
    id
    jcmd 1 VM.version | grep -F "VM version"
    jcmd 1 GC.heap_info | grep -F "heap"
    jcmd 1 Thread.print -l | grep -F "\"main\""
    jmap -clstats 1 | grep -F "Total ="
  '

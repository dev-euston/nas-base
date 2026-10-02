#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

SKIP_BUILD=false
CONTAINER_NAME="claude-interactive"

if [[ -f "$SCRIPT_DIR/.env" ]]; then
  set -o allexport
  source "$SCRIPT_DIR/.env"
  set +o allexport
fi

MEDIA_PATH="${MEDIA_PATH:-}"

usage() {
  echo "Usage: $0 [--no-build] [--media <path>]"
  echo ""
  echo "  --no-build       Skip image builds"
  echo "  --media <path>   Path to media directory (default: \$MEDIA_PATH env var)"
  exit 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --no-build) SKIP_BUILD=true; shift ;;
    --media) MEDIA_PATH="$2"; shift 2 ;;
    -h|--help) usage ;;
    *) echo "Unknown option: $1"; usage ;;
  esac
done

if [[ -z "$MEDIA_PATH" ]]; then
  echo "Error: media path required. Set \$MEDIA_PATH or pass --media <path>"
  exit 1
fi

if [[ ! -d "$MEDIA_PATH" ]]; then
  echo "Error: media path does not exist: $MEDIA_PATH"
  exit 1
fi

if [[ "$SKIP_BUILD" == false ]]; then
  echo "Building images..."
  docker-compose build nas-base
  docker-compose build media-base
  docker-compose build claude
  echo "Build complete."
fi

# Start persistent container if not already running
if ! docker ps -q -f "name=^${CONTAINER_NAME}$" | grep -q .; then
  echo "Starting Claude container..."
  MEDIA_PATH="$MEDIA_PATH" docker-compose run -d --name "$CONTAINER_NAME" claude sleep infinity
fi

echo "Attaching to Claude in $MEDIA_PATH"
docker exec -it "$CONTAINER_NAME" claude

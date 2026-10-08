#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

SKIP_BUILD=false

if [[ -f "$SCRIPT_DIR/.env" ]]; then
  set -o allexport
  source "$SCRIPT_DIR/.env"
  set +o allexport
fi

WORKSPACE_PATH="${WORKSPACE_PATH:-}"
FILES_PATH="${FILES_PATH:-}"

usage() {
  echo "Usage: $0 [--no-build] [--port <port>] [--workspace <path>] [--files <path>] [--auth] [--fix]"
  echo ""
  echo "  --no-build           Skip image build"
  echo "  --port <port>        Gateway port (default: \$OPENCLAW_PORT or 18789)"
  echo "  --workspace <path>   NAS path to expose as openclaw workspace (default: \$WORKSPACE_PATH)"
  echo "  --files <path>       NAS path to expose read-only at /nas (default: \$FILES_PATH)"
  echo "  --auth               Authenticate Claude CLI inside the gateway container"
  echo "  --fix                Run openclaw doctor --fix to clear a stale gateway lock"
  exit 1
}

AUTH=false
FIX=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --no-build) SKIP_BUILD=true; shift ;;
    --port) OPENCLAW_PORT="$2"; shift 2 ;;
    --workspace) WORKSPACE_PATH="$2"; shift 2 ;;
    --files) FILES_PATH="$2"; shift 2 ;;
    --auth) AUTH=true; shift ;;
    --fix) FIX=true; shift ;;
    -h|--help) usage ;;
    *) echo "Unknown option: $1"; usage ;;
  esac
done

if [[ -z "$WORKSPACE_PATH" ]]; then
  echo "Error: workspace path required. Set \$WORKSPACE_PATH in .env or pass --workspace <path>"
  exit 1
fi

mkdir -p "$WORKSPACE_PATH"

if [[ -z "$FILES_PATH" ]]; then
  echo "Error: files path required. Set \$FILES_PATH in .env or pass --files <path>"
  exit 1
fi

mkdir -p "$FILES_PATH"

if [[ "$SKIP_BUILD" == false ]]; then
  echo "Building openclaw-claude image..."
  docker-compose build openclaw-gateway
  echo "Build complete."
fi

if [[ "$FIX" == true ]]; then
  echo "Fixing gateway state directory ownership and clearing stale locks..."
  docker-compose run --rm --user root --entrypoint sh openclaw-gateway \
    -c 'chown -R node:node /home/node/.openclaw && find /home/node/.openclaw -name "*.lock" -delete && echo "Done."'
  exit 0
fi

if [[ "$AUTH" == true ]]; then
  echo "Starting Claude auth login inside openclaw-gateway..."
  docker-compose run --rm --entrypoint /usr/local/bin/claude openclaw-gateway auth login
  exit 0
fi

echo "Starting OpenClaw gateway on port ${OPENCLAW_PORT:-18789}..."
echo "  workspace: $WORKSPACE_PATH"
echo "  files:     $FILES_PATH"
WORKSPACE_PATH="$WORKSPACE_PATH" FILES_PATH="$FILES_PATH" docker-compose up openclaw-gateway

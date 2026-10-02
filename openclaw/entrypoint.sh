#!/bin/sh
set -e
mkdir -p /home/node/.openclaw
cp /app/openclaw-default.json /home/node/.openclaw/openclaw.json
exec tini -s -- node /app/docker-entrypoint.mjs "$@"

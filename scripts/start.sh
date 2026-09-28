#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
[[ -f .env ]] || { echo 'Run ./scripts/install.sh first.' >&2; exit 1; }
docker compose up -d --build gemma-server
printf 'API: http://127.0.0.1:%s/v1\n' "$(awk -F= '$1=="PORT" {print $2}' .env)"

#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
[[ -f .env ]] || { echo 'Run ./scripts/install.sh first.' >&2; exit 1; }
cuda_arch=$(awk -F= '$1=="CUDA_ARCH" {gsub(/[[:space:]]/, "", $2); print $2}' .env)
if [[ "$cuda_arch" != 120 ]]; then
  echo "Refusing to start: .env has CUDA_ARCH=${cuda_arch:-unset}; main targets RTX 50-series (120)." >&2
  echo 'Use the rtx3070-8gb branch for RTX 3070, or rerun this branch installer.' >&2
  exit 2
fi
docker compose up -d --build gemma-server
printf 'API: http://127.0.0.1:%s/v1\n' "$(awk -F= '$1=="PORT" {print $2}' .env)"

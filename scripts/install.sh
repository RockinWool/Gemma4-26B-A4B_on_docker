#!/usr/bin/env bash
set -euo pipefail
umask 077
cd "$(dirname "$0")/.."

usage() {
  cat <<'EOF'
Usage: ./scripts/install.sh --model-dir /absolute/path/to/model-dir [--context 65536] [--cuda-arch 120]

Creates .env from .env.example and builds the llama.cpp CUDA image.
It does not download model weights. See README.md for the Hugging Face command.
EOF
}

model_dir=
context=65536
cuda_arch=120
while (($#)); do
  case "$1" in
    --model-dir) model_dir=${2:?missing model directory}; shift 2 ;;
    --context) context=${2:?missing context size}; shift 2 ;;
    --cuda-arch) cuda_arch=${2:?missing CUDA architecture}; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage >&2; exit 2 ;;
  esac
done

[[ -n "$model_dir" ]] || { echo '--model-dir is required.' >&2; usage >&2; exit 2; }
[[ -d "$model_dir" ]] || { echo "Model directory does not exist: $model_dir" >&2; exit 2; }
command -v docker >/dev/null || { echo 'Docker is required.' >&2; exit 1; }
docker compose version >/dev/null || { echo 'Docker Compose v2 is required.' >&2; exit 1; }
command -v nvidia-smi >/dev/null || { echo 'NVIDIA driver / nvidia-smi is required.' >&2; exit 1; }

command -v python3 >/dev/null || { echo 'Python 3 is required.' >&2; exit 1; }
[[ "$context" =~ ^[1-9][0-9]*$ ]] || { echo 'Context must be a positive integer.' >&2; exit 2; }
[[ "$cuda_arch" == 120 ]] || {
  echo "main targets RTX 50-series (CUDA_ARCH=120), but '$cuda_arch' was requested." >&2
  echo 'Use the rtx3070-8gb branch for RTX 3070.' >&2
  exit 2
}
model_file=$(awk -F= '$1=="MODEL_FILE" {print $2}' .env.example)
mtp_file=$(awk -F= '$1=="MTP_FILE" {print $2}' .env.example)
for file in "$model_file" "$mtp_file"; do
  [[ -s "$model_dir/$file" ]] || { echo "Missing model file: $model_dir/$file" >&2; exit 2; }
done
docker run --rm --gpus all nvidia/cuda:13.0.0-base-ubuntu24.04 nvidia-smi || {
  echo 'CUDA container preflight failed. Check the host NVIDIA driver and NVIDIA Container Toolkit; see README.md.' >&2
  exit 1
}

if [[ -e .env ]]; then
  backup=".env.backup.$(date -u +%Y%m%dT%H%M%SZ)"
  cp -p -- .env "$backup"
  printf 'Existing .env backed up to %s\n' "$backup"
fi

python3 - "$model_dir" "$context" "$cuda_arch" <<'PY2'
from pathlib import Path
import sys
text = Path('.env.example').read_text()
model_dir = str(Path(sys.argv[1]).resolve())
if any(c in model_dir for c in ('\n', '\r', '"', '$', '`', '\\')):
    raise SystemExit('Model directory contains characters unsupported by this installer.')
text = text.replace('/absolute/path/to/Gemma4-26B-A4B-QAT-MTP', '"' + model_dir + '"')
text = text.replace('CONTEXT_SIZE=65536', f'CONTEXT_SIZE={sys.argv[2]}')
text = text.replace('CUDA_ARCH=120', f'CUDA_ARCH={sys.argv[3]}')
Path('.env').write_text(text)
PY2

docker compose build
docker compose run --rm --no-deps gemma-server /opt/llama.cpp/build/bin/llama-server --list-devices
printf 'Installed. Start with: ./scripts/start.sh\n'

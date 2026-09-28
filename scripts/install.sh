#!/usr/bin/env bash
set -euo pipefail

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

python3 - "$model_dir" "$context" "$cuda_arch" <<'PY2'
from pathlib import Path
import sys
text = Path('.env.example').read_text()
text = text.replace('/absolute/path/to/Gemma4-26B-A4B-QAT-MTP', sys.argv[1])
text = text.replace('CONTEXT_SIZE=65536', f'CONTEXT_SIZE={sys.argv[2]}')
text = text.replace('CUDA_ARCH=120', f'CUDA_ARCH={sys.argv[3]}')
Path('.env').write_text(text)
PY2

docker compose build
printf 'Installed. Start with: ./scripts/start.sh\n'

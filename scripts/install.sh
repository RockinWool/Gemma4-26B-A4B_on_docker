#!/usr/bin/env bash
set -euo pipefail
umask 077
cd "$(dirname "$0")/.."

usage() {
  cat <<'EOF'
Usage: ./scripts/install.sh --model-dir /absolute/path/to/model-dir [--context 16384] [--cuda-arch 86]

Creates .env from .env.example and builds the llama.cpp CUDA image.
It does not download model weights. See README.md for the Hugging Face command.
EOF
}

model_dir=
context=16384
cuda_arch=86
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
[[ "$cuda_arch" == 86 ]] || { echo 'This branch targets RTX 3070 (CUDA_ARCH=86).' >&2; exit 2; }
[[ ! -e .env ]] || { echo '.env already exists; edit it and run docker compose build, or back it up before reinstalling.' >&2; exit 2; }
for file in Gemma4-26B-A4B-QAT-Uncensored-HauhauCS-Balanced-Q4_K_M.gguf mtp-gemma-4-26B-A4B-it.gguf; do
  [[ -s "$model_dir/$file" ]] || { echo "Missing model file: $model_dir/$file" >&2; exit 2; }
done
# Check the driver and Container Toolkit against the exact CUDA image before compiling.
docker run --rm --gpus all nvidia/cuda:12.4.1-base-ubuntu22.04 nvidia-smi || {
  echo 'CUDA container preflight failed. Check the host NVIDIA driver and NVIDIA Container Toolkit; see README.md.' >&2
  exit 1
}

python3 - "$model_dir" "$context" "$cuda_arch" <<'PY2'
from pathlib import Path
import sys
text = Path('.env.example').read_text()
model_dir = str(Path(sys.argv[1]).resolve())
if any(c in model_dir for c in ('\n', '\r', '"', '$', '`', '\\')):
    raise SystemExit('Model directory contains characters unsupported by this installer.')
text = text.replace('/absolute/path/to/Gemma4-26B-A4B-QAT-MTP', '"' + model_dir + '"')
text = text.replace('CONTEXT_SIZE=16384', f'CONTEXT_SIZE={sys.argv[2]}')
text = text.replace('CUDA_ARCH=86', f'CUDA_ARCH={sys.argv[3]}')
Path('.env').write_text(text)
PY2

docker compose build
docker compose run --rm --no-deps gemma-server /opt/llama.cpp/build/bin/llama-server --list-devices
printf 'Installed. Start with: ./scripts/start.sh\n'

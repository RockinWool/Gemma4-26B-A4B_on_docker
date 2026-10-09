# Gemma 4 26B-A4B QAT MTP — RTX 3070 8GB branch

A reproducible Docker configuration for running [HauhauCS/Gemma4-26B-A4B-QAT-Uncensored-HauhauCS-Balanced-MTP](https://huggingface.co/HauhauCS/Gemma4-26B-A4B-QAT-Uncensored-HauhauCS-Balanced-MTP) with current `llama.cpp`, CUDA, Q4 KV cache, CPU-resident MoE layers, and the bundled MTP draft head.

The design targets GPUs that cannot hold the complete 16.8GB GGUF with an adequate KV cache. It places all 30 MoE layers in system RAM while retaining dense compute, KV cache, and MTP on one NVIDIA GPU.

> This repository contains Docker and orchestration code only. Model weights, the vision projector, and their respective licenses remain upstream. The bundled model is an uncensored community fine-tune; assess it before using it in a setting that requires safeguards.

## Validation status

This branch targets RTX 3070 8GB (Ampere / SM 86) using CUDA 12.4.1, a 16,384-token context and a 128-token microbatch. **RTX 3070 inference and the Docker build have not been tested here**; the environment used to prepare this branch has no Docker or NVIDIA GPU. The figures below are historical results from the original RTX 5060 Ti configuration, not RTX 3070 measurements.

## Original configuration measurements

- RTX 5060 Ti 16GB + Ryzen 7 7700X + 60GiB RAM
- 131,072-token context with Q4_0 K/V cache
- 28,296-token cold prompt: **666.81 tok/s prefill**, **45.23 tok/s decode**, 90% MTP draft acceptance
- Runtime GPU memory: **4.41GiB / 16GiB** after the long request

See [docs/BENCHMARKS.md](docs/BENCHMARKS.md) for conditions and the 32K comparison. Your performance will depend on GPU compute, memory bandwidth, CPU RAM bandwidth, CUDA architecture, and llama.cpp revision.

## Requirements

- Linux with Docker Engine and Docker Compose v2.30+ (`gpus` service field)
- Python 3 for the installer
- Recommended host driver: Linux 550.54.15+; Windows / WSL2 551.61+. Older CUDA 12.x minor-compatible drivers may have limitations and are not the supported starting point for this branch.
- No host CUDA Toolkit is needed: the container supplies CUDA 12.4.1. `nvidia-smi` reports the maximum CUDA version supported by the driver, not the installed Toolkit.
- NVIDIA driver and NVIDIA Container Toolkit configured for Docker (`docker run --gpus all ... nvidia-smi` must work)
- A CUDA-capable NVIDIA GPU
- At least 32GB system RAM; 64GB or more is recommended
- Approximately 18GB disk space for the text GGUF plus MTP head; add 1.2GB for optional vision

## Quick start

### 1. Download the model

Install the Hugging Face CLI if necessary, authenticate if the upstream repository requires it, then download the required text model and MTP head:

```bash
mkdir -p ~/models/Gemma4-26B-A4B-QAT-MTP
hf download HauhauCS/Gemma4-26B-A4B-QAT-Uncensored-HauhauCS-Balanced-MTP \
  --include 'Gemma4-26B-A4B-QAT-Uncensored-HauhauCS-Balanced-Q4_K_M.gguf' \
  --include 'mtp-gemma-4-26B-A4B-it.gguf' \
  --local-dir ~/models/Gemma4-26B-A4B-QAT-MTP
```

For vision experiments, also download `mmproj-Gemma4-26B-A4B-QAT-Uncensored-HauhauCS-Balanced-BF16.gguf`. The standard compose profile is text-only; an mmproj-enabled profile can be added without changing the text model configuration.

### 2. Configure and build

```bash
git clone --branch rtx3070-8gb https://github.com/RockinWool/Gemma4-26B-A4B_on_docker.git
cd Gemma4-26B-A4B_on_docker
./scripts/install.sh --model-dir ~/models/Gemma4-26B-A4B-QAT-MTP
```

`CUDA_ARCH=86` targets RTX 3070. This branch uses its own image tag and Compose project name. Stop the old server first if it uses port 8096. The installer checks model files and GPU access before compiling, then checks CUDA device enumeration in the built server. If an `.env` from another branch exists, it is copied to a timestamped `.env.backup.*` file before the RTX 3070 configuration is generated. `start.sh` also refuses to build when `.env` does not contain `CUDA_ARCH=86`.

The build pins llama.cpp to `3d65c90d04d337e88f2b1f7f0061f40a5324e662` instead of moving HEAD. `BUILD_JOBS=4` limits compilation RAM usage.

### 3. Run

```bash
./scripts/start.sh
curl http://127.0.0.1:8096/v1/models
```

The server exposes an OpenAI-compatible API at `http://127.0.0.1:8096/v1`. Stop it with `./scripts/stop.sh`.

## Context and VRAM guidance

| GPU memory | Suggested starting context | Notes |
|---:|---:|---|
| RTX 3070 8GB | 16,384 | Text-only recommended; leave margin for the desktop and CUDA allocations. |
| RTX 5060 Ti 16GB (original branch) | 131,072 | Historical result; use main for RTX 50-series. |

The values are starting points, not guarantees. For an 8GB GPU, keep `CPU_MOE_LAYERS=30`, use Q4 KV cache, close competing GPU workloads, and validate with a short request before raising context.

## Benchmark

```bash
./scripts/benchmark.py --prompt-chars 16384 --max-tokens 64
```

The API response includes llama.cpp's `timings.prompt_per_second`, `timings.predicted_per_second`, and speculative-decoding acceptance statistics.

## Key configuration choices

- `--n-cpu-moe 30`: keeps every MoE layer in host RAM, preserving GPU VRAM for KV cache.
- `-ngl 99`: offloads supported dense layers to the selected GPU.
- `-md ... --spec-type draft-mtp`: enables native multi-token prediction with the supplied draft head.
- `--cache-type-k q4_0 --cache-type-v q4_0`: reduces KV-cache memory use.
- `--fit off`: avoids a current automatic-fit issue with this Gemma 4 server profile.

## License

The repository's orchestration code is MIT-licensed. Model weights and upstream model terms are not covered by that license; review the upstream model card and its Gemma license before downloading or redistributing weights.

## RTX 3070 troubleshooting

Start with `nvidia-smi` and the installer preflight. Do not install a Linux NVIDIA driver inside WSL2; update the Windows host driver instead.

| Symptom | Action |
|---|---|
| `unsatisfied condition: cuda>=12.4` / insufficient driver | Update the host driver to the recommended version above. CUDA in the container cannot replace a host driver. |
| `could not select device driver ... gpu` | Install/configure NVIDIA Container Toolkit for Docker, restart Docker, then retry the preflight. |
| `no kernel image is available` / invalid device function | Regenerate `.env` with `CUDA_ARCH=86` and run `docker compose build --no-cache`. |
| `Unsupported gpu architecture 'compute_120'` | An RTX 50-series `.env` is still present. Rerun `./scripts/install.sh --model-dir /path/to/models` without `--cuda-arch`; do not proceed directly to `start.sh`. |
| CUDA out of memory | Set `CONTEXT_SIZE=8192`, `UBATCH_SIZE=64`, keep `CPU_MOE_LAYERS=30`, stop other GPU workloads and recreate the server. If necessary reduce `GPU_LAYERS` from 99 to 20 (slower CPU fallback). |
| Host RAM exhaustion / exit 137 | The 16.8GB model stays largely in RAM; use at least 32GB and close other memory-heavy apps. |

After editing `.env`, run `docker compose up -d --force-recreate gemma-server`. Verify inference, not just `/v1/models`:

```bash
curl --fail-with-body http://127.0.0.1:8096/v1/chat/completions \
  -H 'Content-Type: application/json' \
  -d '{"messages":[{"role":"user","content":"Say hello in Japanese."}],"max_tokens":32}'
docker compose logs --tail=200 gemma-server
```

If it still fails, retain the output of `nvidia-smi`, `docker compose version`, the build failure and the server logs. No RTX 3070 speed or memory guarantee is inferred from the RTX 5060 Ti results.

Driver references: [CUDA 12.4.1 release notes](https://docs.nvidia.com/cuda/archive/12.4.1/cuda-toolkit-release-notes/) and [NVIDIA CUDA compatibility](https://docs.nvidia.com/deploy/cuda-compatibility/minor-version-compatibility.html).

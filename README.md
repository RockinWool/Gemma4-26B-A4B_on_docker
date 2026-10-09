# Gemma 4 26B-A4B QAT MTP on Docker

A reproducible Docker configuration for running [HauhauCS/Gemma4-26B-A4B-QAT-Uncensored-HauhauCS-Balanced-MTP](https://huggingface.co/HauhauCS/Gemma4-26B-A4B-QAT-Uncensored-HauhauCS-Balanced-MTP) with current `llama.cpp`, CUDA, Q4 KV cache, CPU-resident MoE layers, and the bundled MTP draft head.

The design targets GPUs that cannot hold the complete 16.8GB GGUF with an adequate KV cache. It places all 30 MoE layers in system RAM while retaining dense compute, KV cache, and MTP on one NVIDIA GPU.

> This repository contains Docker and orchestration code only. Model weights, the vision projector, and their respective licenses remain upstream. The bundled model is an uncensored community fine-tune; assess it before using it in a setting that requires safeguards.

## Hardware profiles

| Branch | GPU profile | CUDA build | Starting context |
|---|---|---:|---:|
| `main` | RTX 50-series (`sm_120`) | 13.0 | 65,536 |
| [`rtx3070-8gb`](https://github.com/RockinWool/Gemma4-26B-A4B_on_docker/tree/rtx3070-8gb) | RTX 3070 8GB (`sm_86`) | 12.4.1 | 16,384 |

Use the branch matching the GPU. Each start script rejects an `.env` created for the other profile before rebuilding.

## What was validated

- RTX 5060 Ti 16GB + Ryzen 7 7700X + 60GiB RAM
- 131,072-token context with Q4_0 K/V cache
- 28,296-token cold prompt: **666.81 tok/s prefill**, **45.23 tok/s decode**, 90% MTP draft acceptance
- Runtime GPU memory: **4.41GiB / 16GiB** after the long request

See [docs/BENCHMARKS.md](docs/BENCHMARKS.md) for conditions and the 32K comparison. Your performance will depend on GPU compute, memory bandwidth, CPU RAM bandwidth, CUDA architecture, and llama.cpp revision.

## Requirements

- Linux with Docker Engine and Docker Compose v2
- NVIDIA driver and [NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html) configured for Docker (`docker run --gpus all ... nvidia-smi` must work)
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
git clone https://github.com/RockinWool/Gemma4-26B-A4B_on_docker.git
cd Gemma4-26B-A4B_on_docker
./scripts/install.sh --model-dir ~/models/Gemma4-26B-A4B-QAT-MTP --context 65536 --cuda-arch 120
```

`CUDA_ARCH=120` is for RTX 50-series GPUs. Set the architecture appropriate to your GPU before building (for example, `89` for Ada). The installer creates a private `.env` file and builds llama.cpp; it does not upload or copy model files.

### 3. Run

```bash
./scripts/start.sh
curl http://127.0.0.1:8096/v1/models
```

Open [http://127.0.0.1:8096](http://127.0.0.1:8096) for llama.cpp's built-in chat interface. The server exposes an OpenAI-compatible API at `http://127.0.0.1:8096/v1`. See [Chat and API access](docs/CHAT.md) for a complete curl request and SSH access from another computer. Stop it with `./scripts/stop.sh`.

## Context and VRAM guidance

| GPU memory | Suggested starting context | Notes |
|---:|---:|---|
| 8GB | 65,536 | Text-only recommended; leave margin for the desktop and CUDA allocations. |
| 16GB | 131,072 | Validated on RTX 5060 Ti with this exact configuration. |

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
- The Docker build pins llama.cpp to commit `3d65c90d04d337e88f2b1f7f0061f40a5324e662` so rebuilding the same repository revision does not silently change the inference engine.

## License

The repository's orchestration code is MIT-licensed. Model weights and upstream model terms are not covered by that license; review the upstream model card and its Gemma license before downloading or redistributing weights.

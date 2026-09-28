# Benchmark results

Measured on 2026-09-28 with a Ryzen 7 7700X, RTX 5060 Ti 16GB, 60GiB RAM, current llama.cpp built with CUDA 13 for `sm_120`. All 30 MoE layers were placed in CPU RAM; the 5060 Ti held dense work, the Q4 KV cache, and the MTP draft head.

## 131K long-context profile

| Metric | Result |
|---|---:|
| Context configured | 131,072 tokens |
| Cold prompt | 28,296 tokens |
| Prompt processing | **666.81 tok/s** |
| Decode | **45.23 tok/s** |
| Output | 29 tokens |
| MTP acceptance | 18 / 20 (90%) |
| End-to-end wall time | 43.081s |
| GPU memory after request | 4.41GiB / 16GiB |

The benchmark request returned a coherent Japanese one-sentence summary. Values are hardware- and llama.cpp-version-specific; use `scripts/benchmark.py` to reproduce them on another system.

## 32K profile

| Metric | Result |
|---|---:|
| Prompt | 7,094 tokens |
| Prompt processing | 636.30 tok/s |
| Decode | 48.48 tok/s |
| MTP acceptance | 18 / 20 (90%) |

The long-context profile trades a small amount of decode speed for KV capacity.

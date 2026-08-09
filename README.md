# vLLM deployment

Hands-on project to run [vLLM](https://docs.vllm.ai/) locally, then deploy it on Kubernetes.

## What is vLLM?

vLLM is a **high-throughput LLM inference server** — not a model. It loads model weights, accepts prompts via an API, runs token generation on GPU (or CPU), and returns structured output (typically JSON over an OpenAI-compatible HTTP API).

```text
Prompt → vLLM (loads weights, runs inference) → JSON response
```

This repo focuses on **online serving** (`vllm serve`), the long-lived HTTP server pattern used in production and on Kubernetes.

## Project status

| Phase | Goal | Status |
| ----- | ---- | ------ |
| **1 — Local** | Run vLLM on Apple Silicon with a small MLX model | Done |
| **2 — Kubernetes** | Deploy vLLM with NVIDIA/CUDA and GPU resources | Planned |
| **3 — Operate** | Expose the API, capture latency and GPU metrics | Planned |

Phase 1 uses **[vLLM-Metal](https://github.com/vllm-project/vllm-metal)** (Metal + MLX) on an M1/M2/M3 Mac. Phase 2 will use the standard NVIDIA/CUDA path on Kubernetes — same vLLM concepts (`vllm serve`, OpenAI API), different runtime.

## Prerequisites

- Apple Silicon Mac (arm64)
- macOS with [Homebrew](https://brew.sh/)
- [Xcode Command Line Tools](https://developer.apple.com/xcode/resources/) (required for Metal compilation)
- [uv](https://docs.astral.sh/uv/) (Python package manager)

Run the helper script to verify and install what is missing:

```bash
./install-prereqs.sh
```

This script does **not** install vLLM itself — it prepares the host for the upstream vLLM-Metal installer.

## Install vLLM-Metal

After prerequisites are ready:

```bash
curl -fsSL https://raw.githubusercontent.com/vllm-project/vllm-metal/main/install.sh | bash
```

This creates a virtualenv at `~/.venv-vllm-metal` with vLLM-Metal and its dependencies.

## Serve locally

Start the OpenAI-compatible API server on loopback (avoids Tailscale/CGNAT address issues with torch distributed):

```bash
./serve-local.sh
```

Default model: `mlx-community/Qwen2.5-0.5B-Instruct-4bit` (small, fast to load on Apple Silicon).

Serve a different MLX model:

```bash
./serve-local.sh mlx-community/Qwen2.5-0.5B-Instruct-4bit
```

Override the venv path:

```bash
VLLM_METAL_VENV=~/.venv-vllm-metal ./serve-local.sh
```

## Test the API

Once the server is listening on port 8000:

```bash
curl http://127.0.0.1:8000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "mlx-community/Qwen2.5-0.5B-Instruct-4bit",
    "messages": [{"role": "user", "content": "Hello"}],
    "max_tokens": 50
  }'
```

## Repository layout

```text
vllm-deployment/
├── install-prereqs.sh   # Phase 1 host prerequisites (Homebrew, uv, Xcode CLT)
├── serve-local.sh       # Start vLLM-Metal with loopback networking
└── README.md
```

## Design notes

- **GPU path on Mac:** vLLM-Metal, not CPU-from-source or NVIDIA CUDA (unavailable on Apple Silicon).
- **No Devbox wrapper:** vLLM-Metal's `install.sh` is the source of truth for the local runtime; revisit if this becomes a shared team repo.
- **Loopback binding:** `serve-local.sh` sets `VLLM_HOST_IP`, `MASTER_ADDR`, and `GLOO_SOCKET_IFNAME=lo0` so the API server stays on localhost even when Tailscale is active.

## Next: Kubernetes (Phase 2)

Target: deploy vLLM with a CUDA-compatible model on a GPU-backed cluster, reachable in-cluster via ClusterIP. Packaging will likely be Helm; validation will be an executable check script (lint → deploy → in-cluster `/v1/chat/completions`).

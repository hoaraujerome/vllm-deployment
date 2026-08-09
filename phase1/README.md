# Phase 1 — Local vLLM

Run vLLM on Apple Silicon via [vLLM-Metal](https://github.com/vllm-project/vllm-metal). Proves the **inference contract**: `vllm serve`, OpenAI-compatible API, model load, prompt → JSON.

**Status:** done

## Scripts

| Script | Purpose |
| ------ | ------- |
| `install-prereqs.sh` | Homebrew, Xcode CLT, uv — host prep only |
| `serve-local.sh` | Start vLLM-Metal on loopback (`127.0.0.1:8000`) |

```bash
./phase1/install-prereqs.sh
curl -fsSL https://raw.githubusercontent.com/vllm-project/vllm-metal/main/install.sh | bash
./phase1/serve-local.sh
```

Default model: `mlx-community/Qwen2.5-0.5B-Instruct-4bit`

## Next

→ [Phase 2](../phase2/README.md) — bootstrap Kubernetes cluster on AWS

# Phase 1 — Local vLLM


**Status:** done

**Repo:** `~/DEV/vllm-deployment/phase1` — `install-prereqs.sh`, `serve-local.sh`

---

## Done when

You can prompt vLLM locally and get a structured response.

---

## Checklist

- [x] Install vLLM-Metal (`install.sh` → `~/.venv-vllm-metal`)
- [x] Prerequisites: arm64 Python 3.12, Xcode Command Line Tools
- [x] Serve tiny MLX model: `mlx-community/Qwen2.5-0.5B-Instruct-4bit`
- [x] Send a test prompt (`curl` or `vllm chat`)
- [x] Document: model choice, startup time, first-token latency

---

## Local setup decision — GPU path (vLLM-Metal)

**Machine:** Apple M1 Pro (14-core GPU, Metal 3)

**Choice:** GPU path via [vLLM-Metal](https://github.com/vllm-project/vllm-metal) — not CPU.


| Option                  | Why not / why yes                                                                                                                                                 |
| ----------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **CPU on Mac**          | Experimental; requires building vLLM from source. Slow inference.                                                                                                 |
| **NVIDIA CUDA**         | Not available on Apple Silicon.                                                                                                                                   |
| **vLLM-Metal (chosen)** | Official Apple Silicon GPU path. One-line install script, prebuilt Metal kernels, uses M1 GPU. Tiny MLX models (e.g. `mlx-community/Qwen2.5-0.5B-Instruct-4bit`). |


**Rationale:** Simplest local first try that still exercises the **GPU inference** mental model — closer to [Phase 5](../phase5/README.md) than a CPU from-source build. Local stack differs from K8s (Metal/MLX vs NVIDIA/CUDA) but vLLM concepts transfer: `vllm serve`, OpenAI API, model loading.

See vLLM GPU vs CPU installation paths for the broader picture.

---

## Local setup decision — dev environment (Devbox)

**Scope:** Phase 1 toolchain and reproducibility on the work laptop.

**Choice:** Skip [Devbox](https://www.jetify.com/devbox) — use vLLM-Metal's official `install.sh` directly.


| Option                           | Why not / why yes                                                                                                                                                                                                                               |
| -------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Devbox**                       | Good for pinning Python 3.12 and project scripts, but vLLM-Metal expects its own venv (`~/.venv-vllm-metal`) and MLX/Metal GPU deps are unlikely to map cleanly to Nix packages. Adds a second isolation model without replacing the installer. |
| **Direct install (chosen)**      | Follow vLLM-Metal docs as the source of truth: `install.sh`, arm64 Python 3.12, Xcode CLT. One known machine (M1 Pro); no team onboarding need yet.                                                                                             |
| **Devbox as thin wrapper later** | Possible after install works — scripts that activate the vLLM-Metal venv inside `devbox shell` — but not worth the setup for this solo learning pass.                                                                                           |


**Rationale:** Phase 1 goal is to run GPU-backed vLLM locally, not to standardize a multi-developer dev environment. Devbox does not carry the inference runtime into later phases anyway. Revisit if this becomes a shared repo or [Phase 2](../phase2/README.md) / [Phase 4](../phase4/README.md) need pinned tooling.

---

## Runbook

**Prerequisites** (Homebrew, Xcode CLT, uv):

```bash
~/DEV/vllm-deployment/phase1/install-prereqs.sh
```

**Install vLLM-Metal:**

```bash
curl -fsSL https://raw.githubusercontent.com/vllm-project/vllm-metal/main/install.sh | bash
```

**Serve locally** (`serve-local.sh` sets loopback env vars — needed when Tailscale is up):

```bash
~/DEV/vllm-deployment/phase1/serve-local.sh
```

**Smoke test:**

```bash
curl http://127.0.0.1:8000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"model":"mlx-community/Qwen2.5-0.5B-Instruct-4bit","messages":[{"role":"user","content":"Say hello."}],"max_tokens":50}'
```

---

## Notes

- System Python 3.14 is too new — vLLM-Metal installs arm64 Python 3.12 into `~/.venv-vllm-metal`.
- With Tailscale active, vLLM may pick a CGNAT IP (`100.64.x.x`) for torch distributed; `serve-local.sh` forces `127.0.0.1`.

---

## Next

→ [Phase 2](../phase2/README.md)

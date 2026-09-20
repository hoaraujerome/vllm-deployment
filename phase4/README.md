# Phase 4 — Kubernetes deployment

**Status:** done (`make check-deploy` green, 2026-09-18)

**Prerequisite:** [Phase 3](../phase3/README.md) (kubectl / Helm from laptop over VPN)

**Repo:** `~/DEV/vllm-deployment/phase4` — Helm chart, `phase4-check.sh`

---

## Done when

Validation ladder passes on the cluster from **your laptop** (via WireGuard); vLLM pod is running and reachable inside the cluster via ClusterIP. Real inference works on **CPU** — no NVIDIA/CUDA yet ([Phase 5](../phase5/README.md)).

**Verified 2026-09-18** — see [Verification](#verification-2026-09-18) below.

---

## Mindset — loop engineering

Phase 1 proved the **inference contract** locally. Phase 2 proved the **cluster contract**. Phase 3 proved **laptop access**. Phase 4 proves the **workload deployment contract** — Helm, Service, in-cluster API — without GPU complexity.

### Three loops

| Loop | Cadence | Who drives it | Phase 4 role |
| ---- | ------- | ------------- | -------------- |
| **1 — Agentic coding** | seconds → minutes | Cursor + terminal | Edit chart → run checks from laptop |
| **2 — Engineer feedback** | hours | You | Node upsize for RAM, reject bad shortcuts |
| **3 — Production feedback** | days | Metrics + users | [Phase 6](../phase6/README.md) |

---

## Goal

Deploy vLLM (CPU build) on the cluster, serving a tiny Hugging Face model, reachable inside the cluster via ClusterIP (no ingress yet — [Phase 6](../phase6/README.md)).

```text
Goal:     vLLM on cluster, in-cluster inference API works (CPU)
Access:   kubectl / helm from laptop (Phase 3 WireGuard)
Model:    Qwen/Qwen2.5-0.5B-Instruct
Image:    vllm/vllm-openai-cpu:latest-arm64 (Graviton)
Weights:  HF Hub pull at startup
Packaging: Helm chart (phase4/helm/vllm)
Scope:    1 replica, ClusterIP, no GPU
Node:     t4g.large, 30 GiB root (upsize from Phase 2 t4g.small)
```

---

## Constraints (Loop 2 — frozen)

- **Access:** laptop kubeconfig over WireGuard (Phase 3) — not on-node kubectl
- **Node sizing:** `t4g.large` + 30 GiB root volume (image + model weights + shm)
- **Runtime:** vLLM CPU — not Metal, not CUDA
- **No GPU** in Phase 4
- **`enableServiceLinks: false`** — K8s injects `VLLM_PORT=tcp://...` otherwise and vLLM crashes
- **CPU cold start:** first `/v1/chat/completions` can take ~6–8 min (compilation + inference); ladder defaults allow 1200s functional / 900s curl
- **Dtype:** `--dtype=float16` on Graviton2 (no hardware bf16)

---

## Validation ladder — `phase4-check.sh`

| Gate | Check | Proves |
| ---- | ----- | ------ |
| Static | `helm lint`, manifest lint | valid chart |
| Artifact | vLLM CPU image pulls | runtime reachable |
| Deploy | helm install, pod Ready | scheduler + startup |
| Functional | in-cluster `/v1/chat/completions` | CPU inference |
| Resource | model loaded, no OOM | RAM fit |

**Done when:** `make check-deploy` exits 0 from laptop.

```bash
export KUBECONFIG=~/.kube/vllm-phase2.conf
cd ~/DEV/vllm-deployment/phase4
make check-deploy
```

Skip one gate: `SKIP_GATE_FUNCTIONAL=1 make check-deploy`. List gates: `make check-gates`.

Default timeouts (override via env if needed):

| Variable | Default | Purpose |
| -------- | ------- | ------- |
| `DEPLOY_TIMEOUT` | 1800 | helm `--wait` |
| `FUNCTIONAL_TIMEOUT` | 1200 | inference job wait |
| `CURL_MAX_TIME` | 900 | curl inside functional job |

---

## Checklist

- [x] Upsize K8s node from `t4g.small` → `t4g.large` (30 GiB root)
- [x] Helm chart / Deployment + Service (ClusterIP)
- [x] Write `phase4-check.sh`
- [x] Ladder green from laptop over WireGuard

---

## Verification (2026-09-18)

Manual in-cluster chat:

```bash
kubectl --kubeconfig ~/.kube/vllm-phase2.conf run -it --rm curl --image=curlimages/curl --restart=Never -n vllm -- \
  curl -s http://vllm:8000/v1/chat/completions \
  -H 'Content-Type: application/json' \
  -d '{"model":"Qwen/Qwen2.5-0.5B-Instruct","messages":[{"role":"user","content":"hello"}],"max_tokens":32}'
```

Output (~8m28s):

```json
{"id":"chatcmpl-be92d62b5de8e847","object":"chat.completion","created":1789754678,"model":"Qwen/Qwen2.5-0.5B-Instruct","choices":[{"index":0,"message":{"role":"assistant","content":"Hello! How can I assist you today? If you have any questions or need help with anything specific, feel free to ask and I'll do my best to","refusal":null,"annotations":null,"audio":null,"function_call":null,"reasoning":null},"logprobs":null,"finish_reason":"length","stop_reason":null,"token_ids":null,"routed_experts":null}],"service_tier":null,"system_fingerprint":"vllm-0.29.0-fcaa1cbc","usage":{"prompt_tokens":30,"total_tokens":62,"completion_tokens":32,"prompt_tokens_details":null,"completion_tokens_details":null},"prompt_logprobs":null,"prompt_token_ids":null,"prompt_text":null,"kv_transfer_params":null,"ec_transfer_params":null,"metrics":null}
```

Full validation ladder (no skip flags):

```bash
cd ~/DEV/vllm-deployment/phase4
make check-deploy
```

Output:

```text
./scripts/phase4-check.sh
==> Gate 1: static
==> Linting /Users/jhoarau/DEV/vllm-deployment/phase4/helm/vllm
[INFO] Chart.yaml: icon is recommended

1 chart(s) linted, 0 chart(s) failed
==> Gate 2: artifact
job.batch/phase4-image-pull created
==> Artifact (image pull): ok
==> Gate 3: deploy
Release "vllm" has been upgraded. Happy Helming!
NAME: vllm
LAST DEPLOYED: Fri Sep 18 13:57:01 2026
NAMESPACE: vllm
STATUS: deployed
REVISION: 2
TEST SUITE: None
deployment "vllm" successfully rolled out
    vllm-bdb845fbd-d2gdd   1/1   Running   0     141m
==> Gate 4: functional (in-cluster /v1/chat/completions)
job.batch/phase4-functional created
==> Functional: inference job running (0s / 1200s — CPU first request is slow; watch: kubectl logs -n vllm -l app.kubernetes.io/instance=vllm -f)
==> Functional: inference job running (16s / 1200s — CPU first request is slow; watch: kubectl logs -n vllm -l app.kubernetes.io/instance=vllm -f)
==> Functional: inference job running (31s / 1200s — CPU first request is slow; watch: kubectl logs -n vllm -l app.kubernetes.io/instance=vllm -f)
==> Functional: inference job running (47s / 1200s — CPU first request is slow; watch: kubectl logs -n vllm -l app.kubernetes.io/instance=vllm -f)
==> Functional: inference job running (62s / 1200s — CPU first request is slow; watch: kubectl logs -n vllm -l app.kubernetes.io/instance=vllm -f)
==> Functional: inference job running (78s / 1200s — CPU first request is slow; watch: kubectl logs -n vllm -l app.kubernetes.io/instance=vllm -f)
==> Functional: inference job running (93s / 1200s — CPU first request is slow; watch: kubectl logs -n vllm -l app.kubernetes.io/instance=vllm -f)
==> Functional: inference job running (108s / 1200s — CPU first request is slow; watch: kubectl logs -n vllm -l app.kubernetes.io/instance=vllm -f)
==> Functional: inference job running (124s / 1200s — CPU first request is slow; watch: kubectl logs -n vllm -l app.kubernetes.io/instance=vllm -f)
==> Functional: inference job running (139s / 1200s — CPU first request is slow; watch: kubectl logs -n vllm -l app.kubernetes.io/instance=vllm -f)
==> Functional: inference job running (154s / 1200s — CPU first request is slow; watch: kubectl logs -n vllm -l app.kubernetes.io/instance=vllm -f)
==> Functional: inference job running (169s / 1200s — CPU first request is slow; watch: kubectl logs -n vllm -l app.kubernetes.io/instance=vllm -f)
==> Functional: inference job running (185s / 1200s — CPU first request is slow; watch: kubectl logs -n vllm -l app.kubernetes.io/instance=vllm -f)
==> Functional: inference job running (200s / 1200s — CPU first request is slow; watch: kubectl logs -n vllm -l app.kubernetes.io/instance=vllm -f)
==> Functional: inference job running (215s / 1200s — CPU first request is slow; watch: kubectl logs -n vllm -l app.kubernetes.io/instance=vllm -f)
==> Functional: inference job running (231s / 1200s — CPU first request is slow; watch: kubectl logs -n vllm -l app.kubernetes.io/instance=vllm -f)
==> Functional: inference job running (246s / 1200s — CPU first request is slow; watch: kubectl logs -n vllm -l app.kubernetes.io/instance=vllm -f)
==> Functional: inference job running (261s / 1200s — CPU first request is slow; watch: kubectl logs -n vllm -l app.kubernetes.io/instance=vllm -f)
==> Functional: inference job running (276s / 1200s — CPU first request is slow; watch: kubectl logs -n vllm -l app.kubernetes.io/instance=vllm -f)
==> Functional: inference job running (292s / 1200s — CPU first request is slow; watch: kubectl logs -n vllm -l app.kubernetes.io/instance=vllm -f)
==> Functional: inference job running (307s / 1200s — CPU first request is slow; watch: kubectl logs -n vllm -l app.kubernetes.io/instance=vllm -f)
==> Functional: inference job running (322s / 1200s — CPU first request is slow; watch: kubectl logs -n vllm -l app.kubernetes.io/instance=vllm -f)
==> Functional: inference job running (338s / 1200s — CPU first request is slow; watch: kubectl logs -n vllm -l app.kubernetes.io/instance=vllm -f)
==> Functional: inference job running (353s / 1200s — CPU first request is slow; watch: kubectl logs -n vllm -l app.kubernetes.io/instance=vllm -f)
==> Functional: ok
==> Gate 5: resource
==> Resource: model loaded, no OOM (vllm-bdb845fbd-d2gdd)
==> Ladder complete (gate 5 ok)
```

---

## Previous / Next

← [Phase 3](../phase3/README.md)

→ [Phase 5](../phase5/README.md)

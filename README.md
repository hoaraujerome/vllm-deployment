# vLLM deployment

Hands-on project to run [vLLM](https://docs.vllm.ai/) locally, then deploy it on Kubernetes — including bootstrapping the cluster from greenfield code.

## Project phases

| Phase | Goal | Status | Location |
| ----- | ---- | ------ | -------- |
| **1 — Local** | vLLM-Metal on Apple Silicon | Done | [`phase1/`](phase1/) |
| **2 — Cluster** | kubeadm cluster on AWS (EICE, kubectl on node) | Planned | [`phase2/`](phase2/) |
| **3 — WireGuard** | VPN access — laptop kubectl replaces EICE | Planned | [`phase3/`](phase3/) |
| **4 — vLLM deploy** | vLLM CPU; in-cluster API works | Planned | [`phase4/`](phase4/) |
| **5 — GPU** | NVIDIA/CUDA | Planned | TBD |
| **6 — Operate** | Expose externally; metrics | Planned | TBD |

```text
Phase 1        Phase 2           Phase 3          Phase 4         Phase 5        Phase 6
(local)        (cluster)         (WireGuard)      (vLLM)          (GPU)          (operate)
```

Reference architecture: `~/DEV/k8s-homelab` — greenfield code in this repo.

---

## Phase 1 — Local (done)

See [`phase1/README.md`](phase1/README.md).

---

## Phase 2 — Kubernetes cluster (planned)

See [`phase2/README.md`](phase2/README.md). Done when `phase2-check.sh` exits 0. Ops: **kubectl on node** via EICE. Tooling: **devbox** in `phase2/` (homelab pattern).

---

## Phase 3 — WireGuard (planned)

See [`phase3/README.md`](phase3/README.md). Done when `phase3-check.sh` exits 0 — **kubectl from laptop** over VPN.

---

## Phase 4 — vLLM on Kubernetes (planned)

See [`phase4/README.md`](phase4/README.md). Helm + `phase4-check.sh` from laptop (WireGuard).

---

## Repository layout

```text
vllm-deployment/
├── phase1/          # local vLLM-Metal
├── phase2/          # cluster factory (TF, Packer, kubeadm)
├── phase3/          # WireGuard access
└── phase4/          # vLLM workload (Helm, phase4-check.sh)
```

## Design notes

- **Phase 2 ops:** kubectl on node only (homelab smoke-test style).
- **Phase 3:** WireGuard unlocks laptop-native Helm/kubectl for Phase 4+.
- **Validation-driven:** each phase completes when its check script passes.

# Phase 6 — Expose and observe


**Status:** not started

**Prerequisite:** [Phase 5](../phase5/README.md) (GPU-backed in-cluster inference works)

---

## Done when

External client can call the inference API with acceptable latency.

---

## Mindset — Loop 3 (production feedback)

[Loop engineering](https://www.deeplearning.ai/the-batch/issue-359) **Loop 3** lives here: real signals drive architecture changes.

Signals: latency (p50/p95), GPU util, throughput, OOM, cost per million tokens.

---

## Checklist

- [ ] Ingress or Gateway API route
- [ ] Test inference from outside the cluster
- [ ] Baseline metrics: latency, GPU util, memory
- [ ] Note bottlenecks (autoscaling, caching, …)

---

## Scope ideas (after baseline)

| Follow-up | Why |
| --------- | --- |
| HPA / KEDA | scale on queue depth or custom metrics |
| PodDisruptionBudget | safe upgrades |
| Prometheus + Grafana | SLO dashboards |
| TLS + auth at ingress | production hardening |

See AI Inference on Kubernetes and K8s autoscaling.

---

## Previous

← [Phase 5](../phase5/README.md)

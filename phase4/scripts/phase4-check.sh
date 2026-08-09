#!/usr/bin/env bash
# Phase 4 validation ladder — vLLM CPU on the cluster (kubectl from laptop via WireGuard).
#
# Gates:
#   1. Static      — helm lint, yamllint (when chart exists)
#   2. Artifact    — vLLM CPU image reachable from cluster
#   3. Deploy      — helm upgrade --install, pod Ready
#   4. Functional  — in-cluster /v1/chat/completions
#   5. Resource    — model loaded, no OOM in logs
#
# Usage:
#   KUBE_CONTEXT=vllm-homelab ./phase4-check.sh
#   RELEASE=vllm NAMESPACE=vllm ./phase4-check.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PHASE4_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
CHART_DIR="${PHASE4_DIR}/helm/vllm"

KUBE_CONTEXT="${KUBE_CONTEXT:-}"
RELEASE="${RELEASE:-vllm}"
NAMESPACE="${NAMESPACE:-vllm}"

info() { echo "==> $*"; }
fail() { echo "ERROR: $*" >&2; exit 1; }

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || fail "missing required command: $1"
}

kubectl_ctx() {
  if [[ -n "$KUBE_CONTEXT" ]]; then
    kubectl --context "$KUBE_CONTEXT" "$@"
  else
    kubectl "$@"
  fi
}

gate_static() {
  info "Gate: static"
  if [[ ! -f "${CHART_DIR}/Chart.yaml" ]]; then
    fail "Helm chart not found at ${CHART_DIR} — add chart before running deploy gates"
  fi
  require_cmd helm
  helm lint "$CHART_DIR"
}

gate_not_implemented() {
  info "Phase 4 validation ladder stub — implement deploy/functional/resource gates after chart exists"
  info "Chart path: ${CHART_DIR}"
  info "Target context: ${KUBE_CONTEXT:-<current kubectl context>}"
  fail "remaining gates not implemented yet"
}

main() {
  require_cmd kubectl
  gate_static
  gate_not_implemented
}

main "$@"

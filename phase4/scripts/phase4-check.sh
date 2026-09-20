#!/usr/bin/env bash
# Phase 4 validation ladder — vLLM CPU on the cluster (kubectl from laptop via WireGuard).
#
# Prefer the Makefile entrypoint:
#   make check-gates
#   make check-deploy
#
# Gates:
#   1. Static      — helm lint
#   2. Artifact    — vLLM CPU image reachable from cluster
#   3. Deploy      — helm upgrade --install, pod Ready
#   4. Functional  — in-cluster /v1/chat/completions
#   5. Resource    — model loaded, no OOM in logs
#
# Skip: SKIP_GATE_<name>=1 — see --list-gates. Block shortcuts: SKIP_GATE_DEPLOY_BLOCK.
#
# Usage:
#   KUBECONFIG=~/.kube/vllm-phase2.conf ./phase4-check.sh
#   RELEASE=vllm NAMESPACE=vllm ./phase4-check.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PHASE4_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
CHART_DIR="${PHASE4_DIR}/helm/vllm"

KUBECONFIG="${KUBECONFIG:-${HOME}/.kube/vllm-phase2.conf}"
KUBE_CONTEXT="${KUBE_CONTEXT:-}"
RELEASE="${RELEASE:-vllm}"
NAMESPACE="${NAMESPACE:-vllm}"
DEPLOY_TIMEOUT="${DEPLOY_TIMEOUT:-1800}"
ARTIFACT_TIMEOUT="${ARTIFACT_TIMEOUT:-300}"
FUNCTIONAL_TIMEOUT="${FUNCTIONAL_TIMEOUT:-1200}"
CURL_MAX_TIME="${CURL_MAX_TIME:-900}"
ARTIFACT_JOB="${ARTIFACT_JOB:-phase4-image-pull}"
FUNCTIONAL_JOB="${FUNCTIONAL_JOB:-phase4-functional}"

info() { echo "==> $*"; }
fail() { echo "ERROR: $*" >&2; exit 1; }

gate_skip() {
  local flag="$1"
  local label="$2"
  if [[ "${!flag:-}" == "1" ]]; then
    info "Gate ${label} (skipped — ${flag}=1)"
    return 0
  fi
  return 1
}

apply_block_skip_flags() {
  if [[ "${SKIP_GATE_DEPLOY_BLOCK:-}" == "1" ]]; then
    export SKIP_GATE_ARTIFACT=1
    export SKIP_GATE_DEPLOY=1
    export SKIP_GATE_FUNCTIONAL=1
    export SKIP_GATE_RESOURCE=1
  fi
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || fail "missing required command: $1"
}

require_path() {
  local path="$1"
  local hint="$2"
  [[ -e "$path" ]] || fail "${path} not found — ${hint}"
}

kubectl_ctx() {
  if [[ -n "$KUBE_CONTEXT" ]]; then
    kubectl --kubeconfig="$KUBECONFIG" --context "$KUBE_CONTEXT" "$@"
  else
    kubectl --kubeconfig="$KUBECONFIG" "$@"
  fi
}

helm_ctx() {
  if [[ -n "$KUBE_CONTEXT" ]]; then
    helm --kubeconfig "$KUBECONFIG" --kube-context "$KUBE_CONTEXT" "$@"
  else
    helm --kubeconfig "$KUBECONFIG" "$@"
  fi
}

chart_image() {
  helm template "$RELEASE" "$CHART_DIR" \
    --namespace "$NAMESPACE" \
    --show-only templates/deployment.yaml \
    | awk '/^[[:space:]]*image:/{print $2; exit}'
}

chart_model() {
  awk '/^model:/{print $2; exit}' "${CHART_DIR}/values.yaml"
}

poll_until() {
  local label="$1"
  local timeout="$2"
  local interval="$3"
  shift 3
  local start=$SECONDS
  local output=""

  while (( SECONDS - start < timeout )); do
    if output="$("$@" 2>&1)"; then
      info "${label}: ok"
      if [[ -n "${output}" ]]; then
        echo "${output}" | sed 's/^/    /'
      fi
      return 0
    fi
    info "${label}: waiting ($((SECONDS - start))s / ${timeout}s) — $(echo "${output}" | tail -1)"
    sleep "${interval}"
  done

  echo "${output}" >&2
  fail "${label}: timed out after ${timeout}s"
}

gate_static() {
  gate_skip SKIP_GATE_STATIC "1: static" && return
  info "Gate 1: static"
  if [[ ! -f "${CHART_DIR}/Chart.yaml" ]]; then
    fail "Helm chart not found at ${CHART_DIR} — add chart before running deploy gates"
  fi
  require_cmd helm
  helm lint "$CHART_DIR"
}

gate_artifact() {
  gate_skip SKIP_GATE_ARTIFACT "2: artifact" && return
  info "Gate 2: artifact"
  require_cmd kubectl

  local image
  image="$(chart_image)"
  [[ -n "$image" ]] || fail "could not resolve chart image from ${CHART_DIR}"

  kubectl_ctx create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl_ctx apply -f - >/dev/null
  kubectl_ctx delete job "$ARTIFACT_JOB" -n "$NAMESPACE" --ignore-not-found >/dev/null

  kubectl_ctx apply -n "$NAMESPACE" -f - <<EOF
apiVersion: batch/v1
kind: Job
metadata:
  name: ${ARTIFACT_JOB}
spec:
  ttlSecondsAfterFinished: 300
  backoffLimit: 0
  template:
    spec:
      restartPolicy: Never
      containers:
        - name: pull
          image: ${image}
          imagePullPolicy: Always
          command: ["true"]
EOF

  poll_until "Artifact (image pull)" "$ARTIFACT_TIMEOUT" 15 artifact_ok
  kubectl_ctx delete job "$ARTIFACT_JOB" -n "$NAMESPACE" --ignore-not-found >/dev/null
}

artifact_ok() {
  if kubectl_ctx wait --for=condition=complete "job/${ARTIFACT_JOB}" -n "$NAMESPACE" --timeout=15s >/dev/null 2>&1; then
    return 0
  fi

  local failed
  failed="$(kubectl_ctx get job "$ARTIFACT_JOB" -n "$NAMESPACE" -o jsonpath='{.status.failed}' 2>/dev/null || true)"
  if [[ -n "$failed" && "$failed" != "0" ]]; then
    kubectl_ctx get events -n "$NAMESPACE" --sort-by='.lastTimestamp' 2>/dev/null | tail -8 >&2 || true
    fail "image pull job failed — upsize node (t4g.small lacks RAM/disk for vLLM CPU image)"
  fi

  if ! kubectl_ctx get job "$ARTIFACT_JOB" -n "$NAMESPACE" >/dev/null 2>&1; then
    fail "image pull job disappeared before completion"
  fi

  return 1
}

gate_deploy() {
  gate_skip SKIP_GATE_DEPLOY "3: deploy" && return
  info "Gate 3: deploy"
  require_cmd helm
  require_cmd kubectl
  require_path "$KUBECONFIG" "run: cd ../phase3 && make fetch-kubeconfig (WireGuard connected)"

  helm_ctx upgrade --install "$RELEASE" "$CHART_DIR" \
    --namespace "$NAMESPACE" \
    --create-namespace \
    --atomic \
    --wait \
    --timeout "${DEPLOY_TIMEOUT}s"

  local deploy_name
  deploy_name="$(kubectl_ctx get deploy -n "$NAMESPACE" -l "app.kubernetes.io/instance=${RELEASE}" -o jsonpath='{.items[0].metadata.name}')"
  [[ -n "$deploy_name" ]] || fail "deployment for release ${RELEASE} not found in ${NAMESPACE}"

  kubectl_ctx rollout status "deployment/${deploy_name}" -n "$NAMESPACE" --timeout="${DEPLOY_TIMEOUT}s"

  local ready_line
  ready_line="$(kubectl_ctx get pods -n "$NAMESPACE" -l "app.kubernetes.io/instance=${RELEASE}" --no-headers | head -1)"
  [[ -n "$ready_line" ]] || fail "no pod found for release ${RELEASE}"
  echo "$ready_line" | awk '{print "    "$0}'
  echo "$ready_line" | awk '{exit ($2 != "1/1" || $3 != "Running")}'
}

functional_submit_job() {
  local model="$1"
  local service_name="$2"
  local payload payload_yaml

  payload="$(jq -nc --arg model "$model" \
    '{model: $model, messages: [{role: "user", content: "Say hello in one word."}], max_tokens: 4}')"
  payload_yaml="$(printf '%s' "$payload" | sed 's/"/\\"/g')"

  kubectl_ctx delete pod phase4-curl -n "$NAMESPACE" --ignore-not-found --wait=true >/dev/null 2>&1 || true
  kubectl_ctx delete job "$FUNCTIONAL_JOB" -n "$NAMESPACE" --ignore-not-found --wait=true >/dev/null 2>&1 || true

  kubectl_ctx apply -n "$NAMESPACE" -f - <<EOF
apiVersion: batch/v1
kind: Job
metadata:
  name: ${FUNCTIONAL_JOB}
spec:
  ttlSecondsAfterFinished: 300
  backoffLimit: 0
  template:
    spec:
      restartPolicy: Never
      containers:
        - name: curl
          image: curlimages/curl:8.12.1
          env:
            - name: CURL_PAYLOAD
              value: "${payload_yaml}"
          command:
            - sh
            - -c
            - |
              curl -sf --max-time ${CURL_MAX_TIME} \\
                -H "Content-Type: application/json" \\
                -d "\${CURL_PAYLOAD}" \\
                "http://${service_name}:8000/v1/chat/completions"
EOF
}

functional_wait_job() {
  local max_wait="$1"
  local start=$SECONDS
  local succeeded failed

  while (( SECONDS - start < max_wait )); do
    succeeded="$(kubectl_ctx get job "$FUNCTIONAL_JOB" -n "$NAMESPACE" -o jsonpath='{.status.succeeded}' 2>/dev/null || echo 0)"
    failed="$(kubectl_ctx get job "$FUNCTIONAL_JOB" -n "$NAMESPACE" -o jsonpath='{.status.failed}' 2>/dev/null || echo 0)"
    if [[ "${succeeded:-0}" == "1" ]]; then
      return 0
    fi
    if [[ -n "$failed" && "$failed" != "0" ]]; then
      return 1
    fi
    info "Functional: inference job running ($((SECONDS - start))s / ${max_wait}s — CPU first request is slow; watch: kubectl logs -n ${NAMESPACE} -l app.kubernetes.io/instance=${RELEASE} -f)"
    sleep 15
  done
  return 1
}

gate_functional() {
  gate_skip SKIP_GATE_FUNCTIONAL "4: functional" && return
  info "Gate 4: functional (in-cluster /v1/chat/completions)"
  require_cmd kubectl
  require_cmd jq

  local model service_name response
  model="$(chart_model)"
  service_name="$(kubectl_ctx get svc -n "$NAMESPACE" -l "app.kubernetes.io/instance=${RELEASE}" -o jsonpath='{.items[0].metadata.name}')"
  [[ -n "$model" ]] || fail "could not resolve model from chart"
  [[ -n "$service_name" ]] || fail "service for release ${RELEASE} not found in ${NAMESPACE}"

  functional_submit_job "$model" "$service_name"
  if ! functional_wait_job "$FUNCTIONAL_TIMEOUT"; then
    kubectl_ctx logs "job/${FUNCTIONAL_JOB}" -n "$NAMESPACE" --tail=30 >&2 || true
    fail "inference job failed or timed out after ${FUNCTIONAL_TIMEOUT}s — check vLLM logs for EngineCore / RPC timeout"
  fi

  response="$(kubectl_ctx logs "job/${FUNCTIONAL_JOB}" -n "$NAMESPACE")"
  echo "$response" | jq -e '.choices[0].message.content' >/dev/null || {
    echo "$response" >&2
    fail "chat response missing .choices[0].message.content"
  }
  info "Functional: ok"
  kubectl_ctx delete job "$FUNCTIONAL_JOB" -n "$NAMESPACE" --ignore-not-found >/dev/null
}

gate_resource() {
  gate_skip SKIP_GATE_RESOURCE "5: resource" && return
  info "Gate 5: resource"

  local pod_name oom_reason logs
  pod_name="$(kubectl_ctx get pods -n "$NAMESPACE" -l "app.kubernetes.io/instance=${RELEASE}" -o jsonpath='{.items[0].metadata.name}')"
  [[ -n "$pod_name" ]] || fail "no pod found for release ${RELEASE}"

  oom_reason="$(kubectl_ctx get pod "$pod_name" -n "$NAMESPACE" -o jsonpath='{.status.containerStatuses[0].lastState.terminated.reason}' 2>/dev/null || true)"
  if [[ "$oom_reason" == "OOMKilled" ]]; then
    kubectl_ctx logs "$pod_name" -n "$NAMESPACE" --tail=80 >&2 || true
    fail "pod ${pod_name} was OOMKilled — upsize node or reduce memory in values.yaml"
  fi

  # Scan from log start (grep -m1 stops at first hit); --tail=200 misses startup once
  # health probes have filled the buffer (common after gate 4's long inference wait).
  logs="$(kubectl_ctx logs "$pod_name" -n "$NAMESPACE" 2>/dev/null || true)"
  if echo "$logs" | grep -qiE 'out of memory|Cannot allocate memory|OOMKilled'; then
    kubectl_ctx logs "$pod_name" -n "$NAMESPACE" --tail=80 >&2 || true
    fail "OOM indicators in pod logs for ${pod_name}"
  fi

  if echo "$logs" | grep -m1 -qiE 'Application startup complete|Uvicorn running|Started server process'; then
    info "Resource: model loaded, no OOM (${pod_name})"
    return
  fi

  if echo "$logs" | grep -m1 -qE 'POST /v1/chat/completions HTTP/[0-9.]+" 200'; then
    info "Resource: inference confirmed in logs, no OOM (${pod_name})"
    return
  fi

  kubectl_ctx logs "$pod_name" -n "$NAMESPACE" --tail=40 >&2 || true
  fail "model startup not confirmed in logs for ${pod_name} (pod may still be compiling — check full logs)"
}

main() {
  export KUBECONFIG
  apply_block_skip_flags

  gate_static
  gate_artifact
  gate_deploy
  gate_functional
  gate_resource
  info "Ladder complete (gate 5 ok)"
}

list_gates() {
  cat <<'EOF'
Phase 4 validation gates (make check → phase4-check.sh)

  Gate   Block    Name                         Skip flag
  ----   -----    ----                         ---------
  1               Static (helm lint)           SKIP_GATE_STATIC
  2      Deploy   Artifact (image pull)        SKIP_GATE_ARTIFACT
  3      Deploy   Deploy (helm + pod Ready)    SKIP_GATE_DEPLOY
  4      Deploy   Functional (chat API)        SKIP_GATE_FUNCTIONAL
  5      Deploy   Resource (model + no OOM)    SKIP_GATE_RESOURCE

Block shortcuts:
  SKIP_GATE_DEPLOY_BLOCK=1         gates 2–5

Presets:
  make check-chart                 gate 1 only
  make check-deploy                full ladder (gates 1–5)

Environment:
  KUBECONFIG                       default ~/.kube/vllm-phase2.conf
  RELEASE / NAMESPACE              default vllm / vllm
  DEPLOY_TIMEOUT                   default 1800s (helm --atomic --wait)
  FUNCTIONAL_TIMEOUT               default 1200s (CPU first inference is slow)
  CURL_MAX_TIME                    default 900s per in-cluster curl Job
EOF
}

case "${1:-}" in
  --list-gates)
    list_gates
    ;;
  *)
    main "$@"
    ;;
esac

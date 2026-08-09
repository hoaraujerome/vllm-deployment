#!/usr/bin/env bash
# Phase 2 validation ladder — functional Kubernetes cluster on AWS.
#
# Gates:
#   1. TF static     — terraform fmt -check, validate
#   2. TF plan       — terraform plan (optional skip with SKIP_TF_PLAN=1)
#   3. Provision     — terraform apply (skip with SKIP_TF_APPLY=1 if infra exists)
#   4. Ansible static — ansible-playbook --syntax-check
#   5. Bootstrap     — ansible playbooks (skip with SKIP_ANSIBLE=1 if configured)
#   6. Cluster       — kubectl get nodes → all Ready
#   7. Smoke         — test pod Ready
#
# Usage:
#   ./phase2-check.sh
#   KUBECONFIG=~/.kube/vllm-phase2.conf ./phase2-check.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PHASE2_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
TF_DIR="${PHASE2_DIR}/provisioning/envs/dev"
ANSIBLE_DIR="${PHASE2_DIR}/configuration"

info() { echo "==> $*"; }
fail() { echo "ERROR: $*" >&2; exit 1; }

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || fail "missing required command: $1"
}

gate_tf_static() {
  info "Gate: TF static"
  if [[ ! -d "$TF_DIR" ]]; then
    fail "Terraform root not found at ${TF_DIR} — scaffold provisioning/envs/dev first"
  fi
  require_cmd terraform
  terraform -chdir="$TF_DIR" fmt -check -recursive
  terraform -chdir="$TF_DIR" init -backend=false >/dev/null
  terraform -chdir="$TF_DIR" validate
}

gate_tf_plan() {
  if [[ "${SKIP_TF_PLAN:-}" == "1" ]]; then
    info "Gate: TF plan (skipped)"
    return
  fi
  info "Gate: TF plan"
  terraform -chdir="$TF_DIR" plan -input=false
}

gate_tf_apply() {
  if [[ "${SKIP_TF_APPLY:-}" == "1" ]]; then
    info "Gate: provision (skipped — SKIP_TF_APPLY=1)"
    return
  fi
  info "Gate: provision"
  fail "terraform apply not wired yet — implement after envs/dev exists"
}

gate_ansible_static() {
  info "Gate: Ansible static"
  if [[ ! -d "${ANSIBLE_DIR}/playbooks" ]]; then
    fail "Ansible playbooks not found at ${ANSIBLE_DIR}/playbooks"
  fi
  require_cmd ansible-playbook
  local playbook
  shopt -s nullglob
  local playbooks=("${ANSIBLE_DIR}"/playbooks/*.yaml "${ANSIBLE_DIR}"/playbooks/*.yml)
  shopt -u nullglob
  if [[ ${#playbooks[@]} -eq 0 ]]; then
    fail "no playbooks in ${ANSIBLE_DIR}/playbooks — add bootstrap playbooks"
  fi
  for playbook in "${playbooks[@]}"; do
    ansible-playbook "$playbook" --syntax-check
  done
}

gate_not_implemented() {
  info "Phase 2 validation ladder stub — implement bootstrap/cluster/smoke gates after Ansible exists"
  fail "remaining gates not implemented yet"
}

main() {
  gate_tf_static
  gate_tf_plan
  gate_tf_apply
  gate_ansible_static
  gate_not_implemented
}

main "$@"

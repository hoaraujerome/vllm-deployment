#!/usr/bin/env bash
# Phase 3 validation ladder — WireGuard VPN replaces EICE for laptop kubectl.
#
# Prefer the Makefile entrypoint:
#   make check-gates
#   make check-toolchain
#
# Bootstrap: cloud-init in Terraform user_data (no Packer/Ansible).
#
# Gates:
#   1  Devbox
#   Provisioning block:
#   2  Infra plan       3  Infra apply (RUN_PROVISIONING_APPLY=1)
#   Runtime (laptop — WireGuard connected):
#   4  VPN              5  Cluster (kubectl)   6  EICE-free
#
# Skip: SKIP_GATE_<name>=1 — see --list-gates. Block shortcuts: SKIP_GATE_PROVISIONING_BLOCK,
#   SKIP_GATE_RUNTIME_BLOCK.
#
# Usage:
#   ./scripts/phase3-check.sh
#   KUBECONFIG=~/.kube/vllm-phase2.conf ./scripts/phase3-check.sh
#   SKIP_GATE_PROVISIONING_BLOCK=1 ./scripts/phase3-check.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PHASE3_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
PROVISIONING_TF_DIR="${PHASE3_DIR}/vpn/infra/main-account/ca-central-1/prod"
AWS_PROFILE="${AWS_PROFILE:-k8s_homelab}"
AWS_REGION="${AWS_REGION:-ca-central-1}"
KUBECONFIG="${KUBECONFIG:-${HOME}/.kube/vllm-phase2.conf}"
WG_INTERFACE="${WG_INTERFACE:-utun3}"

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
  if [[ "${SKIP_GATE_PROVISIONING_BLOCK:-}" == "1" ]]; then
    export SKIP_GATE_INFRA_PLAN=1
    export SKIP_GATE_INFRA_APPLY=1
  fi
  if [[ "${SKIP_GATE_RUNTIME_BLOCK:-}" == "1" ]]; then
    export SKIP_GATE_VPN=1
    export SKIP_GATE_CLUSTER=1
    export SKIP_GATE_EICE_FREE=1
  fi
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || fail "missing required command: $1 (run devbox shell)"
}

require_version() {
  local label="$1"
  local expected="$2"
  local actual="${3#v}"
  if [[ "$actual" != "$expected" ]]; then
    fail "${label} must be ${expected} (got ${actual}) — run devbox shell"
  fi
}

require_path() {
  local path="$1"
  local hint="$2"
  [[ -e "$path" ]] || fail "${path} not found — ${hint}"
}

gate_devbox() {
  gate_skip SKIP_GATE_DEVBOX "1: devbox toolchain" && return
  info "Gate 1: devbox toolchain"
  require_cmd terraform
  require_cmd aws
  require_cmd jq
  require_cmd trivy
  require_cmd pre-commit
  require_cmd git
  require_cmd wg
  require_cmd kubectl

  require_version "terraform" "1.15.3" "$(terraform version -json | jq -r '.terraform_version')"
  require_version "awscli2" "2.34.24" "$(aws --version 2>&1 | awk '{print $1}' | cut -d/ -f2)"
  require_version "jq" "1.8.2" "$(jq --version | sed 's/^jq-//')"
  require_version "trivy" "0.72.0" "$(trivy --version 2>&1 | awk '/^Version:/ {print $2}')"
  require_version "pre-commit" "4.5.1" "$(pre-commit --version 2>&1 | awk '{print $2}')"
  require_version "git" "2.54.0" "$(git --version | awk '{print $3}')"
  require_version "wireguard-tools" "1.0.20210914" "$(wg version 2>&1 | awk '{print $2}' | sed 's/^v//')"
  require_version "kubectl" "1.36.0" "$(kubectl version --client=true -o json 2>/dev/null | jq -r '.clientVersion.gitVersion' | sed 's/^v//')"
}

gate_infra_plan() {
  gate_skip SKIP_GATE_INFRA_PLAN "2: provisioning infra plan" && return
  info "Gate 2: provisioning infra plan"
  require_path "${PROVISIONING_TF_DIR}" "scaffold phase3/vpn/infra/main-account/ca-central-1/prod (cloud-init user_data)"
  (
    cd "${PROVISIONING_TF_DIR}"
    terraform fmt -check -recursive
    terraform init -input=false
    terraform validate
    trivy config --exit-code 1 .
    terraform plan -input=false -out=/dev/null
  )
}

gate_infra_apply() {
  gate_skip SKIP_GATE_INFRA_APPLY "3: provisioning infra apply" && return
  if [[ "${RUN_PROVISIONING_APPLY:-}" != "1" ]]; then
    info "Gate 3: provisioning infra apply (skipped — set RUN_PROVISIONING_APPLY=1 to apply)"
    return
  fi
  info "Gate 3: provisioning infra apply"
  require_path "${PROVISIONING_TF_DIR}" "scaffold phase3/vpn/infra/main-account/ca-central-1/prod (cloud-init user_data)"
  (
    cd "${PROVISIONING_TF_DIR}"
    terraform init -input=false
    terraform apply -input=false -auto-approve
  )
}

gate_vpn() {
  gate_skip SKIP_GATE_VPN "4: VPN (WireGuard interface up)" && return
  info "Gate 4: VPN (WireGuard interface up)"
  if ! wg show "${WG_INTERFACE}" >/dev/null 2>&1; then
    if ! wg show >/dev/null 2>&1; then
      fail "WireGuard interface not up — connect VPN (wg show ${WG_INTERFACE} failed; override WG_INTERFACE if needed)"
    fi
    info "WireGuard active (default interface; WG_INTERFACE=${WG_INTERFACE} not found)"
  fi
  wg show "${WG_INTERFACE}" 2>/dev/null || wg show
}

gate_cluster() {
  gate_skip SKIP_GATE_CLUSTER "5: cluster (kubectl from laptop)" && return
  info "Gate 5: cluster (kubectl from laptop)"
  require_path "${KUBECONFIG}" "copy kubeconfig to ${KUBECONFIG} (fetch admin.conf via EICE once)"
  kubectl --kubeconfig="${KUBECONFIG}" get nodes
}

gate_eice_free() {
  gate_skip SKIP_GATE_EICE_FREE "6: EICE-free runtime path" && return
  info "Gate 6: EICE-free runtime path"
  if grep -q 'ec2-instance-connect open-tunnel' "${BASH_SOURCE[0]}"; then
    fail "phase3-check.sh must not call ec2-instance-connect for routine runtime gates"
  fi
  info "Runtime gates 4–6 use WireGuard + kubectl only (no EICE in this script)"
}

main() {
  export AWS_PROFILE
  export AWS_DEFAULT_REGION="${AWS_REGION}"
  export AWS_REGION

  apply_block_skip_flags

  gate_devbox
  gate_infra_plan
  gate_infra_apply
  gate_vpn
  gate_cluster
  gate_eice_free
  info "Ladder complete (gate 6 ok)"
}

list_gates() {
  cat <<'EOF'
Phase 3 validation gates (make check → phase3-check.sh)

  Gate   Block          Name                    Skip flag
  ----   -----          ----                    ---------
  1                     Devbox                  SKIP_GATE_DEVBOX
  2      Provisioning   Infra plan              SKIP_GATE_INFRA_PLAN
  3      Provisioning   Infra apply             SKIP_GATE_INFRA_APPLY
  4      Runtime        VPN (wg show)           SKIP_GATE_VPN
  5      Runtime        Cluster (kubectl)       SKIP_GATE_CLUSTER
  6      Runtime        EICE-free path          SKIP_GATE_EICE_FREE

Block shortcuts:
  SKIP_GATE_PROVISIONING_BLOCK=1   gates 2–3
  SKIP_GATE_RUNTIME_BLOCK=1        gates 4–6

Opt-in:
  RUN_PROVISIONING_APPLY=1         gate 3 terraform apply

Presets:
  make check-toolchain             gate 1 only
  make check-provisioning          gates 1–3
  make check-vpn                   gates 1, 4–6 (WireGuard connected)
  make check-full                  all gates + RUN_PROVISIONING_APPLY=1

Bootstrap: cloud-init in Terraform user_data — no Packer/Ansible.
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

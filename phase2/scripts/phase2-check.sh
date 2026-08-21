#!/usr/bin/env bash
# Phase 2 validation ladder — functional Kubernetes cluster on AWS.
#
# Gates (keep in sync with Phase 2 — Kubernetes cluster.md):
#   0. Devbox        — pinned toolchain from devbox.json (run from devbox shell)
#   1. Ansible syntax — ansible-playbook --syntax-check on images/config/ansible/ami.yaml
#   1b. Ansible lint   — ansible-lint ami.yaml in images/config/ansible/
#   2. TF static     — cluster live: terraform fmt -check, validate
#   3. TF plan       — cluster live: terraform plan (skip with SKIP_TF_PLAN=1)
#   3a. AMI apply    — ./images/setup-images.sh deploy (fmt, validate, trivy, TF plan + apply)
#   3b. AMI artifact — base AMI exists in AWS (or RUN_PACKER_BUILD=1 → setup-images build)
#   4. Provision     — cluster terraform apply (skip with SKIP_TF_APPLY=1)
#   5. Bootstrap     — kubeadm init + Cilium on node (skip with SKIP_ANSIBLE=1)
#   6. Cluster       — kubectl get nodes → all Ready
#   7. Smoke         — test pod Ready
#
# Skips:
#   SKIP_CLUSTER_TF=1         — skip gates 2–3
#   SKIP_AMI_ANSIBLE_SYNTAX=1 — skip gate 1 only
#   SKIP_AMI_ANSIBLE_LINT=1   — skip gate 1b only
#   SKIP_AMI=1           — skip gates 3a + 3b
#   SKIP_AMI_PLAN=1      — skip gate 3a only
#   SKIP_AMI_ARTIFACT=1  — skip gate 3b only (TF/plan work without AMI in AWS)
#   SKIP_TF_PLAN=1       — skip gate 2 only
#   SKIP_TF_APPLY=1      — skip gate 4
#   SKIP_ANSIBLE=1       — skip gate 5
#
# AMI env:
#   AWS_PROFILE (default k8s_homelab), AWS_REGION, AMI_NAME_PREFIX (default vllm-phase2-kubeadm)
#   RUN_PACKER_BUILD=1   — run ./images/setup-images.sh build if AMI missing
#
# Usage:
#   ./scripts/phase2-check.sh
#   SKIP_CLUSTER_TF=1 SKIP_AMI_ARTIFACT=1 ./scripts/phase2-check.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PHASE2_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
SETUP_IMAGES="${PHASE2_DIR}/images/setup-images.sh"
AMI_ANSIBLE_DIR="${PHASE2_DIR}/images/config/ansible"
AMI_PLAYBOOK="${AMI_ANSIBLE_DIR}/ami.yaml"
CLUSTER_TF_DIR="${PHASE2_DIR}/provisioning/envs/dev"
BOOTSTRAP_ANSIBLE_DIR="${PHASE2_DIR}/configuration"
AWS_PROFILE="${AWS_PROFILE:-k8s_homelab}"
AWS_REGION="${AWS_REGION:-ca-central-1}"
AMI_NAME_PREFIX="${AMI_NAME_PREFIX:-vllm-phase2-kubeadm}"

info() { echo "==> $*"; }
fail() { echo "ERROR: $*" >&2; exit 1; }

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

gate_devbox() {
  info "Gate: devbox toolchain"
  require_cmd terraform
  require_cmd packer
  require_cmd ansible-playbook
  require_cmd ansible-lint
  require_cmd aws
  require_cmd jq
  require_cmd trivy
  require_cmd pre-commit
  require_cmd git

  require_version "terraform" "1.15.3" "$(terraform version -json | jq -r '.terraform_version')"
  require_version "packer" "1.15.3" "$(packer version 2>&1 | awk 'NR==1 {print $2}')"
  require_version "ansible" "2.21.1" "$(ansible --version 2>&1 | head -1 | sed -E 's/.*\[core ([0-9.]+)\].*/\1/')"
  require_version "ansible-lint" "25.8.2" "$(ansible-lint --version 2>&1 | awk '/ansible-lint/{print $2}')"
  require_version "awscli2" "2.34.24" "$(aws --version 2>&1 | awk '{print $1}' | cut -d/ -f2)"
  require_version "jq" "1.8.2" "$(jq --version | sed 's/^jq-//')"
  require_version "trivy" "0.72.0" "$(trivy --version 2>&1 | awk '/^Version:/ {print $2}')"
  require_version "pre-commit" "4.5.1" "$(pre-commit --version 2>&1 | awk '{print $2}')"
  require_version "git" "2.54.0" "$(git --version | awk '{print $3}')"
}

gate_ansible_syntax() {
  if [[ "${SKIP_AMI_ANSIBLE_SYNTAX:-}" == "1" ]]; then
    info "Gate: Ansible syntax (skipped — SKIP_AMI_ANSIBLE_SYNTAX=1)"
    return
  fi
  info "Gate: Ansible syntax (AMI bake)"
  if [[ ! -f "$AMI_PLAYBOOK" ]]; then
    fail "AMI playbook not found at ${AMI_PLAYBOOK}"
  fi
  (
    cd "$AMI_ANSIBLE_DIR"
    ansible-playbook --syntax-check -i "default," ami.yaml
  )
}

gate_ansible_lint() {
  if [[ "${SKIP_AMI_ANSIBLE_LINT:-}" == "1" ]]; then
    info "Gate: Ansible lint (skipped — SKIP_AMI_ANSIBLE_LINT=1)"
    return
  fi
  info "Gate: Ansible lint (AMI bake)"
  if [[ ! -f "$AMI_PLAYBOOK" ]]; then
    fail "AMI playbook not found at ${AMI_PLAYBOOK}"
  fi
  (
    cd "$AMI_ANSIBLE_DIR"
    # ansible-lint pulls pathspec on Python 3.14 (devbox/nix); GitWildMatchPattern
    # deprecations are upstream noise — not playbook findings.
    lint_output="$(ansible-lint ami.yaml 2>&1)" || {
      echo "$lint_output"
      exit 1
    }
    if [[ -n "$lint_output" ]]; then
      echo "$lint_output" | grep -vE \
        'GitWildMatchPattern|pathspec/(pathspec|pattern)\.py|patterns = \[use_factory|raw_regex, include = self\.pattern_to_regex' \
        || true
    fi
  )
}

gate_tf_static() {
  info "Gate: TF static (cluster live)"
  if [[ ! -d "$CLUSTER_TF_DIR" ]]; then
    fail "cluster live TF not found at ${CLUSTER_TF_DIR} — scaffold provisioning/envs/dev first"
  fi
  terraform -chdir="$CLUSTER_TF_DIR" fmt -check -recursive
  terraform -chdir="$CLUSTER_TF_DIR" init -backend=false >/dev/null
  terraform -chdir="$CLUSTER_TF_DIR" validate
}

gate_tf_plan() {
  if [[ "${SKIP_TF_PLAN:-}" == "1" ]]; then
    info "Gate: TF plan (skipped)"
    return
  fi
  info "Gate: TF plan (cluster live)"
  terraform -chdir="$CLUSTER_TF_DIR" plan -input=false
}

ami_image_count() {
  aws ec2 describe-images \
    --owners self \
    --region "$AWS_REGION" \
    --filters "Name=name,Values=${AMI_NAME_PREFIX}*" "Name=state,Values=available" \
    --query 'length(Images)' \
    --output text 2>/dev/null || echo "0"
}

ami_newest_image_id() {
  aws ec2 describe-images \
    --owners self \
    --region "$AWS_REGION" \
    --filters "Name=name,Values=${AMI_NAME_PREFIX}*" "Name=state,Values=available" \
    --query 'sort_by(Images, &CreationDate)[-1].ImageId' \
    --output text 2>/dev/null || echo "None"
}

gate_ami_plan() {
  if [[ "${SKIP_AMI_PLAN:-}" == "1" ]]; then
    info "Gate: AMI apply (skipped — SKIP_AMI_PLAN=1)"
    return
  fi
  info "Gate: AMI apply (3a)"
  if [[ ! -x "$SETUP_IMAGES" ]]; then
    fail "AMI orchestrator not found or not executable: ${SETUP_IMAGES}"
  fi
  "$SETUP_IMAGES" deploy
}

gate_ami_artifact() {
  if [[ "${SKIP_AMI_ARTIFACT:-}" == "1" ]]; then
    info "Gate: AMI artifact (skipped — SKIP_AMI_ARTIFACT=1)"
    return
  fi
  info "Gate: AMI artifact (3b)"

  local count image_id
  count="$(ami_image_count)"
  if [[ "$count" != "0" && "$count" != "None" ]]; then
    image_id="$(ami_newest_image_id)"
    info "AMI artifact: base AMI found — ${image_id} (prefix ${AMI_NAME_PREFIX}*, ${AWS_REGION})"
    return
  fi

  if [[ "${RUN_PACKER_BUILD:-}" == "1" ]]; then
    info "AMI artifact: no AMI found — running ./images/setup-images.sh build"
    "$SETUP_IMAGES" build
    count="$(ami_image_count)"
    if [[ "$count" == "0" || "$count" == "None" ]]; then
      fail "setup-images build finished but no available AMI matching ${AMI_NAME_PREFIX}* in ${AWS_REGION}"
    fi
    image_id="$(ami_newest_image_id)"
    info "AMI artifact: base AMI built — ${image_id}"
    return
  fi

  fail "no available AMI matching ${AMI_NAME_PREFIX}* in ${AWS_REGION} — run: RUN_PACKER_BUILD=1 ./scripts/phase2-check.sh (or ./images/setup-images.sh build)"
}

gate_ami() {
  if [[ "${SKIP_AMI:-}" == "1" ]]; then
    info "Gate: AMI (skipped — SKIP_AMI=1)"
    return
  fi
  gate_ami_plan
  gate_ami_artifact
}

gate_tf_apply() {
  if [[ "${SKIP_TF_APPLY:-}" == "1" ]]; then
    info "Gate: provision (skipped — SKIP_TF_APPLY=1)"
    return
  fi
  info "Gate: provision (cluster live)"
  fail "terraform apply not wired yet — implement after provisioning/envs/dev exists"
}

gate_bootstrap() {
  if [[ "${SKIP_ANSIBLE:-}" == "1" ]]; then
    info "Gate: bootstrap (skipped — SKIP_ANSIBLE=1)"
    return
  fi
  info "Gate: bootstrap"
  if [[ ! -d "${BOOTSTRAP_ANSIBLE_DIR}/playbooks" ]]; then
    fail "runtime Ansible playbooks not found at ${BOOTSTRAP_ANSIBLE_DIR}/playbooks"
  fi
  shopt -s nullglob
  local playbooks=("${BOOTSTRAP_ANSIBLE_DIR}"/playbooks/*.yaml "${BOOTSTRAP_ANSIBLE_DIR}"/playbooks/*.yml)
  shopt -u nullglob
  if [[ ${#playbooks[@]} -eq 0 ]]; then
    fail "no playbooks in ${BOOTSTRAP_ANSIBLE_DIR}/playbooks — add kubeadm bootstrap playbooks"
  fi
  for playbook in "${playbooks[@]}"; do
    ansible-playbook "$playbook" --syntax-check
  done
  fail "bootstrap playbooks exist but kubeadm + Cilium on node not wired yet"
}

gate_not_implemented() {
  info "Gate: cluster + smoke not implemented yet"
  fail "implement kubectl get nodes and smoke pod checks after bootstrap"
}

main() {
  export AWS_PROFILE
  export AWS_DEFAULT_REGION="${AWS_REGION}"
  export AWS_REGION

  gate_devbox
  gate_ansible_syntax
  gate_ansible_lint
  if [[ "${SKIP_CLUSTER_TF:-}" == "1" ]]; then
    info "Gate: TF static + plan (skipped — SKIP_CLUSTER_TF=1)"
  else
    gate_tf_static
    gate_tf_plan
  fi
  gate_ami
  gate_tf_apply
  gate_bootstrap
  gate_not_implemented
}

main "$@"

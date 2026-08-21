#!/usr/bin/env bash
# Cluster infrastructure orchestrator — Terraform live root for kubeadm on AWS.
#
# Prefer the Makefile (phase2/):
#   make cluster-infra-plan | cluster-infra-validate | cluster-infra-deploy | cluster-infra-destroy
#
# Direct invocation (Makefile recipes only — not from phase2-check.sh):
#   ./cluster/setup-cluster.sh plan | deploy | destroy
#
# plan:   terraform fmt -check, validate modules + live, trivy, terraform plan
# deploy: plan + terraform apply (cluster VPC, NAT, EICE, EC2)
# destroy: terraform destroy on cluster live root
#
# Env:
#   AWS_PROFILE  — default k8s_homelab
#   AWS_REGION   — default ca-central-1
#   SKIP_TRIVY=1 — skip trivy fs scan
#   TF_VAR_ssh_public_key_path — default ${HOME}/.ssh/id_rsa_k8s_homelab.pub
#   TF_VAR_ami_name_prefix     — default vllm-phase2-kubeadm

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PHASE2_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
MODULES_INFRA_DIR="${PHASE2_DIR}/modules/infra"
CLUSTER_MODULES_DIR="${PHASE2_DIR}/cluster/infra/modules"
CLUSTER_TF_DIR="${PHASE2_DIR}/cluster/infra/main-account/ca-central-1/prod"
AWS_PROFILE="${AWS_PROFILE:-k8s_homelab}"
AWS_REGION="${AWS_REGION:-ca-central-1}"
AMI_NAME_PREFIX="${AMI_NAME_PREFIX:-vllm-phase2-kubeadm}"

log() { echo "==> $*"; }

usage() {
  cat <<EOF
Usage: $(basename "$0") <plan|deploy|destroy|validate>

  plan     fmt + validate + trivy + terraform plan (cluster live)
  validate fmt + validate + trivy (no terraform plan)
  deploy   plan + terraform apply
  destroy  terraform destroy (cluster infra only)
EOF
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "ERROR: missing required command: $1 (run devbox shell)" >&2
    exit 1
  }
}

setup_terraform_vars() {
  export TF_VAR_ssh_public_key_path="${TF_VAR_ssh_public_key_path:-${HOME}/.ssh/id_rsa_k8s_homelab.pub}"
  export TF_VAR_ami_name_prefix="${TF_VAR_ami_name_prefix:-${AMI_NAME_PREFIX}}"
}

check_terraform_fmt() {
  log "Check terraform fmt"
  require_cmd terraform
  terraform fmt -check -recursive \
    "${MODULES_INFRA_DIR}" \
    "${CLUSTER_MODULES_DIR}" \
    "${CLUSTER_TF_DIR}"
}

validate_modules() {
  log "Validate modules"
  local module_dir
  shopt -s nullglob
  local modules=(
    "${MODULES_INFRA_DIR}"/*/
    "${CLUSTER_MODULES_DIR}"/*/
  )
  shopt -u nullglob
  if [[ ${#modules[@]} -eq 0 ]]; then
    echo "ERROR: no modules under ${MODULES_INFRA_DIR} or ${CLUSTER_MODULES_DIR}" >&2
    exit 1
  fi
  for module_dir in "${modules[@]}"; do
    log "... ${module_dir}"
    terraform -chdir="${module_dir}" init -backend=false >/dev/null
    terraform -chdir="${module_dir}" validate
  done
}

validate_live() {
  log "Validate cluster live root"
  if [[ ! -d "${CLUSTER_TF_DIR}" ]]; then
    echo "ERROR: cluster live TF not found at ${CLUSTER_TF_DIR}" >&2
    exit 1
  fi
  terraform -chdir="${CLUSTER_TF_DIR}" init -backend=false >/dev/null
  terraform -chdir="${CLUSTER_TF_DIR}" validate
}

run_trivy() {
  if [[ "${SKIP_TRIVY:-}" == "1" ]]; then
    log "Trivy scan (skipped — SKIP_TRIVY=1)"
    return
  fi
  require_cmd trivy
  local target
  for target in "${MODULES_INFRA_DIR}" "${CLUSTER_MODULES_DIR}" "${CLUSTER_TF_DIR}"; do
    log "Run trivy fs on ${target}"
    trivy fs \
      --scanners secret,misconfig \
      --exit-code 1 \
      "${target}"
  done
}

run_terraform_plan() {
  log "Run terraform plan (cluster live)"
  setup_terraform_vars
  terraform -chdir="${CLUSTER_TF_DIR}" init -input=false >/dev/null
  terraform -chdir="${CLUSTER_TF_DIR}" plan -input=false
}

plan_infra() {
  check_terraform_fmt
  validate_modules
  validate_live
  run_trivy
  run_terraform_plan
}

run_terraform_apply() {
  log "Run terraform apply (cluster live)"
  setup_terraform_vars
  terraform -chdir="${CLUSTER_TF_DIR}" apply -input=false -auto-approve
}

deploy_infra() {
  plan_infra
  run_terraform_apply
}

destroy_infra() {
  log "Destroy cluster infra"
  check_terraform_fmt
  setup_terraform_vars
  terraform -chdir="${CLUSTER_TF_DIR}" init -input=false >/dev/null
  terraform -chdir="${CLUSTER_TF_DIR}" destroy -input=false -auto-approve
}

main() {
  local argument="${1:-}"
  if [[ -z "${argument}" ]]; then
    usage >&2
    exit 1
  fi

  export AWS_PROFILE
  export AWS_DEFAULT_REGION="${AWS_REGION}"
  export AWS_REGION

  case "${argument}" in
    plan)
      plan_infra
      ;;
    validate)
      check_terraform_fmt
      validate_modules
      validate_live
      run_trivy
      ;;
    deploy)
      deploy_infra
      ;;
    destroy)
      destroy_infra
      ;;
    -h | --help)
      usage
      ;;
    *)
      echo "ERROR: invalid argument: ${argument}" >&2
      usage >&2
      exit 1
      ;;
  esac
}

main "$@"

#!/usr/bin/env bash
# AMI factory orchestrator — Packer builder infra + bake.
#
# Usage (from devbox shell, phase2/ or anywhere):
#   ./images/setup-images.sh plan
#   ./images/setup-images.sh deploy
#   ./images/setup-images.sh build
#   ./images/setup-images.sh destroy
#
# plan:  terraform fmt -check, validate modules + live, trivy, terraform plan
# deploy: plan + terraform apply (builder VPC/subnet)
# build:  deploy + packer build (requires images/config/packer)
# destroy: terraform destroy on builder live (defer during early dev if needed)
#
# Env:
#   AWS_PROFILE  — default k8s_homelab (homelab account)
#   AWS_REGION   — default ca-central-1
#   SKIP_TRIVY=1 — skip trivy fs scan

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PHASE2_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
MODULES_INFRA_DIR="${PHASE2_DIR}/modules/infra"
IMAGES_TF_DIR="${PHASE2_DIR}/images/infra/main-account/ca-central-1/prod"
PACKER_DIR="${PHASE2_DIR}/images/config/packer"
AWS_PROFILE="${AWS_PROFILE:-k8s_homelab}"
AWS_REGION="${AWS_REGION:-ca-central-1}"

log() { echo "==> $*"; }

usage() {
  cat <<EOF
Usage: $(basename "$0") <plan|deploy|build|destroy>

  plan     fmt + validate + trivy + terraform plan (AMI builder infra)
  deploy   plan + terraform apply
  build    deploy + packer build
  destroy  terraform destroy (builder infra only)
EOF
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "ERROR: missing required command: $1 (run devbox shell)" >&2
    exit 1
  }
}

check_terraform_fmt() {
  log "Check terraform fmt"
  require_cmd terraform
  terraform fmt -check -recursive "${MODULES_INFRA_DIR}" "${IMAGES_TF_DIR}"
}

validate_modules() {
  log "Validate shared modules"
  local module_dir
  shopt -s nullglob
  local modules=("${MODULES_INFRA_DIR}"/*/)
  shopt -u nullglob
  if [[ ${#modules[@]} -eq 0 ]]; then
    echo "ERROR: no modules under ${MODULES_INFRA_DIR}" >&2
    exit 1
  fi
  for module_dir in "${modules[@]}"; do
    log "... ${module_dir}"
    terraform -chdir="${module_dir}" init -backend=false >/dev/null
    terraform -chdir="${module_dir}" validate
  done
}

validate_live() {
  log "Validate AMI live root"
  if [[ ! -d "${IMAGES_TF_DIR}" ]]; then
    echo "ERROR: AMI live TF not found at ${IMAGES_TF_DIR}" >&2
    exit 1
  fi
  terraform -chdir="${IMAGES_TF_DIR}" init -backend=false >/dev/null
  terraform -chdir="${IMAGES_TF_DIR}" validate
}

run_trivy() {
  if [[ "${SKIP_TRIVY:-}" == "1" ]]; then
    log "Trivy scan (skipped — SKIP_TRIVY=1)"
    return
  fi
  require_cmd trivy
  local target
  for target in "${MODULES_INFRA_DIR}" "${IMAGES_TF_DIR}"; do
    log "Run trivy fs on ${target}"
    trivy fs \
      --scanners secret,misconfig \
      --exit-code 1 \
      "${target}"
  done
}

run_terraform_plan() {
  log "Run terraform plan (AMI builder live)"
  terraform -chdir="${IMAGES_TF_DIR}" init -input=false >/dev/null
  terraform -chdir="${IMAGES_TF_DIR}" plan -input=false
}

plan_infra() {
  check_terraform_fmt
  validate_modules
  validate_live
  run_trivy
  run_terraform_plan
}

run_terraform_apply() {
  log "Run terraform apply (AMI builder live)"
  terraform -chdir="${IMAGES_TF_DIR}" apply -input=false -auto-approve
}

capture_packer_network() {
  log "Capture Packer network outputs"
  local outputs
  outputs="$(terraform -chdir="${IMAGES_TF_DIR}" output -json)"
  export PKR_VAR_vpc_id
  export PKR_VAR_subnet_id
  PKR_VAR_vpc_id="$(echo "${outputs}" | jq -r '.packer_vpc_id.value')"
  PKR_VAR_subnet_id="$(echo "${outputs}" | jq -r '.packer_subnet_id.value')"
  if [[ -z "${PKR_VAR_vpc_id}" || "${PKR_VAR_vpc_id}" == "null" ]]; then
    echo "ERROR: packer_vpc_id output missing after apply" >&2
    exit 1
  fi
  if [[ -z "${PKR_VAR_subnet_id}" || "${PKR_VAR_subnet_id}" == "null" ]]; then
    echo "ERROR: packer_subnet_id output missing after apply" >&2
    exit 1
  fi
}

deploy_infra() {
  plan_infra
  run_terraform_apply
  capture_packer_network
}

run_packer_build() {
  log "Run packer build"
  if [[ ! -d "${PACKER_DIR}" ]]; then
    echo "ERROR: Packer config not found at ${PACKER_DIR}" >&2
    exit 1
  fi
  shopt -s nullglob
  local packer_files=("${PACKER_DIR}"/*.pkr.hcl)
  shopt -u nullglob
  if [[ ${#packer_files[@]} -eq 0 ]]; then
    echo "ERROR: no .pkr.hcl under ${PACKER_DIR}" >&2
    exit 1
  fi
  require_cmd packer
  pushd "${PACKER_DIR}" >/dev/null
  packer fmt -check -recursive .
  packer init .
  packer validate .
  packer build .
  popd >/dev/null
}

build_ami() {
  deploy_infra
  run_packer_build
}

destroy_infra() {
  log "Destroy AMI builder infra"
  check_terraform_fmt
  terraform -chdir="${IMAGES_TF_DIR}" init -input=false >/dev/null
  terraform -chdir="${IMAGES_TF_DIR}" destroy -input=false -auto-approve
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
    deploy)
      deploy_infra
      ;;
    build)
      build_ami
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

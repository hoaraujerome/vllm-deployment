#!/usr/bin/env bash
# Phase 2 cluster orchestrator — provision, configure, check, destroy.
#
# Usage:
#   ./cluster.sh provision
#   ./cluster.sh configure
#   ./cluster.sh check
#   ./cluster.sh destroy

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PHASE2_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
TF_DIR="${PHASE2_DIR}/provisioning/envs/dev"

usage() {
  cat <<EOF
Usage: $(basename "$0") <provision|configure|check|destroy>

  provision   terraform apply (AWS infra)
  configure   ansible playbooks (kubeadm bootstrap)
  check       run phase2-check.sh validation ladder
  destroy     tear down cluster and infra (TBD)
EOF
}

cmd="${1:-}"
case "$cmd" in
  provision)
    terraform -chdir="$TF_DIR" init
    terraform -chdir="$TF_DIR" apply
    ;;
  configure)
    echo "ERROR: configure not implemented yet — add Ansible playbooks under configuration/" >&2
    exit 1
    ;;
  check)
    exec "${SCRIPT_DIR}/phase2-check.sh"
    ;;
  destroy)
    echo "ERROR: destroy not implemented yet" >&2
    exit 1
    ;;
  -h | --help | "")
    usage
    exit 0
    ;;
  *)
    usage >&2
    exit 1
    ;;
esac

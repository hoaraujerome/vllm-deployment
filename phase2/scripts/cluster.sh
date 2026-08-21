#!/usr/bin/env bash
# Thin wrapper — prefer: make -C phase2 <target>
#
# Usage:
#   ./scripts/cluster.sh plan       -> make cluster-infra-plan
#   ./scripts/cluster.sh provision  -> make cluster-infra-deploy
#   ./scripts/cluster.sh check      -> make check
#   ./scripts/cluster.sh destroy    -> make cluster-infra-destroy

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PHASE2_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
MAKE="${MAKE:-make}"

usage() {
  cat <<EOF
Usage: $(basename "$0") <plan|provision|configure|check|destroy>

  plan        make cluster-infra-plan
  provision   make cluster-infra-deploy
  configure   not implemented (bootstrap is AMI first-boot)
  check       make check
  destroy     make cluster-infra-destroy
EOF
}

cmd="${1:-}"
case "$cmd" in
  plan)
    exec "${MAKE}" -C "${PHASE2_DIR}" cluster-infra-plan
    ;;
  provision)
    exec "${MAKE}" -C "${PHASE2_DIR}" cluster-infra-deploy
    ;;
  configure)
    echo "ERROR: configure not implemented — bootstrap is baked into the AMI (first boot)" >&2
    exit 1
    ;;
  check)
    exec "${MAKE}" -C "${PHASE2_DIR}" check
    ;;
  destroy)
    exec "${MAKE}" -C "${PHASE2_DIR}" cluster-infra-destroy
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

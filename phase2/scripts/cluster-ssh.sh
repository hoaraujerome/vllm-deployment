#!/usr/bin/env bash
# Interactive SSH to the Phase 2 kubeadm node via EC2 Instance Connect Endpoint.
#
# Usage (from devbox shell, phase2/):
#   make cluster-ssh
#
# Env (exported by Makefile):
#   AWS_PROFILE, AWS_REGION
#   SSH_PRIVATE_KEY_PATH — default ~/.ssh/id_rsa_k8s_homelab
#   EICE_SSH_USER        — default ubuntu

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PHASE2_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
CLUSTER_TF_DIR="${PHASE2_DIR}/cluster/infra/main-account/ca-central-1/prod"
AWS_PROFILE="${AWS_PROFILE:-k8s_homelab}"
AWS_REGION="${AWS_REGION:-ca-central-1}"
SSH_PRIVATE_KEY_PATH="${SSH_PRIVATE_KEY_PATH:-${HOME}/.ssh/id_rsa_k8s_homelab}"
EICE_SSH_USER="${EICE_SSH_USER:-ubuntu}"

fail() { echo "ERROR: $*" >&2; exit 1; }

command -v ssh >/dev/null 2>&1 || fail "missing ssh (run devbox shell)"
command -v terraform >/dev/null 2>&1 || fail "missing terraform (run devbox shell)"
command -v aws >/dev/null 2>&1 || fail "missing aws (run devbox shell)"

[[ -f "${SSH_PRIVATE_KEY_PATH}" ]] || fail "SSH private key not found: ${SSH_PRIVATE_KEY_PATH}"

export AWS_PROFILE
export AWS_DEFAULT_REGION="${AWS_REGION}"

instance_id="$(terraform -chdir="${CLUSTER_TF_DIR}" output -raw k8s_node_instance_id 2>/dev/null)" || {
  fail "k8s_node_instance_id output missing — run: make cluster-infra-deploy"
}
eice_id="$(terraform -chdir="${CLUSTER_TF_DIR}" output -raw ec2_instance_connect_endpoint_id 2>/dev/null)" || {
  fail "ec2_instance_connect_endpoint_id output missing — run: make cluster-infra-deploy"
}

echo "==> SSH ${EICE_SSH_USER}@${instance_id} via ${eice_id}"

exec ssh -i "${SSH_PRIVATE_KEY_PATH}" \
  -o StrictHostKeyChecking=accept-new \
  -o "ProxyCommand=aws ec2-instance-connect open-tunnel --instance-id ${instance_id} --instance-connect-endpoint-id ${eice_id} --region ${AWS_REGION} --profile ${AWS_PROFILE}" \
  "${EICE_SSH_USER}@${instance_id}"

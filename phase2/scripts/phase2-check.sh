#!/usr/bin/env bash
# Phase 2 validation ladder — functional Kubernetes cluster on AWS.
#
# Prefer the Makefile entrypoint:
#   make check
#   make check SKIP_TF_APPLY=1 SKIP_ANSIBLE=1
#
# This script invokes make targets only — never setup-images.sh or setup-cluster.sh.
# Flags are exported from the Makefile and pass through to setup scripts via make recipes.
#
# Gates:
#   0. Devbox        — pinned toolchain
#   1. Ansible syntax / 1b. lint — AMI bake playbook
#   2–3. Cluster TF  — make cluster-infra-plan (or cluster-infra-validate)
#   3a. AMI apply    — make images-infra-deploy
#   3b. AMI artifact — AMI in AWS (or make images-config-build when RUN_PACKER_BUILD=1)
#   4. Provision     — make cluster-infra-deploy (RUN_CLUSTER_APPLY=1)
#   5. EICE SSH      — SSH to private node via EC2 Instance Connect Endpoint
#   6. Bootstrap     — kubeadm-init.service finished successfully
#   7. Cluster       — node Ready, system pods healthy (kubectl on node)
#   8. Smoke         — nginx workload Ready on node (kubectl over EICE)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PHASE2_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
MAKE="${MAKE:-make}"
CLUSTER_TF_DIR="${PHASE2_DIR}/cluster/infra/main-account/ca-central-1/prod"
AMI_ANSIBLE_DIR="${PHASE2_DIR}/images/config/ansible"
AMI_PLAYBOOK="${AMI_ANSIBLE_DIR}/ami.yaml"
AWS_PROFILE="${AWS_PROFILE:-k8s_homelab}"
AWS_REGION="${AWS_REGION:-ca-central-1}"
AMI_NAME_PREFIX="${AMI_NAME_PREFIX:-vllm-phase2-kubeadm}"
SSH_PRIVATE_KEY_PATH="${SSH_PRIVATE_KEY_PATH:-${HOME}/.ssh/id_rsa_k8s_homelab}"
EICE_SSH_USER="${EICE_SSH_USER:-ubuntu}"
EICE_SSH_PROBE="${EICE_SSH_PROBE:-phase2-eice-ssh-ok}"
CLUSTER_BOOTSTRAP_TIMEOUT="${CLUSTER_BOOTSTRAP_TIMEOUT:-900}"
CLUSTER_BOOTSTRAP_INTERVAL="${CLUSTER_BOOTSTRAP_INTERVAL:-20}"
CLUSTER_HEALTH_TIMEOUT="${CLUSTER_HEALTH_TIMEOUT:-900}"
CLUSTER_HEALTH_INTERVAL="${CLUSTER_HEALTH_INTERVAL:-20}"
CLUSTER_SMOKE_TIMEOUT="${CLUSTER_SMOKE_TIMEOUT:-90}"
CLUSTER_SMOKE_INTERVAL="${CLUSTER_SMOKE_INTERVAL:-5}"
SMOKE_DEPLOYMENT_NAME="${SMOKE_DEPLOYMENT_NAME:-phase2-smoke-nginx}"
SMOKE_NAMESPACE="${SMOKE_NAMESPACE:-default}"

CLUSTER_INSTANCE_ID=""
CLUSTER_EICE_ID=""

info() { echo "==> $*"; }
fail() { echo "ERROR: $*" >&2; exit 1; }

run_make() {
  "${MAKE}" -C "${PHASE2_DIR}" "$@"
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

gate_devbox() {
  info "Gate: devbox toolchain"
  require_cmd make
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

gate_cluster_tf() {
  if [[ "${SKIP_CLUSTER_TF:-}" == "1" ]]; then
    info "Gate: cluster TF (skipped — SKIP_CLUSTER_TF=1)"
    return
  fi
  if [[ "${SKIP_TF_PLAN:-}" == "1" ]]; then
    info "Gate: cluster TF validate (2 — plan skipped, SKIP_TF_PLAN=1)"
    run_make cluster-infra-validate
    return
  fi
  info "Gate: cluster TF plan (2–3)"
  run_make cluster-infra-plan
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
  run_make images-infra-deploy
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
    if [[ "${SKIP_AMI_BUILDING:-}" == "1" ]]; then
      fail "AMI missing but RUN_PACKER_BUILD=1 and SKIP_AMI_BUILDING=1 — unset one of them"
    fi
    info "AMI artifact: no AMI found — running make images-config-build"
    run_make images-config-build
    count="$(ami_image_count)"
    if [[ "$count" == "0" || "$count" == "None" ]]; then
      fail "images-config-build finished but no available AMI matching ${AMI_NAME_PREFIX}* in ${AWS_REGION}"
    fi
    image_id="$(ami_newest_image_id)"
    info "AMI artifact: base AMI built — ${image_id}"
    return
  fi

  fail "no available AMI matching ${AMI_NAME_PREFIX}* in ${AWS_REGION} — run: make check RUN_PACKER_BUILD=1 (or make images-config-build)"
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
  info "Gate: provision (4)"

  if [[ "${RUN_CLUSTER_APPLY:-}" == "1" ]]; then
    run_make cluster-infra-deploy
    info "Cluster live: terraform apply complete"
    return
  fi

  fail "cluster live not applied — run: make check RUN_CLUSTER_APPLY=1 (or make cluster-infra-deploy)"
}

cluster_tf_output() {
  local name="$1"
  terraform -chdir="${CLUSTER_TF_DIR}" output -raw "$name"
}

instance_state() {
  local instance_id="$1"
  aws ec2 describe-instances \
    --instance-ids "$instance_id" \
    --region "$AWS_REGION" \
    --query 'Reservations[0].Instances[0].State.Name' \
    --output text
}

run_eice_ssh() {
  local instance_id="$1"
  local eice_id="$2"
  local remote_cmd="$3"

  # open-tunnel + ssh (homelab README pattern). aws ec2-instance-connect ssh does not
  # accept OpenSSH -o flags after --; passing them causes ParamValidation noise.
  ssh -i "${SSH_PRIVATE_KEY_PATH}" \
    -o BatchMode=yes \
    -o StrictHostKeyChecking=accept-new \
    -o ConnectTimeout=30 \
    -o "ProxyCommand=aws ec2-instance-connect open-tunnel --instance-id ${instance_id} --instance-connect-endpoint-id ${eice_id} --region ${AWS_REGION} --profile ${AWS_PROFILE}" \
    "${EICE_SSH_USER}@${instance_id}" \
    "${remote_cmd}"
}

run_eice_remote_script() {
  local instance_id="$1"
  local eice_id="$2"
  local script="$3"

  ssh -i "${SSH_PRIVATE_KEY_PATH}" \
    -o BatchMode=yes \
    -o StrictHostKeyChecking=accept-new \
    -o ConnectTimeout=30 \
    -o "ProxyCommand=aws ec2-instance-connect open-tunnel --instance-id ${instance_id} --instance-connect-endpoint-id ${eice_id} --region ${AWS_REGION} --profile ${AWS_PROFILE}" \
    "${EICE_SSH_USER}@${instance_id}" \
    "bash -s" <<EOF
set -euo pipefail
${script}
EOF
}

require_cluster_ssh() {
  require_cmd ssh
  require_cmd terraform

  if [[ ! -f "${SSH_PRIVATE_KEY_PATH}" ]]; then
    fail "SSH private key not found at ${SSH_PRIVATE_KEY_PATH} (set SSH_PRIVATE_KEY_PATH)"
  fi

  if [[ -z "${CLUSTER_INSTANCE_ID}" ]]; then
    CLUSTER_INSTANCE_ID="$(cluster_tf_output k8s_node_instance_id 2>/dev/null)" || {
      fail "cluster output k8s_node_instance_id unavailable — apply cluster live first (make cluster-infra-deploy)"
    }
    CLUSTER_EICE_ID="$(cluster_tf_output ec2_instance_connect_endpoint_id 2>/dev/null)" || {
      fail "cluster output ec2_instance_connect_endpoint_id unavailable — apply cluster live first"
    }

    local state
    state="$(instance_state "${CLUSTER_INSTANCE_ID}")"
    if [[ "$state" != "running" ]]; then
      fail "EC2 instance ${CLUSTER_INSTANCE_ID} is ${state} (expected running)"
    fi
  fi
}

remote_bootstrap_ok() {
  run_eice_remote_script "${CLUSTER_INSTANCE_ID}" "${CLUSTER_EICE_ID}" '
failed="$(systemctl is-failed kubeadm-init.service 2>/dev/null || true)"
if [[ "${failed}" == "failed" ]]; then
  echo "kubeadm-init.service is failed"
  systemctl status kubeadm-init.service --no-pager || true
  exit 1
fi

active_state="$(systemctl show kubeadm-init.service -p ActiveState --value 2>/dev/null || true)"
result="$(systemctl show kubeadm-init.service -p Result --value 2>/dev/null || true)"

if [[ "${active_state}" == "activating" || -z "${result}" || "${result}" == "ongoing" ]]; then
  echo "kubeadm-init.service still running (ActiveState=${active_state}, Result=${result})"
  exit 1
fi

if [[ "${result}" != "success" ]]; then
  echo "kubeadm-init.service Result=${result} (expected success)"
  systemctl status kubeadm-init.service --no-pager || true
  exit 1
fi

if ! journalctl -u kubeadm-init.service --no-pager | grep -q "Bootstrap complete"; then
  echo "kubeadm-init.service journal missing Bootstrap complete"
  exit 1
fi

kubelet_enabled="$(systemctl is-enabled kubelet 2>/dev/null || true)"
if [[ "${kubelet_enabled}" != "enabled" ]]; then
  echo "kubelet not enabled for boot (is-enabled=${kubelet_enabled})"
  systemctl status kubelet --no-pager || true
  exit 1
fi

echo "gate6-ok"
'
}

remote_cluster_healthy() {
  run_eice_remote_script "${CLUSTER_INSTANCE_ID}" "${CLUSTER_EICE_ID}" '
if [[ ! -f /etc/kubernetes/admin.conf ]]; then
  echo "missing /etc/kubernetes/admin.conf"
  exit 1
fi

kubectl() {
  sudo KUBECONFIG=/etc/kubernetes/admin.conf kubectl "$@"
}

if ! kubectl cluster-info >/dev/null 2>&1; then
  echo "kubectl cluster-info failed"
  exit 1
fi

node_count="$(kubectl get nodes --no-headers 2>/dev/null | wc -l | tr -d " ")"
if [[ "${node_count}" != "1" ]]; then
  echo "expected 1 node, got ${node_count}"
  kubectl get nodes -o wide || true
  exit 1
fi

ready="$(kubectl get nodes --no-headers 2>/dev/null | awk "{print \$2}" | head -1)"
if [[ "${ready}" != "Ready" ]]; then
  echo "node not Ready (status=${ready})"
  kubectl get nodes -o wide || true
  exit 1
fi

while read -r ns name ready _rest; do
  [[ -n "${ns}" ]] || continue
  ready_count="${ready%%/*}"
  ready_total="${ready##*/}"
  if [[ "${ready_count}" != "${ready_total}" ]]; then
    echo "pod not ready: ${ns}/${name} (${ready})"
    exit 1
  fi
done < <(kubectl get pods -A --no-headers 2>/dev/null)

bad_phase="$(kubectl get pods -A --no-headers 2>/dev/null | awk "NF && \$4 != \"Running\" && \$4 != \"Completed\" { print \$1 \"/\" \$2 \" \" \$4; exit 1 }")"
if [[ -n "${bad_phase}" ]]; then
  echo "pod not Running: ${bad_phase}"
  kubectl get pods -A || true
  exit 1
fi

echo "gate7-ok"
kubectl get nodes -o wide
kubectl get pods -A
'
}

remote_smoke_kubectl_script='kubectl() {
  sudo KUBECONFIG=/etc/kubernetes/admin.conf kubectl "$@"
}'

remote_smoke_ensure() {
  run_eice_remote_script "${CLUSTER_INSTANCE_ID}" "${CLUSTER_EICE_ID}" "${remote_smoke_kubectl_script}
deploy=\"${SMOKE_DEPLOYMENT_NAME}\"
ns=\"${SMOKE_NAMESPACE}\"

if kubectl get deployment \"\${deploy}\" -n \"\${ns}\" >/dev/null 2>&1; then
  echo \"smoke deployment exists: \${ns}/\${deploy}\"
  exit 0
fi

if ! create_out=\"\$(kubectl create deployment \"\${deploy}\" --image=nginx -n \"\${ns}\" 2>&1)\"; then
  echo \"kubectl create deployment failed: \${create_out}\"
  exit 1
fi

echo \"\${create_out}\"
echo \"smoke deployment created: \${ns}/\${deploy}\"
"
}

remote_smoke_verify() {
  run_eice_remote_script "${CLUSTER_INSTANCE_ID}" "${CLUSTER_EICE_ID}" "${remote_smoke_kubectl_script}
deploy=\"${SMOKE_DEPLOYMENT_NAME}\"
ns=\"${SMOKE_NAMESPACE}\"

if ! kubectl get deployment \"\${deploy}\" -n \"\${ns}\" >/dev/null 2>&1; then
  echo \"smoke deployment missing: \${ns}/\${deploy}\"
  kubectl get deployments -n \"\${ns}\" || true
  exit 1
fi

pod_line=\"\$(kubectl get pods -n \"\${ns}\" -l \"app=\${deploy}\" --no-headers 2>/dev/null | head -1 || true)\"
if [[ -z \"\${pod_line}\" ]]; then
  echo \"smoke pod not created yet\"
  kubectl get deployment \"\${deploy}\" -n \"\${ns}\" -o wide || true
  kubectl get pods -n \"\${ns}\" -o wide || true
  exit 1
fi

read -r _pod_name ready status _rest <<< \"\${pod_line}\"
if [[ \"\${ready}\" != \"1/1\" || \"\${status}\" != \"Running\" ]]; then
  echo \"smoke pod not ready: \${pod_line}\"
  kubectl get pods -n \"\${ns}\" -l \"app=\${deploy}\" -o wide || true
  exit 1
fi

pod_ip=\"\$(kubectl get pods -n \"\${ns}\" -l \"app=\${deploy}\" -o jsonpath='{.items[0].status.podIP}' 2>/dev/null || true)\"
if [[ -z \"\${pod_ip}\" || \"\${pod_ip}\" == \"<none>\" ]]; then
  echo \"smoke pod has no pod IP\"
  exit 1
fi

echo \"gate8-ok pod_ip=\${pod_ip}\"
kubectl get deployment \"\${deploy}\" -n \"\${ns}\"
kubectl get pods -n \"\${ns}\" -l \"app=\${deploy}\" -o wide
"
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

gate_eice_ssh() {
  if [[ "${SKIP_EICE_SSH:-}" == "1" ]]; then
    info "Gate: EICE SSH (skipped — SKIP_EICE_SSH=1)"
    return
  fi

  info "Gate: EICE SSH (5)"
  require_cluster_ssh

  info "EICE SSH: ${EICE_SSH_USER}@${CLUSTER_INSTANCE_ID} via ${CLUSTER_EICE_ID}"
  local output
  output="$(run_eice_ssh "${CLUSTER_INSTANCE_ID}" "${CLUSTER_EICE_ID}" "echo ${EICE_SSH_PROBE}")" || {
    fail "EICE SSH failed for ${CLUSTER_INSTANCE_ID} — verify AWS profile ${AWS_PROFILE}, key ${SSH_PRIVATE_KEY_PATH}, and EICE/SG rules"
  }

  if [[ "$output" != *"${EICE_SSH_PROBE}"* ]]; then
    fail "EICE SSH connected but probe mismatch (got: ${output})"
  fi

  info "EICE SSH: ok (${CLUSTER_INSTANCE_ID})"
}

gate_bootstrap() {
  if [[ "${SKIP_ANSIBLE:-}" == "1" ]]; then
    info "Gate: bootstrap (skipped — SKIP_ANSIBLE=1)"
    return
  fi

  info "Gate: bootstrap (6)"
  require_cluster_ssh
  poll_until "Bootstrap (kubeadm-init.service)" "${CLUSTER_BOOTSTRAP_TIMEOUT}" "${CLUSTER_BOOTSTRAP_INTERVAL}" remote_bootstrap_ok
}

gate_cluster() {
  if [[ "${SKIP_ANSIBLE:-}" == "1" ]]; then
    info "Gate: cluster (skipped — SKIP_ANSIBLE=1)"
    return
  fi

  info "Gate: cluster health (7)"
  require_cluster_ssh
  poll_until "Cluster (node Ready + system pods)" "${CLUSTER_HEALTH_TIMEOUT}" "${CLUSTER_HEALTH_INTERVAL}" remote_cluster_healthy
}

gate_smoke() {
  if [[ "${SKIP_ANSIBLE:-}" == "1" || "${SKIP_SMOKE:-}" == "1" ]]; then
    info "Gate: smoke (skipped — SKIP_SMOKE=1 or SKIP_ANSIBLE=1)"
    return
  fi
  info "Gate: smoke (8)"
  require_cluster_ssh

  local ensure_out
  info "Smoke: ensure deployment ${SMOKE_NAMESPACE}/${SMOKE_DEPLOYMENT_NAME}"
  ensure_out="$(remote_smoke_ensure 2>&1)" || {
    echo "${ensure_out}" >&2
    fail "Smoke deployment create failed"
  }
  if [[ -n "${ensure_out}" ]]; then
    echo "${ensure_out}" | sed 's/^/    /'
  fi

  poll_until "Smoke (nginx workload)" "${CLUSTER_SMOKE_TIMEOUT}" "${CLUSTER_SMOKE_INTERVAL}" remote_smoke_verify
}

main() {
  export AWS_PROFILE
  export AWS_DEFAULT_REGION="${AWS_REGION}"
  export AWS_REGION

  gate_devbox
  gate_ansible_syntax
  gate_ansible_lint
  gate_cluster_tf
  gate_ami
  gate_tf_apply
  gate_eice_ssh
  if [[ "${SKIP_ANSIBLE:-}" == "1" ]]; then
    info "Ladder complete through gate 5 (bootstrap, cluster, smoke skipped — SKIP_ANSIBLE=1)"
    exit 0
  fi
  gate_bootstrap
  gate_cluster
  gate_smoke
  if [[ "${SKIP_SMOKE:-}" == "1" ]]; then
    info "Ladder complete through gate 7 (smoke skipped — SKIP_SMOKE=1)"
  else
    info "Ladder complete through gate 8 (smoke ok)"
  fi
}

main "$@"

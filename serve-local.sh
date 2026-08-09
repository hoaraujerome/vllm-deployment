#!/usr/bin/env bash
# Start vLLM-Metal locally with loopback networking (avoids Tailscale/CGNAT IP issues).

set -euo pipefail

VENV="${VLLM_METAL_VENV:-$HOME/.venv-vllm-metal}"
DEFAULT_MODEL="mlx-community/Qwen2.5-0.5B-Instruct-4bit"

usage() {
  cat <<EOF
Usage: $(basename "$0") [model]

Start the vLLM OpenAI-compatible API server on this Mac.

  model   Hugging Face model id (default: ${DEFAULT_MODEL})

Examples:
  $(basename "$0")
  $(basename "$0") mlx-community/Qwen2.5-0.5B-Instruct-4bit

Environment:
  VLLM_METAL_VENV   path to vLLM-Metal venv (default: ~/.venv-vllm-metal)

After startup, test with:
  curl http://127.0.0.1:8000/v1/chat/completions \\
    -H "Content-Type: application/json" \\
    -d '{"model":"<model>","messages":[{"role":"user","content":"Hello"}],"max_tokens":50}'
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

model="${1:-$DEFAULT_MODEL}"

if [[ ! -d "$VENV" ]]; then
  echo "Error: vLLM-Metal venv not found at ${VENV}." >&2
  echo "Install with:" >&2
  echo "  curl -fsSL https://raw.githubusercontent.com/vllm-project/vllm-metal/main/install.sh | bash" >&2
  exit 1
fi

# shellcheck source=/dev/null
source "${VENV}/bin/activate"

# vLLM may pick a Tailscale/CGNAT address (100.64.x.x) for torch distributed;
# loopback keeps the API server and EngineCore on the same host.
export VLLM_HOST_IP="${VLLM_HOST_IP:-127.0.0.1}"
export MASTER_ADDR="${MASTER_ADDR:-127.0.0.1}"
export GLOO_SOCKET_IFNAME="${GLOO_SOCKET_IFNAME:-lo0}"

exec vllm serve "$model"

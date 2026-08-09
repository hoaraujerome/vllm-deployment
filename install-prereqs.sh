#!/usr/bin/env bash
# Install Phase 1 prerequisites for vLLM-Metal on Apple Silicon (macOS).
# Does not install vLLM itself — run the upstream install.sh after this.

set -euo pipefail

error() {
  echo "Error: $*" >&2
}

success() {
  echo "✓ $*"
}

section() {
  echo ""
  echo "=== $* ==="
}

require_apple_silicon() {
  if [[ "$(uname -m)" != "arm64" ]]; then
    error "vLLM-Metal requires Apple Silicon (arm64). Detected: $(uname -m)."
    exit 1
  fi
  success "Apple Silicon (arm64) detected"
}

ensure_homebrew() {
  section "Homebrew"
  if command -v brew >/dev/null 2>&1; then
    success "Homebrew already installed ($(brew --version | head -n1))"
    return
  fi

  echo "Installing Homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

  if [[ -x /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  elif [[ -x /usr/local/bin/brew ]]; then
    eval "$(/usr/local/bin/brew shellenv)"
  fi

  if ! command -v brew >/dev/null 2>&1; then
    error "Homebrew install finished but brew is not on PATH."
    echo "Add brew to your shell profile, then re-run this script." >&2
    exit 1
  fi

  success "Homebrew installed"
}

ensure_xcode_clt() {
  section "Xcode Command Line Tools"
  if xcode-select -p >/dev/null 2>&1; then
    success "Xcode Command Line Tools already installed"
    return
  fi

  echo "Xcode Command Line Tools are required for Metal compilation."
  echo "A system dialog will open — complete the install, then re-run this script."
  xcode-select --install || true
  exit 1
}

ensure_uv() {
  section "uv (Python package manager)"
  if command -v uv >/dev/null 2>&1; then
    success "uv already installed ($(uv --version))"
    return
  fi

  echo "Installing uv via Homebrew..."
  brew install uv
  success "uv installed ($(uv --version))"
}

verify_curl() {
  section "curl"
  if ! command -v curl >/dev/null 2>&1; then
    error "curl is required but not found."
    exit 1
  fi
  success "curl available"
}

print_next_steps() {
  local script_dir
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

  section "Next steps"
  cat <<EOF
Prerequisites are ready. Install vLLM-Metal:

  curl -fsSL https://raw.githubusercontent.com/vllm-project/vllm-metal/main/install.sh | bash

Then serve locally (uses loopback — safe with Tailscale):

  ${script_dir}/serve-local.sh

Or with another mlx-community model:

  ${script_dir}/serve-local.sh mlx-community/Qwen2.5-0.5B-Instruct-4bit
EOF
}

main() {
  require_apple_silicon
  ensure_homebrew
  ensure_xcode_clt
  verify_curl
  ensure_uv
  print_next_steps
}

main "$@"

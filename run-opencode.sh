#!/usr/bin/env bash
set -euo pipefail

if ! command -v ollama >/dev/null 2>&1; then
  echo "Ollama is not installed. Run ./setup-opencode.sh first."
  exit 1
fi

if ! command -v opencode >/dev/null 2>&1 && [[ -x "$HOME/.opencode/bin/opencode" ]]; then
  export PATH="$HOME/.opencode/bin:$PATH"
fi

if ! command -v opencode >/dev/null 2>&1; then
  echo "OpenCode is not installed. Run ./setup-opencode.sh first."
  exit 1
fi

exec ollama launch opencode "$@"

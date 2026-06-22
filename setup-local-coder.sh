#!/usr/bin/env bash
set -euo pipefail

MODEL="${1:-${MODEL:-qwen2.5-coder:7b}}"
OLLAMA_HOST_URL="${OLLAMA_HOST_URL:-http://localhost:11434}"

log() {
  printf '\n==> %s\n' "$1"
}

need_cmd() {
  command -v "$1" >/dev/null 2>&1
}

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "This script is for macOS."
  exit 1
fi

log "Checking Homebrew"
if ! need_cmd brew; then
  echo "Homebrew is not installed. Installing it now."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

  if [[ -x /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  elif [[ -x /usr/local/bin/brew ]]; then
    eval "$(/usr/local/bin/brew shellenv)"
  fi
else
  echo "Homebrew is already installed."
fi

if ! need_cmd brew; then
  echo "Homebrew installed, but brew is not on PATH yet."
  echo "Restart Terminal, then run this script again."
  exit 1
fi

log "Installing Ollama"
if ! need_cmd ollama; then
  brew install ollama
else
  echo "Ollama is already installed."
fi

log "Starting Ollama"
if curl -fsS "$OLLAMA_HOST_URL/api/tags" >/dev/null 2>&1; then
  echo "Ollama is already running."
else
  mkdir -p "$HOME/.ollama"
  nohup ollama serve >"$HOME/.ollama/ollama-serve.log" 2>&1 &

  for _ in {1..30}; do
    if curl -fsS "$OLLAMA_HOST_URL/api/tags" >/dev/null 2>&1; then
      echo "Ollama started."
      break
    fi
    sleep 1
  done
fi

if ! curl -fsS "$OLLAMA_HOST_URL/api/tags" >/dev/null 2>&1; then
  echo "Could not reach Ollama at $OLLAMA_HOST_URL."
  echo "Check the log at $HOME/.ollama/ollama-serve.log"
  exit 1
fi

log "Downloading model: $MODEL"
ollama pull "$MODEL"

log "Testing model"
ollama run "$MODEL" "Reply with exactly: local model ready"

cat <<EOF

Done.

Start chatting:
  ollama run $MODEL

Use the local API:
  curl $OLLAMA_HOST_URL/api/generate \\
    -d '{"model":"$MODEL","prompt":"Write hello world in Python","stream":false}'

Try a smaller model if this Mac feels slow:
  ./setup-local-coder.sh qwen2.5-coder:3b
EOF

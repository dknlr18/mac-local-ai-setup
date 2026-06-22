#!/usr/bin/env bash
set -euo pipefail

MODEL="${MODEL:-qwen2.5-coder:7b}"
OLLAMA_HOST_URL="${OLLAMA_HOST_URL:-http://localhost:11434}"
INSTALL_WEBUI=0
INSTALL_OPENCODE=0
SKIP_TEST=0
OPEN_WEBUI_PORT="${OPEN_WEBUI_PORT:-3000}"
OPEN_WEBUI_CONTAINER="${OPEN_WEBUI_CONTAINER:-open-webui}"

usage() {
  cat <<EOF
Usage:
  ./setup-local-coder.sh [model]
  ./setup-local-coder.sh --opencode [model]
  ./setup-local-coder.sh --webui [model]

Examples:
  ./setup-local-coder.sh
  ./setup-local-coder.sh qwen2.5-coder:3b
  ./setup-local-coder.sh --opencode
  ./setup-local-coder.sh --webui
  ./setup-local-coder.sh --opencode --webui
  ./setup-local-coder.sh --webui qwen2.5-coder:3b

Environment:
  MODEL=qwen2.5-coder:7b
  OPEN_WEBUI_PORT=3000
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --webui)
      INSTALL_WEBUI=1
      ;;
    --opencode)
      INSTALL_OPENCODE=1
      ;;
    --no-test)
      SKIP_TEST=1
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    -*)
      echo "Unknown option: $1"
      usage
      exit 1
      ;;
    *)
      MODEL="$1"
      ;;
  esac
  shift
done

log() {
  printf '\n==> %s\n' "$1"
}

need_cmd() {
  command -v "$1" >/dev/null 2>&1
}

ensure_macos() {
  if [[ "$(uname -s)" != "Darwin" ]]; then
    echo "This script is for macOS."
    exit 1
  fi
}

ensure_homebrew() {
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
}

ensure_ollama() {
  log "Installing Ollama"
  if ! need_cmd ollama; then
    brew install ollama
  else
    echo "Ollama is already installed."
  fi
}

start_ollama() {
  log "Starting Ollama"
  if curl -fsS "$OLLAMA_HOST_URL/api/tags" >/dev/null 2>&1; then
    echo "Ollama is already running."
    return
  fi

  mkdir -p "$HOME/.ollama"
  nohup ollama serve >"$HOME/.ollama/ollama-serve.log" 2>&1 &

  for _ in {1..30}; do
    if curl -fsS "$OLLAMA_HOST_URL/api/tags" >/dev/null 2>&1; then
      echo "Ollama started."
      return
    fi
    sleep 1
  done

  echo "Could not reach Ollama at $OLLAMA_HOST_URL."
  echo "Check the log at $HOME/.ollama/ollama-serve.log"
  exit 1
}

pull_model() {
  log "Downloading model: $MODEL"
  ollama pull "$MODEL"
}

test_model() {
  if [[ "$SKIP_TEST" == "1" ]]; then
    return
  fi

  log "Testing model"
  ollama run "$MODEL" "Reply with exactly: local model ready"
}

add_docker_to_path_if_needed() {
  if ! need_cmd docker && [[ -x /Applications/Docker.app/Contents/Resources/bin/docker ]]; then
    export PATH="/Applications/Docker.app/Contents/Resources/bin:$PATH"
  fi
}

ensure_docker_desktop() {
  log "Checking Docker Desktop"
  add_docker_to_path_if_needed

  if ! need_cmd docker; then
    echo "Docker Desktop is not installed. Installing it now."
    brew install --cask docker
    add_docker_to_path_if_needed
  else
    echo "Docker CLI is already installed."
  fi

  if ! need_cmd docker; then
    echo "Docker was installed, but the docker command is not available yet."
    echo "Open Docker Desktop once, then rerun this script."
    exit 1
  fi

  if docker info >/dev/null 2>&1; then
    echo "Docker is already running."
    return
  fi

  echo "Starting Docker Desktop. macOS may ask for permissions."
  open -a Docker || true

  for _ in {1..90}; do
    if docker info >/dev/null 2>&1; then
      echo "Docker started."
      return
    fi
    sleep 2
  done

  echo "Docker Desktop did not become ready in time."
  echo "Open Docker Desktop manually, finish any prompts, then rerun:"
  echo "  ./setup-local-coder.sh --webui $MODEL"
  exit 1
}

add_opencode_to_path_if_needed() {
  if ! need_cmd opencode && [[ -x "$HOME/.opencode/bin/opencode" ]]; then
    export PATH="$HOME/.opencode/bin:$PATH"
  fi
}

ensure_opencode() {
  log "Installing OpenCode"
  add_opencode_to_path_if_needed

  if need_cmd opencode; then
    echo "OpenCode is already installed."
    opencode --version || true
    return
  fi

  curl -fsSL https://opencode.ai/install | bash
  add_opencode_to_path_if_needed

  if ! need_cmd opencode; then
    echo "OpenCode installed, but opencode is not on PATH yet."
    echo "Restart Terminal, then run:"
    echo "  ollama launch opencode"
    exit 1
  fi

  opencode --version || true
}

install_open_webui() {
  log "Installing Open WebUI"
  docker volume create open-webui >/dev/null
  docker pull ghcr.io/open-webui/open-webui:main

  if docker ps -a --format '{{.Names}}' | grep -qx "$OPEN_WEBUI_CONTAINER"; then
    echo "Recreating existing $OPEN_WEBUI_CONTAINER container."
    docker stop "$OPEN_WEBUI_CONTAINER" >/dev/null 2>&1 || true
    docker rm "$OPEN_WEBUI_CONTAINER" >/dev/null 2>&1 || true
  fi

  docker run -d \
    -p "$OPEN_WEBUI_PORT:8080" \
    -e OLLAMA_BASE_URL=http://host.docker.internal:11434 \
    -v open-webui:/app/backend/data \
    --name "$OPEN_WEBUI_CONTAINER" \
    --restart always \
    ghcr.io/open-webui/open-webui:main >/dev/null

  echo "Open WebUI is running at: http://localhost:$OPEN_WEBUI_PORT"
}

ensure_macos
ensure_homebrew
ensure_ollama
start_ollama
pull_model
test_model

if [[ "$INSTALL_WEBUI" == "1" ]]; then
  ensure_docker_desktop
  install_open_webui
fi

if [[ "$INSTALL_OPENCODE" == "1" ]]; then
  ensure_opencode
fi

cat <<EOF

Done.

Start chatting in Terminal:
  ollama run $MODEL

Use the local API:
  curl $OLLAMA_HOST_URL/api/generate \\
    -d '{"model":"$MODEL","prompt":"Write hello world in Python","stream":false}'
EOF

if [[ "$INSTALL_WEBUI" == "1" ]]; then
  cat <<EOF

Use the local web app:
  http://localhost:$OPEN_WEBUI_PORT

Open WebUI should see Ollama at:
  http://host.docker.internal:11434

For web search inside Open WebUI, enable Web Search in the admin/settings UI and add a search provider/API key there.
EOF
else
  cat <<EOF

Install the terminal coding-agent harness:
  ./setup-local-coder.sh --opencode $MODEL

Install the browser harness too:
  ./setup-local-coder.sh --webui $MODEL

Try a smaller model if this Mac feels slow:
  ./setup-local-coder.sh qwen2.5-coder:3b
EOF
fi

if [[ "$INSTALL_OPENCODE" == "1" ]]; then
  cat <<EOF

Use the Codex/Claude Code-style terminal agent inside any project:
  cd /path/to/your/project
  ollama launch opencode

You can also try plain OpenCode:
  opencode
EOF
fi

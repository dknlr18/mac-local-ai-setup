# Mac Local AI Setup

Setup scripts for running a free local coding model and a Codex/Claude Code-style terminal coding agent on a MacBook Air.

The default model is:

```bash
qwen2.5-coder:7b
```

That is a good starting point for a MacBook Air with 16 GB RAM. If it feels slow, use:

```bash
qwen2.5-coder:3b
```

## Run OpenCode Agent Harness

For a Codex CLI / Claude Code-style terminal coding agent, install OpenCode with Ollama:

```bash
chmod +x setup-opencode.sh
./setup-opencode.sh
```

This installs:

- Homebrew, if missing
- Ollama
- `qwen2.5-coder:7b`
- OpenCode

Then open any project and run:

```bash
cd /path/to/your/project
ollama launch opencode
```

Or run the helper from inside whatever project you want OpenCode to work on:

```bash
cd /path/to/your/project
/path/to/mac-local-ai-setup/run-opencode.sh
```

To use the smaller model:

```bash
./setup-opencode.sh qwen2.5-coder:3b
```

OpenCode is the closest option here to Codex CLI or Claude Code. It can inspect/edit files and run commands from your terminal. The local model quality will be weaker than hosted frontier models, especially on a MacBook Air.

## Run A Local Model Only

```bash
chmod +x setup-local-coder.sh
./setup-local-coder.sh
```

To install the smaller model instead:

```bash
./setup-local-coder.sh qwen2.5-coder:3b
```

After setup, chat with the model:

```bash
ollama run qwen2.5-coder:7b
```

Use the local API:

```bash
curl http://localhost:11434/api/generate \
  -d '{"model":"qwen2.5-coder:7b","prompt":"Write hello world in Python","stream":false}'
```

## Run With A Browser Harness

For a ChatGPT-style local browser app with model management and optional web search/RAG features, install Open WebUI:

```bash
./setup-open-webui.sh
```

Or use the main script directly:

```bash
./setup-local-coder.sh --webui
```

This installs:

- Homebrew, if missing
- Ollama
- `qwen2.5-coder:7b`
- Docker Desktop, if missing
- Open WebUI at `http://localhost:3000`

To use the smaller model:

```bash
./setup-open-webui.sh qwen2.5-coder:3b
```

Open WebUI should connect to Ollama at:

```text
http://host.docker.internal:11434
```

For web search inside Open WebUI, enable Web Search in the Open WebUI admin/settings UI and add a search provider/API key there.

## Web Access

Ollama models do not browse the web by themselves. They only know what is in the model and what you paste into the prompt.

To ask the local model about one web page, use:

```bash
./ask-url.py https://example.com "summarize this page"
```

This fetches the page text, sends it to your local Ollama model, and prints the answer. It works best with normal public pages. It will not work well with pages that require login, heavy JavaScript, or bot checks.

## Web Search

Codex and Claude Code can search the web because an agent wrapper gives the model a search tool. For a local Ollama model, use `ask-web.py`.

First create a free Brave Search API key:

```text
https://api.search.brave.com/app/keys
```

Then set it in Terminal:

```bash
export BRAVE_SEARCH_API_KEY="paste_key_here"
```

Ask a web-backed question:

```bash
./ask-web.py "what is the latest stable version of python"
```

The script searches the web, fetches the top result pages, sends that context to the local model, and asks it to cite sources.

If you run your own SearXNG instance instead, set:

```bash
export SEARXNG_URL="http://localhost:8080"
```

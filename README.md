# Mac Local AI Setup

Setup script for running a free local coding model on a MacBook Air.

The default model is:

```bash
qwen2.5-coder:7b
```

That is a good starting point for a MacBook Air with 16 GB RAM. If it feels slow, use:

```bash
qwen2.5-coder:3b
```

## Run

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

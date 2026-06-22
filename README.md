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

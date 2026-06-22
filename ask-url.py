#!/usr/bin/env python3
import argparse
import html
import json
import re
import sys
import urllib.error
import urllib.request
from html.parser import HTMLParser


class TextExtractor(HTMLParser):
    def __init__(self):
        super().__init__()
        self.skip_depth = 0
        self.parts = []

    def handle_starttag(self, tag, attrs):
        if tag in {"script", "style", "noscript", "svg"}:
            self.skip_depth += 1
        elif tag in {"p", "br", "li", "h1", "h2", "h3", "h4", "tr"}:
            self.parts.append("\n")

    def handle_endtag(self, tag):
        if tag in {"script", "style", "noscript", "svg"} and self.skip_depth:
            self.skip_depth -= 1
        elif tag in {"p", "li", "h1", "h2", "h3", "h4", "tr"}:
            self.parts.append("\n")

    def handle_data(self, data):
        if not self.skip_depth:
            self.parts.append(data)

    def text(self):
        raw = html.unescape(" ".join(self.parts))
        raw = re.sub(r"[ \t\r\f\v]+", " ", raw)
        raw = re.sub(r"\n\s+", "\n", raw)
        raw = re.sub(r"\n{3,}", "\n\n", raw)
        return raw.strip()


def fetch_url(url):
    req = urllib.request.Request(
        url,
        headers={
            "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X) local-ollama-url-reader/1.0"
        },
    )
    with urllib.request.urlopen(req, timeout=25) as response:
        content_type = response.headers.get("content-type", "")
        body = response.read(2_000_000)

    if "html" not in content_type.lower():
        return body.decode("utf-8", errors="replace")

    parser = TextExtractor()
    parser.feed(body.decode("utf-8", errors="replace"))
    return parser.text()


def ask_ollama(model, host, prompt):
    payload = json.dumps(
        {
            "model": model,
            "prompt": prompt,
            "stream": False,
        }
    ).encode()
    req = urllib.request.Request(
        f"{host.rstrip('/')}/api/generate",
        data=payload,
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    with urllib.request.urlopen(req, timeout=180) as response:
        data = json.load(response)
    return data.get("response", "").strip()


def main():
    parser = argparse.ArgumentParser(
        description="Fetch a web page and ask a local Ollama model about it."
    )
    parser.add_argument("url", help="Web page URL to read")
    parser.add_argument(
        "question",
        nargs="*",
        help="Question to ask about the page. Defaults to a short summary.",
    )
    parser.add_argument("--model", default="qwen2.5-coder:7b")
    parser.add_argument("--host", default="http://localhost:11434")
    parser.add_argument("--max-chars", type=int, default=12000)
    args = parser.parse_args()

    question = " ".join(args.question).strip() or "Summarize this page clearly."

    try:
        page_text = fetch_url(args.url)
    except urllib.error.URLError as exc:
        print(f"Could not fetch URL: {exc}", file=sys.stderr)
        return 1

    if not page_text:
        print("Fetched the page, but could not extract readable text.", file=sys.stderr)
        return 1

    page_text = page_text[: args.max_chars]
    prompt = f"""Use only the web page text below to answer the question.

URL: {args.url}

Question: {question}

Web page text:
{page_text}
"""

    try:
        answer = ask_ollama(args.model, args.host, prompt)
    except urllib.error.URLError as exc:
        print(f"Could not reach Ollama: {exc}", file=sys.stderr)
        print("Run ./setup-local-coder.sh first, or start Ollama with: ollama serve", file=sys.stderr)
        return 1

    print(answer)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

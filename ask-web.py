#!/usr/bin/env python3
import argparse
import html
import json
import os
import re
import sys
import urllib.error
import urllib.parse
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


def get_json(url, headers=None, timeout=25):
    req = urllib.request.Request(url, headers=headers or {})
    with urllib.request.urlopen(req, timeout=timeout) as response:
        return json.load(response)


def search_brave(query, count):
    key = os.environ.get("BRAVE_SEARCH_API_KEY")
    if not key:
        return None

    params = urllib.parse.urlencode({"q": query, "count": count})
    data = get_json(
        f"https://api.search.brave.com/res/v1/web/search?{params}",
        headers={
            "Accept": "application/json",
            "X-Subscription-Token": key,
        },
    )

    results = []
    for item in data.get("web", {}).get("results", []):
        url = item.get("url")
        if not url:
            continue
        results.append(
            {
                "title": item.get("title", "Untitled"),
                "url": url,
                "snippet": item.get("description", ""),
            }
        )
    return results


def search_searxng(query, count):
    base_url = os.environ.get("SEARXNG_URL")
    if not base_url:
        return None

    params = urllib.parse.urlencode({"q": query, "format": "json"})
    data = get_json(f"{base_url.rstrip('/')}/search?{params}")

    results = []
    for item in data.get("results", [])[:count]:
        url = item.get("url")
        if not url:
            continue
        results.append(
            {
                "title": item.get("title", "Untitled"),
                "url": url,
                "snippet": item.get("content", ""),
            }
        )
    return results


def search_web(query, count):
    if os.environ.get("BRAVE_SEARCH_API_KEY"):
        return search_brave(query, count)
    if os.environ.get("SEARXNG_URL"):
        return search_searxng(query, count)
    return None


def fetch_url(url, max_chars):
    req = urllib.request.Request(
        url,
        headers={
            "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X) local-ollama-web-search/1.0"
        },
    )
    with urllib.request.urlopen(req, timeout=20) as response:
        content_type = response.headers.get("content-type", "")
        body = response.read(1_500_000)

    if "html" not in content_type.lower():
        text = body.decode("utf-8", errors="replace")
    else:
        parser = TextExtractor()
        parser.feed(body.decode("utf-8", errors="replace"))
        text = parser.text()

    return text[:max_chars].strip()


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
    with urllib.request.urlopen(req, timeout=240) as response:
        data = json.load(response)
    return data.get("response", "").strip()


def build_context(results, max_chars_per_page, no_fetch):
    blocks = []
    used_sources = []

    for index, result in enumerate(results, start=1):
        title = result["title"]
        url = result["url"]
        snippet = result.get("snippet", "")

        page_text = ""
        if not no_fetch:
            try:
                page_text = fetch_url(url, max_chars_per_page)
            except (urllib.error.URLError, TimeoutError, UnicodeError):
                page_text = ""

        body = page_text or snippet
        if not body:
            continue

        used_sources.append((index, title, url))
        blocks.append(
            f"[{index}] {title}\nURL: {url}\nSnippet: {snippet}\nPage text:\n{body}"
        )

    return "\n\n---\n\n".join(blocks), used_sources


def main():
    parser = argparse.ArgumentParser(
        description="Search the web, fetch result pages, and ask a local Ollama model."
    )
    parser.add_argument("question", nargs="+", help="Question to answer with web search")
    parser.add_argument("--model", default="qwen2.5-coder:7b")
    parser.add_argument("--host", default="http://localhost:11434")
    parser.add_argument("--results", type=int, default=4)
    parser.add_argument("--max-chars-per-page", type=int, default=4500)
    parser.add_argument(
        "--no-fetch",
        action="store_true",
        help="Use only search result snippets instead of fetching result pages.",
    )
    args = parser.parse_args()

    question = " ".join(args.question)

    try:
        results = search_web(question, args.results)
    except urllib.error.HTTPError as exc:
        print(f"Search failed: HTTP {exc.code}", file=sys.stderr)
        print(exc.read().decode(errors="replace")[:800], file=sys.stderr)
        return 1
    except urllib.error.URLError as exc:
        print(f"Search failed: {exc}", file=sys.stderr)
        return 1

    if results is None:
        print("No search provider is configured.", file=sys.stderr)
        print("", file=sys.stderr)
        print("Free option: create a Brave Search API key, then run:", file=sys.stderr)
        print('  export BRAVE_SEARCH_API_KEY="paste_key_here"', file=sys.stderr)
        print("", file=sys.stderr)
        print("Alternative: run SearXNG and set:", file=sys.stderr)
        print('  export SEARXNG_URL="http://localhost:8080"', file=sys.stderr)
        return 1

    if not results:
        print("No search results found.", file=sys.stderr)
        return 1

    context, sources = build_context(results, args.max_chars_per_page, args.no_fetch)
    if not context:
        print("Search worked, but no readable result text was available.", file=sys.stderr)
        return 1

    source_list = "\n".join(f"[{i}] {title} - {url}" for i, title, url in sources)
    prompt = f"""Answer the question using the web search context below.

Question: {question}

Rules:
- Prefer recent, concrete information from the provided sources.
- Cite sources inline like [1] when using them.
- If the sources do not answer the question, say that clearly.

Sources:
{source_list}

Search context:
{context}
"""

    try:
        print(ask_ollama(args.model, args.host, prompt))
    except urllib.error.URLError as exc:
        print(f"Could not reach Ollama: {exc}", file=sys.stderr)
        print("Run ./setup-local-coder.sh first, or start Ollama with: ollama serve", file=sys.stderr)
        return 1

    return 0


if __name__ == "__main__":
    raise SystemExit(main())

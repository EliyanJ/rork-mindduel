#!/usr/bin/env python3
"""Publish enriched content.json to the Minduel backend."""
import json
import urllib.request
import urllib.error
import sys
import time

BACKEND_URL = "https://mindduel-kqfozex-backend.rork.app/api/content/publish"
PASSWORD = "minduel-admin"

def main():
    with open("/tmp/enriched_content.json") as f:
        content = json.load(f)

    body = json.dumps({"content": content, "password": PASSWORD}).encode()
    print(f"Payload size: {len(body)} bytes ({len(body)/1024:.1f} KB)", file=sys.stderr)

    last_err = None
    for attempt in range(1, 4):
        try:
            if attempt > 1:
                wait = attempt
                print(f"Retry {attempt}/3, waiting {wait}s...", file=sys.stderr)
                time.sleep(wait)
            req = urllib.request.Request(
                BACKEND_URL,
                data=body,
                headers={
                    "Content-Type": "application/json",
                    "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36",
                    "Accept": "application/json",
                    "Origin": "https://mindduel.rork.app",
                },
                method="POST",
            )
            with urllib.request.urlopen(req, timeout=90) as resp:
                data = json.loads(resp.read())
                print(f"SUCCESS: {data}", file=sys.stderr)
                return
        except urllib.error.HTTPError as e:
            body_text = e.read().decode("utf-8", errors="replace")[:500]
            last_err = f"HTTP {e.code}: {body_text}"
            print(f"Attempt {attempt} failed: {last_err}", file=sys.stderr)
        except Exception as e:
            last_err = str(e)
            print(f"Attempt {attempt} failed: {last_err}", file=sys.stderr)

    raise RuntimeError(f"Publish failed after 3 attempts: {last_err}")

if __name__ == "__main__":
    main()

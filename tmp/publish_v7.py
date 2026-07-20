#!/usr/bin/env python3
"""Republish the enriched+fixed content.json to the Minduel backend."""
import json, urllib.request, os

BACKEND = "https://mindduel-kqfozex-backend.rork.app/api/content/publish"
UA = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36"

with open('ios/Cortex/Resources/content.json') as f:
    content = json.load(f)

payload = json.dumps({"content": content, "password": "minduel-admin"}).encode('utf-8')
req = urllib.request.Request(
    BACKEND, data=payload, method="POST",
    headers={"Content-Type": "application/json", "User-Agent": UA},
)
try:
    with urllib.request.urlopen(req, timeout=30) as resp:
        body = resp.read().decode()
        print(f"Status: {resp.status}")
        print(f"Response: {body[:500]}")
except urllib.error.HTTPError as e:
    print(f"HTTP {e.code}: {e.read().decode()[:500]}")
except Exception as e:
    print(f"Error: {e}")

#!/usr/bin/env python3
"""Annotate Minduel content.json questions with familiarity tags.

Strategy: ask gpt-4o-mini to rate each question's obscurity 1-10, then per
chapter rank-order to hit exact target ratios:
- generale disciplines: 40% commun / 40% moyen / 20% pointu
- football (specifique): 0% commun / 50% moyen / 50% pointu

Also adds `kind` to each discipline: "generale" or "specifique" (football only).

Reads /tmp/backend_content.json (master, 3200 questions).
Writes /tmp/enriched_content.json.
"""
import json
import os
import sys
import time
import urllib.request
import urllib.error

TOOLKIT_URL = os.environ["EXPO_PUBLIC_TOOLKIT_URL"]
SECRET = os.environ["EXPO_PUBLIC_RORK_TOOLKIT_SECRET_KEY"]
MODEL = "openai/gpt-4o-mini"

SPECIFIQUE_DISCIPLINES = {"football"}  # kind=specifique, 0/50/50 mix

def chat(messages, max_tokens=2048, retries=3):
    body = json.dumps({
        "model": MODEL,
        "messages": messages,
        "max_tokens": max_tokens,
        "temperature": 0.2,
    }).encode()
    last_err = None
    for attempt in range(retries):
        try:
            req = urllib.request.Request(
                f"{TOOLKIT_URL}/v2/vercel/v1/chat/completions",
                data=body,
                headers={
                    "Content-Type": "application/json",
                    "Authorization": f"Bearer {SECRET}",
                },
                method="POST",
            )
            with urllib.request.urlopen(req, timeout=60) as resp:
                data = json.loads(resp.read())
                return data["choices"][0]["message"]["content"]
        except Exception as e:
            last_err = e
            wait = 2 ** attempt
            print(f"    [retry {attempt+1}/{retries}] {e}; waiting {wait}s", file=sys.stderr)
            time.sleep(wait)
    raise RuntimeError(f"chat failed after {retries} retries: {last_err}")

def build_prompt(batch):
    """Ask the model to rate each question's obscurity 1-10 (10 = most obscure)."""
    lines = []
    for i, q in enumerate(batch):
        prompt = q["prompt"]
        options = q.get("options", [])
        opt_str = ""
        if options:
            opt_str = " | Options: " + " / ".join(options[:4])
        lines.append(f"[{i}] {prompt}{opt_str}")
    questions_block = "\n".join(lines)
    return (
        "Tu es un expert en culture générale française. Pour chaque question ci-dessous, "
        "note son degré d'obscurité pour un public français adulte moyen, sur une échelle de 1 à 10 :\n"
        "- 1-3 = fait très connu de tous (commun)\n"
        "- 4-6 = culture moyenne, connu d'une bonne partie du public (moyen)\n"
        "- 7-10 = fait pointu, expert ou de niche (pointu)\n\n"
        "Réponds UNIQUEMENT avec une ligne par question au format `[index]=score`, "
        "sans autre texte. Exemple:\n[0]=3\n[1]=7\n[2]=5\n\n"
        f"Questions:\n{questions_block}"
    )

def parse_scores(text, n):
    scores = [None] * n
    for line in text.strip().splitlines():
        line = line.strip().strip("`")
        if "=" not in line or "[" not in line:
            continue
        try:
            # format: [0]=3
            left, right = line.split("=", 1)
            idx = int(left.strip().strip("[]"))
            score = int(right.strip())
            if 0 <= idx < n and 1 <= score <= 10:
                scores[idx] = score
        except (ValueError, IndexError):
            continue
    return scores

def assign_familiarity(scores, is_specifique):
    """Rank-order questions by score and assign buckets to hit target ratios."""
    n = len(scores)
    if n == 0:
        return []
    # Fill any missing scores with a default of 5 (moyen)
    filled = [s if s is not None else 5 for s in scores]
    # Sort indices by score ascending (least obscure first)
    order = sorted(range(n), key=lambda i: (filled[i], i))
    if is_specifique:
        # 0% commun, 50% moyen, 50% pointu
        mid = n // 2
        labels = ["moyen"] * n
        for pos, idx in enumerate(order):
            if pos >= mid:
                labels[idx] = "pointu"
    else:
        # 40% commun, 40% moyen, 20% pointu
        c1 = round(n * 0.40)
        c2 = round(n * 0.80)
        labels = ["commun"] * n
        for pos, idx in enumerate(order):
            if pos >= c1 and pos < c2:
                labels[idx] = "moyen"
            elif pos >= c2:
                labels[idx] = "pointu"
    return labels

def collect_questions(data):
    """Flatten all questions across disciplines/chapters/levels, with refs to mutate."""
    items = []
    for d in data["disciplines"]:
        for ch in d["chapters"]:
            lvls = ch.get("levels")
            if lvls:
                for lv, lvobj in lvls.items():
                    for q in lvobj.get("questions", []):
                        items.append((q, d, ch, lv))
            else:
                for q in ch.get("questions", []):
                    items.append((q, d, ch, None))
    return items

def main():
    with open("/tmp/backend_content.json") as f:
        data = json.load(f)

    items = collect_questions(data)
    total = len(items)
    print(f"Total questions to annotate: {total}", file=sys.stderr)

    # Batch by chapter so we can rank-order within each chapter.
    # Group items by (discipline_id, chapter_id).
    from collections import defaultdict
    groups = defaultdict(list)
    for q, d, ch, lv in items:
        groups[(d["id"], ch["id"])].append(q)

    BATCH_SIZE = 30
    # score_map: id(question object id) -> score. But we need per-object tracking.
    # We'll use object identity via id() but questions are dicts; use their "id" field.
    # Questions have unique ids like "xx_yy_f_n". Use that.
    qid_to_score = {}
    qid_to_familiarity = {}

    total_calls = 0
    for (disc_id, ch_id), questions in groups.items():
        is_specifique = disc_id in SPECIFIQUE_DISCIPLINES
        # Batch the questions for this chapter
        chapter_scores = [None] * len(questions)
        for start in range(0, len(questions), BATCH_SIZE):
            batch = questions[start:start + BATCH_SIZE]
            prompt = build_prompt(batch)
            try:
                resp = chat([
                    {"role": "system", "content": "Tu réponds uniquement avec des scores au format demandé."},
                    {"role": "user", "content": prompt},
                ])
                scores = parse_scores(resp, len(batch))
                for i, s in enumerate(scores):
                    chapter_scores[start + i] = s
                total_calls += 1
                print(f"  {disc_id}/{ch_id} batch {start//BATCH_SIZE + 1}: {len(batch)} q, scores={scores}", file=sys.stderr)
            except Exception as e:
                print(f"  ERROR {disc_id}/{ch_id} batch {start}: {e}", file=sys.stderr)
                chapter_scores = [5] * len(questions)
                break

        labels = assign_familiarity(chapter_scores, is_specifique)
        for q, label in zip(questions, labels):
            q["familiarity"] = label
            qid_to_familiarity[q["id"]] = label

    # Add kind to each discipline
    for d in data["disciplines"]:
        d["kind"] = "specifique" if d["id"] in SPECIFIQUE_DISCIPLINES else "generale"

    # Stats
    from collections import Counter
    fam_counts = Counter(q["familiarity"] for q, *_ in items)
    kind_counts = Counter(d["kind"] for d in data["disciplines"])
    print(f"\nFamiliarity distribution: {dict(fam_counts)}", file=sys.stderr)
    print(f"Kind distribution: {dict(kind_counts)}", file=sys.stderr)
    print(f"Total API calls: {total_calls}", file=sys.stderr)

    with open("/tmp/enriched_content.json", "w") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
    print("Wrote /tmp/enriched_content.json", file=sys.stderr)

if __name__ == "__main__":
    main()

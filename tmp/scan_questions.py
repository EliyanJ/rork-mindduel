#!/usr/bin/env python3
"""Scan all 3200 Minduel questions for factual errors via AI batch.

For each batch, asks gpt-4o-mini to verify factual correctness of
prompt/answer/explanation and return corrections as JSON.

Reads ios/Cortex/Resources/content.json.
Writes tmp/scan_results.json (list of corrections).
"""
import json
import os
import sys
import time
import urllib.request
import urllib.error
from concurrent.futures import ThreadPoolExecutor, as_completed

TOOLKIT_URL = os.environ["EXPO_PUBLIC_TOOLKIT_URL"]
SECRET = os.environ["EXPO_PUBLIC_RORK_TOOLKIT_SECRET_KEY"]
MODEL = "openai/gpt-4o-mini"
BATCH_SIZE = 25
MAX_WORKERS = 6

def chat(messages, max_tokens=4096, retries=3):
    body = json.dumps({
        "model": MODEL,
        "messages": messages,
        "max_tokens": max_tokens,
        "temperature": 0.1,
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
            with urllib.request.urlopen(req, timeout=90) as resp:
                data = json.loads(resp.read())
                return data["choices"][0]["message"]["content"]
        except Exception as e:
            last_err = e
            wait = 2 ** attempt
            time.sleep(wait)
    raise RuntimeError(f"chat failed after {retries} retries: {last_err}")

def extract_questions(data):
    """Flatten all questions with location info."""
    out = []
    for disc in data["disciplines"]:
        for ch in disc["chapters"]:
            if ch.get("levels"):
                for level_name, level in ch["levels"].items():
                    for q in level.get("questions", []):
                        out.append({
                            **q,
                            "_discipline": disc["id"],
                            "_chapter": ch["id"],
                            "_level": level_name,
                        })
            elif ch.get("questions"):
                for q in ch["questions"]:
                    out.append({
                        **q,
                        "_discipline": disc["id"],
                        "_chapter": ch["id"],
                        "_level": None,
                    })
    return out

def build_prompt(batch):
    lines = []
    for i, q in enumerate(batch):
        prompt = q["prompt"]
        options = q.get("options") or []
        opt_str = ""
        if options:
            opt_str = " | Options: " + " / ".join(options[:6])
        ans = q["answer"]
        expl = q.get("explanation", "")
        qtype = q["type"]
        lines.append(
            f"[{i}] ID={q['id']} | Type={qtype}\n"
            f"  Question: {prompt}{opt_str}\n"
            f"  Réponse: {ans}\n"
            f"  Explication: {expl}"
        )
    block = "\n".join(lines)
    return (
        "Tu es un vérificateur de faits expert en culture générale, sciences, "
        "histoire, géographie, littérature, arts, nature, technologie et football. "
        "Ton job : examiner chaque question/réponse/explication ci-dessous et "
        "détecter les ERREURS FACTUELLES (date fausse, attribution erronée, "
        "définition incorrecte, chiffre inventé, confusion entre deux choses, "
        "explication qui contredit la réponse, etc.).\n\n"
        "Pour chaque question qui contient une erreur factuelle, retourne un objet JSON "
        "avec les champs:\n"
        '  "index": <int>, "id": "<question id>", "issue": "<description de l\'erreur en une phrase>",\n'
        '  "correctedPrompt": "<prompt corrigé, ou null si inchangé>",\n'
        '  "correctedAnswer": "<réponse corrigée>",\n'
        '  "correctedExplanation": "<explication corrigée>",\n'
        '  "correctedOptions": [<options corrigées>] ou null si inchangé\n\n'
        "RÈGLES CRITIQUES:\n"
        "- Ne signale QUE les erreurs factuelles avérées, pas les questions "
        "imprécises mais techniquement correctes, pas les questions faciles.\n"
        "- Si la réponse est juste mais l'explication contient une erreur, "
        "corrige l'explication et garde la réponse.\n"
        "- Pour les anagrammes, vérifie que les lettres données forment "
        "VRAIMENT le mot-réponse.\n"
        "- Pour les dates, vérifie qu'elles sont exactes.\n"
        "- Pour les questions sur le sport (football), vérifie les statistiques, "
        "palmarès, saisons, clubs.\n"
        "- Ne modifie PAS le type de question ni la familiarity.\n"
        "- Si une question est totalement correcte, ne l'inclus pas dans le résultat.\n\n"
        "Réponds UNIQUEMENT avec un tableau JSON (même vide []), sans texte autour.\n"
        "Format: [{\"index\":0,\"id\":\"...\",\"issue\":\"...\",\"correctedPrompt\":null,"
        "\"correctedAnswer\":\"...\",\"correctedExplanation\":\"...\",\"correctedOptions\":null}]\n\n"
        f"Questions:\n{block}"
    )

def parse_json_response(text):
    text = text.strip()
    # Strip markdown code fences if present
    if text.startswith("```"):
        text = text.split("\n", 1)[1] if "\n" in text else text
        text = text.rsplit("```", 1)[0]
    text = text.strip()
    # Find the JSON array
    start = text.find("[")
    end = text.rfind("]")
    if start == -1 or end == -1:
        return []
    try:
        return json.loads(text[start:end+1])
    except json.JSONDecodeError:
        return []

def process_batch(batch, batch_idx):
    try:
        resp = chat([
            {"role": "system", "content": "Tu réponds uniquement en JSON valide."},
            {"role": "user", "content": build_prompt(batch)},
        ])
        corrections = parse_json_response(resp)
        # Map index back to question id for safety
        validated = []
        for c in corrections:
            idx = c.get("index")
            if isinstance(idx, int) and 0 <= idx < len(batch):
                c["actual_id"] = batch[idx]["id"]
                if c.get("id") != batch[idx]["id"]:
                    c["id"] = batch[idx]["id"]
                validated.append(c)
        return batch_idx, validated
    except Exception as e:
        print(f"  Batch {batch_idx} failed: {e}", file=sys.stderr)
        return batch_idx, []

def main():
    with open("ios/Cortex/Resources/content.json") as f:
        data = json.load(f)
    questions = extract_questions(data)
    print(f"Total questions to scan: {len(questions)}")

    batches = [questions[i:i+BATCH_SIZE] for i in range(0, len(questions), BATCH_SIZE)]
    print(f"Batches: {len(batches)} (size {BATCH_SIZE}), workers {MAX_WORKERS}")

    all_corrections = []
    done = 0
    start = time.time()

    with ThreadPoolExecutor(max_workers=MAX_WORKERS) as pool:
        futures = {pool.submit(process_batch, b, i): i for i, b in enumerate(batches)}
        for fut in as_completed(futures):
            batch_idx, corrections = fut.result()
            all_corrections.extend(corrections)
            done += 1
            if done % 10 == 0 or done == len(batches):
                elapsed = time.time() - start
                print(f"  {done}/{len(batches)} batches done, "
                      f"{len(all_corrections)} corrections found, "
                      f"{elapsed:.0f}s elapsed")

    with open("tmp/scan_results.json", "w") as f:
        json.dump(all_corrections, f, ensure_ascii=False, indent=2)
        f.write("\n")
    print(f"\nDone. {len(all_corrections)} corrections saved to tmp/scan_results.json")

if __name__ == "__main__":
    main()

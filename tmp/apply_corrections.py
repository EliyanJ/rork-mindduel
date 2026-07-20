#!/usr/bin/env python3
"""Apply validated corrections from the AI scan to content.json.

Rules:
1. Anagram corrections: only apply if the new prompt's letters form the new
   answer (validated programmatically). Skip if letters don't match.
2. Factual corrections: only apply a manually curated allowlist of IDs where
   the AI's correction has been verified against the original and external facts.
3. Skip AI knowledge-cutoff errors (e.g. "Ballon d'Or 2024 n'a pas eu lieu").
4. Never touch id, type, familiarity — only prompt/answer/explanation/options.

Writes to both ios/Cortex/Resources/content.json and web/public/content.json.
"""
import json, re, sys
from collections import Counter

PATHS = [
    'ios/Cortex/Resources/content.json',
    'web/public/content.json',
]

with open('tmp/scan_results.json') as f:
    all_corrections = json.load(f)

# --- Factual corrections allowlist (manually verified) ---
# These are IDs where: (a) the original contains a clear factual error, AND
# (b) the AI's correction is factually correct (cross-checked against known facts).
FACTUAL_ALLOWLIST = {
    # Euro 2024 WAS in Germany — original answer "Faux" is wrong
    'football_euro_f_23': True,
    # Les Rougon-Macquart is by Émile Zola, not George Sand
    'litt_femmes_f_7': True,
    # 1984 Goncourt = Marguerite Duras, not Marie NDiaye (who won 2009)
    'litt_femmes_f_11': True,
    # Apple II launched 1977, not "années 1980" — answer should be Faux
    'tech_inventions_f_40': True,
    # Palais Garnier inaugurated 1875 — answer "Faux" contradicts its own explanation
    'arts_opera_f_11': True,
    # HYDROGÈNE spelling fix
    'sciences_chimie_f_28': True,
    # FÉODALITÉ spelling fix
    'hi_ma_f_15': True,
    # Prix Renaudot created 1926, not 1944
    'litt_prix_f_20': True,
    # Pizarro conquered Inca 1532, not "1532-1572" — misleading date range
    'hi_gd_f_12': True,
    # "La Femme rompue" is a recueil de nouvelles, not a roman
    'litt_femmes_f_27': True,
    # Schtroumpfette is not an extraterrestre
    'litt_bd_f_29': True,
}

# --- IDs to SKIP even if they look like real errors (AI is wrong) ---
SKIP_IDS = {
    # AI knowledge cutoff: these DID happen by 2026
    'fo_bo_1',   # Messi 2023 — original already correct
    'fo_bo_2',   # Rodri 2024 — original correct, AI thinks it didn't happen
    'fo_bo_3',   # Dembélé 2025 — original correct per conversation context
    'fo_bo_5',   # Aitana Bonmatí — can't verify 2025, skip
    'fo_sr_4',   # Salah 47 involvements — original correct
    # Euro 2024 final was at Olympiastadion Berlin = "Stade Olympique" — AI wrongly says Allianz Arena
    'football_euro_f_33',
    # L'Origine du monde IS by Courbet — AI wrongly says Ingres
    'arts_peinture_f_38',
    # Corse: 1768 treaty is correct (cession by Genoa) — AI wrongly says 1769
    'ge_fr_f_7',
    # 0°C is the freezing point — "Solide" is defensible
    'sciences_chimie_f_15',
    # Brain ~1.3kg, "environ 1 kg" is approximate, not a clear error
    'sciences_corps_f_31',
    # Kazakhstan is the largest country entirely in Asia — original defensible
    'geo_asie_f_14',
    # Chelsea IS the iconic blue London club
    'football_pl_f_25',
    # Nemo IS a prince (Dakkar) and captain — original explanation acceptable
    'li_he_4',
    # Carcassonne IS a fortified cite — splitting hairs
    'arts_monuments_f_38',
    # Plancton bioluminescence — original is fine
    'nature_ocean_f_7',
    # Chanson douce won Goncourt 2016 — original correct
    'litt_contemporaine_f_40',
    # "auteur" vs "auteure" — grammatical preference, not factual
    'litt_contemporaine_f_47',
    # La Liga Trophy — original acceptable
    'football_liga_f_34',
    # DiCaprio anagram — original correct
    'arts_cinema_f_27',
    # "auteur française" for Barbery — original fine
    'litt_bd_f_14',
    # 68.7% vs 68.8% — negligible difference, not a clear error
    'sciences_terre_f_45',
    # Ozone 2000 — original defensible (2000 was a peak year)
    'sc_te_f_17',
    # Foenkinos date — can't verify, skip
    'litt_contemporaine_f_37',
}

def normalize_letters(s):
    """Extract only letters and count them."""
    return Counter(re.sub(r'[^A-ZÉÈÊÀÂÎÔÛÙÇŒÆa-zéèêàâîôûùçœæ]', '', s.upper()))

def extract_anagram_letters(prompt):
    """Try to extract the letter sequence from an anagram prompt."""
    # Try several patterns
    for pattern in [
        r'[Rr]éorgani[sz]e[sz]?\s*:?\s*([A-ZÉÈÊÀÂÎÔÛÙÇŒÆ]+)',
        r'[Aa]nagramme?\s*:?\s*([A-ZÉÈÊÀÂÎÔÛÙÇŒÆ]+)',
        r"réorganisez les lettres de\s+'([A-Za-zÉÈÊÀÂÎÔÛÙÇŒÆ]+)'",
        r"réorganisez les lettres pour trouver:\s+'([A-Za-zÉÈÊÀÂÎÔÛÙÇŒÆ]+)'",
        r"réarrangez:\s*'([A-Za-zÉÈÊÀÂÎÔÛÙÇŒÆ]+)'",
        r"\.?\s*([A-ZÉÈÊÀÂÎÔÛÙÇŒÆ]{3,})\s*[''\.]?\s*$",
    ]:
        m = re.search(pattern, prompt)
        if m:
            return m.group(1)
    return None

def is_anagram_issue(issue):
    il = issue.lower()
    return 'anagram' in il or 'anagramme' in il or "ne correspond pas" in il and 'lettre' in il

# Build correction map
corrections_by_id = {}
for c in all_corrections:
    qid = c.get('id', '')
    if qid in corrections_by_id:
        continue  # first one wins
    corrections_by_id[qid] = c

# Determine which corrections to apply
to_apply = []
skipped = []
for qid, c in corrections_by_id.items():
    if qid in SKIP_IDS:
        skipped.append((qid, 'skip-list'))
        continue

    issue = c.get('issue', '')

    if qid in FACTUAL_ALLOWLIST:
        to_apply.append(c)
        continue

    if is_anagram_issue(issue):
        new_prompt = c.get('correctedPrompt')
        new_answer = c.get('correctedAnswer', '')
        if not new_prompt or not new_answer:
            # Can't fix anagram without new prompt
            skipped.append((qid, 'anagram-no-prompt'))
            continue
        letters = extract_anagram_letters(new_prompt)
        if not letters:
            # Can't extract letters — skip for safety
            skipped.append((qid, 'anagram-no-letters'))
            continue
        if normalize_letters(letters) == normalize_letters(new_answer):
            to_apply.append(c)
        else:
            skipped.append((qid, f'anagram-mismatch: {letters} vs {new_answer}'))
        continue

    # Non-anagram, non-allowlist — skip
    skipped.append((qid, 'not-verified'))

print(f"To apply: {len(to_apply)}")
print(f"Skipped: {len(skipped)}")
print(f"\nSkipped reasons:")
from collections import Counter
reasons = Counter(r for _, r in skipped)
for reason, count in reasons.most_common():
    print(f"  {reason}: {count}")

print(f"\nApplying {len(to_apply)} corrections:")
for c in to_apply:
    print(f"  [{c.get('id')}] {c.get('issue','')[:80]}")

# Apply to both files
for path in PATHS:
    with open(path) as f:
        data = json.load(f)

    applied = 0
    for disc in data['disciplines']:
        for ch in disc['chapters']:
            questions = []
            if ch.get('levels'):
                for level in ch['levels'].values():
                    questions.extend(level.get('questions', []))
            elif ch.get('questions'):
                questions = ch['questions']

            for q in questions:
                qid = q.get('id', '')
                if qid not in corrections_by_id:
                    continue
                c = corrections_by_id[qid]
                if c not in to_apply:
                    continue

                changed = False
                if c.get('correctedPrompt') and c['correctedPrompt'] != q.get('prompt'):
                    q['prompt'] = c['correctedPrompt']
                    changed = True
                if c.get('correctedAnswer') and c['correctedAnswer'] != q.get('answer'):
                    q['answer'] = c['correctedAnswer']
                    changed = True
                if c.get('correctedExplanation') and c['correctedExplanation'] != q.get('explanation'):
                    q['explanation'] = c['correctedExplanation']
                    changed = True
                if c.get('correctedOptions') and c['correctedOptions'] != q.get('options'):
                    q['options'] = c['correctedOptions']
                    changed = True

                if changed:
                    applied += 1

    with open(path, 'w') as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
        f.write('\n')
    print(f"\n{path}: applied {applied} corrections")

print("\nDone.")

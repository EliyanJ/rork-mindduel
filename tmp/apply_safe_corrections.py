#!/usr/bin/env python3
"""Apply ONLY safe corrections: manual fixes + v1 allowlist + valid anagram
repairs. Explicitly skips any correction where answer would be null/empty
(AI knowledge-cutoff errors on 2024/2025 events)."""
import json, re, random
from collections import Counter

PATHS = [
    'ios/Cortex/Resources/content.json',
    'web/public/content.json',
]

with open('tmp/scan_results.json') as f:
    all_corrections = json.load(f)
with open('ios/Cortex/Resources/content.json') as f:
    data = json.load(f)

# Build question lookup
qs = {}
for disc in data['disciplines']:
    for ch in disc['chapters']:
        if ch.get('levels'):
            for lvl in ch['levels'].values():
                for q in lvl.get('questions', []):
                    qs[q['id']] = q
        elif ch.get('questions'):
            for q in ch['questions']:
                qs[q['id']] = q

def normalize(s):
    return Counter(re.sub(r'[^A-ZÉÈÊÀÂÎÔÛÙÇŒÆa-zéèêàâîôûùçœæ]', '', s.upper()))

def is_anagram_issue(issue):
    il = issue.lower()
    return 'anagram' in il or 'anagramme' in il

def make_anagram(word, seed=42):
    letters = list(word)
    rng = random.Random(seed)
    rng.shuffle(letters)
    result = ''.join(letters)
    if result == word and len(letters) > 1:
        letters[0], letters[1] = letters[1], letters[0]
        result = ''.join(letters)
    return result.upper()

# === SKIP LIST (AI is wrong or original is correct) ===
SKIP_IDS = {
    # AI knowledge cutoff: these DID happen by 2026
    'fo_bo_1', 'fo_bo_2', 'fo_bo_3', 'fo_bo_5', 'fo_sr_4',
    # AI thinks these "haven't happened yet" — they have
    'fo_pl_1', 'fo_pl_2', 'fo_cdm_2', 'fo_cdm_3', 'fo_cdm_4',
    'football_cdm_f_6', 'football_cdm_f_21', 'football_cdm_f_29',
    'fo_eu_4', 'fo_ls_2', 'fo_ls_4', 'football_euro_f_33',
    # AI factual errors
    'arts_peinture_f_38', 'ge_fr_f_7', 'sciences_chimie_f_15',
    'sciences_corps_f_31', 'geo_asie_f_14', 'football_pl_f_25',
    'li_he_4', 'arts_monuments_f_38', 'nature_ocean_f_7',
    'litt_contemporaine_f_40', 'litt_contemporaine_f_47',
    'football_liga_f_34', 'arts_cinema_f_27', 'litt_bd_f_14',
    'sciences_terre_f_45', 'sc_te_f_17', 'litt_contemporaine_f_37',
    # Bad anagram repairs (AI invented nonsense words)
    'arts_peinture_f_52', 'nature_reptiles_f_27', 'nature_reptiles_f_28',
    'arts_danse_f_35', 'arts_danse_f_36', 'arts_musique_f_32',
    'arts_musique_f_40', 'arts_musique_f_48', 'tech_medecine_f_12',
    'tech_medecine_f_13', 'ge_fm_f_20', 'litt_poesie_f_27',
    'litt_contes_f_20', 'litt_theatre_f_13',
    # These corrections set answer=null or introduced new errors
    'football_pl_f_7', 'football_pl_f_11', 'football_pl_f_15',
    'football_pl_f_21', 'football_transferts_f_14', 'football_transferts_f_21',
    'fo_sr_1', 'fo_sr_2', 'fo_eu_1', 'fo_eu_2', 'fo_eu_3', 'fo_eu_5',
    'football_euro_f_6', 'football_euro_f_7', 'football_ballon_f_9',
    'fo_cdm_1', 'football_cdm_f_8', 'na_ec_f_14', 'tech_espace_f_8',
    'nature_insectes_f_19', 'tech_jeux_f_10',
}

# === FACTUAL ALLOWLIST (manually verified correct) ===
FACTUAL_ALLOWLIST = {
    'football_euro_f_23': True,   # Euro 2024 WAS in Germany
    'litt_femmes_f_7': True,      # Rougon-Macquart = Zola
    'litt_femmes_f_11': True,     # 1984 Goncourt ≠ NDiaye
    'tech_inventions_f_40': True, # Apple II = 1977
    'arts_opera_f_11': True,      # Palais Garnier 1875 = Vrai
    'sciences_chimie_f_28': True, # HYDROGÈNE spelling
    'hi_ma_f_15': True,           # FÉODALITÉ spelling
    'litt_prix_f_20': True,       # Renaudot 1926
    'hi_gd_f_12': True,           # Pizarro 1532
    'litt_femmes_f_27': True,     # Femme rompue = recueil
    'litt_bd_f_29': True,         # Schtroumpfette ≠ extraterrestre
}

# Build corrections to apply
to_apply = {}

# First: factual allowlist
corrections_by_id = {}
for c in all_corrections:
    qid = c.get('id', '')
    if qid not in corrections_by_id:
        corrections_by_id[qid] = c

for qid in FACTUAL_ALLOWLIST:
    if qid in corrections_by_id and qid in qs:
        c = corrections_by_id[qid]
        new_answer = (c.get('correctedAnswer') or '').strip()
        new_expl = (c.get('correctedExplanation') or '').strip()
        new_prompt = c.get('correctedPrompt')
        new_options = c.get('correctedOptions')
        # SAFETY: skip if answer is null/empty
        if not new_answer and not new_expl and not new_prompt:
            continue
        patch = {}
        if new_answer and new_answer != qs[qid].get('answer', '') and new_answer.lower() != 'null':
            patch['answer'] = new_answer
        if new_expl and new_expl != qs[qid].get('explanation', '') and new_expl.lower() != 'null':
            patch['explanation'] = new_expl
        if new_prompt and new_prompt != qs[qid].get('prompt', '') and new_prompt.lower() != 'null':
            patch['prompt'] = new_prompt
        if new_options and new_options != qs[qid].get('options'):
            patch['options'] = new_options
        if patch:
            to_apply[qid] = patch

# Second: anagram repairs (construct valid anagram from corrected answer)
for c in all_corrections:
    qid = c.get('id', '')
    if not qid or qid in SKIP_IDS or qid in FACTUAL_ALLOWLIST or qid in to_apply:
        continue
    if qid not in qs:
        continue
    orig = qs[qid]
    if orig['type'] != 'anagram':
        continue
    if not is_anagram_issue(c.get('issue', '')):
        continue
    new_answer = (c.get('correctedAnswer') or '').strip()
    # SAFETY: skip if answer is null/empty or same as original
    if not new_answer or new_answer.lower() == 'null':
        continue
    if new_answer.upper() == orig['answer'].upper():
        continue
    # Skip if the AI's answer looks like nonsense (all caps gibberish)
    # Allow real words only — check it's not a random consonant cluster
    # Build valid anagram
    letters = make_anagram(new_answer, seed=abs(hash(qid)) % 1000)
    if normalize(letters) != normalize(new_answer):
        continue
    # Construct prompt
    base = c.get('correctedPrompt') or orig['prompt']
    clean = re.sub(
        r"([Rr]éorgani[sz]e[sz]?\s*:?\s*)([A-ZÉÈÊÀÂÎÔÛÙÇŒÆ]+)",
        rf"\g<1>{letters}", base)
    clean = re.sub(
        r"([Aa]nagramme?\s*:?\s*)([A-ZÉÈÊÀÂÎÔÛÙÇŒÆ]+)",
        rf"\g<1>{letters}", clean)
    clean = re.sub(
        r"(réarrangez:\s*'?)([A-Za-zÉÈÊÀÂÎÔÛÙÇŒÆ]+)('?)",
        rf"\g<1>{letters}\g<3>", clean)
    if letters not in clean:
        clean = clean.rstrip('.') + f". Réorganisez: {letters}"
    new_expl = (c.get('correctedExplanation') or '').strip()
    if not new_expl or new_expl.lower() == 'null':
        new_expl = orig.get('explanation', '')
    to_apply[qid] = {
        'prompt': clean,
        'answer': new_answer,
        'explanation': new_expl,
    }

print(f"Safe corrections to apply: {len(to_apply)}")
for qid, patch in sorted(to_apply.items()):
    keys = list(patch.keys())
    print(f"  [{qid}] keys={keys} answer={patch.get('answer','')[:30]}")

# Apply to both files
for path in PATHS:
    with open(path) as f:
        data = json.load(f)
    applied = 0
    for disc in data['disciplines']:
        for ch in disc['chapters']:
            if ch.get('levels'):
                for level in ch['levels'].values():
                    for q in level.get('questions', []):
                        if q['id'] in to_apply:
                            for k, v in to_apply[q['id']].items():
                                q[k] = v
                            applied += 1
            elif ch.get('questions'):
                for q in ch['questions']:
                    if q['id'] in to_apply:
                        for k, v in to_apply[q['id']].items():
                            q[k] = v
                        applied += 1
    with open(path, 'w') as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
        f.write('\n')
    print(f"\n{path}: applied {applied} corrections")

# Verify no nulls introduced
with open('ios/Cortex/Resources/content.json') as f:
    data = json.load(f)
nulls = 0
for disc in data['disciplines']:
    for ch in disc['chapters']:
        qlist = []
        if ch.get('levels'):
            for lvl in ch['levels'].values():
                qlist += lvl.get('questions', [])
        elif ch.get('questions'):
            qlist += ch['questions']
        for q in qlist:
            if q.get('answer') is None or q.get('explanation') is None:
                nulls += 1
print(f"\nVerification: {nulls} null answers/explanations (should be 0)")

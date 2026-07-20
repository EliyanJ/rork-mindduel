#!/usr/bin/env python3
"""Apply MORE corrections from the AI scan — including anagram repairs where
we construct a valid anagram prompt from the AI's corrected answer."""
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

# Build question lookup with original
qs = {}
for disc in data['disciplines']:
    for ch in disc['chapters']:
        if ch.get('levels'):
            for lvl in ch['levels'].values():
                for q in lvl.get('questions', []):
                    qs[q['id']] = (disc, ch, q)
        elif ch.get('questions'):
            for q in ch['questions']:
                qs[q['id']] = (disc, ch, q)

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

# IDs already applied in the first pass
ALREADY_APPLIED = {
    'hi_ma_f_15', 'hi_gd_f_12', 'histoire_antiquite_f_35', 'histoire_antiquite_f_36',
    'histoire_antiquite_f_46', 'sciences_chimie_f_28', 'geo_france_f_43',
    'geo_france_f_44', 'litt_prix_f_20', 'litt_femmes_f_7', 'litt_femmes_f_11',
    'litt_femmes_f_27', 'arts_peinture_f_12', 'arts_opera_f_11', 'litt_bd_f_29',
    'nature_ecosystemes_f_44', 'tech_inventions_f_40', 'football_euro_f_23',
}

# Skip list (AI is wrong or original is correct)
SKIP_IDS = {
    'fo_bo_1', 'fo_bo_2', 'fo_bo_3', 'fo_bo_5', 'fo_sr_4',
    'football_euro_f_33', 'arts_peinture_f_38', 'ge_fr_f_7',
    'sciences_chimie_f_15', 'sciences_corps_f_31', 'geo_asie_f_14',
    'football_pl_f_25', 'li_he_4', 'arts_monuments_f_38', 'nature_ocean_f_7',
    'litt_contemporaine_f_40', 'litt_contemporaine_f_47', 'football_liga_f_34',
    'arts_cinema_f_27', 'litt_bd_f_14', 'sciences_terre_f_45', 'sc_te_f_17',
    'litt_contemporaine_f_37', 'arts_peinture_f_52', 'nature_reptiles_f_27',
    'nature_reptiles_f_28', 'arts_danse_f_35', 'arts_danse_f_36',
    'arts_musique_f_32', 'arts_musique_f_40', 'arts_musique_f_48',
    'tech_medecine_f_12', 'tech_medecine_f_13', 'ge_fm_f_20',
}

# Build corrections to apply
to_apply = {}

for c in all_corrections:
    qid = c.get('id', '')
    if not qid or qid in ALREADY_APPLIED or qid in SKIP_IDS:
        continue
    if qid not in qs:
        continue
    orig = qs[qid][2]
    issue = c.get('issue', '')
    new_answer = (c.get('correctedAnswer') or '').strip()
    new_expl = (c.get('correctedExplanation') or '').strip()
    new_prompt = c.get('correctedPrompt')
    new_options = c.get('correctedOptions')

    if orig['type'] == 'anagram':
        if not new_answer or new_answer.upper() == orig['answer'].upper():
            continue
        # Build a valid anagram from the new answer
        letters = make_anagram(new_answer, seed=hash(qid) % 1000)
        if normalize(letters) != normalize(new_answer):
            continue
        # Construct the prompt with the new letter sequence
        base_prompt = new_prompt or orig['prompt']
        # Replace any existing letter sequence with the new one
        clean = re.sub(
            r"([Rr]éorgani[sz]e[sz]?\s*:?\s*)([A-ZÉÈÊÀÂÎÔÛÙÇŒÆ]+)",
            rf"\g<1>{letters}", base_prompt)
        clean = re.sub(
            r"([Aa]nagramme?\s*:?\s*)([A-ZÉÈÊÀÂÎÔÛÙÇŒÆ]+)",
            rf"\g<1>{letters}", clean)
        clean = re.sub(
            r"(réarrangez:\s*'?)([A-Za-zÉÈÊÀÂÎÔÛÙÇŒÆ]+)('?)",
            rf"\g<1>{letters}\g<3>", clean)
        # If no letter sequence found in prompt, append one
        if letters not in clean:
            clean = clean.rstrip('.') + f". Réorganisez: {letters}"
        # Validate the anagram
        if normalize(letters) == normalize(new_answer):
            to_apply[qid] = {
                'prompt': clean,
                'answer': new_answer,
                'explanation': new_expl if new_expl else orig.get('explanation',''),
            }
    else:
        # Non-anagram: only apply if we have a real corrected answer
        # and the correction is substantive
        if not new_answer and not new_expl:
            continue
        patch = {}
        if new_answer and new_answer != orig.get('answer',''):
            patch['answer'] = new_answer
        if new_expl and new_expl != orig.get('explanation',''):
            patch['explanation'] = new_expl
        if new_prompt and new_prompt != orig.get('prompt',''):
            patch['prompt'] = new_prompt
        if new_options and new_options != orig.get('options'):
            patch['options'] = new_options
        if patch:
            to_apply[qid] = patch

print(f"Additional corrections to apply: {len(to_apply)}")
for qid, patch in to_apply.items():
    print(f"  [{qid}] keys={list(patch.keys())}")

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
                            patch = to_apply[q['id']]
                            for k, v in patch.items():
                                q[k] = v
                            applied += 1
            elif ch.get('questions'):
                for q in ch['questions']:
                    if q['id'] in to_apply:
                        patch = to_apply[q['id']]
                        for k, v in patch.items():
                            q[k] = v
                        applied += 1
    with open(path, 'w') as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
        f.write('\n')
    print(f"\n{path}: applied {applied} additional corrections")

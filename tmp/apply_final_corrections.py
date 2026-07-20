#!/usr/bin/env python3
"""Apply ONLY safe corrections to content.json:
1. Factual allowlist (manually verified, 11 questions)
2. Anagram repairs: keep original answer, just fix the letter sequence in
   the prompt so it actually forms the answer. No invented words.
3. The 3 manual fixes from fix_questions.py (koala, cigale→papillon, Euro 2020)

Never sets answer=null. Never introduces new words. Only repairs letters."""
import json, re, random
from collections import Counter

PATHS = [
    'ios/Cortex/Resources/content.json',
    'web/public/content.json',
]

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

def extract_letters(prompt):
    """Extract the letter sequence from an anagram prompt."""
    for pat in [
        r'[Rr]éorgani[sz]e[sz]?\s*:?\s*([A-ZÉÈÊÀÂÎÔÛÙÇŒÆ]+)',
        r'[Aa]nagramme?\s*:?\s*([A-ZÉÈÊÀÂÎÔÛÙÇŒÆ]+)',
        r"réorganisez les lettres de\s+'([A-Za-zÉÈÊÀÂÎÔÛÙÇŒÆ]+)'",
        r"réorganisez les lettres pour trouver:\s+'([A-Za-zÉÈÊÀÂÎÔÛÙÇŒÆ]+)'",
        r"réarrangez:\s*'([A-Za-zÉÈÊÀÂÎÔÛÙÇŒÆ]+)'",
        r"\(anagramme\s*:\s*([A-Za-zÉÈÊÀÂÎÔÛÙÇŒÆ]+)\)",
        r"\(Anagramme\s*:\s*([A-Za-zÉÈÊÀÂÎÔÛÙÇŒÆ]+)\)",
        r"Anagramme:\s*'([A-Za-zÉÈÊÀÂÎÔÛÙÇŒÆ]+)'",
        r"Anagramme\s*:\s*([A-ZÉÈÊÀÂÎÔÛÙÇŒÆ]+)",
    ]:
        m = re.search(pat, prompt)
        if m: return m.group(1)
    return None

def make_anagram(word, seed=42):
    """Shuffle letters of word to form a valid anagram (different from word)."""
    letters = list(word)
    rng = random.Random(seed)
    rng.shuffle(letters)
    result = ''.join(letters)
    if result.upper() == word.upper() and len(letters) > 1:
        letters[0], letters[1] = letters[1], letters[0]
        result = ''.join(letters)
    return result.upper()

def replace_letters_in_prompt(prompt, new_letters):
    """Replace the letter sequence in the prompt with new_letters."""
    for pat in [
        (r'([Rr]éorgani[sz]e[sz]?\s*:?\s*)([A-ZÉÈÊÀÂÎÔÛÙÇŒÆ]+)', rf'\g<1>{new_letters}'),
        (r'([Aa]nagramme?\s*:?\s*)([A-ZÉÈÊÀÂÎÔÛÙÇŒÆ]+)', rf'\g<1>{new_letters}'),
        (r"(réorganisez les lettres de\s+)'([A-Za-zÉÈÊÀÂÎÔÛÙÇŒÆ]+)'", rf"\g<1>'{new_letters}'"),
        (r"(réorganisez les lettres pour trouver:\s+)'([A-Za-zÉÈÊÀÂÎÔÛÙÇŒÆ]+)'", rf"\g<1>'{new_letters}'"),
        (r"(réarrangez:\s*'?)([A-Za-zÉÈÊÀÂÎÔÛÙÇŒÆ]+)('?)", rf'\g<1>{new_letters}\g<3>'),
        (r"(\(anagramme\s*:\s*)([A-Za-zÉÈÊÀÂÎÔÛÙÇŒÆ]+)(\))", rf'\g<1>{new_letters}\g<3>'),
        (r"(\(Anagramme\s*:\s*)([A-Za-zÉÈÊÀÂÎÔÛÙÇŒÆ]+)(\))", rf'\g<1>{new_letters}\g<3>'),
        (r"(Anagramme:\s*'?)([A-Za-zÉÈÊÀÂÎÔÛÙÇŒÆ]+)('?)", rf'\g<1>{new_letters}\g<3>'),
        (r"(Anagramme\s*:\s*)([A-ZÉÈÊÀÂÎÔÛÙÇŒÆ]+)", rf'\g<1>{new_letters}'),
    ]:
        new_prompt, n = re.subn(pat[0], pat[1], prompt)
        if n > 0:
            return new_prompt
    # If no pattern matched, append
    return prompt.rstrip('.') + f". Réorganisez: {new_letters}"

# === 1. The 3 manual fixes ===
MANUAL_FIXES = {
    'nature_mammiferes_f_34': {
        'prompt': "Le ___ est un mammifère marsupial qui se nourrit presque exclusivement de feuilles d'eucalyptus.",
        'answer': "Koala",
        'explanation': "Le koala se nourrit presque exclusivement de feuilles d'eucalyptus, qui sont pauvres en nutriments et légèrement toxiques — c'est pourquoi il dort jusqu'à 20 heures par jour.",
        'options': ["Hérisson", "Koala", "Paresseux", "Blaireau"],
    },
    'nature_insectes_f_43': {
        'prompt': "Indice: Insecte volant aux ailes colorées qui se nourrit de nectar des fleurs. (Réorganisez les lettres : LONPAPIL)",
        'answer': "PAPILLON",
        'explanation': "Le papillon se nourrit du nectar des fleurs grâce à sa trompe, et joue un rôle important de pollinisateur dans les jardins.",
    },
    'football_euro_f_15': {
        'prompt': "Quel joueur a remporté le Soulier d'Or de l'Euro 2020, départagé aux passes décisives après 5 buts ex aequo avec Patrik Schick ?",
        'answer': "Cristiano Ronaldo",
        'explanation': "Cristiano Ronaldo et Patrik Schick ont tous deux marqué 5 buts à l'Euro 2020. Ronaldo a remporté le Soulier d'Or grâce à 1 passe décisive contre 0 pour Schick.",
        'options': ["Cristiano Ronaldo", "Patrik Schick", "Kylian Mbappé", "Karim Benzema"],
    },
}

# === 2. Factual allowlist (manually verified) ===
FACTUAL_ALLOWLIST = {
    'football_euro_f_23': {  # Euro 2024 WAS in Germany — answer "Faux" is wrong
        'answer': "Vrai",
        'explanation': "L'Euro 2024 s'est déroulé en Allemagne du 14 juin au 14 juillet 2024.",
    },
    'litt_femmes_f_7': {  # Rougon-Macquart = Zola, not George Sand
        'answer': "Émile Zola",
        'explanation': "Émile Zola est l'auteur de la série des Rougon-Macquart (20 romans), qui explore la société française du XIXe siècle sous le Second Empire.",
    },
    'litt_femmes_f_11': {  # 1984 Goncourt = Marguerite Duras, not Marie NDiaye
        'answer': "Marguerite Duras",
        'explanation': "Marguerite Duras a remporté le prix Goncourt en 1984 pour « L'Amant ». Marie NDiaye l'a remporté en 2009 pour « Trois femmes puissantes ».",
        'options': ["Marguerite Duras", "Annie Ernaux", "Marie NDiaye", "Alice Ferney"],
    },
    'tech_inventions_f_40': {  # Apple II = 1977, not "années 1980"
        'answer': "Faux",
        'explanation': "Le premier ordinateur personnel largement commercialisé, l'Apple II, a été lancé en 1977, bien avant les années 1980.",
    },
    'arts_opera_f_11': {  # Palais Garnier inaugurated 1875 — answer "Faux" contradicts
        'answer': "Vrai",
        'explanation': "L'Opéra de Paris, connu sous le nom de Palais Garnier, a bien été inauguré en 1875. L'Opéra Bastille, autre salle de l'Opéra de Paris, a été inaugurée en 1989.",
    },
    'sciences_chimie_f_28': {  # spelling
        'answer': "HYDROGÈNE",
    },
    'hi_ma_f_15': {  # spelling
        'answer': "FÉODALITÉ",
    },
    'litt_prix_f_20': {  # Renaudot created 1926, not 1944
        'answer': "RENAUDOT",
        'explanation': "Le Prix Renaudot a été créé en 1926, décerné pour la première fois la même année que le Prix Goncourt.",
    },
    'hi_gd_f_12': {  # Pizarro conquered Inca 1532, not "1532-1572"
        'explanation': "Pizarro conquit l'Empire inca du Pérou en 1532 avec moins de 200 hommes. Il captura l'Inca Atahualpa et le fit exécuter après avoir reçu une rançon fabuleuse en or et argent.",
    },
    'litt_femmes_f_27': {  # Femme rompue = recueil de nouvelles
        'explanation': "Simone de Beauvoir est l'autrice de « La Femme rompue », un recueil de trois nouvelles publié en 1967.",
    },
    'litt_bd_f_29': {  # Schtroumpfette is not an extraterrestre
        'answer': "Faux",
        'explanation': "Schtroumpfette est un personnage de la bande dessinée « Les Schtroumpfs » créée par Peyo, mais elle n'est pas une extraterrestre — c'est une schtroumpf créée par Gargamel.",
    },
}

# === 3. Anagram repairs: fix letters in prompt to match original answer ===
# Find all anagram questions where letters don't form the answer
anagram_repairs = {}
for qid, q in qs.items():
    if q['type'] != 'anagram':
        continue
    if qid in MANUAL_FIXES or qid in FACTUAL_ALLOWLIST:
        continue
    letters = extract_letters(q['prompt'])
    if not letters:
        continue
    answer = q['answer']
    if normalize(letters) != normalize(answer):
        # The letters don't form the answer — repair by generating valid letters
        new_letters = make_anagram(answer, seed=abs(hash(qid)) % 100000)
        if normalize(new_letters) == normalize(answer):
            new_prompt = replace_letters_in_prompt(q['prompt'], new_letters)
            if new_letters in new_prompt:
                anagram_repairs[qid] = {'prompt': new_prompt}

print(f"Manual fixes: {len(MANUAL_FIXES)}")
print(f"Factual allowlist: {len(FACTUAL_ALLOWLIST)}")
print(f"Anagram repairs (letter-only): {len(anagram_repairs)}")

# Combine all corrections
all_fixes = {}
all_fixes.update(MANUAL_FIXES)
all_fixes.update(FACTUAL_ALLOWLIST)
all_fixes.update(anagram_repairs)

print(f"Total corrections to apply: {len(all_fixes)}")

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
                        if q['id'] in all_fixes:
                            for k, v in all_fixes[q['id']].items():
                                q[k] = v
                            applied += 1
            elif ch.get('questions'):
                for q in ch['questions']:
                    if q['id'] in all_fixes:
                        for k, v in all_fixes[q['id']].items():
                            q[k] = v
                        applied += 1
    with open(path, 'w') as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
        f.write('\n')
    print(f"\n{path}: applied {applied} corrections")

# Verify
with open('ios/Cortex/Resources/content.json') as f:
    data = json.load(f)
nulls = 0
total = 0
broken_anagrams = 0
for disc in data['disciplines']:
    for ch in disc['chapters']:
        qlist = []
        if ch.get('levels'):
            for lvl in ch['levels'].values():
                qlist += lvl.get('questions', [])
        elif ch.get('questions'):
            qlist += ch['questions']
        for q in qlist:
            total += 1
            if q.get('answer') is None or q.get('explanation') is None:
                nulls += 1
            if q['type'] == 'anagram':
                letters = extract_letters(q['prompt'])
                if letters and normalize(letters) != normalize(q['answer']):
                    broken_anagrams += 1
print(f"\nVerification: {total} questions, {nulls} nulls, {broken_anagrams} broken anagrams remaining")

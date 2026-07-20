#!/usr/bin/env python3
"""Fix factually wrong questions and add precision to vague ones.
Edits ios/Cortex/Resources/content.json and web/public/content.json identically."""
import json, sys, copy

PATHS = [
    'ios/Cortex/Resources/content.json',
    'web/public/content.json',
]

# Replacements keyed by question id. Only prompt/answer/explanation/options
# are touched — never id/type/familiarity, preserving the schema guarantees.
FIXES = {
    # Koala does NOT eat nectar — it eats eucalyptus leaves. Rewrite the
    # prompt so the answer is factually correct.
    'nature_mammiferes_f_34': {
        'prompt': "Le ___ est un mammifère marsupial qui se nourrit presque exclusivement de feuilles d'eucalyptus.",
        'answer': "Koala",
        'explanation': "Le koala se nourrit presque exclusivement de feuilles d'eucalyptus, qui sont pauvres en nutriments et légèrement toxiques — c'est pourquoi il dort jusqu'à 20 heures par jour.",
        'options': ["Hérisson", "Koala", "Paresseux", "Blaireau"],
    },
    # The anagram "LIAECM" does NOT form CIGALE (no G, extra M). Also,
    # cigales feed on plant sap, not nectar. Replace with a real nectar
    # insect (papillon) and a valid anagram.
    'nature_insectes_f_43': {
        'prompt': "Indice: Insecte volant aux ailes colorées qui se nourrit de nectar des fleurs. (Réorganisez les lettres : LONPAPIL)",
        'answer': "PAPILLON",
        'explanation': "Le papillon se nourrit du nectar des fleurs grâce à sa trompe, et joue un rôle important de pollinisateur dans les jardins.",
    },
    # Add precision to the Ronaldo Euro 2020 Golden Boot question: he tied
    # with Patrik Schick on 5 goals but won on assists (1 vs 0).
    'football_euro_f_15': {
        'prompt': "Quel joueur a remporté le Soulier d'Or de l'Euro 2020, départagé aux passes décisives après 5 buts ex aequo avec Patrik Schick ?",
        'answer': "Cristiano Ronaldo",
        'explanation': "Cristiano Ronaldo et Patrik Schick ont tous deux marqué 5 buts à l'Euro 2020. Ronaldo a remporté le Soulier d'Or grâce à 1 passe décisive contre 0 pour Schick.",
        'options': ["Cristiano Ronaldo", "Patrik Schick", "Kylian Mbappé", "Karim Benzema"],
    },
}

def patch(data):
    counts = {}
    for disc in data['disciplines']:
        for ch in disc['chapters']:
            # flat questions
            if ch.get('questions'):
                for q in ch['questions']:
                    if q['id'] in FIXES:
                        fix = FIXES[q['id']]
                        for k, v in fix.items():
                            q[k] = v
                        counts[q['id']] = counts.get(q['id'], 0) + 1
            # multi-level
            if ch.get('levels'):
                for level in ch['levels'].values():
                    for q in level.get('questions', []):
                        if q['id'] in FIXES:
                            fix = FIXES[q['id']]
                            for k, v in fix.items():
                                q[k] = v
                            counts[q['id']] = counts.get(q['id'], 0) + 1
    return counts

for p in PATHS:
    with open(p) as f:
        data = json.load(f)
    counts = patch(data)
    with open(p, 'w') as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
        f.write('\n')
    print(f"{p}: patched {len(counts)} questions: {sorted(counts.keys())}")

print("Done.")

"""Remove every quiz item about the theory of evolution of species."""
import json
import re
import sys

REMOVED_CHAPTERS = {"sciences_evolution"}
REMOVED_QUESTIONS = {"sc_ge_3", "nature_oiseaux_f_31", "na_di_f_9", "na_di_f_19", "nature_dinosaures_f_23"}
EXPLANATION_FIXES = {
    "na_di_f_3": "Les dinosaures avaient disparu depuis très longtemps quand les premiers humains sont arrivés sur Terre : ils n'ont jamais vécu à la même époque.",
}
OPTION_FIXES = {
    "sc_ge_2": ("Charles Darwin et Gregor Mendel", "Isaac Newton et Gregor Mendel"),
    "sciences_genetique_f_42": ("Évolution", "Photosynthèse"),
}
# Safety net for wording that may exist only in a given copy of the content.
FORBIDDEN = re.compile(
    r"darwin|s[ée]lection naturelle|origine des esp[eè]ces|[ée]volution des esp[eè]ces|th[ée]orie de l.[ée]volution|"
    r"ancêtres? commun|parent[ée] [ée]volutive|hominid|hominin|n[ée]andert|australopith|cha[iî]non manquant|maillon manquant|"
    r"fossile de transition|lamarck|sp[ée]ciation|ancêtres? des oiseaux|ancêtres? de l.homme|descend(ent)? (du|des) (singe|chimpanz)",
    re.IGNORECASE,
)


def blob(q):
    return " | ".join([q.get("prompt", ""), q.get("answer", ""), q.get("explanation", "")] + list(q.get("options") or []))


def clean(content):
    removed = []
    for discipline in content["disciplines"]:
        kept_chapters = []
        for chapter in discipline["chapters"]:
            if chapter["id"] in REMOVED_CHAPTERS:
                removed.append(f"chapter:{chapter['id']}")
                continue
            for block in chapter.get("levels", {}).values():
                kept = []
                for q in block.get("questions", []):
                    if q["id"] in EXPLANATION_FIXES:
                        q["explanation"] = EXPLANATION_FIXES[q["id"]]
                    if q["id"] in OPTION_FIXES:
                        old, new = OPTION_FIXES[q["id"]]
                        q["options"] = [new if o == old else o for o in q.get("options") or []]
                    if q["id"] in REMOVED_QUESTIONS or FORBIDDEN.search(blob(q)):
                        removed.append(q["id"])
                        continue
                    kept.append(q)
                block["questions"] = kept
            kept_chapters.append(chapter)
        discipline["chapters"] = kept_chapters
    return removed


def main(paths):
    for path in paths:
        raw = open(path).read()
        content = json.loads(raw)
        pretty = raw.startswith("{\n")
        removed = clean(content)
        with open(path, "w") as f:
            if pretty:
                json.dump(content, f, ensure_ascii=False, indent=2)
            else:
                json.dump(content, f, ensure_ascii=False, separators=(",", ":"))
        print(path, len(removed), removed)


if __name__ == "__main__":
    main(sys.argv[1:])

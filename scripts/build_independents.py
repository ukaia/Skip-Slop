#!/usr/bin/env python3
"""Builds Skip Slop/Data/IndependentGrades.json from docs/data/independent_evidence.json.

Independent restaurants are never guessed. Each entry here was added by hand
with citations (the restaurant's own menu or site, or press) and a location;
the app matches a map place to an entry by name and distance (250 m).
Grades use the same signals and formula as chains (scripts/build_chains.py),
except that a restaurant's own published claims can support an A or A+.

Usage:  python3 scripts/build_independents.py
Needs:  Python 3.9+. No network.
"""

import json
from collections import OrderedDict
from pathlib import Path

from build_chains import GRADE_RAW, grade_chain

ROOT = Path(__file__).resolve().parent.parent
EVIDENCE = ROOT / "docs" / "data" / "independent_evidence.json"
OUTPUT = ROOT / "Skip Slop" / "Data" / "IndependentGrades.json"


def main():
    entries = json.loads(EVIDENCE.read_text())
    out = []
    ids = set()
    for e in entries:
        assert e["id"] not in ids, f"duplicate id {e['id']}"
        ids.add(e["id"])
        assert -90 <= e["latitude"] <= 90 and -180 <= e["longitude"] <= 180, e["id"]
        e.setdefault("slug", e["id"])
        result = grade_chain(e, require_independent=False)
        assert result, f"{e['id']}: independents need an entree signal with a source"
        letter, confidence, _ = result
        out.append(OrderedDict([
            ("id", e["id"]), ("name", e["name"]), ("aliases", e.get("aliases", [])), ("city", e.get("city")),
            ("latitude", e["latitude"]), ("longitude", e["longitude"]),
            ("grade", GRADE_RAW[letter]), ("confidence", confidence), ("basis", e["basis"]),
            ("sources", [OrderedDict([("title", s["title"]), ("url", s["url"]), ("tier", s["tier"])]) for s in e["sources"]]),
        ]))
        print(f"{letter:2} {confidence:6} {e['name']}")
    OUTPUT.write_text("[\n" + ",\n".join("  " + json.dumps(o, ensure_ascii=False) for o in out) + "\n]\n")
    print(f"{len(out)} independents -> {OUTPUT}")


if __name__ == "__main__":
    main()

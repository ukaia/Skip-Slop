#!/usr/bin/env python3
"""Scores PlaceVerificationTests output against docs/verification/ground_truth.csv.

Usage: python3 scripts/verify_stats.py <verify-dir>
Reads   <dir>/places-before-*.csv  (old fetch + old matcher)
        <dir>/rescore-after.csv    (same places, new matcher)
        <dir>/places-after-*.csv   (new fetch + new matcher)
Writes  docs/verification/accuracy.md (copy the CSVs to docs/verification/raw/)
"""
import csv
import glob
import json
import sys
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "scripts"))
from build_chains import normalize  # noqa: E402

FOOD = {"Restaurant", "Cafe", "Bakery", "Brewery", "Winery", ""}


def load(pattern):
    rows = []
    for f in sorted(glob.glob(pattern)):
        rows += list(csv.DictReader(open(f, encoding="utf-8")))
    return rows


def main():
    vdir = Path(sys.argv[1])
    out_dir = ROOT / "docs" / "verification"
    chains = json.loads((ROOT / "Skip Slop" / "Data" / "SeedChains.json").read_text())
    curated = {c["slug"] for c in chains if c["provenance"] == "curated"}
    by_name = {}
    for c in chains:
        for n in [c["name"]] + c.get("aliases", []):
            by_name.setdefault(normalize(n), c["slug"])
    truth_brand = {r["name"]: r["brand"] for r in csv.DictReader(open(out_dir / "ground_truth.csv", encoding="utf-8"))}

    def truth(name):
        brand = truth_brand.get(name)
        if brand is None:
            return ("independent", None)
        slug = by_name.get(normalize(brand))
        return ("chain", slug) if slug else ("unlisted", brand)

    before = [r for r in load(str(vdir / "places-before-*.csv")) if r["category"] in FOOD or "app" in r["sources"].split()]
    after_same = list(csv.DictReader(open(vdir / "rescore-after.csv", encoding="utf-8")))
    after_same = [r for r in after_same if r["category"] in FOOD or "app" in r["sources"].split()]
    after_fetch = load(str(vdir / "places-after-*.csv"))

    def score(rows):
        c = Counter()
        fp, miss = [], []
        for r in rows:
            kind, slug = truth(r["name"])
            pred = r["chain_slug"] or None
            if kind == "chain":
                if pred == slug:
                    c["tp"] += 1
                elif pred:
                    c["fp_wrong_chain"] += 1
                    fp.append((r["name"], pred, slug))
                else:
                    c["miss_curated" if slug in curated else "miss_new_data"] += 1
                    miss.append((r["name"], slug))
            elif kind == "unlisted":
                if pred:
                    c["fp_wrong_chain"] += 1
                    fp.append((r["name"], pred, "unlisted: " + slug))
                else:
                    c["miss_not_in_sources"] += 1
                    miss.append((r["name"], "not in sources"))
            else:
                if pred:
                    c["fp_independent"] += 1
                    fp.append((r["name"], pred, "independent"))
                else:
                    c["tn"] += 1
        return c, fp, miss

    b, b_fp, b_miss = score(before)
    a, a_fp, a_miss = score(after_same)

    def pct(n, d):
        return f"{100 * n / d:.0f}%" if d else "–"

    def summary(c):
        chains_total = c["tp"] + c["fp_wrong_chain"] + c["miss_curated"] + c["miss_new_data"] + c["miss_not_in_sources"]
        fp = c["fp_wrong_chain"] + c["fp_independent"]
        predicted = c["tp"] + fp
        return chains_total, fp, predicted

    bt, bfp, bpred = summary(b)
    at, afp, apred = summary(a)

    # Grades given to independents (new code, same places).
    indep = [r for r in after_same if truth(r["name"])[0] == "independent"]
    indep_before = [r for r in before if truth(r["name"])[0] == "independent"]
    grade_mix = Counter(r["grade"] for r in indep)
    conf_mix = Counter(r["confidence"] for r in indep)
    est_after = sum(r["estimated"] == "yes" for r in indep)
    est_before = sum(r["estimated"] == "yes" for r in indep_before)

    # App fetch coverage.
    app_before = [r for r in load(str(vdir / "places-before-*.csv")) if "app" in r["sources"].split()]
    app_after = [r for r in after_fetch if "app" in r["sources"].split()]
    cities = sorted({r["city"] for r in app_before})

    def app_stats(rows, city):
        rs = [r for r in rows if r["city"] == city]
        ind = sum(1 for r in rs if not r["chain_slug"])
        return len(rs), ind

    lines = [
        "# Place accuracy: before vs after",
        "",
        "Live MapKit data from `PlaceVerificationTests` (5 cities, 3 km regions), scored against the hand labels in",
        "`ground_truth.csv` (every distinct food-place name was reviewed; names not listed are independents).",
        "\"Before\" is the original matcher and 186-chain list; \"after\" is the new matcher and 977-chain list,",
        "run on **the same places**.",
        "",
        f"Places scored: **{len(before)}** (restaurants, cafes, bakeries, breweries, wineries, and anything the app fetch returned).",
        "",
        "## Chain matching",
        "",
        "| | Before | After |",
        "|---|---|---|",
        f"| Chain places (truth) | {bt} | {at} |",
        f"| True positives | {b['tp']} | {a['tp']} |",
        f"| False positives: independent matched to a chain | {b['fp_independent']} | {a['fp_independent']} |",
        f"| False positives: wrong chain | {b['fp_wrong_chain']} | {a['fp_wrong_chain']} |",
        f"| Misses: chain in curated list | {b['miss_curated']} | {a['miss_curated']} |",
        f"| Misses: chain added from NSI/Wikipedia | {b['miss_new_data']} | {a['miss_new_data']} |",
        f"| Misses: chain in no source | {b['miss_not_in_sources']} | {a['miss_not_in_sources']} |",
        f"| Precision | {pct(b['tp'], bpred)} | {pct(a['tp'], apred)} |",
        f"| Recall (all chains) | {pct(b['tp'], bt)} | {pct(a['tp'], at)} |",
        "",
        "Before, \"misses: chain added from NSI/Wikipedia\" were chains the old list didn't have at all.",
        "",
        "### False positives",
        "",
        "| Place | Before matched | After matched | Truth |",
        "|---|---|---|---|",
    ]
    fps = {}
    for name, pred, t in b_fp:
        fps.setdefault(name, ["", "", t])[0] = pred
    for name, pred, t in a_fp:
        fps.setdefault(name, ["", "", t])[1] = pred
    for name, (bp, ap, t) in sorted(fps.items()):
        lines.append(f"| {name} | {bp or '–'} | {ap or '–'} | {t} |")
    lines += ["", "### Remaining misses (after)", "", "| Place | Truth |", "|---|---|"]
    for name, t in sorted(set(a_miss)):
        lines.append(f"| {name} | {t} |")

    lines += [
        "",
        "## Independents",
        "",
        f"{len(indep)} independent places. Before, {est_before} of {len(indep_before)} were labeled estimated "
        f"(\"Likely\" coffee/fast-food guesses were shown as certain). After, {est_after} of {len(indep)} are.",
        "",
        "| Grade | Places |", "|---|---|",
    ] + [f"| {g} | {n} |" for g, n in sorted(grade_mix.items())] + [
        "", "| Confidence | Places |", "|---|---|",
    ] + [f"| {k} | {n} |" for k, n in sorted(conf_mix.items())] + [
        "",
        "## What the app loads",
        "",
        "Places returned by `MapSearchService.searchNearby` for a 3 km region (before: one \"restaurant\" query;",
        "after: points-of-interest requests for food categories plus \"restaurant\", \"cafe\", \"food\" queries, merged).",
        "",
        "| City | Before: places | Before: not chains | After: places | After: not chains |",
        "|---|---|---|---|---|",
    ]
    for city in cities:
        bp, bi = app_stats(app_before, city)
        ap, ai = app_stats(app_after, city)
        lines.append(f"| {city} | {bp} | {bi} | {ap} | {ai} |")

    # Spot-check sample: every 25th scored place, deterministic.
    lines += ["", "## Spot-check sample", "",
              "Every 25th scored place, checked by hand against the chain list.", "",
              "| City | Place | Category | Before | After | Grade (after) | Estimated | Truth | After correct? |",
              "|---|---|---|---|---|---|---|---|---|"]
    after_by_key = {(r["city"], r["name"], r["lat"], r["lon"]): r for r in after_same}
    for r in before[::25]:
        ar = after_by_key.get((r["city"], r["name"], r["lat"], r["lon"]), {})
        kind, slug = truth(r["name"])
        t = slug if kind == "chain" else ("unlisted: " + slug if kind == "unlisted" else "independent")
        ok = (ar.get("chain_slug") or None) == (slug if kind == "chain" else None)
        lines.append(f"| {r['city']} | {r['name']} | {r['category']} | {r['chain_slug'] or '–'} | "
                     f"{ar.get('chain_slug') or '–'} | {ar.get('grade', '')} | {ar.get('estimated', '')} | {t} | "
                     f"{'yes' if ok else 'no'} |")

    (out_dir / "accuracy.md").write_text("\n".join(lines) + "\n")
    print("\n".join(lines[:30]))


if __name__ == "__main__":
    main()

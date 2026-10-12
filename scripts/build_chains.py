#!/usr/bin/env python3
"""Builds Skip Slop/Data/SeedChains.json: chain names and aliases plus
evidence-backed grades.

Inputs:
  1. docs/data/chain_evidence.json - researched prep evidence with citations.
     The ONLY source of grades. A chain without evidence is "Not graded yet".
  2. scripts/data/curated_chains.json - the original hand-picked list. Used for
     names, aliases and parent companies. Its old grades are only read to log
     how the evidence changed them (docs/data/curated_grade_changes.md).
  3. OpenStreetMap name-suggestion-index (NSI), US food brands - names,
     aliases and Wikidata IDs.
  4. Wikipedia, "List of restaurant chains in the United States" - chains NSI
     lacks.
  5. docs/data/top_chains.json - the ~150 largest US chains, to report
     research coverage.

The grading formula is documented in docs/data/RATING_METHOD.md and
implemented in `grade_chain` below.

Usage:  python3 scripts/build_chains.py [--nsi-ref SHA] [--wiki-oldid REVID]
Writes: Skip Slop/Data/SeedChains.json, docs/data/chains_build_report.md,
        docs/data/curated_grade_changes.md
Needs:  Python 3.9+, network access (NSI and Wikipedia). No third-party packages.
"""

import argparse
import json
import re
import sys
import time
import unicodedata
import urllib.parse
import urllib.request
from collections import Counter, OrderedDict
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CURATED = ROOT / "scripts" / "data" / "curated_chains.json"
EVIDENCE = ROOT / "docs" / "data" / "chain_evidence.json"
TOP_CHAINS = ROOT / "docs" / "data" / "top_chains.json"
OUTPUT = ROOT / "Skip Slop" / "Data" / "SeedChains.json"
REPORT = ROOT / "docs" / "data" / "chains_build_report.md"
CHANGES = ROOT / "docs" / "data" / "curated_grade_changes.md"

NSI_REF = "721a3b9b4d375e637a0b50d7ee9eab800078dcd9"  # name-suggestion-index main, 2026-10-11
WIKI_PAGE = "List of restaurant chains in the United States"
WIKI_OLDID = 1374357555  # revision of 2026-09-11

NSI_FILES = [
    "amenity/fast_food",
    "amenity/restaurant",
    "amenity/cafe",
    "amenity/ice_cream",
    "amenity/bar",
    "amenity/pub",
    "shop/bakery",
    "shop/pastry",
    "shop/coffee",
    "shop/deli",
]

# locationSet codes that cover the US: the country, its states, Northern
# America, the Americas, and the whole world.
US_CODES = {"us", "001", "019", "021", "conus", "us50"}

# Names too generic to identify a chain on their own. NSI excludes most of
# these already; this is a backstop so "Pizza" can never become a chain.
GENERIC_NAMES = {
    "bakery", "bar", "bar and grill", "bbq", "bagels", "bistro", "breakfast",
    "buffet", "burger", "burgers", "cafe", "cafeteria", "cantina", "chicken",
    "chinese", "coffee", "coffee shop", "deli", "diner", "donuts", "doughnuts",
    "express", "fast food", "fried chicken", "grill", "hot dogs", "ice cream",
    "juice", "kitchen", "noodles", "pho", "pizza", "pizzeria", "pub",
    "ramen", "restaurant", "salad", "sandwiches", "seafood", "smoothies",
    "snack bar", "steakhouse", "subs", "sushi", "taco", "tacos", "taqueria",
    "tea", "the kitchen", "wings",
}

# Wikipedia sections above "Casual dining" are quick-service formats.
WIKI_QUICK_SERVICE = {
    "Baked goods": "bakery",
    "Beverages": "coffee",
    "Frozen desserts": "dessert",
}
WIKI_SIT_DOWN = {"Casual dining", "Arcade and game centers"}
WIKI_SKIP = {"Defunct", "Notes", "See also", "References", "External links"}

USER_AGENT = "SkipSlop-chain-builder/2.0 (https://github.com/ukaia/Skip-Slop)"


# MARK: - Grading (documented in docs/data/RATING_METHOD.md)

# Signal values -> score out of 100.
ENTREE = {
    "scratch": 100,                     # raw/fresh ingredients cooked on site
    "fresh_cooked_premade_parts": 75,   # cooked on site, key parts arrive made
    "assembled": 50,                    # mix of on-site cooking and pre-made parts
    "reheated": 15,                     # mostly pre-cooked/frozen, reheated or fried
    "broadline_meals": 0,               # complete meals from a broadline distributor
}
SIDES = {"scratch": 100, "mixed": 55, "premade": 15}
PRODUCE = {"fresh_onsite": 100, "mixed": 55, "precut": 15}
SOURCING = {"local", "direct", "mixed", "broadline"}
WEIGHTS = {"entree": 0.7, "sides": 0.2, "produce": 0.1}

# SlopRating raw values in the app.
GRADE_RAW = {"A+": "green_plus", "A": "green", "B": "yellow", "C": "orange", "F": "red", "F-": "red_minus"}


def prep_score(signals):
    """Weighted mean of the known prep signals (entree, sides, produce)."""
    parts = [(WEIGHTS["entree"], ENTREE[signals["entree"]])]
    if signals.get("sides") in SIDES:
        parts.append((WEIGHTS["sides"], SIDES[signals["sides"]]))
    if signals.get("produce") in PRODUCE:
        parts.append((WEIGHTS["produce"], PRODUCE[signals["produce"]]))
    return sum(w * v for w, v in parts) / sum(w for w, _ in parts)


def sources_for(entry, signal):
    return [s for s in entry["sources"] if signal in s.get("supports", [])]


def confidence_for(entry):
    """high / medium / low from the sources behind the entree signal."""
    srcs = sources_for(entry, "entree")
    tiers = [s["tier"] for s in srcs]
    independent = [t for t in tiers if t in (2, 3)]
    strong = [t for t in tiers if t in (1, 2)]
    if len(srcs) >= 2 and strong and independent:
        return "high"
    if len(srcs) >= 2 or strong:
        return "medium"
    return "low"


def company_only(entry):
    """True when every source for the entree signal is the company itself."""
    return all(s["tier"] == 1 for s in sources_for(entry, "entree"))


def grade_chain(entry):
    """Returns (letter, confidence, score) or None when there is no evidence.

    - F-: entrées arrive as complete meals from a broadline distributor.
    - A+: scratch entrées and sides (or none), score >= 85, and local sourcing
          backed by an independent source.
    - A:  scratch entrées and sides (or none), score >= 80.
    - B:  score >= 60.   C: score >= 38.   F: below 38.
    A and A+ need at least one independent source; company claims alone cap a
    chain at B and at medium confidence.
    """
    signals = entry.get("signals") or {}
    if signals.get("entree") not in ENTREE:
        return None
    for key, table in (("sides", SIDES), ("produce", PRODUCE)):
        value = signals.get(key)
        assert value is None or value in table or (key == "sides" and value == "na"), f"{entry['slug']}: bad {key} {value}"
    assert signals.get("sourcing") in (None, *SOURCING), f"{entry['slug']}: bad sourcing"
    if not sources_for(entry, "entree"):
        raise ValueError(f"{entry['slug']}: entree signal has no source")

    score = prep_score(signals)
    confidence = confidence_for(entry)
    scratch_core = signals["entree"] == "scratch" and signals.get("sides") in ("scratch", "na")
    independent = not company_only(entry)
    local = signals.get("sourcing") == "local" and any(s["tier"] in (2, 3) for s in sources_for(entry, "sourcing"))

    if signals["entree"] == "broadline_meals":
        letter = "F-"
    elif scratch_core and independent and score >= 85 and local:
        letter = "A+"
    elif scratch_core and independent and score >= 80:
        letter = "A"
    elif score >= 60:
        letter = "B"
    elif score >= 38:
        letter = "C"
    else:
        letter = "F"
    if not independent and confidence == "high":
        confidence = "medium"
    return letter, confidence, round(score, 1)


def nsi_category(tags):
    amenity = tags.get("amenity")
    shop = tags.get("shop")
    if amenity == "fast_food" or shop == "deli":
        return "fast_food"
    if amenity == "cafe" or shop == "coffee":
        return "coffee"
    if amenity == "ice_cream":
        return "dessert"
    if shop in ("bakery", "pastry"):
        return "bakery"
    if amenity == "restaurant":
        return "casual_dining"
    if amenity in ("bar", "pub"):
        return "bar"
    return None


# MARK: - Normalization (mirrors ChainDatabase.normalize in Swift)

def normalize(name):
    s = unicodedata.normalize("NFKD", name)
    s = "".join(c for c in s if not unicodedata.combining(c)).lower()
    s = s.replace("’", "'").replace("`", "'")
    s = s.replace("&", " and ").replace("+", " and ")
    s = re.sub(r"'s\b", "s", s)
    s = s.replace("'", "")
    s = re.sub(r"[^a-z0-9]+", " ", s).strip()
    s = re.sub(r"^the ", "", s)
    return re.sub(r"\s+", " ", s)


def compact(name):
    return normalize(name).replace(" ", "")


def slugify(name):
    return normalize(name).replace(" ", "-") or "chain"


# MARK: - Fetching

def fetch(url, retries=3):
    for attempt in range(retries):
        try:
            req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
            with urllib.request.urlopen(req, timeout=60) as resp:
                return resp.read()
        except Exception as error:  # noqa: BLE001 - retry any network error
            if attempt == retries - 1:
                raise
            print(f"retrying {url}: {error}", file=sys.stderr)
            time.sleep(2 * (attempt + 1))


def covers_us(location_set):
    include = location_set.get("include", [])
    exclude = location_set.get("exclude", [])

    def is_us(code):
        if not isinstance(code, str):
            return False
        code = code.lower()
        return code in US_CODES or code.startswith("us-")

    if any(isinstance(c, str) and c.lower() == "us" for c in exclude):
        return False
    return any(is_us(c) for c in include)


def load_nsi(ref):
    brands = []
    for path in NSI_FILES:
        url = f"https://raw.githubusercontent.com/osmlab/name-suggestion-index/{ref}/data/brands/{path}.json"
        data = json.loads(fetch(url))
        for item in data.get("items", []):
            if not covers_us(item.get("locationSet", {})):
                continue
            tags = item.get("tags", {})
            category = nsi_category(tags)
            if category is None:
                continue
            name = tags.get("name:en") or tags.get("brand:en") or tags.get("name") or tags.get("brand") or item.get("displayName")
            if not name or not re.search(r"[A-Za-z]", name):
                continue  # non-Latin names never come back from US MapKit results
            aliases = set(item.get("matchNames", []))
            for key in ("name", "brand", "brand:en", "name:en", "official_name", "short_name", "alt_name"):
                if tags.get(key):
                    aliases.update(v.strip() for v in tags[key].split(";"))
            if item.get("displayName"):
                aliases.add(re.sub(r"\s*\(.*\)$", "", item["displayName"]))
            brands.append({
                "nsiId": item.get("id"),
                "name": name,
                "wikidata": tags.get("brand:wikidata"),
                "category": category,
                "cuisine": tags.get("cuisine"),
                "aliases": aliases,
                "file": path,
            })
    return brands


def load_wikipedia(oldid):
    url = ("https://en.wikipedia.org/w/api.php?action=parse&format=json&formatversion=2&prop=wikitext&oldid="
           + str(oldid))
    text = json.loads(fetch(url))["parse"]["wikitext"]
    entries = []
    section = None
    for block in re.split(r"^(==+[^=\n]+==+)\s*$", text, flags=re.M):
        heading = re.match(r"^(==+)\s*(.*?)\s*==+$", block)
        if heading:
            if len(heading.group(1)) == 2:
                section = heading.group(2)
            continue
        if section is None or section in WIKI_SKIP:
            continue
        if section in WIKI_SIT_DOWN:
            category = "casual_dining"
        else:
            category = WIKI_QUICK_SERVICE.get(section, "fast_food")
        for row in re.split(r"^\|-.*$", block, flags=re.M)[1:]:
            lines = [l for l in row.strip().splitlines() if l.startswith("|") and not l.startswith("|}")]
            if not lines:
                continue
            cell = lines[0][1:].split("||")[0].strip()
            link = re.search(r"\[\[([^\]|#]+)(?:#[^\]|]*)?(?:\|([^\]]+))?\]\]", cell)
            if link:
                title, label = link.group(1).strip(), (link.group(2) or link.group(1)).strip()
            else:
                title, label = None, cell
            label = re.sub(r"<ref.*?(</ref>|/>)|<ref.*$|\{\{.*?\}\}|'''?", "", label).strip()
            label = re.sub(r"\s*\(.*?\)$", "", label).strip()
            if label and re.search(r"[A-Za-z]", label):
                entries.append({"name": label, "title": title, "category": category, "section": section})
    titles = sorted({e["title"] for e in entries if e["title"]})
    qids = {}
    for i in range(0, len(titles), 50):
        batch = titles[i:i + 50]
        url = ("https://en.wikipedia.org/w/api.php?action=query&format=json&formatversion=2&prop=pageprops"
               "&ppprop=wikibase_item&redirects=1&titles=" + urllib.parse.quote("|".join(batch)))
        data = json.loads(fetch(url))["query"]
        forward = {}
        for n in data.get("normalized", []):
            forward[n["from"]] = n["to"]
        for r in data.get("redirects", []):
            forward[r["from"]] = r["to"]
        by_title = {p["title"]: p.get("pageprops", {}).get("wikibase_item") for p in data.get("pages", [])}
        for t in batch:
            resolved = t
            for _ in range(3):
                resolved = forward.get(resolved, resolved)
            qids[t] = by_title.get(resolved)
    for e in entries:
        e["wikidata"] = qids.get(e["title"]) if e["title"] else None
    return entries


# MARK: - Merge

def build(nsi_ref, wiki_oldid):
    curated = json.loads(CURATED.read_text())
    nsi = load_nsi(nsi_ref)
    wiki = load_wikipedia(wiki_oldid)

    chains = OrderedDict()   # slug -> entry
    by_qid = {}              # wikidata -> slug
    by_name = {}             # compact name/alias -> slug
    stats = Counter()

    def index(slug, names, qid):
        if qid and qid not in by_qid:
            by_qid[qid] = slug
        for n in names:
            key = compact(n)
            if key and key not in by_name:
                by_name[key] = slug

    def find(names, qid):
        if qid and qid in by_qid:
            return by_qid[qid]
        for n in names:
            slug = by_name.get(compact(n))
            if slug:
                return slug
        return None

    def unique_slug(name, qid):
        slug = slugify(name)
        if slug in chains:
            slug = f"{slug}-{(qid or str(len(chains))).lower()}"
        return slug

    def new_entry(slug, name, category, provenance, aliases, qid, parent=None):
        return OrderedDict([
            ("slug", slug), ("name", name), ("category", category), ("parentCompany", parent),
            ("aliases", aliases), ("provenance", provenance), ("wikidata", qid),
        ])

    for c in curated:
        chains[c["slug"]] = new_entry(c["slug"], c["name"], c["category"], "curated",
                                      list(c.get("aliases", [])), None, c.get("parentCompany"))
        index(c["slug"], [c["name"]] + list(c.get("aliases", [])), None)
    curated_names = dict(by_name)

    # NSI: attach Wikidata/aliases to curated chains, add the rest.
    for brand in sorted(nsi, key=lambda b: (b["name"].lower(), b["nsiId"] or "")):
        names = [brand["name"]] + sorted(brand["aliases"])
        slug = find([brand["name"]], brand["wikidata"])
        if slug is None:
            # Any NSI name or alias that equals a curated name/alias is that chain.
            slug = next((curated_names[compact(n)] for n in names if compact(n) in curated_names), None)
        if slug is None and brand["wikidata"] is None:
            slug = find(names, None)
        if slug:
            entry = chains[slug]
            if entry["wikidata"] is None and brand["wikidata"] and brand["wikidata"] not in by_qid:
                entry["wikidata"] = brand["wikidata"]
            for a in names:
                if compact(a) != compact(entry["name"]) and a not in entry["aliases"]:
                    entry["aliases"].append(a)
            index(slug, names, brand["wikidata"])
            stats["nsi_merged"] += 1
            continue
        if normalize(brand["name"]) in GENERIC_NAMES:
            stats["nsi_generic_skipped"] += 1
            continue
        slug = unique_slug(brand["name"], brand["wikidata"])
        chains[slug] = new_entry(slug, brand["name"], brand["category"], "nsi",
                                 [a for a in names if compact(a) != compact(brand["name"])], brand["wikidata"])
        index(slug, names, brand["wikidata"])
        stats["nsi_added"] += 1

    # Wikipedia: cross-check and fill gaps.
    for w in wiki:
        slug = find([w["name"]] + ([w["title"]] if w["title"] else []), w["wikidata"])
        if slug:
            entry = chains[slug]
            if entry["wikidata"] is None and w["wikidata"] and w["wikidata"] not in by_qid:
                entry["wikidata"] = w["wikidata"]
                by_qid[w["wikidata"]] = slug
            stats["wiki_already_present"] += 1
            continue
        if normalize(w["name"]) in GENERIC_NAMES:
            stats["wiki_generic_skipped"] += 1
            continue
        slug = unique_slug(w["name"], w["wikidata"])
        chains[slug] = new_entry(slug, w["name"], w["category"], "wikipedia", [], w["wikidata"])
        index(slug, [w["name"]], w["wikidata"])
        stats["wiki_added"] += 1

    # Aliases: drop generic and duplicate ones; an alias shared by two chains
    # identifies neither, so it is removed from both.
    owners = Counter()
    for entry in chains.values():
        for a in {compact(x) for x in entry["aliases"]}:
            owners[a] += 1
    names = {compact(e["name"]) for e in chains.values()}
    for entry in chains.values():
        kept, seen = [], {compact(entry["name"])}
        for a in entry["aliases"]:
            key = compact(a)
            if not key or key in seen or normalize(a) in GENERIC_NAMES:
                continue
            if owners[key] > 1 or (key in names and key != compact(entry["name"])):
                stats["ambiguous_alias_dropped"] += 1
                continue
            seen.add(key)
            kept.append(a)
        entry["aliases"] = kept

    # Evidence: the only source of grades.
    evidence = json.loads(EVIDENCE.read_text())
    researched = set()
    for ev in evidence:
        slug = ev["slug"] if ev["slug"] in chains else find([ev["name"]], None)
        if slug is None:
            slug = unique_slug(ev["name"], None)
            chains[slug] = new_entry(slug, ev["name"], "casual_dining", "evidence", [], None)
            index(slug, [ev["name"]], None)
            stats["evidence_added_chain"] += 1
        if slug in researched:
            raise ValueError(f"two evidence entries for {slug}")
        researched.add(slug)
        entry = chains[slug]
        entry["researched"] = True
        result = grade_chain(ev)
        if result is None:
            stats["evidence_insufficient"] += 1
            continue
        letter, confidence, score = result
        entry["grade"] = GRADE_RAW[letter]
        entry["confidence"] = confidence
        entry["basis"] = ev["basis"]
        entry["score"] = score
        entry["sources"] = [OrderedDict([("title", s["title"]), ("url", s["url"]), ("tier", s["tier"])])
                            for s in ev["sources"]]
        stats["evidence_graded"] += 1

    return list(chains.values()), stats, len(nsi), len(wiki), curated


APP_KEYS = ("slug", "name", "category", "parentCompany", "aliases", "provenance", "wikidata",
            "grade", "confidence", "basis", "sources")


def write(chains, stats, nsi_count, wiki_count, nsi_ref, wiki_oldid, output, curated):
    def clean(entry):
        return OrderedDict((k, entry[k]) for k in APP_KEYS if entry.get(k) not in (None, []))

    # Graded chains first, so they win any name collision in the app.
    ordered = sorted(chains, key=lambda e: 0 if e.get("grade") else 1)
    output.write_text("[\n" + ",\n".join("  " + json.dumps(clean(e), ensure_ascii=False) for e in ordered) + "\n]\n")

    letters = {v: k for k, v in GRADE_RAW.items()}
    graded = [e for e in chains if e.get("grade")]
    by_conf = Counter(e["confidence"] for e in graded)
    by_grade = Counter(letters[e["grade"]] for e in graded)
    by_slug = {e["slug"]: e for e in chains}

    # Top chains coverage.
    top = json.loads(TOP_CHAINS.read_text())["chains"]
    name_index = {}
    for e in chains:
        for n in [e["name"]] + e["aliases"]:
            name_index.setdefault(compact(n), e)
    top_rows, top_graded, top_researched, top_missing = [], 0, 0, []
    for rank, name in enumerate(top, 1):
        e = name_index.get(compact(name))
        if e is None:
            top_missing.append(name)
            top_rows.append(f"| {rank} | {name} | – | not in database |")
            continue
        if e.get("grade"):
            top_graded += 1
            status = f"**{letters[e['grade']]}** ({e['confidence']})"
        elif e.get("researched"):
            status = "researched, not enough evidence"
        else:
            status = "not researched"
        if e.get("researched"):
            top_researched += 1
        top_rows.append(f"| {rank} | {name} | `{e['slug']}` | {status} |")

    lines = [
        "# Chain database build report", "",
        "Generated by `scripts/build_chains.py`. Do not edit by hand.", "",
        f"- NSI ref: `{nsi_ref}` ({nsi_count} US food brands read)",
        f"- Wikipedia: [{WIKI_PAGE}](https://en.wikipedia.org/w/index.php?oldid={wiki_oldid}) oldid {wiki_oldid} ({wiki_count} rows read)",
        f"- Total chains: **{len(chains)}**",
        f"- Researched: **{sum(1 for e in chains if e.get('researched'))}**; graded from evidence: **{len(graded)}**; everything else shows \"Not graded yet\"",
        f"- Largest ~150 chains (`docs/data/top_chains.json`): {top_researched} of {len(top)} researched, {top_graded} graded",
        "",
        "| Confidence | Chains |", "|---|---|",
    ] + [f"| {k} | {by_conf.get(k, 0)} |" for k in ("high", "medium", "low")] + [
        "", "| Grade | Chains |", "|---|---|",
    ] + [f"| {k} | {by_grade.get(k, 0)} |" for k in GRADE_RAW] + [
        "", "| Provenance | Chains |", "|---|---|",
    ] + [f"| {k} | {v} |" for k, v in sorted(Counter(e["provenance"] for e in chains).items())] + [
        "", "| Merge step | Count |", "|---|---|",
    ] + [f"| {k} | {v} |" for k, v in sorted(stats.items())] + [
        "", "## Largest chains", "",
        "| Rank | Chain | Slug | Status |", "|---|---|---|---|",
    ] + top_rows + [""]
    REPORT.write_text("\n".join(lines))

    # Curated grade changes.
    old_letter = {"green_plus": "A+", "green": "A", "yellow": "B", "orange": "C", "red": "F",
                  "red_minus": "F−", "grey": "N/A"}
    rows, counts = [], Counter()
    for c in curated:
        e = by_slug[c["slug"]]
        old = old_letter[c["rating"]]
        new = letters[e["grade"]].replace("-", "−") if e.get("grade") else "Not graded yet"
        if old == new:
            counts["unchanged"] += 1
            continue
        if not e.get("grade"):
            counts["now not graded"] += 1
            reason = "No citable evidence on how the food is prepared; the old grade had none either."
            if e.get("researched"):
                reason = "Researched; not enough evidence to grade."
        else:
            counts["changed"] += 1
            reason = e["basis"]
        rows.append(f"| {c['name']} | {old} | {new} | {e.get('confidence', '–')} | {reason} |")
    CHANGES.write_text("\n".join([
        "# Changes to the original curated grades", "",
        "Generated by `scripts/build_chains.py`. The original 186 grades (`scripts/data/curated_chains.json`) were mostly",
        "inferred from distributor relationships (\"uses Sysco\"), which says nothing about whether a kitchen cooks or reheats.",
        "Every one was re-checked against prep evidence. Grades below come only from `docs/data/chain_evidence.json`.", "",
        f"- Unchanged: {counts['unchanged']}",
        f"- Changed to a different grade: {counts['changed']}",
        f"- Now \"Not graded yet\" (no prep evidence): {counts['now not graded']}", "",
        "| Chain | Old | New | Confidence | Why |", "|---|---|---|---|---|",
    ] + rows + [""]))


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--nsi-ref", default=NSI_REF)
    parser.add_argument("--wiki-oldid", type=int, default=WIKI_OLDID)
    parser.add_argument("--output", type=Path, default=OUTPUT)
    args = parser.parse_args()
    chains, stats, nsi_count, wiki_count, curated = build(args.nsi_ref, args.wiki_oldid)
    for e in chains:
        if e.get("grade"):
            assert e["sources"] and e["confidence"] in ("high", "medium", "low") and e["basis"], e["slug"]
    write(chains, stats, nsi_count, wiki_count, args.nsi_ref, args.wiki_oldid, args.output, curated)
    graded = sum(1 for e in chains if e.get("grade"))
    print(f"{len(chains)} chains, {graded} graded -> {args.output}")
    for k, v in sorted(stats.items()):
        print(f"  {k}: {v}")


if __name__ == "__main__":
    main()

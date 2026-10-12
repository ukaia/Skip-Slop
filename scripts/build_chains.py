#!/usr/bin/env python3
"""Builds Skip Slop/Data/SeedChains.json from curated grades plus public chain lists.

Sources (pinned for reproducibility; override with flags):
  1. scripts/data/curated_chains.json - hand-graded chains. Their grades are
     copied unchanged and always win.
  2. OpenStreetMap name-suggestion-index (NSI), brands/amenity/* and brands/shop/*
     food files, filtered to brands whose locationSet covers the United States.
     Gives names, matchNames (aliases), Wikidata IDs, and amenity/cuisine tags.
  3. Wikipedia, "List of restaurant chains in the United States" - cross-check
     for chains NSI lacks. The section a chain is listed under gives its format.

Chains not in the curated list get a grade only from the category rules in
docs/data/RATING_METHOD.md (`category_grade` below) and are marked
"ratingBasis": "category" so the app shows the grade as estimated.

Usage:  python3 scripts/build_chains.py [--nsi-ref SHA] [--wiki-oldid REVID]
Writes: Skip Slop/Data/SeedChains.json and docs/data/chains_build_report.md
Needs:  Python 3.9+, network access. No third-party packages.
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
OUTPUT = ROOT / "Skip Slop" / "Data" / "SeedChains.json"
REPORT = ROOT / "docs" / "data" / "chains_build_report.md"

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

USER_AGENT = "SkipSlop-chain-builder/1.0 (https://github.com/ukaia/Skip-Slop)"


# MARK: - Rating rules (documented in docs/data/RATING_METHOD.md)

def category_grade(category):
    """Grade for a chain we have not graded by hand, from its format alone.

    - Quick service (fast food, coffee, bakery, dessert): "grey" (N/A). Every
      curated fast-food and coffee chain is grey; the app does not grade fast food.
    - Sit-down (casual dining, bar): "orange" (C). This is the grade the app's
      RatingInferenceEngine gives an unverified chain-style restaurant. We never
      assign F/F- by rule, because those assert a specific distributor.
    """
    if category in ("fast_food", "coffee", "bakery", "dessert"):
        return "grey"
    if category in ("casual_dining", "bar"):
        return "orange"
    raise ValueError(f"unknown category {category}")


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

    for c in curated:
        entry = OrderedDict(c)
        entry["aliases"] = list(c.get("aliases", []))
        entry["provenance"] = "curated"
        entry["ratingBasis"] = "curated"
        entry["wikidata"] = None
        chains[c["slug"]] = entry
        index(c["slug"], [c["name"]] + entry["aliases"], None)
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
        chains[slug] = OrderedDict([
            ("slug", slug),
            ("name", brand["name"]),
            ("rating", category_grade(brand["category"])),
            ("category", brand["category"]),
            ("distributor", None),
            ("parentCompany", None),
            ("source", "OpenStreetMap name-suggestion-index (" + brand["file"] + ")"),
            ("aliases", [a for a in names if compact(a) != compact(brand["name"])]),
            ("provenance", "nsi"),
            ("ratingBasis", "category"),
            ("wikidata", brand["wikidata"]),
        ])
        if brand["cuisine"]:
            chains[slug]["cuisine"] = brand["cuisine"]
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
        chains[slug] = OrderedDict([
            ("slug", slug),
            ("name", w["name"]),
            ("rating", category_grade(w["category"])),
            ("category", w["category"]),
            ("distributor", None),
            ("parentCompany", None),
            ("source", f"Wikipedia: {WIKI_PAGE} ({w['section']})"),
            ("aliases", []),
            ("provenance", "wikipedia"),
            ("ratingBasis", "category"),
            ("wikidata", w["wikidata"]),
        ])
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

    return list(chains.values()), stats, len(nsi), len(wiki)


def write(chains, stats, nsi_count, wiki_count, nsi_ref, wiki_oldid, output):
    def clean(entry):
        return OrderedDict((k, v) for k, v in entry.items() if v not in (None, []))

    output.write_text("[\n" + ",\n".join("  " + json.dumps(clean(e), ensure_ascii=False) for e in chains) + "\n]\n")

    prov = Counter(e["provenance"] for e in chains)
    ratings = Counter((e["ratingBasis"], e["rating"]) for e in chains)
    cats = Counter((e["provenance"], e["category"]) for e in chains)
    lines = [
        "# Chain database build report",
        "",
        "Generated by `scripts/build_chains.py`. Do not edit by hand.",
        "",
        f"- NSI ref: `{nsi_ref}` ({nsi_count} US food brands read)",
        f"- Wikipedia: [{WIKI_PAGE}](https://en.wikipedia.org/w/index.php?oldid={wiki_oldid}) oldid {wiki_oldid} ({wiki_count} rows read)",
        f"- Total chains: **{len(chains)}**",
        "",
        "| Provenance | Chains |", "|---|---|",
    ] + [f"| {k} | {v} |" for k, v in sorted(prov.items())] + [
        "", "| Rating basis | Rating | Chains |", "|---|---|---|",
    ] + [f"| {b} | {r} | {n} |" for (b, r), n in sorted(ratings.items())] + [
        "", "| Provenance | Category | Chains |", "|---|---|---|",
    ] + [f"| {p} | {c} | {n} |" for (p, c), n in sorted(cats.items())] + [
        "", "| Merge step | Count |", "|---|---|",
    ] + [f"| {k} | {v} |" for k, v in sorted(stats.items())] + [""]
    REPORT.write_text("\n".join(lines))


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--nsi-ref", default=NSI_REF)
    parser.add_argument("--wiki-oldid", type=int, default=WIKI_OLDID)
    parser.add_argument("--output", type=Path, default=OUTPUT)
    args = parser.parse_args()
    chains, stats, nsi_count, wiki_count = build(args.nsi_ref, args.wiki_oldid)
    curated = json.loads(CURATED.read_text())
    by_slug = {c["slug"]: c for c in chains}
    for c in curated:
        assert by_slug[c["slug"]]["rating"] == c["rating"], f"curated grade changed: {c['slug']}"
    write(chains, stats, nsi_count, wiki_count, args.nsi_ref, args.wiki_oldid, args.output)
    print(f"{len(chains)} chains ({len(curated)} curated) -> {args.output}")
    for k, v in sorted(stats.items()):
        print(f"  {k}: {v}")


if __name__ == "__main__":
    main()

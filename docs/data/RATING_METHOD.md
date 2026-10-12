# How Skip Slop grades restaurants

A grade answers one question: **how is the food made?** Cooked on site from real ingredients, or reheated from bags and boxes. Nothing is guessed. A place gets a grade only when there is evidence: researched and cited for chains, cited for independents, or enough community reports. Everything else shows **Not graded yet**.

## The scale

| Grade | Name in app | Means |
|---|---|---|
| **A+** | Local & Scratch | Cooked from scratch on site **and** a substantial share of ingredients comes from named local or regional farms and producers. |
| **A** | Scratch Kitchen | Cooked from scratch on site from mostly fresh, raw ingredients. Sides and sauces are made in house. Sourcing doesn't have to be local. |
| **B** | Mostly Scratch | Most cooking happens on site from raw ingredients (fresh proteins cooked, dough made, produce cut), with some pre-made components such as sauces, sides, or desserts. |
| **C** | Assembled | A mix: some on-site cooking, but significant pre-made, frozen, or commissary components are assembled in store (pizza built on commissary dough, sandwiches from pre-cooked meats). |
| **F** | Reheated | Mostly pre-made, pre-cooked, frozen, or commissary food that is reheated, fried, steamed, or microwaved on site. |
| **F−** | Truck to Table | Complete meals bought ready-made from a broadline distributor (Sysco, US Foods, PFG, …) and reheated. |
| – | Not graded yet | No evidence yet. Never a guess, and never "probably fine". |

Who supplies a restaurant is **not** a grade on its own. Almost every restaurant in the US, including scratch kitchens, buys flour, oil, and dairy through Sysco or US Foods. The original grades leaned on distributor relationships; that's the main reason they were wrong (see `curated_grade_changes.md`). Distributors only matter for F−, where the evidence must show the *entrées themselves* arrive as finished meals.

## Chains

### Evidence file

`docs/data/chain_evidence.json` holds the research, one entry per chain:

```json
{"slug": "texas-roadhouse", "name": "Texas Roadhouse",
 "signals": {"entree": "scratch", "sides": "scratch"},
 "basis": "Every restaurant has an in-house meat cutter ...",
 "sources": [{"url": "...", "title": "...", "tier": 1, "supports": ["entree", "sides"]}]}
```

Entries with empty `signals` and a `notes` field record chains we researched but couldn't grade.

### Signals

Each signal is set only when a cited source supports it (`supports` lists the signals a source backs).

| Signal | Values (score) | What it captures |
|---|---|---|
| `entree` (required) | `scratch` (100), `fresh_cooked_premade_parts` (75), `assembled` (50), `reheated` (15), `broadline_meals` (0) | How the main items are made. `scratch`: raw/fresh ingredients cooked on site (central grinding or portioning of raw meat still counts). `fresh_cooked_premade_parts`: cooked on site, but key parts arrive made (sauces, marinated proteins, company dough mix). `assembled`: significant pre-made or commissary components. `reheated`: mostly pre-cooked or frozen items reheated, fried, or steamed. |
| `sides` | `scratch` (100), `mixed` (55), `premade` (15), `na` | Sides, sauces, soups, dressings, bread, desserts. `mixed` also covers "some documented as house-made, the rest unknown". `na` for single-product places (cookie, ice cream, doughnut shops). |
| `produce` | `fresh_onsite` (100), `mixed` (55), `precut` (15) | Whether vegetables and fruit are prepped in store. |
| `sourcing` | `local`, `direct`, `mixed`, `broadline` | Where ingredients come from. Only used to separate A+ from A. |

### Formula

1. **Prep score** = weighted mean of the known prep signals: entrée **0.7**, sides **0.2**, produce **0.1**. Unknown signals are left out and the weights renormalized; `entree` is required.
2. **Grade**
   - **F−** if `entree` is `broadline_meals`.
   - **A+** if `entree` and `sides` are `scratch` (or `na`), score ≥ 85, `sourcing` is `local`, and the local sourcing is backed by an independent source.
   - **A** if `entree` and `sides` are `scratch` (or `na`) and score ≥ 80.
   - **B** if score ≥ 60; **C** if score ≥ 38; **F** otherwise.
   - A and A+ need at least one **independent** source (tier 2 or 3) for the entrée signal. A company's own claims can lift a chain to B, no further.
3. **Confidence** comes from the sources behind the `entree` signal:
   - **High**: two or more sources, at least one tier 1 or 2, and at least one independent (tier 2 or 3).
   - **Medium**: two or more sources, or a single tier 1 or 2 source.
   - **Low**: a single tier 3 source.
   - Company-only evidence is capped at medium.

Examples: Texas Roadhouse (scratch entrée and sides, company site + two independent articles) → **A, high**. Olive Garden (assembled entrées, soups and sauces made in house but frozen proteins and desserts) → score 51 → **C**. Applebee's (entrées and sides reheated per several former-employee accounts) → score 15 → **F, medium**.

### Source tiers

| Tier | What | Examples |
|---|---|---|
| 1 | The company itself | SEC filings (10-K, S-1, 8-K), company website, press releases, executive statements |
| 2 | Independent reporting | Nation's Restaurant News, Restaurant Business, QSR Magazine, newspapers, broadcast news |
| 3 | Aggregated insider and diner accounts | Mashed, Tasting Table, Chowhound, The Daily Meal, The Takeout, Eat This (summarizing employee Reddit/TikTok posts and reviews) |

Paywalled sources (Technomic, WSJ) and sites that block automated fetching (Business Insider, Eater) are not used.

### Coverage

`scripts/build_chains.py` writes `docs/data/chains_build_report.md` with counts by grade and confidence, and a table of the ~150 largest US chains (`docs/data/top_chains.json`) with each one's status. All 186 originally curated chains were re-researched; changes are listed in `docs/data/curated_grade_changes.md`.

### Building

```bash
python3 scripts/build_chains.py            # pinned NSI and Wikipedia versions
python3 scripts/build_chains.py --nsi-ref main --wiki-oldid <newer revid>
```

The script merges brand names and aliases (curated list, OpenStreetMap name-suggestion-index, Wikipedia) with the evidence file, grades every chain that has evidence, and writes `Skip Slop/Data/SeedChains.json`. A grade in the app always carries its confidence, basis, and source links. The build fails if a graded chain is missing any of them.

To add or fix a chain: edit `docs/data/chain_evidence.json`, rerun the script, commit both.

## Independent restaurants

Independents are **never** guessed from their name, category, or neighborhood. They show **Not graded yet** unless:

- there is verifiable evidence in `docs/data/independent_evidence.json` (their own site or menu stating scratch cooking or naming farm partners, or press coverage), graded with the same signals and formula as chains, or
- enough community reports (below).

Independent evidence entries also carry a location (latitude/longitude) and are matched to map places by name **and** distance (within 250 m), since independent names aren't unique. `scripts/build_independents.py` validates the file and writes `Skip Slop/Data/IndependentGrades.json`. No mass scraping: entries are added by hand with citations.

## Community reports

Detail cards ask **"How is the food made here?"** with three answers: **Made from scratch**, **Reheated**, or **Not sure**, plus an optional evidence type and short note.

### Storage

CloudKit public database, record type `PrepReport`. The record name is `prep_<placeKey>_<userRecordName>`, so each iCloud user has exactly one report per place; reporting again edits it. `placeKey` is the MapKit place identifier when available, otherwise `<chain slug or "independent">_<lat>_<lon>` (5 decimals). Fields: `placeKey`, `chainSlug`, `verdict`, `evidence`, `note`, `createdAt`, `updatedAt`, `dayStamp`, `dailyCount`.

Flags on evidence notes are `PrepReportFlag` records named `flag_<reportRecordName>_<userRecordName>` (one flag per user per report).

### Evidence types and weights

| Evidence | Weight |
|---|---|
| I work or worked here | 1.0 |
| Saw it prepared (open kitchen, prep in view) | 1.0 |
| Saw frozen or pre-made boxes / Sysco–US Foods packaging | 1.0 |
| Staff told me | 1.0 |
| The menu or website says house-made | 0.75 |
| Just my impression / none given | 0.5 |

### Roll-up

For one place:

1. Drop reports that are **Not sure**, from **flagged reporters**, from reporters over the **daily limit** on that day, or with 3+ flags from other users.
2. Each remaining report gets weight = evidence weight × **tenure** (0.5 if the reporter's first report is less than 24 hours old, else 1).
3. **Scratch share** p = Σ weight(scratch) / Σ weight.
4. **Outlier dampening / weight by agreement:** when one side holds ≥ 80% of the weight, reports on the other side count half, then p is recomputed. A lone contrarian (or a single bad actor) can't swing a strong consensus.
5. **Smoothing:** p is shrunk toward 0.5 with one virtual report on each side: p' = (Σw·p + 1) / (Σw + 2).
6. **Minimum:** a community grade appears only with **≥ 5** non-"not sure" reports from different users and total weight ≥ 3.
7. **Mapping** (community reports can't verify sourcing, so no A+):

| p' | Grade |
|---|---|
| ≥ 0.80 | A |
| ≥ 0.60 | B |
| ≥ 0.40 | C |
| < 0.40 | F (F− if at least half the reheated weight cites distributor boxes and p' < 0.15) |

The app shows it as **Community grade** with the report count, e.g. "Community grade · 7 reports".

### Chains vs. community

| Cited grade confidence | Community grade |
|---|---|
| High | Never overrides. Shown below the grade as "Community: 7 reports, 86% say scratch". |
| Medium | Overrides only with ≥ 10 qualifying reports. |
| Low | Overrides with the normal minimum (5). |
| Not graded | Shown when it qualifies. |

Reports are per location, so a badly run franchise shows up in its own community numbers without changing the chain's cited grade.

### Abuse protection

- **One report per iCloud user per place** (deterministic record name; editing replaces the old report).
- **Rate limit:** 20 new reports per user per day. Enforced on the device before saving, and recorded on each report (`dayStamp`, `dailyCount`) so the roll-up ignores reports past the limit.
- **Tenure:** reports from accounts whose first report is under 24 hours old count half.
- **Flagged reporters:** reports from user record names listed in `FlaggedReporter` records are ignored. Only the developer creates those (CloudKit Dashboard, security role set so users can't create them).
- **Outlier dampening and smoothing** (above).
- **ContentFilter** screens evidence notes (slurs, threats, links, phone numbers, addresses, shouting).
- **Report a note:** every evidence note has a Report button (required for App Review's user-generated content rules). Three flags from different users hide the note and drop that report from the roll-up.

## Validation

`docs/verification/grading-validation.md` runs about 40 well-known places through the real matcher and grade resolver and compares the result with the grade the evidence supports.

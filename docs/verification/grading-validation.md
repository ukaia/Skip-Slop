# Grading validation

47 well-known places run through the app's real matcher and grade resolver (`GradingValidationTests`, raw output in `raw/grading-validation.csv`). Names are written the way MapKit returns them ("Applebee's Grill + Bar", "Olive Garden Italian Restaurant", "sweetgreen"), and independents use their real coordinates, so the name + 250 m matching is exercised too.

**Expected** is the grade a reviewer assigns after reading the cited evidence for that place, using the scale in `docs/data/RATING_METHOD.md`, without looking at the formula's output. "–" means the right answer is Not graded yet (no evidence collected), which checks that nothing is guessed and that independents don't get mismatched to chains.

## Result

| | Count |
|---|---|
| Places | 47 |
| Pipeline agrees with reviewer | **44 (94%)** |
| Disagreements | 3 |
| Wrong-place matches (a place picking up another restaurant's grade) | **0** |
| Independents guessed without evidence | **0** |

The test fails the build if agreement drops below 85% or any place matches the wrong restaurant.

## By place

| Place | Expected | App | App label | Matched |
|---|---|---|---|---|
| Chez Panisse | A+ | A+ | High confidence | independent |
| Blue Hill (NYC) | A+ | A+ | Medium confidence | independent |
| Le Pigeon | A | A | High confidence | independent |
| Ava Gene's | A+ | A+ | High confidence | independent |
| **Screen Door** | **A** | **B** | High confidence | independent |
| Husk | A+ | A+ | High confidence | independent |
| Zuni Café | A+ | A+ | High confidence | independent |
| **Franklin Barbecue** | **A** | **B** | High confidence | independent |
| Pine State Biscuits | – | – | Not graded yet | – |
| Joe's Pizza (NYC) | – | – | Not graded yet | joes-pizza (ungraded chain) |
| Veracruz All Natural | – | – | Not graded yet | – |
| The Cheesecake Factory | A | A | Medium confidence | cheesecake-factory |
| Applebee's | F | F | Medium confidence | applebees |
| Chili's | F | F | Medium confidence | chilis |
| Olive Garden | C | C | Medium confidence | olive-garden |
| Texas Roadhouse | A | A | High confidence | texas-roadhouse |
| Red Lobster | F | F | Medium confidence | red-lobster |
| Outback Steakhouse | B | B | High confidence | outback-steakhouse |
| Cracker Barrel | A | A | High confidence | cracker-barrel |
| Denny's | F | F | Medium confidence | dennys |
| IHOP | B | B | Medium confidence | ihop |
| P.F. Chang's | A | A | High confidence | pf-changs |
| TGI Fridays | F | F | Medium confidence | tgi-fridays |
| Waffle House | B | B | Low confidence | waffle-house |
| McDonald's | F | F | High confidence | mcdonalds |
| In-N-Out Burger | A | A | Medium confidence | in-n-out |
| Chipotle | B | B | High confidence | chipotle |
| **Panera Bread** | **F** | **C** | Low confidence | panera-bread |
| Subway | F | F | High confidence | subway |
| Taco Bell | F | F | High confidence | taco-bell |
| Wendy's | C | C | High confidence | wendys |
| Burger King | F | F | Medium confidence | burger-king |
| Chick-fil-A | B | B | High confidence | chick-fil-a |
| Starbucks | F | F | Medium confidence | starbucks |
| Domino's | C | C | High confidence | dominos |
| Five Guys | A | A | Medium confidence | five-guys |
| Shake Shack | B | B | Medium confidence | shake-shack |
| Sweetgreen | A+ | A+ | High confidence | sweetgreen |
| CAVA | B | B | Medium confidence | cava |
| Popeyes | B | B | Medium confidence | popeyes |
| KFC | B | B | Low confidence | kfc |
| Raising Cane's | B | B | Medium confidence | raising-canes |
| Dunkin' | F | F | Low confidence | dunkin |
| Jersey Mike's | C | C | High confidence | jersey-mikes |
| Panda Express | B | B | Medium confidence | panda-express |
| Buffalo Wild Wings | F | F | Medium confidence | buffalo-wild-wings |
| Dutch Bros | – | – | Not graded yet | dutch-bros (ungraded chain) |

## Disagreements

1. **Screen Door (A expected, B given).** The cited sources cover the fried chicken (battered in house, local poultry) and fresh-baked biscuits but not the other sides, so the `sides` signal is `mixed` and the formula caps it at B. A source covering the rest of the menu would move it to A (A+ if local sourcing is confirmed independently). This is the formula being conservative, not wrong.
2. **Franklin Barbecue (A expected, B given).** Same cause: overnight post-oak brisket is well documented, but nothing citable covers the sides. Without a `sides` signal the formula caps at B.
3. **Panera Bread (F expected, C given).** The evidence that soups are factory-made and reheated and that bread arrives par-baked and frozen is solid. A reviewer reading it calls Panera "predominantly reheated" (F). The `entree` signal is `assembled` because no cited source says how sandwich proteins arrive. A source on pre-cooked proteins would make it `reheated`, and the grade F. Confidence is low, which the app shows.

All three come from missing evidence, and each moves toward the reviewer's grade once one more source is added. None is a matching error.

## What this doesn't cover

- These are offline name/coordinate inputs. The live MapKit harness (`PlaceVerificationTests`, `docs/verification/accuracy.md`) covers how real MapKit names match; it wasn't rerun for this change.
- Expected grades were set by the same researcher who collected the evidence. An independent second reviewer (Kai) should spot-check them, especially the B/C boundary chains.

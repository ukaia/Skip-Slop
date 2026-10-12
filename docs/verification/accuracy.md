# Place accuracy: before vs after

Live MapKit data from `PlaceVerificationTests` (5 cities, 3 km regions), scored against the hand labels in
`ground_truth.csv` (every distinct food-place name was reviewed; names not listed are independents).
"Before" is the original matcher and 186-chain list; "after" is the new matcher and 977-chain list,
run on **the same places**.

Places scored: **1008** (restaurants, cafes, bakeries, breweries, wineries, and anything the app fetch returned).

## Chain matching

| | Before | After |
|---|---|---|
| Chain places (truth) | 213 | 213 |
| True positives | 88 | 161 |
| False positives: independent matched to a chain | 6 | 1 |
| False positives: wrong chain | 0 | 0 |
| Misses: chain in curated list | 0 | 0 |
| Misses: chain added from NSI/Wikipedia | 75 | 2 |
| Misses: chain in no source | 50 | 50 |
| Precision | 94% | 99% |
| Recall (all chains) | 41% | 76% |

Before, "misses: chain added from NSI/Wikipedia" were chains the old list didn't have at all.

### False positives

| Place | Before matched | After matched | Truth |
|---|---|---|---|
| Ca Va Marche | cava | – | independent |
| Grind | – | grind | independent |
| Palmer House | the-palm | – | independent |
| Palmieri Cafe | the-palm | – | independent |
| Taqueria El Torito | el-torito | – | independent |
| The Star | starbucks | – | independent |
| The Village | village-inn | – | independent |

### Remaining misses (after)

| Place | Truth |
|---|---|
| 2 Bros Pizza | not in sources |
| 5 Napkin Burger | not in sources |
| Alfred Coffee | not in sources |
| Angelina | not in sources |
| Angelina Bakery | not in sources |
| Angelina Bakery - 7 Times Square | not in sources |
| Angelina Bakery Times Square NYC | not in sources |
| Bill's Bar & Burger | not in sources |
| Black Rifle Coffee Company | not in sources |
| Black Tap | not in sources |
| Bluestone Lane | not in sources |
| Café Grumpy | not in sources |
| Capital One Café | not in sources |
| Carlo's Bake Shop | not in sources |
| Carmine's | not in sources |
| Chi'Lantro | not in sources |
| Dollop Coffee Co. | not in sources |
| Dos Caminos | not in sources |
| Emmy Squared Pizza | not in sources |
| Epic Burger | not in sources |
| Eureka! | not in sources |
| Foxtrot | not in sources |
| Gordon Ramsay Burger | not in sources |
| Grimaldi's Coal Brick-Oven Pizzeria | not in sources |
| Hat Creek Burger Company | not in sources |
| Junior's Restaurant | not in sources |
| Killer Burger | not in sources |
| Ladurée Macaroons | not in sources |
| Lady M Cake Boutique | not in sources |
| Levain Bakery | not in sources |
| Maman | not in sources |
| Melt Shop | not in sources |
| MidCity SmashBurger | midcity-smashedburger |
| MrBeast Burger | not in sources |
| Pizano's Pizza & Pasta | not in sources |
| Prince St. Pizza | not in sources |
| Rodeo Goat | not in sources |
| Smallcakes Cupcakery and Creamery | smallcakes |
| Sushi Roku | not in sources |
| Tacodeli | not in sources |
| Twisted Root Burger Co. | not in sources |
| Verve Coffee Roasters | not in sources |
| Via 313 Pizza | not in sources |
| Virgil's Real BBQ | not in sources |
| Zalat Pizza | not in sources |
| maman | not in sources |

## Independents

795 independent places. Before, 556 of 795 were labeled estimated ("Likely" coffee/fast-food guesses were shown as certain). After, 795 of 795 are.

| Grade | Places |
|---|---|
| A | 168 |
| B | 292 |
| C | 107 |
| N/A | 228 |

| Confidence | Places |
|---|---|
| Category | 1 |
| Estimated | 126 |
| Guess | 441 |
| Likely | 227 |

## What the app loads

Places returned by `MapSearchService.searchNearby` for a 3 km region (before: one "restaurant" query;
after: points-of-interest requests for food categories plus "restaurant", "cafe", "food" queries, merged).

| City | Before: places | Before: not chains | After: places | After: not chains |
|---|---|---|---|---|
| Austin TX | 25 | 25 | 125 | 107 |
| Chicago IL | 25 | 24 | 134 | 107 |
| New York NY | 25 | 25 | 138 | 115 |
| Plano TX | 25 | 23 | 85 | 76 |
| Portland OR | 25 | 24 | 160 | 151 |

## Spot-check sample

Every 25th scored place, checked by hand against the chain list.

| City | Place | Category | Before | After | Grade (after) | Estimated | Truth | After correct? |
|---|---|---|---|---|---|---|---|---|
| Austin TX | 1886 Cafe & Bakery | Cafe | – | – | N/A | yes | independent | yes |
| Austin TX | Carter Bros’ Pizza | Restaurant | – | – | C | yes | independent | yes |
| Austin TX | Emojis Grilled Cheese Bar | Restaurant | – | – | B | yes | independent | yes |
| Austin TX | Jewboy Sliders | Restaurant | – | – | B | yes | independent | yes |
| Austin TX | NADC Burger | Restaurant | – | – | C | yes | independent | yes |
| Austin TX | Rogue Radish | Restaurant | – | – | B | yes | independent | yes |
| Austin TX | The Backspace | Restaurant | – | – | B | yes | independent | yes |
| Austin TX | kebabalicious | Restaurant | – | – | B | yes | independent | yes |
| Chicago IL | Brewlée Coffee | Cafe | – | – | N/A | yes | independent | yes |
| Chicago IL | DANKE | Restaurant | – | – | B | yes | independent | yes |
| Chicago IL | FARE | Restaurant | – | – | B | yes | independent | yes |
| Chicago IL | Harry's Hamburgs & Wings | Restaurant | – | – | C | yes | independent | yes |
| Chicago IL | Lou Malnati's Pizzeria | Restaurant | lou-malnatis | lou-malnatis | A | no | lou-malnatis | yes |
| Chicago IL | Oasis Cafe | Restaurant | – | – | N/A | yes | independent | yes |
| Chicago IL | Seedo’s Levantine Bakery | Bakery | – | – | A | yes | independent | yes |
| Chicago IL | The Bagel Spot | Restaurant | – | – | B | yes | independent | yes |
| New York NY | 99 Cent Fresh Pizza | Restaurant | – | – | C | yes | independent | yes |
| New York NY | Black Iron Burger | Restaurant | – | – | C | yes | independent | yes |
| New York NY | Capital Grab & Go | Cafe | – | – | N/A | yes | independent | yes |
| New York NY | Dunkin' | Cafe | dunkin | dunkin | N/A | no | dunkin | yes |
| New York NY | HEYTEA | Restaurant | – | heytea | N/A | yes | heytea | yes |
| New York NY | Lady M Cake Boutique | Bakery | – | – | A | yes | unlisted: Lady M | yes |
| New York NY | Melt Shop | Restaurant | – | – | B | yes | unlisted: Melt Shop | yes |
| New York NY | Rosetta Bakery | Cafe | – | – | N/A | yes | independent | yes |
| New York NY | Taco Bell Cantina | Restaurant | taco-bell | taco-bell | N/A | no | taco-bell | yes |
| New York NY | Villas De Guadalupe | Restaurant | – | – | B | yes | independent | yes |
| Plano TX | Bloom Cafe | Cafe | – | – | N/A | yes | independent | yes |
| Plano TX | Fifthteen Street & Bakery | Restaurant | – | – | B | yes | independent | yes |
| Plano TX | Lazy Dog Restaurant & Bar | Restaurant | – | lazy-dog-restaurant-and-bar | C | yes | lazy-dog-restaurant-and-bar | yes |
| Plano TX | Paris Baguette | Cafe | – | paris-baguette | N/A | yes | paris-baguette | yes |
| Plano TX | The Boiling Crab | Restaurant | boiling-crab | boiling-crab | B | no | boiling-crab | yes |
| Portland OR | 40 LBS Coffee Bar | Cafe | – | – | N/A | yes | independent | yes |
| Portland OR | Caffè Umbria | Cafe | – | – | N/A | yes | independent | yes |
| Portland OR | Espresso Bar | Cafe | – | – | N/A | yes | independent | yes |
| Portland OR | Indian Curry House | Bakery | – | – | A | yes | independent | yes |
| Portland OR | Lucky Cat Coffee | Cafe | – | – | N/A | yes | independent | yes |
| Portland OR | OG Poke | Restaurant | – | – | B | yes | independent | yes |
| Portland OR | Portland Burger | Restaurant | – | – | C | yes | independent | yes |
| Portland OR | Shogun Burger & Rice | Restaurant | – | – | C | yes | independent | yes |
| Portland OR | Tasty Corner | Restaurant | – | – | B | yes | independent | yes |
| Portland OR | Wild Child Pizza | Restaurant | – | – | C | yes | independent | yes |

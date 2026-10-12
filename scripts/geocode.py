#!/usr/bin/env python3
"""Prints latitude/longitude for addresses via OpenStreetMap Nominatim.

Used once per new entry in docs/data/independent_evidence.json:
    python3 scripts/geocode.py "1517 Shattuck Avenue, Berkeley, CA" ...
Nominatim's usage policy allows about one request per second.
"""

import json
import sys
import time
import urllib.parse
import urllib.request

for address in sys.argv[1:]:
    url = "https://nominatim.openstreetmap.org/search?format=json&limit=1&q=" + urllib.parse.quote(address)
    req = urllib.request.Request(url, headers={"User-Agent": "SkipSlop-geocode/1.0"})
    results = json.loads(urllib.request.urlopen(req, timeout=30).read())
    if results:
        print(f"{results[0]['lat']},{results[0]['lon']}\t{address}\t{results[0]['display_name'][:80]}")
    else:
        print(f"NOT FOUND\t{address}")
    time.sleep(1.1)

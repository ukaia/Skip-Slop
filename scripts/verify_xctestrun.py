#!/usr/bin/env python3
"""Copies an .xctestrun file, adding the env vars that enable PlaceVerificationTests.

Usage:
  python3 scripts/verify_xctestrun.py <in.xctestrun> <out.xctestrun> <output-dir> <label>
  xcodebuild test-without-building -xctestrun <out.xctestrun> \
    -destination 'platform=iOS Simulator,id=<udid>' \
    -only-testing:"Skip SlopTests/PlaceVerificationTests"
"""
import plistlib
import sys

src, dst, out_dir, label = sys.argv[1:5]
with open(src, "rb") as f:
    plist = plistlib.load(f)

env = {"SKIPSLOP_VERIFY": out_dir, "SKIPSLOP_VERIFY_LABEL": label}
configs = plist.get("TestConfigurations")
targets = [t for c in configs for t in c["TestTargets"]] if configs else [
    v for k, v in plist.items() if isinstance(v, dict) and "TestHostPath" in v]
for target in targets:
    target.setdefault("EnvironmentVariables", {}).update(env)
    target.setdefault("TestingEnvironmentVariables", {}).update(env)

with open(dst, "wb") as f:
    plistlib.dump(plist, f)
print(f"wrote {dst} ({len(targets)} targets)")

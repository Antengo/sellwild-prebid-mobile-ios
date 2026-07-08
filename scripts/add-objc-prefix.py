#!/usr/bin/env python3
"""Add explicit @objc(SWPB<Name>) attributes to public Swift types whose
Objective-C names collide with upstream PrebidMobile.

The Swift-visible names stay unchanged; only the names emitted into the
generated -Swift.h header (and the ObjC runtime) get the SWPB prefix. This
lets an app import both PrebidMobile and SellwildPrebidSDK from Objective-C
without "different definitions in different modules" errors.

Usage: python3 scripts/add-objc-prefix.py collisions.txt
"""
import re
import sys
import pathlib

ROOT = pathlib.Path(__file__).resolve().parent.parent
SRC_DIRS = [ROOT / "SellwildPrebid", ROOT / "EventHandlers"]
PREFIX = "SWPB"

names = set()
for line in open(sys.argv[1]):
    n = line.strip()
    if n:
        names.add(n)

# decl regex: optional attributes/modifiers before the keyword on same line
DECL = re.compile(
    r"^(?P<indent>\s*)(?P<attrs>(?:@\w+(?:\([^)]*\))?\s+)*)"
    r"(?P<mods>(?:public|open|final|@objcMembers\s+)*(?:public|open)\s+(?:final\s+)?)"
    r"(?P<kw>class|enum|protocol)\s+(?P<name>\w+)\b"
)

changed = {}
handled = set()

for src_dir in SRC_DIRS:
    for path in src_dir.rglob("*.swift"):
        text = path.read_text()
        lines = text.split("\n")
        out = []
        dirty = False
        for i, line in enumerate(lines):
            m = DECL.match(line)
            if m and m.group("name") in names:
                name = m.group("name")
                objc_name = PREFIX + name
                # look back for existing @objc attribute lines directly above
                prev = out[-1].strip() if out else ""
                new_line = line
                if f"@objc({objc_name})" in line or (out and f"@objc({objc_name})" in prev):
                    handled.add(name)
                    out.append(line)
                    continue
                if prev == "@objc" or prev == "@objcMembers @objc" :
                    # replace bare @objc above with named form
                    out[-1] = out[-1].replace("@objc", f"@objc({objc_name})", 1)
                    dirty = True
                elif re.match(r"^@objc\b(?!\()", prev):
                    out[-1] = re.sub(r"@objc\b(?!\()", f"@objc({objc_name})", out[-1], count=1)
                    dirty = True
                elif "@objc(" in prev:
                    # already has an explicit different name; leave it
                    handled.add(name)
                    out.append(line)
                    continue
                elif re.search(r"@objc\b(?!\()", line):
                    new_line = re.sub(r"@objc\b(?!\()", f"@objc({objc_name})", line, count=1)
                    dirty = True
                else:
                    # no @objc anywhere: insert attribute line above
                    out.append(m.group("indent") + f"@objc({objc_name})")
                    dirty = True
                handled.add(name)
                out.append(new_line)
            else:
                out.append(line)
        if dirty:
            path.write_text("\n".join(out))
            changed[str(path.relative_to(ROOT))] = True

print(f"files changed: {len(changed)}")
missing = names - handled
print(f"types handled: {len(handled)}/{len(names)}")
if missing:
    print("NOT FOUND (need manual handling):")
    for n in sorted(missing):
        print("  " + n)

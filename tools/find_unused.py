#!/usr/bin/env python3
"""Find files the game never uses.  Run from the project folder:

    python tools/find_unused.py            (report only — deletes nothing)

What it checks
  1. Game files (scripts, scenes, models, textures, sounds, data) that no game
     script or scene refers to.  Test scripts in sim/tests/ do not count as "use".
  2. Folders that are not part of the game (demos, docs, old outputs, template addons).
  3. Data CSVs imported as translations (they create junk .translation files and are
     left out of an exported game; they should use importer="keep").
  4. Leftover copies of the Terrain3D library outside addons/terrain_3d/bin.

Files it may wrongly flag: anything loaded with a built path, e.g.
"res://assets/models/horse43/marks/%s.png" — check by hand before deleting.
"""
import os, re, sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
os.chdir(ROOT)

SKIP_DIRS = {".godot", ".git", ".github", "tools"}
KEEP = {"project.godot", "export_presets.cfg", "icon.svg", "README.md", ".gitignore",
        ".gitattributes", ".editorconfig", "LICENSE"}
GAME_ADDONS = {"terrain_3d"}            # addons the game really uses
NOT_GAME_DIRS = {"demo", "docs", "Claude outputs"}
DYNAMIC = ("assets/models/horse43/marks/",)   # loaded by built path in race3d/horse_look.gd
SRC_EXT = (".gd", ".tscn", ".tres", ".godot", ".cfg", ".json", ".gdshader", ".gdextension")


def read(p):
    try:
        return open(p, encoding="utf-8", errors="ignore").read()
    except OSError:
        return ""


files = []
for d, ds, fs in os.walk("."):
    parts = d.replace("\\", "/").split("/")
    if any(x in SKIP_DIRS for x in parts) or (len(parts) > 1 and parts[1] in NOT_GAME_DIRS):
        ds[:] = []
        continue
    if len(parts) > 1 and parts[1] == "addons":
        ds[:] = []          # addons are checked as whole folders below
        continue
    for f in fs:
        if f.endswith((".import", ".uid")) or f == ".gdignore":
            continue
        files.append(os.path.join(d, f)[2:].replace("\\", "/"))

src = {p: read(p) for p in files if p.endswith(SRC_EXT) and not p.startswith("sim/tests/")}
classes = {}
for p, t in src.items():
    m = re.search(r"^class_name\s+(\w+)", t, re.M)
    if m:
        classes[p] = m.group(1)

unused = []
for p in files:
    if p.startswith("sim/tests/") or p.startswith(DYNAMIC) or p in KEEP or p.endswith(".md"):
        continue
    others = "\n".join(t for q, t in src.items() if q != p)
    base = os.path.basename(p)
    stem = os.path.splitext(base)[0]
    used = ("res://" + p) in others or base in others
    if p in classes and re.search(r"\b" + classes[p] + r"\b", others):
        used = True
    if not used and p.startswith("assets") and re.search(r"[\"']" + re.escape(stem) + r"[\"']", others):
        used = True   # built paths such as DIR + "name"
    if not used:
        unused.append(p)


def size(path):
    if os.path.isfile(path):
        return os.path.getsize(path)
    return sum(os.path.getsize(os.path.join(d, f)) for d, _, fs in os.walk(path) for f in fs)


def mb(n):
    return f"{n / 1e6:7.1f} MB"


print("== 1. Game files nothing refers to")
for p in sorted(unused):
    print(mb(size(p)), p)
if not unused:
    print("   none")

print("\n== 2. Folders that are not part of the game")
found = False
for d in sorted(NOT_GAME_DIRS):
    if os.path.isdir(d):
        print(mb(size(d)), d + "/"); found = True
if os.path.isdir("addons"):
    for a in sorted(os.listdir("addons")):
        if os.path.isdir("addons/" + a) and a not in GAME_ADDONS:
            print(mb(size("addons/" + a)), "addons/" + a + "/  (addon the game does not use)"); found = True
if not found:
    print("   none")

print("\n== 3. CSV import mode")
bad = False
for d, _, fs in os.walk("data"):
    for f in fs:
        if f.endswith(".csv.import") and 'importer="csv_translation"' in read(os.path.join(d, f)):
            print("   " + os.path.join(d, f) + ' -> set importer="keep"'); bad = True
        if f.endswith(".translation"):
            print("   " + os.path.join(d, f) + "  (junk translation file)"); bad = True
if not bad:
    print("   ok")

print("\n== 4. Stray Terrain3D libraries")
stray = [f for f in os.listdir(".") if f.startswith("libterrain")]
bin_dir = "addons/terrain_3d/bin"
if os.path.isdir(bin_dir):
    stray += [bin_dir + "/" + f for f in os.listdir(bin_dir) if f.startswith("~")]
for f in stray:
    print(mb(size(f)), f)
if not stray:
    print("   none")

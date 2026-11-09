# Publishing handoff — November 9, 2026

This repository contains the owner-selected horse-racing-simulation folder.
The publishing copy was prepared separately; the working game folder was not
modified. Existing GitHub history is preserved.

Game scripts, scenes, data, models, textures, `.uid`/`.import` settings,
third-party libraries and existing licence/credit files are included. Godot
rebuilds `.godot/` on first open. Old ZIP handoffs under `Claude outputs/`,
generated builds, personal saves/logs, caches and local credential files are
excluded. The supplied game source was not refactored or changed for publishing.

Checks: every copied source file was compared byte-for-byte using SHA-256;
high-confidence token/private-key patterns and sensitive filenames were scanned;
no obvious secret was found. Project entry scene and Windows x64 extension
libraries were checked for inclusion. Sixteen optional platform library paths
are already absent in the supplied source and remain absent. This is an upload/integrity check, not a
fresh gameplay regression test. No save-writing tests or engine changes occurred.

Existing asset/data/add-on terms and provenance remain in their credit/license
files. The older `assets/models/CREDITS.md` still contains an unfinished author
placeholder; current horse43 provenance is separately documented in its folder.

Next: clone/open `project.godot` in the documented Godot version, allow imports,
and run the README's gameplay/regression checks before making further changes.

# horse43 — the race and paddock horse

- Model and original textures: the owner's Meshy model (owner-supplied; original provenance and terms apply).
- 43-bone rig, refined walk / trot / gallop, coat & marking system: ChatGPT handoff
  `horse_walk_trot_update_2026-11-08` (`horse_master_walk_trot_gallop.blend`).
- Claude exported `horse43.glb` (visible mesh + active rig + the three refined clips, no materials) with Blender 5.2,
  and baked the procedural coats (6), head markings (10), leg heights (4), leg regions and face normal strength into
  the textures in `coats/` and `marks/`. Settings kept from the master: Mark Variation 17, Face Mark Size 1.0,
  Marking Softness 0.7.
- Known from the handoff: the walk's hooves sit ~8 cm low on the source; trot stance soles 6–33 mm high.
- Trot: replaced by the owner's improved trot (horse_shared_original_trot.blend, action Trot_Smoothed_Original, 1-38.5 at 60 fps); the game eases its last 0.1 s into the first pose so it loops.

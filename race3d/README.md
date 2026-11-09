# race3d/ – 3D race (toon style)

Start from the 2D Race screen with **🎥 Watch in 3D** (same course, distance, going, field and seed),
or open `res://race3d/race_3d.tscn` and press F6.

Keys: **Space** start/pause · **1** Auto TV · **2** Side-on · **3** Head-on · **4** Blimp · **5** Follow selected ·
**6** Gates · **7** Finish line · **R** reset · **N** next race · **Esc** back to 2D

- `track_builder.gd` – builds the course from the engine data: Terrain3D landscape (real elevation under the
  track, flat infield with a lake, hills outside), turf (mowing stripes) / dirt (harrow lines), the second course,
  rails with posts, starting chute, furlong poles every 200 m, finish post, judge's box, start line, starting gate
  (removed after the start), grandstand with crowd, trees.
- `horse_3d.gd` – the toon horse: coat by the engine's coat colour, Western saddle hidden, racing saddle + saddle
  cloth in the JRA gate colour with the number, placeholder jockey in the runner's silks, gallop timed so one
  stride of the clip = one engine stride (stride frequency), trot / walk / rest at low speed.
- `camera_director.gd` – TV cameras; Auto cuts Gates → Side-on → Blimp (bends) → Head-on (home straight) →
  Side-on (last 260 m) → Finish line.
- `race_3d.gd` – scene, sky and sun, engine loop (positions interpolated between 20 Hz engine steps), HUD,
  commentary, results.

If Terrain3D ever causes a problem, set `use_terrain3d := false` at the top of `track_builder.gd` to use a plain
ground mesh instead (same shape and heights).

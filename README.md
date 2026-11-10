# Horse Racing Simulation

A realistic Japanese (JRA) horse racing simulation made in **Godot 4.7**. You can breed, buy and train horses and race them across a full JRA season, then watch the races in 3D.

## Getting started

1. Install **Godot 4.7.2** (standard version, not .NET): <https://godotengine.org/download>
2. Clone this repository.
3. In Godot, use **Import** and choose `project.godot`. The first time it opens, Godot spends a minute or two importing the models and textures.
4. Press **Play** (F5). The game starts at the main menu (`ui/main.tscn`).

The project uses the Vulkan renderer on Windows. If your graphics card has trouble with it, change `rendering_device/driver.windows` in Project Settings.

**Editor tip:** turn on *Editor Settings → Text Editor → Behavior → Auto Reload Scripts on External Change*. Otherwise Godot can save its open script tabs over newer files when you pull changes.

## What's in the game

- **Race engine:** a physics model of each horse's speed, stamina and acceleration, calibrated to real JRA race times. Every other race uses a fast quick model. The full engine also runs as a C++ extension (`addons/race_core`) about 100× faster, with results identical to the GDScript version.
- **Breeding:** genetics with heritability, the MSTN "speed gene", coat colours and markings, and inbreeding. The stud book starts with real sires.
- **Career:** play as an owner, trainer or breeder through the real graded calendar plus overseas G1s, with ratings, jockeys, trainers, finances, injuries and retirement.
- **Market:** the yearly sales, including a 3D sale ring with live bidding. Yearlings are judged mostly on pedigree.
- **Race day:** a race card for every race, odds and all 8 JRA bet types, a 3D paddock, and 3D races with TV-style cameras, the JRA-style overlay, weather and seasons.
- **Riders and silks:** an animated jockey on every horse (riding, pushing and using the crop in time with the gallop), reins, a fitted racing saddle with the horse's number and name, and 40 owner silks (25 Japan, 5 USA, 5 Europe, 5 Hong Kong) with JRA bracket-coloured caps. Owners without catalogue silks use generated colours.
- **World:** about 1,100 foals a year, plus rival open-class horses from the rest of Japan. The share of horses that win a race, reach open class and win a G1 matches real JRA figures.

## Settings and bug reports

**Settings** is on the main menu and at the bottom of the sidebar. It covers graphics quality, shadows, crowd size, frame-rate cap, V-Sync, full screen, volumes, race names on the TV graphics, weekly autosave, and skip-ahead news stops.

**Settings → Create a bug report…** zips the logs, settings, the current career and the newest autosave into `user://bug_reports/`. Send that zip when something goes wrong.

## Project layout

| Folder | What it holds |
|---|---|
| `sim/` | Simulation code: race engine (`race_engine.gd`), career and world (`career.gd`), breeding, stud, training, auction, odds, weather, rivals |
| `sim/tests/` | Headless test scripts for calibration, regression and screenshots (see below) |
| `ui/` | Menus and pages: home, horses, race cards, schedule, market, auctions |
| `race3d/` | 3D race, paddock, sale ring, cameras, TV overlay, weather effects |
| `assets/` | Models (horse, gate), textures, coats and markings, sounds (see `assets/models/CREDITS.md`) |
| `data/` | Real data tables: courses, sires, race times |
| `addons/` | Godot add-ons: `race_core` (C++ race engine, prebuilt for Windows and Linux) and `terrain_3d` |
| `native/race_core/` | C++ source of the race engine extension (see below) |

## Tests

Run a test without opening the editor, from the project folder:

```
godot --headless -s res://sim/tests/<test>.gd
```

Useful ones:
- `g1_replay_check.gd`: replays must match.
- `funnel.gd -- 7 5`: share of foals that win a race, reach open class, win a G1, become elite.
- `inj_phys.gd`: injury rates and movement physics.
- `perf_week.gd`: where a simulated week's time goes.
- `plan_check.gd`: race planner.
- `thread_week.gd`: a week simulated on the worker thread gives the same races as on the main thread.
- `save_check.gd`: safe saves (continue identically after loading, backup when damaged, version checks).
- `perf_week.gd -- 52 5`: a full season's timing by phase.

Screenshot tests (`shot_*.gd`) need a display. Run them with `--rendering-driver opengl3`.

## Building the C++ race engine (only if you change it)

The built libraries are committed in `addons/race_core/bin`, so you do not need this to play. To rebuild after changing `native/race_core/src`:

1. Install Python 3 and SCons (`pip install scons`), plus a C++ compiler (MSVC on Windows, or MinGW).
2. Clone godot-cpp into `native/race_core/godot-cpp` (it is not stored in this repo), on the branch that matches Godot 4.7.
3. From `native/race_core`, run `scons platform=windows target=template_release` (or `platform=linux`).
4. Check that `native_check.gd` still reports every race identical to the GDScript engine.

If the library is missing, the game falls back to the GDScript engine automatically.

## Team

| Who | Role |
|---|---|
| Project owner | Priorities, play-testing, approves each step |
| Claude | Game code, simulation and calibration, tests, integration |
| ChatGPT | 3D models, textures, animations, images, research |

The roadmap and the design notes are kept in the project's shared docs.

## Rules for changes

- Keep the simulation **seeded and deterministic**: the same seed must give the same races. `g1_replay_check.gd` must still pass.
- Don't break existing saves. If the save format changes, add a migration.
- Test before you merge, and say which tests you ran.

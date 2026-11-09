# sim/ – race engine, breeding and career (GDScript)

Started as a GDScript port of the v0.5 JavaScript simulation; v0.6 (Step 2) recalibrated the timing against real JRA data. Pure logic: no scenes, no nodes, no add-ons needed.

| File | Class | What it does |
|---|---|---|
| `sim_rng.gd` | `SimRng` | Seeded random numbers (mulberry32, same sequence as the JavaScript version) |
| `sim_util.gd` | `SimUtil` | Stable sort, JavaScript-style rounding, JSON helpers |
| `race_engine.gd` | `RaceEngine` | 25 JRA courses (with starting spurs), physics, energy, tactics, jockeys, bumping, injuries, EIPH, JRA lap timing, results |
| `breeding.gd` | `Breeding` | Stud book, MSTN speed gene, stat inheritance, coat colour, inbreeding |
| `qcal.gd` | `QCal` | Generated table: quick-result corrections per course + distance (rebuild with `tests/build_qcal.gd` after engine changes) |
| `stud.gd` | `Stud` | Breeding season, heats, pregnancies, foaling, young stock, stallion market, scouting estimates, mating planner |
| `bloodlines.gd` | `Bloodlines` | Real names: Japan's 2026 stallions and fees, famous ancestors, sires that died, overseas stallions (stats are game estimates) |
| `career.gd` | `Career` | Weekly JRA calendar, class ladder, graded races, aging, training, retirement to stud, saves, replays |
| `tests/sim_tests.tscn` | – | Self-test: open it and press **F6** |

## Quick use

```gdscript
# one race
var race := RaceEngine.create_race(field, { "course": "tokyo", "dist": 2400, "going": "firm", "seed": 42 })
while not race.done:
    RaceEngine.step(race)          # 0.05 s of race time; call it from _physics_process to watch live
var res := RaceEngine.results(race) # rows (pos, name, time, margin, last3f, notes), laps, first1000, raceL3F

# where to draw a runner (metres; y is across the track)
var pos: Vector2 = RaceEngine.race_xy(race, runner.dist, runner.lane)
var height: float = RaceEngine.race_elev(race, runner.dist)

# career
Career.init(5)
Career.add_to_stable(Career.buy_yearling()[0].id)
Career.advance_week()
Career.save_to_file()     # user://career.sav (exact binary save)
Career.load_from_file()
```

A horse is a Dictionary: `name`, `stats` (speed, stamina, accel, strength, burst, guts, agility, temper,
sound, wind: 1–100), `gene` (CC/CT/TT), `style` (front/stalker/mid/closer), `bw`, `carried`, `jockey`, `dirt`.

## Notes
- Same seed + same horses = the same race, every time (replays rely on this).
- v0.5 matched the JavaScript version exactly; v0.6 changed the timing on purpose, so the self-test now checks v0.6 reference results.

## v0.6 timing calibration (Step 2)
Real data: JRA average winning times on good going by course, distance, class and age (2015–, sonomamakeiba.com),
200 m lap medians (2016–2025, keiba-rap.com), going effects (JRA Equine Research Institute; course data).
- Faster cruising pace (CS base 15.32 → 15.68) and aerobic fatigue in long races (CS falls after 100 s; jockeys allow for it).
- Dirt CS factor 0.968 → 0.953; start acceleration A0 6.0 → 5.6.
- Going: turf Good +0.5%, Yielding +1.5%, Soft +3.3% (was +0.9 / +2.4 / +4.6%); dirt Good −0.6%, Muddy −1.1%, Sloppy −1.3%.
  JRA English names: turf Firm / Good / Yielding / Soft, dirt Standard / Good / Muddy / Sloppy (`RaceEngine.going_label`).
- Career: going frequency 70 / 20 / 8 / 2% (wetter in Jun–Jul and Sep); debut runners ~1% slower (green);
  quick results use `QCal` so background races match full-engine races.
- Result (full engine, 22 course/class cases, 10 races each): turf 0.0%, dirt +0.1% vs real, every case within ±1.1%.
- Test tools: `tests/lap_bench.gd`, `tests/measure_times.gd`, `tests/build_qcal.gd`, `tests/gen_golden.gd`.
  Different maths libraries (browser vs Godot, Windows vs Linux) can differ in the last binary digit of
  `log`/`cos`, which very rarely shifts a minor placing by a few thousandths of a second.
- `Career.save_json()` / `load_json()` read and write the JavaScript save layout. Godot's JSON reader can change
  the last digit of some numbers, so use `save_data()` / `save_to_file()` for normal saves.
- Speed: a 16-runner race takes about 1.5 s to compute in one go. That's fine for live viewing (20 steps a second)
  and for career mode, and it can be optimised later.

## Step 3 – breeding with real bloodlines
- 34 real stallions in Japan with 2026 fees (Kitasan Black and Equinox ¥25M, Kizuna ¥20M, Contrail ¥18M …; ~ = estimated fee),
  famous ancestors (Sunday Silence, Northern Dancer, Mr. Prospector, Roberto lines), sires that died but still have runners
  (Deep Impact, King Kamehameha, Heart's Cry, Duramente …), and 9 overseas stallions (Frankel, Dubawi, Sea The Stars, Into Mischief …).
- Names, years, pedigrees, coat colours and the listed race records are real; ability, genes and breeding values are game estimates.
- The world's broodmares have fictional names but real sires, so JRA-style crosses appear (e.g. "Sunday Silence 3×4").
- Covering abroad: stud fee + about ¥4M shipping and boarding.
- Tests: `tests/real_check.gd`, `tests/abroad_test.gd`, `tests/own_stud_test.gd`, `tests/stud_test.gd`, screenshots `tests/shot_breed.gd`.

## Step 4A – careers, money and saves
- `profile.gd` (Profile): your career — **Trainer** (youngster path: Racing School → groom → assistant trainer → JRA licence
  exam from 28; or already licensed), **Owner** (JRA licence) or **Breeder** (Hidaka farm). Japan only for now; other
  countries are listed as "coming later". Trainers can't own horses; owners can buy a farm; breeders can get an owner licence.
- Trainer yard: owners offer horses a few times a year, move them away after poor runs and retire them when they choose;
  JRA reviews your boxes every January (8–28, a few at a time); retirement at 70.
- `finance.gd` (Finance): cash (`W.money`), every movement through `Career.ledger(text, amount, category)`, yearly totals
  by category (`W.finYear`), monthly bills, prize split (owner 80 % / trainer 10 % / jockey 5 % / groom 5 %), running
  allowances, breeder prizes, bank loans (2.5 %, up to half your net worth), bankruptcy, private sales (Market).
  Real figures: training fee ~¥700k a month (JRA), JRA owner licence income ≥ ¥20M and assets ≥ ¥100M.
- `saves.gd` (Saves): 10 save slots + 3 rotating weekly autosaves in `user://saves/`; old `career.sav` still loads and is
  converted to an owner-breeder.
- Screens: new-career wizard (`ui/main.gd`), Career (`career_page.gd`), Finances (`finance_page.gd`), Market (`market_page.gd`),
  Buy/Sell on the horse page, cash in the top bar.
- Tests: `tests/career_roles_test.gd` (play a career N years: `-- trainer young normal 15 balanced`), `tests/saves_test.gd`,
  screenshots `tests/shot_careers.gd`.

## Step 4B/4C – people, training, auctions, real pedigrees, bigger world
- `people.gd` (People): real JRA jockeys and trainers from `data/jockeys.csv` / `data/trainers.csv` (the player's netkeiba
  export). Skill from win rate and prize money per ride (small samples shrunk to the average). Jockeys get rides in
  proportion to their real number of rides, the best riders go to the best-fancied horses; apprentice allowances
  (▲3 △2 ☆1, ★ female) in condition races; retirements and 7–9 new apprentices a year; trainers retire at 70.
  Players book jockeys per race (top jockeys can say no) and owners choose the trainer.
- `training.gd` (Training): weekly plan per horse — rest, walking, canter, woodchip, uphill (坂路), turf, dirt, polytrack,
  pool, gate practice × easy (馬なり) / firm (強め) / all-out (一杯). Fitness, fatigue, mood (race-day form ±1 %), weight
  now, gate manners, injury risk; JRA-style workout times. "Trainer decides" uses the stable's routine.
- `auction.gd` (Auction): HBA Training Sale, JRHA Select Sale (yearlings, foals), HBA Selection, Summer, Autumn sales and a
  Mixed Sale; catalogues three weeks before; live bidding against 3–8 bidders; reserves and buy-backs; 5 % commission.
  Each sale is scaled to its real 2025 average (Select yearlings ~¥65M, Summer ~¥7.8M).
- `realped.gd` (RealPed) + `data/realped.json`: real pedigrees from the open-horse-data set (credit: Sheep Meadow Road Games /
  Horse Racing Manager, see `data/CREDITS.md`) plus a hand table of famous ancestors; ~40 more stallions (Kingman,
  Siyouni, Justify, Flightline, I Am Invincible, Bricks And Mortar …) with real 2026 fees; ~520 real Japanese broodmares.
  Pedigree tab shows 5 generations; ancestors the data doesn't name show as "(not recorded)".
- World: 600 mares, 450 foals a year, 7 condition races a week (was 400 / 300 / 5).
- Tests: `tests/people_check.gd`, `tests/world_check.gd`, `tests/auction_check.gd`, screenshots `tests/shot_4b.gd`.

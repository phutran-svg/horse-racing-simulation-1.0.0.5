# ui/ – menu and FM-style game screens (step 1)

`res://ui/main.tscn` is the main scene: **New Career · Load Career · Quick Race · Exit**.

- `main.gd` – app controller: main menu, new-career screen (stable name, silks, starting package), loads the save from `user://career.sav`
- `game_shell.gd` – the career screen in Football Manager style: left menu (Home, Inbox, My Stable, Horses, Breeding,
  Training, Schedule, Results, Finances, Stable Info), top bar (back/forward, search, date, **CONTINUE / NEXT RACE**)
- `horse_page.gd` – horse profile (double-click any horse name): Overview, Race entries, History, Pedigree
- `horse_table.gd` – sortable horse table (click a column title to sort, double-click a row to open the horse)
- `breeding_page.gd` – Breeding tab: Overview · Stallions (Japan + overseas) · Mating planner (predicted foal, inbreeding crosses, fee, live-foal chance, book) · Foals & yearlings (staff reports)
- `game.gd` – helpers: dates, stars, value, aptitudes, labels
- `quick_race_screen.gd` – one-off race setup, starts the 3D race
- `ui_theme.gd` – FM-style colours and theme
- `race_view.gd` – top-down course (used as the minimap in the 3D race)
- `standings_board.gd`, `race_commentary.gd`, `app_state.gd` – shared parts

On race day the game asks: **Watch in 3D** or **Quick result**. Results can be replayed in 3D from the Results page.


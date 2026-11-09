@echo off
rem  Horse Racing Simulation - remove files the game does not use.
rem  Put this file in the project folder (next to project.godot) and double-click it.
rem  CLOSE GODOT FIRST.  Nothing here is used by the game; see the list below.
setlocal
cd /d "%~dp0"
if not exist project.godot ( echo This file must sit next to project.godot. & pause & exit /b 1 )
tasklist /fi "imagename eq Godot*" | find /i "Godot" >nul && ( echo Please close Godot first, then run this again. & pause & exit /b 1 )

echo Removing template and demo folders (COGITO / Terrain3D demo, not part of the game)...
for %%D in (demo docs .github addons\cogito addons\godot_state_charts addons\input_helper) do if exist "%%D" rmdir /s /q "%%D"

echo Removing unused horse models (the game uses assets\models\horse43)...
for %%D in (assets\models\hyper3d assets\models\toon-horse-with-saddle-rigged-animated) do if exist "%%D" rmdir /s /q "%%D"

echo Removing old scripts the game no longer uses...
for %%F in (race3d\gallop_rig ui\race_screen ui\elev_view ui\horse_panel) do (
  if exist "%%F.gd" del /q "%%F.gd"
  if exist "%%F.gd.uid" del /q "%%F.gd.uid"
)
for %%F in (anim_strip anim_strip2 anim_check anim_diff bones_fbx bones_h3d gallop_check gallop_check2 gallop_check3 gallop_strip p) do (
  if exist "sim\tests\%%F.gd" del /q "sim\tests\%%F.gd"
  if exist "sim\tests\%%F.gd.uid" del /q "sim\tests\%%F.gd.uid"
)

echo Removing junk files (stray copies, generated translations)...
del /q "data\*.translation" 2>nul
del /q "Meshy_AI_*.png" "Meshy_AI_*.png.import" 2>nul
if exist "libterrain.windows.release.x86_64.dll" del /q "libterrain.windows.release.x86_64.dll"
del /q "addons\terrain_3d\bin\~*.dll" 2>nul

echo Moving "Claude outputs" (old zips) out of the project to Documents\Claude outputs...
if exist "Claude outputs" (
  if not exist "..\Claude outputs" mkdir "..\Claude outputs"
  robocopy "Claude outputs" "..\Claude outputs" /e /move /njh /njs /nfl /ndl >nul
  if exist "Claude outputs" rmdir /s /q "Claude outputs"
)

echo Clearing Godot's import cache (Godot rebuilds it the next time you open the project)...
if exist ".godot\imported" rmdir /s /q ".godot\imported"

echo.
echo Done. Open the project in Godot; the first open re-imports assets (a minute or two).
pause

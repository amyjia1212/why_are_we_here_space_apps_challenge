The hangar version of walk.tscn, saved 2026-11-09 before the ship interior replaced it.
Godot ignores this folder (.gdignore): it is not in the game or the export.
To use it again, copy walk_hangar.tscn back to scenes/walk.tscn (and restore the "hangar" numbers).

intro.tscn, intro.gd, intro.gd.uid: the old 2D intro screen, archived 2026-11-11 when the
3D intro cutscene (scenes/cutscene_intro.tscn) became the first screen (PLAN.md step 1).
To use it again, move intro.tscn back to scenes/, intro.gd and intro.gd.uid back to
scripts/, put "intro" back in stages.order, and restore the "intro" block in
data/story.json (its text is in Kaleb's GitHub repo).

destination.tscn, destination.gd, destination.gd.uid: the old "Where are we going?" screen,
archived 2026-11-11 (TASKS.md step 2). Choosing a mission (mission_select) now also picks
the place: Moon, Mars or Venus.

walk.tscn, flight.tscn, reroute_panel.tscn, station_panel.tscn: the walkable ship (used for
Flight and the Mars-orbit walk), the Reroute Power panel and the Life Support station panel,
archived 2026-11-12 (TASKS.md step 7, PLAN.md section 9). Their scripts are in
scripts/archive/ (walk.gd, reroute_panel.gd, power_panel.gd, life_support.gd, ship.gd,
station_panel.gd). Flight is now the 2D map and flight log (scenes/flight.tscn). The shadow
pass numbers (game_data.json events.power_low, reroute_power) and the crew supplies
(supplies.json, events.json water_leak) stay in the data files but nothing uses them now.
To use the ship again, move the scenes back to scenes/ and the scripts back to scripts/.

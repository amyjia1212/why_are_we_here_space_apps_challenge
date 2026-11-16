# PROGRESS.md: where we stopped

## Shared planet (2026-11-15 night, not committed yet): waiting for Holden's test

| What changed | Key files |
|---|---|
| Online: the leader's game owns the planet's task list, data sent, ice samples and bots, and sends them 5x a second; the others send planet_do when they finish a task. A task done never goes back to open | `arrival.gd` (shared planet section: player_did, bot_did, credit_send, apply_planet_state), `Party.gd` |
| Bots on the planet: walk to an open task nobody is on (3 s), do it, and go straight to the next step of their chain; with nothing to do they wander (never stand still); they report a task whose instrument was not packed; Venus uses the ship's doors and hallway. Fix after Holden's fail (bots stood still: 15 s wait, and tasks with an unpacked instrument were skipped) | new `scripts/planet_crew.gd` (extends `ship_crew.gd`), `multiplayer.json` bots |
| Teammates on the planet with name tags and on the Tab map; a teammate's task flashes "Nova did it: …" | `arrival.gd`, `story.json` party > planet_did |
| `arrival.gd` line endings made LF (the repo's .gitattributes rule) | |

Self-checks (passed): compile check; bots on the Moon, Mars and Venus (they did every task, Mars drill → analyze straight away, Venus through the ship rooms); online leader + player + bot (the player's tasks show on the leader's planet and the leader's on theirs, checklist ticks on both); solo planet unchanged; screenshot of a bot walking to a seismometer.

## Shared ship (2026-11-15 night, branch `multiplayer-v6`, not committed yet): waiting for Holden's test

Holden: teammates (bots or people) must all be on the same ship working on the same tasks.

| What changed | Key files |
|---|---|
| Online: the leader's game runs the one ship and sends it 5x a second (tasks, life bars, trip progress, bots, data, cash). Others send ship_do / ship_need; the leader does the job for everyone and the log says who fixed it | `flight.gd` (shared ship section: do_task, ask_leader, apply_ship_state, refill_need), `Party.gd` ship_note |
| Teammates on the ship: bots and other players as their characters with a fixed-size name tag; also dots on the Tab map | new `scripts/ship_crew.gd`, `flight.gd` get_tablet_map |
| Bots walk room door → hallway → room door to the station, fix problems nobody started (5 s, then 10 s at the station) and do calm tasks nobody took (12 s, then 4 s) | `ship_crew.gd`, `multiplayer.json` bots + ship_sync |
| Problems x party size on the one ship; online a job/talk/Clean Room no longer pauses the trip; only the leader skips; a life bar at 0 restarts the trip for everyone | `flight.gd`, `Party.gd` |

Self-checks (passed): compile check; bots party on the ship (a bot walked Bridge → hallway → Life Support and fixed the air filter; it also took a calm task); solo flight unchanged (no teammates, normal problem count); online leader + player + bot (the player sees the leader's problem, fixes it, it is gone on the leader's ship and credited to them; a refill reaches the leader; each sees the other and the bot); the earlier online test still passes; screenshots of bots on the ship.

## Multiplayer V6 (2026-11-15 evening, branch `multiplayer-v6`): Phase A + Phase B built, waiting for Holden's test

Plan: `MULTIPLAYER PLAN V6  MD.md`. Decisions: `AGENT_SOURCE.md` section 2 (multiplayer lines).

| Step | What changed | Key files |
|---|---|---|
| A1 | Party screen + lobby (create / join, other players or bots, seat rows with portrait and Waiting / Joined / Bot, "Fill with a bot", START when every seat is filled). 1 player skips it | `scenes/party.tscn`, `scripts/party.gd`, `scripts/autoload/Party.gd`, `StageManager.gd`, `game_data.json` stages, `story.json` party |
| A2 | Harder with more players: ship problems, supply drain (life bars + crew supplies), data goal; bots fix untouched problems (5 s / 10 s) and gather data; briefing line "Crew of 3: …" | `data/multiplayer.json`, `flight.gd`, `GameState.gd` get_data_target / get_supply_use_per_day, `mission_briefing.gd` |
| A3 | Minigames: everyone plays once on their own screen; bots roll 85-100; every score + the team average | `minigame_frame.gd` (minigame scenes unchanged) |
| A4 | Votes in the Mission Room and Design Lab: Enter = my vote, dots over the nameplates, "2 of 3 votes in · 45 s", tie → revote → coin flip, instruments by majority. Test key F8 (bots party) = a fake human vote | `choice_room.gd`, `Party.gd` |
| A5 | Launch pad crew rows (GO / NO-GO / …), "Say GO" button, GO FOR LAUNCH locked until all GO. F8 = a fake human flips NO-GO / GO. Ready checks = moving on together (below) | `launch.gd`, `Party.gd` |
| A6 | Report: "The crew" box (build-job scores, problems fixed, data per player); leaderboard row with the party's names | `debrief.gd` |
| B1 | Relay plan written (no sign-ups, nothing downloaded): Godot relay; the internet address waits for the coach | `relay/README.md`, `AGENT_SOURCE.md` |
| B2 | Relay (`relay/relay.gd`, its own tiny project, ignored by the game) + `Net` autoload (WebSocketPeer) | `relay/`, `serve_relay.ps1`, `scripts/autoload/Net.gd` |
| B3 | Move together: a screen that wants to move on = "I'm ready"; the leader moves everyone with its GameState (each keeps own name + character). "Go anyway" for the leader after 20 s | `Party.gd`, `StageManager.gd` |
| B4 | Votes, minigame scores (0 after 30 s) and GO calls over the network | `Party.gd` |
| B5 | Smaller version: each player flies their own ship (fair share of problems); data, ticked goals, problems fixed and launch damage (averaged) are merged when the screen ends | `Party.gd` merge_contribs, `flight.gd` |
| B6 | Not built (first on the cut list) | |
| B7 | Holden's test (below) | |

Self-checks run (all passed): compile check of every changed script; bots-party logic test (scores, win, tie → revote → coin, timer restart, instruments, GO lock); scenes in a bots party (party, design room vote, assembly scores, launch lock, flight with 3x problems and a bot fix, report); solo check (1 player skips the party screen, no votes, no crew rows, normal problem count); relay test (create, join, lowercase code, messages, full, wrong code, leader left); two-process online test (join, lobby names, START, ready sync, tie vote, scores, leader leaves → start menu); three-process test (2 humans + bot, a player leaves → bot, late join → "already started", wrong code). Web export to `build/web` (relay not in the .pck). `docs/` not updated (only on push).


## Final copy (2026-11-15 afternoon): UPGRADE_PLAN_V6 A1, A2 + three team requests, waiting for Holden's test

| Change | Key files |
|---|---|
| A1: launch caption "head for ." now names Mars / Venus (only the Moon had `in_sentence`; now falls back to the name) | `launch.gd` |
| A2: the report's header (stamp, Redesign, New mission, Notebook, Leaderboard) scrolls with the page; a second Redesign button at the bottom | `debrief.tscn`, `debrief.gd` |
| Previous button in the Design Lab (top left, from the 2nd station on; Backspace does the same) | `choice_room.gd`, `story.json` choice_room > previous_button |
| Ship window: Earth first (big, front right), swings past the right windows to behind; the destination grows ahead; 4 satellites drift past early in the trip. **Bug fixed:** on Moon trips the destination Moon was pulled next to Earth behind the ship, so it never showed ahead | `flight.gd`, `extras.json` spotting > earth_swing, satellites |
| Voice bar never blocks: clicks pass through, 860 px wide and centered, fades after the line is read (stays while a Next button waits) | `inner_voice_bar.gd`, `game_data.json` hud > voice_bar_* |
| Review: the Notebook button moved into the bottom button row (the floating one covered the title) | `review.gd`, `game_data.json` hud > notebook_button_scenes |

**Rest of Tier 1 (3:00 pm):**

| Step | What changed | Key files |
|---|---|---|
| A3 | Key caps strip at the top of the walking screens ([WASD] move, [E] use...) | `Hud.gd` fill_key_strip, `story.json` controls > key_strip |
| A4 | Build job start card: "Press Q to learn why..." + the Q ? sign pulses; the Q ? sign no longer covers the "?" button | `minigame_frame.gd`, `Hud.gd` pulse_question_tag, `story.json` minigames > q_reminder |
| A5 | Ship and planet: after a line is read, the voice bar quietly shows the task at hand (alarm first, then the nearest yellow job) | `inner_voice_bar.gd`, `flight.gd` get_goal_text, `game_data.json` hud > voice_goal_scenes |
| A6 | Drill green zone 0.74-0.84 (was 0.70-0.86); a paused card explains the drill and the ice race before the first drill | `destinations.json`, `arrival.gd` show_explain_card, `story.json` arrival_screen > explain |
| A7 | Hammering = 8 named panels (nose cone, body ring, fin, engine skirt, door hatch...), 3 nails along each seam, panels slide in, a corner rocket fills up | `minigame_hammer.gd`, `minigames.json` hammer > panels |
| Sound | Fixed bus layout file (Music / SFX / Voice made at start, not at run time). Browser check in headless Edge: audio running, sounds start on the first click | `default_bus_layout.tres` |
| Test | Python is not installed: `serve_web.ps1` serves `build/web` for the browser test | `serve_web.ps1` |

Web export 3:02 PM. No git in this folder.

**Tier 2 (3:25 pm) + Credits removed from the start menu:**

| Step | What changed | Key files |
|---|---|---|
| B1 | Launch dates: Best = +8 M$ waiting, short trip, scrub 15% (max 1); OK = +3 M$, scrub 40% (max 2); Poor = soonest, long trip, +120 kg, scrub 70% (max 3). A scrub can come back after you wait; poor dates say "That is what a poor date costs". Wall chips: Wait · Trip · Scrub risk | `extras.json` launch_window, `launch.gd` roll_scrub, `choice_room.gd`, `story.json` extras > launch_window |
| B2 | New "Build complete" screen after the fuel job: rocket rolls out, 3 scores count up, staff jump, confetti, cheer sized to the build, "Ready to launch" | `scenes/build_done.tscn`, `scripts/build_done.gd`, `game_data.json` build_done + stages, `story.json` build_done |
| B3 | Redesign by character: Scientist keeps the design, opens at the instruments if a key instrument was forgotten, amber arrow + name over what to pick; Janitor and Student start the design again from station 1 | `GameState.start_retry / guide_options`, `choice_room.gd` update_retry_marks, `game_data.json` stages > retry_by_level |
| B4 | "LAST TIME" tag over last run's pick and one line per station in the character's own words (good / okay / bad) | `GameState.save_last_attempt`, `inner_voice.json` last_time |

Browser sound re-checked on the 3:24 pm export (audio running, sounds start on the first click).

**Tier 3 (3:55 pm) + the instrument-bay bug:**

| Step | What changed | Key files |
|---|---|---|
| Bug | Calm ship tasks (and the Clean Room at Instruments) never opened: `task_key_at` ranked them with INF - 1.0, which equals INF. Now 1e9. The cleaning game also draws above the Hud | `flight.gd` |
| C1 | Real astronauts walk the ship, the same three all mission (Moon: Koch, Glover, Glenn; Mars: Whitson, Pettit, Mann; Venus: Ride, Mann, Pettit). Toy figures with matching skin, hair, age and suit, a chest name tag and a floating name; drawn portraits. E = the trip pauses, the voice bar shows their name + portrait and narrates 3 sourced facts (NASA links, checked 2026-11-15), then "our game's idea" line. A hidden PLACEHOLDER slot for the unconfirmed intro person | `data/crew.json`, `characters/astronaut.gd/.tscn`, `Bots.gd`, `Portraits.gd`, `flight.gd` |
| C2 | Hunger / Hydration / Air bars (bottom left). Food, Water, Air stations refill them; a learn card the first time (sourced); low bars = reminder + slow walk; a bar at 0 = trip over, start the trip again (design kept). "Life on the ship" box on the report | `supplies.json` needs, `learn_card.gd`, `flight.gd`, `debrief.gd`, `story.json` ship_life / life_report |
| C3 | 31 achievements (explore / skill / outcome), pop-up, saved on the computer; Notebook (N) right side lists them with badges and how to get them; a board behind the start spot in the Character Room | `data/achievements.json`, `autoload/Achievements.gd`, `Hud.gd`, `choice_room.gd` |
| C4 | Mars: three dig sites (radar reading on each), three samples one at a time, deeper = longer drill, farther = longer run; list shows the current site + "Ice samples n of 3" | `destinations.json` mars arrival, `arrival.gd` text_of / current_site |
| C5 | Small jobs: Air = drag the dirty filter out and the clean one in; Water = hold the valve, let go in the green; Food = add water, then eat | `ship_task.gd`, `minigames.json` ship_tasks |

Web export 3:54 PM; browser sound re-checked. New autoload (Achievements): Project → Reload Current Project.

## Innovation features (2026-11-15, 11:05–11:35 am): Feature A + B built and tested, see INNOVATION.md

- **Feature A, "Three voices, one decision":** rocket, orbit and instruments stations; the inner voice gives the
  picked character's hint 1.6 s after the station loads (`hint_delay_seconds`, default). Text:
  `inner_voice.json` > `character_hints`; numbers filled from the data (`Notebook.hint_values`).
  Tested: Design Lab loaded for each character, the voice bar showed 3 different hints per station (Mars), Venus and
  Moon hints use their own numbers.
- **Feature B, "The voice learns":** `scripts/autoload/Notebook.gd` (new autoload, saved to user://notebook.json),
  report card "New word in your notebook", Notebook page (N key; button in Mission Room, Design Lab, Review and the
  report). Tested: a failed Janitor run (over budget) earned "Trade-off" with the run's numbers, the notebook showed
  "1 of 10 words earned", the retry's rocket hint used the word; failing the same way again taught "Payload capacity"
  ("87 kg over the Atlas V 401's payload capacity of 2315 kg"); other characters' notebooks stay empty.
- The character is now called "The Assistant Scientist" on screen (was "The Scientist").
- Answers chosen for the brief's questions (recommended): rocket/orbit/instruments; the existing voice bar; learn on
  mission AND checkpoint failures; the notebook is kept between sessions; Claude drafted the text (Head Writer edits).
- No git, so no commits. Web export 11:30 AM. Holden: Project → Reload Current Project (new autoload).

## ROOM_LAYOUT_PLAN_V5 (2026-11-15, 10:15–10:40 am): Steps 0–5 built, waiting for Holden's test

Layout only (no rules, numbers, scoring or stage order). One shared room scene (`choice_room.gd`) drives the Character
Room, the Mission Room and all 11 Design Lab steps, so each change was made once. All tuning numbers are in
`game_data.json` > `choice_room` (see `_layout_readme`): pedestal_z / pedestal_curve / pedestal_spacing /
pedestal_max_span / pedestal_radius / pedestal_height / character_pedestal_height / small_model_scale / nameplate_size /
nameplate_letter / side_screens (size, x, z, height, angle_degrees, ui_scale) / display_position (shelf) / shelf_scale /
console_position / spawn / room_size (now 18 × 17, one wall moved back so the first frame fits everything).

| Step | What changed |
|---|---|
| 1 | Back-wall screen removed. Two screens on posts, left and right, turned 38° toward the start spot. Left "This choice": room question, step dots + discipline, the option you stand at (or the picked one): "2 · Atlas V 401", Picked tag, one line, up to 3 stat chips; else "Walk to a pedestal". Right "Your mission": six resources (name, bar off-white/amber/red, number; "before → after" on the rows that changed at this station; numbers count), one red blocker line (or green "No blockers"). Character / Mission Room: the staff card / mission card (where, job, why). Option cards, "Did you know?" and the orange Confirm button are off the screens (Did you know is behind Q) |
| 2 | Pedestals raised (1.3 m, characters 0.8 m), slimmer (0.55), in a gentle curve facing the player, row never wider than 7 m (4–5 options get closer together). Small models shown 1.6× bigger. Your spacecraft on a high shelf on the back wall (turns slowly, no floating label). No floating CONFIRM text or waypoint; the green ring on the picked pedestal and the hint bar say it. Confirm desk lower (0.85 m) and placed so it hides no nameplate |
| 3 | Floating outlined labels gone: a navy nameplate on each pedestal's front with "number · name" in big off-white letters; long names wrap to 2 lines (letters never shrink); the picked plate turns amber; blocked options get a dim plate (reason on the left screen) |
| 4 | Start spot moved back so the first frame shows every pedestal and both screens. 3D room title gone: small room name chip at the top left next to the portrait. Voice box hidden until it has something to say, then fades in |
| 5 | First-look screenshots of the Character Room, Mission Room (empty + picked) and every Design Lab step (rocket, orbit, date, 7 parts, Mars instruments ×4, Venus instruments ×4 + 1 blocked): all pass. Walk-up test: the left screen switches to that option. Headless room flow (preview, back, confirm through every step) ran with no errors. Web export 10:35 AM |

**Holden's change (10:45 am):** the spacecraft model at the back has no shelf any more: it floats by itself (turns and
bobs gently). The two screens hang flat on the left and right walls (no posts, no angle), 6 × 3.4 m, centered 3 m back
along the wall (`side_screens` z / height / size). The walking staff moved to the front corners and the General to the
back between the Janitor and the Student, so nothing stands in front of a screen or a character.

**Holden's second layout (11:00 am), replaces the side-wall screens and the floating model at the back:**
- Room is a wide rectangle (26 × 15). Back wall in thirds: screens flat on the LEFT and RIGHT thirds (8 × 4.5 m, bottom
  edge above eye height), the middle third is the observation area.
- Observation area: a round holographic emitter on the floor (glowing rings, a see-through cyan beam, a cyan glow light),
  a spotlight from the ceiling, and a railing ring you cannot walk through. The chosen thing floats big over it, turning
  and bobbing: the rocket (centered), the spacecraft with the part glowing, the planet with its real NASA map, the chosen
  person.
- Options stand in a straight row in front on LOW pedestals (0.6 m, characters 0.3 m) with smaller models
  (`option_model_scale`), all below eye height so they never cover the screens. The picked one rises 0.15 m, grows
  1.15× and gets its own spotlight; option planets use the real NASA maps too.
- Better lighting: 6 ceiling lights, brighter ambient. The confirm desk moved to the front right. The "click a part"
  hint only shows near the railing. The General stands back right, under the right screen; staff walk the front corners.
- Checked: self-check clean, room flow ran, first-look shots of the Character Room, Mission Room, rocket, battery and
  the 5-option Venus instruments room, walk-up test. Web export 10:59 AM.

Screenshots: `Nasa_space_apps\UI polish screenshots\rooms v5\`.
Rough edges: the right screen's mission/staff card uses small print (14 × 2.9) to fit; nameplates are readable but small
for the 5-option Venus instrument room; the hidden test window can pick up the real mouse, so a test screenshot may look
turned (not a game bug).

## UI_POLISH_PLAN_V4 (2026-11-15 morning): Steps 0, 1, 2, 3a, 3b, 4, 5 + one extra built, waiting for Holden's test

Look-only pass (no rules, numbers, scoring or stage order changed). No git, so the "commit" is a copy:
`Nasa_space_apps\UI backup before polish V4` (made before any change). Before/after screenshots for Richard:
`Nasa_space_apps\UI polish screenshots\`.

| Step | What changed | Key files |
|---|---|---|
| 0 | Read-only check: window 1280×720; ~110 per-node sizes/colors; parts screen = a SubViewport wall in the 3D Design Lab; ship "big boxes" = arrival task panel + centered Q card | |
| 1 | New theme: fonts Title 36 / Heading 24 / Body 18 / Small 14 (display effects keep theirs); no borders; radius 16/12/8; see-through navy panels with soft shadows; amber only for the next action; cyan-ish for labels; box/grid gaps in the theme; every per-node gap snapped to 8/16/24/32/48; voice bar = floating rounded panel | `theme/game_theme.tres`, `inner_voice_bar.tscn`, `scripts/ui_kit.gd` (new) |
| 2 | Design Lab wall rebuilt: title + discipline + step dots; ONE slim strip of 6 resources (name, thin bar off-white/amber/red, one number that counts, change mark that fades); 3 equal cards per row (name, one line, ≤3 stat chips; Normal / near = lighter / Picked = amber border + tag / won't work = half dim + reason); one quiet description; ripple line; blockers line; ONE amber "Enter · Confirm" bottom right; pedestal labels = name + one fact, thin navy outline; smaller navy room sign | `choice_room.gd`, `game_data.json` choice_room > wall_ui_scale, `story.json` choice_room > wall |
| 3a | Q card = one small see-through card, low left, 380 px, fades in, no dark screen; arrival task box = small corner card (tasks only + "Mission checklist · 3 of 8 done"); ship door/station signs smaller, thin navy outline; day counter on a dark chip | `Hud.gd`, `arrival.gd`, `ship_builder.gd`, `flight.gd`, `game_data.json` hud > question_card_width |
| 3b | Bridge flight-log screen: scaled theme (readable), warm-white bezel, cyan glow strip and soft light | `flight.gd` |
| 4 | One motion helper (`ui_kit.gd`): fades for Q card, pages, tablet, dictionary; every button grows 3% on hover / dips on press (one hook in Hud); screens change with a 0.3 s navy fade (StageManager); wall numbers count | `ui_kit.gd`, `Hud.gd`, `StageManager.gd` |
| 5 | Review: Back = quiet text bottom left, Office Hours quiet, Launch = the one amber button bottom right; table rows body size, numbers right-aligned. Report: "Redesign and fly again" is the one amber button. Start menu: soft gradient instead of a dark band. Q ? tag moved to the top-right corner (it covered Next). Title Case for SCORE / CHECKLIST / MISSION SCHOOL / launch poll headings / room signs | `review.gd`, `debrief.tscn`, `start_menu.gd`, `Hud.gd`, `story.json`, `inner_voice.json` |
| Extra | Report score counts up (section 4) | `debrief.gd` |

Checked: self-check clean; screenshots of Design Lab (rocket, antenna, Mars and Venus instruments with 2 rows), Character/Mission
rooms, ship, Bridge screen, Q card, Venus + Mars arrival, Review, report, start menu, briefing, Mission School, launch,
minigame, Your File; headless room flow ran with no errors. Web export 2026-11-15 ~9:49 AM.

Rough edges (not fixed): on minigame screens the Q ? tag sits right above the minigame's own "?" button; long names on a
card with the "Picked" tag are cut with "…"; with 4+ options the wall shows 2 chips per card and no description line.

## UPGRADE_PLAN_V3 (2026-11-14 evening): Step 0 + A1-E built, waiting for Holden's test

| Step | What changed | Key files |
|---|---|---|
| 0 | Read-only check done (patch in 5 places, Q = back in 2 places + ship quick fix, checklist only at arrival, planets = code-made textures) | |
| A1 | Mission patch removed (rocket = two plain stripes, suit, report, leaderboard); patch files in archive folders; patch_maker out of the stage list | `rocket_model.gd`, `arrival.gd`, `debrief.gd`, `Leaderboard.gd` |
| A2 | Q = Question card (glossary, pauses the game, unlocks the stamp), "Q ?" tag; Backspace = back; R = quick fix; 15 new glossary entries (peanuts, zero-g indicator, 6 resources, 3 planets, 3 rockets, launch window); cabin tile with the plush that floats at STABLE | `Hud.gd`, `GameState.question_for`, `nasa_resources.json`, `launch.gd`, `flight.gd`, `arrival.gd`, `choice_room.gd` |
| A3 | 8-item checklist by phase, ticked by launch / flight / orbit burn / arrival / return rule; tablet and arrival show only this phase + "3 of 8 done"; report shows all, grouped | `destinations.json` goals + goal_phases, `GameState` checklist section, `cutscene_return.gd`, `debrief.gd` |
| B1 | Character Room staff card | `story.json` characters > staff_card |
| B2 | Mission Room 4-line card | `story.json` destinations > mission_card |
| B3 | Briefing = 4 typed cards (TypewriterLabel, amber arrow, card dots, Q per card) | `mission_briefing.gd`, `typewriter_label.gd` |
| B4 | Mission School (new screen): 6 resource beats + ripple demo, limits read from data, S skips after the first time, Tab then L replays; resources removed from Your File | `mission_school.gd/.tscn`, `story.json` mission_school |
| C1-C4 | real_missions, real_rockets, astronaut_facts (6 facts checked on NASA pages), intro name plaques before "You. I want you.", flight log real-mission line | `nasa_resources.json`, `cutscene_intro.gd`, `flight.gd` |
| D1 | Planet look: real map used when present, else better code-made surfaces, glowing edge, slow spin. **Real NASA maps for Earth, Mars, the Moon and Venus added 2026-11-14** (`assets/planets/`, sources in `REFERENCES.md`); Venus's radar map has a see-through cloud layer on top | `planet_look.gd`, `game_data.json` ship > planet_look |
| E | Hints = 3 keys, flight log = last 4 lines, Design Lab tiles show before→after only when changed, ripple only after a change | `story.json` controls, `flight_log.gd`, `choice_room.gd` |

Screenshot check (2026-11-14, 9:45 PM): all new screens rendered at 1280×720; fixed the Q ? sign (now bottom right),
the briefing checklist card (two columns), Mission School (General faces the class, closer camera, panel under the
Q ? sign; a double signal connect), and the tablet (no repeated timers or strip lines). Winning round: MISSION
SUCCESS with 8 of 8 done. Maps shrunk to 1024 × 512 (web data file 5.3 MB).
Second screenshot pass (9:55 PM): Controls panel in two columns (it overflowed), Space Dictionary list scrolls (45
words) and frees the mouse, launch right panel leaves room for the Q ? sign, report SCORE pinned to the top of its
panel (the longer checklist had pushed it out of view). Your File, Review, Venus arrival, return screen and a losing
report looked right. Note for agents: a test that opens the report adds a leaderboard run unless
GameState.run_recorded is set to true first.

Not done (needs a person): git commit/branch (no git), a full screenshot-by-screenshot declutter audit (Jeremy).

Last updated 2026-11-14. **All 28 steps of `UPGRADE_PLAN_V2.md` are built** (Step 28 = plan only, see below).
Holden's tests for Steps 5–28 are still to do (one combined test list in the last agent report).

## UPGRADE_PLAN_V2 status (2026-11-14)

| Step | Status | Key files |
|---|---|---|
| 1–6 | Done (1 passed; 2–4 folded into 21; 5 built; 6 already done) | |
| 7–16 | Built: start menu, keybinds, AudioManager, portraits, Your File + Briefing, leaderboard, Choice Rooms, rockets, 3D launch | `start_menu`, `Controls.gd`, `AudioManager.gd`, `Portraits.gd`, `your_file`, `mission_briefing`, `Leaderboard.gd`, `choice_room`, `rocket_model.gd`, `launch` |
| 17 | Built: tutorial card (3 steps, moving example, Space to start, "?" to see it again) | `minigame_frame.gd` |
| 18 | Built: type the part's name, part snaps onto the workshop rocket, word lists by level | `minigame_assembly.gd`, `workshop_background.gd`, `minigames.json` |
| 19 | Built: rocket panel, hammer cursor that swings, sparks, dents, nails left | `minigame_hammer.gd` |
| 20 | Built: valve wheel, filling fuel gauge, target mark | `valve_dial.gd` |
| 21 | Built: walkable ship with 5 furnished rooms, 11 stations, Bridge window + wall-screen flight log, emergencies with timers, calm tasks, day counter, skip after first trip | `flight.gd/.tscn` (ship), `flight_log.gd/.tscn` (old flight screen, now the wall screen), `events.json` flight > ship, `game_data.json` ship, `story.json` flight_ship |
| 22–23 | Built: the tablet and waypoints now work in the ship and on the planet | `Hud.gd`, `flight.gd`, `arrival.gd` |
| 24 | Built: third person on Moon/Mars (SpringArm), Venus first person on the ship | `arrival.gd` |
| 25 | Built (earlier): music states incl. tension on alerts, faster for harder levels | `audio.json` |
| 26 | Built: door and station sounds added; everything else was already wired | `flight.gd`, `arrival.gd` |
| 27 | Built: staff walk in the ship and Choice Rooms; bot crewmates on the leaderboard (for show) | `Bots.gd`, `choice_room.gd` |
| 28 | Plan only: online multiplayer not built (cut list #1, team chose pass-the-keyboard) | `MULTIPLAYER_PLAN.md` |

Checked 2026-11-14: self-check clean; every screen ran headless for Moon/Scientist, Mars/Janitor and
Venus/Student; ship trip tested (fix in time, miss, arrival); screenshots of the ship looked right.

**Polish after Step 28 (2026-11-14):** the ship is built by one shared script (`scripts/ship_builder.gd`), so
the Venus arrival now happens in the SAME ship as the flight (task spots: Science Bay, Bridge window, Comms
Room; yellow clouds outside the windows). The planet in the Bridge window has a made-in-code surface (bands
for Venus). Station labels hide while you stand on the pad. The portrait no longer covers the arrival task list.
**Web export:** `build/web`, 2026-11-14 10:19 AM.

**Note for agents:** the self-check (`--quit`) does not load every script. After changing a 3D screen, also
run that scene (or a small `-s` test script) to catch parse errors. Prefer `preload()` over a new
`class_name`: new class names are only known after the editor rescans.

## Playtest notes fixed (2026-11-14 afternoon)

- **Destination grows in the window:** its size on screen now grows steadily (3° to 32°) instead of only at the end (`game_data.json` ship > planet).
- **Landing animation:** new stage `landing` between flight and arrival (`scenes/landing.tscn`, `scripts/landing.gd`, `game_data.json` "landing", `story.json` "landing"). Moon/Mars: lander descends on its flame, dust, TOUCHDOWN. Venus: braking burn into orbit, IN ORBIT. One fact caption each (PLACEHOLDER sources). Space/Enter/click skips.
- **"You're hired" was easy to miss:** pedestal labels now hide and a big HIRED paper card with the portrait stamps onto the screen.
- **Text visibility pass (2026-11-14):** the "E: ..." prompts (Choice Rooms, ship, arrival) now sit on a dark box above the voice bar (`scripts/prompt_box.gd`); pedestal labels stand on the pedestals' front edge at a fixed size, so they never cover the wall screen; the 3D CONFIRM sign and the console waypoint never show together; launch: Scrub/Skip on their own row, the right panel scrolls so GO FOR LAUNCH stays above the voice bar, ring + hint moved clear of the caption; ship alert moved left (clear of the timer box); arrival task list moved under the hint/strip, controls in the Hud hint bar; off-screen waypoint arrows stay out of the top bar and above the voice bar (`game_data.json` hud waypoint margins).

## NASA_RESOURCES_PLAN status (2026-11-14): N1–N9 all built

| Step | What the player sees | Key files |
|---|---|---|
| N1 | (data) every resource, its use, screens, submission sentence; glossary; CML; segments | `data/nasa_resources.json` |
| N2 | Strip under the controls hint: `[x] Launch [>] Space [ ] Ground [ ] User` + CML meter (Design Lab, Review); tablet lines; report's first line "User segment: ..." | `Hud.gd`, `GameState.gd` (cml_event, reach_segment), `choice_room.gd`, `review.gd`, `debrief.gd` |
| N3 | MISSION DESIGN LAB sign; stations named by discipline; O = Office Hours hint (Design Lab) + button on Review; Review = Equipment List ("Verification: does it all add up?"); end-of-mission line on the Briefing | `choice_room.gd`, `review.gd`, `mission_briefing.gd`, `inner_voice.json` office_hours |
| N4 | Dim "won't work here" pedestals with a reason (Venus: land on the surface, ice drill; Moon: cloud camera) | `destinations.json` not_possible |
| N5 | "Your mission twin" in the report's checklist panel (picked by packed instruments) | `destinations.json` twins, `debrief.gd` |
| N6 | ConOps picture strip on the Briefing | `mission_briefing.gd` |
| N7 | Space Dictionary (G): 30 stamps unlock as you play, saved on the computer; full set = +20 score | `Hud.gd`, `GameState.gd`, glossary in `nasa_resources.json` |
| N8 | "Real teams..." line on each minigame tutorial card | `story.json` minigames real_step |
| N9 | Bridge map views on keys 1/2/3; GMAT named in the orbit station's Did you know?; CSA tip slot (hidden until a writer fills it) | `flight_map.gd`, `flight.gd`, `nasa_resources.json` csa_tip |

Also: the Design Lab now shows the "Did you know?" tips again (they were lost with the old 2D screens), after you preview.
Checked: self-check clean; every screen headless for 3 missions; CML 0→3→4, segments, twins, 30/30 stamps tested;
screenshots of Briefing, Design Lab, Review, report, Dictionary, minigame card, Bridge map. Web export 11:19 AM.

**Links found by web search (2026-11-14), writers only confirm they match the Resources tab:** CML paper
(NTRS 20150007816), Goddard Mission Design Lab, CubeSat 101 PDF, GMAT (NASA Software Catalog), CSA digital games
page; the CML official names (Cocktail Napkin, Initial Feasibility, Trade Space, Point Design); the GMAT tip source.
Tested 2026-11-14: "Redesign and fly again" keeps the design and CML, segments start over; "New mission" resets all.

Also found: Design and Develop Science Missions (NTRS 20250002492), the telescope game (science.nasa.gov Build It
Yourself: Satellite!), Mission Viz (nasa.github.io/mission-viz).

**Writers must still fill (marked PLACEHOLDER):** the VR challenge link (cited only, not in the game); glossary `source`s;
`csa_tip` text + link (needs someone to read the CSA site); twin sentences + links and `not_possible` reasons in
`destinations.json`; the three minigame `real_step_source`s.

## Older notes

- **2026-11-14: `UPGRADE_PLAN_V2.md` is now the design source.** Step 0 (read-only report) done. **Upgrade Step 1 (score) passed.** **Step 2 checked: nothing to build** (every timed thing in the live game already shows its time). **Steps 2–4 are part of Step 21's done-check:** every ship task/emergency shows a countdown on the HUD and over the station; every station works on Moon, Mars and Venus (no "Mars orbit" checks); the Bridge is a real room. **Step 5 built** (`timing.json` good_window 0.16 → 0.32), waiting for Holden's test. Step 6 already done; next is Step 7 (start menu).

- **Steps 1–10:** passed Holden's tests.
- **Steps 12–14:** passed (Holden, 2026-11-13). **Step 11:** fine for Holden; Amy's check still open. **Step 15:** Holden's full browser playthrough and Richard's video are left.
- **Decisions 2026-11-13:** rockets keep the real numbers and the rocket screen teaches why the Falcon 9 is cheap; multiplayer is pass-the-keyboard only (Steps 17–19 dropped).
- **Built 2026-11-13:** Self-check clean;
  every screen ran headless for 3 missions × 3 characters with no errors; screenshots
  checked for the workshop, suits, arrival areas and Build screen.
- **Step 16:** done (`MULTIPLAYER_PLAN.md`); pass-the-keyboard only.
- **Last web export:** `build/web`, 2026-11-13 4:08 PM (has Moon, Venus, Steps 11–14).
- **2026 rules:** criteria confirmed as Impact, Creativity, Validity, Relevance,
  Presentation. The judging guide page would not load for the agent, so a person
  should read it once.
- **Reviewer** ran on Steps 11–15 and all its fixes are applied (see below); #1, the rocket balance, was settled by the team's decision.

## Still open (most important first)

1. **Step 15:** Holden plays the whole web build (a losing and a winning round), then
   Richard records the 30-second video.
2. **The Science & Data Lead checks `STEP11_TABLES.md`**, especially Atlas V 401
   2,315 kg, Atlas V 541 4,050 kg (that is Curiosity's mass, not the rocket's limit),
   laser reflector 5 vs 77 kg, Magellan radar 154 vs 15.2 kg.
3. **Every value labelled "PLACEHOLDER: game-design choice proposed at Step 11b"**
   needs a search or the team's pass (cards, Moon/Venus limits, orbit fuel, minigame
   and flight numbers).
4. **Read the 2026 Judging and Awards Guide once** (the page didn't load for the agent).
5. **Public link for judges:** follow `HOSTING.md` (itch.io recommended); the coach
   picks the account.

**For judges and the submission form:** `HOW_TO_PLAY.md` (story, controls, how to win
each mission, the challenge's six points, NASA number examples). The Head Writer can
reuse it. If the game's numbers change, re-check its "How to win" hints.

## Decided 2026-11-13 (in AGENT_SOURCE.md)

- **Rockets:** keep the real numbers (Falcon 9 is cheapest and lifts the most) and
  teach why: a "Did you know?" on the rocket screen. The trade-off is cost and lift
  against launch timing.
- **Multiplayer:** pass-the-keyboard only (1–4 players on one computer). Steps 17–19
  are dropped.

## Built today

| Step | What | Key files |
|---|---|---|
| 11b | Real rocket names/costs/lifts, real trip days, radio delays, Moon/Venus instrument numbers; orbit fuel scaled to MRO's 1,149 kg | `game_data.json`, `destinations.json`, `story.json`, `inner_voice.json` |
| 12 | 3D workshop with 4 toy-like staff behind every minigame (rocket looks more finished each job) | `workshop_background.gd/.tscn`, `minigame_frame`, `minigames.json` workshop |
| 13 | Player's own character in a suit (helmet, backpack); landers with legs, lumpy rocks, hills, Moon stars, seismometers/drill rig appear when tasks are done; Venus consoles and window frame | `arrival.gd`, `player.gd`, `game_data.json` suit / arrival_props |
| 14 | Code-made sounds (clicks, good/bad, hits, launch, report stamp); "Did you know?" tip per Build tab; inner-voice line on each minigame's results | `autoload/Sfx.gd`, `game_data.json` sounds, `story.json` did_you_know, `inner_voice.json` minigames |
| 15 | Web export | `build/web` |

Also fixed: "Round 1 of 3.0" in Fueling; the Build screen no longer overflows at
1280×720 (tip next to Review, ripple under the dashboard and scrollable, tab "Heat");
console prints are off in the web build; student/coach names removed from the data.

## Reviewer fixes applied

- Falcon 9 lines no longer say the landing booster helps it lift; "launch windows" →
  "launch moments".
- HiRISE/CTX tips say "was planned to"; the computer tip is now accurate.
- Unsearched values are PLACEHOLDER again (honest label, still searchable).
- Rocket card says "Lift toward Mars".
- Names → role titles in the data; `run/disable_stdout.web` turns prints off in the browser.
- Workshop shadows off for browser speed; ripple panel scrolls.
- Arrival props and lander sizes moved into `game_data.json` (`arrival_props` > `kinds`, `lander_parts`).
- Workshop sounds (PLAN.md §7): a drill when a worker starts a job, and a radio beep every 11 s (based on the Apollo Quindar tones).
- Out-of-date notes fixed (base budget readme, AGENT_SOURCE orbit fuel line, lunar night note).
- Reviewer #1 (rocket balance): settled 2026-11-13. The real numbers stay, and the rocket screen teaches why the Falcon 9 is cheap.

## Rough edges (not fixed)

- Code-made sounds need a real browser test.
- The Controls hint overlaps the task panel on the arrival screen at 1280×720.
- Fixed 2026-11-13: the arrival Controls hint no longer overlaps the task panel; flight lines read naturally ("on its way to the Moon", "our radiators and heat pipes get rid of...", via `in_sentence` and `phrase` in story.json).
- Also fixed: with 1 player the report says "Build jobs average" instead of "Teamwork average"; minigame turn and score buttons wait 0.8 s, so mashing keys can't skip them (minigames.json `button_delay_seconds`).
- Still open (harmless): unused leftovers (`has_sample`, `supplies.json`, `arm.tscn`).

## The "more stuff" copy (2026-11-14)

This folder is the copy with the team's extra ideas ("Original how did we get here" is the untouched copy).
Added and checked (headless test of every screen for Moon, Mars and Venus, screenshots, web export):
- Design: Launch window station (3 dates: trip length, fuel, launch tightness), mission patch maker
  (`patch_maker.tscn`; the patch shows on the rocket's logo panel, the suit, the report and the leaderboard),
  rocket line-up (a school bus to scale by each rocket), tap a part (Inside view: click a part for its job).
- Build: Clean Room minigame (`minigame_clean.tscn`, counts in teamwork), part jobs after each Assembly word,
  "Fuel = 90% of the rocket's weight" on Fueling.
- Launch: lucky peanut jar (E), wait-or-go space weather call (wait = $6 million from the flight reserve).
- Flight: zero-g plush on the Bridge, two-way fixes (hold E proper / Q quick, the bill comes at arrival),
  Real Mission Moments after each problem, window photos and sightings (on the report), "?" crew bubbles (E).
- Planet: real gravity (Moon 0.165, Mars 0.38), footprints (stay on the Moon, fade on Mars), Mars ice
  sample that turns to gas on the way to the analyzer, the real radio delay pointed out when sending.
- 2026-11-15: every real-fact PLACEHOLDER now has a NASA link (extras, mission moments, mission twins,
  "won't work here" reasons, landing and launch captions, briefings, glossary, CML, VR challenge, CSA tip,
  orbit speeds). Corrected while checking: Atlas V 401 is 57.3 m and Atlas V 541 is 60 m tall (not 58.3 / 62.2),
  a rocket is about 85% fuel (not 90-94%), the school bus is 13.2 m (NASA: Hubble is "about the size of a
  school bus"). Still PLACEHOLDER on purpose: game-design numbers waiting for the team's pass, the laser
  reflector's mass, and the archived Life Support data (supplies.json, the old water leak).
- Self-check for this copy: use `--path "C:\Users\holde\Onedrive\Desktop\Nasa_space_apps\How did we get here + more stuff"`.

## How to resume

- Read `CLAUDE.md`, `TASKS.md`, `AGENT_SOURCE.md` (section "Step 11b").
- Self-check:
  `& "C:\Users\holde\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe" --headless --path "C:\Users\holde\onedrive\desktop\Nasa_space_apps\how-did-we-get-here-" --quit`
- Web export: `... --headless --path "<project>" --export-release "Web" "build/web/index.html"`
- Browser test: `cd build\web; python -m http.server 8000`, open http://localhost:8000
  (Ctrl+Shift+R).

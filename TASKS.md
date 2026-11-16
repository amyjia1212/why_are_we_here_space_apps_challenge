# TASKS.md: steps to finish "How Did We Get Here?"

Rewritten 2026-11-11 from `PLAN.md` section 15 (build order). `PLAN.md` wins
wherever it disagrees with `GAME_PLAN.md`. Hackathon: Nov 14–15.

- **Size:** S = under 30 min, M = 30 min to 2 hours, L = more than 2 hours.
- Each step can be built and tested alone. Tick the box when Holden says pass.
- Build Mars all the way through first, then copy the shape for Moon and Venus.
- Phase 1 stays gray and plain. No polish before Phase 3.
- The `###` headings are the **batches**. Each batch ends with one full playthrough
  (a losing and a winning round), a re-export to `build/web`, and a browser test.
- Every new made-up number is marked `"source": "PLACEHOLDER"`.
- Target `stages.order` (PLAN.md §3), reached step by step:
  `cutscene_intro, name, character_select, player_count, mission_select, rocket, orbit,
  build, review, minigame_assembly, minigame_hammer, minigame_fuel, launch, flight,
  arrival, cutscene_return, debrief`

## Phase 1: Skeleton, Mars only (before the hackathon, Nov 12–13)

### Batch 1: Start of the game and the design checks

- [x] **1. Intro cutscene in, speaker renamed, old intro removed.** S (Holden: pass, 2026-11-11)
  Put `cutscene_intro` first in `stages.order` and make it the main scene. When the
  cutscene ends it calls `go_next()`. The speaker who says "I quit!" is now "Chief
  Mission Designer". Move the old 2D `intro` scene and script to `scenes/archive/`.
  Space, Enter or a click skips the cutscene, with a small "Press Space to skip" hint
  (Holden, 2026-11-11).
  Test: press Play. The cutscene plays first, the amber name reads "Chief Mission
  Designer", and the name screen follows. Play again and press Space, then Enter, then
  click: each one jumps straight to the name screen. The rest of the game plays as
  before.

- [x] **2. Destinations: Moon, Mars, Venus (Moon and Venus locked).** M (Holden: pass, 2026-11-11)
  `data/destinations.json` gets three missions with their goal checklists (PLAN.md
  §5). Mars is playable; Moon and Venus show as locked cards. Choosing a mission is
  one screen (`mission_select`); the old `destination` screen leaves the order.
  Test: Mars can be picked and shows its checklist (land safely, drill and sample
  ice, send the data home). Moon and Venus show "locked" and can't be picked.

- [x] **3. Orbit screen and the mass-versus-rocket check.** M (Holden: pass, 2026-11-11)
  New `orbit` screen after `rocket`: 3 orbit cards for Mars, one sentence each. Each
  rocket gets a payload capacity per orbit (PLACEHOLDER). Review shows a red blocker
  when the mass is over the capacity, with a one-line reason, but the player can
  still go on.
  Test: pick the small rocket and a hard orbit with a heavy build, and Review shows a
  red mass blocker. Pick the heavy rocket, and the blocker goes away.

### Batch 2: Design screens

- [x] **4. Build screen: 7 part categories plus instruments.** L (Holden: pass, 2026-11-12)
  Structure size, solar array, battery, attitude control, thermal control,
  radio/antenna, computer (simple / better / best), plus 3–4 Mars instruments with
  the ice drill required for the goal. All numbers PLACEHOLDER. The dashboard stays
  on screen.
  Test: every category has 3 cards. Each pick changes the six dashboard rows. Leaving
  out the ice drill shows a blocker at Review.

- [x] **5. Ripple effect panel.** M (Holden: pass, 2026-11-12)
  A strip that shows the chain when a card changes, for example "Bigger camera → more
  power needed → bigger solar panels → more mass → +$ cost". Text in `story.json`.
  Test: swap a small instrument for a big one, and the strip shows the chain with the
  real changes in numbers.

### Batch 3: Build minigames

- [x] **6. Player count and three minigames as gray boxes with scoring.** L (Holden: pass, 2026-11-12)
  New `player_count` screen (1–4). New `data/minigames.json` (PLACEHOLDER, marked as
  game-design choices). Assembly (press the shown A–Z letter), Hammering (click nails
  before they fade), Fueling (drag a valve to the target angle, 3 rounds). Each lasts
  20–30 s, shows a "how to play" line and returns a 0–100 score. With more than one
  player, each player takes a turn and the screen shows every score and the team
  average. Scores go into GameState as build quality, structure strength and fuel
  loaded.
  Test: play each minigame well and badly, and see high and low scores. With 2
  players, both play and the average shows.

### Batch 4: Launch, flight, arrival, report

- [x] **7. Flight screen with map and flight log, 3 Mars events.** L (Holden: pass, 2026-11-12)
  Map (Earth left, Mars right, ship on a curve, mission clock), status tiles, a
  terminal-style log (green / amber / red), 3 events from `data/events.json` whose
  outcome depends on the design and the minigame scores, and a 1x / 4x button. Every
  bad line says why. Launch gets the go / no-go poll (PLAN.md §8) and applies
  structure strength. The walkable ship, Reroute Power, power panel, life support
  and the shadow pass move to `scenes/archive/`.
  Test: a weak design gets red log lines with reasons. A strong design gets green
  lines. 4x makes it faster.

- [x] **8. Mars arrival with 3 gray-box tasks.** L (Holden: pass, 2026-11-12)
  Third-person walk on an orange gray-box plain, starting from `player.tscn`. Walk to
  the dig spot, run the ice drill (hold a key, stop in the green zone), put the
  sample in the analyzer. No drill packed means no sample. The tasks tick the
  checklist.
  Test: with the drill, all 3 tasks tick. Without it, the drill task says why it
  can't be done.

- [x] **9. Report with score and reasons; Redesign button.** M (Holden: pass, 2026-11-12)
  Add the `cutscene_return` slot (one line of text, then moves on). The debrief shows
  the checklist, a score out of 1000 (weights in data), and 2–3 "went well / fix next
  time" lines that name a design choice. Buttons: "Redesign and fly again" (keeps the
  design) and "New mission".
  Test: a losing and a winning round both end on the right report. Redesign returns
  to the design with the old parts still picked.

## Phase 2: Hackathon day 1 (Nov 14)

### Batch 5: Moon and Venus, real numbers, workers

- [x] **10. Moon and Venus data, events and arrival scenes.** L (Holden: pass, 2026-11-12)
  Unlock both. Moon: lunar night, 3 seismometers, gray plain. Venus: nobody lands,
  balloon and storms, inside the orbiting ship.
- [ ] **11. Amy's real numbers replace placeholders.** M (built 2026-11-13 with the recommended answers; Holden: fine, 2026-11-13; rockets: keep real and teach it, Holden 2026-11-13; still waiting for Amy's check of `STEP11_TABLES.md`)
  Show each table (value, real number, source link) first, then put them in.
- [x] **12. Minigame background scene with workers.** M (Holden: pass, 2026-11-13)
  Toy-like staff from the cutscene setting up the rocket behind each minigame.

## Phase 3: Hackathon day 2 (Nov 15). Polish until 2 pm, then stop

### Batch 6: Polish and submit

- [x] **13. Art pass on the three arrival areas and the suits.** L (Holden: pass, 2026-11-13)
- [x] **14. Sounds, "Did you know?" tips, inner-voice lines.** M (Holden: pass, 2026-11-13)
- [ ] **15. Web export, full playthrough, record the 30-second video.** M (web export done 2026-11-13; Holden plays it through; Richard records the video)
  After this, single-player is safe to submit.

## Phase 4: True multiplayer (last, only after step 15 passes)

### Batch 7: Online room

- [x] **16. Plan the connection.** S (plan in `MULTIPLAYER_PLAN.md`; Holden 2026-11-13: pass-the-keyboard only) (read and plan only; ask the coach; ask before
  downloading anything)
- [~] **DROPPED 2026-11-13 (pass-the-keyboard only).** **17. Room code: host and join, player list.** L
- [~] **DROPPED 2026-11-13 (pass-the-keyboard only).** **18. Send the shared mission state; run minigames on every screen; collect and
  average scores.** L
- [~] **DROPPED 2026-11-13 (pass-the-keyboard only).** **19. Test with 2, then 4 computers.** M
  If it is not solid by Sunday noon, ship the pass-the-keyboard fallback.

## If time runs short

Cut in this order: online multiplayer (use pass-the-keyboard) → team vote → 3D
spacecraft model (use 2D) → hammering minigame → Venus arrival scene (end Venus at
the flight log) → Moon arrival scene.

**Never cut:** the six resources, the ripple effect, the rocket-and-orbit check, the
flight log, the report with reasons.

## Other open items

- [x] **Confirm the 2026 rules (Nov 13).** S. (2026-11-13: the criteria are Impact, Creativity, Validity, Relevance, Presentation; The judging guide page did not load for the agent, so a person should read it once.) Read the 2026 Space Apps guide. Confirm
  the judging criteria names and what a submission needs.
- [ ] **Public link for judges.** S. Host the newest tested `build/web`. Where to host
  it is still open.
- [ ] **Toy-like character scenes (old 19c).** Built in Kaleb's template; waiting for
  a test. Gets checked during step 1.
- [ ] **Nice to have: team vote** on one design choice before the minigames
  (PLAN.md §7).

## Done in Kaleb's template (before 2026-11-11)

A1 GameState with `to_dict()` / `from_dict()`, A2 StageManager, A3 name screen, A4
three characters and `levels.json`, A5 destination screen, A6 mission goals, A7
rocket cards, A8 timed-press scene, A9 launch with 3 timed presses, 7a–7g real NASA
data for the Mars orbiter parts, 8 balance review, 9 full playthrough and browser
test, 19a intro cutscene greybox, 19b cutscene animation (27.5 s, 11 shots).

## Dropped on 2026-11-11 (replaced by PLAN.md)

Old A10–A22 (Life Support room, crew supply meters, food / air tasks, water leak,
flight leg in the walk, orbit burn plus shadow pass, science pass, checkpoints,
three report buttons), and old 5a–5c, 6, 13, 15, 16 (ship windows, Bridge wall
screen, shadow-pass alarm, ship stations). They were built for the walkable ship,
which is archived. Old 12 (remove leftovers) and 14 (student guide) can come back
in Phase 3 if there is time.

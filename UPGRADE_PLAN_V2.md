# UPGRADE PLAN V2: "How Did We Get Here?"

Written Nov 13, 2026 by Fable, from the team's playtest notes and three reference videos.
Engine: Godot 4, web export. Hackathon: Nov 14–15. Feature freeze: **Sunday Nov 15, 2:00 pm**.

**How to use this file.** Put it in the game folder next to `FINAL GAME PLAN`. Unzip `reference_stills.zip` into the reference folder. Then paste the kickoff prompt (section 1) into Claude Code, started inside the game folder.

**Which file wins.** This file wins over `FINAL GAME PLAN` and `GAME_PLAN.md` wherever they disagree. The rules in `CLAUDE.md` still apply (numbers in data files, PLACEHOLDER marking, PLAN / DO / SELF-CHECK / MY TEST / WAIT). Where this plan says **DEFAULT**, build it that way and list it in the report so the team can change it.

**Be honest about time.** This list is bigger than one weekend. The phases are ordered so the game works at the end of every phase. Stop wherever you are at the freeze time and submit that.

---

## 1. Kickoff prompt (paste this into Claude Code)

```
Read these files in order: CLAUDE.md, AGENT_SOURCE.md, FINAL GAME PLAN, then UPGRADE_PLAN_V2.md.
UPGRADE_PLAN_V2.md wins wherever they disagree.

Look at every image in the reference folder (the ref1_, ref2_, ref3_ stills). You cannot
watch the .mov files, so section 3 of the plan describes them in words. If ffmpeg is already
installed you may pull more frames from the .mov files. Do not install anything without asking.

Before changing anything: make a git branch called upgrade-v2 and commit the current game.

Start with Step 0 of the plan. Step 0 is read-only: change no files. Give me the Step 0
report, then WAIT for me.

After that, do ONE step at a time, in the plan's order. For each step use
PLAN / DO / SELF-CHECK / MY TEST / WAIT. Commit after every step that I approve.
Never start the next step until I say so. If a step is bigger than you expected, tell me
and offer a smaller version instead of half-finishing it.
```

## 2. What changes from the old plan

| Topic | Old plan (Nov 11) | New decision (Nov 13) |
|---|---|---|
| First screen | Intro cutscene | A start menu comes first |
| Order of choices | Rocket could come before the mission | **Planet first.** Then briefing, then rocket |
| Picking things | 2D card menus | 3D rooms you walk around in (the "Choice Room") |
| Launch | Restyled existing scene | Rebuilt in 3D to match reference 1 |
| Flight | Automatic, log only, ship archived | **Walkable ship is back** (reference 3), with more tasks. The flight log moves to a screen on the Bridge |
| Tab key | Raise arm (wrist dashboard) | Opens the mission tablet: mini map + all six resources |
| Planet camera | Third person (planned) | Third person (must actually be built) |
| New | | Sound, keybinds, portraits, briefing pages, leaderboard, waypoints, bots |

Record each row in `AGENT_SOURCE.md` as a team decision dated Nov 13, 2026.

## 3. The three references

The videos are in the reference folder. The stills are named `ref1_…`, `ref2_…`, `ref3_…`. Take the layout and the feel from them. Keep our own art style (`MASTER ART DIRECTION`) and our own theme file.

**Reference 1: the launch (Ms. Libby's "Mission Orbit" game).** We want ours almost exactly like this.

- Screen: a big 3D view on the left (about 70%), a panel on the right.
- Top-left tiles: MISSION TIME (T-00:20), ALTITUDE, SPEED, STATUS (ON PAD → ASCENT → IN ORBIT → HOLD → SEPARATED).
- Header chips: rocket name with its success rate, and the launch site. Buttons: "Scrub – back to build" and "Skip".
- Right panel: GO / NO-GO POLL (rocket, mass vs capacity, target orbit, design check, space weather), each with a green GO or amber CAUTION badge. One warning line under it. A FLIGHT TIMELINE of chips that turn green one by one. A big amber GO FOR LAUNCH button.
- The scene: the rocket on a pad at dawn next to a white tower, two tall masts, the sea, a low sun, soft floating dust.
- Countdown: huge numbers in the middle. A timed press near zero shows PERFECT or GOOD in floating text. Smoke builds at the base.
- Liftoff: the camera follows the rocket up. A caption box in the bottom-left has an amber title and one or two sentences of real science.
- Climb: the rocket tips over, the sky goes from orange to purple to black. Round buttons appear with a ring that shrinks ("Tap when the ring closes"): THROTTLE DOWN, STAGE, FAIRING, RELEASE.
- Surprises: "ENGINE OUT!" with a REBALANCE ring. If you miss, "Computer took over" and you lose something. Later a "DEBRIS ALERT" with two buttons, WAIT or RELEASE NOW, and a timer bar.
- Space: the first stage drops away, the nose cone splits, Earth's curve and thin blue air show below. The spacecraft separates, then "HOLD TO DETUMBLE" (hold until the spin reaches zero), then STABLE.

**Reference 2: building the rocket (same game).** The middle of this screen is what goes on our wall screen.

- Middle: a 3D model you can spin, with three tabs: 3D view, Camera view, **Inside**. Inside makes the shell see-through so you can see the battery, computer, wheels, tanks and instruments.
- The part you are choosing glows, and a small label points at it ("Launch vehicle: Vega-C").
- Top: six resource tiles with bars (mass, power, budget, data, comms, lifetime) and goal chips with ticks.
- Right: the option cards for the current category.
- Bottom: the RIPPLE EFFECT strip (old value → new value for everything the choice changed), a predicted score, and red "mission blocker" messages.
- Left: the full loadout list. **We do not copy this part.** It is why the screen feels crowded.

**Reference 3: inside the ship (our own old scene).** This is the base for the flight. Upgrade it.

- First person. A gray hallway with rooms: BRIDGE, SCIENCE ROOM, POWER, COMMS ROOM, LIFE SUPPORT. Orange 3D signs over the doors.
- Stations are glowing cyan floor pads with floating labels (Air, Water, Food).
- A red alert at the top ("WATER LEAK! Go to the Water station"). The inner-voice box at the bottom. A controls line at the top. The arm with the wrist button.
- Problems to fix: some stations say "works in Mars orbit", the Bridge goes nowhere, no timer is shown, the rooms are empty gray boxes.

## 4. New player flow

```
Start menu
 → Intro cutscene (exists)
 → Name
 → Character Room (3D) → "You're hired" moment
 → How many players
 → Your File (who you are, what the job is)
 → Mission Room (3D): Moon / Mars / Venus        ← planet first
 → Mission Briefing (what it is for, what success needs, what you have)
 → Design Rooms (3D): rocket → orbit → spacecraft parts → instruments
 → Review
 → Build minigames: Assembly → Hammering → Fueling
 → Launch (3D, like reference 1)
 → Flight (walk inside the ship, tasks and emergencies)
 → Arrival (third person on the planet; Venus stays on the ship)
 → Return cutscene (slot)
 → Mission report → Leaderboard
 → Redesign and fly again / New mission
```

Update `stages.order` in `data/game_data.json` to match.

---

## 5. Build steps

### Step 0: Look before you touch (read-only)

Change nothing. Report:

1. The scene list and the current `stages.order`.
2. What is in the reference folder.
3. For each bug in Phase 1: the file and line that causes it, and the fix you suggest.
4. Which camera each 3D scene uses now (first or third person).
5. Whether any sound files or an audio manager exist.
6. Anything in this plan that does not match the real project.

### Phase 1: Fix what is broken

| Step | Fix | Done when |
|---|---|---|
| 1 | **Score is always 399/1000.** Find why the parts of the score do not change. Show the five parts on the report screen | Two different playthroughs give two different scores, and the parts add up to the total |
| 2 | **No timer on tasks.** Every timed task shows a countdown on the HUD and above the station | You can always see how long is left |
| 3 | **Stations only work for Mars.** Stations read the current mission from `data/destinations.json`. Remove every "works in Mars orbit" check | Every station does something on Moon, Mars and Venus |
| 4 | **Bridge goes nowhere.** For now, close the Bridge door with a "sealed" sign. Step 21 builds the real room | No dead-end hallway |
| 5 | **Launch "GOOD" is too narrow.** Move the timing windows to the data file and widen GOOD. **DEFAULT:** GOOD is twice as wide as now, PERFECT stays the same | A normal player gets GOOD most of the time |
| 6 | **Planet first.** Reorder the stages so the mission is chosen before the rocket | The game asks "where are we going?" first |

### Phase 2: The front door

**Step 7: Start menu.** A 3D backdrop (the rocket on the pad at dawn, slow camera). The title, two or three lines of story ("The chief mission designer just quit. The General needs someone. Anyone."), and buttons: Start, Leaderboard, Controls, Settings (volume sliders), Credits. Browsers block sound until the first click, so start the music when Start is pressed.

**Step 8: Keybinds.** Put every action in Godot's Input Map so nothing is hard-coded. Add a Controls screen and a small hint bar that changes with the scene.

| Key | Action |
|---|---|
| W A S D / arrows | Walk |
| Space | Jump · timed press in the launch |
| Shift | Run |
| Mouse | Look |
| E | Use / pick up |
| 1, 2, 3 | Preview option 1, 2 or 3 in a Choice Room |
| Enter | Confirm |
| Q | Go back one choice |
| Tab | Mission tablet (mini map + resources) |
| H | Show controls |
| M | Mute |
| F | Full screen |
| Esc | Pause / free the mouse |

**Step 9: Sound system.** One autoload, `AudioManager`, with buses for Music, SFX and Voice. Functions: `play_sfx(name)`, `play_music(state)` with a one-second crossfade, `talk(character, text)`. Names map to files in `data/audio.json`. A missing file must not crash: play a simple generated beep and mark it PLACEHOLDER. Add click and hover sounds to the theme's buttons now. **From this step on, every new step adds its own sounds.**

**Step 10: Portraits.** Take a picture of each character model (scientist, janitor, student, General) with a SubViewport and save them as images. Use them in dialogue boxes, the HUD corner, Your File and the leaderboard.

**Step 11: Your File and Mission Briefing.** Two clean pages styled like a paper file.

- *Your File* (after the character is chosen): portrait, name, who you are, your difficulty, one line on what the job is, and the six resources in one short line each.
- *Mission Briefing* (after the mission is chosen): what the mission is for, why it matters, the success checklist, what you start with (budget and the other limits from the data file), the main trade-off, and the real missions it is based on. The General reads the first line.

**Step 12: Leaderboard.** Save the top 10 runs to `user://leaderboard.json`: name, character, mission, score, date. Show it from the start menu and after the report, with the new run highlighted. It is saved on that one computer only. An online board waits for multiplayer.

### Phase 3: The Choice Room (3D picking)

**Step 13: Build one reusable room.** `scenes/choice_room.tscn` takes a category from the data files and builds itself. Every selection in the game uses it.

- The player walks and jumps around a small room. **DEFAULT:** first person, using the existing `player.tscn`.
- **Three pedestals**, one per option. Each holds a 3D model of the option with its name and cost floating above.
- Walk up and press E (or click, or press 1/2/3) to **preview**. Nothing is final yet.
- **The wall screen** (a SubViewport on a big wall panel) shows the middle of reference 2:
  - the rocket and spacecraft model, slowly turning, with the previewed part glowing and labeled;
  - tabs for Outside and Inside. It switches to Inside by itself when the category is inside the spacecraft (battery, computer, thermal, instruments);
  - the three option cards, with the previewed one lit;
  - the six resource tiles showing **before → after** for the previewed option;
  - the ripple effect strip and any red blockers.
- **A CONFIRM console** in the middle of the room. Press E on it (or Enter) to lock the choice. A sound plays, the model on the wall snaps the part on, and the room loads the next category. A strip on the wall shows progress ("Battery · 4 of 10").
- Q goes back one choice. Instruments allow more than one pick: pedestals switch on and off.
- Keep it uncluttered: the wall shows only those five things. The old left-hand list is not used.

Done when: the rocket choice works in the room from start to finish and changes the dashboard.

**Step 14: Use the room everywhere.**

- **Character Room:** the three character models stand on the pedestals. The wall shows the name, difficulty and a sample of the inner voice. After Confirm, play the **"You're hired" moment** (about 5 seconds): the camera swings to the chosen character, the General says one line, a name tag stamps on with a sound. From then on the player is that character.
- **Mission Room:** three planet globes. The wall shows the goal and the trip time.
- **Design Rooms:** rocket, orbit, the seven part categories, instruments.
- Replace the old 2D pick screens. Keep the Review screen, but tidy it: one line per check, green or red.

**Step 15: A better rocket.** The team's words: "goofy" and "ugly". Rebuild it from clean low-poly parts: engine bells, first stage, a ring between stages, second stage, nose cone that can split, a stripe and a mission logo panel. The small, medium and heavy rockets must look clearly different. One scene per rocket so the Art Designer can swap in his own models later. Give the spacecraft an **inside**: battery, computer, tanks, wheels, antenna, each instrument, so the Inside view has something to show. The same models are used on the wall screen, the start menu, the minigame backgrounds and the launch.

### Phase 4: The launch, like reference 1

**Step 16: Rebuild the launch in 3D.** Follow the reference 1 description in section 3 beat by beat, using the player's own rocket.

1. Pad at dawn with the go / no-go panel. GO FOR LAUNCH starts it. Scrub goes back to design.
2. Countdown from 10 with big numbers and the ignition press.
3. Liftoff with smoke, camera follow, and a science caption.
4. Climb: sky color change, the rocket tips over, ring prompts for throttle down, stage separation and fairing.
5. One surprise per launch from `data/events.json`. How bad it is depends on the Hammering score (structure strength) and Assembly score (build quality).
6. Stage drop, nose cone split, Earth's curve.
7. The burn toward the Moon, Mars or Venus, then release, hold to detumble, STABLE.
8. Fade into the ship.

Every timing window is in data. Skip works after the first launch. Every caption is a real fact with a source, or marked PLACEHOLDER for the Science & Data Lead.

### Phase 5: Better minigames

**Step 17: Shared frame for all minigames.** Each one gets: a tutorial card (three short steps, a tiny moving example, "Press Space to start", shown the first time, with a "?" button to see it again), a visible timer, a themed 3D background of workers preparing the rocket, and sounds.

**Step 18: Assembly (typing) makes sense now.** Type the **name of the part** being bolted on (FIN, TANK, ANTENNA, SOLAR PANEL). Each finished word snaps that part onto the rocket in the background. Harder characters get longer words and less time: Scientist short, Janitor medium, Student long. Word lists and times in `data/minigames.json`.

**Step 19: Hammering looks like hammering.** Nails sit on a real rocket panel. The cursor is a hammer that swings. A hit sinks the nail with sparks and a clank; a miss dents the panel. Bigger, clearer targets and a count of nails left.

**Step 20: Fueling polish.** A proper valve wheel, a fuel gauge that fills, and a clear target mark.

### Phase 6: The flight, inside the ship

**Step 21: Bring the ship back and make it worth walking.** Start from the scene in reference 3.

- **Looks:** warm white walls, navy floor, cyan and orange accents, ceiling lights, windows. Each room has furniture that shows what it is for. No bare gray boxes.
- **The Bridge is a real room:** pilot seats, a big window where the destination slowly grows, and a wall screen with the **flight log** and the trip map.
- **More to do.** At least two things per room, all driven by data:

| Room | Tasks |
|---|---|
| Life Support | Patch the water leak · swap the air filter · hand out food |
| Power | Reset a breaker · turn the solar panels toward the Sun |
| Comms | Aim the dish at Earth · send the data packets |
| Science | Calibrate the key instrument · check the samples |
| Bridge | Course-correction burn · solar-flare warning (get everyone to the shielded room) |

- **Emergencies** come from `data/events.json`, 3 to 5 per trip. How hard each one is depends on the player's design (a small battery makes the power problem worse). Each one has an alert, a visible timer, and a reason in the flight log.
- The trip lasts about three minutes with a day counter. After the first trip, a "skip to arrival" button appears.
- The Venus arrival scene uses this same ship.

**Step 22: Mission tablet (Tab).** Hold or press Tab anywhere in 3D. It shows a top-down mini map of the area (you, the rooms or landmarks, open tasks, emergencies in red), the six resources, the current goal, and any running timers. In 2D screens Tab shows the resources only. The arm can still lift as the animation.

**Step 23: Waypoints.** Every open problem gets a marker floating over it with the distance. When it is off screen, an arrow on the edge of the screen points the way. With more than one, show the most urgent.

### Phase 7: On the planet

**Step 24: Third person.** On the Moon and Mars, the camera sits behind the character in the suit (a SpringArm3D so it does not go through rocks). Keep walk, run, jump, E, Tab and waypoints working. Make sure every task works for its own mission.

### Phase 8: Sound pass

**Step 25: Music for every situation.** States: menu, calm (walking and choosing), build (minigames), tension (emergencies), launch, space, one per planet, win, fail. The music changes by itself: calm when walking, tension the moment an alert starts, back to calm when it is fixed. **DEFAULT for difficulty:** the tension track plays a little faster and adds a drum layer for the Janitor, and more for the Student.

**Step 26: Fill every gap.** Footsteps, doors, pickups, station sounds, alarms, rocket rumble, countdown beeps, PERFECT / GOOD / MISS, typing clicks, hammer hits, valve turns, confirm and cancel. **Voices:** each character "talks" in short beeps with its own pitch while the text types out. No recorded voices (see section 7).

### Phase 9: Other people (lowest priority)

**Step 27: Bots.** Toy-like staff walk simple routes in the rooms and the ship, wave, and run during alerts. In a solo game, three bot crewmates appear with names and show scores on the scoreboard. **DEFAULT:** bot scores are for show and do not change the mission result.

**Step 28: Multiplayer on different computers.** Unchanged from `FINAL GAME PLAN` section 7: plan first, room codes, share the one `GameState` dictionary, pass-the-keyboard as the fallback.

---

## 6. If time runs short

**Cut in this order:** online multiplayer → bots → third-person camera on the planet → Design Rooms for the part categories (keep the 3D room for character, mission and rocket; show the rest on the wall-screen layout as a flat screen) → launch surprises → extra ship tasks → difficulty music layers.

**Never cut:** the Phase 1 fixes, planet first, the six resources, the ripple effect, the rocket-and-orbit check, the report with reasons, the start menu, basic sound.

**Freeze at 2:00 pm Sunday.** After that: web export, one full playthrough per mission, the 30-second video, the submission form.

## 7. Rules that affect this work

- **No student voices, names or faces.** Use beep-talk for voices. Use made-up names in the video and on any leaderboard that is shown.
- **Sound and music must be free to use** (CC0 or made by the team). Claude Code asks before downloading anything. Write every sound's source in `AGENT_SOURCE.md` so the Head Writer can list it in References.
- **Credit Mission Orbit** (Ms. Libby's game) in References as the inspiration for the launch and build screens. Rebuild in Godot; copy no code or art from it.
- **Real facts need sources.** Captions, tips and numbers are real with a link, or marked PLACEHOLDER.
- **It runs in a browser.** Keep models low-poly, one SubViewport for the wall screen, and test the web export at the end of each phase.

## 8. Every note, and where it is handled

| Note | Step |
|---|---|
| Start screen with name, context, start button | 7 |
| Sound effects and voices for everything | 9, 26 |
| Different music for different situations and difficulties | 25 |
| Keybinds / shortcuts | 8 |
| Pictures for scientist / janitor / student | 10 |
| Character selection shows each model; click to become them | 14 |
| A small thing after selecting the character | 14 |
| Page before packing: name, who you are, mission, budget | 11 |
| After the mission: what it is for and what it needs | 11 |
| Third person on the planet | 24 |
| Score leaderboard | 12 |
| Selections as a 3D room: walk, jump, 3 options, wall screen, confirm, dashboard change | 13, 14 |
| Wall screen shows the middle of reference 2; see changes to the rocket | 13, 15 |
| Multiplayer on different computers | 28 |
| Bots / NPCs walking around, also in solo | 27 |
| 3D room to pick the rocket | 14 |
| Rocket flying cutscene; launch like reference 1; 3D modeled | 16 |
| Better rocket design; show inside parts | 15 |
| Packing UI is cluttered | 13, 14 |
| Better minigame graphics, backgrounds, mini tutorials | 17–20 |
| Typing minigame has no connection; make it harder | 18 |
| Better UI for nails | 19 |
| Launch "good" should be wider | 5 |
| Tab shows a mini map with mass, budget and the rest | 22 |
| Waypoint / arrow to every issue | 23 |
| Choose the planet first | 6 |
| Can't see the timer for tasks | 2 |
| Some stations only work for Mars | 3 |
| Bridge goes nowhere | 4, 21 |
| Always 399/1000 | 1 |
| Flight like reference 3, with more to interact with, walking inside the rocket | 21 |

## 9. Questions for the team

1. Choice Rooms and the ship are first person and the planet is third person. Is that what you want, or third person everywhere?
2. Ten Design Rooms in a row is a lot of walking. Is 1/2/3 + Enter enough of a shortcut, or should some categories share a room?
3. Who finds the music and sound files, and from where?
4. Should bot scores count toward the team average?

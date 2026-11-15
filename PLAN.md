# FINAL GAME PLAN: "How Did We Get Here?" (student team version)

Written Nov 11, 2026 by Fable, from the team's choices. Engine: Godot 4, web export.
Challenge: NASA Space Apps 2026, **Space Mission Design Game**. Hackathon: Nov 14–15.

**How to use this file.** Put it in the game folder next to `GAME_PLAN.md`. This file wins wherever the two disagree. The rules in `CLAUDE.md` still apply (numbers in data files, PLACEHOLDER marking, PLAN / DO / SELF-CHECK / MY TEST / WAIT). Where this plan says **DEFAULT**, build it that way and list it in the report so the team can change it later.

---

## 1. The game in one paragraph

The chief mission designer quits. The General points at you: an assistant scientist, a janitor, or a lost student. You pick a mission (Moon, Mars or Venus), design the spacecraft against six limited resources, then help build it in three hands-on minigames. The rocket launches and flies by itself while a live flight log shows how your choices play out. At the destination you walk around in 3D and do the science. The game ends with a report that explains why the mission went the way it did, and lets you redesign and try again.

**Pillars**

1. Every design choice has a cost, and you see the cost right away (the ripple effect).
2. How well you build matters (minigame scores change the mission).
3. Real NASA numbers set the limits.
4. The report explains *why*, not just pass or fail.

## 2. Decisions locked on Nov 11

| Topic | Decision |
|---|---|
| Intro | Use the 3D cutscene already in the repo (`scenes/cutscene_intro.tscn`, 11 shots, about 27 s), then name entry |
| Who quits | Always "chief mission designer". Change the cutscene speaker name from "Commander" |
| Destinations | Moon, Mars, Venus. These replace Mars orbit, the three Mars sites and Europa |
| Moon goal | Moonquake network: place 3 seismometers |
| Mars goal | Collect ice data |
| Venus goal | Study storms from orbit and with a cloud balloon. Nobody lands |
| Build order | Pick parts, rocket and orbit first. Then the three minigames |
| Minigame 1 | Assembly: press the shown letter key fast (A–Z only, no symbols) |
| Minigame 2 | Fueling: match the target angle |
| Minigame 3 | Hammering: hit nails that pop up at random spots |
| Minigame mood | Building and preparing. Workers set up the rocket in the background |
| Flight | Automatic. Flight log only, no in-flight challenges |
| At the destination | 3D walk-around with tasks. More minigames come later |
| Return to Earth | The team makes the cutscene later. This plan leaves a slot |
| Multiplayer | Amy's version: every player plays each minigame, scores are averaged. True online multiplayer (each player on their own computer), built last |
| Art | Toy-like cast in the cutscene and at NASA. Same characters in PEAK-style suits on the planets |

## 3. Player flow

```
Intro cutscene (3D, exists)
 → Name
 → Who are you? (difficulty)
 → How many players? (1–4)
 → Choose a mission (Moon / Mars / Venus)
 → DESIGN: launch vehicle → orbit → spacecraft parts → science instruments
 → Review: "Does it all add up?"
 → BUILD: Assembly → Hammering → Fueling
 → Launch (go / no-go check, timed presses, then autopilot)
 → Flight (automatic, live flight log)
 → Arrival (3D walk-around tasks)
 → Return to Earth cutscene (slot)
 → Mission report
 → Redesign and fly again / New mission
```

New `stages.order` in `data/game_data.json`:

`cutscene_intro, name, character_select, player_count, mission_select, rocket, orbit, build, review, minigame_assembly, minigame_hammer, minigame_fuel, launch, flight, arrival, cutscene_return, debrief`

## 4. Characters and difficulty

The inner voice only knows what its character knows. Limits and scoring are the same for everyone; only the help changes.

| Character | Level | Inner voice |
|---|---|---|
| Assistant Scientist | Easy | Gives clear hints with real terms ("That camera needs 40 W. Check your solar panels.") |
| Janitor | Medium | Half-remembered hints from overhearing scientists ("I heard them say big cameras are hungry...") |
| Lost Student | Hard | No hints. Only sci-fi guesses that are funny but not useful |

The inner voice must never say anything false. On Hard it stays vague instead of wrong.

## 5. The three missions

Each mission is one entry in `data/destinations.json` with its own goal checklist, allowed parts, orbit options, flight events and arrival scene.

| | Moon | Mars | Venus |
|---|---|---|---|
| Goal | Build a moonquake network | Find and measure ice under the soil | Study the storms and clouds |
| Success checklist | Land safely · place 3 seismometers · send quake data home through one lunar night | Land safely · drill and sample ice · send the data home | Reach orbit · release a cloud balloon · map the storms |
| Key instrument | Seismometer | Ice drill + sampler | Cloud camera + balloon probe |
| Main trade-off | Lunar night is about 14 Earth days with no sunlight, so batteries and heaters cost mass | Far from Earth: weak signal, less sunlight, heavy landing gear | Extreme heat near the planet and thick clouds: radar sees through but costs power |
| Arrival scene | Walk on the surface | Walk on the surface | Walk inside the orbiting ship |
| Real missions to cite | Apollo seismic experiments, Artemis | Phoenix lander, Mars Reconnaissance Orbiter | Magellan, Akatsuki, the Vega balloons, DAVINCI |

**Why nobody lands on Venus:** the surface is hot enough to melt lead and the air pressure crushes spacecraft. Landers have only lasted about two hours. The game says this out loud. It is a good teaching moment, and it keeps us valid.

**DEFAULT:** Moon and Mars carry a crew on a lander; Venus has a crew ship in orbit. These are game-design choices, written as such in the data file.

## 6. DESIGN stage (the challenge's main ask)

Model this on the team's "Mission Orbit" reference video. One screen per category, cards to pick from, the dashboard always visible.

**6a. Six resources, always on screen** (the dashboard already exists):

| Resource | Meaning in simple words |
|---|---|
| Budget | Money. Every part and the rocket cost some |
| Mass | How heavy the spacecraft is. The rocket has a lifting limit |
| Power | Electricity made by panels versus used by parts |
| Communications | How fast data can be sent to Earth |
| Data | How much the instruments make each day |
| Mission lifetime | How long the mission must and can last |

**6b. Choices, in order**

1. **Launch vehicle** (exists as `rocket`): 3 real rockets, small / medium / heavy. Each has a cost and a payload capacity.
2. **Orbit** (new screen): 3 options per mission. Low orbit = sharper science and more fuel to get there. High orbit = wider view, less detail, easier to reach. Third option is mission-specific (for example a polar orbit). The card explains each in one sentence.
3. **Spacecraft parts** (grow from 3 to 7 categories): structure size, solar array, battery, attitude control (pointing), thermal control, radio/antenna, computer. Three cards each: simple, better, best.
4. **Science instruments (payload)**: 3–4 per mission. Each has mass, power, cost, data per day and science value. The mission's key instrument is required for the goal.

**6c. Ripple effect panel.** When the player changes a card, a strip shows the chain: "Bigger camera → more power needed → bigger solar panels → more mass → +$ cost". This is the most important teaching feature. Build it before anything fancy.

**6d. Checks at Review.** Mass must fit the rocket's capacity for the chosen orbit. Power made must cover power used. Data per day must fit the downlink. Budget must not go over. Lifetime must reach the goal. A failed check shows as a **blocker** in red, with a one-line reason. The player can still launch with blockers and see what happens. Failing teaches.

**6e. "Did you know?" tips.** One short real fact per category, from `data/story.json`.

**DEFAULT:** the spacecraft picture is a simple 3D model that changes as parts change (a box, panels, a dish). If time is short, use a 2D picture.

## 7. BUILD stage: three minigames

Each minigame lasts about 20–30 seconds, shows a quick "how to play" line, and gives a score from 0 to 100. Behind the play area, a looping background scene shows workers (the toy-like staff from the cutscene) setting up the rocket: carrying parts, tightening bolts, rolling fuel hoses. Sounds: clanks, drills, radio chatter. Reuse the war-room models and materials.

| # | Minigame | How it plays | Score becomes |
|---|---|---|---|
| 1 | **Assembly** | A rocket part and a random letter (A–Z) appear. Press that letter. Each correct press snaps the part on and shows the next. A wrong key costs half a second. Place as many parts as you can before the timer ends | **Build quality** |
| 2 | **Hammering** | Nails pop up at random places. Click each one before it fades. Missed nails stay loose | **Structure strength** |
| 3 | **Fueling** | A target angle appears ("turn the valve 254° counterclockwise"). Drag the valve handle around the circle and let go. Three rounds. Closer = more points | **Fuel loaded** |

**What the scores do** (all numbers in `data/minigames.json`, marked as game-design choices):

- **Build quality** changes how much damage flight surprises do. High quality: small problems fix themselves. Low quality: a small problem costs reserve money or data.
- **Structure strength** matters at launch. Low strength means something shakes loose (an antenna or panel works at reduced power).
- **Fuel loaded** sets the fuel margin for entering orbit or landing. Low fuel means a worse orbit than planned or a rougher landing.

A low score never ends the game on the spot. It shows up later in the flight log and the report, with the reason.

**Team play.** Each player takes a turn at each minigame, and the scores are averaged. The screen shows every player's score and the team average.

**True multiplayer, built last (team decision, Nov 11).** Up to 4 players, each on their own computer, join one mission with a room code. Everyone plays each minigame at the same time on their own screen, then all screens show every score and the team average. One player (the host) makes the design choices; the others see them live.

Rules so this stays possible:

- Finish and test the whole single-player game first. Multiplayer is the last phase.
- Keep all mission state in the one `GameState` dictionary (`to_dict()` / `from_dict()` already exist). Multiplayer then only has to send that dictionary and the minigame scores.
- Minigames report one number (0–100) when they end. Nothing inside a minigame is synced.
- A game running in a browser cannot host other players by itself, so online play needs a small relay server. Step 1 of the multiplayer phase is read-and-plan only: choose how to connect (ask the coach), and ask before downloading anything.
- **DEFAULT fallback:** if online play is not working by Sunday noon, ship pass-the-keyboard turns on one computer (same averaging) so the game still supports 4 players.

**Nice to have:** before the minigames, the team votes on one design choice where they disagree. This shows negotiation, which the challenge rewards.

## 8. Launch

Keep what the repo has, restyled like the reference video.

1. **Go / no-go poll:** a short list (rocket, mass versus capacity, target orbit, design blockers, weather), each green or amber.
2. **Countdown with 2–3 timed presses** (the existing `timed_press` scene): ignition, throttle down, stage separation.
3. Then the rocket flies itself. Nothing is steerable.

Structure strength is applied here.

## 9. Flight: automatic, with a live flight log

Model this on the team's "travel and log" reference video. The old walkable ship and the Reroute Power minigame are not used; move them to `scenes/archive/`.

- **Map:** Earth on the left, the destination on the right, the ship moving along a curve. A mission clock counts days.
- **Status tiles:** phase, signal delay, power made / used, cash reserve, science data returned.
- **Flight log:** lines print one by one like a terminal. Green = fine, amber = warning, red = loss.
- **Events** come from `data/events.json`, 3–5 per flight, picked by mission. The outcome of each depends on the player's design and minigame scores. Examples:
  - Solar flare: fine with good shielding; otherwise the computer resets and a day of data is lost.
  - Dust on the panels (Mars): fine with a power margin; otherwise an instrument is switched off.
  - Orbit insertion burn: fine with enough fuel; otherwise a worse orbit.
  - Lunar night (Moon): fine with enough battery and heaters; otherwise a seismometer freezes.
- Every log line that hurts says why: "Radio too weak for this distance. Data rate cut in half."
- A **speed-up button** (1x / 4x) so repeat players do not wait.

## 10. Arrival: 3D walk-around

Third-person camera, the same character in a PEAK-style suit. One small handcrafted area per mission with 3 task spots, each marked with a glowing accent color. Fable picked these first tasks; the team adds minigames later.

| Mission | Area | Tasks |
|---|---|---|
| Moon | Gray plain with craters, black sky, no fog, Earth overhead | Carry and place 3 seismometers far apart · point the antenna at Earth · watch the first quake wiggle on the screen |
| Mars | Orange plain with rocks and soft haze | Walk to the dig spot · run the ice drill (hold a key, stop in the green zone) · put the sample in the analyzer |
| Venus | Inside the ship: warm white and navy, a big window with yellow-cream clouds | Release the cloud balloon · aim the cloud camera at a storm · read the wind data and send it home |

What the player packed matters here. No drill means no ice sample. A weak antenna means the data sends slowly. The tasks tick off the mission's success checklist.

**DEFAULT:** each area is small (about one minute of play). The existing `player.tscn` and `arm.tscn` are the starting point.

## 11. Return and report

- **Return to Earth cutscene:** a placeholder scene `cutscene_return.tscn` that shows one line of text and moves on. The team replaces it later.
- **Mission report** (grow the existing `debrief`): the General reads it out.
  - Success checklist with ticks.
  - **Score** out of 1000: goals met (400), science data returned (200), resources used well (200), build quality from minigames (100), teamwork average (100). **DEFAULT** weights, kept in data.
  - "What went well / what to fix next time": 2–3 lines built from the flight log, each naming a design choice ("Your battery was too small for the lunar night").
  - Buttons: **Redesign and fly again** (keeps the design so the player changes one thing), **New mission**.

## 12. Art direction

Follow the project's "Master Art Direction" doc for everything on the planets and in space. Short version:

- Low-poly, chunky shapes, matte flat colors, soft lighting. No photorealism, no heavy bloom, no outlines.
- **Moon:** cool grays and off-white. No fog and no blue sky; it has no air.
- **Mars:** dusty orange, terracotta, beige, soft haze.
- **Venus** (new): pale yellow, cream and soft orange clouds outside; warm white, navy and gray inside the ship with cyan or orange accents.
- **NASA on Earth** (cutscene, minigame backgrounds): keep the existing war-room look and the toy-like cast.
- **Suits:** the same three characters in simple suits with big helmets. Keep each one recognizable (the janitor's mustache shows through the visor, the student is short).
- **2D screens:** dark navy panels, rounded corners, one amber accent, all from `theme/game_theme.tres`.
- Inspired by PEAK's overall feel only. Copy none of its models, places or UI.

## 13. Real data (Amy owns this)

Every number is real with a source link, or marked `"source": "PLACEHOLDER"`. Agents never invent real-looking numbers. Amy's list to fill, in priority order:

1. Launch vehicles: payload capacity and cost for 3 real rockets.
2. Trip time and one-way signal delay for the Moon, Mars and Venus.
3. Sunlight strength at each destination (it changes how much power panels make).
4. Mass and power of the key instruments (a seismometer, an ice drill, a cloud camera).
5. Length of the lunar night; Venus surface temperature and pressure; how long Venus landers lasted.
6. One real mission budget per destination to set the budget limit.

Places to look: the challenge's Resources tab (check first), NASA Technical Reports Server, NASA mission press kits, JPL Horizons, NASA Space Science Data Coordinated Archive.

## 14. What changes in the repo

| Keep | Change | New | Archive |
|---|---|---|---|
| Intro cutscene, characters | Speaker name to "Chief Mission Designer"; wire the cutscene into `stages.order`; remove the old 2D `intro` | `player_count`, `orbit` screens | Walkable ship (`walk`) |
| Name, character select | `destinations.json`: three new missions | Three minigame scenes + background scene | Reroute Power, power panel |
| Dashboard, review | `build`: 7 part categories + instruments | Ripple effect panel | Life support, supplies |
| Launch, timed press | `flight`: map + flight log | Three arrival scenes | Mars shadow-pass event |
| Debrief | `debrief`: score and reasons | `cutscene_return` slot, `data/minigames.json` | |

Record each of these as a team decision in `AGENT_SOURCE.md`, dated Nov 11, 2026.

## 15. Build order

Build one mission all the way through first, then copy the shape. **Mars first** (the repo already has Mars data).

**Phase 1: Skeleton, Mars only (before the hackathon, Nov 12–13)**

1. Wire the intro cutscene in; rename the speaker; remove the old intro.
2. Swap destinations to Moon / Mars / Venus in data (Moon and Venus locked for now).
3. Add the orbit screen and the mass-versus-rocket check.
4. Grow the build screen to 7 categories plus instruments (placeholder numbers).
5. Ripple effect panel.
6. Three minigames as gray boxes with scoring.
7. Flight screen with map and log, 3 events.
8. Mars arrival with 3 gray-box tasks.
9. Report with score and reasons; Redesign button.

**Phase 2: Hackathon day 1 (Nov 14)**

10. Moon and Venus data, events and arrival scenes.
11. Amy's real numbers replace placeholders.
12. Minigame background scene with workers.

**Phase 3: Hackathon day 2 (Nov 15), polish until 2 pm, then stop**

13. Art pass on the three arrival areas and the suits.
14. Sounds, "Did you know?" tips, inner-voice lines.
15. Web export, full playthrough, record the 30-second video (single-player is now safe to submit).

**Phase 4: True multiplayer (last, only after step 15 passes)**

16. Plan the connection (read and plan only).
17. Room code: host and join, player list.
18. Send the shared mission state; run minigames on every screen; collect and average scores.
19. Test with 2, then 4 computers. If it is not solid by Sunday noon, switch to the pass-the-keyboard fallback.

**If time runs short, cut in this order:** online multiplayer (use the pass-the-keyboard fallback) → team vote → 3D spacecraft model (use 2D) → hammering minigame → Venus arrival scene (end Venus at the flight log) → Moon arrival scene. **Never cut:** the six resources, the ripple effect, the rocket-and-orbit check, the flight log, the report with reasons.

## 16. Challenge checklist

| The challenge asks for | Where it is in our game |
|---|---|
| Define a mission objective first | Choose a mission, with a success checklist |
| Design a spacecraft, select instruments | Section 6b, steps 3 and 4 |
| Choose a launch vehicle and orbit | Section 6b, steps 1 and 2, plus the fit check |
| Manage budget, mass, power, comms, data, lifetime | Dashboard on every design screen |
| See how one decision affects others | Ripple effect panel |
| Simulate the mission | Launch, flight log, arrival |
| Feedback on why it passed or failed | Flight log reasons and the report |
| Up to 4 players | Online room for up to 4, everyone plays each minigame, averaged scores |
| Difficulty levels | Three characters |
| Redesign and rerun | "Redesign and fly again" |
| Simple explanations | Inner voice, card text, "Did you know?" |

## 17. For the submission

- **References to list:** Perceptle (inspiration for the angle minigame), PEAK by Aggro Crab and Landfall (art inspiration only), every NASA source Amy uses, Godot.
- **Use of AI field:** Claude (Fable for planning, Opus through Claude Code for building). Watermark any AI-made images or video.
- No student names, voices or faces in the game, video or page.
- Suggested 30-second video: General points (3 s) → pick mission and parts with the ripple effect (8 s) → three minigames (7 s) → launch and flight log (6 s) → planet task and report (6 s).

## 18. Still open

- Real NASA numbers and the official Resources tab (Amy).
- The return-to-Earth cutscene (team).
- More arrival minigames (team, after the skeleton works).
- Confirm the 2026 judging and submission guides on Nov 13.

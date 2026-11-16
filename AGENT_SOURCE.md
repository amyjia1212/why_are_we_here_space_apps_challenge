# AGENT_SOURCE.md: How Kaleb builds games with Claude Code

Source material for agents that build games the way Kaleb does. It was extracted on 2026-11-09 from:

- **The codebase:** `how-did-we-get-here/`, at commit `2e7a732`.
- **The git history:** one commit, "Graybox ship interior, steps 1-4: hallway, four rooms, signs, power panel", made 2026-11-09.
- **CLAUDE.md:** this folder had none at extraction time. One was added later on 2026-11-09 (commit `06ab0c1`). It holds the short rules every agent follows.
- **Session transcripts.** This folder's transcript folder (`~/.claude/projects/-Users-kalebtovar-Desktop-Nasa-Space-App-Challenge-how-did-we-get-here/`) holds only one file, and it is this extraction session. The game was really built in sessions started from the **Motion Studio** folder (`~/.claude/projects/-Users-kalebtovar-Desktop-OCAI-Center-Content-Creation--Motion-Studio/`):
  - `b4bfa5db-57ad-4afb-b944-c2c1c401ddfc.jsonl` is the whole build: 2026-11-08 to 2026-11-09, about 50 user turns and 3 context compactions.
  - `7ecfb294-1005-46f8-822d-0aea10f68608.jsonl` only holds a `cd` into this folder, with no game work.

Dates are local Pacific time, the same zone as the commit.

---

## 1. Game summary

- **Title:** "How Did We Get Here?" (`project.godot`: "How did we get here").
- **What it is:** a proof-of-concept mission-design game made in Godot 4.
  - The chief mission designer quits suddenly, and the general puts a random person in charge: the janitor.
  - The player must plan a real NASA-style science mission, "Map the ice on Mars", with no training.
  - An **inner voice** in the player's head guides them, warns them and explains failures.
- **The core loop:**
  1. Intro.
  2. Pick a character (only the janitor, medium difficulty).
  3. Pick a mission (one).
  4. Build: choose a version of the solar panel, camera and antenna.
  5. Review the six resources (budget, mass, power, communications, data, mission lifetime) against the mission limits.
  6. Launch into a **first-person 3D walk** through the ship. A wrist light and a raisable arm dashboard show live resources.
  7. A **Mars shadow pass** (the orbiter flies through Mars' shadow) cuts solar power to zero, and the batteries cannot carry everything. The player runs the **Reroute Power** mini-game at the power panel.
  8. The **mission report** debrief shows success or failure. Each failure lists what failed, why it failed and how to fix it.
  9. Try again.
- **Who plays it:**
  - Students **aged 10–15** ("Students aged 10–15 will play this." 2026-11-08).
  - It is built by Kaleb, a Magikid coach, for "a team of 5 Magikid students" as a demo "so the students can see how the game works before they build the real one" (2026-11-08).
- **The challenge it answers:** NASA Space Apps Challenge 2026 (Nov 14–15), challenge **"Space Mission Design Game"** (2026-11-08).
- **From 2026-11-10 the game grows into the full game in `GAME_PLAN.md`:** setup questions, Build, Launch, Flight, Arrival and the report, for five destinations. The summary above is the proof of concept it grows from.
- **From 2026-11-11 the design source is `PLAN.md`** (the team's final plan): Moon, Mars or Venus; design against the six resources; three build minigames; automatic flight with a flight log; a 3D walk-around at the destination; a report with a score and reasons. See section 2, "Team decisions locked on 2026-11-11".

---

## 2. Design decisions

### Team decisions locked on 2026-11-11 (PLAN.md sections 2 and 14)

These come from the team's final plan, `PLAN.md` (written 2026-11-11 from the team's choices). `PLAN.md` wins wherever it disagrees with `GAME_PLAN.md` or with an older line in this file. The older lines they replace are in section 3 under "Replaced on 2026-11-11".

**Section 2: decisions locked on Nov 11**

- **Intro: use the 3D intro cutscene (`scenes/cutscene_intro.tscn`, 11 shots, about 27 s), then the name screen.**
  Why: "Use the 3D cutscene already in the repo... then name entry" (PLAN.md §2, 2026-11-11)
- **The person who quits is always the "chief mission designer". The cutscene speaker name changes from "Commander".**
  Why: "Always 'chief mission designer'. Change the cutscene speaker name from 'Commander'" (PLAN.md §2, 2026-11-11)
- **Three destinations: Moon, Mars, Venus. They replace Mars orbit, the three Mars sites and Europa.**
  Why: PLAN.md §2 (2026-11-11)
- **Moon goal: a moonquake network. Place 3 seismometers.**
  Why: PLAN.md §2 (2026-11-11)
- **Mars goal: collect ice data.** Checklist: land safely, drill and sample ice, send the data home.
  Why: PLAN.md §2 and §5 (2026-11-11)
- **Venus goal: study the storms from orbit and with a cloud balloon. Nobody lands.** The game says why out loud: the surface melts lead, the pressure crushes spacecraft, and landers lasted only about two hours.
  Why: PLAN.md §2 and §5 (2026-11-11)
- **DEFAULT: Moon and Mars carry a crew on a lander. Venus has a crew ship in orbit.** These are game-design choices, written as such in the data file.
  Why: PLAN.md §5 DEFAULT (2026-11-11)
- **Build order: pick the parts, rocket and orbit first. Then the three minigames.**
  Why: PLAN.md §2 (2026-11-11)
- **Minigame 1, Assembly: press the shown letter key fast (A–Z only, no symbols). Its score becomes build quality.**
  Why: PLAN.md §2 and §7 (2026-11-11)
- **Minigame 2, Fueling: match the target angle by dragging a valve handle. Its score becomes fuel loaded.**
  Why: PLAN.md §2 and §7 (2026-11-11)
- **Minigame 3, Hammering: hit nails that pop up at random spots. Its score becomes structure strength.**
  Why: PLAN.md §2 and §7 (2026-11-11)
- **Minigame mood: building and preparing. Workers set up the rocket in the background.** Each minigame lasts about 20–30 s and gives a score of 0–100. A low score never ends the game on the spot; it shows up later in the flight log and the report, with the reason.
  Why: PLAN.md §2 and §7 (2026-11-11)
- **Flight is automatic: a flight log only, no in-flight challenges.** A map, status tiles, 3–5 events from `data/events.json` whose outcome depends on the design and the minigame scores, and a 1x / 4x speed button.
  Why: PLAN.md §2 and §9 (2026-11-11)
- **At the destination: a 3D walk-around with 3 tasks. More minigames come later.**
  Why: PLAN.md §2 and §10 (2026-11-11)
- **Return to Earth: the team makes the cutscene later. For now, `cutscene_return.tscn` is a slot that shows one line of text and moves on.**
  Why: PLAN.md §2 and §11 (2026-11-11)
- **Multiplayer (MULTIPLAYER_PLAN_V6, team decision 2026-11-15): each player on their own computer, joined by a 4-letter party code; or 2-4 seats on one computer filled with bots (no internet). 1 player = solo, exactly as before, with no party screen.**
  Why: Holden's note, written up as MULTIPLAYER PLAN V6 (2026-11-15).
- **Everyone votes on every choice after the party forms (mission, rocket, orbit, launch date, the seven parts, instruments). Most votes wins. Tie: "Tie! Talk it over.", one 20-second revote, then a coin flip (DEFAULT). Instruments: in when more than half the party wants it; exactly half = coin flip (DEFAULT, no revote for instruments).**
  Why: Holden's note (2026-11-15); tie rule = plan DEFAULT.
- **Every player must say GO before GO FOR LAUNCH unlocks. Bots always say GO.**
  Why: Holden's note (2026-11-15).
- **Harder with more players (bots count): ship problems x1/x2/x3/x4, supplies drain x1.0/1.2/1.3/1.4, data goal x1/x2/x3/x4 (data column = DEFAULT). All in data/multiplayer.json.**
  Why: Holden's note (2026-11-15); Amy playtests the table.
- **Minigames: everyone plays at the same time on their own screen; the minigames themselves did not change. Bots score a random 85-100, new each minigame, and it counts in the team average. A missing score gets 0 after 30 s (DEFAULT, the plan said 15 s after time is up).**
  Why: Holden's note (2026-11-15).
- **Bots: vote with the people's favorite (never change who wins), always GO, always ready; take a ship problem nobody started after 5 s and fix it in 10 s; gather 85-100% of one player's data share during the flight (DEFAULTS).**
  Why: plan DEFAULT; without it one human with three bots faces 4x the problems alone (2026-11-15).
- **The party leader's game is the boss: it holds GameState, rolls the dice (bot scores, coin flips, a seed for each stage) and moves everyone to the next screen when all people are ready ("Go anyway" for the leader after 20 s). A player who leaves becomes a bot; if the leader leaves, the mission ends for everyone (DEFAULT).**
  Why: MULTIPLAYER_PLAN_V6 section 5 (2026-11-15).
- **Flight and planet in an online party use the plan's smaller version (B5): each player flies their own ship with their fair share of the problems; at the end of each screen their data, ticked checklist items and problems fixed are added to the team. Launch damage = the average of everyone's launch (DEFAULT). Seeing each other's characters (B6) is not built.**
  Why: plan section 8 cut list, built fast on 2026-11-15.
- **Relay: a ~150-line Godot program (relay/relay.gd, run headless) that passes notes and knows nothing about the game. No chat box and no public party list. The internet address waits for the coach (B1); until then the game uses ws://localhost:9080 (serve_relay.ps1).**
  Why: no Node or Python on Holden's PC, Godot runs everywhere; plan sections 4 and 9 (2026-11-15).
- **Art: the toy-like cast in the cutscene and at NASA. The same characters in PEAK-style suits on the planets.** PEAK inspires the overall feel only; we copy none of its models, places or UI.
  Why: PLAN.md §2 and §12 (2026-11-11)
- **The report has two buttons: "Redesign and fly again" (keeps the design) and "New mission". Score out of 1000: goals 400, science data 200, resources used well 200, build quality 100, teamwork 100 (DEFAULT weights, kept in data).**
  Why: PLAN.md §11 (2026-11-11)
- **The launch vehicle has a payload capacity. At Review, mass must fit the rocket's capacity for the chosen orbit. A failed check is a red blocker with a one-line reason, but the player can still launch and see what happens.**
  Why: PLAN.md §6b and §6d, "Failing teaches." (2026-11-11)
- **Build one mission all the way through first (Mars), then copy the shape. Follow the build order in PLAN.md §15.**
  Why: PLAN.md §15 (2026-11-11)

**Section 14: what changes in the repo**

- **Keep:** the intro cutscene and characters; the name and character select screens; the dashboard and review; launch and the timed press; the debrief.
  Why: PLAN.md §14 (2026-11-11)
- **Change:** the cutscene speaker name to "Chief Mission Designer"; wire the cutscene into `stages.order` and remove the old 2D `intro`; `destinations.json` gets the three new missions; `build` grows to 7 part categories plus instruments; `flight` becomes a map plus a flight log; `debrief` gets the score and reasons.
  Why: PLAN.md §14 (2026-11-11)
- **New:** `player_count` and `orbit` screens; three minigame scenes plus a background scene; the ripple effect panel; three arrival scenes; the `cutscene_return` slot; `data/minigames.json`.
  Why: PLAN.md §14 (2026-11-11)
- **Archive (move to `scenes/archive/`):** the walkable ship (`walk`); Reroute Power and the power panel; life support and crew supplies; the Mars shadow-pass event.
  Why: PLAN.md §9 and §14 (2026-11-11)
- **New `stages.order`:** `cutscene_intro, name, character_select, player_count, mission_select, rocket, orbit, build, review, minigame_assembly, minigame_hammer, minigame_fuel, launch, flight, arrival, cutscene_return, debrief`.
  Why: PLAN.md §3 (2026-11-11)

**Holden's setup choices, 2026-11-11**

- **The project is Kaleb's template from GitHub, copied into `how-did-we-get-here-\` on Holden's Windows computer. Holden's `Refrences` folder (reference videos) is kept.**
  Why: "The full project is Kaleb's template on GitHub... Keep my Refrences folder." (2026-11-11)
- **`UPGRADE_PLAN_V2.md` is the design source and wins over `PLAN.md` and `GAME_PLAN.md` wherever they disagree. Build in its section 5 order. (Its "FINAL GAME PLAN" means our `PLAN.md`.)**
  Why: "yes, the upgrade plan works, start step 1" (2026-11-14)

**Team decisions, 2026-11-13 (UPGRADE_PLAN_V2.md section 2)**

- **A start menu comes first, then the intro cutscene.**
  Why: playtest note "Start screen with name, context, start button" (2026-11-13)
- **Planet first: mission, then briefing, then rocket.** (The stage order already had the mission before the rocket.)
  Why: playtest note "Choose the planet first" (2026-11-13)
- **Picking things happens in 3D rooms you walk around in (the Choice Room), not 2D card menus.**
  Why: playtest note "Selections as a 3D room... Packing UI is cluttered" (2026-11-13)
- **The launch is rebuilt in 3D to match reference 1 (Mission Orbit).**
  Why: playtest note "launch like reference 1; 3D modeled" (2026-11-13)
- **The walkable ship is back for the flight (reference 3), with more tasks. The flight log moves to a screen on the Bridge.**
  Why: playtest note "Flight like reference 3, with more to interact with" (2026-11-13)
- **Tab opens the mission tablet: mini map plus all six resources.**
  Why: playtest note "Tab shows a mini map with mass, budget and the rest" (2026-11-13)
- **The planet camera is third person.** (Already built in `player.gd` since 2026-11-12.)
  Why: playtest note "Third person on the planet" (2026-11-13)
- **New: sound, keybinds, portraits, briefing pages, leaderboard, waypoints, bots.**
  Why: the playtest notes in UPGRADE_PLAN_V2.md section 8 (2026-11-13)

**Recommended choices used for NASA_RESOURCES_PLAN.md N1–N9 (2026-11-14)**

- Full Space Dictionary set adds +20 to the score (plan DEFAULT; `nasa_resources.json` dictionary_bonus). Stamps are saved on that computer and count across runs.
- Hints are called "Office Hours" (key O in the Design Lab, a button on Review). Detail follows the level rule (scientist names problem + parts, janitor names problem, student only warns).
- GMAT: named only (nothing installed). CSA tip: an empty slot that stays hidden until a writer adds text + link.
- "Won't work here" options come only from `destinations.json` not_possible (no rocket or orbit is truly impossible with today's numbers). Mars has none.
- Mission twins are picked by packed instruments; the fallback is the mission's main real example.
- The CML meter shows on the strip only in the Design Lab and on Review (always in the tablet). CML resets on "New mission", not on "Redesign".
  Why: Holden: "dont stop until you are done like last time chooseing the recomended" (2026-11-14)

**Recommended choices used for UPGRADE_PLAN_V2 Steps 17–28 (2026-11-14, the team can change any of them)**

- **Minigame tutorial card:** the full card (3 steps + a tiny moving example) shows the first time each minigame is played in a session; after that only the short how-to; "?" opens the full card and pauses the game.
- **Assembly:** type the part's name (spaces skipped). Word lists and times per level in `minigames.json` (Scientist 8 short words, 10 for 100 points, 30 s; Janitor medium words, 8, 30 s; Student long words, 6, 28 s). Each word snaps a part onto the workshop rocket.
- **Hammering:** 24 nails per turn; a missed click dents the panel but costs no points (looks only).
- **Fueling:** the gauge fills with the turn (a full turn = full); orange mark on the wheel and on the gauge.
- **Flight ship:** the old flight log became `flight_log.tscn` on the Bridge wall screen; `flight.tscn` is now the walkable ship (3-minute trip). A design check that fails becomes an emergency with a timer; fixing it in time avoids the loss (report says "fixed", with a note that a better part would not need it). A good design gets no emergency for that event. Crew emergencies (water leak, air filter, breaker) top each trip up to 3–5; a missed one costs 6–10 million $ from the cash reserve. Calm tasks give +2 Gb of data. Skipping (after the first trip) lets the design alone decide everything still open.
- **Planet:** Moon and Mars third person; Venus (on the ship) first person.
- **Bots:** staff walk in the ship and the Choice Rooms; in a solo game three bot crewmates show on the leaderboard for show only. In a party, bots are real crewmates (see the multiplayer lines above, 2026-11-15).
- **Step 28 online multiplayer:** built on 2026-11-15 from MULTIPLAYER PLAN V6 (branch multiplayer-v6).
  Why: Holden asked to "just do recommended" and keep going until all 28 steps are finished (2026-11-14)
- **Holden runs Claude Code and says pass. The self-check uses Holden's Windows Godot (`C:\Users\holde\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe`).**
  Why: "Change it to my Windows Godot path" (2026-11-11)
- **CLAUDE.md is Kaleb's version merged with Holden's: Kaleb's rules and data files, plus Holden's team table, privacy rule and REFERENCES.md rule. No commits for now, because git is not installed on Holden's computer.**
  Why: Holden picked "Merge (Recommended)" (2026-11-11)
- **The intro cutscene can be skipped with Space, Enter or a mouse click. It jumps to the next screen. A small hint ("Press Space to skip", text in `story.json`) shows in the letterbox bar.**
  Why: Holden answered "YES" to a skip for repeat players, then picked "Space, Enter or click (Recommended)" (2026-11-11)
- **"Choose a mission" is one screen that picks both the place and the goal. The cards are in PLAN.md order (Moon, Mars, Venus). Locked cards still show their goal and checklist, greyed out. The old "Where are we going?" screen is archived.**
  Why: Holden passed step 2 with these choices listed (2026-11-11)
- **The mass check: each rocket has one lifting capacity, and each orbit adds the fuel the spacecraft needs to slow down into it (a lower orbit needs more fuel, which is true for Mars). Launch mass = spacecraft + orbit fuel, and the Mass limit is the rocket's capacity. Mars orbits: low, high, polar (a low orbit over the poles, with low-orbit fuel). High is the default when a later screen is tested alone. Capacities and fuel were replaced together at Step 11b (2026-11-13): real rocket lifts, orbit fuel scaled to MRO's real propellant.**
  Why: Holden passed step 3 with this listed as the recommended model (2026-11-11)
- **Review lists a red blocker with a one-line reason for every resource that breaks its limit (all six, not only mass). With blockers, the button says "Launch anyway" and still works.**
  Why: PLAN.md §6d ("Failing teaches"); Holden passed step 3 (2026-11-11)
- **Until steps 3–4, Mars uses the `mars_ice` limits (the MRO orbiter numbers) through `limits_from` in `destinations.json`. Moon and Venus get no trip numbers until Amy has real ones.**
  Why: Holden passed step 2 with this listed (2026-11-11)

### Player experience
- **In the intro cutscene (mission control war room), the Assistant Scientist, the Janitor and the Student are the three playable characters.** The Assistant Scientist capsule is the playable scientist (easy). Not a non-playing extra.
  Why: "assistant is a play able character, so is janitor and the student." (2026-11-11)
- **The general puts a person in charge: a scientist, the janitor or a student. The premise is the same for all three.** Later, in multiplayer, every player uses the same character type.
  Why: "The premise for all: the general puts this person in charge. Later, in multiplayer, every player uses the same character type." (2026-11-10) The original premise: "The player must plan a real NASA-style science mission with no training." (2026-11-08)
- **An inner voice guides, warns and explains failures. It is the game's only teacher.**
  Why: Kaleb's brief (2026-11-08).
- **The inner voice is never wrong. It only knows what its character knows (scientist = expert, janitor = everyday adult, student = kid), and it always teaches.**
  Why: "The voice is never wrong. It only knows what its character knows... and it always teaches." (2026-11-10)
- **Six resources with exact names: budget, mass, power, communications, data, mission lifetime.**
  Why: "Use these exact names" (2026-11-08). Kept: "Keep the six exact resource names." (2026-11-10)
- **Mission lifetime means how long the spacecraft works after arrival.**
  Why: "Mission lifetime = how long the spacecraft works after arrival." (2026-11-10)
- **Three levels: Scientist = easy, Janitor = medium, Student = hard. The levels change only how much guidance the player gets. Budget, mass, timing windows and supply use are the same for everyone (the real numbers).**
  Why: "3 levels, not 4... Drop 'Assistant'." (2026-11-10) and "the budget should be the same or everyone, the different levels will just be how much guidance we give them." Kaleb then picked "guidance only": timing windows and supply use are the same for all levels too (2026-11-10).
- **Hint detail per level:** Scientist = full (names the problem and the part that causes it), Janitor = some (names the problem), Student = few (only the warning). Hints never give the answer.
  Why: accepted with "for all questions do recommended" (2026-11-10), and kept when the other multipliers were dropped.
- **After each setup answer, the inner voice reacts and a Next button appears. The player reads at their own pace.**
  Why: Kaleb picked "Show a Next button (Recommended)" over a timer (2026-11-10).
- **The rocket's cost comes out of the spacecraft base budget: the middle rocket's cost is taken out of the $490M base, so the middle rocket keeps today's balance and the other two move it up or down.** MAVEN's $671M and MRO's $720M already include their launch.
  Why: "for all questions do recommended" (Q1, 2026-11-10).
- **Limits must matter, so the player cannot take everything. But they must not be so tight that the player plays scared. The player should be able to take risks and "do some damage."**
  Why: Kaleb's own words (2026-11-09).
- **Each resource has three colors: green = safe, yellow = close to the limit, red = past a max or under a min.**
  Why: Kaleb's dashboard brief (2026-11-08).
- **Rows still red at the end of the walk count as mission failures. Any meter the player sees go red can fail the mission, in every stage. On fail, the report offers "Retry from checkpoint".**
  Why: "yes we can count it as failure, they should have goals that will make it so that they need to pay attention to what they need to do" (2026-11-08). "AGENT_SOURCE wins. Any meter the player sees go red can fail the mission. On fail, offer 'Retry from checkpoint'." (2026-11-10)
- **The wrist light shows the worst row (green, yellow or red) and blinks on red. The dashboard stays hidden until Tab raises the arm.**
  Why: "an arm that will have a light on it that will go red if something goes bad... That way its hidden but also still can notify if anything is wrong." (2026-11-08)
  Picked options: "Light warns, Tab raises arm" and "Green / yellow / red".
- **When the arm is raised, the dashboard is a 2D screen panel above the wrist, not a 3D wrist screen.**
  Why: Kaleb picked the recommended option, "Easy to read, reuses the dashboard we already built." (2026-11-08)
- **Controls:**
  - WASD to walk, Space to jump, mouse to look, E to use.
  - Tab raises the arm (dashboard).
  - Esc frees the mouse. Esc or E closes a panel.
  - Why: "can we get a jump feature please" (2026-11-08). The rest is the brief and the arm feature.
- **Timed presses: Space only in Launch, where the player cannot move. On the ship and the surface, timed presses use E, and Space stays jump.**
  Why: "Space = jump on the ship. Space = timed press only in Launch, where the player cannot move. Timed presses on the ship or surface use E." (2026-11-10)
- **"Press E" prompts appear near interactive things: parts, the power panel and, later, parts seen at windows.**
  Why: the brief: "When the player walks close to a part and presses E, the inner voice explains that part and its numbers." (2026-11-08) Inspecting parts at the windows was accepted at G1 (2026-11-09).

### Game structure
- **Screen flow (PLAN.md section 3): Intro cutscene → Name → Who are you? → How many players? → Choose a mission → Design (launch vehicle → orbit → spacecraft parts → instruments) → Review → Build minigames (Assembly → Hammering → Fueling) → Launch → Flight → Arrival → Return to Earth cutscene → Mission report → Redesign / New mission.**
  Why: team decision, PLAN.md section 3 (2026-11-11). Replaces the GAME_PLAN.md flow.
- **I built the 2D loop (Build → Review → Debrief) before the 3D walk.**
  Why: my plan, so "the students can play a whole working loop early, and the 3D walk slots into the middle later" (2026-11-08). Kaleb approved it.
- **Two autoloads hold the logic: `Data` loads the JSON files, and `GameState` holds the choices and does all the math. A third autoload, `Textures`, makes textures in code.**
  Why: this follows from the data rules (2026-11-08) (guess: Kaleb did not phrase it this way).
- **The dashboard is one reusable scene. It only draws values and does no math. It is used on Build, in the walk (on the arm) and later on the Bridge wall.**
  Why: "One reusable dashboard scene" (2026-11-08).
- **Difficulty is set by how much guidance the character gets, not by changing the numbers.**
  Why: the brief named "janitor (medium difficulty)" (2026-11-08). "the budget should be the same or everyone, the different levels will just be how much guidance we give them." Kaleb then picked "guidance only": timing windows and supply use are the same for all levels too (2026-11-10).
- **When `PLAN.md` gives a DEFAULT, agents use it and list it in the report. Otherwise they ask one short question.**
  Why: "Use the GAME_PLAN DEFAULTs and list them in your report." (2026-11-10). From 2026-11-11 the DEFAULTs come from `PLAN.md`, which wins over `GAME_PLAN.md` (Holden, 2026-11-11).
- **Science instruments are on/off toggle cards: the player packs as many as budget, mass and power allow. The mission's key instrument (Mars: ice drill) is required, and leaving it out is a Review blocker.**
  Why: Holden picked "Pick any (on/off) (Recommended)" (step 4, 2026-11-12).
- **The new part categories (structure, battery, attitude control, thermal control, computer) do not count twice with `spacecraft_base`: each category's "simple" card numbers are taken out of the base, so the default build totals stay the same.**
  Why: Holden picked "Move simple card out of base (Recommended)" (step 4, 2026-11-12).
- **The playthrough, web export and browser test happen once per batch of steps. A batch is one of the batch headings in `TASKS.md`; a single step is not its own batch.**
  Why: "One playthrough, web export, and browser test per batch of steps." and "for all questions do recommended" (Q3, 2026-11-10).

### NASA data
- **No numbers are hard-coded in scripts. Numbers go in the data files listed in `GAME_PLAN.md` section 11: `game_data.json`, `destinations.json`, `parts.json`, `events.json`, `supplies.json`, `timing.json`, `levels.json`. On-screen text stays in `story.json` and inner-voice text in `inner_voice.json`.**
  Why: Kaleb's data rule (2026-11-08). "Use the GAME_PLAN data files... Text stays in story.json and inner_voice.json." (2026-11-10)
- **Placeholder numbers are marked `"source": "PLACEHOLDER"`.**
  Why: "Use placeholder numbers for now and mark them as placeholders. A student will replace them later with real NASA data." (2026-11-08)
- **Each number's `source` must be replaced with a link or document name when real data goes in.**
  Why: the `_readme` in `game_data.json` (2026-11-08).
- **The agent finds real NASA numbers by web search (no downloads), and cites a source link for each one.**
  Why: Kaleb picked "Agent searches the web (Recommended)" (2026-11-09).
- **Each game part version stands for real flown NASA hardware and uses its published mass and power. Where no cost is published, the source says "no public source" and the game value stays.**
  Why: Kaleb picked "Match a real mission (Recommended)" (2026-11-09).
- **For a batch of data steps, show all the tables (value, real number, source link) together, wait for one pass, then build them in a row.**
  Why: Kaleb picked "All 3 tables first (Recommended)" (2026-11-09).
- **Real hardware for the parts: small solar = Mars Odyssey array, medium = MAVEN arrays, large = MRO arrays (both wings, 96.6 kg), basic camera = MRO CTX, high-res camera = MRO HiRISE, small antenna = Mars Odyssey 1.3 m high-gain antenna, large antenna = MRO 3 m high-gain antenna, heater = all MRO heaters.**
  Why: "pass" on the 7a–7c tables, accepting the recommended answers (2026-11-10).
- **Crew supplies per person per day: food 1.831 kg (with packaging; Lopez et al., NASA JSC, NTRS 20150003005, "BVAD Table & ISS experience"), water 2.5 L (NASA-STD-3001 OCHMO-TB-027, minimum potable water for hydration), oxygen 0.82 kg (Lopez et al., "O 2 Metabolic ... HIDH / BVAD"). Crew size, start amounts, task effects and the leak rate stay PLACEHOLDER.** The ECLSS brief's 1.083 kg/day oxygen (with 2 h exercise) was offered and not picked.
  Why: "pass" on the A11 table (2026-11-10).
- **Every number comes from a NASA source. News sources do not count: where NASA has no number (for example HiRISE cost), write "no public source" and keep the game value.**
  Why: "pass", accepting the recommendation (2026-11-10).
- **A peer-reviewed science paper by the NASA instrument team counts as a source when no NASA page has the number (for example HiRISE data per day, McEwen et al. 2007). News sources still do not count.**
  Why: Kaleb passed the 7b table with this paper as the source (2026-11-10).
- **Both antennas use the same 172 W radio amplifier power (as on MRO). The real difference between them is size and data rate.**
  Why: "pass", accepting the recommendation (2026-11-10).
- **Values with no real-world match (solar lifetime bonus, heater lifetime loss) are marked as a written game-design choice instead of a source link.**
  Why: "pass", accepting the recommendation (2026-11-10). This also answers step 7g.
- **Step 11 (real numbers): the agent web-searches NASA sources (no downloads) and shows tables (value, real number, source link); Amy checks the tables before anything goes into the data files.**
  Why: Holden picked "I search, Amy checks (Recommended)" (2026-11-12).
- **The three rockets become real launch vehicles, with their real names on the cards and their real cost and lift.**
  Why: Holden picked "Real rockets (Recommended)" (2026-11-12). Replaces the "plain names on purpose" note in story.json.
- **Step 11b: the real numbers went in with the recommended answers, before Amy's check.** Holden: "if there is any issue, do the recommended fix ... i will see when it is all done at the end and make changes then" (2026-11-13). Amy still checks `STEP11_TABLES.md`.
  - **Rockets: option (a), the real Falcon 9.** Falcon 9 ($80.4 M, 4,020 kg), Atlas V 401 ($148.3 M, 2,315 kg), Atlas V 541 ($243 M, 4,050 kg). The ids stay small / medium / large. The rocket trade-off is now cost and lift against launch timing (Falcon 9 has the most, tightest moments). Known effect: Atlas V 541 never fits a winning budget. **Decided 2026-11-13: keep the real numbers and teach it** with a "Did you know?" on the rocket screen (what NASA really paid for a Falcon 9 and an Atlas V 401 launch, and that the Falcon 9 booster lands and flies again). Why: Holden picked "Keep real, teach it (Recommended)" (2026-11-13).
  - **Mass scale: real-sized orbit fuel, scaled to MRO's 1,149 kg** (Mars low/polar 1,149, high 800; Moon 600/400; Venus 1,300/900). A written game-design choice.
  - **Base budget 276.7** (= 490 − 148.3 − 65), so a medium-rocket build costs the same as before.
  - **Moon budget stays $620 M; Venus stays $700 M** (inside the real $580–743 M range; the table's $650 M left Atlas V 401 builds no way to win).
  - **Laser reflector mass stays 5 kg** until Amy checks NSSDC's 77 kg. **Magellan radar = 154 kg** (the whole radar).
  - **Part B game rules are labelled "Game-design choice, waiting for the team's pass"** instead of PLACEHOLDER.
  Why: Holden's "do the recommended fix" (2026-11-13).
- **Multiplayer: pass-the-keyboard only (1–4 players on one computer, Step 6). No online relay server; Steps 17–19 are dropped.**
  Why: Holden picked "Pass-the-keyboard only (Recommended)" (2026-11-13). A browser can't host, and a relay server would need an https host that stays on for the judges.
- **The 2026 judging criteria are Impact, Creativity, Validity, Relevance, Presentation** (NASA project submission guide, checked 2026-11-13; the full judging guide page did not load for the agent).
  Why: TASKS.md open item "Confirm the 2026 rules (Nov 13)".
- **Steps 12–14 looks and sound (2026-11-13):** a 3D workshop with four toy-like staff behind every minigame; the player wears a suit on their own character in the arrival walk; sounds are made in code (no files); "Did you know?" tips use only facts already sourced in the data files; the minigame results screen has an inner-voice line whose good/bad line matches the real thresholds (Hammering uses the launch structure check).
  Why: Holden's "continue all of them ... do the recommended fix" (2026-11-13).
- **"Gb/day" means gigabits per day.**
  Why: "pass", accepting the recommendation (2026-11-10).
- **The spacecraft base is MRO without the swappable parts, so the biggest build (Large solar, High-res, Large antenna) is the real MRO. The base keeps the CTX camera.**
  Why: "pass" on the 7d/7e tables, accepting the recommendations (2026-11-10).
- **The mission budget limit is MAVEN's real total cost ($671M), so "you built MRO, with MAVEN money" fails. The player cannot take everything.**
  Why: "pass", accepting the recommendation (2026-11-10).
- **The comms minimum is MRO's real rate at its farthest from Earth (0.6 Mb/s), so the small antenna always fails comms. This is a real-world lesson.**
  Why: "pass", accepting the recommendation (2026-11-10).
- **Base mission lifetime is 30 months (game-design choice), so Small solar can still win. Data minimum 4 Gb/day is a game-design choice. Mass limit is MRO's real dry mass (1,031 kg), so mass only turns yellow and never fails alone.**
  Why: "pass", accepting the recommendations (2026-11-10).
- **NASA's own news pages (jpl.nasa.gov, science.nasa.gov) count as sources. Outside news does not.**
  Why: "pass" on the 7f/7g choices, accepting the recommendation (2026-11-10).
- **Where two NASA pages disagree, keep the number already passed and write the other one in the source text** (for example MRO solar power: 2,000 W in the press kit, 1,000 W on an archived JPL page).
  Why: "pass", accepting the recommendation (2026-11-10).
- **Game balance is decided only after real numbers arrive.** With the placeholder numbers, "Medium solar + Basic camera always fails. That could be a good lesson or too harsh for 10–15 year olds; worth deciding once you have real NASA numbers." (my note, 2026-11-09). Settled 2026-11-10 in step 8: with real numbers, 4 builds can win and doing nothing always loses. See the step 8 lines below.
- **Keep the Large solar panel as it is, even though Medium does the same job for less in this mission. Its voice line teaches why: in Mars' shadow it makes no power.**
  Why: Kaleb passed the step 8 balance review (2026-11-10).
- **Keep turning the antenna off as a cheap fix (communications only count at the end), until the Comms station gives it a cost.**
  Why: Kaleb passed the step 8 balance review (2026-11-10).
- **Keep the failure cards that the janitor cannot reach (the mass, power, data and mission lifetime build cards, and the `storm_ok` line). Students who change numbers, or a harder character, will reach them.**
  Why: Kaleb passed the step 8 balance review (2026-11-10).
- **Keep the "just fits" case: High-res camera with the antenna off leaves exactly 0 W spare in the shadow, and that counts as fitting.**
  Why: Kaleb passed the step 8 balance review (2026-11-10).
- **No change to the Small solar heater timing: the heater can be off 30 s at most in total (for example, off at 22 s, back on by 52 s).**
  Why: Kaleb passed the step 8 balance review (2026-11-10).

### Visual style
- **The 3D starts as simple boxes and cylinders, with an optional `"model"` path per part version to swap in real models later.**
  Why: "yea, lets just build it for now then upgrade" (2026-11-08).
- **Textures are made in Godot code, with no downloads.**
  Why: Kaleb picked "Made in Godot, no downloads" (2026-11-08).
- **The ship interior is a graybox: plain boxes, no art.**
  Why: Kaleb's brief, "A graybox is a rough layout with plain boxes, no art." (2026-11-09)
- **All 2D screens use a navy and orange theme from one shared theme file (`theme/game_theme.tres`).**
  Why: "Use a navy and orange color theme on all 2D screens (intro, build, review, debrief)." (2026-11-08)
- **Text is large everywhere: base font 26, titles 50, body 28, smallest 22–24.**
  Why: "Make all text larger and easier to read. Students aged 10–15 will play this." (2026-11-08)
- **The walk's control hints at the top are large.**
  Why: "The control hints at the top of the walk screen are too small to read. Make them larger." (2026-11-08)
- **Characters are cute, rounded, toy-like, made only from built-in shapes: one rounded body with no neck, small capsule arms, short legs with round shoes, round hands with no fingers. The top of the head is a lid that hinges at the back and flips open to talk. Each person is easy to know by shape: General = V shape, Janitor = squash, Assistant Scientist = tall thin cylinder, Student = small. No clothes yet.**
  Why: "Style: cute, rounded, toy-like." (2026-11-11)
- **The intro cutscene is directed like a polished animated short: hard cuts with eased camera moves, letterbox bars, a fade-in from black, warm key lights and cool rim lights, a dim table, code-drawn Mars maps on the screens (blue and amber), and subtitles with no box and an amber speaker name. Under 30 seconds. Primitive meshes and code-made graphics only.**
  Why: "Make it look like a polished animated short." Kaleb approved the 11-shot list with "yes" (2026-11-11).
- **Character art proportions (leg length, arm thickness, eye and mustache sizes) stay as constants in the character scripts, not in `game_data.json`.** They are drawing choices, not game numbers.
  Why: Kaleb answered "yes, do both" to keeping them in the scripts (2026-11-11).
- **The intro shows Kaleb's own character art for the general and the janitor.**
  Why: "Add the character images I made to the intro screen" (2026-11-08).
- **The debrief looks like a mission report: a stamp, numbered findings with what, why and fix, and a FINAL READINGS grid.**
  Why: "Make the 'Mission success' and 'Mission failed' screens look like a mission report, not a plain list." (2026-11-08)
- **Soft fill light, so no part of the craft is pitch black.**
  Why: "Add softer fill light... so the shadow side of the spacecraft is not black." (2026-11-08)
- **The glove stays yellow when lit.**
  Why: "Make the glove stay yellow when it faces the light." (2026-11-08)
- **The dashboard is anchored and never shifts as numbers grow.**
  Why: "Stop the dashboard from shifting when a number gets longer. Anchor it in place." (2026-11-08)
- **The arm is raised above the inner voice bar.**
  Why: "Raise or move the arm so it is not hidden behind the inner voice bar." (2026-11-08)
- **Under the web renderer the glove top is lemon-yellow instead of golden. This was accepted, not fixed.**
  Why: Kaleb's rule "Fix only what looks broken" (2026-11-08). Kaleb answered "pass" when asked whether to fix it.

### Text and story
- **All inner-voice text is in its own file (`data/inner_voice.json`), "so a student writer can edit it without touching code."**
  Why: Kaleb's brief (2026-11-08).
- **All other on-screen text is in `data/story.json`: screen titles, buttons, room names and station labels.**
  Why: "All text goes in inner_voice.json" (2026-11-09) and "Room names and labels go in a data file, not in code." (2026-11-09)
- **Dashboard warning text comes from `inner_voice.json`.**
  Why: "All warning text comes from inner_voice.json, so the writer can edit it." (2026-11-08)
- **The story opener reads: "NASA Mission Control. 7:42 AM. The chief mission designer just quit..." and the general says "You're in charge now." The button says "Uh... okay?"**
  Why: the general's line is from Kaleb's brief (2026-11-08). The rest is my writing, which Kaleb accepted (guess).
- **Each failure card has three parts: what failed, why it failed, how to fix it.**
  Why: "On failure, show three things: what failed, why it failed, and how to fix it." (2026-11-08)
- **The inner voice speaks in a nervous, funny first person**, for example "Huh. Everything is inside the limits. Did I... do that right?"
  Why: Kaleb chose it. "The voice is a little clueless, but sometimes it understands." (2026-11-09)

### Scope
- **Build the game in `PLAN.md`, in the order of its section 15 (Mars first, then Moon and Venus). No polish before Phase 3.**
  Why: "Build one mission all the way through first, then copy the shape." (PLAN.md §15, 2026-11-11). Replaces "Build in GAME_PLAN.md's phase order" (2026-11-10).
- **Change only what the current step needs.**
  Why: "DO: Make the change. Change only what this step needs." (2026-11-08)
- **Cosmetics wait until a feature is finished.**
  Why: "I have some cosmetic changes that I want but we can do that at the end" (2026-11-08).
- **The game must run in a browser.**
  - Use the Compatibility renderer and a single-threaded Web export.
  - Why: "make sure the game runs in a browser" (2026-11-08). Single-threaded is Kaleb's own requirement. My reason: it runs on hosts like itch.io without special headers.
- **Each batch of steps ends with one full playthrough, a re-export to `build/web` and a browser test.**
  Why: "One playthrough, web export, and browser test per batch of steps." (2026-11-10)

### The "more stuff" copy (2026-11-14)
- **Two copies of the game: "Original how did we get here" stays as it is; the extra ideas go into "How did we get here + more stuff".**
  Why: Holden: "first make a copy of the game and put them into two seperet folders" (2026-11-14).
- **Added from the team's idea list:** launch window station, mission patch maker, Clean Room minigame, lucky peanuts, wait-or-go weather call, zero-g toy, two-way fixes (hold E proper / Q quick), window postcards and spotting, real gravity jumps, footprints, race the ice, signal delay pointed out, rocket line-up with a school bus, tap a part, part jobs, mostly fuel, Real Mission Moments, ask the crew. Numbers: `data/extras.json`; words: story.json and inner_voice.json "extras".
  Why: Holden: "Add all of these changes to the game ... choosing the recomended" (2026-11-14).
- **Real gravity: the Moon uses 0.165 and Mars 0.38 of Earth's gravity in the arrival walk** (replaces the Moon's 0.35).
  Why: the idea list: "Jump about six times higher on the Moon and a bit under three times on Mars." (2026-11-14)
- **The signal delay is pointed out, not waited for**: the real radio delay is said when data is sent.
  Why: Holden: "just point it out instead of 'accurate' cuz i dont wanna wait a day" (2026-11-14).
- **Recommended choices made without asking (2026-11-14):** the launch window is a Design Room station after the orbit (the best date = shortest trip and least fuel but a tighter launch, a poor date = longer trip, more fuel, easier launch); the patch maker is its own screen after the briefing; the Clean Room's score counts in the teamwork average; postcards can be taken at any ship window (Earth is seen from the back windows, since the Bridge window faces forward); the weather call is space weather (the launch poll's item); quick fixes cost 3 Gb of data (design emergencies) or $4 million (crew emergencies) at the end of the trip.
- **The Clean Room is a flight task, halfway to the planet** (replaces "build job 0"): at half the trip a yellow task opens at Instruments in the Science Bay; E opens the wipe-the-dust minigame over the ship and the trip pauses. Arriving without cleaning = CLEANLINESS 0; Skip to arrival costs nothing. Numbers: extras.json "clean_room" (flight_at, flight_station, missed_score).
  Why: Holden: "make the player do it halfway through the flight to the planet they are going to being one of the tasks making the ship clean instead of just having it randomly when building the ship" (2026-11-14).

---

- **UPGRADE_PLAN_V3 (team decisions, 2026-11-14):** Q = Question (a small card from the glossary; the game pauses while it is open, DEFAULT), Backspace = go back, R = the ship's quick fix. Character Room wall = a staff card (who, knows, help, difficulty dots), no inner-voice text. Mission Room wall = a 4-line mission card (where, job, why, NASA has done this). Mission Briefing = four short cards that type out. The six resources are taught by the General in Mission School (new screen after the briefing) and removed from Your File. Success checklist = 8 items by phase through the landing at home (Depart/Home by a fuel/structure rule, DEFAULT). Mission patch removed everywhere (files in scenes/archive and scripts/archive). Window planets: real NASA maps allowed for the window only (code ready; download waits for approval). Real astronauts only as sourced facts, text plaques, no photos, no invented dialogue.
  Why: Holden: "Input this into the game following what the plan says. complete all the steps without stopping if you have to choose something choose the recommended option" (2026-11-14), with UPGRADE_PLAN_V3.md.
- **Real NASA maps in the ship's window (UPGRADE_PLAN_V3 D1):** Earth = NASA Blue Marble "Land Surface, Ocean Color and Sea Ice" (Visible Earth image 57730, http://visibleearth.nasa.gov/view.php?id=57730, shrunk to 1024 × 512, via https://commons.wikimedia.org/wiki/File:Land_ocean_ice_2048.jpg); Mars = USGS/NASA Viking MDIM 2.1 colorized global mosaic (https://astrogeology.usgs.gov/search/map/mars_viking_colorized_global_mosaic_232m, via https://commons.wikimedia.org/wiki/File:Mars_Viking_MDIM21_ClrMosaic_1km.jpg, shrunk to 1024 × 512). Files: `assets/planets/`, listed in `REFERENCES.md`. Moon = NASA SVS CGI Moon Kit LROC color map (https://svs.gsfc.nasa.gov/4720, lroc_color_poles_2k.tif); Venus = NASA/JPL Magellan radar composite (https://commons.wikimedia.org/wiki/File:Cylindrical_Map_of_Venus.jpg) with a see-through made-in-code cloud layer on top, because the radar map shows the ground hidden under Venus's clouds.
  Why: Holden: "yes download the nasa maps", then "add real maps for the moon and venus too" (2026-11-14).
- **Cause chain report: each resource finding card on the Mission Report shows "How it happened"**, e.g. "Heavy instrument → more mass → bigger rocket → budget gone". It names the one choice that pushed that resource furthest from its best option. When the design was too heavy for a cheaper rocket than the one picked, a budget chain follows the mass back to its heaviest choice. Code: `GameState.get_cause_chain()`; words: story.json "cause_chain".
  Why: Holden pasted the idea "Cause chain report: The fail screen shows the chain: 'Heavy instrument → more mass → bigger rocket → budget gone.' Medium" and said "input this into the game" (2026-11-14).
- **UI_POLISH_PLAN_V4 (look only, 2026-11-15):** replaces Phase E of UPGRADE_PLAN_V3. DEFAULTS used (Jeremy may change them in `theme/game_theme.tres`): spacing 8/16/24/32/48; screen edge 32 (the plan's 48 scaled to our 1280×720 window); fonts Title 36 / Heading 24 / Body 18 / Small 14, display effects (countdown, stamps, typing game) keep their own sizes; no borders except the selected card and the report's status stamp; amber only for the one next action and the selected card; labels in a soft cyan-blue; screens inside the 3D world use the theme × 1.5 (Design Lab), × 1.45 (Bridge), × 1.7 (Mission School). Card stat chips = the three effects that move their resource the most (so the antenna shows its signal) until Amy picks. The Q ? tag moved to the top-right corner, because "Next" always sits bottom right. The arrival checklist shows as one line on screen (items on the tablet and report). Extra from section 4: the report score counts up. 3b done (Bridge screen) because 3a was finished before noon.
  Why: Holden: "incorperate all this information into the game to make ui better. Dont stop until you have done selecting teh recomended option" (2026-11-15), with UI_POLISH_PLAN_V4 (Holden's note: the UI is clunky and packed together, and the big info boxes on the ship and the parts screen do not fit in).
- **ROOM_LAYOUT_PLAN_V5 (layout only, 2026-11-15):** wins over UI_POLISH_PLAN_V4 Steps 2–3 for the Mission Room and Design Lab (and the Character Room, same scene). DEFAULTS picked: side screens angled toward the start spot (38°); your spacecraft on a high shelf on the back wall (not hidden); left = "This choice", right = "Your mission" (the plan's split). The room is 2 m deeper (18 × 17) so the first frame fits; row of pedestals capped at 7 m; small models 1.6×. Replaces the V4 back-wall card screen (moved to section 3).
  Why: Holden: "Add all of this into the game fixing the room layout. Continue until you are done without stopping choosing the recomended option" (2026-11-15), with ROOM_LAYOUT_PLAN_V5 (models covered the wall screen; names hard to see; cluttered first look).
- **Choice rooms: the spacecraft model floats by itself (no shelf), and the two info screens are flat on the left and right walls (no stands, no angle).** Replaces the V5 defaults "high shelf" and "angled screens on posts".
  Why: Holden: "Remove the pedastool for the model in the back instead just make it float by itself. for the information instead of being a stand have it pasted on the right and left walls" (2026-11-15).
- **Choice rooms, second layout (replaces the line above):** a wide room (26 × 15); the two screens on the back wall's left and right thirds; the middle third is a railed-off observation area where the chosen thing floats big and detailed over a round holographic emitter with a light beam and spotlight; the options stand low and small in front (below eye height, so nothing covers the screens); the picked option rises, grows and gets a spotlight. No lens change (forced perspective not needed).
  Why: Holden: "we want it to be on the back wall, but on the left third and the right third ... Displaying the selection in the center ... enlarged and in a bit more detail ... the selected object could be a bit higher ... better lighting ... circular, holographic look ... the observation part could be blocked off ... make these selections a bit smaller" (2026-11-15).
- **Three voices, one decision + The voice learns (INNOVATION.md):** hints on the rocket, orbit and instruments stations, in the existing voice bar; a word is learned when a mission or a checkpoint fails (the main cause, ranked by overshoot); each character keeps its own Notebook, saved between sessions; hint and notebook text drafted by Claude for the Head Writer to edit; on-screen name "The Assistant Scientist".
  Why: Holden pasted the feature brief and said "Add of this into the game without stopping. If it asks for a choice just chose the recommended" (2026-11-15).

- **Redesign depends on the character (2026-11-15).** The Assistant Scientist keeps the design and is guided with amber arrows and names; the Janitor and the Lost Student pick the whole design again. Why: "When it's the janitor, we wanted to reset back to the beginning... Scientist has way more direction and will make it kind of easier."
- **Launch dates trade off waiting money against trip length and scrubs (2026-11-15).** Why: "poor dates are sooner... but there's a lot of variability... We want trade-offs for all of those. And for it to be apparent."
- **Credits removed from the start menu (2026-11-15).** Team request.
- **Real astronauts as crew, facts only (2026-11-15).** Narrator fact cards with NASA sources, drawn in-game portraits, no photos, no invented first-person lines; the game says the crew assignment is our idea. Why: the team wants players to "learn about the person who's in there... who they are, what they've done".
- **No astronaut name plaques in the intro (2026-11-15).** Turned off (nasa_resources.json intro_plaques > enabled = false); the real astronauts meet the player as crew on the ship. Why: "why is that in the first cutscene, I feel like it is a bit out of place" (it also covered the subtitle line).
- **Life bars with consequences (2026-11-15).** A bar at zero restarts the trip with the same design (DEFAULT). Why: "if one of these things go bad, there's actual consequences to it".

## 3. Rejected choices

- **Multiplayer on one computer with turns at each minigame (pass the keyboard), and "the host picks the parts, the others watch".** Replaced on 2026-11-15 by MULTIPLAYER_PLAN_V6 (separate computers or bots, everyone votes).
- **Bot scores for show only.** Replaced on 2026-11-15: in a party, bot scores (85-100) count in the team average.
- **One GO button for the whole team.** Replaced on 2026-11-15: every player must say GO.

- **"Try again keeps the part choices" for every character.** Replaced on 2026-11-15 for the Janitor and the Student (they start the design again); the Scientist still keeps the design.

- The Design Lab back-wall screen with three option cards, a resource strip and an orange Confirm button (UI_POLISH_PLAN_V4 Step 2), plus floating pedestal labels and the CONFIRM marker (replaced 2026-11-15 by ROOM_LAYOUT_PLAN_V5: two side screens and nameplates).
- Q = go back one choice (replaced 2026-11-14 by Q = Question, Backspace = back; UPGRADE_PLAN_V3).
- The mission patch maker and the patch on the rocket, suit, report and leaderboard (removed 2026-11-14, UPGRADE_PLAN_V3 A1).
- A 3-item success checklist (replaced 2026-11-14 by 8 items by phase, UPGRADE_PLAN_V3 A3).
- The Clean Room as build job 0 (before Assembly). Replaced 2026-11-14: it is now a task halfway through the flight.

- **`PLAN.md` as the design source.** Replaced by `UPGRADE_PLAN_V2.md` (2026-11-14).
- **Intro cutscene as the first screen; 2D card menus for picking; an automatic flight with the ship archived; Tab raises the wrist dashboard.** Replaced by the UPGRADE_PLAN_V2 decisions above (2026-11-13).

- **The project folder `~/Desktop/OCAI Center/space-apps-game/`.** Rejected: "Use this folder for the project, not the OCAI folder" (2026-11-08). The project lives at `~/Desktop/Nasa Space App Challenge/how-did-we-get-here/`.
- **An auto-popup dashboard ("Red light pops it up") and "Both, player choice".** Rejected for "Light warns, Tab raises arm" (2026-11-08). Kaleb gave no reason beyond wanting the dashboard "hidden but also still can notify".
- **A dashboard drawn on a 3D wrist screen.** Rejected for a 2D panel above the wrist (2026-11-08). My stated tradeoff: the 3D screen's "text is smaller and harder to read" (guess that this was Kaleb's reason).
- **Free CC0 web textures (ambientCG or Poly Haven) and student-made textures.** Rejected for "Made in Godot, no downloads" (2026-11-08).
- **A green/red-only wrist light.** Rejected for green, yellow and red to match the dashboard (2026-11-08).
- **Getting or buying a spacecraft model now.** Kaleb asked "should I get a model for the space ship or will you generate one?" and then decided "lets just build it for now then upgrade" (2026-11-08).
- **The Forward+ renderer.** Replaced by Compatibility for the web build (2026-11-08).
- **A multi-threaded web export.** Kaleb required single-threaded (2026-11-08).
- **Fixing small renderer differences that aren't broken**, such as the glove tint. Not done, under "Fix only what looks broken" (2026-11-08).
- **The hangar as the walk location.** Replaced by the graybox ship and archived in `scenes/archive/` (2026-11-09).
- **The dust storm as the live event.** Replaced by the Mars shadow pass (2026-11-10): a real dust storm barely dims an orbiter's solar panels.
- **The old camera-E alarm fix.** Replaced by the Reroute Power panel (2026-11-09).
- **The corner mini-dashboard and the full-screen Tab overlay.** Replaced by the arm dashboard (2026-11-08).
- **Rooms without ceilings.** Kaleb accepted ceilings with shadowless lights at G1 (2026-11-09).

Replaced on 2026-11-10 by Kaleb's answers to the GAME_PLAN vs AGENT_SOURCE conflict list (C1–C16):

- **Only the janitor, told "You're in charge now."** Replaced by three characters, all put in charge by the general (C1, 2026-11-10).
- **Four levels with an "Assistant", and the janitor as "Very hard"** (GAME_PLAN draft). Replaced by three levels with the janitor as medium (C1, 2026-11-10).
- **Level multipliers on budget (×1.1 / ×1.0 / ×0.95), timing windows (×1.5 / ×1.0 / ×0.7) and supply use (×0.9 / ×1.0 / ×1.1).** Replaced the same day: the levels only change guidance (2026-11-10). It made the Student with the Large rocket unable to win.
- **"Swap the scrubber" as the air task.** Replaced by "run the oxygen generator": a scrubber removes carbon dioxide, it makes no oxygen (2026-11-10).
- **Crew uses only 90 days of supplies during the 730-day Arrival.** Replaced by the real 730 days (2026-11-10).
- **A 3-second automatic pause after each setup answer.** Replaced by a Next button: 3 s was too short to read the longer voice lines (2026-11-10).
- **"If a choice is not covered, ask one short question. Do not guess."** Replaced: use a GAME_PLAN DEFAULT when there is one and list it; otherwise ask (C2, 2026-11-10).
- **The shadow pass as a Flight event** (GAME_PLAN draft, Phase A step 5). Replaced: it stays a Mars-orbit event in Arrival (C3, 2026-11-10).
- **Food, water, air, heat, power and data as one row of trip meters** (GAME_PLAN draft). Replaced: the six resources keep their names, and food, water and air are "crew supplies" (C4, 2026-11-10).
- **A heat meter and a thermal-panel task** (GAME_PLAN draft). Replaced by the heater switch only (C6, 2026-11-10).
- **The mission fails only on the 2–3 goal rules** (GAME_PLAN draft). Replaced: any meter that goes red can fail it (C7, 2026-11-10).
- **The launch vehicle sets max mass and part of the budget** (GAME_PLAN draft). Replaced: the real limits stay, and the rocket changes the launch sequence and its cost (C8, 2026-11-10).
- **All numbers in ONE shared file, `data/game_data.json`.** Replaced by the GAME_PLAN data files (C9, 2026-11-10).
- **Space as the timed-press key everywhere** (GAME_PLAN draft). Replaced: Space only in Launch, E on the ship and surface (C10, 2026-11-10).
- **The janitor's inner voice "is often wrong"** (GAME_PLAN draft). Replaced: the voice is never wrong, and only knows what its character knows (C11, 2026-11-10).
- **Four ship rooms (Bridge, Power room, Science bay, Comms room).** Replaced by five, adding Life Support (C12, 2026-11-10).
- **"Keep the proof of concept small: one character, one mission, three parts with 2–3 versions each, and one live event."** Replaced by the full 5-destination game (C13, 2026-11-10).
- **The full playthrough, re-export and browser test only in a feature's last step.** Replaced by once per batch of steps (C14, 2026-11-10).
- **Screen flow "Intro → Character select → Mission select → Build → Review → Walk → Debrief → Try again" (Try again returns to Build).** Replaced by the GAME_PLAN flow and three report buttons: Retry from checkpoint, Same design / new destination, Start fresh (C15, 2026-11-10).

Replaced on 2026-11-11 by the team decisions in `PLAN.md` (sections 2, 3, 9 and 14):

- **The GAME_PLAN.md screen flow: Title → setup questions 1–5 → Build → Review → Checkpoint 1 → Launch → Checkpoint 2 → Flight → Checkpoint 3 → Arrival → Report** (2026-11-10). Replaced by the PLAN.md §3 flow (2026-11-11).
- **The old 2D `intro` screen as the first screen.** Replaced by the 3D intro cutscene (2026-11-11).
- **"Commander" as the speaker who quits.** Replaced by "Chief Mission Designer" (2026-11-11).
- **Five destinations: Mars orbit, Jezero, Gale, Arcadia Planitia, Europa** ("Full 5-destination game", 2026-11-10). Replaced by Moon, Mars, Venus (2026-11-11).
- **"Map the ice on Mars" with 3 goal rules: at least 4 Gb/day, 24 months working, communications at least 0.6 Mb/s** (Q4, 2026-11-10). Replaced by the Mars "collect ice data" checklist: land safely, drill and sample ice, send the data home (2026-11-11).
- **Mars missions have a crew on a ship that carries the spacecraft; Europa has no crew** (2026-11-10). Replaced by the PLAN.md DEFAULT: Moon and Mars have a crew on a lander, Venus has a crew ship in orbit (2026-11-11).
- **Crew supplies (food, water, air) as a separate group in Flight and Arrival, with NASA's per-person daily numbers; the crew uses all 730 days of supplies in Arrival** (2026-11-10). Archived with life support (2026-11-11). The NASA numbers stay in `data/supplies.json` in case the team brings supplies back.
- **Phase A Flight: ration food, run the oxygen generator, fix a water leak, all in the Life Support room** (Q2, 2026-11-10). Replaced: Flight is automatic, with a flight log and no in-flight challenges (2026-11-11).
- **The walkable graybox ship (hallway, Bridge, Power room, Science bay, Comms room, Life Support) with future station spots** (2026-11-09 and 2026-11-10). Archived to `scenes/archive/` (2026-11-11).
- **The Mars shadow pass as the live event (Arrival, orbit type) with the Reroute Power mini-game at the power panel, the cost of turning systems off, and the 24-month / 60 s mission clock in the walk** (2026-11-09 and 2026-11-10). Archived (2026-11-11). The heater switch on the power panel, the only heat mechanic, goes with it; thermal control is now a spacecraft part category (PLAN.md §6b).
- **The mission limits stay fixed; the launch vehicle changes only the launch sequence and its cost** (C8, 2026-11-10). Replaced: each rocket has a payload capacity, and at Review the mass must fit the rocket's capacity for the chosen orbit (PLAN.md §6b, §6d, 2026-11-11).
- **The report's three buttons: Retry from checkpoint, Same design / new destination, Start fresh** (C15, 2026-11-10). Replaced by "Redesign and fly again" and "New mission" (PLAN.md §11, 2026-11-11).
- **GAME_PLAN.md as the design source.** Replaced by PLAN.md, which wins wherever they disagree (Holden, 2026-11-11).
- **Commit after each step that passes its self-check** (correction 12, 2026-11-09). Paused: git is not installed on Holden's computer. It comes back if git is added (Holden, 2026-11-11).

---

## 4. My corrections

Kaleb never answered a step with "fail". Every change Kaleb asked for to existing work is listed below.

1. **Project location (2026-11-08)**
   - **What I did:** proposed creating the project in `~/Desktop/OCAI Center/space-apps-game/`, near the folder the session started in.
   - **What Kaleb wanted:** "Use this folder for the project, not the OCAI folder '/Users/kalebtovar/Desktop/Nasa Space App Challenge'".
   - **Rule:** confirm the project folder before creating files. Never default to the session's working folder or another project's folder.

2. **Runtime error after new files (2026-11-08)**
   - **What I did:** wrote new autoload scripts from outside the editor. Godot's uid cache didn't know them, so `GameState` was Nil.
   - **What Kaleb sent:** "Invalid assignment of property or key 'character_id' with value of type 'String' on a base object of type 'Nil'."
   - **Rule:** after adding new files or settings, tell Kaleb to use **Project → Reload Current Project** before pressing Play. Explain errors as a teaching moment.

3. **Missing extra feature (2026-11-08)**
   - **What I did:** built walking with no jump.
   - **What Kaleb wanted:** "can we get a jump feature please and do step 9 too".
   - **Rule:** small feel features can be added mid-plan when Kaleb asks. Kaleb may also ask to batch two steps.

4. **Debrief judged only the build (2026-11-08)**
   - **What I did:** a mission counted as a success even when live Data was red at the end.
   - **What Kaleb wanted:** "yes we can count it as failure, they should have goals that will make it so that they need to pay attention to what they need to do".
   - **Rule:** the end state of the live mission must count. Any goal the player can see go red must be able to fail the mission.

5. **Control hints too small (2026-11-08)**
   - **What I did:** used small fonts in the walk HUD.
   - **What Kaleb wanted:** "The control hints at the top of the walk screen are too small to read. Make them larger."
   - **Rule:** size all HUD text for 10–15-year-olds.

6. **All text too small (2026-11-08)**
   - **What I did:** used default and small font sizes across the screens.
   - **What Kaleb wanted:** "Make all text larger and easier to read. Students aged 10–15 will play this."
   - **Rule:** use one shared theme with large type variations (base 26, body 28, title 50). Never set font sizes per node.

7. **Plain colors (2026-11-08)**
   - **What I did:** used dark gray screens with yellow accents and per-scene StyleBoxes.
   - **What Kaleb wanted:** "Use a navy and orange color theme on all 2D screens (intro, build, review, debrief)."
   - **Rule:** put every 2D color in the shared theme file, and keep a consistent identity across all screens.

8. **No character art (2026-11-08)**
   - **What I did:** made an intro screen with text only.
   - **What Kaleb wanted:** "Add the character images I made to the intro screen".
   - **Rule:** leave slots for Kaleb's own art, with picture paths in data and a visible "Picture goes here" fallback.

9. **Plain-list debrief (2026-11-08)**
   - **What I did:** made a debrief that was a plain list of cards.
   - **What Kaleb wanted:** "Make the 'Mission success' and 'Mission failed' screens look like a mission report, not a plain list."
   - **Rule:** outcome screens should feel like an in-world document, not a debug list.

10. **Issues I found myself (2026-11-08)**
    - **What I did:** I reported four rough edges: a black shadow side, the arm hidden behind the voice bar, the dashboard shifting, and a cream glove.
    - **What Kaleb wanted:** "Your four items (do all four)".
    - **Rule:** report the rough edges you notice at the end of each step. Kaleb will add them to the list.

11. **Missing error help (2026-11-08)**
    - **What I did:** the W3 test steps said what to expect, but not what to do if errors appeared.
    - **What Kaleb asked:** "what do I do if it does show errors:"
    - **Rule:** every MY TEST includes "If you see an error" steps, for example a table of likely errors and fixes. Why: it saves time when a test fails (Kaleb, 2026-11-09).

12. **Commit each step (2026-11-09)**
    - **What I did:** left four passed steps uncommitted and offered to go on to step 5.
    - **What Kaleb wanted:** "Step 4 passed. Commit it. Do not start step 5."
    - **Rule:** commit after each step that passes its self-check. "Do not start step 5" was a one-time stop, not a rule (Kaleb, 2026-11-09).

---

## 5. Repeated questions

- **"Should red data (a live dashboard row) at the end of the walk fail the mission?"** I asked this **4 times**: in the Dashboard Step 6 report, the Dashboard Step 7 report, the Arm plan and the Arm Step 5 report (2026-11-08).
  - **Kaleb's answer:** "yes we can count it as failure, they should have goals that will make it so that they need to pay attention to what they need to do" (2026-11-08).
  - **Lesson:** ask an open design question once, record it, and don't repeat it in every report. Or ask it as a blocking question.
- **The arm/texture question set** appears twice in the transcript with the same answers. This is a logging duplicate, not a second ask.
- **"Tell me when it works / Say 'pass'"** ended every step. This was the agreed protocol, not a real repeated question.

No other question was asked more than once.

---

## 6. My acceptance checks

What Kaleb looks at or tests before saying "pass":

1. **Kaleb follows my MY TEST list exactly in the Godot editor.** Kaleb presses F5, clicks the listed buttons and compares the result with the "Expect:" lines.
2. **Kaleb requires a self-check before testing.**
   - I run `cd "/Users/kalebtovar/Desktop/Nasa Space App Challenge/how-did-we-get-here" && /Applications/Godot.app/Contents/MacOS/Godot --headless --path . --quit`, fix errors and warnings from our scripts, and show the final output.
   - "Show me the final check output." (2026-11-08)
3. **Visible proof for data steps.** For example, "okay, i see the print out, everything looks good" (2026-11-08) after the data-loader printout.
4. **Visual details on the dashboard.** "yes, the warning and max bar are good" (2026-11-08): the warning and limit markers and bars.
5. **Readability for kids.** Kaleb checks font sizes, the control hints and whether the arm or dashboard is hidden behind other UI.
6. **Nothing else broke.** Each feature's last step is a full playthrough from the intro to Try Again: "Confirm nothing else broke." (2026-11-08)
7. **Both outcomes play.** (2026-11-11: the shadow pass below is archived. Until the new flight log and report exist (TASKS.md steps 7–9), a "losing round" means a design with a red blocker at Review, and a "winning round" means one with none. The old tests below are kept for reference.) (From 2026-11-10 the shadow pass runs in Stage 4 Arrival, orbit type. These tests stay the same there.) A losing round (do nothing at the shadow pass → MISSION FAILED, Power alarm) and a winning round (reroute power → MISSION SUCCESS). The winning build is Medium solar + Basic camera + Large antenna (set in step 8, 2026-11-10).
   - Win: turn the heater off at the power panel when the alarm rings (about 20 s), then back on after "Out of the shadow!" (about 40 s) → MISSION SUCCESS.
   - Lose: the same build, do nothing → MISSION FAILED, with the "Power alarm" card.
   - Harder test: Small solar + Basic camera + Large antenna, where the heater can be off 30 s at most (for example, off at 22 s, back on by 52 s).
   - The old winning build, Large solar + High-res, fails the real budget limit since step 7e.
8. **Browser check.** After the web task, Kaleb plays both rounds in the browser from `build/web` using `python3 -m http.server`.
9. **Walkability for 3D layout.** Kaleb walks through every room and checks that the walls are solid.

**Optional, not required:** the "Try it" and "Bonus test" data edits in each report. Why: fastest path. "We can add it back later." (Kaleb, 2026-11-09)

---

## 7. How I work

- **How Kaleb gives tasks.** Each feature starts with a **pasted, structured brief**. It contains:
  - "Next task: ..."
  - A short "What it does" or layout section.
  - Rules: numbers go in `game_data.json`, text goes in `inner_voice.json` or `story.json`.
  - A numbered step list (6–9 steps).
  - It ends with **"Start with step 1 only."**
- **Step 1 is always read and plan, with no file changes.** For example: "Read the current walk scene. Tell me what moves to the new ship and what stays. Change no files."
- **The last step of each feature** is a full playthrough. After the web task it also includes a re-export to `build/web` and a browser test.
- **Step size.** One small, testable change per step: one scene, one connection, one visual fix. Most steps are passed within 5–15 minutes.
- **The step-and-check protocol** (pasted 2026-11-08, then "Same step-and-check system" for every later feature):
  1. **PLAN:** 2–3 sentences on what changes and which files.
  2. **DO:** change only what this step needs.
  3. **SELF-CHECK:** run Godot headless, fix errors and show the output.
  4. **MY TEST:** exactly what to click or press, and what should appear.
  5. **WAIT:** stop until Kaleb says pass. If the task asks for several steps in a row, wait after the last step only. On fail, fix only that problem.
     Why: "WAIT: stop until Kaleb says pass. If the task asks for several steps in a row, wait after the last step only. On fail, fix only that problem." (2026-11-09)
- **Kaleb's replies** are short: "pass", "PASS", "passs", "lets continue", "go". "pass" with no comment accepts my recommended defaults. Kaleb uses "pass, but..." for changes, though that was never needed.
- **Teaching focus.** "I am a beginner in Godot. Explain each step in simple English, so I can teach it to students." Every report includes teaching ideas, "Try it" and student challenges.
- **Decisions.** Kaleb answers multiple-choice questions by picking the "(Recommended)" option each time. Kaleb gives reasons in their own words only for gameplay goals, such as the red-data answer.
- **Deferral.** Kaleb parks polish for later ("we can do the cosmetics stuff at the end") and then pastes a single cosmetics list that mixes their items with mine.
- **What Kaleb does first in a session:** pastes a context brief:
  - who Kaleb is (Magikid coach, 5 students, Space Apps dates)
  - the tools (Godot 4, GDScript, beginner)
  - the game premise and scope
  - the data rules
  - "FIRST STEP: Do not write code yet... give me the folder and file structure and the list of build steps... Then wait for my approval."
- **What Kaleb does last in a session:** passes the last step, checks that it is committed, then stops. Agents commit each step that passes its self-check without waiting to be asked (see correction 12). (2026-11-09)
- **Session length.** The whole game was built in one long session (2026-11-08 00:34 to 2026-11-09 22:44) with 3 context compactions. It was started from another project's folder (Motion Studio).
- **Downloads.** Ask before downloading any model, package or tool. Source: Kaleb confirmed for this game (2026-11-09).

---

## 8. Tech setup

- **Engine:** Godot **4.7.2** (stable), GDScript. Installed at `/Applications/Godot.app`.
- **Renderer:** `gl_compatibility` (desktop and mobile) and `config/features = "4.7", "GL Compatibility"`. It was switched from Forward+ for the web build.
- **Physics:** Jolt Physics.
- **Window:** viewport 1280×720, stretch mode `canvas_items`, aspect `expand`.
- **Autoloads:**
  - `Data` (`scripts/autoload/Data.gd`): loads the 3 JSON files.
  - `GameState` (`scripts/autoload/GameState.gd`): choices, totals, limits, live mission math, failures.
  - `Textures` (`scripts/autoload/Textures.gd`): makes textures in code from the recipes in data.
- **Theme:** `theme/game_theme.tres`, set as the project theme (`gui/theme/custom`).
  - Type variations: TitleText, HeadingText, BodyText, SmallText, AccentText, TableText, BannerText, SmallButton, NavyPanel, VoiceBar, ScreenBackground.
  - Scenes use `theme_type_variation`, never per-node font sizes.
- **Plugins / addons:** none.
- **Folder structure:**
  ```
  how-did-we-get-here/
    project.godot  export_presets.cfg  icon.svg  .gitignore  .editorconfig  .gitattributes
    data/        game_data.json (all numbers)  story.json (screen text)  inner_voice.json (voice text)
    scenes/      one .tscn per screen/component; archive/ (old hangar walk, .gdignore'd)
    scripts/     one .gd per scene, same name; autoload/ (Data, GameState, Textures)
    theme/       game_theme.tres
    assets/characters/  general.png  janitor.png  (Kaleb's art)
    build/web/   web export (.gdignore'd, git-ignored)
  ```
- **Naming:**
  - Scenes and scripts use `snake_case` and share a name: `scenes/build.tscn` ↔ `scripts/build.gd`.
  - Some scripts have no scene and build their 3D in code from data: `ship.gd`, `spacecraft.gd`, `power_panel.gd`.
  - Autoload scripts use PascalCase (`Data.gd`, `GameState.gd`, `Textures.gd`).
  - Nodes use PascalCase. Unique `%Name` nodes are used for script access.
  - JSON keys use snake_case. Every JSON section has a `_readme` key in plain English for students.
- **Scenes:**
  - Screens: intro, character_select, mission_select, build, review, walk, debrief.
  - Components: choice_card, dashboard, dashboard_row, inner_voice_bar, player, arm, reroute_panel.
  - Test bench: dashboard_test.
- **How the code is written:**
  - `.tscn` files are written as text by Claude. Transform3D values are row-order and are written with `var_to_str`.
  - Poses are Marker3D nodes.
  - First-person overlay meshes use `no_depth_test` + `render_priority`.
  - 3D interaction uses Area3D reach zones with `meta part_id` and the group "player".
  - Input actions are created in code in `player.gd`.
  - Lights are shadowless in the ship, for web speed.
- **Self-check:**
  - From 2026-11-11 on Holden's Windows computer (PowerShell): `& "C:\Users\holde\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe" --headless --path "C:\Users\holde\onedrive\desktop\Nasa_space_apps\how-did-we-get-here-" --quit`. Git is not installed there. The Mac lines below are Kaleb's original setup.
  - Kaleb's command: `cd "/Users/kalebtovar/Desktop/Nasa Space App Challenge/how-did-we-get-here" && /Applications/Godot.app/Contents/MacOS/Godot --headless --path . --quit`. The `cd` matters because an agent's working folder can reset between commands.
  - I also kept a scratch copy of the project with a `Tester` autoload for automated playthroughs and screenshots, run windowed at 1280×720 in the foreground.
  - Don't use `--check-only --script`, because it reports false autoload errors.
- **Editing gotchas:**
  - Edit `game_data.json` by inserting text. Don't use `json.dump`, because it reformats the compact texture recipes.
  - Reload the project in the editor after adding files.
- **Export:** one preset, "Web".
  - Platform Web, `variant/thread_support=false` (single-threaded).
  - Export path `build/web/index.html`.
  - Export filter: all resources.
  - Needs the 4.7.2 export templates (`web_nothreads_*`).
- **Testing the web build on the Mac:** `cd build/web && python3 -m http.server 8000`, then open http://localhost:8000. Remote Deploy → Run in Browser also works.
- **Git:**
  - Initialized 2026-11-09 on branch `main`. First commit: `2e7a732`. It had 4 commits by the end of 2026-11-09. Run `git log --oneline` for the current history.
  - `.gitignore` covers `.godot/`, `/android/`, `/build/` and `.DS_Store`.
  - No global git identity is set on this Mac. The commit used Kaleb's name with `-c` flags. (guess on the exact method)

---

## 9. NASA data used

**Every NASA or mission number in `data/game_data.json` now has real NASA data or a written game-design choice (steps 7a–7g, 2026-11-10). Layout, look and timing settings (walk, arm, dashboard, ship, power_panel) are game-design choices with no source. No value is marked `"source": "PLACEHOLDER"`.** The steps: the solar panels and the heater (7a), the cameras (7b), the antennas (7c), the spacecraft base (7d), the mission limits (7e), the shadow pass event (7f), and the mission clock and the janitor's multipliers (7g). The table lists each dataset, its source, and where the game uses it. The full links are in each `source` string in `game_data.json`.

| Dataset | Source link | Where the game uses it |
|---|---|---|
| Mission limits for `mars_ice`: budget max 671 (MAVEN's total cost), mass max 1,031 kg (MRO dry mass), comms min 0.6 Mb/s (MRO's rate when Mars is farthest), lifetime min 24 months (MRO's two-year science phase). Power min 0 and data min 4 Gb/day: game-design choice. Every warning and bar_max: game-design choice | MAVEN press kit (Nov 2013), Quick Facts; MRO launch press kit (Aug 2005) | Build dashboard, Review table, walk dashboard, wrist light, debrief |
| Spacecraft base = MRO spacecraft without the swappable parts: budget 490 ($720M MRO total − 230 for the game costs of MRO's parts), mass 848.7 kg (1,031 kg MRO dry mass − 96.6 − 65 − 20.7; CTX stays in the base). Power −40: no public source. Communications 0, data 0, lifetime 30: game-design choice | MRO launch press kit (Aug 2005), Quick Facts | Totals on Build and Review, live values |
| Solar panel small / medium / large = Mars Odyssey array (32.3 kg, 750 W), MAVEN arrays (1,135 W; mass: no public source, keeps the game value 60 kg), MRO arrays (96.6 kg, 2,000 W). Costs: no public source. Lifetime bonus: game-design choice | NASA NTRS papers 20030065626 and 20070029236; Odyssey arrival and MRO launch press kits; MAVEN fact sheet 2013 | Build choices, 3D parts, shadow pass power math |
| Camera basic / high-res = MRO CTX (3 kg, 7 W, 4.8 Gb/day), MRO HiRISE (65 kg, 60 W, 16.4 Gb/day). Costs: no public source | NASA MRO science instruments page; CTX data guide in NASA PDS (ctxsis.pdf, "approximately 3.5 Tb"); HiRISE team science paper, McEwen et al. 2007 JGR ("more than 12 Tb") | Build choices, data collection rate, Reroute panel |
| Antenna small / large = Mars Odyssey 1.3 m high-gain antenna (3.15 kg with its medium-gain antenna, 0.124 Mb/s), MRO 3 m high-gain antenna (20.7 kg, 6 Mb/s). Both use 172 W (MRO's amplifier power used; for the small antenna a game-design choice). Costs: no public source | NASA PDS Odyssey radio science catalog (inst.cat, "Mass (kg) 3.150"); NASA Mars Relay Description 2010 ("124.425 kbps", and 5.2 Mbps for MRO); MRO telecom summary, DESCANSO (Table 2-1, "rates as high as 6 Mbps") | Build choices, Reroute panel |
| Heater = all MRO heaters: power −300 W. Off = 0.2 lifetime months lost per second (game-design choice) | NASA MRO thermal systems page ("As much as 300 watts") | Reroute panel, live lifetime |
| Shadow pass event (Mars eclipse): 100% solar drop (in shadow the panels make nothing and the batteries take over), batteries give 400 W (game-design choice; MRO's real batteries could give about 1,900 W: 2 × 1,600 Wh × 40% usable over a 40-minute shadow, so the alarm would never ring), lasts 20 s of the 60 s walk (game-design choice, about one third, like the real 40 of every 112 minutes), starts at 20 s and 15 s to fix (game-design choice) | MRO launch press kit (Aug 2005), Power Subsystem; JPL "Mars Reconnaissance Orbiter Preparing for Years Ahead" (Feb 9, 2018); archived JPL MRO "Electrical Power" page (2009) | Walk alarm, Reroute mini-game, Reroute panel "Power available" |
| Mission clock: 0.4 months per second (game-design choice: the 60 s walk = MRO's real 24-month primary science phase), 30.4 days per month (calendar math, 365.25 / 12; 24 × 30.4 = 730 days, so the basic camera collects about 3,500 Gb, like CTX's real 3.5 Tb), turned-off parts stop power, data and comms (game rule) | MRO launch press kit (Aug 2005), Quick Facts | Walk clock, data total, live limits, debrief mission time |
| Character multipliers (janitor all 1.0): game-design choice, 1.0 = the real mission limits from 7e, unchanged | none (game-design choice) | `GameState.get_limits` |

The inner-voice text uses real-world reasoning in plain words, for example "NASA can't pay for a mission that costs more than its budget." The mission concept, mapping subsurface ice on Mars, is NASA-style, but no dataset is cited. All placeholders were replaced with real NASA data or a written game-design choice on 2026-11-10. Students can check each source link, and any new made-up number must be marked PLACEHOLDER until it is replaced.

---

## 10. Unfinished work

- **Graybox ship, G5:** show the chosen part version in each room, for example the solar panels through the Power room window, with E inspection at the windows. Not started; Kaleb said "Do not start step 5." The spacecraft is still parked off-map at x=40 in `scenes/walk.tscn` as a stand-in until G5.
- **Graybox ship, G6:** a dashboard wall screen on the Bridge. My planned approach was a second dashboard on a SubViewport on a 3D quad. Not started.
- **Future stations:** the Science bay ("Future station: Data") and Comms room ("Future station: Comms") have markers only. No mini-games yet.
- **Real 3D models:** the `"model"` slot in each part version is empty.
- **Ideas I offered that Kaleb never picked up:**
  - an alarm sound
  - more characters (easier and harder) and more missions
  - a one-page student README or guide
  - uploading to itch.io
- **Leftover test and legacy code:**
  - `scenes/dashboard_test.tscn` and `scripts/dashboard_test.gd`, a dashboard test bench (guess: kept on purpose).
  - The unused compact-dashboard mode and the `"hint_small": "Tab = bigger"` text in `story.json`, left over from the corner dashboard. (guess)

---

## Uncertain lines answered by Kaleb (2026-11-09)

1. Limits (§2 Player experience): replaced with Kaleb's rule. Limits matter, but they're not so tight that the player plays scared.
2. Downloads (§7): kept. Kaleb confirmed it for this game.
3. Correction 11 (§4): kept as a rule. Every MY TEST includes "If you see an error" steps.
4. Data-only edits (§6): removed from the required checks. "Try it" and "Bonus test" edits are optional.
5. Inner voice tone (§2): kept. Kaleb chose it.

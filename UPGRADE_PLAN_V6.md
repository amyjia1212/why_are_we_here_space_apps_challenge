# UPGRADE PLAN V6: "How Did We Get Here?" (final copy)

Written Sunday Nov 15, 2026 by Fable, from the team's playtest word dump.
Build folder: **`How did we get here final`** only. Never touch `How did we get here + more stuff`
(that is the saved draft on GitHub). No git, no commits, no push from this folder.

**Which file wins.** This file wins over the older plans wherever they disagree. The rules in

**Be honest about time.** The team has **a few hours today**. The list has about 20 features and
the full list is several days of work. So the steps are in three tiers, ordered so the game works
after every step. Do Tier 1 fully. Then go down the list and **stop when time is up**. Every big
step has a **small version**: build the small version first.

**What I checked.** I read the code and data in the `final` folder, so file names below are real.
Step 0 still confirms the details before anything changes.

---

## 1. Team decisions made for this plan

| Topic | Decision |
|---|---|
| Real astronauts as crew | **Fact card.** Press E: the voice bar shows their name and portrait, and a narrator tells true, sourced facts. No made-up quotes, no first-person lines |
| Crew portraits | **Drawn in the game** (same style as `Portraits.gd`). No photos, nothing downloaded |
| "Gospel Fita" | The name could not be matched to a real person. Keep an **eighth crew slot marked PLACEHOLDER** for Amy |
| Time | A few hours. Small versions first |

Section 4 of `UPGRADE_PLAN_V3.md` (rules for real people) still applies, with one change: a game
character may now *look like* and *carry the name of* a real astronaut. It still never speaks
invented words.

## 2. DEFAULTS I chose (change any of them before the run)

1. **Student retry** works like the Janitor's (start the design again) but with the fewest hints.
2. **Life bars reaching zero** send the player back to the **start of the trip** (the design is
   kept). The report says which bar ran out.
3. **Launch dates:** Soonest = cheap to wait but a long trip and many scrubs. Best = short trip
   but months of waiting that cost budget. Numbers in section 4, step B1.
4. **Crew per mission** (three crew each, the same three for the whole mission):
   Moon = Christina Koch, Victor Glover, John Glenn. Mars = Peggy Whitson, Don Pettit,
   Nicole Mann. Venus = Sally Ride, Nicole Mann, Don Pettit.
5. **Achievement pictures** are drawn in code (a colored badge with a simple icon). No downloads.
6. **Space to jump** goes on the controls strip only if the player can already jump. Step 0
   checks. Adding a jump is not in this plan.
7. **Mars:** five survey sites, the player drills any three.

---

## 3. Step 0: Look before you touch (read-only, change nothing)

Report in a short list:

1. What happens today when a key instrument is missing at arrival (`arrival.gd` `fail_missing`),
   and where "Redesign and fly again" sends each character (`debrief.gd` `_on_redesign_pressed`,
   `game_data.json` stages > `redesign_to`).
2. Whether the player can jump (`player.gd`), and where the hint bar text is built (`Hud.gd`,
   `story.json` controls).
3. Why the launch caption ends in "head for ." (`story.json` launch > captions > burn uses
   `{planet}`; `launch.gd` line ~925 fills it from a `planet` variable that looks empty. The
   summary on line ~1205 uses `in_sentence`, which works).
4. How many crew walk the ship and which scenes they use (`flight.gd`, `ship_builder.gd`,
   `scenes/characters/staff1-3.tscn`, `character_base.gd`), and what look options
   `character_base.gd` already has (skin, hair, suit color).
5. How `Portraits.gd` draws a portrait and how `inner_voice_bar` gets its name and picture.
6. Where the weather scrub happens in `launch.gd` and how `extras.json` > `weather` is used.
7. How the Notebook page (N key) is laid out (`Notebook.gd`, `Hud.gd`).
8. Anything in this plan that does not match the real project.

Then go straight on to Tier 1 (no waiting).

---

## 4. Build steps

Sizes: **S** = under 20 minutes, **M** = 30 to 45 minutes, **L** = an hour or more.

### Tier 1: Quick fixes (do all of these first, about 90 minutes)

**A1. Fix "head for ." (S)**
`launch.gd`: fill the caption's `{planet}` the same way the summary does (`in_sentence`).
Done when: the Leaving Earth caption names Mars, Venus and the Moon correctly.

**A2. The report scrolls as one page. (S)**
`scenes/debrief.tscn`: the `Header` panel (title, stamp, Redesign and New mission buttons) sits
above the `Scroll` box and never moves, so the rest is a thin strip. Move `Header` inside
`Scroll/Body` as its first child. Do the same for the leaderboard block if it is pinned. Add a
small "Redesign and fly again" button at the very bottom of the page too, so nobody has to scroll
back up.
Done when: the mouse wheel scrolls everything and the report fills the screen.

**A3. Controls strip in the walking scenes. (S)**
A small see-through strip at the top of the screen in every scene with a walking player (rooms,
ship, planet): `WASD move · Mouse look · E use · Q question · Tab tablet` (plus `Space jump` only
if Step 0 found a jump). Each key is drawn as a little key cap so it reads as "these are buttons".
Text in `story.json` controls. Build it once in `Hud.gd`.
Done when: the strip shows in the Character Room, the ship and on the planet, and hides on 2D
screens.

**A4. "Press Q to learn more" in the build jobs. (S)**
Each build minigame (`minigame_assembly`, `minigame_hammer`, `minigame_fuel`) shows one line on
its start card: "Press Q to learn why real rockets need this." The Q ? tag pulses once when the
turn starts. Rough edge to fix here: the Q ? tag sits on top of the minigame's own "?" button
(`PROGRESS.md`), so move one of them.
Done when: a new player sees the Q reminder before each build job starts.

**A5. The voice bar goes back to "what to do now". (S)**
On the ship and the planet, the voice bar keeps the last clicked line forever. After
`voice_return_seconds` (6, in `game_data.json` hud) with no new line, it shows the current goal
(`get_goal_text()` already exists in `flight.gd` and `arrival.gd`). The goal picks the most
useful thing: a red alert first, then a low life bar ("I should eat something"), then the nearest
yellow task.
Done when: click a station, wait 6 seconds, and the bar shows the next thing to do.

**A6. Harder drill and an explanation first. (S)**
- `destinations.json` mars > tasks > drill: the green zone is `green_start 0.7` to
  `green_end 0.86`. Make it narrower (0.74 to 0.84, PLACEHOLDER) and let Holden tune it.
- Before the first drill, one paused card (Enter to start): "Stop the needle in the green. Then
  run! Mars ice turns to gas in the thin air. Reach the analyzer before it is gone." The Phoenix
  source is already in `extras.json` > `ice_race`.
Done when: the card shows once per run before the drill, and the drill takes a couple of tries.

**A7. Hammering looks like building a ship. (M)**
`minigame_hammer.gd` draws one panel with nails at random spots. Change it so the turn is a
**sequence of panels**: after every `nails_per_panel` (3) nails, the finished panel slides away
and the next one slides in. Each panel has its own shape (nose cone, body ring, fin, engine
skirt, door hatch) drawn with simple polygons, and the nails appear **along its seam** in order,
not at random. A small rocket outline in the corner fills in one piece per finished panel.
Shapes and counts go in `minigames.json` > hammer > `panels`. The score rule does not change.
Done when: a turn shows 4 or 5 different panels and the corner rocket fills up.

Tier 1 ends with: self-check, one quick playthrough, web export.

---

### Tier 2: Medium features (about 2 hours for all four)

**B1. Launch dates with clear trade-offs. (M)**
Today `extras.json` > `launch_window` has best / ok / poor, and the weather call has one
`amber_chance` for everyone. Change to:

| Date | Wait before launch | Trip | Fuel | Scrub risk | Launch timing |
|---|---|---|---|---|---|
| Soonest (poor) | none | long (×1.3) | +120 kg | high: 0.7 chance, up to 3 times | wide rings |
| Middle (ok) | some: +3 M$ | normal | 0 | medium: 0.4 chance, up to 2 times | normal |
| Best | long: +8 M$ | short (×0.85) | −60 kg | low: 0.15 chance, once at most | tight rings |

- New numbers per date in `extras.json`: `wait_cost`, `scrub_chance`, `max_scrubs` (all
  PLACEHOLDER). The weather call in `launch.gd` reads them from the picked date instead of the one
  shared `amber_chance`. After a wait, the weather can be amber **again** until `max_scrubs`.
- The Design Lab wall shows three chips per date: **Wait · Trip · Scrub risk**, so the trade-off
  is visible before picking.
- The General or the voice says one line when a second scrub hits: "That is what a poor date
  costs."
- Each scrub goes in the flight log and the report.
Done when: a Soonest date often scrubs twice or more, a Best date almost never does, and the wall
shows why each date is good and bad.

**B2. "Build complete" celebration. (M)**
A new short screen between the last build job and the launch: new stage `build_done` after
`minigame_fuel` in `game_data.json` stages > order (`scenes/build_done.tscn`,
`scripts/build_done.gd`).
- About 12 seconds, Enter skips after 3 seconds.
- Beat 1: the finished rocket (reuse `rocket_model.gd`) rolls out to the pad (reuse
  `launch_pad.gd`). Beat 2: three build scores count up (Assembly, Structure strength, Fuel) with
  a line each: "All that work went into this." Beat 3: the staff cheer (reuse the staff models,
  arms up, confetti particles, a cheer sound made in `Sfx.gd`).
- The cheer matches the result: a great build gets a loud cheer, a weak build gets a kind one
  ("It is not pretty, but it is ours.").
- Then a clear "Ready to launch" card with one amber button.
Done when: finishing the build feels like a moment, and the launch no longer starts in a flash.

**B3. A forgotten key instrument, and retries that fit the character. (M)**
Today the voice says the ice drill was forgotten, and Redesign sends everyone to the Design Lab.
Change the retry by character:

| Character | Where the retry starts | Help |
|---|---|---|
| Assistant Scientist (easy) | Straight at the **instruments** station | A bouncing amber **arrow** over the right pedestal, its name plate lit, and the voice says exactly what to pick and why |
| Janitor (medium) | The **first** Design Lab station. All choices are cleared, so everything is picked again | The "last time" lines from B4, no arrows |
| Lost Student (hard) | Same as the Janitor | Only short "that did not work" lines |

- The arrows and name call-outs show **once** per station, then stay away.
- For the Scientist, also show the arrow on any station whose last choice caused a failure
  (`GameState.most_blamed_choice`).
- This replaces the old rule "Try again keeps the part choices" for the Janitor and the Student.
  Drop that rule.
- Jump targets go in `game_data.json` (`redesign_by_character`), not in code.
Done when: fly Mars without the ice drill as each character and the three retries differ.

**B4. "Last time you chose this." (M)**
- When a run ends, save a copy of the choices and a verdict for each: **good**, **okay** or
  **bad** (bad = it is in a cause chain of a failure; okay = worked but cost a goal or points;
  good = the rest). Keep it in `GameState` (`last_attempt`) and in the save.
- On the next run, standing at a pedestal that was picked last time shows a small "Last time" tag
  and the voice says one line, written per character in `inner_voice.json` > `last_time`:
  - Scientist: "That was the correct choice." / "That could work too, but it is less effective."
    / "That was not the correct choice. The {part} could not {job}."
  - Janitor: "Last time we chose this. Good idea." / "Last time we chose this. Not a good idea."
  - Student: "This did not work." / "Maybe we should try something else."
- One line per station, once.
Done when: a second run shows the tag and the right line for a good, an okay and a bad choice.

Tier 2 ends with: self-check, a losing run and a winning run, web export.

---

### Tier 3: Big features (each one is an hour or more: build the small version, in this order)

**C1. Real astronauts as the crew. (L)**
- **Data first:** a new list `crew` in `nasa_resources.json`. One entry per person: `id`, `name`,
  `one_line`, `facts` (3 short true sentences), `source` (a NASA link for each fact), `look`
  (skin tone, hair color and style, age, suit color, glasses) and `missions` (where they crew).
  The seven people: Sally Ride, Christina Koch, Victor Glover, Peggy Whitson, Nicole Mann,
  Don Pettit, John Glenn. An eighth entry is `"source": "PLACEHOLDER"` for the unconfirmed name
  and **does not show in the game** until Amy fills it.
- **Facts are checked, not remembered.** The agent opens each astronaut's NASA biography page and
  copies facts from it. A fact with no NASA link stays PLACEHOLDER and is not shown. The team's
  one-line notes (first American woman in space, 328 days, Artemis II pilot, most days in space by
  an American, first Native American woman in space, space photography, first American to orbit
  Earth and back in space at 77) are the starting list to check.
- **Looks:** add look options to `character_base.gd` (skin tone, hair shape and color, gray hair
  and a slightly different build for an older person, suit color, name tag on the chest and a name
  over the head). Each astronaut gets a scene in `scenes/characters/`. Research each person's real
  look from their NASA portrait so the figure is respectful and correct. Be honest: a low-poly
  figure cannot be a perfect likeness. The **name tag, the drawn portrait and the fact card** do
  the recognizing.
- **Portraits:** drawn in `Portraits.gd` from the same `look` data.
- **Same crew all mission:** the three crew for the mission (DEFAULT 4 in section 2) replace the
  random staff on the ship and stay the same in the flight, on the planet and in the return.
- **Talking to them:** press E near one. The trip **pauses**. The voice bar changes to their name
  and portrait and shows the facts one at a time (Enter for the next, typed out with
  `TypewriterLabel`). The last line is always: "On this mission, {name} is part of your crew. That
  part is our game's idea." Then the bar goes back to the inner voice and time runs again.
- The room line from `ask_crew` stays as a fourth "what I am doing here" line in the narrator's
  voice ("{name} is checking the water tanks.").
- **Small version:** three crew on the Mars mission only, name tags and fact cards, looks by skin
  tone, hair and age only.
Done when: each crew member has a name, a matching look, a portrait and a paused fact card with
sources, and the same people are there for the whole mission.

**C2. Life on the ship: learn cards and life bars. (L)**
The ship already has food, water and air supplies (`supplies.json`, `GameState` supplies) and
stations `life_food`, `life_water`, `life_air`.
- **Three bars always on screen** in the flight: **Hunger, Hydration, Air**. They drain as the
  days pass (drain numbers in `supplies.json` > `needs`, PLACEHOLDER). They are the crew's needs,
  so they are separate from the six resources.
- **Refill by doing:** E at Food = eat (hunger up, food supply down). E at Water = drink. E at Air
  = swap the filter (air up). These are **mandatory**: the voice bar reminds the player when a bar
  drops under 30% (A5 does the reminding).
- **Consequence:** a bar under 15% slows the walk and shakes the screen a little. A bar at zero
  ends the trip: "The crew could not go on: no {thing}." DEFAULT: back to the start of the trip,
  design kept. It is saved as a finding for the report.
- **Learn cards:** the first time the player uses any station, the trip pauses and a full-screen
  card teaches it: a picture drawn in code, a title, two or three short true sentences and the
  NASA source. Examples: Food ("Astronauts eat freeze-dried food. Water is added back before
  eating."), Water ("Most water on the Space Station is recycled."), Air, Breakers, Solar panels,
  Dish, Sample freezer, Pilot seat, Space weather. Reuse the glossary entries the Q cards already
  use (`game_data.json` ship > `station_questions`); add entries where one is missing. Every new
  fact needs a NASA link or it stays PLACEHOLDER and is not shown.
- The ship has no brig. If the team wants one, it is a new room: not in this plan.
- **Report:** a new "Life on the ship" box: meals eaten, drinks, filters swapped, crew talked to,
  stations learned, photos taken, and what was skipped. The second run can compare with it.
- **Small version:** the three bars, eat / drink / filter, the zero rule, and learn cards for the
  three Life Support stations only.
Done when: ignoring food ends the trip, eating teaches one real fact, and the report lists what
the player did on the way.

**C3. Achievements. (L)**
- `data/achievements.json`: each one has `id`, `name`, `how` (shown to the player, so they know
  what to do), `icon`, `color`, `trigger`. A new autoload `Achievements.gd` saves to
  `user://achievements.json` and shows a toast ("Achievement: First Meal in Space") through `Hud`.
- **Three kinds:**
  - *Explore:* talk to each crew member (one achievement per astronaut, named for them), learn
    each station, eat the lucky peanuts, find the zero-g plush, take a postcard, open 10 Q cards.
  - *Do it a certain way:* perfect launch, perfect build, no quick fixes, all three ice samples
    saved, launch on the Best date, survive two scrubs.
  - *Outcomes, per mission:* success on the Moon / Mars / Venus, a perfect run (8 of 8 goals), a
    rough landing, "Forgot the whole point" (flew without the key instrument), "Over budget",
    "That was pretty bad" (score under a number in the data file). Every ending gets one, so
    there is always something new to find.
- **Notebook (N):** two tabs. Left = the words you have seen (as today). Right = achievements: a
  grid of badges, earned ones in color, the others gray with their name and how to get them.
- **Achievement board:** a big board on the wall **behind the player's start spot** in the
  Character Room, showing the same grid. Turn around to see it.
- A person's name is used for an achievement only for the crew in C1, with the true fact it
  points to.
- **Small version:** 12 achievements, the toast and the Notebook tab. The wall board comes last.
Done when: an achievement pops up the moment it is earned, stays after closing the game, and the
Notebook and the board list all of them.

**C4. Mars: survey first, then three ice samples. (L)**
Today Mars has one dig spot and one sample (`destinations.json` mars > arrival: reach, drill,
analyze).
- **Survey:** five marked sites. At each one, E runs the ground radar and shows a reading: how
  deep the ice is and how much there may be (numbers per site in the data file, PLACEHOLDER; the
  idea of radar finding buried ice has a NASA source in the game already). The tablet lists the
  sites surveyed.
- **Choose:** the player drills at any three. Deeper ice takes a longer drill hold. Farther sites
  mean a longer run back, so more ice is lost on the way (the ice race already exists).
- **Three samples:** the goal `sample_ice` needs three drills, and each analyze sends data. The
  task list shows "Ice samples 1 of 3".
- **Small version:** three fixed dig spots, no survey choice.
Done when: the Mars walk is survey, pick, drill, run, three times, and the checklist still adds
up.

**C5. A small game for each ship task. (L)**
Today every calm task is one press of E. Give the tasks a short hands-on step (5 to 10 seconds
each, on top of the ship, trip paused):
- Air filter: drag the dirty filter out, drag the clean one in (new, simple).
- Water: turn the valve to the mark (reuse `valve_dial`).
- Solar panels and Dish: turn until the bar is full (reuse `timed_press` or `arm`).
- Instruments: wipe the lens (reuse `minigame_clean`, shorter).
- Breakers: flip the tripped switch among six.
- Food: pick a food pouch and add water.
Numbers in `minigames.json` > `ship_tasks`. Emergencies keep the hold-E proper fix so the timers
stay fair.
- **Small version:** air filter and water only.
Done when: the calm tasks feel like doing the job, and none takes longer than 10 seconds.

Tier 3 ends with: self-check, one full run per mission if time allows, web export, browser test.

---

## 5. If time runs short

**Build order:** A1 to A7 → B1 → B2 → C1 small → C2 small → B3 → B4 → C3 small → C4 small →
C5 small → the full versions.

**Cut first:** C5 → C4 → the achievement wall board → B4 → the full versions of C1 and C2.

**Never cut:** A1, A2, A3, A5, A6. They are small and fix things every player hits.

**Stop** with at least 45 minutes left for: web export, one playthrough per mission, the video
and the form.

---

## 6. Who does what

| Person | Job for this plan |
|---|---|
| Holden (Lead Programmer) | Builds the steps and tests each tier |
| Amy (Science & Data) | Checks every astronaut fact and station fact has a NASA link. Confirms the eighth name |
| Rena (Head Writer) | "Last time" lines for the three characters, learn-card text, achievement names |
| Jeremy (Art Designer) | Checks each astronaut's look is respectful and correct. Picks the badge look |
| Richard (Video Editor) | Films the celebration scene and the crew fact cards once they work |

---

## 8. Every note, and where it is handled

| Note from the word dump | Step |
|---|---|
| Forgot the ice straw: Janitor starts over, Scientist is guided with arrows and names | B3 |
| "Last time you chose this" lines, different for each character | B4 |
| Show the buttons at the top of the walking screens | A3 |
| Report: the top part should scroll away | A2 |
| Build jobs: remind the player to press Q | A4 |
| Poor launch date should mean more reschedules; trade-offs for all dates | B1 |
| Cutscene and cheering between the build and the launch | B2 |
| Nailing game: change panel and shape every 2 or 3 nails | A7 |
| Talk to crew members, time pauses, name and picture in the voice bar | C1 |
| The crew are real astronauts, the same ones all mission, with matching looks | C1 |
| More things to interact with on the ship; learn about every station | C2, C5 |
| Hunger, hydration and air bars with real consequences | C2 |
| At the end, show what we did on the ship | C2 (report box) |
| Achievements, the board behind the player, the Notebook tab, outcome achievements | C3 |
| The voice bar should update to the task at hand after 5 or 6 seconds | A5 |
| A mini game for each space task | C5 |
| Mars: survey sites first, then three ice samples | C4 |
| Drill slider harder; explain the ice race first | A6 |
| "We are headed for ." has no destination | A1 |

## 9. Questions still open for the team

1. Who is "Gospel Fita"? Type the right name and Amy finds the NASA page.
2. Is "back to the start of the trip" the right penalty when a life bar hits zero, or should it be
   the whole mission?
3. Is the Student's retry (start the design again, few hints) right?
4. Does the coach agree that named astronaut figures with fact cards are fine for the submission?
   The rule "never put a student's real name or face in the game" is not affected, but real
   public figures are new for us.
5. Does the ship need a brig? There is none today.

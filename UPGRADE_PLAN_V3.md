# UPGRADE PLAN V3: "How Did We Get Here?"

Written Nov 14, 2026 (Saturday evening) by Fable, from the team's day-1 playtest notes.
Freeze is still **Sunday Nov 15, 2:00 pm**.

**How to use this file.** Put it in the game folder next to `UPGRADE_PLAN_V2.md` and `NASA_RESOURCES_PLAN.md`. Paste the kickoff prompt (section 8) into Claude Code.

**Which file wins.** This file wins over the older plans wherever they disagree. The rules in `CLAUDE.md` still apply (numbers in data files, PLACEHOLDER marking, PLAN / DO / SELF-CHECK / MY TEST / WAIT).

**Be honest about time.** There is less than one working day left. Most of this list is *words and data*, which is good news: Rena and Amy can write while Holden and Claude Code build. The steps are ordered so the game still works after every step. Stop at the freeze and submit what you have.

**What I have not seen.** I wrote this from the plans, not from the running game. Step 0 checks the plan against the real project before anything changes.

---

## 1. Three rules for this whole upgrade

Almost every note says the same thing in a different way: *too much on screen at once*. So:

1. **One job per screen.** Each screen answers one question ("Who are you?", "Where are we going?", "What can you spend?").
2. **Short first, more if you ask.** The screen shows the short version. The long version lives behind **Q**.
3. **Show it a bit at a time.** Text types out. Lists appear one line at a time. The player always knows where to look.

These add to the seven "fun first" rules in the NASA Resources Plan (20 words per pop-up, do then learn, and so on).

---

## 2. Decisions that change

Record each row in `AGENT_SOURCE.md` as a team decision dated Nov 14, 2026.

| Topic | Before | Now |
|---|---|---|
| Q key | Go back one choice | **Q = Question.** "Go back" moves to **Backspace** (DEFAULT) |
| Character Room wall | Name, difficulty, a sample of the inner voice | A plain description of the person: what they know, how much experience, how much help you get. No inner-voice text |
| Mission Room wall | Goal and trip time | A short, accurate mission card based on real NASA missions |
| Mission Briefing | One full page | Short cards that type out one at a time |
| The six resources | One line each on Your File | The General teaches them in a short cutscene. Remove them from Your File |
| Success checklist | 3 items per mission | 7–8 items, grouped by mission phase, covering the trip home |
| Mission patch | Shown | Removed everywhere |
| Planets in the ship window | Low-poly flat color | Real NASA map textures (an agreed exception to the art direction, for the window only) |
| Real people | None | Real astronauts appear as **sourced facts**, never as invented dialogue (section 4) |

---

## 3. Build steps

Sizes: **S** = under 30 minutes, **M** = about an hour, **L** = two hours or more.

### Step 0: Look before you touch (read-only)

Change nothing. Report:

1. Which V2 and N steps are actually finished in the project right now.
2. Every place the mission patch appears (scenes, textures, the rocket's logo panel).
3. Every place Q is used as "go back".
4. Where the Character Room and Mission Room wall text comes from (which data file and keys).
5. How the success checklist is stored and how its items get ticked.
6. How the planets outside the window are built (mesh, material, size).
7. Anything in this plan that does not match the real project.

### Phase A: Quick wins (do these first)

**A1. Take out the mission patch. (S)**
Remove it from every screen found in Step 0. If the rocket has a logo panel, make it a plain stripe. Move the patch files to `scenes/archive/`; do not delete them.
Done when: a full playthrough shows no patch and nothing has a hole where it used to be.

**A2. Q for Question. (M)**
- Change the Input Map: `ask_question` = Q, `go_back` = Backspace. Update the Controls screen and the hint bar.
- Anything the player can ask about gets a small **"Q ?"** tag when they look at it or stand near it.
- Pressing Q opens one small card: a title, 20 words or fewer, and one "real missions do this" line with its source. Q or Esc closes it. Q never pauses a running timer on purpose... **DEFAULT:** it *does* pause timers, so nobody is punished for being curious.
- The answers are the glossary from the NASA Resources Plan (steps N1 and N7). Do not make a second file. Add a `question_id` to objects and point it at a glossary entry. Opening a card also unlocks that word's Dictionary stamp.
- Two fun objects to place now:
  - **Lucky peanuts**: a jar on the launch control desk. (The story: a JPL tradition that began with the Ranger 7 mission in 1964. Amy confirms with a NASA or JPL link.)
  - **Zero-g indicator**: a small plushie on the Bridge. It sits on the dashboard on the pad and **floats** once the launch reaches STABLE. (The story: crews carry a small toy; when it floats, they know they are weightless. Amy confirms with a link.) **DEFAULT:** our plushie is an original design, not Snoopy or any real character.

Done when: Q works in the Choice Rooms, on the ship and on the planet; the two objects have cards; Backspace goes back.

**A3. A longer success checklist. (M)**
Group the list by phase. Each item is ticked by the stage where it happens.

| Phase | Moon | Mars | Venus | Ticked by |
|---|---|---|---|---|
| Launch | Launch safely | Launch safely | Launch safely | Launch ends at STABLE |
| Cruise | Cross to the Moon | Survive the trip to Mars | Survive the trip to Venus | Flight ends without losing the ship |
| Arrive | Enter lunar orbit | Enter Mars orbit | Enter Venus orbit | Orbit burn event in the flight |
| Land | Land on the Moon | Land on Mars | *(nobody lands on Venus)* | Start of the arrival scene |
| Science | Place 3 seismometers | Drill and sample the ice | Release the balloon · map the storms | Arrival tasks |
| Data | Send quake data through one lunar night | Send the ice data home | Send the storm data home | Arrival task + comms check |
| Depart | Lift off from the Moon | Lift off from Mars | Leave Venus orbit | Return cutscene |
| Home | Land safely on Earth | Land safely on Earth | Land safely on Earth | Return cutscene |

- The return cutscene is still a placeholder, so **DEFAULT:** Depart and Home are decided by a simple rule in data (fuel margin for Depart, structure strength for Home) and shown as one line each: "Smooth landing" or "Rough landing: here is why".
- The 400 "goals met" points are split evenly across the items. Keep the split in the data file.
- **Declutter:** never show all eight at once during play. The tablet shows the current phase's items and "3 of 8 done". The full list appears on the Briefing and the Report only.

Done when: each mission has its full list in `data/destinations.json`, every item can be ticked or failed, and the score still adds up.

### Phase B: Screens that explain better

**B1. Character Room wall. (S, mostly Rena)**
The wall stops quoting the inner voice. It shows a small "staff card" instead:

| Line | Example for the Lost Student |
|---|---|
| Who | "Lost Student. Came for a field trip. Took a wrong turn." |
| Knows | "Not much yet. Has never worked on a mission." |
| Help you get | "Almost no hints. You figure it out." |
| Difficulty | Hard (three dots, not a paragraph) |

Write the same four lines for the Assistant Scientist ("Works here. Knows the real terms. Gives clear hints.") and the Janitor ("Twenty years of overhearing scientists. Half-remembers things."). Text goes in `data/story.json`.
Done when: no wall text matches an inner-voice line, and each card is under 30 words.

**B2. Mission Room wall: "Where are we going?" (M, Rena + Amy)**
One mission card per planet, same four lines each:

1. **Where:** distance and trip time (Amy's real numbers).
2. **The job:** one sentence.
3. **Why it matters:** one sentence.
4. **NASA has done this:** one or two real missions (section 5).

Everything longer goes behind Q on the globe. Venus's card must say that nobody lands, and why.
Done when: each card is under 40 words and every fact has a source or says PLACEHOLDER.

**B3. Mission Briefing that types out. (M)**
- Split the page into **four cards**, 25 words or fewer each:
  1. Why we are going.
  2. What success looks like (the checklist, by phase, appearing one line at a time).
  3. The big trade-off.
  4. Real missions like this one.
- Text types out with the beep-talk voice. **Enter** once finishes the line, Enter again goes to the next card. Dots at the bottom show "card 2 of 4".
- A small amber arrow marks the line being typed, so the reader knows where to start.
- Key words are bold and have a "Q ?" tag.
- "What you start with" moves out of the briefing and into B4.
- Build the typewriter as **one reusable piece** (`TypewriterLabel`), and use it for the General, the inner voice and the Q cards too.

Done when: a new player can get through the briefing without ever seeing more than about 25 words at once.

**B4. The General's lesson: "Mission School." (L)**
A short cutscene right after the briefing and before the Design Rooms. The General stands at the wall screen like a teacher. Reuse the war-room set and the General's model.

- Six beats, one per resource: budget, mass, power, communications, data, mission lifetime.
- For each beat: the resource's tile lights up on the wall, the General says **one sentence** on what it means and **one sentence** with your limit for this mission, read from the data file ("You get this much. Not a dollar more.").
- Last beat: he changes one part on the wall and the ripple effect strip plays. "Touch one thing, and everything else moves. That is your whole job."
- About 45 seconds. Enter moves to the next beat. **Skip** appears after the first time. The lesson can be replayed from the tablet.
- Tone: a gruff teacher. The jokes are his; the facts stay true.
- Then remove the six resource lines from Your File, so the same thing is not explained twice.

Done when: the numbers the General says match the dashboard for all three missions.

### Phase C: Real astronauts, missions and rockets

Read section 4 before starting. This phase is mostly Amy and Rena filling data, with small code hooks.

**C1. One file for the real things. (M, Amy + Rena)**
Add `real_missions`, `real_rockets` and `astronaut_facts` lists to `data/nasa_resources.json`. Every entry: name, year, one sentence, source link, and where it shows in the game. Unchecked entries say `PLACEHOLDER` and do not ship.

**C2. Real rockets on the pedestals. (S–M)**
The three launch vehicles use real names, real payload capacity and real cost (Amy's list, FINAL GAME PLAN section 13, item 1). Each rocket's Q card names one real mission it launched. The launch header chip shows the real name.

**C3. Real missions in the right places. (S)**
- Mission Room wall, line 4 (step B2).
- Briefing card 4 (step B3).
- "Your mission twin" on the report (step N5), if that step has shipped.
- Flight log: one line per trip that compares you to a real mission ("Day 3. Apollo crews reached the Moon in about this long." Amy confirms the wording).

**C4. Astronauts in the intro and in the explanations. (M)**
- **Intro:** add one shot or one line to the cutscene where the General points at a wall of **name plaques** (text only) and says a true, sourced sentence about what real crews have done. Then the usual "You. I want you."
- **Explanations:** an "Astronaut fact" line on Q cards and in Mission School where one fits. Format: *name · mission · one true sentence · source.*
- Aim for 6 to 8 facts in total. Quality over number.

### Phase D: The view out the window (M)

**D1. Real Earth and Mars.**
- Wrap real NASA map images around the spheres: NASA's Blue Marble for Earth and a NASA/USGS global Mars mosaic for Mars. These are real NASA data, so they also count in the NASA Data field. Claude Code **asks before downloading**, and writes the exact source page in `AGENT_SOURCE.md`.
- Keep each image at 2048 pixels wide or smaller so the web build stays fast.
- Earth: a thin blue glow at the edge, a slow spin, a soft cloud layer if the map has one. Mars: a thin pale-orange edge, visible polar cap, slow spin.
- One strong light from the Sun's side so each planet has a day side and a night side.
- The planet grows as the day counter goes up.
- **Stretch:** the Moon and Venus the same way, so all three missions match.

Done when: the planets look real from the Bridge window and the web export still runs smoothly.

### Phase E: Declutter pass (M–L, Jeremy leads the look)

Do this last, because the steps above already remove a lot. Go screen by screen. For each one, take a screenshot and sort every item into **keep**, **move behind Q or Tab**, or **remove**.

Rules for every 2D screen and wall screen:

- At most **three panels** on screen.
- At most about **25 words** in any one panel.
- One amber accent per screen: it marks the *one* thing to do next.
- Numbers show only when they matter here. The six tiles show a bar and one number; before → after appears only for tiles that changed.
- The hint bar shows three keys at most. H shows the rest.
- The flight log shows the last four lines. Older lines scroll away.
- Same margins, same corner radius, same font sizes everywhere, all from `theme/game_theme.tres`.
- **The squint test:** squint at the screen. If you cannot tell what to do next, remove something.

Order to audit: Review / Equipment List → wall screen in the Design Rooms → flight HUD → tablet → report → start menu.

Done when: every screen passes the squint test and the 60-second test (play one minute without reading).

---

## 4. Rules for real people (read before Phase C)

Astronauts are real people, so we are careful.

- **Facts only.** We say what they really did, with a source. We never write made-up lines for them, and no toy-style character plays a real astronaut who talks.
- **Real quotes** are allowed only if they are short, exact and have a link to where NASA published them.
- **No photos by DEFAULT.** Use text plaques. If the team wants pictures, the coach checks NASA's media usage guidelines first.
- This matches our Validity goal and the rule that everything outside our own work is listed in References.

---

## 5. Starter list for Amy to check

These are from my memory, **not checked today**. Each one needs a NASA link before it goes in the game. Mission plans and rocket line-ups change, so check the planned ones most carefully.

| Use | Candidates |
|---|---|
| Moon missions | Apollo seismic experiments (the Apollo 11 crew set up the first one); Artemis program |
| Mars missions | Phoenix lander (dug down to ice); Mars Reconnaissance Orbiter (radar that looks for buried ice); InSight (a seismometer on Mars) |
| Venus missions | Magellan (radar map through the clouds, launched from a Space Shuttle); the Vega balloons; Akatsuki (Japan); DAVINCI (planned: check its current status) |
| Rockets | Whatever three the game already uses, plus the real rockets that launched the missions above. Check which are still flying |
| Astronaut facts: Moon | Apollo moonwalkers who set up science instruments; the Artemis II crew, who flew around the Moon |
| Astronaut facts: long trips | NASA astronauts who spent close to a year on the Space Station (good for "mission lifetime") |
| Astronaut facts: Venus | The Shuttle crew who released Magellan |
| Q objects | Lucky peanuts (JPL); zero-g indicators |

An honest note for the briefing: no astronaut has been to Mars or Venus. Our crews there are a game-design choice, and the game should say so in one line.

---

## 6. Who does what

| Person | Tonight and Sunday morning |
|---|---|
| Holden (Lead Programmer) | Runs Claude Code through Step 0 → A → B → D. Tests each step |
| Rena (Head Writer) | Staff cards (B1), mission cards (B2), briefing cards (B3), the General's 13 lines (B4), Q card text |
| Amy (Science & Data) | Checks section 5, fills sources, confirms every number the General says |
| Jeremy (Art Designer) | Leads the declutter audit (E), picks the planet look (D), designs the plushie |
| Richard (Video Editor) | Starts the 30-second video from what works now. Does not wait for these upgrades |

---

## 7. If time runs short

**Cut in this order:** D stretch (Moon and Venus textures) → C4 intro shot (keep the Q-card facts) → E for the start menu and report → B4 ripple demo beat → D1 (keep the old planets) → C3 flight log line.

**Never cut:** A1, A2, A3, B1, B3. They are small, and they fix the notes players will feel most.

**Stop at 2:00 pm Sunday.** Then: web export, one playthrough per mission, the video, the form.

---

## 8. Kickoff prompt (paste into Claude Code)

```
Read CLAUDE.md, AGENT_SOURCE.md, UPGRADE_PLAN_V2.md, NASA_RESOURCES_PLAN.md, then
UPGRADE_PLAN_V3.md. UPGRADE_PLAN_V3.md wins wherever they disagree.

Before changing anything: commit the current game and make a branch called upgrade-v3.

Start with Step 0. It is read-only: change no files. Give me the Step 0 report, then WAIT.

Then do ONE step at a time in this order: A1, A2, A3, B1, B2, B3, B4, C1–C4, D1, E.
For each step use PLAN / DO / SELF-CHECK / MY TEST / WAIT, and commit after I approve.

For every line of player-facing text: create the slot in the data file, mark it
PLACEHOLDER, and tell me which lines the writers need to fill. Never invent a real-looking
fact, name, number or quote. Never write dialogue for a real person. Ask before
downloading anything. If a step is bigger than expected, offer a smaller version.
```

---

## 9. Every note, and where it is handled

| Note | Step |
|---|---|
| Actual astronauts in the intro and for explaining things | C4, section 4 |
| Actual space missions and rockets | C1, C2, C3 |
| Character screen should not repeat the Inner Voice; explain experience | B1 |
| More and more accurate context for "where we are going" | B2, C3 |
| Too much to read in the briefing; type it out; show where to start | B3 |
| Cutscene where the General explains stats and constraints like a teacher | B4 |
| More tasks on the success checklist, through to landing at home | A3 |
| Take out the mission patch | A1 |
| Whole UI more pleasing, less clutter and info dumping | Section 1, E |
| Earth and Mars outside the window more detailed and realistic | D1 |
| Press Q for question (lucky peanuts, zero-g plushie) | A2 |

## 10. Questions for the team

1. Is **Backspace** fine for "go back" now that Q means Question?
2. Should Q pause timers during emergencies (kinder) or not (more tense)?
3. Real planet photos in the window break the "no photorealism" art rule. Is everyone, especially Jeremy, happy with that one exception?
4. Astronauts as text plaques only, or does the coach want to check NASA's rules so we can use photos?
5. Which planets matter most for the window if there is only time for two?

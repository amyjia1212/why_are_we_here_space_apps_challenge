# INNOVATION.md: what is new in "How Did We Get Here?"

## 1. The new idea in one sentence

Other mission design games assume the player is an expert. In our game, what the character knows is the
difficulty, and the character learns from failure.

## 2. How the two features work

### Feature A: "Three voices, one decision"

On three Design Lab stations (the launch vehicle, the orbit and the science instruments), the inner voice gives a
hint a moment after the station loads. The hint depends on who you picked. The Assistant Scientist (easy) names
the real term and gives a real number with its unit. The Janitor (medium) compares the choice to everyday life
with no technical words. The Student (hard) asks a question about the trade-off and never gives the answer. The
numbers are filled in by the game from its own data files (the same numbers the screens show), so a hint is
always true for the mission on screen.

- Text: `data/inner_voice.json` > `character_hints` (keyed by decision and by character). Writers can change the
  words without touching code; keep the `{blanks}`.
- Code: `scripts/autoload/Notebook.gd` (`hint_for`, `hint_values`), called from `scripts/choice_room.gd`
  (`show_station_hint`).

### Feature B: "The voice learns"

When a mission or a checkpoint fails, the game finds the main cause (for example the spacecraft was heavier than
the rocket can lift) and the character earns the word for it. The word goes into that character's Notebook with
a one-sentence meaning and a line about this run with its real numbers ("Your spacecraft was 87 kg over the Atlas
V 401's payload capacity of 2315 kg."). The report shows the new word at the top, and the Notebook (N key, or the
Notebook button in the Mission Room, Design Lab, Review and the report) shows "3 of 10 words earned"; words not
earned stay hidden. After a word is earned, that character's inner voice uses it in later hints (for example the
Janitor's rocket hint becomes "Now I know the word: payload capacity..."). The Notebook is saved on the computer
(`user://notebook.json`), so it stays between retries and after the game is closed. Each character keeps its own
Notebook.

- Text: `data/story.json` > `notebook` (terms, meanings, which failure teaches which word, the run lines) and the
  `learned` lines in `data/inner_voice.json` > `character_hints`.
- Code: `scripts/autoload/Notebook.gd` (`learn_from_run`, `ranked_failures`, save/load), `scripts/debrief.gd`
  (`add_notebook_card`), `scripts/autoload/Hud.gd` (`fill_notebook`, the button, the N key).
- Which word: the failures are ranked (build problems by how far over the limit they are, then a missing key
  instrument, then flight and arrival problems). The main cause's word is taught first; if the character already
  knows it, the next unknown word from the run is taught (so failing the same way twice teaches a second word).

## 3. Notebook terms

| Term | Meaning (in the game) | Taught by |
|---|---|---|
| Payload | The science instruments a spacecraft carries to do its job. | Not enough science data; a key instrument left behind |
| Launch vehicle | The rocket that carries the spacecraft from the ground into space. | Too heavy or over budget (second word) |
| Orbit | The curved path a spacecraft follows around a planet or moon. | The arrival burn ran short; struggling to leave |
| Orbital altitude | How high above the surface a spacecraft circles. | The arrival burn ran short (second word) |
| Payload capacity | The most mass a rocket can lift to where it is going. | Spacecraft heavier than the rocket can lift |
| Power consumption | How much electric power the parts use, measured in watts. | Not enough power; batteries ran out; dust on panels |
| Data rate | How fast data can be sent home, measured in megabits per second. | Signal too weak; data never sent home |
| Attitude control | The system that turns and points the spacecraft the right way. | Signal problems (second word) |
| Mission lifetime | How long the spacecraft is built to keep working. | Lifetime too short; the lunar night |
| Trade-off | A choice where you gain one thing and give up another. | Over budget; not enough data (second word) |

## 4. Every number a hint or a notebook line can use, and its source

All hint numbers come from the game's data files at the moment the hint is shown; nothing is typed into the hint
text. The run lines use the numbers from the player's own run (totals and limits).

| Number | Value in the game | Where / source |
|---|---|---|
| Falcon 9 cost and lift | 80.4 million $, 4020 kg | `game_data.json` launch_vehicles small: NASA PACE launch contract; KSC LSP fleet page |
| Atlas V 401 cost and lift | 148.3 million $ (shown as 148), 2315 kg | `game_data.json` launch_vehicles medium: NASA Lucy launch contract; NTRS 20130013405 (**Science & Data Lead: confirm the 2315 kg line in the PDF**) |
| Atlas V 541 cost and lift | 243 million $, 4050 kg | `game_data.json` launch_vehicles large: NASA Mars 2020 launch contract; DESCANSO monograph |
| Spacecraft mass | the player's current total (kg) | sum of the player's parts, instruments and orbit fuel (`GameState.get_totals`) |
| Mars orbit fuel | low 1149 kg, high 800 kg | `destinations.json`: low = MRO's real 1,149 kg (NSSDC); **high 800 kg is PLACEHOLDER (game-design choice, NEEDS SOURCE or team pass)** |
| Moon orbit fuel | low 600 kg, high 400 kg | `destinations.json`: **PLACEHOLDER (game-design choice, NEEDS SOURCE or team pass)** |
| Venus orbit fuel | low 1300 kg, high 900 kg | `destinations.json`: **PLACEHOLDER (game-design choice, NEEDS SOURCE or team pass)** |
| Ice drill power | 100 W | `destinations.json` mars instruments: **PLACEHOLDER (NEEDS SOURCE or team pass)** |
| Cloud camera power | 5.4 W | `destinations.json` venus instruments: Pioneer Venus Cloud Photopolarimeter (NSSDC) |
| Seismometer power | 7.1 W | `destinations.json` moon instruments: Apollo 15 Passive Seismic Experiment (NSSDC) |
| Signal needed (Mars) | 0.6 Mb/s | `destinations.json` mars limits: MRO launch press kit (JPL) |
| Signal needed (Moon) | 0.1 Mb/s | **PLACEHOLDER (game-design choice, team pass)** |
| Signal and lifetime needed (Venus), lifetime (Moon) | see `destinations.json` limits | each limit carries its own source or PLACEHOLDER note there |
| Mission lifetime needed (Mars) | 24 months | MRO primary science phase (JPL press kit) |
| Budgets | Mars 671, Moon 620, Venus 700 million $ | Mars: MAVEN press kit; Moon and Venus: game-design choices (see `destinations.json`) |
| Spare power, signal, lifetime | the player's current totals | sums of the player's parts (`GameState.get_totals`) |

**NEEDS SOURCE / team pass list (for the Science & Data Lead):** Mars high-orbit fuel (800 kg); Moon orbit fuel
(600 / 400 kg); Venus orbit fuel (1300 / 900 kg); ice drill power (100 W); Moon signal limit (0.1 Mb/s); the
Atlas V 401 2315 kg line. No hint text contains a typed-in number, so fixing a value in the data file fixes every
hint that uses it.

## 5. Use of Artificial Intelligence (for the submission form)

Claude (an AI assistant by Anthropic, used through Claude Code) wrote, with the Lead Programmer testing every step:
- Code: `scripts/autoload/Notebook.gd` (new), the hint hook in `scripts/choice_room.gd`, the notebook card and
  button in `scripts/debrief.gd`, the notebook page, button and N key in `scripts/autoload/Hud.gd`, the
  `Notebook` autoload line in `project.godot`, the `notebook` key in `data/game_data.json`.
- Text (drafts for the Head Writer to edit): all 48 hint lines (9 base, 39 learned) in `data/inner_voice.json` >
  `character_hints`, the 10 notebook meanings, the run-line templates and the notebook screen words in
  `data/story.json` > `notebook`, and this file.
- Not written by AI: the NASA numbers themselves (they were already in the game, each with its source), the
  game idea and the characters.

## 6. Demo path for the video (about 20 seconds of footage)

Getting to a failure takes a few minutes of real play, so record five short clips and cut them together.
Before recording: play one round as the Janitor and fail it (for example pick the Atlas V 401 and the largest
parts, or leave the key instrument behind). That run gives the Janitor a notebook word.

1. **Assistant Scientist, rocket (4 s).** Start a game, pick the Assistant Scientist (1, Enter), pick Mars (2,
   Enter), press Enter through the briefing and S to skip Mission School. In the Design Lab, wait 2 seconds on
   "Pick a rocket": the voice says "Payload capacity is the most mass a launch vehicle can lift. Our spacecraft
   is ... kg ..."
2. **Janitor, same rocket station (4 s).** New game as the Janitor (2, Enter), same clicks. The voice says
   "You can't fit a couch in a tiny car..." (or the learned line if the Janitor already has the word).
3. **The failure (4 s).** On the report after the failed run: the amber card "New word in your notebook: ...".
4. **The notebook (3 s).** Press N: "The Janitor's Notebook · 1 of 10 words earned" with the word, its meaning
   and "What happened: ...".
5. **The voice learned (4 s).** Press "Redesign and fly again", go back to the rocket station: the Janitor now
   says "Now I know the word: ...".

To reset the notebooks before recording: close the game and delete `notebook.json` in the game's user folder
(in Godot: Project > Open User Data Folder).

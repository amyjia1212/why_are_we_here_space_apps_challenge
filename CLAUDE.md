
# How Did We Get Here?

A Godot 4.7.2 (GDScript) mission-design game for the NASA Space Apps Challenge 2026
(Nov 14–15), challenge "Space Mission Design Game". The chief mission designer quits,
and the General puts a person in charge: an assistant scientist (easy), the janitor
(medium) or a lost student (hard). The player picks a mission (Moon, Mars or Venus),
designs the spacecraft against six resources (budget, mass, power, communications,
data, mission lifetime), helps build it in three minigames, watches an automatic
flight with a live flight log, does the science in a 3D walk-around, and gets a
report that explains why the mission went the way it did. Players are students aged
10–15.

The full design is `PLAN.md`. It started from Kaleb's template
(github.com/Kaleb-45/how-did-we-get-here), copied in on 2026-11-11.

## Team

Our Magikid team has five students. Coach Kaleb guides us. Holden is the Lead
Programmer, runs Claude Code and tests every step.

| Role | Student | What they own in the game |
| --- | --- | --- |
| Lead Programmer | Holden | Game code and mechanics |
| Art Designer | Jeremy | Art, textures, and 3D models |
| Head Writer | Rena | On-screen text, story, and the submission form |
| Video Editor | Richard | The 30-second demo video |
| Science & Data Lead | Amy | Real NASA numbers and their sources |

Never put a student's real name, face, or voice into the game, the video or the
submission page. Use role titles, the team name, or avatars.

## The challenge's literal ask

Every build must move us toward these six points. The game must let players:

1. Set a mission objective first, then the mission requirements.
2. Design the spacecraft and pick science instruments (the payload).
3. Choose a launch vehicle (rocket) and an orbit.
4. Manage six resources: budget, mass, power, communications, data, and mission
   lifetime. Use these exact names.
5. Simulate the mission and see a result.
6. See how one choice changes other parts of the mission (trade-offs).

## Rules

- `UPGRADE_PLAN_V2.md` is the design source (since 2026-11-14). It wins wherever it
  disagrees with `PLAN.md`, `GAME_PLAN.md` or an older line in `AGENT_SOURCE.md`.
  Build in the order of its section 5, one step at a time. Feature freeze: Sunday
  Nov 15, 2:00 pm.
- Follow `AGENT_SOURCE.md`. It records the design choices made so far.
- If `PLAN.md` gives a DEFAULT, use it and list it. Otherwise ask one short question.
- Ask each open design question once, as a blocking question, and record the answer
  in `AGENT_SOURCE.md`. Do not repeat it in later reports.
- Step 1 of a feature is read and plan only, with no file changes.
- Fix only what looks broken. Save cosmetic changes for the end of a feature.
- List any rough edges you noticed at the end of each step, but do not fix them
  unless Holden asks.
- Report every step as PLAN, DO, SELF-CHECK, MY TEST, then WAIT.
  - PLAN: 2–3 sentences on what changes and which files.
  - DO: change only what this step needs.
  - SELF-CHECK: run the command below, fix errors and warnings from our scripts,
    show the output.
  - MY TEST: exactly what to click or press in Godot, and what Holden should see.
  - WAIT: stop until Holden says pass. If the task asks for several steps in a row,
    wait after the last step only. On fail, fix only that problem.
- Every MY TEST includes "If you see an error" steps.
- After adding new files or settings, remind Holden to use Project → Reload Current
  Project before pressing Play.
- Only create or change files inside this folder.
- Scenes go in `scenes/`, scripts in `scripts/` with the same name as their scene.
  Old scenes we stop using move to `scenes/archive/` (Godot ignores that folder).
- Keep numbers in the data files, not in code: `data/game_data.json`,
  `destinations.json`, `events.json`, `supplies.json`, `timing.json`, `levels.json`,
  and the new `minigames.json` (`PLAN.md` section 7).
- Keep inner-voice text and dashboard warning text in `data/inner_voice.json`.
- Keep all other on-screen text (screen titles, buttons, card text, labels, subtitles)
  in `data/story.json`.
- Take all 2D colors and font sizes from the shared theme `theme/game_theme.tres`.
  Never set font sizes on a single node.
- The game must run in a browser: use the Compatibility renderer and a
  single-threaded Web export.
- Each batch of steps (a batch heading in `TASKS.md`) ends with one full playthrough,
  a re-export to `build/web`, and a browser test, done once at the end of the batch.
  The playthrough covers a losing round and a winning round. The agent does the
  re-export. MY TEST tells Holden how to do the browser test: in PowerShell,
  `cd build\web; python -m http.server 8000`, then open http://localhost:8000.
- Amy replaces PLACEHOLDER values with real NASA data and a source link, or a
  written game-design choice the team passes, before the final submission. Agents
  never invent real-looking numbers. Mark every new made-up number
  `"source": "PLACEHOLDER"`.
- Ask before downloading anything or adding an outside asset. When we use an outside
  image, sound, model, or code file, add it to `REFERENCES.md` with its link.
- This folder is our saved final draft (2026-11-15). It is the copy pushed to
  github.com/amyjia1212/why_are_we_here_space_apps_challenge. Do not change it, commit
  or push from it unless Holden asks. New changes go in "How did we get here final".
- Explain each step in short, simple English. Holden is learning Godot and shows this
  work to the team.

## Self-check command

Run this in PowerShell (the full `--path` means it works from any folder):

```
& "C:\Users\holde\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe" --headless --path "C:\Users\holde\Onedrive\Desktop\Nasa_space_apps\How did we get here + more stuff" --quit
```

(This is the "+ more stuff" copy, 2026-11-14. The original game is in "Original how did we get here".)

Don't use `--check-only --script`; it reports false autoload errors.

## Judging criteria

Check every feature against the five Space Apps judging criteria:

1. Impact (checked 2026-11-13: NASA's project submission guide names the five criteria
   Impact, Creativity, Validity, Relevance and Presentation. The full 2026 Judging and
   Awards Guide page would not load for the agent, so a human should still read it once:
   https://www.spaceappschallenge.org/resources/judging-awards-guide)
2. Creativity
3. Validity
4. Relevance
5. Presentation

## Keeping the record current

When Holden or the team makes a new design choice, add it to `AGENT_SOURCE.md`: one
line, then "Why:" in their own words and the date. If it replaces an earlier choice,
replace the old line in section 2, and move the old choice to section 3, Rejected
choices, with the date.

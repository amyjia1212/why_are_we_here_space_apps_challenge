# NASA RESOURCES PLAN: "How Did We Get Here?"

Written Nov 14, 2026 by Fable, from the challenge's Resources tab (NASA Data & Resources, plus the CSA partner resource). Freeze is still Sunday Nov 15, 2:00 pm.

**How to use this file.** It adds to `UPGRADE_PLAN_V2.md` and does not replace it. `UPGRADE_PLAN_V2.md` wins on build order.

**One honest thing first.** Almost nothing on the Resources tab is a table of numbers. They are guides, tools and example games. So "putting them in the game" means the game is organized and worded the way NASA does it, and each resource is named where it is used. Amy's list of real numbers is still needed. Nothing here fills it.

## 1. Fun first: seven rules

1. Do, then learn. A fact shows up right after the player does something, never before.
2. 20 words or fewer per pop-up. One idea each.
3. Real word + kid meaning, once. "Payload: the science tools your rocket carries." After that, just use the word.
4. Extra reading is a choice. Longer explanations live in the Space Dictionary (step N7). Nobody has to open it.
5. The characters carry the jokes. The facts stay true.
6. No quiz ever blocks the player. Learning is rewarded with stamps and score, not gates.
7. The 60-second test. A new player should be able to play one minute without reading anything.

## 2. Where each resource goes

| Resource | What it is | In our game | Cost |
|---|---|---|---|
| Design and Develop Science Missions | NASA's four mission segments, and the path need → requirements → design → verification → build | Four chapter badges on the progress strip; Review is renamed "Verification" | Small |
| Concept Maturity Levels (CML 1–4) | JPL's ladder for how grown-up a mission idea is | A level-up meter while designing | Small |
| Mission Design Lab (MDL) | How NASA teams study a concept, and the list of spacecraft disciplines | The Design Rooms are the Mission Design Lab; rooms named by discipline; Review becomes an equipment list | Words only |
| A Learning Game About Telescopes | Science goal limits your choices; ends by showing real missions like yours | Greyed-out options with a reason; "Your mission twin" on the report | Medium |
| CubeSat 101 | Every phase of a small mission, from ConOps to operations | A picture-strip ConOps on the briefing; real names for the minigames | Small |
| NASA Mission Viz | 3D viewer for trajectories and mission events | Look and feel of the Bridge trip map | Stretch |
| GMAT | NASA's real trajectory software | Named in the orbit room | Stretch |
| Visualize a Space Mission in VR (2023 challenge) | A checklist: concept, trajectory, timeline, 3D | A checklist for the Bridge wall screen. No VR | Cite only |
| CSA Digital Games and Activities | Canada's space games for kids | One sourced tip; tone reference | Words only |

## 3. Steps

- **N1** One data file for all of it: `data/nasa_resources.json` (name, link, how we use it, screen; glossary; every entry has a real source or PLACEHOLDER).
- **N2** Four segments (Launch, Space, Ground, User) as badges on the progress strip + the CML meter (CML 1 The idea: mission picked; CML 2 Could it work?: rocket and orbit pass the fit check; CML 3 Trade-off time: the player changes a part after seeing the ripple effect; CML 4 The real design: Review confirmed). Report's first line: "User segment: here is what scientists learned from your data."
- **N3** Call things what NASA calls them: Mission Design Lab; part rooms named by discipline (Power, Thermal, Structures, Attitude Control, Communications, Avionics); hint button = Office Hours; Review = Equipment List ("Verification: does it all add up?"); DEFAULT one end-of-mission line on the Briefing.
- **N4** Options that cannot work for the chosen mission are greyed out with a one-line reason from `data/destinations.json`. Bad ideas stay pickable.
- **N5** "Your mission twin" on the report: a real mission like the player's design (name, one sentence, source). `twins` list in `data/destinations.json`, PLACEHOLDER until Amy confirms.
- **N6** ConOps picture strip on the Briefing: launch → travel → arrive → do the science → send it home.
- **N7** Space Dictionary in the tablet: glossary words unlock as stamps the first time the player meets them ("12 of 30 stamps"). DEFAULT: a full set adds a small score bonus (in data).
- **N8** Real names for the minigames: one line on each tutorial card. Unchecked lines are PLACEHOLDER.
- **N9** Stretch: Bridge trip map views on keys 1/2/3; GMAT named in a "Did you know?" in the orbit room (ask before installing anything); one CSA tip with its link.

## 4. If time runs short

Cut in this order: N9 → N7 stamps (keep the plain glossary) → N8 → N6 → N5. Keep N1, N2 and N3.

## 5. For the submission form (Rena)

For each resource, write one sentence that says where the player sees it. Only list a resource if its step shipped. See `data/nasa_resources.json` ("submission_sentence").

## 7. Questions for the team

1. Should a full stamp set add to the score, or just be for fun? (Built: DEFAULT small bonus, in data.)
2. Is "Office Hours" a good name for hints? (Built as Office Hours.)
3. Does anyone have GMAT installed? (Built: named only, nothing installed.)
4. Who writes the glossary: Rena, Amy, or half each?

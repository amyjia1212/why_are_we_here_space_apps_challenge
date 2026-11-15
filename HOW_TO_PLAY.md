# How Did We Get Here? — How to play

*NASA Space Apps Challenge 2026 · Challenge: "Space Mission Design Game"*
*Made by a Magikid student team (Lead Programmer, Art Designer, Head Writer, Video
Editor, Science & Data Lead) with their coach.*

## The story

NASA's chief mission designer just quit. The General puts **you** in charge: the
assistant scientist (easy), the janitor (medium) or a lost student (hard). You have
never planned a space mission. Your **inner voice** helps you along. It is never
wrong, but it only knows what your character knows.

## What you do (about 10 minutes)

1. **Pick a mission:** the Moon, Mars or Venus. Each has a goal checklist.
2. **Pick a rocket and an orbit.** These are real rockets with their real NASA launch
   prices.
3. **Design the spacecraft:** 7 part types (frame, solar panels, battery, pointing,
   heat control, antenna, computer) plus science instruments.
4. **Review** the six resources: **budget, mass, power, communications, data and
   mission lifetime.** Any red row is a blocker that comes with a reason. You can
   still launch anyway and see what happens.
5. **Build it** in three short minigames, 1–4 players taking turns.
6. **Launch:** press Space when the ring hits the target.
7. **Flight:** walk around inside the ship. Events go well or badly *because of your
   design*: a weak part turns into a red emergency with a timer that you can still
   fix at the right station. The flight log on the Bridge wall says why each
   thing happened.
8. **Arrival:** walk around in a space suit and do the science.
9. **Mission report:** a score out of 1000, what went well, and what to fix. Then
   "Redesign and fly again" keeps your design, so you can change one thing and see
   the difference.

## Controls

| Where | Controls |
|---|---|
| Intro cutscene | Space, Enter or a click skips it |
| Setup, Build, Review, Report | Mouse |
| Assembly minigame | Type the name of the part being bolted on (FIN, TANK, SOLAR PANEL…) |
| Hammering minigame | Click each nail on the rocket panel before it slides back out |
| Fueling minigame | Drag the valve wheel's knob until the fuel gauge reaches the orange mark |
| Any minigame | "?" shows the how-to card again |
| Launch | Space when the ring lines up with the target |
| Flight (inside the ship) | WASD to walk, Shift to run, E at a glowing pad (hold E = proper fix, R = quick fix), Tab for the tablet, 1/2/3 switch the Bridge map view, Enter skips to the arrival after your first trip |
| Mission Briefing, Mission School | Enter finishes the line, Enter again goes on; S skips Mission School after the first time |
| Choice Rooms | E or 1/2/3 to look, Enter to confirm, Backspace to go back one choice |
| Mission Design Lab | O = Office Hours (a hint from your inner voice) |
| Anywhere | Q = Question: when you see "Q ?", press Q for a short card about that thing (the game pauses) |
| Anywhere | G = Space Dictionary: collect all 45 word stamps for a score bonus · Tab then L = Mission School again |
| Arrival walk | WASD to walk, mouse to look, Space to jump, E to use, Esc frees the mouse, Enter leaves when done |

## How to win each mission (spoilers)

The mission succeeds when every checklist goal is done. Reading the inner voice and
the ripple strip on the Build screen is the real way to learn. These hints are for
judges who want to see a win quickly.

- **Mars (collect ice data):** pack the **ice drill**, which the goal needs. The small
  antenna is too weak for Mars, so pick a **medium or large antenna**. At the dig
  spot, hold E and let go in the green zone, then send the data from the analyzer.
- **Moon (moonquake network):** pack the **seismometer** and place all three, far
  apart. The lunar night lasts about two Earth weeks. A bigger battery **and** better
  heat control keep the seismometers warm. On the Atlas V 401 that goes over budget,
  but the cheaper Falcon 9 fits.
- **Venus (storms from orbit):** nobody lands. The surface would melt lead. Pack the
  **cloud camera** and the **balloon probe**, and pick a medium antenna. Unpack the
  spectrometer, or fly on the Falcon 9, to stay inside the budget.

## Where the challenge's six points are

| The challenge asks players to… | In the game |
|---|---|
| Set an objective, then requirements | Choose a mission and its goal checklist; the limits come from it |
| Design the spacecraft and pick instruments | Build screen: 7 part types plus instruments, each with real trade-offs |
| Choose a launch vehicle and an orbit | Rocket screen (real rockets) and orbit screen (lower orbit = more fuel = more mass) |
| Manage the six resources | The dashboard is always on screen, with green / yellow / red rows |
| Simulate the mission and see a result | Launch, flight log, arrival walk and mission report |
| See how one choice changes others | The ripple strip, for example "Large frame → Mission lifetime +6 months → Budget +30" |

## Real NASA numbers (a few examples)

Every number in the game has a source written next to it in the `data/` files. It is
a NASA link, or it is marked as a game-design choice. Some examples:

- **Mars spacecraft parts** are based on the Mars Reconnaissance Orbiter (MRO): solar
  arrays, the HiRISE and Context cameras, and the 3-meter dish (JPL press kit,
  NSSDC).
- **Budget limit for Mars:** MAVEN's real total cost, $671 million (MAVEN press kit).
- **Rockets:** NASA's published launch contract prices (PACE on Falcon 9, $80.4 M;
  Lucy on Atlas V 401, $148.3 M; Mars 2020 on Atlas V 541, $243 M).
- **Trip lengths:** MRO took 210 days to Mars, Pioneer Venus took 198 days to Venus,
  and Apollo 8 took about 3 days to the Moon.
- **Radio delay:** 3 to 22 minutes to Mars and 1.3 seconds to the Moon (NASA Science,
  Apollo Lunar Surface Journal).
- **Instruments:** the Apollo seismometer (11.5 kg, 7.1 W), the Vega 1 balloon
  (21.5 kg) and the Magellan radar (210 W).

Values still marked **PLACEHOLDER** are game-design guesses. The team is still
checking them.

## Running it

- **In a browser:** open the game's web link, then click once so sound can play.
- **From the files:** in PowerShell, run `cd build\web; python -m http.server 8000`,
  then open http://localhost:8000.
- **In Godot 4.7:** open the `how-did-we-get-here-` folder and press Play.

Made with Godot 4 (GDScript). All shapes, textures and sounds are made in code. No
outside art, models or sound files are used.

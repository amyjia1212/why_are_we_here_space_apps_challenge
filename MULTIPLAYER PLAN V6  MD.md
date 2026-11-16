# MULTIPLAYER PLAN V6: "How Did We Get Here?"

Written Nov 15, 2026 (Sunday, 5:30 pm) by Fable, from Holden's note.

**How to use this file.** Put it in the game folder as `MULTIPLAYER_PLAN_V6.md`.

**Which file wins.** This file replaces the "True multiplayer" part of `FINAL GAME PLAN` section 7 and Steps 27 and 28 of `UPGRADE_PLAN_V2.md`. Where this plan says **DEFAULT**, build it that way and list it in the report so the team can change it.

**Be honest about time.** The freeze was 2:00 pm today and the form is due tonight. This plan is about **two to three build days**. Phase A alone is one long afternoon. So:

- If the submission is not in yet, **submit first**. Do not merge any of this into the build you submit.
- Build on a branch called `multiplayer-v6`. The submitted game stays untouched.
- In the form, multiplayer on separate computers can go in the one short "future plans" paragraph.

**What I have not seen.** I wrote this from the plans, not from the running game. Step 0 checks it against the real project.

---

## 1. Decisions that change

| Topic | Before | Now |
|---|---|---|
| Where players sit | Everyone on one computer | Each player on their own computer, joined by a party code. Bots can fill seats |
| Who picks the parts | The host picks, the others watch | Everyone votes. Most votes wins |
| Bot scores | For show only | Count in the team average. Random 85 to 100 |
| Difficulty | Same for any team size | Grows with the number of players (section 3) |
| Launch | One GO button | Every player must say GO |
| Minigames | Take turns | Everyone plays at the same time on their own screen. The minigames themselves do not change |

---

## 2. The party screen

```
How many players? (1–4)
 ├─ 1  → solo, same as today. No party screen, no code.
 └─ 2–4 → PARTY SCREEN
      ├─ CREATE A PARTY
      │    └─ Who fills the other seats?
      │         ├─ Other players join → shows the code (like KXTR) and the seat list
      │         └─ Play with bots     → seats fill with bots. No code, no internet needed
      └─ JOIN A PARTY
           └─ Type the code → lobby → wait for the party leader to start
```

- The player who creates the party is the **party leader**.
- **The lobby** shows one row per seat: portrait, name, and "Waiting…", "Joined" or "Bot". The leader can turn any empty seat into a bot, so 2 humans + 1 bot works. START lights up when every seat is filled.
- **The code** is 4 letters, made by the relay (section 4) so two parties never share one. It uses no vowels and no look-alike letters, so it cannot spell a word and is easy to read out loud. Capital or small letters both work.
- A player who joins already answered "how many players". **DEFAULT:** that answer is ignored and the party's size wins. A full party says "This party is full".
- Nobody can join after START.
- Each player keeps their own character and inner voice. Limits and scoring are already the same for every character, so nothing needs to change there.
- Wrong code, lost connection and a full party each get one plain sentence, not an error number.

---

## 3. The rules

**3a. Harder with more players.** Bots count as players here.

| Players | Problems on the ship | Air, water and food go down | Data to gather |
|---|---|---|---|
| 1 | ×1 | ×1.0 | ×1 |
| 2 | ×2 | ×1.2 | ×2 |
| 3 | ×3 | ×1.3 | ×3 |
| 4 | ×4 | ×1.4 | ×4 |

- The first two columns are Holden's numbers. The data column is my **DEFAULT**, because the note says "more" without a number.
- The trip stays the same length, so more problems means more than one at the same time.
- The briefing gets one new line so the crew knows: "Crew of 3: 3× the problems, supplies drain 1.3× faster, 3× the data."

**3b. Voting on parts.**

- Every choice made after the party forms is a vote: mission, rocket, orbit, the seven part categories, instruments.
- Each player gets **one vote** per choice. Preview with 1 / 2 / 3 as today; Enter locks the vote. A vote can be changed until voting ends.
- Each pedestal's nameplate shows a dot for every vote it has. The screen shows "2 of 3 votes in".
- Voting ends when every human has voted, or after 60 seconds. The option with the most votes is picked, snaps onto the spacecraft, and everyone moves to the next room together.
- **Tie (DEFAULT):** "Tie! Talk it over." One 20-second revote between the tied options. Still tied: a coin flip. With 2 players, ties will happen a lot, so this rule matters.
- **Instruments** allow more than one pick. Each player marks the ones they want. An instrument is in when more than half the party wants it; exactly half uses the tie rule.
- If time runs out with no votes at all, the timer starts again.

**3c. Launch.** The GO / NO-GO poll gets a crew row for every player. GO FOR LAUNCH stays locked until every row says GO. A player can switch between GO and NO-GO. "Scrub – back to build" still works. **DEFAULT:** once launched, each player does the timed presses on their own screen and the team uses the average, the same way as the minigames.

**3d. Minigames.** All players start on the same countdown, play on their own screen, and send one number (0 to 100) at the end. Then every screen shows every score and the team average. The average feeds build quality, structure strength and fuel loaded exactly as it does now.

**3e. What bots do.**

| Moment | The bot | Whose rule |
|---|---|---|
| Minigames | Gets a random whole number from 85 to 100, new for each minigame | Holden |
| Votes | Votes for whatever the humans picked most. Bots never change who wins | Holden |
| Launch | Always GO | Holden |
| Ready checks | Always ready | DEFAULT |
| Ship problems | If nobody has started a problem after 5 seconds, a free bot takes it and fixes it in 10 seconds | DEFAULT |
| Planet data | Each bot gathers its share at a steady pace | DEFAULT |

The last two rows are needed. Without them, one human with three bots would face four times the problems alone. The times are game-design choices in the data file.

**3f. One data file for all of it.** New file `data/multiplayer.json`:

```json
{
  "relay_url": "PLACEHOLDER: the coach fills this in. It starts with wss://",
  "max_players": 4,
  "vote_seconds": 60,
  "tie_revote_seconds": 20,
  "scaling": {
    "1": { "ship_problems": 1, "supply_drain": 1.0, "data_goal": 1 },
    "2": { "ship_problems": 2, "supply_drain": 1.2, "data_goal": 2 },
    "3": { "ship_problems": 3, "supply_drain": 1.3, "data_goal": 3 },
    "4": { "ship_problems": 4, "supply_drain": 1.4, "data_goal": 4 }
  },
  "bots": {
    "minigame_score_min": 85,
    "minigame_score_max": 100,
    "take_problem_after_seconds": 5,
    "fix_problem_in_seconds": 10
  }
}
```

---

## 4. How the computers talk

**The limit.** Our game runs in a browser. A browser game cannot be the host that other players connect to: Godot's web builds can only connect *out*, as a WebSocket client or over WebRTC. So separate computers need one small program on the internet that sits in the middle. Bots-only parties do not need it.

**The choice: a tiny relay.** Think of a mail carrier. It passes notes between the computers in one party and does not read them.

The relay does only this:

1. Make a party and hand back a code.
2. Let a player join a party by its code (4 players at most).
3. Pass every message from one player to the others in the same party.
4. Tell the party when someone joins or leaves. Close the party when it is empty.

It saves nothing and knows nothing about the game. **All the game rules stay in Godot**, so the relay should never need to change once it works. It is about 100 lines and lives in a `relay/` folder in the repo.

**What the coach has to do.**

- Pick where the relay runs. The game page is served over `https`, so the relay address must start with `wss://` (the secure kind). Browsers block the plain `ws://` kind from an `https` page.
- Free hosting changes often, and accounts belong to an adult. The team suggests options and **asks before downloading or signing up for anything**.
- Some free hosts go to sleep when nobody is using them. The game shows "Connecting…" for up to 15 seconds before it gives up.

**Testing without the internet.** Run the relay on one laptop and connect to `ws://localhost`. Godot's Debug menu can run more than one copy of the game at once, so one person can test a 2-player party alone.

**In Godot.** One new autoload, `Net`, built on `WebSocketPeer`. It has `create_party()`, `join_party(code)`, `send(type, data)` and a signal for messages that arrive. Messages are small JSON notes. A second autoload, `Party`, holds the seat list and answers "how many players?", "am I the leader?" and "is this seat a bot?".

---

## 5. The one big rule: the leader's computer is the boss

- The party leader's game holds the real `GameState`. It already has `to_dict()` and `from_dict()`, which is what gets sent.
- Other players send **requests**: "I vote 2", "my score is 91", "I fixed the leak", "GO". The leader's game decides and sends the result to everyone.
- **Every dice roll happens on the leader's computer**: bot scores, coin flips, which problems appear. Then it is sent. Otherwise two screens would disagree.
- Bots live on the leader's computer.
- Only the leader's game changes the stage. Everyone else follows.
- **If a player leaves:** their seat becomes a bot and the mission goes on.
- **If the leader leaves (DEFAULT):** the mission ends for everyone with "The party leader left", and goes back to the start menu. Picking a new leader mid-mission is too big for now.

---

## 6. Every stage, in a party

| Stage | What happens |
|---|---|
| Start menu, cutscene, name, character, player count | Each player alone, as today |
| Party screen and lobby | Create or join. The leader presses START |
| Your File, Briefing, Mission School | Everyone reads at their own speed and presses **Ready**. It moves on when all are ready. After 20 seconds the leader gets a quiet "Go anyway" button |
| Mission Room and Design Rooms | Vote (3b) |
| Review | Ready check |
| Minigames | Same time, own screen, scores averaged (3d) |
| Launch | Everyone says GO (3c) |
| Flight on the ship | One shared list of problems and one shared supply of air, water and food. Fixing a problem fixes it for everyone. The flight log says who fixed it |
| Arrival | One shared data goal. Everyone's work adds to it |
| Report | One team score. Each player's line shows their minigame scores, problems fixed and data gathered |
| Leaderboard | Saved on each computer with the party's names |
| Redesign and fly again | The leader chooses. The party stays together |

---

## 7. Build steps

Sizes: **S** = under 30 minutes, **M** = about an hour, **L** = two hours or more.

### Step 0: Look before you touch (read-only)

Change nothing. Report:

1. The current `stages.order`, and what the player count does in the game today (turns, bots, averaging, or nothing).
2. Whether **all** mission state is in `GameState` and survives `to_dict()` / `from_dict()`: the ship's air, water and food, open problems, timers, planet progress, the checklist.
3. How ship problems are picked and timed, where their count comes from, and whether two can run at once. Where the air, water and food drain rates live.
4. How data gathering on the planet is counted for each mission.
5. How a minigame reports its score, how a Choice Room confirms a pick, and how GO FOR LAUNCH is wired.
6. Any bots that exist already and what they do.
7. Every use of random numbers.
8. Anything in this plan that does not match the real project.

### Phase A: A party with bots, on one computer

No internet needed. Every rule in section 3 gets built and tested here. The game works after each step.

**A1. Party and lobby. (M)** The `Party` autoload, the party screen and the lobby from section 2. Bot names come from the data file and are made up. Join shows the code box but is wired in Phase B.
Done when: pick 3 players → Create → Play with bots → the lobby shows you and two bots → START goes to the next stage. Picking 1 player never shows the party screen.

**A2. Harder with more players. (M)** Read the scaling table. Multiply the number of ship problems, the supply drain and the data goal. Add the bot helper rules for the ship and the planet. Add the briefing line.
Done when: the same mission with 1, 2 and 4 seats shows the right numbers, and a solo run is exactly as it was.

**A3. Bot scores in the minigames. (S)** Roll each bot's score when the minigame ends. Show every score and the average. Change nothing inside the minigame scenes.
Done when: bot scores are always 85 to 100, change every minigame, and the average is right.

**A4. Voting. (M–L)** Section 3b. With only bots your vote always wins, so add a **debug key that casts a fake human vote**. Take it out of the menu later, not out of the code.
Done when: a win, a tie, a revote and a coin flip all work with fake votes, and instruments work with more than one pick.
**Smaller version:** skip the revote and go straight to the coin flip.

**A5. Everyone says GO. (S)** Crew rows in the poll, the locked button, bots always GO. Also build the shared **Ready check** here and use it on the briefing and Review.
Done when: with a fake human set to NO-GO, the launch cannot start.

**A6. Team report. (S)** One team score, one line per player, leaderboard entry with the party's names.

### Phase B: Real players on separate computers

**B1. Plan the connection. (S, read-only, with the coach)** The team proposes how to build the relay and where it could run. The coach decides. Write the decision down. Nothing is downloaded before the coach says yes.

**B2. The relay and `Net`. (M–L)** Build the relay and the autoload. Test on one laptop with two game windows.
Done when: one window creates, the other joins with the code, both lobbies match, and these all show a clear message: wrong code, full party, a player leaving, the leader leaving.

**B3. Move together. (M)** The leader sends "go to this stage" with the `GameState`. Everyone follows. A joined player who is waiting sees "Waiting for the party leader".
Done when: two windows stay on the same stage from the lobby to the report.

**B4. Real answers in place of bot answers. (M)** Votes, Ready checks, minigame scores and GO now come over the network. A player who has not sent a minigame score 15 seconds after time is up gets a 0, so nobody waits forever.
Done when: two windows can vote against each other, tie, and block a launch.

**B5. The ship and the planet together. (L)** The leader sends the shared state (supplies, open problems, timers, data gathered) a few times a second and whenever it changes. Players send "I started this" and "I fixed this". The tablet map shows the other players as dots.
Done when: a problem fixed in one window disappears in the other, and both windows show the same supplies.
**Smaller version:** every player gets their own ship with their share of the problems, and only the results are sent at the end, like a minigame score. Much less to build, but it feels less like one crew.

**B6. Stretch: see each other. (M)** Send each player's position about 5 times a second. Show the other players as their toy characters with a name tag. No collisions.

**B7. Test for real. (M)** Two computers, then four, in the **web export**, on the network you will really use. School and event Wi-Fi sometimes blocks this kind of connection, so test there early.

- [ ] Create, join, start
- [ ] Vote: win, tie, coin flip
- [ ] All three minigames, scores match on every screen
- [ ] NO-GO blocks the launch
- [ ] Ship problems and supplies match on every screen
- [ ] A player closes their tab mid-mission: a bot takes over
- [ ] The leader closes their tab: everyone gets the message
- [ ] Solo play is unchanged

---

## 8. If time runs short

**Cut in this order:** B6 (seeing each other) → the tie revote (coin flip only) → the Ready check on briefings (leader presses Enter for everyone) → the full B5 (use the smaller version) → instruments voting (leader picks instruments).

**Never cut:** Phase A steps 1, 2, 3 and 5; the "leader's computer is the boss" rule; the solo game working exactly as before.

**A good place to stop:** the end of Phase A. The game then supports 2 to 4 players with bots, with every one of Holden's rules working, and needs no server.

---

## 9. Safety rules

- Commit first. Work on `multiplayer-v6`. Commit after each approved step.
- **Solo must not change.** After every step, play one solo mission start to finish.
- **Names.** In a party, the name a player types shows on the other players' screens. The relay stores nothing and keeps no list of names. Use made-up names in any video.
- **No chat box and no public list of parties (DEFAULT).** The only way in is a code someone tells you. That keeps strangers out.
- The relay address lives in `data/multiplayer.json`, never in code.
- Test in the web export after B2, B3 and B5.

---

## 10. Who does what

| Person | Job |
|---|---|
| Holden (Lead Programmer) | Builds Step 0 → A → B. Tests with two game windows |
| The coach | Decides where the relay runs and owns that account (B1) |
| Amy (Science & Data) | Playtests the scaling table. Is ×4 problems fair with 4 players? Changes the numbers in the data file |
| Rena (Head Writer) | Party screen text, bot names, waiting lines, error sentences, "Tie! Talk it over." |
| Jeremy (Art Designer) | The lobby, vote dots on the nameplates, crew rows in the launch poll, all from the V4 look table |
| Richard (Video Editor) | A two-computer clip once B4 works. Screens only, no faces or real names |

---

## 11. Holden's note, and where it is handled

| Note | Where |
|---|---|
| Two or more players on separate computers | Sections 4 and 5, Phase B |
| A code for each game; others join by entering it | Section 2, B2 |
| Only offer the code with 2 or more players | Section 2, A1 |
| Create a party or join a party | Section 2, A1 |
| Other players join, or play with bots | Section 2, A1 |
| 2 players: double the ship problems, supplies drain 1.2×; 3 players: 3× and 1.3×; and so on | 3a, A2 |
| Gather more data with more players | 3a, A2 |
| Minigames unchanged, everyone at the same time | 3d, A3, B4 |
| Bots score a random 85 to 100 on each minigame | 3e, A3 |
| Everyone votes on parts; most votes wins | 3b, A4, B4 |
| Everyone must say yes to launch | 3c, A5 |
| Bots vote with the most-picked option and always say yes | 3e, A4, A5 |

## 12. Questions for the team

1. Should bots help fix ship problems and gather data (my default), or only do the three things in Holden's note?
2. Is "data to gather" ×2, ×3, ×4 right, or should it grow slower, like the supplies do?
3. Ties: talk it over, revote, then a coin flip (my default)? Or should the party leader's vote break ties?
4. If the leader leaves, the mission ends for everyone. Is that fine for now?
5. A player who joins has already picked a player count that gets ignored. Would you rather ask "Create or Join?" before "How many players?"
6. During the launch, should everyone do the timed presses and share the average (my default), or only the leader?
7. Coach: who sets up the relay, and where?

## Sources

- [Exporting for the Web: networking limits (Godot docs)](https://docs.godotengine.org/en/4.2/tutorials/export/exporting_for_web.html)
- [WebSocket (Godot docs)](https://docs.godotengine.org/en/4.0/tutorials/networking/websocket.html)

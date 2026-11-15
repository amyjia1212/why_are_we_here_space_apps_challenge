# MULTIPLAYER_PLAN.md: Step 16, plan the connection (read and plan only)

**UPGRADE_PLAN_V2 Step 28 (2026-11-14):** this page is that step's "plan first" part. No online code was
built. Online play is first on the plan's cut list (section 6), and the team already chose pass-the-keyboard
(1–4 players on one computer), which works now. If the team wants online play after the freeze, start
from option A below.

Written 2026-11-13. **Decision (Holden, 2026-11-13): pass-the-keyboard only (option D). Steps 17–19 are dropped.** No code changed and nothing downloaded. TASKS.md says to ask the
coach before Steps 17–19 start, so this page is for Kaleb and Holden to decide.

## What we need (PLAN.md §7, Amy's version)

Each player is on their own computer. One player hosts a room. The others type a room
code and join. Everyone sees the same design, plays every minigame on their own
screen, and the host averages the scores. The rest of the game (flight, arrival,
report) runs on the host and is sent to everyone.

## The big limit: a browser can't host

The game runs in a browser (Web export, single-threaded). A browser page **cannot open
a server**. It can only connect out to one. So any online play needs something that
is not a browser to sit in the middle.

## Options

| | How it works | Good | Bad |
|---|---|---|---|
| **A. Small relay server (recommended if we go online)** | A tiny Godot headless program (the same Godot, no download) runs `WebSocketMultiplayerPeer` as a server on a computer or cheap host with a public `wss://` address. Every browser connects to it; the room code picks the room. | Built into Godot 4 (high-level multiplayer, `@rpc`). Works from the judges' browsers. | Needs a host with HTTPS (wss) that the coach sets up. Browsers block plain `ws://` from an `https://` page. Hosting is still an open item. |
| **B. Desktop host on the same Wi-Fi** | One player runs the Windows build as host; the others open the web build from `http://` (not https) and join the host's local IP. | No outside server. | Only works on one network, and only over `http`; fails on school Wi-Fi that blocks devices from seeing each other. Judges can't use it. |
| **C. WebRTC peer-to-peer** | Browsers talk directly; a small "signaling" server only introduces them. | Lower lag. | Still needs the signaling server **and** extra setup (STUN/TURN). Most work. |
| **D. Pass-the-keyboard (already built)** | 1–4 players take turns on one computer (Step 6). | Done and tested. Works for judges. | Not "real" online. |

## Recommendation

1. **Submit with D** (it already works). PLAN.md says: if online play is not solid by
   Sunday noon, ship pass-the-keyboard.
2. If time is left after Step 15 passes, build **A**: a relay server plus a room-code
   screen, in this order: Step 17 host/join and player list; Step 18 send the shared
   state (`GameState.to_dict()` already exists for this) and collect minigame scores;
   Step 19 test with 2, then 4 computers.

## Questions for the coach (one answer each)

1. Go online at all, or ship pass-the-keyboard only?
2. If online: where can the relay server run with an `https`/`wss` address (and who
   pays or owns it)?
3. Is it OK if online play works only while that server is running (the judges might
   play days later)?

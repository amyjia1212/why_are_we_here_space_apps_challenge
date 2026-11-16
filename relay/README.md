# Party relay

A tiny "mail carrier" between the computers of one party (MULTIPLAYER_PLAN_V6 section 4).
It makes 4-letter party codes, lets players join by code (4 at most), passes notes
between them, and tells the party when someone joins or leaves. It saves nothing and
keeps no names. All game rules are in the game (`scripts/autoload/Party.gd`).

`relay.gd` is a small Godot program with no window. This folder has its own
`project.godot` and a `.gdignore`, so the game never imports or exports it.

## Run it on this computer (testing)

From the game folder, in PowerShell:

```
powershell -ExecutionPolicy Bypass -File serve_relay.ps1
```

Or directly: `Godot.exe --headless --path relay -s relay.gd -- 9080`.
A second number stops it after that many seconds (used by the self-tests).

While `data/multiplayer.json` → `relay_url` says PLACEHOLDER, the game uses
`local_relay_url` (`ws://localhost:9080`).

## Put it on the internet (the coach decides, B1)

The web game is on `https`, so the relay address must start with `wss://`.
Options to discuss (nothing has been signed up for or downloaded):

1. **A small cloud server or container host that can run the Godot Linux binary
   headless.** Run `godot --headless --path relay -s relay.gd` with the `PORT`
   environment variable set (the relay reads it). The host must give an `https`
   address so the game can use `wss://`.
2. **A school or club computer on the same Wi-Fi** running `serve_relay.ps1`.
   This works for the downloaded desktop game (`ws://<that computer's IP>:9080`),
   but not for the `https` web page, which needs `wss://`.

Some free hosts sleep when nobody uses them. The game waits up to 15 seconds
("Connecting…") before it gives up.

## Messages (JSON text)

| From | Note | Answer |
|---|---|---|
| game | `{"op":"create","max":3}` | `{"op":"created","code":"KXTR","seat":0}` |
| game | `{"op":"join","code":"KXTR"}` | `{"op":"joined","code":"KXTR","seat":1,"seats":[0,1]}` or `{"op":"error","reason":"no_party" / "full" / "locked"}` |
| game | `{"op":"msg","data":{...}}` (optional `"to": seat`) | the others get `{"op":"msg","from":seat,"data":{...}}` |
| leader | `{"op":"lock"}` | nobody can join any more |
| relay | | `{"op":"peer_joined","seat":2}`, `{"op":"peer_left","seat":2}` |

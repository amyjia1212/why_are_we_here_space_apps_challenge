# HOSTING.md: putting the game online for the judges

Written 2026-11-13. A person on the team does the upload. Agents never publish
anything. **Ask the coach first** which account to use. Use a team or coach account,
and never a student's real name, face or photo (team privacy rule).

## Why this is easy

Our web export is **single-threaded** (`export_presets.cfg`:
`variant/thread_support=false`). That means it needs no special server settings
("SharedArrayBuffer" / cross-origin headers). Any normal static web host works.

## Before uploading

1. Do the Step 15 playthrough in the browser first (a losing round and a winning
   round).
2. Re-export so `build/web` is the newest tested version (the agent can do this).
3. Make a zip of the **contents** of `build\web`, not the folder itself:
   `index.html` must be at the top level of the zip. In PowerShell:
   ```
   cd build\web
   Compress-Archive -Path * -DestinationPath ..\game_web.zip -Force
   ```
   The zip ends up at `build\game_web.zip`. It's well under itch.io's upload limit,
   though the game's main file, `index.wasm`, is about 40 MB before zipping.

## Option A: itch.io (recommended, free, made for browser games)

1. Log in with the team or coach account, then go to **Dashboard → Create new
   project**.
2. **Title:** How Did We Get Here?
3. **Kind of project:** HTML.
4. **Uploads:** upload `game_web.zip`, then tick **"This file will be played in the
   browser"**.
5. **Embed options:**
   - Viewport: **1280 × 720**.
   - Tick **Fullscreen button**.
   - Leave **"SharedArrayBuffer support"** OFF (we don't need it).
6. **Description:** paste parts of `HOW_TO_PLAY.md` (story, controls, the six points).
7. **Visibility:**
   - Use **Draft** or **Restricted** (password) while testing.
   - Switch to **Public** just before submitting.
8. Open the page in a private browser window and play one round. Click once so sound
   can play.
9. Put the link in the Space Apps submission form, and in `TASKS.md` under "Public
   link for judges".

## Option B: GitHub Pages (if the team has GitHub)

1. Make a public repository and upload the **contents** of `build\web` (with
   `index.html` at the top).
2. Go to **Settings → Pages**, set Source to the main branch, and use the `/` (root)
   folder.
3. The link is `https://<account>.github.io/<repository>/`. It can take a few minutes
   to go live.

## After it's online

- **Every new export means a new upload.** On itch.io, replace the old file; don't add
  a second one.
- Test the public link on a second computer, and on a Chromebook if judges might use
  one.
- **If the page stays black:** press Ctrl+Shift+R. If it is still black, check that
  `index.html` is at the top of the zip and not inside a `web` folder.

# UI POLISH PLAN V4: "How Did We Get Here?"

Written Nov 15, 2026 (Sunday, 9 am) by Fable, from Holden's note: *the UI is clunky and packed together, and the big info boxes on the ship and the parts screen do not fit in with what is around them.*

Freeze is still **today at 2:00 pm**.

**Which file wins.** This file replaces **Phase E** of `UPGRADE_PLAN_V3.md`. Phase E was about *removing* things. This plan is about how what is left *looks*. Everything else in V3 and `CLAUDE.md` still applies.

**Be honest about time.** About five hours are left, and the web export, playthroughs and video need the last part of it. The whole plan is about 3 hours. The first three steps are about 2 hours and fix most of what Holden described. Stop wherever you are at **1:00 pm** and move to export.

---

## 1. Why it looks clunky (three causes)

1. **No breathing room.** Panels touch each other and text touches panel edges.
2. **Everything is equally loud.** Same size, same brightness, a border on every box.
3. **The boxes do not belong to the world.** A big solid rectangle on top of a soft low-poly ship looks like it came from a different game.

Fixes: **add space, pick one loud thing per screen, and make panels softer and smaller so the world shows through.**

## 2. The look (Jeremy owns this) — all in `theme/game_theme.tres`

| Thing | DEFAULT |
|---|---|
| Spacing steps | 8, 16, 24, 32, 48 pixels only |
| Screen edge margin | 48 |
| Gap between panels and cards | 24 |
| Padding inside a panel | 24 (16 for small chips) |
| Corner radius | 16 panels, 12 cards, 8 chips and buttons |
| Borders | None. Only the *selected* thing gets one |
| Font sizes | Title 36 · Heading 24 · Body 18 · Small 14 |
| Text colors | Off-white main, soft gray-blue extra |
| Panel color | Dark navy, ~85% over 3D, solid over 2D |
| Card color | One step lighter than the panel |
| Amber | Only the one thing to do next, and the selected card |
| Green / red | Only status |
| Shadow | Soft, low, dark navy |

## 3. Build steps

- **Step 0** Look before you touch (read-only report).
- **Step 1** One theme, real spacing (M).
- **Step 2** Parts and materials screen: cards (4 states), slim dashboard strip, ripple strip, one amber Next (M).
- **Step 3a** Ship info boxes: nothing open by default, one small see-through card low on one side, 0.15 s fade/slide, HUD to corners (M).
- **Step 3b** In-world Bridge screen (SubViewport) — only if 3a done before noon.
- **Step 4** Soft motion: one helper, fades/slides 0.15–0.2 s, hover grow, count-up numbers, screen fades (S).
- **Step 5** Consistency sweep: Review → flight HUD → tablet → report → start menu. One amber thing, same button same place, Title Case titles, dim the world behind menus, body ≥ 18 (S).

## 4. Extras (pick at most one)
Start menu turning planet · report score counts up · flight log fade · chip tooltips.

## 6. If time runs short
Cut: extras → 3b → Step 5 start menu/tablet → number counting → Step 4. Never cut Steps 1 and 2. Stop at 1:00 pm.

## 7. Safety rules
Look-only pass. No changes to game rules, data, scoring or stage order. Test in the web export. Check longest part name, biggest number, smallest window.

(Full original text was pasted into Claude Code on 2026-11-15; this is the condensed copy kept in the game folder.)

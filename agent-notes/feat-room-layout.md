# feat/room-layout

## Goal

Q, 2026-11-14: spatial rooms share their layout so clients show it as a picture ("labels, etc. beautiful.
zoomable. correct, principled"), "and also update the mudlet package". The MOO sends GMCP `Room.Layout`
(contract: the Mongoose hub's `agent-notes/spatial-room-svg.md`); this branch draws it in Mudlet and gives a text
command for players who do not see the picture.

## State

- `layout/layout.lua` written; `tests/test_layout.lua` 63/63 under Lua 5.4.8 with stand-ins for Mudlet and Geyser;
  the other four suites still pass. Added to `build.py` MODULES; `python build.py 6` builds. PR #3.
- The tests carry the contract-shaped payload and the real one the live MOO sent for room #1770 (hub
  `reports/room-layout-sample-2026-11-14.json`, transcribed as a Lua table).
- Not run in a real Mudlet.

## Decisions and why

- Drawn with Geyser labels in a docked user window, not an SVG: Mudlet's wiki (UI Functions, setBackgroundImage)
  says labels accept SVG backgrounds only since Mudlet 5.1; labels with Qt stylesheets work on any Mudlet from 4.8
  (user window title), wheel callbacks since 3.6, tooltips since 4.6.1. Text stays text, so zoom is a re-layout at
  a new pixels-per-metre, sharp at every size.
- No Core.Supports change: `$gmcp_package:send` gates on the package name `Room`, which Mudlet declares by default
  (`src/ctelnet.cpp:3569` in Mudlet's source). Client.Spatial is not declared, so the picture follows Room.Layout
  only (on entering a room), not moves inside it.
- "You" is the thing whose id equals `gmcp.Char.Name.name` (`$gmcp_char:send_name` sends `tostr(player)`).
- Every label gets the wheel callback: `TLabel::wheelEvent` accepts the event when a callback is set, so a label
  without one would let the scroll box scroll instead of zooming.
- Room.Info for another room clears the picture, since non-spatial rooms send no Room.Layout.
- `layout hide` is saved with `table.save` in the profile home, so a player who hid the window keeps it hidden.
- Mudlet runs Lua 5.1: `math.atan2 or math.atan`.
- Names (things, exits, the Room.Info title) have Mongoose's bracketed colour tags stripped ("[red]...[normal]"),
  with the tag list of the web client's `src/stripMudAnsiTags.ts`; other bracketed text is kept.
- A thing with `"shapes": []` (the sample's puddle) has nothing to draw; `layout` lists it as "place not given".
- Doorway points sit slightly inside the walls in real data (south door at y -3.6 in an 8 m room); the bar goes on
  the nearest wall at the point's along-wall position.
- The contract's `origin` field is for clients that follow Client.Spatial; this package does not, so ignores it.
- No MOO verb named `layout` is reachable by players (team lead checked $player, $spatial_room, $builder, $prog,
  $wiz in the dump), so the `layout` alias hides no server command.

## Next step

Team lead pushes. Then: a run in a real Mudlet, a
release (`python build.py 6`, `gh release create v6 dist/mongoose.mpackage --title "Mongoose 6"`, then
`$client_gui.version`/`url` on the server).

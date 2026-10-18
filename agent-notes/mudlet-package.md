# mudlet-package

## Goal

One Mudlet package for Mongoose, offered by the server through GMCP `Client.GUI`: keys (GMCP
`Client.Keystrokes` layers, by the hotkeys work) and the map (by the mapping work). Mudlet keeps one server
package per profile, so both live here. The full record of the keys work is the Mongoose hub's
`agent-notes/hotkeys.md`.

## State

- `keys/keys.lua` written from Mudlet's own source (tempKey, killKey, mudlet.key, gmod.enableModule,
  gmcp.* events); `tests/test_keys.lua` passes 19/19 under Lua 5.4 with stand-ins for Mudlet's functions.
- `mapper/mapper.lua` is the mapping session's file, unchanged.
- `build.py VERSION` builds a byte-reproducible `dist/mongoose.mpackage`.
- Not yet run in a real Mudlet: there is none on the machine it was written on.

## Decisions and why

- Typing keys (no Ctrl/Alt/Meta) are installed only in keys mode; with text in the command line they type the
  character themselves, because Mudlet has already consumed the key. Arrows and F-keys do nothing then.
- Release assets are versioned (`releases/download/vN/mongoose.mpackage`); the MOO's `$client_gui` holds version
  and URL, and Mudlet upgrades when the version changes.

## Next step

Try it in a real Mudlet: install from the release, log in, sit at a game, Alt+Shift+H.

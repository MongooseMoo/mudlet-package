# feat/status

## Goal

Package C of the Mongoose hub's `status-todo/plan.md` (Q's request 2026-10-24, decisions 2026-10-24/25): a status
module that reads GMCP `Char.Vitals` (list of meters), `Char.Effects` (list) and `Char.Target`, speaks Alt+H
(health percent and words), Alt+M (every power meter), Alt+V (body meter), Alt+T (target) through Mudlet's
`announce()`, warns once per downward crossing of 50/25/10 percent health, and announces effects gained and lost.
Built by `build.py`, tests in `tests/`. Nothing else: no sounds, no UI panels.

## State

- Worktree `C:\Users\Q\code\mudlet-package-status`, branch `feat/status` from `origin/main` f5e0f60.
- `status/status.lua` written; `tests/test_status.lua` 23/23 under Lua 5.4.8 with stand-ins for Mudlet.
- Added to `build.py` MODULES; `python build.py 5` produced a package with four scripts, status among them.
- README and `agent-notes/mudlet-package.md` updated. Branch pushed; PR text in `agent-notes/pr-body.md`
  (uncommitted). No PR opened, no release made.
- Not run in a real Mudlet, and not against the live server: package A (the MOO side that sends these
  packages) is not built yet, so the payloads are the plan's contract, not captured wire.

## Decisions and why

- No `Core.Supports` line: Mudlet already declares `Char 1` in its default set (`src/ctelnet.cpp:3569` in the
  Mudlet clone), so Char.* packages arrive.
- `announce(text)` with no processing argument: `TLuaInterpreter::announce` (`src/TLuaInterpreter.cpp:9891`) takes
  an optional processing style that only matters on Windows.
- A JSON list arrives in `gmcp.Char.Vitals` as a 1-based Lua sequence (`yajl.to_value`,
  `src/mudlet-lua/tests/LuaGlobal_spec.lua:12-17`); `{}` and `[]` are empty tables (same file, 35-40).
- Readouts apply each meter's `rate` since arrival, clamped to [0, max], as the wire contract says the client
  does; the clock is `getEpoch()` (`src/TLuaInterpreter.cpp:2860`, seconds with milliseconds).
- A health warning compares the new value against the previous meter as it stands at that moment (rate
  applied), and speaks only the lowest threshold crossed, once.
- The first `Char.Effects` list after connecting is the baseline and is not announced; disconnecting clears all
  three packages.

## Surprises

- Mudlet's starter UI listens to `gmcp.Char.Vitals` but reads only named keys (`hp`, `health`, ...:
  `src/packages/mudlet-base-ui/mudlet-base-ui.xml:731-733`); a list has none, so it shows no gauge. Left alone.
- Mudlet runs the first key that matches a chord, or every one (`TKey::match`, `src/TKey.cpp:80-110`), so a
  server keys layer binding Alt+H/M/V/T would collide with the status keys. Team lead's decision: `keys.lua`
  keeps those four out of layers as it keeps out Alt+Shift+H (`RESERVED`); `tests/test_keys.lua` 37/37.
- Team lead's decisions on the other two: the server will leave the Readiness row out of Char.Effects, so no
  client change; the starter UI is left alone.

- `$abilities:affects_rows` (#149604 [28], dump 2026-10-24T2135, lines 595/606/612) always gives string
  section, name and source, so the effect key needs no nil handling. It also returns a "Readiness: Ability
  recovery" row; sent unchanged as Char.Effects, every ability use would be said as gained, then lost. That is
  package A's choice of rows, not changed here.

## Next step

Team lead reviews and opens the PR. Then: package A's real payloads checked against this module, a run in a real
Mudlet, and a release (`python build.py N`, `gh release create`, `$client_gui` version/url).

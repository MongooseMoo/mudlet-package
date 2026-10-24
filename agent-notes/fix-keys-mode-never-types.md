# fix/keys-mode-never-types

## Goal
Q (2026-10-24): keys mode must never put a key into the command line, here and in the web client, plus key help
on Alt+Shift+F1. The full record (Q's answers, Mudlet source citations, browser check) is
`agent-notes/fix-keys-mode-never-types.md` on the same branch in MongooseMoo/react-client.

## State
`keys/keys.lua`: in keys mode, no-op tempKeys on mudlet.key codes 0x21..0xff, plain and Shift, below the real
bindings; `fire` no longer types the letter itself; an autosend-false binding turns keys mode off until
sysDataSendRequest (ignored while the package's own `send` runs, `K.sending`); Alt+Shift+F1 key help.
`lua tests/test_keys.lua`: all passed. README updated. Not tried in a real Mudlet.

## Decisions and why
Space can't be stopped by a package: Mudlet's TCommandLine.cpp:327-335 types a plain Space without asking key
bindings. Q chose package-only plus a note. Plain Escape is Mudlet's own (TCommandLine.cpp:575-586), so key help ends
only on Alt+Shift+F1 here.

## Next step
PR open, then Q decides merge and the v4 release (`python build.py 4`, `$client_gui.version/.url`).

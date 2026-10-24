# Mongoose for Mudlet

The package Mongoose (`mongoose.world`) gives Mudlet. When you log in with Mudlet the server offers it through GMCP
`Client.GUI`, and Mudlet installs it, or upgrades it when the version changes. You can also install a release's
`mongoose.mpackage` by hand from Mudlet's Package Manager.

## What it does

- **Keys** (`keys/keys.lua`): while you sit at a game or man a ship's console, the server sends its keys (GMCP
  `Client.Keystrokes` layers) and this module makes them Mudlet keys. Keys that are plain letters, digits, arrows
  or F-keys work only in keys mode: **Alt+Shift+H** turns it on and off. In keys mode no key types into the command
  line, except Space: Mudlet always types a plain Space. A key that starts a command for you to finish (Shift+S
  for a Yahtzee score) turns keys mode off so you can type the rest, and sending it turns keys mode back on.
  **Alt+Shift+F1** is key help: each key says what it does instead of doing it, until Alt+Shift+F1 again. Type
  `keys` in the game to hear what you have. The protocol is
  [`docs/keystrokes.md`](https://github.com/MongooseMoo/react-client/blob/master/docs/keystrokes.md) in the web
  client.
- **Map** (`mapper/mapper.lua`): draws the rooms you visit from GMCP `Room.Info`, and walks you to a room you click.
- **Starter UI** (`ui/ui.lua`): Mudlet's starter UI hides itself when any game package installs. This package has
  no interface of its own, so it brings the starter UI back (its dock, map and chat tabs), unless you hid it
  yourself with `baseui hide`.

## Test, build and release

```sh
lua tests/test_keys.lua    # the keys module against stand-ins for Mudlet's functions
python build.py 2          # writes dist/mongoose.mpackage
gh release create v2 dist/mongoose.mpackage --title "Mongoose 2"
```

Then point the server at it, as a wizard:

```
;$client_gui.version = "2"
;$client_gui.url = "https://github.com/MongooseMoo/mudlet-package/releases/download/v2/mongoose.mpackage"
```

Mudlet names the package after the URL's last segment, so the file must stay `mongoose.mpackage`. It keeps one
server package per profile, which is why keys and the map ship together.

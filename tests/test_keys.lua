-- Runs keys/keys.lua against stand-ins for the Mudlet functions it uses.
--   lua tests/test_keys.lua
-- The payloads are the ones the live MOO sent on 2026-10-18.

local said, sent, gmcpSent, handlers, keys, nextKey = {}, {}, {}, {}, {}, 0
local cmdLine = ""

mudlet = {
  key = {A = 0x41, H = 0x48, P = 0x50, R = 0x52, S = 0x53, F1 = 0x01000030, Left = 0x01000012},
  keymodifier = {Shift = 0x02000000, Control = 0x04000000, Alt = 0x08000000, Meta = 0x10000000},
}
gmcp = {Client = {Keystrokes = {}}}
yajl = {to_string = function(value) return "<json " .. #value .. ">" end}
gmod = {enableModule = function(user, module) gmcpSent[#gmcpSent + 1] = "enable " .. user .. " " .. module end}

function echo(text) said[#said + 1] = (text:gsub("^\n%[Keys%] ", ""):gsub("\n$", "")) end
function send(command) sent[#sent + 1] = command end
function sendGMCP(message) gmcpSent[#gmcpSent + 1] = message end
function getCmdLine() return cmdLine end
function clearCmdLine() cmdLine = "" end
function appendCmdLine(text) cmdLine = cmdLine .. text end
function registerAnonymousEventHandler(event, fn) handlers[event] = fn; return event end
function killAnonymousEventHandler(id) handlers[id] = nil end
function tempKey(mask, code, fn)
  nextKey = nextKey + 1
  keys[nextKey] = {mask = mask, code = code, fn = fn}
  return nextKey
end
function killKey(id) keys[id] = nil end

local function press(code, mask)
  mask = mask or 0
  for _, key in pairs(keys) do
    if key.code == code and key.mask == mask then key.fn(); return true end
  end
  return false
end

local function arrive(name, data)
  gmcp.Client.Keystrokes[name] = data
  handlers["gmcp.Client.Keystrokes." .. name]()
end

local failures = 0
local function check(what, ok)
  if not ok then failures = failures + 1; print("FAIL " .. what) else print("ok   " .. what) end
end

dofile("keys/keys.lua")
local Shift, Alt, Control = mudlet.keymodifier.Shift, mudlet.keymodifier.Alt, mudlet.keymodifier.Control

check("takes back the bare Client namespace", gmcpSent[1] == [[Core.Supports.Remove ["Client 1"] ]])
check("declares Client.Keystrokes alone", gmcpSent[2] == [[Core.Supports.Add ["Client.Keystrokes 1"] ]])
check("does not use gmod, which would declare Client", #gmcpSent == 2)
handlers["sysProtocolEnabled"](nil, "GMCP")
check("declares again on reconnect", gmcpSent[4] == [[Core.Supports.Add ["Client.Keystrokes 1"] ]])

arrive("Layer", {id = "#16186", label = "Yahtzee", modal = true, bindings = {
  {key = "F1", modifiers = {}, command = "rules", label = "How to play", autosend = true},
  {key = "s", modifiers = {}, command = "sheet", label = "Scorecards", autosend = true},
  {key = "s", modifiers = {"shift"}, command = "score ", label = "Score in a category", autosend = false},
  {key = "h", modifiers = {"alt", "shift"}, command = "grab", label = "Takes the toggle", autosend = true},
}})
check("announces a modal layer", said[#said] == "Yahtzee keys available. Alt+Shift+H for keys mode.")
check("typing keys are not live outside keys mode", not press(mudlet.key.S))

press(mudlet.key.H, Alt + Shift)
check("Alt+Shift+H turns keys mode on and names the layer", said[#said] == "Keys mode on: Yahtzee")
check("a layer cannot take Alt+Shift+H", #sent == 0 and mongoose.keys.keysMode)

press(mudlet.key.S)
check("s sends sheet", sent[#sent] == "sheet")
press(mudlet.key.S, Shift)
check("Shift+S stages score", cmdLine == "score " and #sent == 1)
press(mudlet.key.S)
check("with text in the command line, s types", cmdLine == "score s" and #sent == 1)
press(mudlet.key.S, Shift)
check("and Shift+S types a capital", cmdLine == "score sS" and #sent == 1)
clearCmdLine()
press(mudlet.key.F1)
check("F1 sends rules", sent[#sent] == "rules")

arrive("Layer", {id = "#12", label = "Helm console", bindings = {
  {key = "s", modifiers = {"ctrl"}, command = "scan %1", label = "Scan", autosend = true},
}})
check("announces a plain layer with its count", said[#said] == "Helm console keys: 1")
cmdLine = "bob hello"
press(mudlet.key.S, Control)
check("Ctrl binding fires with text and fills %1", sent[#sent] == "scan bob")
clearCmdLine()

arrive("RemoveLayer", {id = "#16186"})
check("removing the last modal layer ends keys mode", said[#said] == "Yahtzee keys removed. Keys mode off"
  and not mongoose.keys.keysMode)
check("its keys are gone", not press(mudlet.key.F1))
check("the other layer stays", press(mudlet.key.S, Control))

arrive("Bind", {key = "r", modifiers = {"ctrl"}, command = "roll", autosend = true})
press(mudlet.key.R, Control)
check("an older Bind works", sent[#sent] == "roll")
arrive("ListBindings", {})
check("ListBindings answers", gmcpSent[#gmcpSent] == "Client.Keystrokes.BindingsList <json 2>")

handlers["sysDisconnectionEvent"]()
check("disconnecting clears every layer", not press(mudlet.key.S, Control) and not press(mudlet.key.R, Control))
check("the toggle survives a disconnect", press(mudlet.key.H, Alt + Shift))

print(failures == 0 and "all passed" or (failures .. " failed"))
os.exit(failures == 0 and 0 or 1)

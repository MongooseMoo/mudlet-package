-- Mongoose keys for Mudlet: GMCP Client.Keystrokes layers as Mudlet keys.
--
-- The server sends a layer of keys while the player uses something (a game they
-- sit at, a console they man) and removes it when they stop. A key without Ctrl,
-- Alt or Meta would take a letter away from typing, so those work only in keys
-- mode (Alt+Shift+H). In keys mode no key types, bound or not, except Space:
-- Mudlet never offers a plain Space to key bindings. Alt+Shift+F1 is key help,
-- where each key says what it does. The contract is docs/keystrokes.md in
-- MongooseMoo/react-client.

mongoose = mongoose or {}
mongoose.keys = mongoose.keys or {}
local K = mongoose.keys

K.layers = K.layers or {}       -- in arrival order; the last one wins a key two layers bind
K.keysMode = K.keysMode or false
K.help = K.help or false
K.resumeOnSend = K.resumeOnSend or false -- a staged command turned keys mode off until it is sent
K.installed = K.installed or {} -- tempKey ids of the bindings now live

local MODIFIERS = {
  shift = "Shift", ctrl = "Control", control = "Control",
  alt = "Alt", option = "Alt", meta = "Meta", cmd = "Meta",
}
local KEY_NAMES = {
  left = "Left", right = "Right", up = "Up", down = "Down",
  arrowleft = "Left", arrowright = "Right", arrowup = "Up", arrowdown = "Down",
  esc = "Escape", escape = "Escape", space = "Space", [" "] = "Space",
  del = "Delete", delete = "Delete", enter = "Return", tab = "Tab",
  backspace = "Backspace", insert = "Insert", home = "Home", ["end"] = "End",
  pageup = "PageUp", pagedown = "PageDown",
  [","] = "Comma", ["."] = "Period", ["-"] = "Minus", ["/"] = "Slash",
}

local function say(text)
  echo("\n[Keys] " .. text .. "\n")
end

local MODIFIER_NAMES = {{"Control", "Ctrl"}, {"Alt", "Alt"}, {"Shift", "Shift"}, {"Meta", "Meta"}}

-- How key help says a key: "Ctrl+Alt+S".
local function keyName(used, name)
  local parts = {}
  for _, pair in ipairs(MODIFIER_NAMES) do
    if used[pair[1]] then parts[#parts + 1] = pair[2] end
  end
  parts[#parts + 1] = name
  return table.concat(parts, "+")
end

-- A binding's Mudlet key code and modifier mask, whether it is a typing key
-- (no Ctrl, Alt or Meta), and its name for key help. Nil when Mudlet has no such key.
local function chord(binding)
  local key = binding.key or ""
  local name
  if #key == 1 and key:match("%w") then
    name = key:upper()
  else
    name = KEY_NAMES[key:lower()] or key
  end
  local code = mudlet.key[name]
  if not code then return nil end
  local used, mask, typing = {}, 0, true
  for _, modifier in ipairs(binding.modifiers or {}) do
    local mod = MODIFIERS[modifier:lower()]
    if not mod then return nil end
    if not used[mod] then
      used[mod] = true
      mask = mask + mudlet.keymodifier[mod]
    end
    if mod ~= "Shift" then typing = false end
  end
  return code, mask, typing, keyName(used, name)
end

local TOGGLE_MASK = mudlet.keymodifier.Alt + mudlet.keymodifier.Shift
local TOGGLE_CHORD = TOGGLE_MASK .. ":" .. mudlet.key.H
local HELP_CHORD = TOGGLE_MASK .. ":" .. mudlet.key.F1
-- The status readouts (status/status.lua) own Alt+H, M, V and T; a layer cannot take them.
local RESERVED = {[TOGGLE_CHORD] = true, [HELP_CHORD] = true}
for _, letter in ipairs({"H", "M", "V", "T"}) do
  RESERVED[mudlet.keymodifier.Alt .. ":" .. mudlet.key[letter]] = true
end
-- Mudlet's codes for the Latin-1 characters, Exclam to ydiaeresis. Space (0x20)
-- is left out: Mudlet types it without asking the key bindings.
local FIRST_CHARACTER, LAST_CHARACTER = 0x21, 0xff

local function expand(command, line)
  local words = {}
  for word in line:gmatch("%S+") do words[#words + 1] = word end
  command = command:gsub("%%(%d)", function(n) return words[tonumber(n)] or ("%" .. n) end)
  command = command:gsub("%%%*", function() return line end)
  return command
end

local function fire(binding)
  local command = expand(binding.command, getCmdLine())
  if binding.autosend ~= false then
    -- Our own send is not the player sending a staged command.
    K.sending = true
    send(command)
    K.sending = false
    return
  end
  clearCmdLine()
  appendCmdLine(command)
  if K.keysMode then
    -- The player types the rest; sending it turns keys mode back on.
    K.keysMode = false
    K.resumeOnSend = true
    K.install()
    say("Keys mode off")
  end
end

function K.install()
  for _, id in ipairs(K.installed) do killKey(id) end
  K.installed = {}
  local taken = {}
  local function add(mask, code, fn)
    local id = mask .. ":" .. code
    if taken[id] or RESERVED[id] then return end
    taken[id] = true
    K.installed[#K.installed + 1] = tempKey(mask, code, fn)
  end
  for i = #K.layers, 1, -1 do
    local bindings = K.layers[i].bindings
    for j = #bindings, 1, -1 do
      local binding = bindings[j]
      local code, mask, typing, name = chord(binding)
      if code and K.help then
        add(mask, code, function() say(name .. ": " .. (binding.label or binding.command)) end)
      elseif code and (K.keysMode or not typing) then
        add(mask, code, function() fire(binding) end)
      end
    end
  end
  if not (K.keysMode or K.help) then return end
  -- A bound key Mudlet runs is not typed, so every other character key gets one that does nothing.
  local shift = mudlet.keymodifier.Shift
  for name, code in pairs(mudlet.key) do
    if code >= FIRST_CHARACTER and code <= LAST_CHARACTER then
      if K.help then
        add(0, code, function() say(name .. ": not bound") end)
        add(shift, code, function() say("Shift+" .. name .. ": not bound") end)
      else
        add(0, code, function() end)
        add(shift, code, function() end)
      end
    end
  end
end

local function modalLabels()
  local labels = {}
  for _, layer in ipairs(K.layers) do
    if layer.modal then labels[#labels + 1] = layer.label end
  end
  return labels
end

function K.toggle()
  if K.help then return say("Alt+Shift+H turns keys mode on and off") end
  K.keysMode = not K.keysMode
  K.resumeOnSend = false
  K.install()
  if not K.keysMode then return say("Keys mode off") end
  local labels = modalLabels()
  say(#labels > 0 and ("Keys mode on: " .. table.concat(labels, ", ")) or "Keys mode on")
end

-- Mudlet keeps a plain Escape for itself, so only Alt+Shift+F1 ends key help.
function K.toggleHelp()
  K.help = not K.help
  K.install()
  say(K.help and "Key help on. Press a key to hear what it does. Alt+Shift+F1 ends key help." or "Key help off")
end

function K.onSend()
  if not K.resumeOnSend or K.sending then return end
  K.resumeOnSend = false
  K.keysMode = true
  K.install()
  say("Keys mode on")
end

local function indexOf(id)
  for i, layer in ipairs(K.layers) do
    if layer.id == id then return i end
  end
end

function K.onLayer()
  local data = gmcp.Client.Keystrokes.Layer
  local old = indexOf(data.id)
  if old then table.remove(K.layers, old) end
  local layer = {id = data.id, label = data.label or data.id, modal = data.modal == true, bindings = data.bindings or {}}
  table.insert(K.layers, layer)
  K.install()
  if old then return end
  if layer.modal then
    say(layer.label .. " keys available. Alt+Shift+H for keys mode.")
  else
    say(layer.label .. " keys: " .. #layer.bindings)
  end
end

local function removeLayer(id)
  local i = indexOf(id)
  if not i then return end
  local layer = table.remove(K.layers, i)
  local lastModal = layer.modal and #modalLabels() == 0
  local ends = lastModal and K.keysMode
  if lastModal then
    K.keysMode = false
    K.resumeOnSend = false
  end
  K.install()
  if layer.id == "" then return ends and "Keys mode off" or nil end
  return layer.label .. " keys removed" .. (ends and ". Keys mode off" or "")
end

function K.onRemoveLayer()
  local message = removeLayer(gmcp.Client.Keystrokes.RemoveLayer.id)
  if message then say(message) end
end

-- The older messages act on a layer with id "", which is never announced.
local function serverKeys()
  local i = indexOf("")
  if i then return K.layers[i] end
  local layer = {id = "", label = "Server keys", modal = false, bindings = {}}
  table.insert(K.layers, layer)
  return layer
end

local function sameKey(a, b)
  local codeA, maskA = chord(a)
  local codeB, maskB = chord(b)
  return codeA ~= nil and codeA == codeB and maskA == maskB
end

local function withoutKey(bindings, key)
  local kept = {}
  for _, binding in ipairs(bindings) do
    if not sameKey(binding, key) then kept[#kept + 1] = binding end
  end
  return kept
end

function K.onBind()
  local data = gmcp.Client.Keystrokes.Bind
  local layer = serverKeys()
  layer.bindings = withoutKey(layer.bindings, data)
  table.insert(layer.bindings, data)
  K.install()
end

function K.onUnbind()
  local layer = serverKeys()
  layer.bindings = withoutKey(layer.bindings, gmcp.Client.Keystrokes.Unbind)
  K.install()
end

function K.onBindAll()
  serverKeys().bindings = gmcp.Client.Keystrokes.Bind_all.bindings or {}
  K.install()
end

function K.onUnbindAll()
  local messages = {}
  while #K.layers > 0 do
    local message = removeLayer(K.layers[#K.layers].id)
    if message then table.insert(messages, 1, message) end
  end
  if #messages > 0 then say(table.concat(messages, ". ")) end
end

function K.onListBindings()
  local list = {}
  for _, layer in ipairs(K.layers) do
    for _, binding in ipairs(layer.bindings) do
      list[#list + 1] = {
        id = layer.id, key = binding.key, modifiers = binding.modifiers or {},
        command = binding.command, label = binding.label, autosend = binding.autosend ~= false,
      }
    end
  end
  sendGMCP("Client.Keystrokes.BindingsList " .. (#list > 0 and yajl.to_string(list) or "[]"))
end

function K.onDisconnect()
  K.layers = {}
  K.keysMode = false
  K.help = false
  K.resumeOnSend = false
  K.install()
end

for _, handler in ipairs(K.handlers or {}) do killAnonymousEventHandler(handler) end
K.handlers = {
  registerAnonymousEventHandler("gmcp.Client.Keystrokes.Layer", K.onLayer),
  registerAnonymousEventHandler("gmcp.Client.Keystrokes.RemoveLayer", K.onRemoveLayer),
  registerAnonymousEventHandler("gmcp.Client.Keystrokes.Bind", K.onBind),
  registerAnonymousEventHandler("gmcp.Client.Keystrokes.Unbind", K.onUnbind),
  registerAnonymousEventHandler("gmcp.Client.Keystrokes.Bind_all", K.onBindAll),
  registerAnonymousEventHandler("gmcp.Client.Keystrokes.UnbindAll", K.onUnbindAll),
  registerAnonymousEventHandler("gmcp.Client.Keystrokes.ListBindings", K.onListBindings),
  registerAnonymousEventHandler("sysDisconnectionEvent", K.onDisconnect),
  registerAnonymousEventHandler("sysDataSendRequest", K.onSend),
  registerAnonymousEventHandler("sysProtocolEnabled", function(_, protocol)
    if protocol == "GMCP" then K.declare() end
  end),
}

-- Tells the server this client takes Client.Keystrokes. Not with gmod.enableModule: that also declares
-- the bare "Client" namespace, which the server reads as every Client.* package, Client.Html among them,
-- and Client.Html replaces room text. Version 1 did that, so take the namespace back.
function K.declare()
  sendGMCP([[Core.Supports.Remove ["Client 1"] ]])
  sendGMCP([[Core.Supports.Add ["Client.Keystrokes 1"] ]])
end

if K.toggleKey then killKey(K.toggleKey) end
K.toggleKey = tempKey(TOGGLE_MASK, mudlet.key.H, K.toggle)
if K.helpKey then killKey(K.helpKey) end
K.helpKey = tempKey(TOGGLE_MASK, mudlet.key.F1, K.toggleHelp)
K.install()
K.declare()

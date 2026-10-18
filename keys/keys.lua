-- Mongoose keys for Mudlet: GMCP Client.Keystrokes layers as Mudlet keys.
--
-- The server sends a layer of keys while the player uses something (a game they
-- sit at, a console they man) and removes it when they stop. A key without Ctrl,
-- Alt or Meta would take a letter away from typing, so those work only in keys
-- mode (Alt+Shift+H), and only while the command line is empty: once it has
-- text, they type. The contract is docs/keystrokes.md in MongooseMoo/react-client.

mongoose = mongoose or {}
mongoose.keys = mongoose.keys or {}
local K = mongoose.keys

K.layers = K.layers or {}       -- in arrival order; the last one wins a key two layers bind
K.keysMode = K.keysMode or false
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

-- A binding's Mudlet key code and modifier mask, and whether it is a typing key
-- (no Ctrl, Alt or Meta). Nil when Mudlet has no such key.
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
  return code, mask, typing
end

local TOGGLE_MASK = mudlet.keymodifier.Alt + mudlet.keymodifier.Shift
local TOGGLE_CHORD = TOGGLE_MASK .. ":" .. mudlet.key.H

local function expand(command, line)
  local words = {}
  for word in line:gmatch("%S+") do words[#words + 1] = word end
  command = command:gsub("%%(%d)", function(n) return words[tonumber(n)] or ("%" .. n) end)
  command = command:gsub("%%%*", function() return line end)
  return command
end

local function fire(binding, typing)
  local line = getCmdLine()
  if typing and line ~= "" then
    -- Mudlet has already taken the key, so type it ourselves.
    local key = binding.key or ""
    if #key == 1 then
      local shifted = false
      for _, modifier in ipairs(binding.modifiers or {}) do
        if modifier:lower() == "shift" then shifted = true end
      end
      appendCmdLine(shifted and key:upper() or key:lower())
    end
    return
  end
  local command = expand(binding.command, line)
  if binding.autosend == false then
    clearCmdLine()
    appendCmdLine(command)
  else
    send(command)
  end
end

function K.install()
  for _, id in ipairs(K.installed) do killKey(id) end
  K.installed = {}
  local taken = {}
  for i = #K.layers, 1, -1 do
    local bindings = K.layers[i].bindings
    for j = #bindings, 1, -1 do
      local binding = bindings[j]
      local code, mask, typing = chord(binding)
      local id = code and (mask .. ":" .. code)
      if id and not taken[id] and id ~= TOGGLE_CHORD and (K.keysMode or not typing) then
        taken[id] = true
        K.installed[#K.installed + 1] = tempKey(mask, code, function() fire(binding, typing) end)
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
  K.keysMode = not K.keysMode
  K.install()
  if not K.keysMode then return say("Keys mode off") end
  local labels = modalLabels()
  say(#labels > 0 and ("Keys mode on: " .. table.concat(labels, ", ")) or "Keys mode on")
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
  local ends = layer.modal and K.keysMode and #modalLabels() == 0
  if ends then K.keysMode = false end
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
K.install()
K.declare()

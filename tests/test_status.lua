-- Runs status/status.lua against stand-ins for the Mudlet functions it uses.
--   lua tests/test_status.lua
-- The payloads follow the wire contract in the Mongoose hub's status-todo/plan.md; the effect rows have the
-- shape $abilities:affects_rows (#149604) returns.

local said, handlers, keys, nextKey, now = {}, {}, {}, 0, 1000

mudlet = {
  key = {H = 0x48, M = 0x4d, T = 0x54, V = 0x56},
  keymodifier = {Shift = 0x02000000, Control = 0x04000000, Alt = 0x08000000, Meta = 0x10000000},
}
gmcp = {Char = {}}

function announce(text) said[#said + 1] = text end
function getEpoch() return now end
function registerAnonymousEventHandler(event, fn) handlers[event] = fn; return event end
function killAnonymousEventHandler(id) handlers[id] = nil end
function tempKey(mask, code, fn)
  nextKey = nextKey + 1
  keys[nextKey] = {mask = mask, code = code, fn = fn}
  return nextKey
end
function killKey(id) keys[id] = nil end

local Alt = mudlet.keymodifier.Alt
local function press(code)
  for _, key in pairs(keys) do
    if key.code == code and key.mask == Alt then key.fn(); return said[#said] end
  end
end

local function arrive(name, data)
  gmcp.Char[name] = data
  handlers["gmcp.Char." .. name]()
end

local function vitals(health, words, rate)
  return {
    {id = "health", kind = "health", label = "Health", value = health, max = 200, words = words, rate = rate or 0},
    {id = "#149602", kind = "body", label = "Stamina", value = 30, max = 60, rate = 0},
    {id = "#5001", kind = "power", label = "Mana", value = 40, max = 100, rate = 2},
    {id = "#5002", kind = "power", label = "Qi", value = 10, max = 10, rate = 0},
  }
end

local function effect(name, source, seconds)
  return {section = "Effects", name = name, source = source, seconds = seconds, dismissible = 1}
end

local failures = 0
local function check(what, ok)
  if not ok then failures = failures + 1; print("FAIL " .. what) else print("ok   " .. what) end
end

dofile("status/status.lua")

check("Alt+H before any vitals says there is no reading", press(mudlet.key.H) == "No health reading")
check("Alt+T with no target says so", press(mudlet.key.T) == "No target")

arrive("Vitals", vitals(150, "slightly bruised"))
check("the first vitals give no warning", #said == 2)
check("Alt+H says health percent and words", press(mudlet.key.H) == "Health 75 percent, slightly bruised")
check("Alt+M says every power meter", press(mudlet.key.M) == "Mana 40 percent. Qi 100 percent")
check("Alt+V says the body meter", press(mudlet.key.V) == "Stamina 50 percent")

now = now + 10
check("a meter moves by its rate since it arrived", press(mudlet.key.M) == "Mana 60 percent. Qi 100 percent")
now = now + 100
check("and stops at its max", press(mudlet.key.M) == "Mana 100 percent. Qi 100 percent")

local count = #said
arrive("Vitals", vitals(110, "hurt"))
check("staying above 50 percent gives no warning", #said == count)
arrive("Vitals", vitals(90, "badly hurt"))
check("falling below 50 percent warns", said[#said] == "Health below 50 percent, badly hurt")
count = #said
arrive("Vitals", vitals(60, "badly hurt"))
check("falling further but above 25 percent says nothing more", #said == count)
arrive("Vitals", vitals(80, "badly hurt"))
arrive("Vitals", vitals(70, "badly hurt"))
check("moving about under 50 percent never warns again", #said == count)
arrive("Vitals", vitals(10, "near death"))
check("a fall past 25 and 10 at once warns once, at 10", #said == count + 1
  and said[#said] == "Health below 10 percent, near death")

arrive("Vitals", vitals(40, "badly hurt", 1))
now = now + 80
count = #said
arrive("Vitals", vitals(90, "badly hurt"))
check("recovery by rate counts: 60 percent down to 45 warns at 50", #said == count + 1
  and said[#said] == "Health below 50 percent, badly hurt")

arrive("Target", {name = "a giant rat", value = 0.3, words = "badly wounded"})
check("Alt+T says the target", press(mudlet.key.T) == "a giant rat 30 percent, badly wounded")
arrive("Target", {})
check("an empty target clears it", press(mudlet.key.T) == "No target")

count = #said
arrive("Effects", {effect("bless", "a priest", 60)})
check("the first effects list is not announced", #said == count)
arrive("Effects", {effect("bless", "a priest", 50), effect("haste", "a potion", 30), effect("shield", "you", 20)})
check("new effects are announced, a changed timer is not", said[#said] == "Gained haste, shield" and #said == count + 1)
arrive("Effects", {effect("haste", "a potion", 20), effect("bless", "a ring", 60)})
check("gained and lost together, the same name from another source counts as new",
  said[#said] == "Gained bless. Lost bless, shield")
count = #said
arrive("Effects", {effect("haste", "a potion", 10), effect("bless", "a ring", 50)})
check("no change, nothing said", #said == count)

handlers["sysDisconnectionEvent"]()
check("disconnecting clears vitals", press(mudlet.key.H) == "No health reading")
count = #said
arrive("Effects", {effect("haste", "a potion", 10)})
check("and the next effects list is a fresh start", #said == count)

dofile("status/status.lua")
local live = 0
for _ in pairs(keys) do live = live + 1 end
check("loading again replaces its keys instead of adding more", live == 4)

print(failures == 0 and "all passed" or (failures .. " failed"))
os.exit(failures == 0 and 0 or 1)

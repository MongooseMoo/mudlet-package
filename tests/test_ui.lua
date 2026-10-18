-- Runs ui/ui.lua against stand-ins for Mudlet's starter UI (mudlet-base-ui) and timers.
--   lua tests/test_ui.lua

local handlers, timers, shown = {}, {}, 0

function registerAnonymousEventHandler(event, fn) handlers[event] = fn; return event end
function killAnonymousEventHandler(id) handlers[id] = nil end
function tempTimer(_, fn) timers[#timers + 1] = fn end
local function runTimers()
  local due = timers
  timers = {}
  for _, fn in ipairs(due) do fn() end
end

BaseUI = {settings = {}}
function BaseUI.show()
  shown = shown + 1
  BaseUI.settings.standingAside = nil
end
function BaseUI.standAside(_, packageName) BaseUI.settings.standingAside = packageName end

local failures = 0
local function check(what, ok)
  if not ok then failures = failures + 1; print("FAIL " .. what) else print("ok   " .. what) end
end

-- A later session: the starter UI is still standing aside for this package.
BaseUI.settings.standingAside = "mongoose"
dofile("ui/ui.lua")
runTimers()
check("at load, brings back a starter UI that stood aside for mongoose", shown == 1)

-- An upgrade: the install event makes the starter UI stand aside again; ours runs after it.
BaseUI.standAside(nil, "mongoose")
handlers["sysServerGuiInstalled"](nil, "mongoose")
check("waits until the starter UI has stood aside", shown == 1)
runTimers()
check("then brings it back", shown == 2 and BaseUI.settings.standingAside == nil)

BaseUI.settings.standingAside = "othergame"
handlers["sysServerGuiInstalled"](nil, "othergame")
runTimers()
check("leaves alone a stand-aside for another package", shown == 2)

BaseUI.settings.standingAside = "mongoose"
BaseUI.settings.hidden = true
handlers["sysServerGuiInstalled"](nil, "mongoose")
runTimers()
check("keeps it hidden if the player hid it", shown == 2)

BaseUI = nil
mongoose.ui.restore()
check("does nothing without the starter UI", shown == 2)

print(failures == 0 and "all passed" or (failures .. " failed"))
os.exit(failures == 0 and 0 or 1)

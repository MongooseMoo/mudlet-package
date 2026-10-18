-- Mongoose automapper for Mudlet.
--
-- Builds Mudlet's map from GMCP Room.Info as the player walks: only rooms the
-- player has visited. Rooms carry no coordinates, so each new room is placed
-- one grid step from the room it was entered from, in the direction of the
-- exit taken. Mudlet's own click-to-walk and speedwalk work through
-- doSpeedWalk below, which sends one step at a time and stops on
-- Room.WrongDir or on arriving somewhere the map did not expect.
--
-- Room.Info (IRE shape, as Mongoose sends it):
--   {num, name, area, environment, exits = {n = 12, u = 40, hatch = 7}, weather}

mongoose = mongoose or {}
mongoose.mapper = mongoose.mapper or {}
local M = mongoose.mapper

mudlet = mudlet or {}
mudlet.mapper_script = true

local STEPS = {
  n = {0, 1, 0}, ne = {1, 1, 0}, e = {1, 0, 0}, se = {1, -1, 0},
  s = {0, -1, 0}, sw = {-1, -1, 0}, w = {-1, 0, 0}, nw = {-1, 1, 0},
  u = {0, 0, 1}, d = {0, 0, -1}, ["in"] = {1, 0, 0}, out = {-1, 0, 0},
}
-- Mudlet's names for the standard exits; anything else is a special exit.
local MUDLET_DIR = {
  n = "n", ne = "ne", e = "e", se = "se", s = "s", sw = "sw", w = "w", nw = "nw",
  u = "up", d = "down", ["in"] = "in", out = "out",
}
local SHORT = {
  north = "n", northeast = "ne", east = "e", southeast = "se", south = "s",
  southwest = "sw", west = "w", northwest = "nw", up = "u", down = "d",
}

-- Environment names to Mudlet environment numbers, with colours for the two
-- Mongoose sends for ordinary rooms. Other names (ROM sectors) get numbers
-- from 300 up in the order they are first seen, with Mudlet's default colour.
local ENV_FIRST = 300
M.envs = M.envs or {outdoors = ENV_FIRST, indoors = ENV_FIRST + 1}
local ENV_COLOURS = {outdoors = {110, 170, 100}, indoors = {150, 150, 150}}

M.previous = M.previous or nil   -- {id =, exits =} of the last room entered
M.pending = M.pending or {}      -- dest id -> list of {from =, key =} waiting for dest to exist
M.walk = M.walk or nil           -- {dirs =, rooms =, i =} during a speedwalk

local function short(key)
  key = string.lower(key)
  return SHORT[key] or key
end

local function areaId(name)
  if name == nil or name == "" then name = "Mongoose" end
  local id = getAreaTable()[name]
  if id then return id end
  return addAreaName(name)
end

local function envId(name)
  if name == nil or name == "" then return nil end
  name = string.lower(name)
  if not M.envs[name] then
    local top = ENV_FIRST + 1
    for _, id in pairs(M.envs) do
      if id > top then top = id end
    end
    M.envs[name] = top + 1
  end
  local id = M.envs[name]
  local colour = ENV_COLOURS[name]
  if colour then setCustomEnvColor(id, colour[1], colour[2], colour[3], 255) end
  return id
end

local function link(from, key, to)
  local dir = MUDLET_DIR[key]
  if dir then
    setExit(from, to, dir)
  else
    addSpecialExit(from, to, key)
  end
end

-- Where a new room goes: one step from the room just left, in the direction
-- of the exit that led here; otherwise the origin of its area.
local function placeNew(id)
  local prev = M.previous
  if prev and roomExists(prev.id) then
    for key, dest in pairs(prev.exits) do
      if dest == id then
        local x, y, z = getRoomCoordinates(prev.id)
        local step = STEPS[key] or {1, 0, 0}
        setRoomCoordinates(id, x + step[1], y + step[2], z + step[3])
        return
      end
    end
  end
  setRoomCoordinates(id, 0, 0, 0)
end

function M.onRoomInfo()
  local info = gmcp.Room and gmcp.Room.Info
  if not info or type(info.num) ~= "number" or info.num < 1 then return end
  local id = info.num
  local exits = {}
  for key, dest in pairs(info.exits or {}) do
    if type(dest) == "number" and dest >= 1 then exits[short(key)] = dest end
  end

  if not roomExists(id) then
    addRoom(id)
    setRoomArea(id, areaId(info.area))
    placeNew(id)
  end
  setRoomName(id, info.name or "")
  local env = envId(info.environment)
  if env then setRoomEnv(id, env) end

  for key, dest in pairs(exits) do
    if roomExists(dest) then
      link(id, key, dest)
    else
      if MUDLET_DIR[key] then setExitStub(id, MUDLET_DIR[key], true) end
      M.pending[dest] = M.pending[dest] or {}
      table.insert(M.pending[dest], {from = id, key = key})
    end
  end
  for _, waiting in ipairs(M.pending[id] or {}) do
    if roomExists(waiting.from) then link(waiting.from, waiting.key, id) end
  end
  M.pending[id] = nil

  M.previous = {id = id, exits = exits}
  centerview(id)
  M.walkArrived(id)
end

-- Speedwalk. Mudlet calls doSpeedWalk() after filling speedWalkDir and
-- speedWalkPath (for a map click, or after gotoRoom/getPath).
local function stopWalk(message)
  M.walk = nil
  if message then cecho("\n<orange>" .. message .. "\n") end
end

local function sendStep()
  local walk = M.walk
  send(walk.dirs[walk.i], false)
end

function doSpeedWalk()
  if #speedWalkDir == 0 then return end
  M.walk = {dirs = {}, rooms = {}, i = 1}
  for i, dir in ipairs(speedWalkDir) do
    M.walk.dirs[i] = dir
    M.walk.rooms[i] = tonumber(speedWalkPath[i])
  end
  sendStep()
end

function M.walkArrived(id)
  local walk = M.walk
  if not walk then return end
  if id ~= walk.rooms[walk.i] then
    stopWalk("Walk stopped: not where the map expected.")
    return
  end
  walk.i = walk.i + 1
  if walk.i > #walk.dirs then
    stopWalk("Arrived.")
    return
  end
  sendStep()
end

function M.onWrongDir()
  if M.walk then stopWalk("Walk stopped: no exit " .. tostring(gmcp.Room.WrongDir) .. ".") end
end

for _, handler in ipairs(M.handlers or {}) do killAnonymousEventHandler(handler) end
M.handlers = {
  registerAnonymousEventHandler("gmcp.Room.Info", M.onRoomInfo),
  registerAnonymousEventHandler("gmcp.Room.WrongDir", M.onWrongDir),
}

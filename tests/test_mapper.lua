-- Runs mapper/mapper.lua against stand-ins for the Mudlet mapper functions it uses.
--   lua tests/test_mapper.lua
-- The Room.Info payloads are the ones the live MOO sent a guest on 2026-10-18.

local rooms, areas, nextArea, sent, said, handlers, centred = {}, {}, 0, {}, {}, {}, nil
local envColours = {}

gmcp = {Room = {}}
mudlet = {}

function roomExists(id) return rooms[id] ~= nil end
function addRoom(id)
  rooms[id] = {exits = {}, stubs = {}, special = {}, x = 0, y = 0, z = 0}
  return true
end
function getAreaTable() return areas end
function addAreaName(name) nextArea = nextArea + 1; areas[name] = nextArea; return nextArea end
function setRoomArea(id, area) rooms[id].area = area end
function setRoomName(id, name) rooms[id].name = name end
function setRoomCoordinates(id, x, y, z) rooms[id].x, rooms[id].y, rooms[id].z = x, y, z end
function getRoomCoordinates(id) return rooms[id].x, rooms[id].y, rooms[id].z end
function setRoomEnv(id, env) rooms[id].env = env end
function setCustomEnvColor(id, r, g, b, a) envColours[id] = {r, g, b, a} end
function setExit(from, to, dir) rooms[from].exits[dir] = to; return true end
function setExitStub(id, dir, on) rooms[id].stubs[dir] = on end
function addSpecialExit(from, to, command) rooms[from].special[command] = to end
function centerview(id) centred = id end
function send(command) sent[#sent + 1] = command end
function cecho(text) said[#said + 1] = (text:gsub("^\n<orange>", ""):gsub("\n$", "")) end
function registerAnonymousEventHandler(event, fn) handlers[event] = fn; return event end
function killAnonymousEventHandler(id) handlers[id] = nil end

local function arrive(info)
  gmcp.Room.Info = info
  handlers["gmcp.Room.Info"]()
end

local function wrongDir(dir)
  gmcp.Room.WrongDir = dir
  handlers["gmcp.Room.WrongDir"]()
end

local failures = 0
local function check(what, ok)
  if not ok then failures = failures + 1; print("FAIL " .. what) else print("ok   " .. what) end
end

dofile("mapper/mapper.lua")

local PARLOR = {area = "Georgie's Guesthouse", environment = "indoors", exits = {s = 3510, u = 4243, w = 6285},
  name = "The Parlor", num = 4241, weather = ""}
local GEORGE = {area = "Toint Town", environment = "outdoors", exits = {e = 5291, n = 4241, s = 5268, w = 442},
  name = "George Street", num = 3510, weather = ""}

check("claims the map for this script", mudlet.mapper_script == true)

arrive(PARLOR)
local parlor = rooms[4241]
check("adds the first room at the origin", parlor and parlor.x == 0 and parlor.y == 0 and parlor.z == 0)
check("names it and files it under its area", parlor.name == "The Parlor" and parlor.area == areas["Georgie's Guesthouse"])
check("colours indoor rooms", parlor.env ~= nil and envColours[parlor.env] ~= nil)
check("marks exits to unvisited rooms as stubs", parlor.stubs.s and parlor.stubs.up and parlor.stubs.w)
check("centres the view on the player", centred == 4241)

arrive(GEORGE)
local george = rooms[3510]
check("places the next room one step south", george.x == 0 and george.y == -1 and george.z == 0)
check("starts the new area", george.area == areas["Toint Town"] and george.area ~= parlor.area)
check("links back to a known room", george.exits.n == 4241)
check("links the waiting exit once its room exists", parlor.exits.s == 3510)
check("uses a different environment for outdoors", george.env ~= parlor.env)

arrive(GEORGE)
check("a revisit keeps the room where it was", george.x == 0 and george.y == -1)

-- Mudlet fills speedWalkDir and speedWalkPath, then calls doSpeedWalk.
speedWalkDir, speedWalkPath = {"n"}, {"4241"}
doSpeedWalk()
check("walks the first step", sent[#sent] == "n")
arrive(PARLOR)
check("announces arrival and ends the walk", said[#said] == "Arrived." and mongoose.mapper.walk == nil)

speedWalkDir, speedWalkPath = {"s", "w"}, {"3510", "442"}
doSpeedWalk()
check("sends only one step at a time", #sent == 2 and sent[2] == "s")
wrongDir("south")
check("stops on Room.WrongDir", mongoose.mapper.walk == nil and said[#said] == "Walk stopped: no exit south.")
arrive(GEORGE)
check("sends nothing after a stop", #sent == 2)

speedWalkDir, speedWalkPath = {"n", "u"}, {"4241", "4243"}
doSpeedWalk()
arrive({num = 9999, name = "Cellar", area = "Toint Town", exits = {}})
check("stops when a step arrives somewhere unexpected",
  mongoose.mapper.walk == nil and said[#said] == "Walk stopped: not where the map expected.")

arrive({num = 7000, name = "Deck", area = "Ship", exits = {hatch = 7001, north = 7002}})
check("keys long exit names by short direction", rooms[7000].stubs.n == true)
arrive({num = 7001, name = "Hold", area = "Ship", exits = {}})
check("named exits become special exits once their room exists", rooms[7000].special.hatch == 7001)

dofile("mapper/mapper.lua")
local count = 0
for _ in pairs(handlers) do count = count + 1 end
check("reloading replaces its handlers instead of adding more", count == 2)

if failures > 0 then
  print(failures .. " failed")
  os.exit(1)
end
print("all passed")

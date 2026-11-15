-- Runs layout/layout.lua against stand-ins for the Mudlet and Geyser functions it uses.
--   lua tests/test_layout.lua
-- The Room.Layout payload has the shape of the contract in the Mongoose hub's agent-notes/spatial-room-svg.md.

local said, handlers, aliases, nextAlias, files, windows = {}, {}, {}, 0, {}, {}

gmcp = {Room = {}, Char = {Name = {name = "#99", fullname = "Q"}}}

function echo(text) said[#said + 1] = (text:gsub("^\n%[Layout%] ", ""):gsub("\n$", "")) end
function registerAnonymousEventHandler(event, fn) handlers[event] = fn; return event end
function killAnonymousEventHandler(id) handlers[id] = nil end
function tempAlias(pattern, fn) nextAlias = nextAlias + 1; aliases[nextAlias] = {pattern = pattern, fn = fn}; return nextAlias end
function killAlias(id) aliases[id] = nil end
function getMudletHomeDir() return "/home" end
io.exists = function(path) return files[path] ~= nil end
function table.save(path, t) files[path] = {hidden = t.hidden} end
function table.load(path, into) for k, v in pairs(files[path]) do into[k] = v end end

local VIEW_W, VIEW_H = 400, 600
local function widget(cons)
  local w = cons
  w.shown = true
  function w:move(x, y) self.x, self.y = x, y end
  function w:resize(width, height) self.width, self.height = width, height end
  function w:setStyleSheet(css) self.css = css end
  function w:echo(text) self.text = text end
  function w:setToolTip(tip) self.tip = tip end
  function w:setWheelCallback(fn) self.wheel = fn end
  function w:show() self.shown = true end
  function w:hide() self.shown = false end
  function w:get_width() return VIEW_W end
  function w:get_height() return VIEW_H end
  windows[cons.name] = w
  return w
end
Geyser = {
  UserWindow = {new = function(_, cons) return widget(cons) end},
  Label = {new = function(_, cons) return widget(cons) end},
  ScrollBox = {new = function(_, cons) return widget(cons) end},
}

local function type_(line)
  for _, alias in pairs(aliases) do
    local arg = line:match("^layout (.+)$")
    if line == "layout" or arg then matches = {line, arg}; alias.fn(); return end
  end
end

local ROOM = {
  num = 1234,
  size = {4.0, 6.0, 2.5},
  exits = {
    {name = "west", to = 1235, at = {-2.0, -1.5, 0.0}, width = 0.9},
    {name = "hatch", to = 1236, at = {0.0, 3.0, 0.0}, width = 1.2},
  },
  things = {
    {id = "#5678", name = "oak table", kind = "object", fixed = false, mounted = false,
     shapes = {{box = {{-0.5, 0.5}, {0.2, 1.0}, {0.0, 0.75}}}, {sphere = {{0.1, 0.4, 0.9}, 0.15}}}},
    {id = "#5679", name = "lamp", kind = "object", fixed = false, mounted = false,
     shapes = {{sphere = {{0.0, 0.6, 0.9}, 0.15}}}},
    {id = "#99", name = "Q", kind = "player", fixed = true, mounted = false,
     shapes = {{box = {{1.0, 1.5}, {-2.0, -1.5}, {0.0, 1.8}}}}},
    {id = "#77", name = "Georgie", kind = "person", fixed = true, mounted = false,
     shapes = {{box = {{-1.5, -1.0}, {2.0, 2.5}, {0.0, 1.7}}}}},
  },
}

local function arrive(name, data)
  gmcp.Room[name] = data
  handlers["gmcp.Room." .. name]()
end

local function shown()
  local list = {}
  for i, lbl in ipairs(mongoose.layout.labels) do
    if lbl.shown then list[#list + 1] = lbl end
  end
  return list
end

local function find(tip)
  for _, lbl in ipairs(shown()) do
    if lbl.tip == tip and lbl.text == "" then return lbl end
  end
end

local failures = 0
local function check(what, ok, got)
  if not ok then
    failures = failures + 1
    print("FAIL " .. what .. (got ~= nil and (": got " .. tostring(got)) or ""))
  else
    print("ok   " .. what)
  end
end

dofile("layout/layout.lua")
local L = mongoose.layout

local table_ = L.footprint(ROOM.things[1])
check("a footprint is the union of its shapes from above",
  table_.x0 == -0.5 and table_.x1 == 0.5 and table_.y0 == 0.2 and table_.y1 == 1.0 and not table_.round)
check("a thing of one sphere is round", L.footprint(ROOM.things[2]).round == true)
check("a doorway is on the wall it is nearest",
  L.wall(ROOM, ROOM.exits[1].at) == "west" and L.wall(ROOM, ROOM.exits[2].at) == "north")

check("the window is not opened before a layout arrives", windows.mongooseRoomLayout == nil)
arrive("Info", {num = 1234, name = "The Parlor", exits = {w = 1235}})
arrive("Layout", ROOM)
check("a layout arriving prints nothing", #said == 0)
check("a layout opens the room window docked on the right",
  windows.mongooseRoomLayout and windows.mongooseRoomLayout.docked == true
  and windows.mongooseRoomLayout.dockPosition == "right")
check("the title names the room from Room.Info", windows.mongooseRoomLayoutTitle.text == "The Parlor (zoom 100%)")

-- 400 x 600 view, 28 px margin: min(344 / 4, 544 / 6) = 86 px per metre.
local floor = shown()[2]
check("the room is drawn to scale inside its margin",
  floor.x == 28 and floor.y == 28 and floor.width == 344 and floor.height == 516)
local tbl = find("oak table")
check("north is up: a thing's top edge is its north edge",
  tbl.x == 28 + 1.5 * 86 and tbl.y == 28 + 2 * 86 and tbl.width == 86 and tbl.height == 69)
local lamp, you, georgie = find("lamp"), find("You"), find("Georgie")
check("a round thing is drawn round", lamp.css:find("border%-radius") ~= nil)
check("you are drawn in your own colour and labelled You", you and you.css:find("240, 200, 60") ~= nil)
check("a person has a colour of its own", georgie.css:find("110, 190, 120") ~= nil)
local order = {}
for i, lbl in ipairs(shown()) do order[lbl.tip or ""] = order[lbl.tip or ""] or i end
check("what stands on a table is drawn over it", order["oak table"] < order["lamp"])
local west = find("west")
check("a doorway is a bar across its wall, to scale",
  west.x == 25 and west.width == 6 and west.height == math.floor(0.9 * 86 + 0.5)
  and west.y == math.floor(28 + 4.5 * 86 - 0.9 * 86 / 2 + 0.5))
local named = false
for _, lbl in ipairs(shown()) do
  if lbl.text == "hatch" then named = true end
end
check("doorways are named", named)
for _, lbl in ipairs(shown()) do
  check("label " .. tostring(lbl.tip) .. " zooms on the wheel", lbl.wheel == L.onWheel)
end
local scale
for _, lbl in ipairs(shown()) do
  if lbl.tip == "scale" and lbl.text ~= "" then scale = lbl.text end
end
-- 1 m is 86 px, at most a quarter of the 344 px room.
check("a scale bar of the longest round length up to a quarter of the room", scale == "1 m", scale)

type_("layout")
check("layout says the room size", said[1] == "Room 4.0 by 6.0 metres, 2.5 high, north up.")
check("layout says where you stand", said[2] == "You are 2.2 metres southeast of the centre.")
check("layout gives each exit by wall and direction from you",
  said[3] == "Exits: west on the west wall, 3.3 metres west of you; "
    .. "hatch on the north wall, 4.9 metres north of you.")
check("layout gives each thing with its size and direction from you, not you",
  said[4] == "Things: oak table, 1.0 by 0.8 metres, 2.7 metres northwest of you; "
    .. "lamp, 0.3 by 0.3 metres, 2.7 metres northwest of you; "
    .. "Georgie (person), 0.5 by 0.5 metres, 4.7 metres northwest of you.", said[4])

type_("layout zoom in")
check("zoom in scales the picture by a quarter", find("oak table").width == math.floor(86 * 1.25 + 0.5)
  and windows.mongooseRoomLayoutTitle.text == "The Parlor (zoom 125%)")
L.onWheel({angleDeltaY = -120})
check("the wheel zooms back out", find("oak table").width == 86)
type_("layout zoom in")
type_("layout zoom reset")
check("zoom reset returns to the fitted size", find("oak table").width == 86)

local before = #said
handlers.sysUserWindowResizeEvent("sysUserWindowResizeEvent", 500, 600, "mongooseRoomLayout")
check("a resize redraws without printing", #said == before)

arrive("Info", {num = 1234, name = "The Parlor", exits = {}})
check("Room.Info for the same room keeps the picture", #shown() > 2)
arrive("Info", {num = 4241, name = "George Street", exits = {}})
check("Room.Info for another room clears the picture", #shown() == 0
  and windows.mongooseRoomLayoutTitle.text == "No layout for this room")
type_("layout")
check("layout in a room without one says so", said[#said] == "No layout for this room.")

type_("layout hide")
check("layout hide hides the window and keeps the choice",
  windows.mongooseRoomLayout.shown == false and files["/home/mongoose_layout.lua"].hidden == true)
arrive("Layout", ROOM)
check("a hidden window is not redrawn", #shown() == 0)
dofile("layout/layout.lua")
check("the hidden choice survives a reload", L.hidden == true)
type_("layout show")
check("layout show draws and shows it again",
  windows.mongooseRoomLayout.shown == true and #shown() > 2 and files["/home/mongoose_layout.lua"].hidden == false)

local count, aliasCount = 0, 0
for _ in pairs(handlers) do count = count + 1 end
for _ in pairs(aliases) do aliasCount = aliasCount + 1 end
check("reloading replaces its handlers and alias instead of adding more", count == 4 and aliasCount == 1)

handlers.sysDisconnectionEvent()
check("disconnecting clears the picture", L.room == nil and #shown() == 0)

if failures > 0 then
  print(failures .. " failed")
  os.exit(1)
end
print("all passed")

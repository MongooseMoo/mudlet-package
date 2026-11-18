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
check("the title says the zoom", windows.mongooseRoomLayoutTitle.text == "Room layout (zoom 100%)")

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
  and windows.mongooseRoomLayoutTitle.text == "Room layout (zoom 125%)")
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

-- The Room.Layout the live MOO sent for room #1770, hub reports/room-layout-sample-2026-11-14.json, as Lua.
local function sample()
  return {
    exits = {
      {at = {0.0, -3.6, 0.0}, name = "south", to = 1751, width = 0.9},
      {at = {-2.7, 0.0, 0.0}, name = "west", to = 1767, width = 0.9},
    },
    num = 1770,
    size = {6.0, 8.0, 3.0},
    things = {
      {fixed = true, id = "#23011", kind = "object", mounted = false, name = "the west washer",
       shapes = {{box = {{-2.8, -2.2}, {1.0, 1.65}, {0.0, 0.85}}}}},
      {fixed = true, id = "#23028", kind = "object", mounted = false, name = "the east washer",
       shapes = {{box = {{-1.8, -1.2}, {1.0, 1.65}, {0.0, 0.85}}}}},
      {fixed = true, id = "#23036", kind = "object", mounted = false, name = "the west dryer",
       shapes = {{box = {{-2.8, -2.2}, {-2.0, -1.35}, {0.0, 0.85}}}}},
      {fixed = true, id = "#23041", kind = "object", mounted = false, name = "the east dryer",
       shapes = {{box = {{-1.8, -1.2}, {-2.0, -1.35}, {0.0, 0.85}}}}},
      {fixed = true, id = "#23253", kind = "object", mounted = false, name = "hand-wash tub",
       shapes = {{box = {{-0.5, 0.0}, {1.0, 1.45}, {0.0, 0.9}}}}},
      {fixed = true, id = "#23528", kind = "object", mounted = false, name = "laundry drying rack",
       shapes = {{box = {{1.0, 2.2}, {1.0, 1.6}, {0.0, 1.1}}}}},
      {fixed = true, id = "#23529", kind = "object", mounted = false, name = "folding table",
       shapes = {{box = {{0.5, 2.0}, {-2.0, -1.3}, {0.0, 0.8}}}}},
      {fixed = true, id = "#23535", kind = "object", mounted = false, name = "laundry supplies cabinet",
       shapes = {{box = {{1.8, 2.2}, {-1.0, -0.6}, {0.0, 0.6}}}}},
      {fixed = false, id = "#23884", kind = "object", mounted = false, name = "a glazed clay pot",
       shapes = {{box = {{0.0, 0.1}, {2.0, 2.1}, {0.0, 0.1}}}}},
      {fixed = false, id = "#31824", kind = "object", mounted = false, name = "laundry grid connection",
       shapes = {{box = {{0.0, 0.3}, {0.0, 0.15}, {0.0, 0.4}}}}},
      {fixed = false, id = "#31825", kind = "object", mounted = false, name = "laundry service panel",
       shapes = {{box = {{0.0, 0.299999828}, {0.0, 0.149999914}, {0.0, 0.399999771}}}}},
      {fixed = false, id = "#39832", kind = "object", mounted = false, name = "a puddle of water and copper",
       shapes = {}},
      {fixed = false, id = "#10211", kind = "object", mounted = false, name = "wall-mounted heat pump",
       shapes = {{box = {{-3.0, -2.2}, {-4.0, -3.75}, {0.0, 0.3}}}}},
    },
  }
end

arrive("Info", {num = 1770, name = "Laundry Room", exits = {s = 1751, w = 1767}})
arrive("Layout", sample())
-- 400 x 600 view: min(344 / 6, 544 / 8) = 57.33 px per metre; the room is 344 x 458.67 px.
local s = 344 / 6
local floor2 = shown()[2]
check("the sample room is drawn to scale", floor2.width == 344 and floor2.height == 459)
check("the sample's things with shapes are drawn", find("folding table") and find("wall-mounted heat pump")
  and find("folding table").width == math.floor(1.5 * s + 0.5))
check("a thing with no shapes is not drawn", find("a puddle of water and copper") == nil)
local south, west2 = find("south"), find("west")
check("a doorway inside the south wall is drawn on the wall, at its along-wall place",
  south.y == math.floor(28 + 8 * s - 3 + 0.5) and south.x == math.floor(28 + 3 * s - 0.9 * s / 2 + 0.5),
  south.x .. "," .. south.y)
check("a doorway inside the west wall is drawn on the wall", west2.x == 25
  and west2.y == math.floor(28 + 4 * s - 0.9 * s / 2 + 0.5), west2.x .. "," .. west2.y)

said = {}
type_("layout")
check("the sample room's size", said[1] == "Room 6.0 by 8.0 metres, 3.0 high, north up.", said[1])
check("with no you in the room, exits are placed from the centre",
  said[2] == "Exits: south on the south wall, 3.6 metres south of the centre; "
    .. "west on the west wall, 2.7 metres west of the centre.", said[2])
check("things are placed from the centre", said[3]:find("folding table, 1.5 by 0.7 metres, "
  .. "2.1 metres southeast of the centre", 1, true) ~= nil, said[3])
check("a thing with no shapes is still listed in words",
  said[3]:find("a puddle of water and copper, place not given", 1, true) ~= nil, said[3])

-- Classes and material, shaped like the live MOO's Room.Layout for room #25828 (hub
-- reports/room-layout-sample-25828-2026-11-14.json); the person's name is made up.
local KINDS = {
  num = 4242,
  size = {3.81, 5.13, 2.44},
  exits = {},
  things = {
    {id = "#29617", name = "coffee table", kind = "object", fixed = false, mounted = false,
     classes = {"table", "furniture", "thing", "gpo", "root_class"}, capabilities = {"support_surface"},
     material = {{fraction = 1.0, species = "pine"}},
     shapes = {{box = {{-0.4, 0.6}, {-1.665, -1.115}, {0.0, 0.4}}}}},
    {id = "#3963", name = "trek box", kind = "object", fixed = false, mounted = false,
     classes = {"radio", "audio_device", "thing", "gpo", "root_class"}, capabilities = {},
     material = {
       {fraction = 0.3, frozen_fraction = 1.0, phase = "solid", species = "circuitboard", vapor_fraction = 0.0},
       {fraction = 0.6, frozen_fraction = 1.0, phase = "solid", species = "plastic", vapor_fraction = 0.0},
       {fraction = 0.1, frozen_fraction = 1.0, phase = "solid", species = "steel", vapor_fraction = 0.0}},
     shapes = {{box = {{-0.947, -0.447}, {0.334, 0.734}, {0.0, 0.3}}}}},
    {id = "#29972", name = "weather station", kind = "object", fixed = true, mounted = true,
     classes = {"thing", "gpo", "root_class"}, capabilities = {}, material = {},
     shapes = {{box = {{-0.25, -0.15}, {-2.565, -2.465}, {1.5, 1.6}}}}},
    {id = "#1", name = "plain crate", kind = "object", fixed = false, mounted = false,
     shapes = {{box = {{0.0, 0.5}, {0.0, 0.5}, {0.0, 0.5}}}}},
    {id = "#2", name = "Visitor", kind = "player", fixed = true, mounted = false,
     classes = {"wiz", "prog", "builder", "player"}, material = {{fraction = 1.0, species = "flesh"}},
     shapes = {{box = {{1.0, 1.4}, {1.0, 1.4}, {0.0, 1.8}}}}},
  },
}
check("the main material is the largest fraction, extra keys ignored", L.mainMaterial(KINDS.things[2]) == "plastic")
check("no material when the list is empty", L.mainMaterial(KINDS.things[3]) == nil)
check("a thing is named with its nearest class and main material",
  L.named(KINDS.things[1]) == "coffee table (table, pine)", L.named(KINDS.things[1]))
check("an empty material list leaves the class alone",
  L.named(KINDS.things[3]) == "weather station (thing)", L.named(KINDS.things[3]))
check("a thing with neither keeps its name", L.named(KINDS.things[4]) == "plain crate")
check("a person keeps their name, with no class or material",
  L.named(KINDS.things[5]) == "Visitor (player)", L.named(KINDS.things[5]))

arrive("Info", {num = 4242, name = "Living Room", exits = {}})
arrive("Layout", KINDS)
check("the picture names a thing with its class and material", find("coffee table (table, pine)") ~= nil)
local labelText = false
for _, lbl in ipairs(shown()) do
  if lbl.text == "trek box (radio, plastic)" then labelText = true end
end
check("the label on the picture says it too", labelText)
check("a person in the picture keeps a plain name", find("Visitor") ~= nil)
said = {}
type_("layout")
check("layout says each thing with its class and material",
  said[3]:find("coffee table (table, pine), 1.0 by 0.6 metres", 1, true) ~= nil
  and said[3]:find("trek box (radio, plastic), ", 1, true) ~= nil
  and said[3]:find("weather station (thing), ", 1, true) ~= nil
  and said[3]:find("plain crate, ", 1, true) ~= nil
  and said[3]:find("Visitor (player), ", 1, true) ~= nil, said[3])

if failures > 0 then
  print(failures .. " failed")
  os.exit(1)
end
print("all passed")

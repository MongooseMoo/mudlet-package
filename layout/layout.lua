-- Mongoose room layout for Mudlet: a top-down picture of a spatial room from GMCP Room.Layout.
--
-- Room.Layout (contract: agent-notes/spatial-room-svg.md in the Mongoose hub) gives the room's size in metres,
-- its doorways and the things in it with their shapes, room-local: x east, y north, z up, x/y from the room's
-- centre. The picture is drawn with Geyser labels in a docked window, north up: walls, each thing's footprint
-- (lowest first, so what stands on a table shows over it), doorways named on their walls, you, and a scale bar.
-- The mouse wheel over the picture zooms, as do `layout zoom in`, `layout zoom out` and `layout zoom reset`.
-- `layout` prints the room in words: where you stand, then each exit and thing by distance and direction from
-- you. Nothing is printed when a layout arrives. `layout hide` and `layout show` put the window away and back,
-- and the choice is kept between sessions.
--
-- The server sends Room.Layout with Room.Info in spatial rooms only, so a Room.Info for another room clears
-- the picture. It does not follow moves inside a room: the package does not take Client.Spatial.

mongoose = mongoose or {}
mongoose.layout = mongoose.layout or {}
local L = mongoose.layout

L.room = L.room or nil       -- the last Room.Layout, while it is the room you are in
L.zoom = L.zoom or 1
L.labels = L.labels or {}    -- Geyser labels, reused from one drawing to the next in drawing order

local NAME = "mongooseRoomLayout"
local MARGIN = 28            -- pixels around the room, room for doorway names and the scale bar
local ZOOM_STEP = 1.25
local ZOOM_MIN, ZOOM_MAX = 0.25, 16
local SETTINGS = "mongoose_layout.lua"

local COLOURS = {
  object = "rgba(150, 170, 200, 150)", fixed = "rgba(120, 130, 150, 190)",
  person = "rgba(110, 190, 120, 200)", player = "rgba(90, 150, 230, 210)", you = "rgba(240, 200, 60, 230)",
}

local function say(text)
  echo("\n[Layout] " .. text .. "\n")
end

local function metres(n)
  return string.format("%.1f", n)
end

-- The top-down extent of a thing: the union of its boxes' x/y ranges and its spheres' circles.
function L.footprint(thing)
  local x0, x1, y0, y1
  local round = true
  for _, shape in ipairs(thing.shapes or {}) do
    local a0, a1, b0, b1
    if shape.box then
      a0, a1, b0, b1 = shape.box[1][1], shape.box[1][2], shape.box[2][1], shape.box[2][2]
      round = false
    elseif shape.sphere then
      local c, r = shape.sphere[1], shape.sphere[2]
      a0, a1, b0, b1 = c[1] - r, c[1] + r, c[2] - r, c[2] + r
    end
    if a0 then
      x0 = x0 and math.min(x0, a0) or a0
      x1 = x1 and math.max(x1, a1) or a1
      y0 = y0 and math.min(y0, b0) or b0
      y1 = y1 and math.max(y1, b1) or b1
    end
  end
  if not x0 then return nil end
  return {x0 = x0, x1 = x1, y0 = y0, y1 = y1, round = round and #thing.shapes == 1}
end

-- The lowest z any of a thing's shapes reaches, for drawing order.
local function bottom(thing)
  local low = math.huge
  for _, shape in ipairs(thing.shapes or {}) do
    if shape.box then low = math.min(low, shape.box[3][1]) end
    if shape.sphere then low = math.min(low, shape.sphere[1][3] - shape.sphere[2]) end
  end
  return low
end

local function me()
  local name = gmcp.Char and gmcp.Char.Name and gmcp.Char.Name.name
  return name
end

-- The wall a doorway point stands on: the one it is nearest.
function L.wall(room, at)
  local w, d = room.size[1] / 2, room.size[2] / 2
  local toEastWest, toNorthSouth = w - math.abs(at[1]), d - math.abs(at[2])
  if toEastWest <= toNorthSouth then
    return at[1] >= 0 and "east" or "west"
  end
  return at[2] >= 0 and "north" or "south"
end

-- Mudlet runs Lua 5.1 (Mudlet's src/CMakeLists.txt: find_package(Lua51)), where two-argument atan is math.atan2;
-- the tests run under Lua 5.4, which has only math.atan(y, x).
local atan2 = math.atan2 or math.atan

local COMPASS = {"east", "northeast", "north", "northwest", "west", "southwest", "south", "southeast"}

-- "2.1 metres northwest", from (fx, fy) to (tx, ty).
local function bearing(fx, fy, tx, ty)
  local dx, dy = tx - fx, ty - fy
  local distance = math.sqrt(dx * dx + dy * dy)
  if distance < 0.25 then return "beside" end
  local angle = atan2(dy, dx)
  local sector = math.floor((angle / (math.pi / 4)) + 0.5) % 8
  return metres(distance) .. " metres " .. COMPASS[sector + 1]
end

local function centre(box)
  return (box.x0 + box.x1) / 2, (box.y0 + box.y1) / 2
end

-- The lines `layout` prints.
function L.describe(room)
  local lines = {}
  local size = room.size
  lines[1] = "Room " .. metres(size[1]) .. " by " .. metres(size[2]) .. " metres, " .. metres(size[3])
    .. " high, north up."
  local myId = me()
  local fx, fy, from = 0, 0, "the centre"
  for _, thing in ipairs(room.things or {}) do
    local box = thing.id == myId and L.footprint(thing)
    if box then
      fx, fy = centre(box)
      from = "you"
      local where = bearing(0, 0, fx, fy)
      lines[#lines + 1] = where == "beside" and "You are at the centre."
        or ("You are " .. where .. " of the centre.")
    end
  end
  local exits = {}
  for _, exit in ipairs(room.exits or {}) do
    local where = bearing(fx, fy, exit.at[1], exit.at[2])
    exits[#exits + 1] = exit.name .. " on the " .. L.wall(room, exit.at) .. " wall, "
      .. (where == "beside" and ("beside " .. from) or (where .. " of " .. from))
  end
  lines[#lines + 1] = #exits > 0 and ("Exits: " .. table.concat(exits, "; ") .. ".") or "No exits."
  local things = {}
  for _, thing in ipairs(room.things or {}) do
    if thing.id ~= myId then
      local box = L.footprint(thing)
      local kind = thing.kind == "object" and "" or (" (" .. thing.kind .. ")")
      if box then
        local cx, cy = centre(box)
        local where = bearing(fx, fy, cx, cy)
        things[#things + 1] = thing.name .. kind .. ", " .. metres(box.x1 - box.x0) .. " by "
          .. metres(box.y1 - box.y0) .. " metres, " .. (where == "beside" and ("beside " .. from)
          or (where .. " of " .. from))
      else
        -- a thing with no shapes has no place to draw, but it is in the room
        things[#things + 1] = thing.name .. kind .. ", place not given"
      end
    end
  end
  lines[#lines + 1] = #things > 0 and ("Things: " .. table.concat(things, "; ") .. ".") or "Nothing else here."
  return lines
end

local function escape(text)
  return (tostring(text):gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"))
end

-- What to draw for a room in a view of width x height pixels at a zoom: a list of
-- {x, y, w, h, css, text, tip}, back to front, in pixels from the top left of the picture.
function L.items(room, width, height, zoom)
  local w, d = room.size[1], room.size[2]
  local fit = math.min((width - 2 * MARGIN) / w, (height - 2 * MARGIN) / d)
  local s = math.max(fit, 1) * zoom
  local function px(x) return MARGIN + (x + w / 2) * s end
  local function py(y) return MARGIN + (d / 2 - y) * s end
  local items = {}
  local function add(item) items[#items + 1] = item end
  local roomW, roomH = w * s, d * s

  add({x = 0, y = 0, w = math.floor(roomW + 2 * MARGIN), h = math.floor(roomH + 2 * MARGIN),
    css = "background-color: rgb(24, 26, 32);"})
  add({x = MARGIN, y = MARGIN, w = roomW, h = roomH,
    css = "background-color: rgb(52, 50, 46); border: 3px solid rgb(220, 215, 200);"})

  local myId = me()
  local drawn = {}
  for _, thing in ipairs(room.things or {}) do
    local box = L.footprint(thing)
    if box then drawn[#drawn + 1] = {thing = thing, box = box, low = bottom(thing)} end
  end
  table.sort(drawn, function(a, b)
    if a.low ~= b.low then return a.low < b.low end
    return (a.thing.id == myId and 1 or 0) < (b.thing.id == myId and 1 or 0)
  end)
  local names = {}
  for _, entry in ipairs(drawn) do
    local thing, box = entry.thing, entry.box
    local mine = thing.id == myId
    local colour = mine and COLOURS.you or COLOURS[thing.kind] or COLOURS.object
    if thing.kind == "object" and thing.fixed then colour = COLOURS.fixed end
    local bw, bh = math.max((box.x1 - box.x0) * s, 3), math.max((box.y1 - box.y0) * s, 3)
    local border = thing.mounted and "dashed" or "solid"
    local radius = box.round and ("border-radius: " .. math.floor(math.min(bw, bh) / 2) .. "px;") or ""
    local label = mine and "You" or thing.name
    add({x = px(box.x0), y = py(box.y1), w = bw, h = bh,
      css = "background-color: " .. colour .. "; border: 1px " .. border .. " rgb(235, 235, 235);" .. radius,
      tip = label})
    local tw = math.max(bw, #label * 7 + 8)
    names[#names + 1] = {x = px(box.x0) + bw / 2 - tw / 2, y = py(box.y1) + bh / 2 - 8, w = tw, h = 16,
      css = "background-color: rgba(0, 0, 0, 0); color: rgb(255, 255, 255);", text = escape(label), tip = label}
  end

  for _, exit in ipairs(room.exits or {}) do
    local wall = L.wall(room, exit.at)
    local cx, cy = px(exit.at[1]), py(exit.at[2])
    local span = math.max((exit.width or 0.9) * s, 6)
    local css = "background-color: rgb(80, 210, 230);"
    local tw = #exit.name * 7 + 10
    if wall == "north" or wall == "south" then
      cy = wall == "north" and MARGIN or MARGIN + roomH
      add({x = cx - span / 2, y = cy - 3, w = span, h = 6, css = css, tip = exit.name})
      names[#names + 1] = {x = cx - tw / 2, y = wall == "north" and cy - 22 or cy + 5, w = tw, h = 16,
        css = "background-color: rgba(0, 0, 0, 0); color: rgb(80, 210, 230);", text = escape(exit.name),
        tip = exit.name}
    else
      cx = wall == "west" and MARGIN or MARGIN + roomW
      add({x = cx - 3, y = cy - span / 2, w = 6, h = span, css = css, tip = exit.name})
      names[#names + 1] = {x = wall == "west" and cx + 6 or cx - tw - 6, y = cy - 8, w = tw, h = 16,
        css = "background-color: rgba(0, 0, 0, 0); color: rgb(80, 210, 230);", text = escape(exit.name),
        tip = exit.name}
    end
  end
  for _, item in ipairs(names) do add(item) end

  -- A scale bar of the longest round length up to a quarter of the room's drawn width.
  local length = 1
  for _, candidate in ipairs({0.1, 0.25, 0.5, 1, 2, 5, 10, 20, 50, 100}) do
    if candidate * s <= roomW / 4 + 1 then length = candidate end
  end
  local barW = length * s
  add({x = MARGIN, y = MARGIN + roomH + 8, w = barW, h = 4, css = "background-color: rgb(235, 235, 235);",
    tip = "scale"})
  add({x = MARGIN + barW + 6, y = MARGIN + roomH + 2, w = 60, h = 16,
    css = "background-color: rgba(0, 0, 0, 0); color: rgb(235, 235, 235);",
    text = (length < 1 and (math.floor(length * 100 + 0.5) .. " cm") or (length .. " m")), tip = "scale"})
  add({x = MARGIN, y = 4, w = 40, h = 16, css = "background-color: rgba(0, 0, 0, 0); color: rgb(235, 235, 235);",
    text = "N &#8593;", tip = "north"})

  for _, item in ipairs(items) do
    item.x, item.y = math.floor(item.x + 0.5), math.floor(item.y + 0.5)
    item.w, item.h = math.max(math.floor(item.w + 0.5), 1), math.max(math.floor(item.h + 0.5), 1)
  end
  return items
end

-- Window and drawing.

local function settingsPath()
  return getMudletHomeDir() .. "/" .. SETTINGS
end

function L.loadSettings()
  local settings = {}
  if io.exists(settingsPath()) then table.load(settingsPath(), settings) end
  L.hidden = settings.hidden == true
end

local function saveSettings()
  table.save(settingsPath(), {hidden = L.hidden})
end

function L.onWheel(event)
  if event.angleDeltaY > 0 then L.setZoom(L.zoom * ZOOM_STEP) end
  if event.angleDeltaY < 0 then L.setZoom(L.zoom / ZOOM_STEP) end
end

local function ensureWindow()
  if L.window then return end
  L.window = Geyser.UserWindow:new({name = NAME, titleText = "Room layout", docked = true, dockPosition = "right"})
  L.title = Geyser.Label:new({name = NAME .. "Title", x = 0, y = 0, width = "100%", height = 22}, L.window)
  L.title:setStyleSheet("background-color: rgb(24, 26, 32); color: rgb(235, 235, 235); padding-left: 4px;")
  L.box = Geyser.ScrollBox:new({name = NAME .. "Box", x = 0, y = 22, width = "100%", height = "100%-22px"},
    L.window)
end

local function label(i)
  local lbl = L.labels[i]
  if not lbl then
    lbl = Geyser.Label:new({name = NAME .. i, x = 0, y = 0, width = 1, height = 1}, L.box)
    lbl:setWheelCallback(L.onWheel)
    L.labels[i] = lbl
  end
  return lbl
end

local function titleText()
  local room = L.room
  if not room then return "No layout for this room" end
  return "Room layout (zoom " .. math.floor(L.zoom * 100 + 0.5) .. "%)"
end

function L.draw()
  if L.hidden then return end
  ensureWindow()
  L.title:echo(titleText(), "nocolor")
  local items = L.room and L.items(L.room, L.box:get_width(), L.box:get_height(), L.zoom) or {}
  for i, item in ipairs(items) do
    local lbl = label(i)
    lbl:move(item.x, item.y)
    lbl:resize(item.w, item.h)
    lbl:setStyleSheet(item.css)
    lbl:echo(item.text or "", "nocolor", "c9")
    lbl:setToolTip(item.tip or "")
    lbl:show()
  end
  for i = #items + 1, #L.labels do L.labels[i]:hide() end
end

function L.setZoom(zoom)
  L.zoom = math.max(ZOOM_MIN, math.min(ZOOM_MAX, zoom))
  L.draw()
end

function L.onLayout()
  local room = gmcp.Room.Layout
  if type(room) ~= "table" or type(room.size) ~= "table" then return end
  L.room = room
  L.draw()
end

function L.onRoomInfo()
  local info = gmcp.Room.Info
  if L.room and info and info.num ~= L.room.num then
    L.room = nil
    L.draw()
  end
end

function L.onResize(_, _, _, name)
  if name == NAME and L.room then L.draw() end
end

function L.onDisconnect()
  L.room = nil
  if L.window then L.draw() end
end

function L.command(arg)
  arg = arg and arg:lower() or ""
  if arg == "" then
    if not L.room then return say("No layout for this room.") end
    for _, line in ipairs(L.describe(L.room)) do say(line) end
  elseif arg == "zoom in" then
    L.setZoom(L.zoom * ZOOM_STEP)
  elseif arg == "zoom out" then
    L.setZoom(L.zoom / ZOOM_STEP)
  elseif arg == "zoom reset" then
    L.setZoom(1)
  elseif arg == "hide" then
    L.hidden = true
    saveSettings()
    if L.window then L.window:hide() end
    say("Room layout window hidden. layout show brings it back.")
  elseif arg == "show" then
    L.hidden = false
    saveSettings()
    L.draw()
    L.window:show()
  else
    say("layout: the room in words. layout zoom in, zoom out, zoom reset. layout hide, layout show.")
  end
end

L.loadSettings()

for _, handler in ipairs(L.handlers or {}) do killAnonymousEventHandler(handler) end
L.handlers = {
  registerAnonymousEventHandler("gmcp.Room.Layout", L.onLayout),
  registerAnonymousEventHandler("gmcp.Room.Info", L.onRoomInfo),
  registerAnonymousEventHandler("sysUserWindowResizeEvent", L.onResize),
  registerAnonymousEventHandler("sysDisconnectionEvent", L.onDisconnect),
}

if L.alias then killAlias(L.alias) end
L.alias = tempAlias("^layout(?: (.+))?$", function() L.command(matches[2]) end)

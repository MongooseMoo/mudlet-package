-- Mongoose status for Mudlet: spoken readouts of GMCP Char.Vitals, Char.Effects and Char.Target.
--
-- Char.Vitals is a list of meters {id, kind, label, value, max, words, rate}, kind being health, body or power.
-- The server sends it when a value changes, never on a timer; between messages a meter moves by its rate (per
-- second) from the moment it arrived, kept within 0 and its max. Alt+H says health, Alt+M every power meter,
-- Alt+V the body meter, Alt+T the target. Health falling below 50, 25 or 10 percent is said once as it falls.
-- Char.Effects is the whole list of effects on each change; what came and went is said.

mongoose = mongoose or {}
mongoose.status = mongoose.status or {}
local S = mongoose.status

S.vitals = S.vitals or {}  -- the last Char.Vitals list
S.vitalsAt = S.vitalsAt or 0 -- getEpoch() when it arrived
S.effects = S.effects       -- the last Char.Effects list; nil until the first, which is not announced
S.target = S.target or {}   -- the last Char.Target; {} when there is none

local WARNINGS = {10, 25, 50} -- lowest first: one fall past several is said at the lowest

local function percent(meter, at)
  local value = meter.value + meter.rate * (at - S.vitalsAt)
  value = math.max(0, math.min(meter.max, value))
  return math.floor(value / meter.max * 100 + 0.5)
end

local function describe(label, pct, words)
  return label .. " " .. pct .. " percent" .. (words and (", " .. words) or "")
end

local function meters(kind)
  local found = {}
  for _, meter in ipairs(S.vitals) do
    if meter.kind == kind then found[#found + 1] = meter end
  end
  return found
end

local function readout(kind)
  local now = getEpoch()
  local parts = {}
  for _, meter in ipairs(meters(kind)) do
    parts[#parts + 1] = describe(meter.label, percent(meter, now), meter.words)
  end
  announce(#parts > 0 and table.concat(parts, ". ") or ("No " .. kind .. " reading"))
end

function S.sayHealth() readout("health") end
function S.sayPower() readout("power") end
function S.sayBody() readout("body") end

function S.sayTarget()
  local target = S.target
  if not target.name then return announce("No target") end
  announce(describe(target.name, math.floor(target.value * 100 + 0.5), target.words))
end

function S.onVitals()
  local now = getEpoch()
  local before = meters("health")[1]
  local beforePct = before and percent(before, now)
  S.vitals = gmcp.Char.Vitals
  S.vitalsAt = now
  local after = meters("health")[1]
  if not (before and after) then return end
  local afterPct = percent(after, now)
  for _, threshold in ipairs(WARNINGS) do
    if afterPct < threshold and beforePct >= threshold then
      return announce(after.label .. " below " .. threshold .. " percent, " .. after.words)
    end
  end
end

local function effectKey(effect)
  return effect.section .. "\0" .. effect.name .. "\0" .. effect.source
end

-- Names of the effects in list a that are not in list b.
local function missing(a, b)
  local inB = {}
  for _, effect in ipairs(b) do inB[effectKey(effect)] = true end
  local names = {}
  for _, effect in ipairs(a) do
    if not inB[effectKey(effect)] then names[#names + 1] = effect.name end
  end
  return names
end

function S.onEffects()
  local old, new = S.effects, gmcp.Char.Effects
  S.effects = new
  if not old then return end
  local parts = {}
  local gained, lost = missing(new, old), missing(old, new)
  if #gained > 0 then parts[#parts + 1] = "Gained " .. table.concat(gained, ", ") end
  if #lost > 0 then parts[#parts + 1] = "Lost " .. table.concat(lost, ", ") end
  if #parts > 0 then announce(table.concat(parts, ". ")) end
end

function S.onTarget()
  S.target = gmcp.Char.Target
end

function S.onDisconnect()
  S.vitals = {}
  S.vitalsAt = 0
  S.effects = nil
  S.target = {}
end

for _, handler in ipairs(S.handlers or {}) do killAnonymousEventHandler(handler) end
S.handlers = {
  registerAnonymousEventHandler("gmcp.Char.Vitals", S.onVitals),
  registerAnonymousEventHandler("gmcp.Char.Effects", S.onEffects),
  registerAnonymousEventHandler("gmcp.Char.Target", S.onTarget),
  registerAnonymousEventHandler("sysDisconnectionEvent", S.onDisconnect),
}

for _, id in ipairs(S.keys or {}) do killKey(id) end
local Alt = mudlet.keymodifier.Alt
S.keys = {
  tempKey(Alt, mudlet.key.H, S.sayHealth),
  tempKey(Alt, mudlet.key.M, S.sayPower),
  tempKey(Alt, mudlet.key.V, S.sayBody),
  tempKey(Alt, mudlet.key.T, S.sayTarget),
}

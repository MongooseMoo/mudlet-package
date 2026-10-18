-- Mongoose and Mudlet's starter UI.
--
-- When a game's package arrives through Client.GUI, Mudlet's starter UI stands aside: it hides its dock (map,
-- chat tabs, vitals) and stays aside in later sessions. This package brings keys and a map script, not an
-- interface of its own, so it brings the starter UI back. A player who hid it themselves keeps it hidden.

mongoose = mongoose or {}
mongoose.ui = mongoose.ui or {}
local U = mongoose.ui

function U.restore()
  if type(BaseUI) ~= "table" or type(BaseUI.show) ~= "function" or type(BaseUI.settings) ~= "table" then return end
  if BaseUI.settings.standingAside == "mongoose" and not BaseUI.settings.hidden then
    BaseUI.show()
  end
end

for _, handler in ipairs(U.handlers or {}) do killAnonymousEventHandler(handler) end
U.handlers = {
  -- The starter UI stands aside on this same event; run after it has.
  registerAnonymousEventHandler("sysServerGuiInstalled", function(_, packageName)
    if packageName == "mongoose" then tempTimer(0, U.restore) end
  end),
}
tempTimer(0, U.restore)

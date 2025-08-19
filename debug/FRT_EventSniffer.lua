-- Fingbel Raid Tool — Event Sniffer (WoW 1.12 / Lua 5.0)
-- FRT_EventSniffer.lua

FRT = FRT or {}
FRT.Sniff = FRT.Sniff or {}
local S = FRT.Sniff

-- Very noisy events you probably don't want to see every frame
local EXCLUDE = {
  ACTIONBAR_UPDATE_STATE = true,
  BAG_UPDATE_COOLDOWN    = true,
  CURSOR_UPDATE          = true,
  UPDATE_MOUSEOVER_UNIT  = true,
  WORLD_MAP_UPDATE       = true,
  MINIMAP_UPDATE_ZOOM    = true,
  PLAYER_AURAS_CHANGED   = true, -- can be very spammy on some cores
  UNIT_AURA              = true, -- idem
}
local function IsExcludedEvent(name)
  if EXCLUDE[name] then return true end
  if not name then return true end
  
  -- prefix filters
  if string.find(name, "UNIT_HEALTH", 1, true) == 1 then return true end
  if string.find(name, "UNIT_MANA",   1, true) == 1 then return true end
  if string.find(name, "CHAT_MSG_CHANNEL",   1, true) == 1 then return true end
  if string.find(name, "CHAT_MSG_ADDON",   1, true) == 1 then return true end
  --if string.find(name, "UNIT_",   1, true) == 1 then return true end
  return false
end

local function say(msg)
  if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage(msg) end
end

-- Enable the sniffer. pattern is optional (e.g. "SPELL", "TALENT", "BAG").
function S.Enable(pattern)
  if S.frame then S.Disable() end

  local f = CreateFrame("Frame"); S.frame = f
  f:RegisterAllEvents()
  S.pattern = pattern
  S.lastShownAt = {}   -- per-event throttle timestamps

  f:SetScript("OnEvent", function()
    local e = event
    if IsExcludedEvent(e) then return end

    -- (keep the pattern filter & throttle exactly as before)
    if S.pattern and S.pattern ~= "" then
        local nameU = string.upper(e)
        local patU  = string.upper(S.pattern)
        if not string.find(nameU, patU, 1, true) then return end
    end

    local now = GetTime() or 0
    local last = S.lastShownAt[e] or 0
    if (now - last) < 0.10 then return end
    S.lastShownAt[e] = now

    local parts, i = {}, 1
    while i <= 10 do
        local v = getglobal("arg"..i)
        if v == nil then break end
        parts[i] = tostring(v)
        i = i + 1
    end

    local line = "|cff99ccffEVT|r "..e
    if i > 1 then line = line .. ": " .. table.concat(parts, " | ") end
    if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage(line) end
    end)

  say("|cff66ccffFRT|r Sniffer ON"
      .. (pattern and pattern ~= "" and (" (filter: "..pattern..")") or " (all events)"))
end

function S.Disable()
  if not S.frame then return end
  S.frame:UnregisterAllEvents()
  S.frame:SetScript("OnEvent", nil)
  S.frame = nil
  say("|cff66ccffFRT|r Sniffer OFF")
end

-- Slash commands:
SLASH_FRTSNIFF1 = "/frtsniff"
SlashCmdList["FRTSNIFF"] = function(msg)
  msg = tostring(msg or "")
  if msg == "" or msg == "all" then
    S.Enable("")                 -- show all (except EXCLUDE)
  elseif msg == "off" then
    S.Disable()
  else
    -- Example: /frtsniff SPELL  /frtsniff TALENT  /frtsniff BAG
    S.Enable(msg)
  end
end

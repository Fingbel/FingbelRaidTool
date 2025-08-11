-- FRT_Events.lua
-- Group-related event bridge with debounce

FRT = FRT or {}
FRT.GroupEvents = FRT.GroupEvents or {}

do
  local frame, armedFn = nil, nil
  local debounced = nil

  local function ensureFrame()
    if frame then return frame end
    frame = CreateFrame("Frame")
    frame:SetScript("OnEvent", function()
      if debounced then debounced() end
    end)
    return frame
  end

  function FRT.GroupEvents.Enable(callback, debounceSeconds)
    local f = ensureFrame()
    armedFn = callback
    debounced = FRT.Scheduler.Debounce(debounceSeconds or 0.15, function()
      if type(armedFn) == "function" then pcall(armedFn) end
    end)

    f:RegisterEvent("UNIT_AURA")
    f:RegisterEvent("PLAYER_AURAS_CHANGED")
    f:RegisterEvent("RAID_ROSTER_UPDATE")
    f:RegisterEvent("PARTY_MEMBERS_CHANGED")
    f:RegisterEvent("PLAYER_ENTERING_WORLD")
    f:RegisterEvent("ZONE_CHANGED_NEW_AREA")
  end

  function FRT.GroupEvents.Disable()
    if not frame then return end
    frame:UnregisterEvent("UNIT_AURA")
    frame:UnregisterEvent("PLAYER_AURAS_CHANGED")
    frame:UnregisterEvent("RAID_ROSTER_UPDATE")
    frame:UnregisterEvent("PARTY_MEMBERS_CHANGED")
    frame:UnregisterEvent("PLAYER_ENTERING_WORLD")
    frame:UnregisterEvent("ZONE_CHANGED_NEW_AREA")
  end
end

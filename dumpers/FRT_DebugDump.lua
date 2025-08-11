-- Fingbel Raid Tool — Debug  Info Dump 

SLASH_FRTME1 = "/frtme"

SlashCmdList["FRTME"] = function()
    local name = UnitName("player") or "?"
    local classLoc, classEN = UnitClass("player")
    local race = UnitRace("player") or "?"
    local level = UnitLevel("player") or "?"
    local faction = (UnitFactionGroup and UnitFactionGroup("player")) or "?"

    DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[FRT]|r === Character Info ===")
    DEFAULT_CHAT_FRAME:AddMessage(string.format("%s (%s %s %d) — %s", name, race, classLoc or "?", level, faction))
    DEFAULT_CHAT_FRAME:AddMessage(string.format("Class (EN): %s", classEN or "?"))

    -- Attributes
    local labels = {"STR","AGI","STA","INT","SPI"}
    for i=1,5 do
        local base, eff = UnitStat("player", i)
        DEFAULT_CHAT_FRAME:AddMessage(string.format("%s: %d (eff %d)", labels[i], base or 0, eff or 0))
    end

    -- Resistances 
    local resistNames = {"Armor","Holy","Fire","Nature","Frost","Shadow","Arcane"}
    for i=0,6 do
        local base, total = UnitResistance("player", i)
        DEFAULT_CHAT_FRAME:AddMessage(string.format("%s: base=%d total=%d", resistNames[i+1] or i, base or 0, total or 0))
    end

    -- Equipment quick list
    local slots = {
        "HeadSlot","NeckSlot","ShoulderSlot","ChestSlot","WaistSlot","LegsSlot","FeetSlot",
        "WristSlot","HandsSlot","Finger0Slot","Finger1Slot","Trinket0Slot","Trinket1Slot",
        "BackSlot","MainHandSlot","SecondaryHandSlot","RangedSlot"
    }
    for _, token in ipairs(slots) do
        local id = GetInventorySlotInfo(token)
        if id then
            local link = GetInventoryItemLink("player", id)
            DEFAULT_CHAT_FRAME:AddMessage(string.format("%-14s: %s", token, link or "(empty)"))
        end
    end
end



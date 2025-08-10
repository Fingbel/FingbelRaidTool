-- Fingbel Raid Tool — Buff Dump 

local function p(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[FRT]|r " .. tostring(msg))
end

-- Hidden tooltip to scan buff names
if not FRT_ScanTip then
    CreateFrame("GameTooltip", "FRT_ScanTip", UIParent, "GameTooltipTemplate")
    FRT_ScanTip:SetOwner(UIParent, "ANCHOR_NONE")
end

local function tipName()
    local fs = getglobal("FRT_ScanTipTextLeft1")
    if fs and fs.GetText then
        return fs:GetText()
    end
    return nil
end

local function DumpAuras(kind) -- "HELPFUL" or "HARMFUL"
    p("== " .. ((kind == "HARMFUL") and "Debuffs" or "Buffs") .. " ==")
    local found = 0

    for i = 0, 31 do
        local buffIndex = GetPlayerBuff(i, kind)
        if buffIndex >= 0 then
            FRT_ScanTip:ClearLines()
            FRT_ScanTip:SetPlayerBuff(buffIndex)
            local name = tipName() or "<no name>"
            local tex = GetPlayerBuffTexture(buffIndex) or ""
            local timeLeft = GetPlayerBuffTimeLeft(buffIndex) or 0

            p(string.format(" - %s | %ds left | tex=%s", name, timeLeft, tex))
            found = found + 1
        end
    end

    if found == 0 then
        p("(none)")
    end
end

SLASH_FRTBUFFS1 = "/frtbuffs"
SlashCmdList["FRTBUFFS"] = function()
    p("Dumping buffs & debuffs…")
    DumpAuras("HELPFUL")
    DumpAuras("HARMFUL")
end

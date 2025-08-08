-- Always make sure our SV is a table
if type(FRT_Saved) ~= "table" then
    FRT_Saved = {}
end
if FRT_Saved.note == nil then
    FRT_Saved.note = ""
end

local ADDON_PREFIX = "FRT"

-- Debug helper
local function FRT_Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[FRT]|r " .. tostring(msg))
end

-- Safe send (trim to ~240 chars for 1.12 addon channel limits)
local function FRT_SendAddon(channel, text)
    text = tostring(text or "")
    if string.len(text) > 240 then
        text = string.sub(text, 1, 240)
        FRT_Print("Note truncated to 240 chars for sending.")
    end
    if RegisterAddonMessagePrefix then
        RegisterAddonMessagePrefix(ADDON_PREFIX)
    end
    SendAddonMessage(ADDON_PREFIX, text, channel)
end

-- Initialize
local f = CreateFrame("Frame")
f:RegisterEvent("VARIABLES_LOADED")
f:RegisterEvent("CHAT_MSG_ADDON")
f:SetScript("OnEvent", function()
    if event == "VARIABLES_LOADED" then
        FRT_Print("Addon loaded. Use /frt set <text>, /frt show, /frt share")
        if RegisterAddonMessagePrefix then
            RegisterAddonMessagePrefix(ADDON_PREFIX)
        end
    elseif event == "CHAT_MSG_ADDON" then
        local prefix, message, channel, sender = arg1, arg2, arg3, arg4
        if prefix == ADDON_PREFIX and sender ~= UnitName("player") then
            -- Auto-apply received note so everyone stays synced
            FRT_Saved.note = tostring(message or "")
            FRT_Print("Note from " .. (sender or "unknown") .. ": " .. FRT_Saved.note)
        end
    end
end)

-- Slash command
SLASH_FRT1 = "/frt"
SlashCmdList["FRT"] = function(msg)
    msg = tostring(msg or "")
    local _, _, cmd, rest = string.find(msg, "^(%S*)%s*(.*)$")
    cmd = string.lower(cmd or "")

    if cmd == "set" and rest ~= "" then
        FRT_Saved.note = rest
        FRT_Print("Set note: " .. FRT_Saved.note)

    elseif cmd == "show" then
        FRT_Print("Current note: " .. (FRT_Saved.note or "<nil>"))

    elseif cmd == "share" then
        if GetNumRaidMembers() > 0 then
            FRT_SendAddon("RAID", FRT_Saved.note)
            FRT_Print("Note shared to raid.")
        elseif GetNumPartyMembers() > 0 then
            FRT_SendAddon("PARTY", FRT_Saved.note)
            FRT_Print("Note shared to party.")
        else
            FRT_Print("You are not in a group.")
        end

    elseif cmd == "clear" then
        FRT_Saved.note = ""
        FRT_Print("Note cleared.")

    else
        FRT_Print("Commands:")
        FRT_Print("  /frt set <text>  - set note")
        FRT_Print("  /frt show        - show note")
        FRT_Print("  /frt share       - send note to raid/party")
        FRT_Print("  /frt clear       - clear the note")
    end
end

-- =========================
-- = Minimal UI (Vanilla)  =
-- =========================
FRT_Saved.ui = FRT_Saved.ui or { editor = {}, viewer = { locked = false } }

local function FRT_IsLeaderOrOfficer()
    if (GetNumRaidMembers() or 0) > 0 then
        if IsRaidLeader and IsRaidLeader() then return true end
        if IsRaidOfficer and IsRaidOfficer() then return true end
    end
    return false
end

-- Backdrop (Vanilla-style)
local FRT_Backdrop = {
    bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 32, edgeSize = 32,
    insets = { left = 11, right = 12, top = 12, bottom = 11 }
}

-- Safe SetPoint helper (always passes full arg list)
local function FRT_SafeSetPoint(frame, point, relTo, relPoint, x, y)
    frame:ClearAllPoints()
    frame:SetPoint(point or "CENTER", relTo or UIParent, relPoint or (point or "CENTER"), tonumber(x) or 0, tonumber(y) or 0)
end

-- ===== Viewer (read-only) =====
local FRT_Viewer = CreateFrame("Frame", "FRT_Viewer", UIParent)
FRT_Viewer:SetWidth(320); FRT_Viewer:SetHeight(160)
FRT_Viewer:SetFrameStrata("DIALOG")
FRT_Viewer:SetBackdrop(FRT_Backdrop)
FRT_Viewer:EnableMouse(true)
FRT_Viewer:SetMovable(true)
FRT_Viewer:RegisterForDrag("LeftButton")
FRT_Viewer:SetScript("OnDragStart", function()
    if not FRT_Saved.ui.viewer.locked then
        FRT_Viewer:StartMoving()
    end
end)
-- Viewer drag stop (no 'self' reliance)
FRT_Viewer:SetScript("OnDragStop", function()
    FRT_Viewer:StopMovingOrSizing()
    local x, y = FRT_Viewer:GetLeft(), FRT_Viewer:GetTop()
    if x and y then
        FRT_Saved.ui.viewer.x = x
        FRT_Saved.ui.viewer.y = y
    end
end)
FRT_Viewer:Hide()

-- Title
local vt = FRT_Viewer:CreateFontString(nil, "ARTWORK", "GameFontNormal")
vt:SetPoint("TOP", 0, -10)
vt:SetText("FRT — Raid Note")

-- Note text
local vtext = FRT_Viewer:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
vtext:SetPoint("TOPLEFT", 18, -36)
vtext:SetPoint("RIGHT", -18, 0)
vtext:SetJustifyH("LEFT")
vtext:SetJustifyV("TOP")
vtext:SetText("")
vtext:SetNonSpaceWrap(true)

-- Buttons
local vclose = CreateFrame("Button", nil, FRT_Viewer, "UIPanelButtonTemplate")
vclose:SetWidth(60); vclose:SetHeight(20)
vclose:SetPoint("BOTTOMRIGHT", -15, 15)
vclose:SetText("Close")
vclose:SetScript("OnClick", function() FRT_Viewer:Hide() end)

local vlock = CreateFrame("Button", nil, FRT_Viewer, "UIPanelButtonTemplate")
vlock:SetWidth(80); vlock:SetHeight(20)
vlock:SetPoint("BOTTOMLEFT", 15, 15)
local function RefreshLockButton()
    vlock:SetText(FRT_Saved.ui.viewer.locked and "Unlock" or "Lock")
end
vlock:SetScript("OnClick", function()
    FRT_Saved.ui.viewer.locked = not FRT_Saved.ui.viewer.locked
    RefreshLockButton()
end)
RefreshLockButton()

-- Position restore
local function FRT_ShowViewer()
    FRT_Viewer:Show()
    local sv = FRT_Saved.ui.viewer
    if type(sv.x) == "number" and type(sv.y) == "number" then
        FRT_SafeSetPoint(FRT_Viewer, "TOPLEFT", UIParent, "BOTTOMLEFT", sv.x, sv.y)
    else
        FRT_SafeSetPoint(FRT_Viewer, "CENTER", UIParent, "CENTER", 0, 0)
    end
end

local function FRT_UpdateViewerText()
    vtext:SetText(tostring(FRT_Saved.note or ""))
end

-- ===== Editor (leader/officer) =====
local FRT_Editor = CreateFrame("Frame", "FRT_Editor", UIParent)
FRT_Editor:SetWidth(420); FRT_Editor:SetHeight(260)
FRT_Editor:SetFrameStrata("DIALOG")
FRT_Editor:SetBackdrop(FRT_Backdrop)
FRT_Editor:EnableMouse(true)
FRT_Editor:SetMovable(true)
FRT_Editor:RegisterForDrag("LeftButton")
-- Editor move handlers (no 'self' usage)
FRT_Editor:SetScript("OnDragStart", function()
    FRT_Editor:StartMoving()
end)

-- Editor drag stop (no 'self' reliance)
FRT_Editor:SetScript("OnDragStop", function()
    FRT_Editor:StopMovingOrSizing()
    local x, y = FRT_Editor:GetLeft(), FRT_Editor:GetTop()
    if x and y then
        FRT_Saved.ui.editor.x = x
        FRT_Saved.ui.editor.y = y
    end
end)
FRT_Editor:Hide()

local et = FRT_Editor:CreateFontString(nil, "ARTWORK", "GameFontNormal")
et:SetPoint("TOP", 0, -10)
et:SetText("FRT — Raid Note Editor")

-- Scroll + EditBox
local scroll = CreateFrame("ScrollFrame", "FRT_EditorScroll", FRT_Editor, "UIPanelScrollFrameTemplate")
scroll:SetPoint("TOPLEFT", 18, -36)
scroll:SetPoint("BOTTOMRIGHT", -38, 46)

local edit = CreateFrame("EditBox", "FRT_EditorEditBox", scroll)
edit:SetMultiLine(true)
edit:SetAutoFocus(false)
edit:SetWidth(360)
edit:SetFontObject("ChatFontNormal")
edit:ClearFocus()
scroll:SetScrollChild(edit)

-- Buttons: Save, Share, Close
local esave = CreateFrame("Button", nil, FRT_Editor, "UIPanelButtonTemplate")
esave:SetWidth(80); esave:SetHeight(22)
esave:SetPoint("BOTTOMLEFT", 15, 15)
esave:SetText("Save")
esave:SetScript("OnClick", function()
    FRT_Saved.note = edit:GetText() or ""
    FRT_Print("Saved note.")
    FRT_UpdateViewerText()
end)

local eshare = CreateFrame("Button", nil, FRT_Editor, "UIPanelButtonTemplate")
eshare:SetWidth(80); eshare:SetHeight(22)
eshare:SetPoint("LEFT", esave, "RIGHT", 8, 0)
eshare:SetText("Share")
eshare:SetScript("OnClick", function()
    local text = edit:GetText() or ""
    if text == "" then FRT_Print("Nothing to share."); return end
    if (GetNumRaidMembers() or 0) > 0 then
        if RegisterAddonMessagePrefix then RegisterAddonMessagePrefix(ADDON_PREFIX) end
        if string.len(text) > 240 then
            text = string.sub(text, 1, 240)
            FRT_Print("Note truncated to 240 chars for sending.")
        end
        SendAddonMessage(ADDON_PREFIX, text, "RAID")
        FRT_Print("Shared to RAID.")
    elseif (GetNumPartyMembers() or 0) > 0 then
        if RegisterAddonMessagePrefix then RegisterAddonMessagePrefix(ADDON_PREFIX) end
        if string.len(text) > 240 then
            text = string.sub(text, 1, 240)
            FRT_Print("Note truncated to 240 chars for sending.")
        end
        SendAddonMessage(ADDON_PREFIX, text, "PARTY")
        FRT_Print("Shared to PARTY.")
    else
        FRT_Print("You are not in a group.")
    end
end)

local eclose = CreateFrame("Button", nil, FRT_Editor, "UIPanelButtonTemplate")
eclose:SetWidth(80); eclose:SetHeight(22)
eclose:SetPoint("BOTTOMRIGHT", -15, 15)
eclose:SetText("Close")
eclose:SetScript("OnClick", function() FRT_Editor:Hide() end)

-- Position + populate
local function FRT_ShowEditor()
    if not FRT_IsLeaderOrOfficer() then
        FRT_Print("Editor requires raid lead or assist.")
        return
    end
    edit:SetText(tostring(FRT_Saved.note or ""))
    FRT_Editor:Show()
    local sv = FRT_Saved.ui.editor
    if type(sv.x) == "number" and type(sv.y) == "number" then
        FRT_SafeSetPoint(FRT_Editor, "TOPLEFT", UIParent, "BOTTOMLEFT", sv.x, sv.y)
    else
        FRT_SafeSetPoint(FRT_Editor, "CENTER", UIParent, "CENTER", 0, 0)
    end
end

-- When note changes (set/share/receive), keep viewer up to date
local function FRT_NoteChanged()
    FRT_UpdateViewerText()
end

-- Hook addon message receive to update viewer (chain to your existing frame handler)
local _f_OnEvent = f:GetScript("OnEvent")
f:SetScript("OnEvent", function()
    _f_OnEvent()
    if event == "CHAT_MSG_ADDON" then
        local prefix, message = arg1, arg2
        if prefix == ADDON_PREFIX and message then
            FRT_NoteChanged()
        end
    end
end)

-- ===== Consolidated slash wrapper =====
-- Add viewer/editor commands, and update viewer when base handler changes the note
local _BaseSlash = SlashCmdList["FRT"]
SlashCmdList["FRT"] = function(msg)
    msg = tostring(msg or "")
    local _, _, cmd, rest = string.find(msg, "^(%S*)%s*(.*)$")
    cmd = string.lower(cmd or "")

    -- UI commands
    if cmd == "editor" then
        FRT_ShowEditor()
        return
    elseif cmd == "view" then
        FRT_ShowViewer()
        FRT_UpdateViewerText()
        return
    elseif cmd == "lock" then
        FRT_Saved.ui.viewer.locked = not FRT_Saved.ui.viewer.locked
        RefreshLockButton()
        FRT_Print("Viewer " .. (FRT_Saved.ui.viewer.locked and "locked" or "unlocked") .. ".")
        return
    end

    -- Defer to original handler (set/show/share/clear)
    local before = tostring(FRT_Saved.note or "")
    _BaseSlash(msg)
    local after = tostring(FRT_Saved.note or "")

    if before ~= after then
        FRT_NoteChanged()
    end
end

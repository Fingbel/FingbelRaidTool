-- Fingbel Raid Tool (Vanilla 1.12)
-- SavedVariables: FRT_Saved

-- ===============================
-- SavedVariables boot
-- ===============================
if type(FRT_Saved) ~= "table" then
    FRT_Saved = {}
end
if FRT_Saved.note == nil then
    FRT_Saved.note = ""
end
FRT_Saved.ui = FRT_Saved.ui or { editor = {}, viewer = { autoOpen = true, locked = false } }
if FRT_Saved.ui.viewer.autoOpen == nil then FRT_Saved.ui.viewer.autoOpen = true end
if FRT_Saved.ui.viewer.locked == nil then FRT_Saved.ui.viewer.locked = false end

local ADDON_PREFIX = "FRT"

-- ===============================
-- Utilities
-- ===============================
local function FRT_Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[FRT]|r " .. tostring(msg))
end

-- Trim long addon messages to fit vanilla limits
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

-- Always pass full arg list to SetPoint
local function FRT_SafeSetPoint(frame, point, relTo, relPoint, x, y)
    frame:ClearAllPoints()
    frame:SetPoint(point or "CENTER", relTo or UIParent, relPoint or (point or "CENTER"), tonumber(x) or 0, tonumber(y) or 0)
end

-- ===============================
-- Event frame (load + addon comms)
-- ===============================
local f = CreateFrame("Frame")
f:RegisterEvent("VARIABLES_LOADED")
f:RegisterEvent("CHAT_MSG_ADDON")

-- Forward decls (globals later)
function FRT_ShowViewer() end
function FRT_UpdateViewerText() end

f:SetScript("OnEvent", function()
    if event == "VARIABLES_LOADED" then
        FRT_Print("Addon loaded. Use /frt set <text>, /frt show, /frt share, /frt view, /frt editor")
        if RegisterAddonMessagePrefix then
            RegisterAddonMessagePrefix(ADDON_PREFIX)
        end
    elseif event == "CHAT_MSG_ADDON" then
        local prefix, message, channel, sender = arg1, arg2, arg3, arg4
        if prefix == ADDON_PREFIX and sender ~= UnitName("player") then
            FRT_Saved.note = tostring(message or "")
            FRT_Print("Note from " .. (sender or "unknown") .. ": " .. FRT_Saved.note)
            if FRT_UpdateViewerText then FRT_UpdateViewerText() end
            if FRT_Saved.ui.viewer.autoOpen and FRT_ShowViewer then FRT_ShowViewer() end
        end
    end
end)

-- ===============================
-- Base slash commands (data functions)
-- ===============================
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
            FRT_Print("Note shared to RAID.")
        elseif GetNumPartyMembers() > 0 then
            FRT_SendAddon("PARTY", FRT_Saved.note)
            FRT_Print("Note shared to PARTY.")
        else
            FRT_Print("You are not in a group.")
        end

    elseif cmd == "clear" then
        FRT_Saved.note = ""
        FRT_Print("Note cleared.")

    else
        FRT_Print("Commands:")
        FRT_Print("  /frt set <text>   - set note")
        FRT_Print("  /frt show         - show note in chat")
        FRT_Print("  /frt share        - send note to raid/party")
        FRT_Print("  /frt clear        - clear the note")
        FRT_Print("  /frt view         - open read-only viewer")
        FRT_Print("  /frt editor       - open editor (leader/assist)")
        FRT_Print("  /frt autoopen on|off - auto-open viewer when note arrives")
        FRT_Print("  /frt lock [on|off]  - lock/unlock viewer move/resize")
    end
end

-- ===============================
-- UI: Viewer (read-only)
-- ===============================
local FRT_Viewer = CreateFrame("Frame", "FRT_Viewer", UIParent)
FRT_Viewer:SetWidth(320); FRT_Viewer:SetHeight(160)
FRT_Viewer:SetFrameStrata("DIALOG")
FRT_Viewer:SetBackdrop({
    bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 32, edgeSize = 32,
    insets = { left = 11, right = 12, top = 12, bottom = 11 }
})
FRT_Viewer:EnableMouse(true)
FRT_Viewer:SetMovable(true)
FRT_Viewer:RegisterForDrag("LeftButton")
FRT_Viewer:SetScript("OnDragStart", function()
    if not FRT_Saved.ui.viewer.locked then
        FRT_Viewer:StartMoving()
    end
end)
FRT_Viewer:SetScript("OnDragStop", function()
    FRT_Viewer:StopMovingOrSizing()
    local x, y = FRT_Viewer:GetLeft(), FRT_Viewer:GetTop()
    if x and y then
        FRT_Saved.ui.viewer.x = x
        FRT_Saved.ui.viewer.y = y
    end
end)
FRT_Viewer:SetClampedToScreen(true)

-- Make resizable + handle
if FRT_Viewer.SetResizable then FRT_Viewer:SetResizable(true) end
if FRT_Viewer.SetMinResize then FRT_Viewer:SetMinResize(240, 120) end

FRT_Viewer:SetScript("OnSizeChanged", function()
    local w = FRT_Viewer:GetWidth()
    local h = FRT_Viewer:GetHeight()
    if w and h then
        FRT_Saved.ui.viewer.w = w
        FRT_Saved.ui.viewer.h = h
    end
    if FRT_UpdateViewerText then FRT_UpdateViewerText() end
end)

-- Bottom-right resize handle (drawn outside, diagonal)
local vresize = CreateFrame("Button", nil, FRT_Viewer)
vresize:SetWidth(16); vresize:SetHeight(16)
-- push it OUTSIDE the frame: positive x, negative y from BOTTOMRIGHT
vresize:SetPoint("BOTTOMRIGHT", 10, -10)
vresize:SetFrameLevel(FRT_Viewer:GetFrameLevel() + 10)

-- subtle but visible style
vresize:SetNormalTexture("Interface\\DialogFrame\\UI-DialogBox-Corner")
vresize:GetNormalTexture():SetVertexColor(1, 1, 1, 0.9)
vresize:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
vresize:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")

-- hover reveal
vresize:SetAlpha(0.4)
vresize:SetScript("OnEnter", function() vresize:SetAlpha(1) end)
vresize:SetScript("OnLeave", function() vresize:SetAlpha(0.4) end)

-- sizing (guarded by lock)
vresize:SetScript("OnMouseDown", function()
    if not FRT_Saved.ui.viewer.locked then
        FRT_Viewer:StartSizing("BOTTOMRIGHT")
    end
end)
vresize:SetScript("OnMouseUp", function()
    FRT_Viewer:StopMovingOrSizing()
end)
-- show/hide based on lock
function FRT_UpdateViewerLockUI()
    if FRT_Saved.ui.viewer.locked then
        vresize:Hide()
    else
        vresize:Show()
    end
    -- keep checkbox in sync if present
    if FRT_ViewerLock and FRT_ViewerLock.SetChecked then
        FRT_ViewerLock:SetChecked(FRT_Saved.ui.viewer.locked and 1 or 0)
    end
end

-- call once on init
FRT_UpdateViewerLockUI()

vresize:SetScript("OnMouseDown", function()
    if not FRT_Saved.ui.viewer.locked then
        FRT_Viewer:StartSizing("BOTTOMRIGHT")
    end
end)
vresize:SetScript("OnMouseUp", function()
    FRT_Viewer:StopMovingOrSizing()
end)

FRT_Viewer:Hide()

local vt = FRT_Viewer:CreateFontString(nil, "ARTWORK", "GameFontNormal")
vt:SetPoint("TOP", 0, -10)
vt:SetText("FRT — Raid Note")

local vtext = FRT_Viewer:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
vtext:SetPoint("TOPLEFT", 18, -36)
vtext:SetWidth((FRT_Viewer:GetWidth() or 320) - 36)
vtext:SetJustifyH("LEFT")
vtext:SetJustifyV("TOP")
vtext:SetNonSpaceWrap(true)
vtext:SetText("")

-- Small lock toggle (checkbox) + label
local vlock = CreateFrame("CheckButton", "FRT_ViewerLock", FRT_Viewer, "UICheckButtonTemplate")
vlock:SetWidth(18); vlock:SetHeight(18)
vlock:SetPoint("TOPLEFT", 6, -6)
local vlockText = getglobal(vlock:GetName().."Text"); if vlockText then vlockText:Hide() end
local vlockLabel = FRT_Viewer:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
vlockLabel:SetPoint("LEFT", vlock, "RIGHT", 4, 0)
vlockLabel:SetText("Lock")
vlock:SetFrameLevel(FRT_Viewer:GetFrameLevel() + 5)
vlock:SetChecked(FRT_Saved.ui.viewer.locked and 1 or 0)

function FRT_RefreshLockIcon()
    vlock:SetChecked(FRT_Saved.ui.viewer.locked and 1 or 0)
end

vlock:SetScript("OnClick", function()
    FRT_Saved.ui.viewer.locked = not FRT_Saved.ui.viewer.locked
    FRT_UpdateViewerLockUI()
    FRT_Print("Viewer " .. (FRT_Saved.ui.viewer.locked and "locked" or "unlocked") .. ".")
end)

local vclose = CreateFrame("Button", nil, FRT_Viewer, "UIPanelCloseButton")
vclose:SetPoint("TOPRIGHT", -5, -5)

function FRT_UpdateViewerText()
    local w = (FRT_Viewer:GetWidth() or 320) - 36
    if w < 50 then w = 50 end
    if vtext and vtext.SetWidth then vtext:SetWidth(w) end
    vtext:SetJustifyH("LEFT")
    vtext:SetJustifyV("TOP")
    vtext:SetText(tostring(FRT_Saved.note or ""))
end

function FRT_ShowViewer()
    FRT_Viewer:Show()
    local sv = FRT_Saved.ui.viewer
    if type(sv.w) == "number" and type(sv.h) == "number" then
        FRT_Viewer:SetWidth(sv.w)
        FRT_Viewer:SetHeight(sv.h)
    end
    if type(sv.x) == "number" and type(sv.y) == "number" then
        FRT_SafeSetPoint(FRT_Viewer, "TOPLEFT", UIParent, "BOTTOMLEFT", sv.x, sv.y)
    else
        FRT_SafeSetPoint(FRT_Viewer, "CENTER", UIParent, "CENTER", 0, 0)
    end
    FRT_UpdateViewerLockUI()
    FRT_UpdateViewerText()
end

-- ===============================
-- UI: Editor (leader/officer)
-- ===============================
local function FRT_IsLeaderOrOfficer()
    if (GetNumRaidMembers() or 0) > 0 then
        if IsRaidLeader and IsRaidLeader() then return true end
        if IsRaidOfficer and IsRaidOfficer() then return true end
    end
    return false
end

local FRT_Editor = CreateFrame("Frame", "FRT_Editor", UIParent)
FRT_Editor:SetWidth(420); FRT_Editor:SetHeight(260)
FRT_Editor:SetFrameStrata("DIALOG")
FRT_Editor:SetBackdrop({
    bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 32, edgeSize = 32,
    insets = { left = 11, right = 12, top = 12, bottom = 11 }
})
FRT_Editor:EnableMouse(true)
FRT_Editor:SetMovable(true)
FRT_Editor:RegisterForDrag("LeftButton")
FRT_Editor:SetScript("OnDragStart", function() FRT_Editor:StartMoving() end)
FRT_Editor:SetScript("OnDragStop", function()
    FRT_Editor:StopMovingOrSizing()
    local x, y = FRT_Editor:GetLeft(), FRT_Editor:GetTop()
    if x and y then
        FRT_Saved.ui.editor.x = x
        FRT_Saved.ui.editor.y = y
    end
end)
FRT_Editor:SetClampedToScreen(true)

-- Make resizable + handle
if FRT_Editor.SetResizable then FRT_Editor:SetResizable(true) end
if FRT_Editor.SetMinResize then FRT_Editor:SetMinResize(320, 180) end

local eresize = CreateFrame("Button", nil, FRT_Editor)
eresize:SetWidth(16); eresize:SetHeight(16)
eresize:SetPoint("BOTTOMRIGHT", 10, -10)
eresize:SetFrameLevel(FRT_Editor:GetFrameLevel() + 10)

eresize:SetNormalTexture("Interface\\DialogFrame\\UI-DialogBox-Corner")
eresize:GetNormalTexture():SetVertexColor(1, 1, 1, 1)
eresize:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
eresize:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")

eresize:SetAlpha(0.4)
eresize:SetScript("OnEnter", function() eresize:SetAlpha(1) end)
eresize:SetScript("OnLeave", function() eresize:SetAlpha(0.4) end)

eresize:SetScript("OnMouseDown", function()
    FRT_Editor:StartSizing("BOTTOMRIGHT")
end)
eresize:SetScript("OnMouseUp", function()
    FRT_Editor:StopMovingOrSizing()
end)

FRT_Editor:Hide()

local et = FRT_Editor:CreateFontString(nil, "ARTWORK", "GameFontNormal")
et:SetPoint("TOP", 0, -10)
et:SetText("FRT — Raid Note Editor")

-- Scroll + EditBox
local scroll = CreateFrame("ScrollFrame", "FRT_EditorScroll", FRT_Editor, "UIPanelScrollFrameTemplate")
scroll:SetPoint("TOPLEFT", 18, -36)
scroll:SetPoint("BOTTOMRIGHT", -38, 46)

local editBG = CreateFrame("Frame", nil, FRT_Editor)
editBG:SetPoint("TOPLEFT", 18, -36)
editBG:SetPoint("BOTTOMRIGHT", -38, 46)
editBG:SetBackdrop({
  bgFile   = "Interface\\ChatFrame\\ChatFrameBackground",
  edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
  tile = true, tileSize = 16, edgeSize = 12,
  insets = { left = 3, right = 3, top = 3, bottom = 3 }
})
editBG:SetBackdropColor(0,0,0,0.5)

local edit = CreateFrame("EditBox", "FRT_EditorEditBox", scroll)
edit:SetMultiLine(true)
edit:SetAutoFocus(false)
edit:SetWidth((FRT_Editor:GetWidth() or 420) - 60) -- dynamic wrap width
edit:SetHeight(180)
edit:SetFontObject("ChatFontNormal")
edit:SetTextInsets(4,4,4,4)
edit:EnableMouse(true)
edit:SetScript("OnEscapePressed", function() edit:ClearFocus() end)
edit:SetScript("OnEnterPressed",  function() edit:Insert("\n") end)
edit:SetScript("OnTextChanged", function()
  local text = edit:GetText() or ""
  local lines = 1
  for _ in string.gfind(text, "\n") do lines = lines + 1 end
  local h = lines * 16 + 12
  if h < 180 then h = 180 end
  edit:SetHeight(h)
end)
scroll:SetScrollChild(edit)

scroll:EnableMouseWheel(true)
scroll:SetScript("OnMouseWheel", function()
  local sb = getglobal(scroll:GetName() .. "ScrollBar")
  if not sb then return end
  local step = 20
  local delta = arg1 or 0
  sb:SetValue(sb:GetValue() - delta * step)
end)

-- Keep edit wrapping width in sync with editor size + save size
FRT_Editor:SetScript("OnSizeChanged", function()
    local w = FRT_Editor:GetWidth()
    local h = FRT_Editor:GetHeight()
    if w and h then
        FRT_Saved.ui.editor.w = w
        FRT_Saved.ui.editor.h = h
        edit:SetWidth(w - 60)
    end
end)

-- Buttons
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

local function FRT_ShowEditor()
    if not FRT_IsLeaderOrOfficer() then
        FRT_Print("Editor requires raid lead or assist.")
        return
    end
    edit:SetText(tostring(FRT_Saved.note or ""))
    edit:SetFocus()
    FRT_Editor:Show()

    local sv = FRT_Saved.ui.editor
    -- Apply saved size first (so wrapping width is correct)
    if type(sv.w) == "number" and type(sv.h) == "number" then
        FRT_Editor:SetWidth(sv.w)
        FRT_Editor:SetHeight(sv.h)
        edit:SetWidth(sv.w - 60)
    else
        edit:SetWidth((FRT_Editor:GetWidth() or 420) - 60)
    end

    -- Restore position
    if type(sv.x) == "number" and type(sv.y) == "number" then
        FRT_SafeSetPoint(FRT_Editor, "TOPLEFT", UIParent, "BOTTOMLEFT", sv.x, sv.y)
    else
        FRT_SafeSetPoint(FRT_Editor, "CENTER", UIParent, "CENTER", 0, 0)
    end
end

-- ===============================
-- UI-aware slash wrapper
-- ===============================
local _BaseSlash = SlashCmdList["FRT"]
SlashCmdList["FRT"] = function(msg)
    msg = tostring(msg or "")
    local _, _, cmd, rest = string.find(msg, "^(%S*)%s*(.*)$")
    cmd = string.lower(cmd or "")

    if cmd == "view" then
        FRT_ShowViewer()
        return
    elseif cmd == "editor" then
        FRT_ShowEditor()
        return
    elseif cmd == "autoopen" then
        local arg = string.lower(rest or "")
        if arg == "on" or arg == "1" or arg == "true" then
            FRT_Saved.ui.viewer.autoOpen = true
            FRT_Print("Auto-open ON.")
        elseif arg == "off" or arg == "0" or arg == "false" then
            FRT_Saved.ui.viewer.autoOpen = false
            FRT_Print("Auto-open OFF.")
        else
            FRT_Print("Auto-open is " .. (FRT_Saved.ui.viewer.autoOpen and "ON" or "OFF") .. ". Use /frt autoopen on|off")
        end
        return
    elseif cmd == "lock" then
        local arg = string.lower(rest or "")
        if arg == "on" or arg == "1" or arg == "true" then
            FRT_Saved.ui.viewer.locked = true
        elseif arg == "off" or arg == "0" or arg == "false" then
            FRT_Saved.ui.viewer.locked = false
        else
            FRT_Saved.ui.viewer.locked = not FRT_Saved.ui.viewer.locked
        end
        if type(FRT_RefreshLockIcon) == "function" then FRT_RefreshLockIcon() end
        FRT_UpdateViewerLockUI()
        FRT_Print("Viewer " .. (FRT_Saved.ui.viewer.locked and "locked" or "unlocked") .. ".")
    return
    end

    local before = tostring(FRT_Saved.note or "")
    _BaseSlash(msg)
    local after = tostring(FRT_Saved.note or "")
    if before ~= after then
        FRT_UpdateViewerText()
    end
end

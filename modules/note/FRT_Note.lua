-- Fingbel Raid Tool - Note Module (embedded editor pane)
-- Requires core FingbelRaidTool.lua (defines FRT)
-- Optional: FingbelRaidEditor.lua (global editor host with left-side tabs)

local safePrint = (FRT and FRT.Print) or function(msg)
  DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[FRT]|r " .. tostring(msg))
end
safePrint("FRT_Note.lua loaded")

local Note = {}
Note.name = "Note"

-- ===============================
-- SavedVariables (module scope)
-- ===============================
local function EnsureSaved()
  if type(FRT_Saved) ~= "table" then FRT_Saved = {} end
  if FRT_Saved.note == nil then FRT_Saved.note = "" end
  FRT_Saved.ui = FRT_Saved.ui or { editor = {}, viewer = { autoOpen = true, locked = false } }
  if FRT_Saved.ui.viewer.autoOpen == nil then FRT_Saved.ui.viewer.autoOpen = true end
  if FRT_Saved.ui.viewer.locked   == nil then FRT_Saved.ui.viewer.locked   = false end
end

-- ===============================
-- Helpers (1.12/Turtle WoW APIs)
-- ===============================
local function IsLeaderOrOfficer()
  if (GetNumRaidMembers() or 0) > 0 then
    if IsRaidLeader and IsRaidLeader() then return true end
    if IsRaidOfficer and IsRaidOfficer() then return true end
  end
  return false
end

-- ===============================
-- Viewer UI (read-only; unchanged)
-- ===============================
local viewer, vtext, vresize, vlock

local function UpdateViewerLockUI()
  if FRT_Saved.ui.viewer.locked then
    if vresize then vresize:Hide() end
  else
    if vresize then vresize:Show() end
  end
  if vlock and vlock.SetChecked then
    vlock:SetChecked(FRT_Saved.ui.viewer.locked and 1 or 0)
  end
end

function Note.UpdateViewerText(mod)
  local w = (viewer and viewer:GetWidth() or 320) - 36
  if w < 50 then w = 50 end
  if vtext and vtext.SetWidth then vtext:SetWidth(w) end
  if vtext then
    vtext:SetJustifyH("LEFT")
    vtext:SetJustifyV("TOP")
    vtext:SetText(tostring(FRT_Saved.note or ""))
  end
end

function Note.ShowViewer(mod)
  if not viewer then return end
  viewer:Show()
  local sv = FRT_Saved.ui.viewer
  if type(sv.w) == "number" and type(sv.h) == "number" then
    viewer:SetWidth(sv.w)
    viewer:SetHeight(sv.h)
  end
  if type(sv.x) == "number" and type(sv.y) == "number" then
    FRT.SafeSetPoint(viewer, "TOPLEFT", UIParent, "BOTTOMLEFT", sv.x, sv.y)
  else
    FRT.SafeSetPoint(viewer, "CENTER", UIParent, "CENTER", 0, 0)
  end
  UpdateViewerLockUI()
  Note.UpdateViewerText(Note)
end

local function BuildViewer()
  viewer = CreateFrame("Frame", "FRT_Viewer", UIParent)
  viewer:SetWidth(320); viewer:SetHeight(160)
  viewer:SetFrameStrata("DIALOG")
  viewer:SetBackdrop({
    bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 32, edgeSize = 32,
    insets = { left = 11, right = 12, top = 12, bottom = 11 }
  })
  viewer:EnableMouse(true)
  viewer:SetMovable(true)
  viewer:RegisterForDrag("LeftButton")
  viewer:SetScript("OnDragStart", function()
    if not FRT_Saved.ui.viewer.locked then viewer:StartMoving() end
  end)
  viewer:SetScript("OnDragStop", function()
    viewer:StopMovingOrSizing()
    local x, y = viewer:GetLeft(), viewer:GetTop()
    if x and y then FRT_Saved.ui.viewer.x = x; FRT_Saved.ui.viewer.y = y end
  end)
  viewer:SetClampedToScreen(true)

  if viewer.SetResizable then viewer:SetResizable(true) end
  if viewer.SetMinResize then viewer:SetMinResize(240, 120) end

  viewer:SetScript("OnSizeChanged", function()
    local w = viewer:GetWidth(); local h = viewer:GetHeight()
    if w and h then FRT_Saved.ui.viewer.w = w; FRT_Saved.ui.viewer.h = h end
    Note.UpdateViewerText(Note)
  end)

  vresize = CreateFrame("Button", nil, viewer)
  vresize:SetWidth(16); vresize:SetHeight(16)
  vresize:SetPoint("BOTTOMRIGHT", 10, -10)
  vresize:SetFrameLevel(viewer:GetFrameLevel() + 10)
  vresize:SetNormalTexture("Interface\\DialogFrame\\UI-DialogBox-Corner")
  vresize:GetNormalTexture():SetVertexColor(1,1,1,0.9)
  vresize:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
  vresize:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
  vresize:SetAlpha(0.4)
  vresize:SetScript("OnEnter", function() vresize:SetAlpha(1) end)
  vresize:SetScript("OnLeave", function() vresize:SetAlpha(0.4) end)
  vresize:SetScript("OnMouseDown", function()
    if not FRT_Saved.ui.viewer.locked then viewer:StartSizing("BOTTOMRIGHT") end
  end)
  vresize:SetScript("OnMouseUp", function() viewer:StopMovingOrSizing() end)

  viewer:Hide()

  local vt = viewer:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  vt:SetPoint("TOP", 0, -10)
  vt:SetText("FRT — Raid Note")

  vtext = viewer:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
  vtext:SetPoint("TOPLEFT", 18, -36)
  vtext:SetWidth((viewer:GetWidth() or 320) - 36)
  vtext:SetJustifyH("LEFT")
  vtext:SetJustifyV("TOP")
  vtext:SetNonSpaceWrap(true)
  vtext:SetText("")

  -- lock toggle
  vlock = CreateFrame("CheckButton", "FRT_ViewerLock", viewer, "UICheckButtonTemplate")
  vlock:SetWidth(18); vlock:SetHeight(18)
  vlock:SetPoint("TOPLEFT", 6, -6)
  local vlockText = getglobal(vlock:GetName().."Text"); if vlockText then vlockText:Hide() end
  local vlockLabel = viewer:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
  vlockLabel:SetPoint("LEFT", vlock, "RIGHT", 4, 0)
  vlockLabel:SetText("Lock")
  vlock:SetFrameLevel(viewer:GetFrameLevel() + 5)
  vlock:SetChecked(FRT_Saved.ui.viewer.locked and 1 or 0)
  vlock:SetScript("OnClick", function()
    FRT_Saved.ui.viewer.locked = not FRT_Saved.ui.viewer.locked
    UpdateViewerLockUI()
    FRT.Print("Viewer " .. (FRT_Saved.ui.viewer.locked and "locked" or "unlocked") .. ".")
  end)

  local vclose = CreateFrame("Button", nil, viewer, "UIPanelCloseButton")
  vclose:SetPoint("TOPRIGHT", -5, -5)

  UpdateViewerLockUI()
end

-- =====================================================
-- Embedded Editor Pane (inside global Fingbel Raid Editor)
-- =====================================================
-- Note: No standalone top-level editor frame anymore.
--       We register a builder that fills a pane inside the global editor.

local function BuildNoteEditorPane(parent)
  -- Title
  local title = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  title:SetPoint("TOPLEFT", 0, 0)
  title:SetText("Raid Note — Editor")

  -- Scroll area + background
  local scroll = CreateFrame("ScrollFrame", "FRT_NoteEditorScroll", parent, "UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", 0, -24)
  scroll:SetPoint("BOTTOMRIGHT", -120, 36)

  local editBG = CreateFrame("Frame", nil, parent)
  editBG:SetPoint("TOPLEFT", 0, -24)
  editBG:SetPoint("BOTTOMRIGHT", -120, 36)
  editBG:SetBackdrop({
    bgFile   = "Interface\\ChatFrame\\ChatFrameBackground",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 12,
    insets = { left = 3, right = 3, top = 3, bottom = 3 }
  })
  editBG:SetBackdropColor(0,0,0,0.5)

  local edit = CreateFrame("EditBox", "FRT_NoteEditorEditBox", scroll)
  edit:SetMultiLine(true)
  edit:SetAutoFocus(false)
  edit:SetWidth(parent:GetWidth() - 140)
  edit:SetHeight(200)
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
    if h < 200 then h = 200 end
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

  -- Resize behavior inside host pane
  parent:SetScript("OnSizeChanged", function()
    edit:SetWidth(parent:GetWidth() - 140)
  end)
  parent:SetScript("OnShow", function()
    edit:SetWidth(parent:GetWidth() - 140)
    edit:SetText(tostring(FRT_Saved.note or ""))
  end)

  -- Buttons (right column)
  local save = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
  save:SetWidth(96); save:SetHeight(22)
  save:SetPoint("TOPRIGHT", 0, -24)
  save:SetText("Save")
  save:SetScript("OnClick", function()
    if not IsLeaderOrOfficer() then
      FRT.Print("Editor requires raid lead or assist.")
      return
    end
    FRT_Saved.note = edit:GetText() or ""
    FRT.Print("Saved note.")
    Note.UpdateViewerText(Note)
  end)

  local share = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
  share:SetWidth(96); share:SetHeight(22)
  share:SetPoint("TOPRIGHT", 0, -50)
  share:SetText("Share")
  share:SetScript("OnClick", function()
    local text = edit:GetText() or ""
    if text == "" then FRT.Print("Nothing to share."); return end
    if (GetNumRaidMembers() or 0) > 0 then
      FRT.SendAddon("RAID", text)
      FRT.Print("Shared to RAID.")
    elseif (GetNumPartyMembers() or 0) > 0 then
      FRT.SendAddon("PARTY", text)
      FRT.Print("Shared to PARTY.")
    else
      FRT.Print("You are not in a group.")
    end
  end)

  local openViewer = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
  openViewer:SetWidth(96); openViewer:SetHeight(22)
  openViewer:SetPoint("TOPRIGHT", 0, -76)
  openViewer:SetText("Open Viewer")
  openViewer:SetScript("OnClick", function()
    Note.ShowViewer(Note)
  end)
end

-- Exposed helper so /frt editor routes to the global host
function Note.ShowEditor(mod)
  if not IsLeaderOrOfficer() then FRT.Print("Editor requires raid lead or assist."); return end
  if FRT and FRT.Editor and FRT.Editor.Show then
    FRT.Editor.Show("Note")
  else
    FRT.Print("Global editor not available.")
  end
end

-- ===============================
-- Module events (comms)
-- ===============================
local ev = CreateFrame("Frame")

function Note.OnLoad(mod)
  EnsureSaved()
  FRT.RegisterAddonPrefix()
  BuildViewer()

  -- Register our editor pane with the global editor host (if present)
  if FRT and FRT.Editor and FRT.Editor.RegisterPanel then
    FRT.Editor.RegisterPanel("Note", BuildNoteEditorPane, { title = "📝 Raid Note", order = 10 })
  end

  -- Listen for incoming addon notes
  ev:RegisterEvent("CHAT_MSG_ADDON")
  ev:SetScript("OnEvent", function()
    if event == "CHAT_MSG_ADDON" then
      local prefix, message, channel, sender = arg1, arg2, arg3, arg4
      if prefix == FRT.ADDON_PREFIX and sender ~= UnitName("player") then
        FRT_Saved.note = tostring(message or "")
        FRT.Print("Note from " .. (sender or "unknown") .. ": " .. FRT_Saved.note)
        Note.UpdateViewerText(Note)
        if FRT_Saved.ui.viewer.autoOpen then Note.ShowViewer(Note) end
      end
    end
  end)
end

-- ===============================
-- Slash subcommands
-- ===============================
function Note.GetHelp(mod)
  return {
    "/frt set <text>        - set note",
    "/frt show              - show note in chat",
    "/frt share             - send note to raid/party",
    "/frt clear             - clear the note",
    "/frt view              - open read-only viewer",
    "/frt editor            - open global editor on Note (lead/assist)",
    "/frt autoopen on|off   - toggle auto-open viewer",
    "/frt lock [on|off]     - lock/unlock viewer move/resize",
  }
end

function Note.OnSlash(mod, cmd, rest)
  if cmd == "set" and rest ~= "" then
    FRT_Saved.note = rest
    FRT.Print("Set note: " .. FRT_Saved.note)
    Note.UpdateViewerText(Note)
    return true

  elseif cmd == "show" then
    FRT.Print("Current note: " .. (FRT_Saved.note or "<nil>"))
    return true

  elseif cmd == "share" then
    if GetNumRaidMembers() > 0 then
      FRT.SendAddon("RAID", FRT_Saved.note)
      FRT.Print("Note shared to RAID.")
    elseif GetNumPartyMembers() > 0 then
      FRT.SendAddon("PARTY", FRT_Saved.note)
      FRT.Print("Note shared to PARTY.")
    else
      FRT.Print("You are not in a group.")
    end
    return true

  elseif cmd == "clear" then
    FRT_Saved.note = ""
    FRT.Print("Note cleared.")
    Note.UpdateViewerText(Note)
    return true

  elseif cmd == "view" then
    Note.ShowViewer(Note)
    return true

  elseif cmd == "editor" then
    Note.ShowEditor(Note)
    return true

  elseif cmd == "autoopen" then
    local a = string.lower(rest or "")
    if a == "on" or a == "1" or a == "true" then
      FRT_Saved.ui.viewer.autoOpen = true
      FRT.Print("Auto-open ON.")
    elseif a == "off" or a == "0" or a == "false" then
      FRT_Saved.ui.viewer.autoOpen = false
      FRT.Print("Auto-open OFF.")
    else
      FRT.Print("Auto-open is " .. (FRT_Saved.ui.viewer.autoOpen and "ON" or "OFF") .. ". Use /frt autoopen on|off")
    end
    return true

  elseif cmd == "lock" then
    local a = string.lower(rest or "")
    if a == "on" or a == "1" or a == "true" then
      FRT_Saved.ui.viewer.locked = true
    elseif a == "off" or a == "0" or a == "false" then
      FRT_Saved.ui.viewer.locked = false
    else
      FRT_Saved.ui.viewer.locked = not FRT_Saved.ui.viewer.locked
    end
    UpdateViewerLockUI()
    FRT.Print("Viewer " .. (FRT_Saved.ui.viewer.locked and "locked" or "unlocked") .. ".")
    return true
  end

  return false -- not handled
end

-- Register module with core (immediately on file load)
if FRT and FRT.RegisterModule then
  FRT.RegisterModule(Note.name, Note)
else
  -- Extreme fallback: if core isn't loaded yet, create a tiny loader
  local wait = CreateFrame("Frame")
  wait:SetScript("OnUpdate", function()
    if FRT and FRT.RegisterModule then
      wait:SetScript("OnUpdate", nil)
      FRT.RegisterModule(Note.name, Note)
      safePrint("FRTNote registered late")
    end
  end)
end

-- Fingbel Raid Tool - Note Viewer
-- FRT_NoteViewer.lua --

FRT = FRT or {}
FRT.Note = FRT.Note or {}
local Note = FRT.Note

--Hooking auto reparse on spec change
if FRT and FRT.Role then
  FRT.Role.OnChanged = function()
    if FRT.Note and FRT.Note.UpdateViewerText then
      FRT.Note.UpdateViewerText()
    end
  end
end

local viewer, vresize, vlock , vtitle
local _pendingTitle = "FRT — Raid Note"
local _pendingBoss = nil
local ed 

local function composeHeader(title, boss)
  title = tostring(title or "")
  boss  = tostring(boss or "")
  if title ~= "" and boss ~= "" then return boss .. " — " .. title end
  if title ~= "" then return title end
  if boss  ~= "" then return boss end
  return "FRT — Raid Note"
end

function Note.UpdateViewerLockUI()
  if FRT_Saved.ui.viewer.locked then
    if vresize then vresize:Hide() end
  else
    if vresize then vresize:Show() end
  end
  if vlock and vlock.SetChecked then
    vlock:SetChecked(FRT_Saved.ui.viewer.locked and 1 or 0)
  end
end

function Note.UpdateViewerText()
  if not ed then return end
  local text = (FRT_Saved and FRT_Saved.note) or ""
  local Parser = (FRT.Note and FRT.Note.Parser) or FRT.Parser
  if Parser and Parser.Parse and ed.SetTokens then
    ed.SetTokens(Parser.Parse(text))
  elseif ed.SetText then
    ed.SetText(text)
  end
  if ed.Refresh then ed.Refresh() end
end

function Note.ShowViewer()
  if not viewer then return end
  viewer:Show()

  local sv = FRT_Saved.ui.viewer
  if type(sv.w) == "number" and type(sv.h) == "number" then
    viewer:SetWidth(sv.w); viewer:SetHeight(sv.h)
  end
  if type(sv.x) == "number" and type(sv.y) == "number" then
    FRT.SafeSetPoint(viewer, "TOPLEFT", UIParent, "BOTTOMLEFT", sv.x, sv.y)
  else
    FRT.SafeSetPoint(viewer, "CENTER", UIParent, "CENTER", 0, 0)
  end
   if vtitle then vtitle:SetText(composeHeader(_pendingTitle, _pendingBoss)) end
  Note.UpdateViewerLockUI()
  Note.UpdateViewerText()
end

function Note.BuildViewer()
  viewer = CreateFrame("Frame", "FRT_Viewer", UIParent)
  viewer:SetWidth(320); viewer:SetHeight(160)
  viewer:SetFrameStrata("DIALOG")
  viewer:SetBackdrop({
    bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 12,
    insets = { left = 4, right = 4, top = 4, bottom = 4 }
  })
  viewer:SetBackdropColor(0, 0, 0, 0.85)
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

  -- === Top bar ===
  local BORDER   = 4
  local TOPBAR_H = 20

  local topbar = CreateFrame("Frame", nil, viewer)
  topbar:SetPoint("TOPLEFT",  BORDER, -BORDER)
  topbar:SetPoint("TOPRIGHT", -BORDER, -BORDER)
  topbar:SetHeight(TOPBAR_H)
  topbar:EnableMouse(true)
  topbar:RegisterForDrag("LeftButton")
  topbar:SetScript("OnDragStart", function()
    if not FRT_Saved.ui.viewer.locked then viewer:StartMoving() end
  end)
  topbar:SetScript("OnDragStop", function()
    viewer:StopMovingOrSizing()
    local x, y = viewer:GetLeft(), viewer:GetTop()
    if x and y then FRT_Saved.ui.viewer.x = x; FRT_Saved.ui.viewer.y = y end
  end)

  -- Lock (left)
  vlock = CreateFrame("CheckButton", "FRT_ViewerLock", topbar, "UICheckButtonTemplate")
  vlock:SetWidth(18); vlock:SetHeight(18)
  vlock:SetPoint("LEFT", 2, 0)
  local vlockText = getglobal(vlock:GetName().."Text"); if vlockText then vlockText:Hide() end
  local vlockLabel = topbar:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
  vlockLabel:SetPoint("LEFT", vlock, "RIGHT", 4, 0)
  vlockLabel:SetText("Lock")
  vlock:SetFrameLevel(viewer:GetFrameLevel() + 10)
  vlock:SetChecked(FRT_Saved.ui.viewer.locked and 1 or 0)
  vlock:SetScript("OnClick", function()
    FRT_Saved.ui.viewer.locked = not FRT_Saved.ui.viewer.locked
    Note.UpdateViewerLockUI()
    FRT.Print("Viewer " .. (FRT_Saved.ui.viewer.locked and "locked" or "unlocked") .. ".")
  end)

  -- Title (center)
  vtitle = topbar:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  vtitle:SetPoint("CENTER", 0, 0)
  vtitle:SetText(composeHeader(_pendingTitle, _pendingBoss))

  -- Close (parented to VIEWER so it closes the whole window)
  local vclose = CreateFrame("Button", "FRT_ViewerClose", viewer, "UIPanelCloseButton")
  vclose:ClearAllPoints()
  vclose:SetPoint("TOPRIGHT", viewer, "TOPRIGHT", 0, -BORDER + 1)
  vclose:SetFrameLevel(viewer:GetFrameLevel() + 10)   
  vclose:SetScript("OnClick", function() viewer:Hide() end)

  -- === Content area (under topbar, inside the frame) ===
  local area = CreateFrame("Frame", nil, viewer)
  area:SetPoint("TOPLEFT",     viewer, "TOPLEFT",  BORDER + 2, -(BORDER + TOPBAR_H + 2))
  area:SetPoint("BOTTOMLEFT",  viewer, "BOTTOMLEFT", BORDER + 2, BORDER + 2)
  area:SetPoint("RIGHT",       vclose, "RIGHT", 0, 0)  -- scrollbar lines up under the close button

  -- Token-based scrollable renderer (scrollbar lives INSIDE 'area')
  ed = FRT.Utils.CreateRichTextViewer(area, {
    name             = "FRT_ViewerScroll",
    rightColumnWidth = 16,
    insets           = { left=0, right=0, top=0, bottom=0 },
    fontObject       = "GameFontHighlight",
  })

  -- === Scrollbar nudge ===
  do
    local NUDGE_X = -8  -- negative = move left
    local NUDGE_Y = -6  -- negative = move down (for TOP anchors)

    local sfName = ed.scroll:GetName() or ""
    local sb   = getglobal(sfName.."ScrollBar")
    local up   = getglobal(sfName.."ScrollBarScrollUpButton")   or getglobal(sfName.."ScrollUpButton")
    local down = getglobal(sfName.."ScrollBarScrollDownButton") or getglobal(sfName.."ScrollDownButton")

    if up then
      up:ClearAllPoints()
      up:SetPoint("TOPRIGHT", area, "TOPRIGHT", NUDGE_X, NUDGE_Y)
    end
    if down then
      down:ClearAllPoints()
      down:SetPoint("BOTTOMRIGHT", area, "BOTTOMRIGHT", NUDGE_X, 0)
    end
    if sb then
      sb:ClearAllPoints()
      if up then sb:SetPoint("TOPRIGHT", up, "BOTTOMRIGHT", 0, -1)
      else       sb:SetPoint("TOPRIGHT", area, "TOPRIGHT", NUDGE_X, NUDGE_Y - 18) end
      if down then sb:SetPoint("BOTTOMRIGHT", down, "TOPRIGHT", 0, 1)
      else         sb:SetPoint("BOTTOMRIGHT", area, "BOTTOMRIGHT", NUDGE_X, 18) end
    end
  end

  -- Resize handle
  vresize = CreateFrame("Button", nil, viewer)
  vresize:SetWidth(16); vresize:SetHeight(16)
  vresize:SetPoint("BOTTOMRIGHT", 10, -10)
  vresize:SetFrameLevel(viewer:GetFrameLevel() + 10)
  vresize:SetNormalTexture("Interface\\DialogFrame\\UI-DialogBox-Corner")
  vresize:GetNormalTexture():SetVertexColor(1,1,1,1)
  vresize:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
  vresize:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
  vresize:SetAlpha(0.4)
  vresize:SetScript("OnEnter", function() vresize:SetAlpha(1) end)
  vresize:SetScript("OnLeave", function() vresize:SetAlpha(0.4) end)
  vresize:SetScript("OnMouseDown", function()
    if not FRT_Saved.ui.viewer.locked then viewer:StartSizing("BOTTOMRIGHT") end
  end)
  vresize:SetScript("OnMouseUp", function() viewer:StopMovingOrSizing() end)

  -- Persist size + reflow
  viewer:SetScript("OnSizeChanged", function()
    local w, h = viewer:GetWidth(), viewer:GetHeight()
    if w and h then FRT_Saved.ui.viewer.w, FRT_Saved.ui.viewer.h = w, h end
    if ed and ed.Refresh then ed.Refresh() end
  end)

  viewer:Hide()
  Note.UpdateViewerLockUI()
end

-- ===== Live preview helpers  =====
function Note.EnsureViewer()
  if not viewer then Note.BuildViewer() end
  return viewer
end

function Note.SetViewerRaw(raw)
  if not ed then return end
  local Parser = (FRT.Note and FRT.Note.Parser) or FRT.Parser
  local s = tostring(raw or "")
  if Parser and Parser.Parse then
    ed.SetTokens(Parser.Parse(s))
  elseif Parser and Parser.ParseNote then
    ed.SetTokens(Parser.ParseNote(s))
  else
    ed.SetTokens({ { kind="text", value=s, font="GameFontHighlight" } })
  end
  if ed.Refresh then ed.Refresh() end
end

function Note.SetViewerTokens(tokens)
  if not ed then return end
  ed.SetTokens(tokens or {})
  if ed.Refresh then ed.Refresh() end
end

function Note.SetViewerTitle(title, boss)
  _pendingTitle = tostring(title or "")
  _pendingBoss  = (boss ~= nil and tostring(boss)) or _pendingBoss
  if _pendingTitle == "" and (not _pendingBoss or _pendingBoss == "") then
    _pendingTitle = "FRT — Raid Note"
  end
  if vtitle and vtitle.SetText then
    vtitle:SetText(composeHeader(_pendingTitle, _pendingBoss))
  end
end
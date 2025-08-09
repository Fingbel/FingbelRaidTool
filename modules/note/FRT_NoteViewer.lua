-- FRT_NoteViewer.lua
FRT = FRT or {}
FRT.Note = FRT.Note or {}
local Note = FRT.Note

local viewer, vresize, vlock
local ed -- util return (has .SetTokens/.SetText/.Refresh, etc.)

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

  local Parser = FRT.Note and FRT.Note.Parser
  if Parser and Parser.Parse and ed.SetTokens then
    local tokens = Parser.Parse(text)
    ed.SetTokens(tokens)
  elseif ed.SetText then
    ed.SetText(text)  -- safe fallback
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

  Note.UpdateViewerLockUI()
  Note.UpdateViewerText()
end

function Note.BuildViewer()
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

  -- Title
  local vt = viewer:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  vt:SetPoint("TOP", 0, -10)
  vt:SetText("FRT — Raid Note")

  -- Content area
  local area = CreateFrame("Frame", nil, viewer)
  area:SetPoint("TOPLEFT", 18, -36)
  area:SetPoint("BOTTOMRIGHT", -18, 18)

  -- Token-based scrollable renderer (dumb util)
  ed = FRT.Utils.CreateScrollable(area, {
    name             = "FRT_ViewerScroll",
    rightColumnWidth = 18,
    insets           = { left=0, right=0, top=0, bottom=0 },
    fontObject       = "GameFontHighlight",
  })

  -- Lock toggle
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
    Note.UpdateViewerLockUI()
    FRT.Print("Viewer " .. (FRT_Saved.ui.viewer.locked and "locked" or "unlocked") .. ".")
  end)

  -- Resize handle
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

  -- Close button
  local vclose = CreateFrame("Button", nil, viewer, "UIPanelCloseButton")
  vclose:SetPoint("TOPRIGHT", -5, -5)

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

-- Push raw text to the viewer WITHOUT touching FRT_Saved.note
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

-- If you already have tokens and just want to render them
function Note.SetViewerTokens(tokens)
  if not ed then return end
  ed.SetTokens(tokens or {})
  if ed.Refresh then ed.Refresh() end
end

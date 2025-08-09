FRT = FRT or {}
FRT.Note = FRT.Note or {}
local Note = FRT.Note

local viewer, vtext, vresize, vlock

-- ===============================
-- Helpers 
-- ===============================
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
  Note.UpdateViewerLockUI()
  Note.UpdateViewerText(Note)
end

-- ===============================
-- Main viewer builder
-- ===============================
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
    Note.UpdateViewerLockUI()
    FRT.Print("Viewer " .. (FRT_Saved.ui.viewer.locked and "locked" or "unlocked") .. ".")
  end)

  local vclose = CreateFrame("Button", nil, viewer, "UIPanelCloseButton")
  vclose:SetPoint("TOPRIGHT", -5, -5)

  Note.UpdateViewerLockUI()
end
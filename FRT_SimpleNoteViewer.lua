-- FRT_SimpleNoteViewer.lua (Vanilla 1.12) — tiny text viewer + lock + resize
FRT = FRT or {}
FRT.SimpleNoteViewer = FRT.SimpleNoteViewer or {}

-- Minimal SV defaults (safe even if core didn't init yet)
if type(FRT_Saved) ~= "table" then FRT_Saved = {} end
FRT_Saved.ui = FRT_Saved.ui or {}
FRT_Saved.ui.viewer = FRT_Saved.ui.viewer or { x=nil,y=nil,w=520,h=360, locked=false }

do
  local UI -- { frame, title, scroll, content, fs, lock, resize }

  local function ApplySavedPosSize()
    local sv = FRT_Saved.ui.viewer
    if type(sv.w) == "number" and type(sv.h) == "number" then
      UI.frame:SetWidth(sv.w); UI.frame:SetHeight(sv.h)
    end
    if type(sv.x) == "number" and type(sv.y) == "number" then
      if FRT.SafeSetPoint then
        FRT.SafeSetPoint(UI.frame, "TOPLEFT", UIParent, "BOTTOMLEFT", sv.x, sv.y)
      else
        UI.frame:ClearAllPoints()
        UI.frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", sv.x, sv.y)
      end
    else
      UI.frame:ClearAllPoints()
      UI.frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end
  end

  local function UpdateLockUI()
    local locked = FRT_Saved.ui.viewer.locked
    if UI.resize then (locked and UI.resize.Hide or UI.resize.Show)(UI.resize) end
    if UI.lock and UI.lock.SetChecked then UI.lock:SetChecked(locked and 1 or 0) end
  end

  local function Reflow()
    local maxW = (UI.scroll:GetWidth() or 480) - 16
    if maxW < 100 then maxW = 100 end
    UI.fs:SetWidth(maxW)
    -- Height after width forces wrapping in 1.12
    local textH = UI.fs:GetHeight() or 0
    local minH  = UI.scroll:GetHeight() or 200
    UI.content:SetWidth(maxW)
    UI.content:SetHeight(math.max(textH, minH))
  end

  local function Build()
    if UI then return end

    local f = CreateFrame("Frame", "FRT_SimpleNoteViewer", UIParent)
    f:SetWidth(520); f:SetHeight(360)
    f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    f:SetFrameStrata("DIALOG")
    f:SetBackdrop({
      bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background",
      edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
      tile = true, tileSize = 32, edgeSize = 32,
      insets   = { left = 11, right = 12, top = 12, bottom = 11 },
    })
    f:EnableMouse(true)
    f:SetMovable(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function()
      if not FRT_Saved.ui.viewer.locked then f:StartMoving() end
    end)
    f:SetScript("OnDragStop", function()
      f:StopMovingOrSizing()
      local x, y = f:GetLeft(), f:GetTop()
      if x and y then FRT_Saved.ui.viewer.x, FRT_Saved.ui.viewer.y = x, y end
    end)
    f:SetClampedToScreen(true)
    if f.SetResizable then f:SetResizable(true) end
    if f.SetMinResize then f:SetMinResize(240, 120) end

    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -5, -5)

    local title = f:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOP", f, "TOP", 0, -10)
    title:SetText("FRT — Simple Note")

    -- Lock toggle
    local lock = CreateFrame("CheckButton", "FRT_SimpleViewerLock", f, "UICheckButtonTemplate")
    lock:SetWidth(18); lock:SetHeight(18)
    lock:SetPoint("TOPLEFT", f, "TOPLEFT", 6, -6)
    local lockText = getglobal(lock:GetName().."Text"); if lockText then lockText:Hide() end
    local lockLabel = f:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    lockLabel:SetPoint("LEFT", lock, "RIGHT", 4, 0); lockLabel:SetText("Lock")
    lock:SetFrameLevel(f:GetFrameLevel() + 5)
    lock:SetScript("OnClick", function()
      FRT_Saved.ui.viewer.locked = not FRT_Saved.ui.viewer.locked
      UpdateLockUI()
      if FRT.Print then FRT.Print("Viewer " .. (FRT_Saved.ui.viewer.locked and "locked" or "unlocked") .. ".") end
    end)

    -- Scroll area
    local scroll = CreateFrame("ScrollFrame", "FRT_SimpleNoteViewerScroll", f, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -40)
    scroll:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -14, 14)

    local content = CreateFrame("Frame", "FRT_SimpleNoteViewerContent", scroll)
    content:SetWidth(1); content:SetHeight(1)
    scroll:SetScrollChild(content)

    local fs = content:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    fs:SetPoint("TOPLEFT", content, "TOPLEFT", 0, 0)
    fs:SetJustifyH("LEFT"); fs:SetJustifyV("TOP")

    -- Resize handle (bottom-right corner)
    local resize = CreateFrame("Button", nil, f)
    resize:SetWidth(16); resize:SetHeight(16)
    resize:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 10, -10)
    resize:SetFrameLevel(f:GetFrameLevel() + 10)
    resize:SetNormalTexture("Interface\\DialogFrame\\UI-DialogBox-Corner")
    resize:GetNormalTexture():SetVertexColor(1,1,1,0.9)
    resize:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    resize:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    resize:SetAlpha(0.4)
    resize:SetScript("OnEnter", function() resize:SetAlpha(1) end)
    resize:SetScript("OnLeave", function() resize:SetAlpha(0.4) end)
    resize:SetScript("OnMouseDown", function()
      if not FRT_Saved.ui.viewer.locked then f:StartSizing("BOTTOMRIGHT") end
    end)
    resize:SetScript("OnMouseUp", function() f:StopMovingOrSizing() end)

    -- Persist size + reflow
    f:SetScript("OnSizeChanged", function()
      local w, h = f:GetWidth(), f:GetHeight()
      if w and h then FRT_Saved.ui.viewer.w, FRT_Saved.ui.viewer.h = w, h end
      Reflow()
    end)

    UI = { frame=f, title=title, scroll=scroll, content=content, fs=fs, lock=lock, resize=resize }
  end

  local function Layout(text, title)
    Build()
    UI.frame:Show()
    if title and title ~= "" then UI.title:SetText(title) end
    ApplySavedPosSize()
    UpdateLockUI()

    -- text + reflow
    local maxW = (UI.scroll:GetWidth() or 480) - 16
    if maxW < 100 then maxW = 100 end
    UI.fs:SetWidth(maxW)
    UI.fs:SetText(text or "")
    Reflow()
  end

  function FRT.SimpleNoteViewer.Show(text, title)
    Layout(text, title)
  end
  function FRT.SimpleNoteViewer.Hide()
    if UI and UI.frame then UI.frame:Hide() end
  end
  function FRT.SimpleNoteViewer.Toggle(text, title)
    Build()
    if UI.frame:IsShown() then UI.frame:Hide() else Layout(text, title) end
  end
end

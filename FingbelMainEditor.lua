-- Fingbel Raid Tool — Main Editor Host 
FRT = FRT or {}
FRT.Editor = FRT.Editor or {}

local E = FRT.Editor
E._panels  = E._panels  or {}
E._frames  = E._frames  or {}
E._buttons = E._buttons or {}
E._current = E._current or nil

function E.RegisterPanel(name, builder, opts)
  if not name or not builder then return end
  E._panels[name] = {
    builder = builder,
    title   = (opts and opts.title) or name,
    order   = (opts and opts.order) or 1000,
  }
  if E.frame and E.left then
    E:_RebuildButtons()
  end
end

local function GetMainEditorSV()
  if type(FRT_Saved) ~= "table" then FRT_Saved = {} end
  FRT_Saved.ui = FRT_Saved.ui or {}
  -- bigger defaults
  FRT_Saved.ui.mainEditor = FRT_Saved.ui.mainEditor or { x=nil, y=nil, w=800, h=500, selected=nil }
  return FRT_Saved.ui.mainEditor
end

local function SafePoint(frame, point, relTo, relPoint, x, y)
  if FRT and FRT.SafeSetPoint then
    FRT.SafeSetPoint(frame, point, relTo, relPoint, x, y)
  else
    frame:ClearAllPoints()
    frame:SetPoint(point or "CENTER", relTo or UIParent, relPoint or (point or "CENTER"), tonumber(x) or 0, tonumber(y) or 0)
  end
end

function E:_CreateWindowOnce()
  if self.frame then return end

  local sv = GetMainEditorSV()

  local f = CreateFrame("Frame", "FRT_MainEditor", UIParent)
  f:SetFrameStrata("DIALOG")
  f:SetWidth(sv.w or 800); f:SetHeight(sv.h or 500)
  f:SetBackdrop({
    bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 32, edgeSize = 32,
    insets   = { left = 11, right = 12, top = 12, bottom = 11 }
  })
  f:EnableMouse(true)
  f:SetMovable(true)

  -- title/drag
  local drag = CreateFrame("Frame", nil, f)
  drag:SetPoint("TOPLEFT", 12, 0)
  drag:SetPoint("TOPRIGHT", -32, -8)
  drag:SetHeight(18)
  drag:EnableMouse(true)
  drag:RegisterForDrag("LeftButton")
  drag:SetScript("OnDragStart", function() f:StartMoving() end)
  drag:SetScript("OnDragStop", function()
    f:StopMovingOrSizing()
    local x, y = f:GetLeft(), f:GetTop()
    if x and y then sv.x, sv.y = x, y end
  end)

  f:SetClampedToScreen(true)
  if f.SetResizable then f:SetResizable(true) end
  if f.SetMinResize then f:SetMinResize(800, 500) end -- tighter min for the bigger layout

  -- visible resize handle (bottom-right)
  local grip = CreateFrame("Button", nil, f)
  grip:SetWidth(16); grip:SetHeight(16)
  grip:SetPoint("BOTTOMRIGHT", 10, -10)
  grip:SetFrameLevel(f:GetFrameLevel() + 10)
  grip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
  grip:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
  grip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
  grip:SetAlpha(0.6)
  grip:SetScript("OnEnter", function() grip:SetAlpha(1) end)
  grip:SetScript("OnLeave", function() grip:SetAlpha(0.6) end)
  grip:SetScript("OnMouseDown", function()
    if f.StartSizing then f:StartSizing("BOTTOMRIGHT") end
  end)
  grip:SetScript("OnMouseUp", function() f:StopMovingOrSizing() end)

  f:SetScript("OnSizeChanged", function()
    local w,h = f:GetWidth(), f:GetHeight()
    if w and h then sv.w, sv.h = w,h end
    if self.left and self.content then
      self.content:ClearAllPoints()
      -- was: (drag:GetHeight() or 16)
      self.content:SetPoint("TOPLEFT", self.left, "TOPRIGHT", 10, 0)
      self.content:SetPoint("BOTTOMRIGHT", -14, 14)
    end
    if self._current and self._frames[self._current] then
      local pane = self._frames[self._current]
      if pane.OnHostResized then pane:OnHostResized(f) end
    end
  end)

  local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", -5, -5)

  -- left (tabs) — a bit wider to suit more raid names
  local left = CreateFrame("Frame", nil, f)
  left:ClearAllPoints() 
  left:SetPoint("TOPLEFT", drag, "BOTTOMLEFT", 14, -8)  -- no extra vertical gap
  left:SetPoint("BOTTOMLEFT", 14, 24)
  left:SetWidth(100)
  left:SetBackdrop({
    bgFile   = "Interface\\ChatFrame\\ChatFrameBackground",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 12,
    insets   = { left = 3, right = 3, top = 3, bottom = 3 }
  })
  left:SetBackdropColor(0,0,0,0.4)

  -- after `left` exists, re-anchor drag to only sit above the left column
  drag:ClearAllPoints()
  drag:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -8)
  drag:SetPoint("TOPRIGHT", f, "TOPLEFT", 12 + 100, -8)
  drag:SetHeight(16)


  local title = drag:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    title:SetText("Fingbel Raid Tool")
    title:SetJustifyH("CENTER")    
    title:SetPoint("BOTTOM", left, "TOP", 0, 0)  -- centered above the left column

  -- right content
  local content = CreateFrame("Frame", nil, f)
    content:ClearAllPoints()
    content:SetPoint("TOPLEFT", left, "TOPRIGHT", 10, 0)
    content:SetPoint("BOTTOMRIGHT", -14, 14)
    self.frame, self.left, self.content = f, left, content

  -- lifecycle passthrough
  f:SetScript("OnShow", function()
    if self._current and self._frames[self._current] then
      local pane = self._frames[self._current]
      if pane.OnHostShown then pane:OnHostShown(f) end
      if pane.OnHostResized then pane:OnHostResized(f) end
    end
  end)
  f:SetScript("OnHide", function()
    if self._current and self._frames[self._current] then
      local pane = self._frames[self._current]
      if pane.OnHostHidden then pane:OnHostHidden(f) end
    end
  end)

  -- placement
  if type(sv.x) == "number" and type(sv.y) == "number" then
    SafePoint(f, "TOPLEFT", UIParent, "BOTTOMLEFT", sv.x, sv.y)
  else
    SafePoint(f, "CENTER", UIParent, "CENTER", 0, 0)
  end

  f:Hide()
  self:_RebuildButtons()
end

function E:_RebuildButtons()
  for _, btn in pairs(self._buttons) do btn:Hide() end
  self._buttons = {}

  local names = {}
  for n,_ in pairs(self._panels) do table.insert(names, n) end
  table.sort(names, function(a,b)
    local pa, pb = self._panels[a], self._panels[b]
    if pa.order ~= pb.order then return pa.order < pb.order end
    return (pa.title or a) < (pb.title or b)
  end)

  local y = -6
  for _, name in ipairs(names) do
    local info = self._panels[name]
    local btn = CreateFrame("Button", nil, self.left, "UIPanelButtonTemplate")
    btn:SetWidth(80); btn:SetHeight(20)
    btn:SetPoint("TOPLEFT", 10, y)
    btn:SetText(info.title or name)

    local panelName = name  -- capture a fresh local for the closure
    btn:SetScript("OnClick", function()
      E:_Select(panelName)
    end)

    self._buttons[name] = btn
    y = y - 24
  end
end

function E:_EnsurePanel(name)
  if self._frames[name] then return self._frames[name] end
  local info = self._panels[name]; if not info then return nil end
  local pane = CreateFrame("Frame", nil, self.content)
  pane:SetAllPoints(self.content)
  pane:Hide()
  info.builder(pane)
  self._frames[name] = pane
  return pane
end

function E:_Select(name)
  if not name then return end
  local sv = GetMainEditorSV()
  sv.selected = name

  if self._current and self._frames[self._current] then
    local oldPane = self._frames[self._current]
    if oldPane.OnHostHidden then oldPane:OnHostHidden(self.frame) end
    oldPane:Hide()
  end

  for n,btn in pairs(self._buttons) do
    if btn.SetButtonState then btn:SetButtonState((n == name) and "PUSHED" or "NORMAL") end
    if btn.SetEnabled then btn:SetEnabled(n ~= name) end
  end

  local pane = self:_EnsurePanel(name)
  if pane then
    self._current = name
    pane:Show()
    if pane.OnHostShown then pane:OnHostShown(self.frame) end
    if pane.OnHostResized then pane:OnHostResized(self.frame) end
  end
end

function E.Show(name)
  E:_CreateWindowOnce()
  E.frame:Show()
  local sv = GetMainEditorSV()
  local pick = name or sv.selected
  if pick and E._panels[pick] then
    E:_Select(pick)
  else
    for n,_ in pairs(E._panels) do E:_Select(n); break end
  end
end

function E.Hide() if E.frame then E.frame:Hide() end end
function E.Toggle(name) if E.frame and E.frame:IsShown() then E.Hide() else E.Show(name) end end

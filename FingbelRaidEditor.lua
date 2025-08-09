-- Fingbel Raid Tool — Global Editor Host (1.12)
FRT = FRT or {}
FRT.Editor = FRT.Editor or {}

local E = FRT.Editor
E._panels = E._panels or {}   -- name -> { builder=func, title=string, order=number }
E._frames = E._frames or {}   -- name -> built frame
E._buttons = E._buttons or {} -- name -> button

-- Public: modules call this to register their editor pane
function E.RegisterPanel(name, builder, opts)
  if not name or not builder then return end
  E._panels[name] = {
    builder = builder,
    title   = (opts and opts.title) or name,
    order   = (opts and opts.order) or 1000,
  }
  -- If window already exists, add button now
  if E.frame and E.left then
    E:_RebuildButtons()
  end
end

function GetMainEditorSV()
  if type(FRT_Saved) ~= "table" then FRT_Saved = {} end
  FRT_Saved.ui = FRT_Saved.ui or {}
  FRT_Saved.ui.mainEditor = FRT_Saved.ui.mainEditor or { x=nil, y=nil, w=560, h=360, selected=nil }
  return FRT_Saved.ui.mainEditor
end

function SafePoint(frame, point, relTo, relPoint, x, y)
  if FRT and FRT.SafeSetPoint then
    FRT.SafeSetPoint(frame, point, relTo, relPoint, x, y)
  else
    frame:ClearAllPoints()
    frame:SetPoint(point or "CENTER", relTo or UIParent, relPoint or (point or "CENTER"), tonumber(x) or 0, tonumber(y) or 0)
  end
end

-- Create host window once
function E:_CreateWindowOnce()
  if self.frame then return end

  local sv = GetMainEditorSV()

  local f = CreateFrame("Frame", "FRT_MainEditor", UIParent)
  f:SetFrameStrata("DIALOG")
  f:SetWidth(sv.w or 560); f:SetHeight(sv.h or 360)
  f:SetBackdrop({
    bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 32, edgeSize = 32,
    insets = { left = 11, right = 12, top = 12, bottom = 11 }
  })
  f:EnableMouse(true)
  f:SetMovable(true)  -- keep movable, but don't register f itself for drag

  -- title bar / drag handle
  local drag = CreateFrame("Frame", nil, f)
  drag:SetPoint("TOPLEFT", 12, -8)
  drag:SetPoint("TOPRIGHT", -32, -8)
  drag:SetHeight(22)
  drag:EnableMouse(true)
  drag:RegisterForDrag("LeftButton")
  drag:SetScript("OnDragStart", function() f:StartMoving() end)
  drag:SetScript("OnDragStop", function()
    f:StopMovingOrSizing()
    local x,y = f:GetLeft(), f:GetTop()
    if x and y then sv.x, sv.y = x,y end
  end)
  f:SetClampedToScreen(true)
  if f.SetResizable then f:SetResizable(true) end
  if f.SetMinResize then f:SetMinResize(520, 300) end
  f:SetScript("OnSizeChanged", function()
    local w,h = f:GetWidth(), f:GetHeight()
    if w and h then sv.w, sv.h = w,h end
    -- stretch children
    if self.left and self.content then
      self.content:SetPoint("TOPLEFT", self.left, "TOPRIGHT", 10, 0)
      self.content:SetPoint("BOTTOMRIGHT", -14, 14)
    end
  end)

  -- title
  local title = f:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  title:SetPoint("TOP", 0, -10)
  title:SetText("Fingbel Raid Editor")

  -- close
  local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", -5, -5)

  -- left column (tabs)
  local left = CreateFrame("Frame", nil, f)
  left:SetPoint("TOPLEFT", 14, -36)
  left:SetWidth(140)
  left:SetPoint("BOTTOMLEFT", 14, 14)
  left:SetBackdrop({
    bgFile   = "Interface\\ChatFrame\\ChatFrameBackground",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 12,
    insets = { left = 3, right = 3, top = 3, bottom = 3 }
  })
  left:SetBackdropColor(0,0,0,0.4)

  -- right content area
  local content = CreateFrame("Frame", nil, f)
  content:SetPoint("TOPLEFT", left, "TOPRIGHT", 10, 0)
  content:SetPoint("BOTTOMRIGHT", -14, 14)

  self.frame, self.left, self.content = f, left, content

  -- initial placement
  if type(sv.x) == "number" and type(sv.y) == "number" then
    SafePoint(f, "TOPLEFT", UIParent, "BOTTOMLEFT", sv.x, sv.y)
  else
    SafePoint(f, "CENTER", UIParent, "CENTER", 0, 0)
  end

  f:Hide()
  self:_RebuildButtons()
end

-- Build/refresh left-side tab buttons
function E:_RebuildButtons()
  -- wipe old
  for _,btn in pairs(self._buttons) do btn:Hide() end
  self._buttons = {}

  -- sort panels
  local names = {}
  for name,_ in pairs(self._panels) do table.insert(names, name) end
  table.sort(names, function(a,b)
    local pa, pb = self._panels[a], self._panels[b]
    if pa.order ~= pb.order then return pa.order < pb.order end
    return (pa.title or a) < (pb.title or b)
  end)

  local y = -6
  for _,name in ipairs(names) do
    local info = self._panels[name]
    local btn = CreateFrame("Button", nil, self.left, "UIPanelButtonTemplate")
    btn:SetWidth(120); btn:SetHeight(20)
    btn:SetPoint("TOPLEFT", 10, y)
    btn:SetText(info.title or name)
    btn:SetScript("OnClick", function() E:Show(name) end)
    self._buttons[name] = btn
    y = y - 24
  end
end

-- Build a panel frame on demand
function E:_EnsurePanel(name)
  if self._frames[name] then return self._frames[name] end
  local info = self._panels[name]; if not info then return nil end
  local pane = CreateFrame("Frame", nil, self.content)
  pane:SetAllPoints(self.content)
  pane:Hide()
  -- let module populate
  info.builder(pane)
  self._frames[name] = pane
  return pane
end

-- Show main editor (optionally focus a tab)
function E.Show(name)
  E:_CreateWindowOnce()

  -- show window
  E.frame:Show()

  -- select saved or requested
local sv = GetMainEditorSV()  local pick = name or sv.selected
if pick and E._panels[pick] then
    E:_Select(pick)
else
    -- default to first panel if any
    for n,_ in pairs(E._panels) do E:_Select(n); break end
  end
end

-- Hide/toggle helpers
function E.Hide() if E.frame then E.frame:Hide() end end
function E.Toggle(name)
  if E.frame and E.frame:IsShown() then E.Hide() else E.Show(name) end
end

-- Internal: select tab + show panel
function E:_Select(name)
  if not name then return end
local sv = GetMainEditorSV()
sv.selected = name

  -- button highlight-ish: disable selected
  for n,btn in pairs(self._buttons) do
    if btn.SetButtonState then
      btn:SetButtonState((n==name) and "PUSHED" or "NORMAL")
    end
    if btn.SetEnabled then btn:SetEnabled(n ~= name) end
  end

  -- swap panels
  for n,frm in pairs(self._frames) do frm:Hide() end
  local pane = self:_EnsurePanel(name)
  if pane then pane:Show() end
end

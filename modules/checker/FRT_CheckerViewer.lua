-- Fingbel Raid Tool - Checker Viewer (frames only)
-- Depends on FRT_CheckerCore
-- Turtle WoW / Vanilla 1.12 / Lua 5.0

FRT = FRT or {}

--===============================
-- UI constants / textures
--===============================
local ROW_HEIGHT   = 18
local TEX_CHECK    = "Interface\\Buttons\\UI-CheckBox-Check"
local TEX_CROSS    = "Interface\\Buttons\\UI-GroupLoot-Pass-Up"

--===============================
-- Local UI state
--===============================
local UI = {
  frame=nil, header=nil, scroll=nil, rows=nil, scrollChild=nil,
  -- Behavior: baseline = "missing only", no toggle for that anymore.
  myBuffs=false,          -- NEW: show only columns you can provide
  filteredIndex={},
  visibleRows=0,          -- calculated on show/resize
  _lastTotal=0,
}

--===============================
-- Helpers
--===============================
local function ClassColorRGB(class)
  local t = RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
  if t then return t.r, t.g, t.b end
  return 1,1,1
end

local function ClearRowFrames()
  if not UI.scrollChild then return end
  local kids = { UI.scrollChild:GetChildren() }
  local i = 1
  while kids[i] do
    local k = kids[i]
    k:Hide()
    k:SetParent(nil)
    kids[i] = nil
    i = i + 1
  end
  UI.rows = nil
end

local function RecalcVisibleRows()
  if not UI.scroll then return end
  local h = UI.scroll:GetHeight() or 0
  local rowsFit = math.floor(h / ROW_HEIGHT)
  if rowsFit < 4 then rowsFit = 4 end
  if rowsFit > 40 then rowsFit = 40 end
  if rowsFit ~= UI.visibleRows then
    UI.visibleRows = rowsFit
    if UI.scrollChild then
      UI.scrollChild:SetHeight(ROW_HEIGHT * UI.visibleRows)
    end
    ClearRowFrames()
  end
end

-- min size helpers (guard SetMinResize for 1.12 safety)
local function ComputeMinSize(numCols)
  local LEFT_PAD  = 10
  local START_X   = 160
  local COL_W     = 22
  local COL_SP    = 6
  local RIGHT_PAD = 10

  local minW = LEFT_PAD + START_X + (numCols * (COL_W + COL_SP)) + RIGHT_PAD
  if minW < 460 then minW = 460 end

  local MIN_ROWS = 4
  local minH = 92 + (MIN_ROWS * ROW_HEIGHT)
  if minH < 260 then minH = 260 end
  return minW, minH
end

local function ApplyMinResizeForCols(frame, cols)
  if not frame then return end
  local n = (cols and table.getn(cols)) or 0
  local w, h = ComputeMinSize(n)
  if frame.SetMinResize then frame:SetMinResize(w, h) end
end

--===============================
-- Column filtering (NEW)
--===============================
local function FilterColumnsForView(allCols)
  if not UI.myBuffs then return allCols end
  local filtered = {}
  local i=1
  while i <= table.getn(allCols) do
    local col = allCols[i]
    local ok = (FRT.CheckerCore and FRT.CheckerCore.PlayerCanProvide and FRT.CheckerCore.PlayerCanProvide(col.key)) or false
    if ok then table.insert(filtered, col) end
    i = i + 1
  end
  return filtered
end

--===============================
-- Header + rows
--===============================
local function CreateHeader(parent)
  local header = CreateFrame("Frame", nil, parent)
  header:SetHeight(24)
  header:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, -38)
  header:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -10, -38)

  local name = header:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  name:SetPoint("LEFT", header, "LEFT", 8, 0)
  name:SetText("Name")
  header.name = name
  header.cols = {}
  return header
end

local function SetHeaderColumns(header, cols, roster, results)
  -- clear old
  local i=1
  while i <= table.getn(header.cols) do
    if header.cols[i] then header.cols[i]:Hide() end
    i = i + 1
  end
  header.cols = {}

  local startX = 160
  local colW   = 22
  i=1
  while i <= table.getn(cols) do
    local h = CreateFrame("Frame", nil, header)
    h:SetWidth(colW); h:SetHeight(18)
    h:SetPoint("LEFT", header, "LEFT", startX + (i-1)*(colW+6), 0)

    local t = h:CreateTexture(nil, "ARTWORK"); t:SetAllPoints()
    t:SetTexture(cols[i].icon or "Interface\\Icons\\INV_Misc_QuestionMark")
    t:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    h.tex = t

    header.cols[i] = h
    i = i + 1
  end

  -- Tooltip with missing count for the **visible** columns
  i=1
  while i <= table.getn(header.cols) do
    local col = cols[i]
    local missingCount = 0
    local r=1
    while r <= table.getn(roster) do
      local rn = roster[r].name
      local res = results[rn]
      if res and res.present then
        local present = res.present[col.key]
        local isNA = (present == "__NA__")
        if not isNA and not present then missingCount = missingCount + 1 end
      end
      r = r + 1
    end
    local h = header.cols[i]
    local labelCopy, missCopy = col.label, missingCount
    h:EnableMouse(true)
    h:SetScript("OnEnter", function()
      GameTooltip:SetOwner(h, "ANCHOR_BOTTOM")
      GameTooltip:SetText(labelCopy)
      GameTooltip:AddLine("Missing: "..missCopy, 1,0.6,0.6)
      GameTooltip:Show()
    end)
    h:SetScript("OnLeave", function() GameTooltip:Hide() end)
    i = i + 1
  end
end

local function CreateRow(parent)
  local row = CreateFrame("Frame", nil, parent)
  row:SetHeight(ROW_HEIGHT)

  local name = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  name:SetPoint("LEFT", row, "LEFT", 8, 0)
  name:SetText("Player")
  row.name = name

  row.cells = {}
  return row
end

local function EnsureRows(scrollChild)
  if UI.rows and table.getn(UI.rows) >= UI.visibleRows then return end
  UI.rows = UI.rows or {}
  local i = (table.getn(UI.rows) + 1)
  while i <= UI.visibleRows do
    local r = CreateRow(scrollChild)
    if i == 1 then
      r:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, 0)
      r:SetPoint("TOPRIGHT", scrollChild, "TOPRIGHT", 0, 0)
    else
      r:SetPoint("TOPLEFT", UI.rows[i-1], "BOTTOMLEFT", 0, 0)
      r:SetPoint("TOPRIGHT", UI.rows[i-1], "BOTTOMRIGHT", 0, 0)
    end
    UI.rows[i] = r
    i = i + 1
  end
end

local function SetRowCells(row, numCols)
  if row.cells then
    local i=1
    while i <= table.getn(row.cells) do
      row.cells[i]:Hide()
      i = i + 1
    end
  end
  row.cells = {}

  local startX = 160
  local colW = 18
  local i=1
  while i <= numCols do
    local f = CreateFrame("Button", nil, row)
    f:SetWidth(colW); f:SetHeight(colW)
    f:SetPoint("LEFT", row, "LEFT", startX + (i-1)*(colW+10), 0)
    f:RegisterForClicks()

    local t = f:CreateTexture(nil, "ARTWORK")
    t:SetAllPoints()
    t:SetTexture(TEX_CHECK)
    f.tex = t

    f:SetScript("OnClick", function()
      if not f.key or not f.unit then return end
      if not f._missing then return end
      local useGroup = (arg1 == "RightButton")
      if FRT.CheckerCore and FRT.CheckerCore.TryCast then
        FRT.CheckerCore.TryCast(f.key, f.unit, useGroup)
      end
    end)

    f:SetScript("OnEnter", function()
      if not f.key then return end
      local col = f._colLabel
      GameTooltip:SetOwner(f, "ANCHOR_RIGHT")
      GameTooltip:SetText(col or "Buff")
      if f._canCast then
        GameTooltip:AddLine("Left-click: single buff", 0,1,0)
        GameTooltip:AddLine("Right-click: group buff (if known)", 0,1,0)
      else
        if not f._missing then
          GameTooltip:AddLine("Already present or N/A.", 0.8,0.8,0.8)
        else
          GameTooltip:AddLine("You cannot cast this buff.", 1,0.3,0.3)
        end
      end
      GameTooltip:Show()
    end)
    f:SetScript("OnLeave", function() GameTooltip:Hide() end)

    row.cells[i] = f
    i = i + 1
  end
end

local function UpdateRowVisual(row, rosterEntry, cols, results)
  if not rosterEntry then row:Hide(); return end
  row:Show()
  row.name:SetText(rosterEntry.name or "?")
  local r,g,b = ClassColorRGB(rosterEntry.class or "")
  row.name:SetTextColor(r,g,b)

  if not row.cells or table.getn(row.cells) ~= table.getn(cols) then
    SetRowCells(row, table.getn(cols))
  end

  local i=1
  while i <= table.getn(cols) do
    local key = cols[i].key
    local cell = row.cells[i]
    local tex = cell.tex

    cell.unit = rosterEntry.unit
    cell.key  = key
    cell._colLabel = cols[i].label

    local res = results[rosterEntry.name]
    local present = res and res.present and res.present[key]
    local isNA = (present == "__NA__")
    local missing = (not isNA) and (not present)
    cell._missing = missing

    if isNA then
      tex:SetTexture(TEX_CHECK); tex:SetVertexColor(0.7, 0.7, 0.7, 0.35)
    elseif present then
      tex:SetTexture(TEX_CHECK); tex:SetVertexColor(0.2, 1.0, 0.2, 1.0)
    else
      tex:SetTexture(TEX_CROSS); tex:SetVertexColor(1.0, 0.2, 0.2, 1.0)
    end

    local canCast = FRT.CheckerCore and FRT.CheckerCore.PlayerCanProvide and FRT.CheckerCore.PlayerCanProvide(key)
    local clickable = canCast and missing
    cell._canCast = canCast
    cell:EnableMouse(clickable)
    if clickable then
      cell:RegisterForClicks("LeftButtonDown", "RightButtonDown")
      cell:SetAlpha(1.0)
    else
      cell:RegisterForClicks()
      cell:SetAlpha(0.6)
    end

    i = i + 1
  end
end

--===============================
-- Refresh pipeline
--===============================
-- Baseline behavior: rows show only raiders with at least ONE missing among the **visible** columns.
local function RebuildFilter(roster, results, visibleCols)
  UI.filteredIndex = {}
  local i=1
  while i <= table.getn(roster) do
    local name = roster[i].name
    local res = results[name]
    local show = false
    if res and res.present and table.getn(visibleCols) > 0 then
      local j=1
      while j <= table.getn(visibleCols) do
        local key = visibleCols[j].key
        local p = res.present[key]
        local isNA = (p == "__NA__")
        if not isNA and not p then
          show = true
          break
        end
        j = j + 1
      end
    end
    if show then table.insert(UI.filteredIndex, i) end
    i = i + 1
  end
end

local function RefreshGrid()
  if not UI.frame then return end
  local roster   = (FRT.CheckerCore and FRT.CheckerCore.GetRoster())  or {}
  local allCols  = (FRT.CheckerCore and FRT.CheckerCore.GetColumns()) or {}
  local results  = (FRT.CheckerCore and FRT.CheckerCore.GetResults()) or {}

  local cols = FilterColumnsForView(allCols)

  ApplyMinResizeForCols(UI.frame, cols)
  SetHeaderColumns(UI.header, cols, roster, results)
  RebuildFilter(roster, results, cols)

  local total = table.getn(UI.filteredIndex)
  if total ~= UI._lastTotal then
    ClearRowFrames()
    UI._lastTotal = total
  end

  FauxScrollFrame_Update(UI.scroll, total, UI.visibleRows, ROW_HEIGHT)
  local offset = FauxScrollFrame_GetOffset(UI.scroll) or 0
  if offset > 0 and (offset + UI.visibleRows) > total then
    offset = math.max(0, total - UI.visibleRows)
    local sb = getglobal((UI.scroll:GetName() or "").."ScrollBar")
    if sb then sb:SetValue(offset * ROW_HEIGHT) end
  end

  EnsureRows(UI.scrollChild)

  -- Shrink paint area when few rows
  local used = math.max(1, math.min(UI.visibleRows, total))
  UI.scrollChild:SetHeight(ROW_HEIGHT * used)

  if UI.rows then
    local r = 1
    while r <= table.getn(UI.rows) do
      UI.rows[r]:Hide()
      r = r + 1
    end
  end

  local i = 1
  while i <= UI.visibleRows do
    local idx = UI.filteredIndex[offset + i]
    local rosterEntry = idx and roster[idx] or nil
    UpdateRowVisual(UI.rows[i], rosterEntry, cols, results)
    i = i + 1
  end
end

--===============================
-- Build UI
--===============================
local function BuildUI()
  if UI.frame then return end

  local f = CreateFrame("Frame", "FRT_CheckerFrame", UIParent)
  f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
  f:SetWidth(560); f:SetHeight(360)
  f:SetFrameStrata("DIALOG")
  f:SetBackdrop({
    bgFile  = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile= "Interface\\Tooltips\\UI-Tooltip-Border",
    tile=true, tileSize=16, edgeSize=14,
    insets={ left=4, right=4, top=4, bottom=4 }
  })
  f:SetBackdropColor(0,0,0,0.85)
  f:SetBackdropBorderColor(1,1,1,1)

  local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  title:SetPoint("TOPLEFT", f, "TOPLEFT", 16, -12)
  title:SetText("FRT Checker — Missing Buffs")

  local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -4, -4)

  -- Drag by title area
  f:SetMovable(true)
  f:EnableMouse(true)
  local drag = CreateFrame("Frame", nil, f)
  drag:SetPoint("TOPLEFT", f, "TOPLEFT", 8, -8)
  drag:SetPoint("TOPRIGHT", f, "TOPRIGHT", -28, -8)
  drag:SetHeight(28)
  drag:EnableMouse(true)
  drag:RegisterForDrag("LeftButton")
  drag:SetScript("OnDragStart", function() f:StartMoving() end)
  drag:SetScript("OnDragStop",  function() f:StopMovingOrSizing() end)
  title:ClearAllPoints()
  title:SetPoint("LEFT", drag, "LEFT", 8, 0)

  -- REPLACED: "Only Missing" -> "My buffs"
  local onlyMine = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate")
  onlyMine:SetPoint("TOPRIGHT", f, "TOPRIGHT", -110, -12)
  onlyMine.text = onlyMine:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
  onlyMine.text:SetPoint("LEFT", onlyMine, "RIGHT", 2, 0)
  onlyMine.text:SetText("My buffs")
  onlyMine:SetScript("OnClick", function()
    UI.myBuffs = (onlyMine:GetChecked() and true or false)
    RefreshGrid()
  end)

  UI.header = CreateHeader(f)

  local scroll = CreateFrame("ScrollFrame", "FRT_CheckerScroll", f, "FauxScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -60)
  scroll:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -28, 32)
  UI.scroll = scroll

  local child = CreateFrame("Frame", nil, f)
  child:ClearAllPoints()
  child:SetPoint("TOPLEFT",  UI.scroll, "TOPLEFT",  0, 0)
  child:SetPoint("TOPRIGHT", UI.scroll, "TOPRIGHT", 0, 0)
  child:SetHeight(ROW_HEIGHT * (UI.visibleRows > 0 and UI.visibleRows or 4))
  f.scrollChild = child
  UI.scrollChild = child

  scroll:SetScript("OnVerticalScroll", function()
    FauxScrollFrame_OnVerticalScroll(this, arg1, ROW_HEIGHT, RefreshGrid)
  end)

  -- Resize handle
  f:SetResizable(true)
  if f.SetMinResize then f:SetMinResize(460, 260) end
  local sizer = CreateFrame("Button", nil, f)
  sizer:SetFrameLevel((f:GetFrameLevel() or 0) + 5)
  sizer:SetWidth(18); sizer:SetHeight(18)
  sizer:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -6, 6)
  sizer:SetNormalTexture("Interface\\DialogFrame\\UI-DialogBox-Corner")
  sizer:SetPushedTexture("Interface\\DialogFrame\\UI-DialogBox-Corner")
  sizer:SetHighlightTexture("Interface\\DialogFrame\\UI-DialogBox-Corner")

  sizer:SetScript("OnMouseDown", function()
    f:StartSizing("BOTTOMRIGHT")
    if this and this.SetButtonState then this:SetButtonState("PUSHED", true) end
  end)
  sizer:SetScript("OnMouseUp", function()
    f:StopMovingOrSizing()
    if this and this.SetButtonState then this:SetButtonState("NORMAL") end
    -- manual clamp for vanilla safety
    local allCols  = (FRT.CheckerCore and FRT.CheckerCore.GetColumns()) or {}
    local cols = FilterColumnsForView(allCols)
    local mw, mh = ComputeMinSize(table.getn(cols))
    local w, h = f:GetWidth(), f:GetHeight()
    if w < mw then f:SetWidth(mw) end
    if h < mh then f:SetHeight(mh) end
    RecalcVisibleRows()
    RefreshGrid()
  end)

  -- hook core updates while visible
  f:SetScript("OnShow", function()
    if FRT.CheckerCore then
      FRT.CheckerCore.SetLiveEvents(true)
    end
    RecalcVisibleRows()
    RefreshGrid()
  end)

  f:SetScript("OnHide", function()
    if FRT.CheckerCore then
      FRT.CheckerCore.SetLiveEvents(false)
    end
  end)

  UI.frame = f
  UI.rows  = nil
end

--===============================
-- Viewer public
--===============================
FRT.CheckerViewer = {
  Show = function()
    BuildUI()
    if FRT.CheckerCore then
      FRT.CheckerCore.SetLiveEvents(true)
      FRT.CheckerCore.RefreshNow()
    end
    UI.frame:Show()
    RecalcVisibleRows()
    RefreshGrid()
  end
}

-- Subscribe once so any core refresh pings the grid (if visible)
if FRT.CheckerCore and FRT.CheckerCore.Subscribe then
  FRT.CheckerCore.Subscribe(function()
    if UI.frame and UI.frame:IsShown() then
      RefreshGrid()
    end
  end)
end

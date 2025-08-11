-- Fingbel Raid Tool - Checker Viewer (frames only)
-- Depends on FRT_CheckerCore
-- Turtle WoW / Vanilla 1.12 / Lua 5.0

FRT = FRT or {}

--===============================
-- UI constants / textures
--===============================
local ROW_HEIGHT   = 18
local VISIBLE_ROWS = 12
local TEX_CHECK    = "Interface\\Buttons\\UI-CheckBox-Check"
local TEX_CROSS    = "Interface\\Buttons\\UI-GroupLoot-Pass-Up"

--===============================
-- Local UI state
--===============================
local UI = {
  frame=nil, header=nil, scroll=nil, rows=nil,
  onlyMissing=false, filteredIndex={},
}

--===============================
-- Helpers
--===============================
local function ClassColorRGB(class)
  local t = RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
  if t then return t.r, t.g, t.b end
  return 1,1,1
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

  -- Tooltip with missing count (kept)
  i=1
  while i <= table.getn(header.cols) do
    local col = cols[i]
    local missingCount = 0
    local r=1
    while r <= table.getn(roster) do
      local rn = roster[r].name
      local res = results[rn]
      if res then
        local present = res.present[col.key]
        if not present or present == false then missingCount = missingCount + 1 end
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
  if UI.rows and table.getn(UI.rows) >= VISIBLE_ROWS then return end
  UI.rows = UI.rows or {}
  local i = (table.getn(UI.rows) + 1)
  while i <= VISIBLE_ROWS do
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
    local f = CreateFrame("Button", nil, row) -- button for hardware clicks
    f:SetWidth(colW); f:SetHeight(colW)
    f:SetPoint("LEFT", row, "LEFT", startX + (i-1)*(colW+10), 0)
    f:RegisterForClicks() -- set per-update

    local t = f:CreateTexture(nil, "ARTWORK")
    t:SetAllPoints()
    t:SetTexture(TEX_CHECK)
    f.tex = t

    -- Click -> Core.TryCast
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
local function RebuildFilter(roster, results, onlyMissing, cols)
  UI.filteredIndex = {}
  local i=1
  while i <= table.getn(roster) do
    local name = roster[i].name
    local res = results[name]
    local show = true
    if onlyMissing and res then
      show = (table.getn(res.missing) > 0)
    end
    if show then table.insert(UI.filteredIndex, i) end
    i = i + 1
  end
end

local function RefreshGrid()
  if not UI.frame then return end
  local roster  = (FRT.CheckerCore and FRT.CheckerCore.GetRoster())  or {}
  local cols    = (FRT.CheckerCore and FRT.CheckerCore.GetColumns()) or {}
  local results = (FRT.CheckerCore and FRT.CheckerCore.GetResults()) or {}

  SetHeaderColumns(UI.header, cols, roster, results)
  RebuildFilter(roster, results, UI.onlyMissing, cols)

  local total = table.getn(UI.filteredIndex)
  FauxScrollFrame_Update(UI.scroll, total, VISIBLE_ROWS, ROW_HEIGHT)

  local offset = FauxScrollFrame_GetOffset(UI.scroll)
  EnsureRows(UI.frame.scrollChild)

  local i=1
  while i <= VISIBLE_ROWS do
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
    edgeFile= "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile=true, tileSize=16, edgeSize=32,
    insets={ left=10, right=10, top=10, bottom=10 }
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
  drag:SetPoint("TOPRIGHT", f, "TOPRIGHT", -28, -8) -- leave room for close button
  drag:SetHeight(28)
  drag:EnableMouse(true)
  drag:RegisterForDrag("LeftButton")
  drag:SetScript("OnDragStart", function() f:StartMoving() end)
  drag:SetScript("OnDragStop",  function() f:StopMovingOrSizing() end)
  title:ClearAllPoints()
  title:SetPoint("LEFT", drag, "LEFT", 8, 0)

  local only = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate")
  only:SetPoint("TOPRIGHT", f, "TOPRIGHT", -110, -12)
  only.text = only:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
  only.text:SetPoint("LEFT", only, "RIGHT", 2, 0)
  only.text:SetText("Only Missing")
  only:SetScript("OnClick", function()
    UI.onlyMissing = (only:GetChecked() and true or false)
    RefreshGrid()
  end)

  UI.header = CreateHeader(f)

  local scroll = CreateFrame("ScrollFrame", "FRT_CheckerScroll", f, "FauxScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -60)
  scroll:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -26, 32)
  UI.scroll = scroll

  local child = CreateFrame("Frame", nil, f)
  child:SetPoint("TOPLEFT", scroll, "TOPLEFT", 0, 0)
  child:SetWidth(1); child:SetHeight(ROW_HEIGHT * VISIBLE_ROWS)
  f.scrollChild = child

  scroll:SetScript("OnVerticalScroll", function()
    FauxScrollFrame_OnVerticalScroll(this, arg1, ROW_HEIGHT, RefreshGrid)
  end)

  -- hook core updates while visible
  f:SetScript("OnShow", function()
    if FRT.CheckerCore then
      FRT.CheckerCore.SetLiveEvents(true)
    end
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

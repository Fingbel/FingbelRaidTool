-- Fingbel Raid Tool - Checker Viewer (auto-sized, no scrolling, tight, with live range checks)
-- Depends on FRT_CheckerCore + FRT_Casting (for range checks)
-- Turtle WoW / Vanilla 1.12 / Lua 5.0

FRT = FRT or {}

--===============================
-- UI constants / textures
--===============================
local ROW_HEIGHT   = 18
local TEX_CHECK    = "Interface\\Buttons\\UI-CheckBox-Check"
local TEX_CROSS    = "Interface\\Buttons\\UI-GroupLoot-Pass-Up"
local TEX_WARN     = "Interface\\GossipFrame\\AvailableQuestIcon"

-- Layout (tight)
local HEADER_TOP_OFFSET = 38
local HEADER_HEIGHT     = 24
local PAD_LEFT          = 4
local PAD_RIGHT         = 8
local PAD_BELOW_HEADER  = 0
local PAD_BOTTOM        = 4

local NAME_START_X = 8
local COL_START_X  = 90     -- width of the name column
local COL_W        = 18
local COL_SP       = 10
local HEADER_COL_W = 22
local HEADER_COL_SP= 6

-- Empty overlay line sizes
local EMPTY_ICON  = 24
local EMPTY_GAP   = 2
local EMPTY_TOTAL = EMPTY_ICON + EMPTY_GAP + EMPTY_ICON

-- Range polling
local RANGE_TICK_SEC = 0.25  -- how often to refresh range UI

--===============================
-- Local UI state
--===============================
local UI = {
  frame=nil, header=nil, rows=nil, list=nil, empty=nil, content=nil, topBar=nil,
  expand=false,            -- false=compact (group rows), true=expanded (players only)
  filteredIndex={},
  visibleCols=nil,
  rowsData=nil,            -- unified rows (player or group)
  _rangeAccum=0,
}

--===============================
-- Helpers (colors, filters, range)
--===============================

-- Return the best unit in the group to anchor a group buff:
-- prefer visible + in-range by SINGLE spell; else any visible member
local function PickGroupAnchorForCell(cell)
  if not cell or not cell._groupUnits or not cell.key then return nil end
  local icons = FRT.CheckerRegistry and FRT.CheckerRegistry.GetSpellIcons(cell.key)
  local list  = icons and (icons.single or icons.group)

  local fallback = nil
  local i = 1
  while cell._groupUnits[i] do
    local u = cell._groupUnits[i]
    if UnitExists(u) and UnitIsConnected(u) and not UnitIsDeadOrGhost(u) and UnitIsVisible(u) then
      fallback = fallback or u
      if list and FRT.Cast.InRangeByIcons(list, u) then
        return u
      end
    end
    i = i + 1
  end
  return fallback
end


local function ClassColorRGB(class)
  local t = RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
  if t then return t.r, t.g, t.b end
  return 1,1,1
end

-- Force "my columns" regardless of UI.expand (for sizing in empty/expanded state)
local function FilterMyColumns(allCols)
  local filtered, i = {}, 1
  while i <= table.getn(allCols) do
    local col = allCols[i]
    local ok = FRT.CheckerCore and FRT.CheckerCore.PlayerCanProvide and FRT.CheckerCore.PlayerCanProvide(col.key)
    if ok then table.insert(filtered, col) end
    i = i + 1
  end
  return filtered
end

-- Column filter: default only buffs I can provide; expand=true shows all
local function FilterColumnsForView(allCols)
  if UI.expand then return allCols end
  return FilterMyColumns(allCols)
end

--===============================
-- Header + rows
--===============================
local function CreateHeader(parent)
  local header = CreateFrame("Frame", nil, parent)
  header:SetHeight(HEADER_HEIGHT)
  header:SetPoint("TOPLEFT", parent, "TOPLEFT", PAD_LEFT, -HEADER_TOP_OFFSET - 20)
  header:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -PAD_RIGHT, -HEADER_TOP_OFFSET - 20)

  local name = header:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  name:SetPoint("LEFT",  header, "LEFT", NAME_START_X, 0)
  name:SetPoint("RIGHT", header, "LEFT", COL_START_X - 4, 0)
  name:SetJustifyH("LEFT")
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

  local iCol=1
  while iCol <= table.getn(cols) do
    local h = CreateFrame("Frame", nil, header)
    h:SetWidth(HEADER_COL_W); h:SetHeight(18)
    h:SetPoint("LEFT", header, "LEFT", COL_START_X + (iCol-1)*(HEADER_COL_W+HEADER_COL_SP), 0)

    local t = h:CreateTexture(nil, "ARTWORK"); t:SetAllPoints()
    t:SetTexture(cols[iCol].icon or "Interface\\Icons\\INV_Misc_QuestionMark")
    t:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    header.cols[iCol] = h
    iCol = iCol + 1
  end

  -- Tooltip with missing count (visible cols)
  iCol=1
  while iCol <= table.getn(header.cols) do
    local col = cols[iCol]
    local missingCount, r = 0, 1
    while r <= table.getn(roster) do
      local rn = roster[r].name
      local res = results[rn]
      if res and res.present then
        local p = res.present[col.key]
        local isNA = (p == "__NA__")
        if not isNA and not p then missingCount = missingCount + 1 end
      end
      r = r + 1
    end
    local h = header.cols[iCol]
    local labelCopy, missCopy = col.label, missingCount
    h:EnableMouse(true)
    h:SetScript("OnEnter", function()
      GameTooltip:SetOwner(h, "ANCHOR_BOTTOM")
      GameTooltip:SetText(labelCopy)
      GameTooltip:AddLine("Missing: "..missCopy, 1,0.6,0.6)
      GameTooltip:Show()
    end)
    h:SetScript("OnLeave", function() GameTooltip:Hide() end)
    iCol = iCol + 1
  end
end

local function CreateRow(parent)
  local row = CreateFrame("Frame", nil, parent)
  row:SetHeight(ROW_HEIGHT)

  local name = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  name:SetPoint("LEFT", row, "LEFT", NAME_START_X, 0)
  name:SetPoint("RIGHT", row, "LEFT", COL_START_X - 4, 0)
  name:SetJustifyH("LEFT")
  name:SetText("Player")
  row.name = name

  row.cells = {}
  return row
end

local function SetRowCells(row, numCols)
  if row.cells then
    local i=1; while i <= table.getn(row.cells) do row.cells[i]:Hide(); i = i + 1 end
  end
  row.cells = {}

  local i=1
  while i <= numCols do
    local f = CreateFrame("Button", nil, row)
    f:SetWidth(COL_W); f:SetHeight(COL_W)
    f:SetPoint("LEFT", row, "LEFT", COL_START_X + (i-1)*(COL_W+COL_SP), 0)
    f:RegisterForClicks()

    local t = f:CreateTexture(nil, "ARTWORK"); t:SetAllPoints(); t:SetTexture(TEX_CHECK)
    f.tex = t

    f:SetScript("OnLeave", function() GameTooltip:Hide() end)

    row.cells[i] = f
    i = i + 1
  end
end

-- Range-aware interactivity/alpha
-- Range-aware visuals; do NOT block clicks (casting layer enforces safely)
local function UpdateCellRangeDecor(cell)
  if not cell then return end

  -- Only repick an anchor in compact group rows if we have candidates
  if cell._isGroupRow and cell._groupUnits and table.getn(cell._groupUnits) > 0 then
    local anchor = PickGroupAnchorForCell(cell)
    if anchor then cell.unit = anchor end
  end

  -- If you can't cast or nothing is missing, keep dim and inert
  if not (cell._canCast and cell._missing and cell.key) then
    cell:EnableMouse(false)
    cell:RegisterForClicks()
    cell:SetAlpha(0.6)
    cell._inRange, cell._visible, cell._rangeGroupOK, cell._rangeSingleOK = false, false, false, false
    return
  end

  -- Compute effective range like TryCast: group first, else single.
  local unit   = cell.unit
  local icons  = FRT.CheckerRegistry and FRT.CheckerRegistry.GetSpellIcons(cell.key)
  local gOK, sOK = false, false
  local vis      = false

  if unit then
    vis = FRT.Cast.IsVisiblyReachable(unit)
    if icons then
      if icons.group  then gOK = FRT.Cast.InRangeByIcons(icons.group, unit) end
      if icons.single then sOK = FRT.Cast.InRangeByIcons(icons.single, unit) end
    end
  end

  -- Store flags for the tooltip
  cell._rangeGroupOK  = gOK
  cell._rangeSingleOK = sOK
  cell._visible       = vis
  cell._inRange       = (vis and (gOK or sOK)) and true or false

  -- Interactivity/alpha
  if cell._inRange then
    cell:EnableMouse(true)
    cell:RegisterForClicks("LeftButtonDown","RightButtonDown")
    cell:SetAlpha(1.0)
  else
    cell:EnableMouse(false)
    cell:RegisterForClicks()
    cell:SetAlpha(0.45)
  end
end


-- Per-player row painter
local function UpdateRowVisual(row, rosterEntry, cols, results)
  if not rosterEntry then row:Hide(); return end
  row:Show()
  row.name:SetText(rosterEntry.name or "?")
  local r,g,b = ClassColorRGB(rosterEntry.class or ""); row.name:SetTextColor(r,g,b)

  if not row.cells or table.getn(row.cells) ~= table.getn(cols) then
    SetRowCells(row, table.getn(cols))
  end

  local i=1
  while i <= table.getn(cols) do
    local key  = cols[i].key
    local cell = row.cells[i]
    local tex  = cell.tex

    cell.unit = rosterEntry.unit
    cell.key  = key
    cell._colLabel = cols[i].label
    cell._preferGroupRange = nil

    local res = results[rosterEntry.name]
    local present = res and res.present and res.present[key]
    local isNA    = (present == "__NA__")
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
    cell._canCast = canCast

    cell:SetScript("OnClick", function()
      if not cell._canCast or not cell._missing then return end
      if not FRT.Cast.IsVisiblyReachable(cell.unit) or not FRT.Cast.InRangeByKey(cell.key, cell.unit, false) then
        if FRT and FRT.Print then FRT.Print("|cffffcc00Out of range.|r") end
        return
      end
      if FRT.CheckerCore and FRT.CheckerCore.TryCast then
        FRT.CheckerCore.TryCast(cell.key, cell.unit, false)
      end
    end)

    cell:SetScript("OnEnter", function()
      if not cell.key then return end
      GameTooltip:SetOwner(cell, "ANCHOR_RIGHT")
      GameTooltip:SetText(cell._colLabel or "Buff")
      if cell._canCast then
        if cell._missing then
          if cell._inRange and cell._visible then
            GameTooltip:AddLine("Left-click: single buff", 0,1,0)
          else
            GameTooltip:AddLine("Out of range.", 1,0.3,0.3)
          end
        else
          GameTooltip:AddLine("Already present or N/A.", 0.8,0.8,0.8)
        end
      else
        GameTooltip:AddLine("You cannot cast this buff.", 1,0.3,0.3)
      end
      GameTooltip:Show()
    end)

    UpdateCellRangeDecor(cell)
    i = i + 1
  end
end

-- Compact-mode: paint a single row that represents one subgroup.
local function UpdateGroupRowVisual(row, rowdesc, cols)
  if not rowdesc then row:Hide(); return end
  row:Show()

  -- Title: "Group X (sz/5)" when not full, else "Group X"
  local g  = rowdesc.groupId or "?"
  local sz = rowdesc.groupSize or 0
  local MAX_GROUP_SIZE = 5
  if sz > 0 and sz < MAX_GROUP_SIZE then
    row.name:SetText("Group "..tostring(g).." ("..sz.."/"..MAX_GROUP_SIZE..")")
  else
    row.name:SetText("Group "..tostring(g))
  end
  row.name:SetTextColor(0.9, 0.9, 0.9)

  -- Ensure the right amount of cells for current visible columns
  local numCols = table.getn(cols or {})
  if not row.cells or table.getn(row.cells) ~= numCols then
    SetRowCells(row, numCols)
  end

  -- Helper: choose a good anchor from a list of units (prefer non-player & visible)
  local function pickAnchorFor(units)
    if not units then return nil end
    -- 1) visible & non-player & exists
    local i = 1
    while units[i] do
      local u = units[i]
      if UnitExists(u) and (not UnitIsUnit("player", u)) and FRT.Cast.IsVisiblyReachable(u) then
        return u
      end
      i = i + 1
    end
    -- 2) fallback: any non-player that exists
    i = 1
    while units[i] do
      local u = units[i]
      if UnitExists(u) and (not UnitIsUnit("player", u)) then
        return u
      end
      i = i + 1
    end
    -- 3) nothing suitable
    return nil
  end

  -- Paint each column
  local i = 1
  while i <= numCols do
    local key     = cols[i].key
    local cell    = row.cells[i]
    local tex     = cell.tex
    local st      = (rowdesc.perCol and rowdesc.perCol[key]) or {}

    local eligible= st.eligible or 0
    local missing = st.missing  or 0
    local canCast = (st.canGroupCast and true)
                    or (FRT.CheckerCore and FRT.CheckerCore.PlayerCanProvide and FRT.CheckerCore.PlayerCanProvide(key))
                    or false

    -- Units in this subgroup (for anchoring)
    local groupUnits = rowdesc.units

    -- Base cell metadata
    cell.key               = key
    cell._colLabel         = cols[i].label
    cell._isGroupRow       = true
    cell._groupUnits       = groupUnits
    cell._preferGroupRange = true   -- our range UI should assume the group version
    cell._canCast          = canCast
    cell._missing          = (missing > 0)

    -- Initial anchor (avoid picking the player)
    cell.unit = st.anchor
                or pickAnchorFor(groupUnits)
                or nil

    -- Presence tint (independent of range)
    if eligible <= 0 then
      tex:SetTexture(TEX_CHECK); tex:SetVertexColor(0.7, 0.7, 0.7, 0.35)  -- N/A for this subgroup
    elseif missing <= 0 then
      tex:SetTexture(TEX_CHECK); tex:SetVertexColor(0.2, 1.0, 0.2, 1.0)   -- everyone covered
    else
      tex:SetTexture(TEX_CROSS); tex:SetVertexColor(1.0, 0.2, 0.2, 1.0)   -- at least one missing
    end

    -- Click = attempt a GROUP buff (re-pick anchor right before casting)
    cell:SetScript("OnClick", function()
      if not (cell._canCast and cell._missing) then return end
      -- re-pick an anchor using the populated list
      local anchor = PickGroupAnchorForCell(cell)
      if not anchor then return end
      if FRT.CheckerCore and FRT.CheckerCore.TryCast then
        FRT.CheckerCore.TryCast(cell.key, anchor, true)
      end
    end)

    -- Tooltip with counts + live range hint (range/visibility flags set by UpdateCellRangeDecor)
    cell:SetScript("OnEnter", function()
      GameTooltip:SetOwner(cell, "ANCHOR_RIGHT")
      GameTooltip:SetText(cell._colLabel or "Buff")
      if not cell._canCast then
        GameTooltip:AddLine("You cannot cast this buff.", 1,0.3,0.3)
      else
        GameTooltip:AddLine(string.format("Eligible: %d / Missing: %d", eligible, missing), 0.8,0.8,0.8)
        if missing > 0 then
          if cell._visible and (cell._rangeGroupOK or cell._rangeSingleOK) then
            GameTooltip:AddLine("In range — casting GROUP buff.", 0,1,0)
          else
            GameTooltip:AddLine("Out of range (or not visible).", 1,0.3,0.3)
          end
        else
          GameTooltip:AddLine("Everyone covered or N/A.", 0.8,0.8,0.8)
        end
      end
      GameTooltip:Show()
    end)

    -- Seed range UI now; the periodic ticker will keep it fresh
    UpdateCellRangeDecor(cell)

    i = i + 1
  end
end


-- Ensure we have exactly needed row frames (no scrolling)
local function EnsureRowCount(parent, needed)
  UI.rows = UI.rows or {}
  local have = table.getn(UI.rows)

  local i = have + 1
  while i <= needed do
    local r = CreateRow(parent)
    if i == 1 then
      r:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
      r:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, 0)
    else
      r:SetPoint("TOPLEFT", UI.rows[i-1], "BOTTOMLEFT", 0, 0)
      r:SetPoint("TOPRIGHT", UI.rows[i-1], "BOTTOMRIGHT", 0, 0)
    end
    UI.rows[i] = r
    i = i + 1
  end

  if needed < have then
    local j = needed + 1
    while j <= have do UI.rows[j]:Hide(); j = j + 1 end
  end
end

--===============================
-- Empty overlay (two lines, left-aligned; anchored just under title)
--===============================
local function EnsureEmptyOverlay(parent)
  if UI.empty and UI.empty:GetParent() ~= parent then
    UI.empty:SetParent(parent)
  end
  if UI.empty then return end

  local ov = CreateFrame("Frame", nil, parent)
  ov:SetPoint("TOPLEFT", parent, "TOPLEFT", NAME_START_X, 0)
  ov:SetPoint("RIGHT",   parent, "RIGHT",  -PAD_RIGHT, 0)
  ov:SetHeight(EMPTY_TOTAL)
  ov:SetFrameStrata("DIALOG")
  ov:SetFrameLevel((parent:GetFrameLevel() or 0) + 50)
  ov:Hide()

  -- Line 1 (you)
  local l1tex = ov:CreateTexture(nil, "OVERLAY")
  l1tex:SetTexture(TEX_CHECK)
  l1tex:SetWidth(EMPTY_ICON); l1tex:SetHeight(EMPTY_ICON)
  l1tex:SetPoint("TOPLEFT", ov, "TOPLEFT", 0, 0)
  l1tex:SetVertexColor(0.2, 1.0, 0.2, 1.0)

  local l1msg = ov:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  l1msg:SetPoint("LEFT", l1tex, "RIGHT", 8, 0)
  l1msg:SetText("Job done !")
  l1msg:SetTextColor(0.9, 0.9, 0.9, 1)
  l1msg:SetJustifyH("LEFT")

  -- Line 2 (others)
  local l2tex = ov:CreateTexture(nil, "OVERLAY")
  l2tex:SetWidth(EMPTY_ICON); l2tex:SetHeight(EMPTY_ICON)
  l2tex:SetPoint("TOPLEFT", l1tex, "BOTTOMLEFT", 0, -EMPTY_GAP)

  local l2msg = ov:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  l2msg:SetPoint("LEFT", l2tex, "RIGHT", 8, 0)
  l2msg:SetTextColor(0.9, 0.9, 0.9, 1)
  l2msg:SetJustifyH("LEFT")

  ov.l1 = { tex = l1tex, msg = l1msg }
  ov.l2 = { tex = l2tex, msg = l2msg }
  UI.empty = ov
end

--===============================
-- Logic helpers
--===============================
local function AnyMissingForOtherClasses(roster, results)
  local allCols = (FRT.CheckerCore and FRT.CheckerCore.GetColumns()) or {}
  local i=1
  while i <= table.getn(allCols) do
    local col  = allCols[i]
    local mine = FRT.CheckerCore and FRT.CheckerCore.PlayerCanProvide and FRT.CheckerCore.PlayerCanProvide(col.key)
    if not mine then
      local r=1
      while r <= table.getn(roster) do
        local rn = roster[r].name
        local res = results[rn]
        if res and res.present then
          local p = res.present[col.key]
          local isNA = (p == "__NA__")
          if not isNA and not p then return true end
        end
        r = r + 1
      end
    end
    i = i + 1
  end
  return false
end

-- Baseline: show only raiders with >=1 missing among **visible** columns (player mode)
local function RebuildFilter(roster, results, visibleCols)
  UI.filteredIndex = {}
  local i=1
  while i <= table.getn(roster) do
    local res = results[ roster[i].name ]
    local show = false
    if res and res.present and table.getn(visibleCols) > 0 then
      local j=1
      while j <= table.getn(visibleCols) do
        local key = visibleCols[j].key
        local p = res.present[key]
        local isNA = (p == "__NA__")
        if not isNA and not p then show = true; break end
        j = j + 1
      end
    end
    if show then table.insert(UI.filteredIndex, i) end
    i = i + 1
  end
end

-- Range-only repaint for visible cells (cheap, runs on OnUpdate)
local function RefreshRangeForVisibleRows()
  if not UI.rows or not UI.visibleCols then return end
  local total = table.getn(UI.rowsData or {})
  local numCols = table.getn(UI.visibleCols)
  local i=1
  while i <= total do
    local row = UI.rows[i]
    if row and row:IsShown() then
      local c=1
      while c <= numCols do
        local cell = row.cells and row.cells[c]
        if cell then
          UpdateCellRangeDecor(cell)
        end
        c = c + 1
      end
    end
    i = i + 1
  end
end

--===============================
-- Refresh pipeline (presence + sizing)
--===============================
local function RefreshGrid()
  if not UI.frame then return end

  local roster   = (FRT.CheckerCore and FRT.CheckerCore.GetRoster())  or {}
  local allCols  = (FRT.CheckerCore and FRT.CheckerCore.GetColumns()) or {}
  local results  = (FRT.CheckerCore and FRT.CheckerCore.GetResults()) or {}

  local cols = FilterColumnsForView(allCols)
  UI.visibleCols = cols

  -- Build overlay once on the content area
  if UI.content and (not UI.empty or UI.empty:GetParent() ~= UI.content) then
    EnsureEmptyOverlay(UI.content)
  end

  -- Build unified rowsData: group rows when compact and group % missing high; else player rows
  UI.rowsData = {}
  if not UI.expand and FRT.CheckerCore and FRT.CheckerCore.BuildRows then
    UI.rowsData = FRT.CheckerCore.BuildRows(cols, {
      compact      = true,
      thresholdOn  = 0.60, -- promote to group row when >= 60% of eligible missing
      thresholdOff = 0.50, -- (hysteresis ready if you choose to keep state)
    }) or {}
  else
    RebuildFilter(roster, results, cols)
    local i=1
    while i <= table.getn(UI.filteredIndex) do
      table.insert(UI.rowsData, { type="player", idx=UI.filteredIndex[i] })
      i = i + 1
    end
  end

  local total   = table.getn(UI.rowsData)
  local hasRows = (total > 0)

  SetHeaderColumns(UI.header, cols, roster, results)

  -- Toggle header/rows/overlay
  if hasRows then
    if UI.header then UI.header:Show() end
    if UI.list   then UI.list:Show()  end
    if UI.empty  then UI.empty:Hide() end
  else
    if UI.header then UI.header:Hide() end
    if UI.list   then UI.list:Hide()  end
    if UI.empty  then
      UI.empty.l1.tex:SetTexture(TEX_CHECK)
      UI.empty.l1.tex:SetVertexColor(0.2, 1.0, 0.2, 1.0)
      UI.empty.l1.msg:SetText("Job done !")

      local othersNeed = AnyMissingForOtherClasses(roster, results)
      if othersNeed then
        UI.empty.l2.tex:SetTexture(TEX_WARN)
        UI.empty.l2.tex:SetWidth(20); UI.empty.l2.tex:SetHeight(20)
        UI.empty.l2.tex:SetVertexColor(1.0, 0.95, 0.2)
        UI.empty.l2.msg:SetText("Raid is missing buffs")
      else
        UI.empty.l2.tex:SetTexture(TEX_CHECK)
        UI.empty.l2.tex:SetVertexColor(0.2, 1.0, 0.2, 1.0)
        UI.empty.l2.msg:SetText("Raid fully buffed")
      end
      UI.empty:Show()
    end
  end

  -- Paint rows from rowsData
  EnsureRowCount(UI.list, total)
  local i=1
  while i <= total do
    local rd = UI.rowsData[i]
    if rd.type == "group" then
      UpdateGroupRowVisual(UI.rows[i], rd, cols)
    else
      local rosterEntry = roster[ rd.idx ]
      UpdateRowVisual(UI.rows[i], rosterEntry, cols, results)
    end
    i = i + 1
  end

  -- === SIZING (expanded+empty uses "my columns" for width) ===
  local perCol = HEADER_COL_W + HEADER_COL_SP
  local widthCols = cols
  if (UI.expand and not hasRows) then
    widthCols = FilterMyColumns(allCols)  -- size like non-expanded mode
  end
  local visibleColCount = (widthCols and table.getn(widthCols)) or 0
  local w = PAD_LEFT + COL_START_X + (visibleColCount * perCol) + PAD_RIGHT
  if w < (PAD_LEFT + COL_START_X + PAD_RIGHT) then
    w = PAD_LEFT + COL_START_X + PAD_RIGHT
  end

  local padTop = HEADER_TOP_OFFSET + (hasRows and HEADER_HEIGHT or 0) + PAD_BELOW_HEADER
  local listH  = hasRows and (total * ROW_HEIGHT) or EMPTY_TOTAL

  if UI.list    then UI.list:SetHeight(listH) end
  if UI.content then
    local contentH = hasRows and (HEADER_HEIGHT + listH) or listH
    UI.content:SetHeight(contentH)
  end

  UI.frame:SetHeight(padTop + listH + PAD_BOTTOM)
  UI.frame:SetWidth(w)

  -- Do an immediate range pass so state is correct without waiting for the ticker
  RefreshRangeForVisibleRows()
end

--===============================
-- Build UI ( +/- left of title; grows right & down ) + range ticker
--===============================
local function BuildUI()
  if UI.frame then return end

  -- Helper: pin TOPLEFT so size changes grow to the right & down
  local function LockGrowthTopLeft(frame)
    if not frame or frame._growthLockedTemp then return end
    local l, t = frame:GetLeft(), frame:GetTop()
    if l and t then
      frame._growthLockedTemp = true
      frame:ClearAllPoints()
      frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", l, t)
      frame._growthLockedTemp = nil
    end
  end

  local f = CreateFrame("Frame", "FRT_CheckerFrame", UIParent)
  f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
  f:SetWidth(400); f:SetHeight(200)
  f:SetFrameStrata("DIALOG")
  f:SetClampedToScreen(true)
  f:SetBackdrop({
    bgFile  = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile= "Interface\\Tooltips\\UI-Tooltip-Border",
    tile=true, tileSize=16, edgeSize=14,
    insets={ left=4, right=4, top=4, bottom=4 }
  })
  f:SetBackdropColor(0,0,0,0.85)
  f:SetBackdropBorderColor(1,1,1,1)

  -- Close
  local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -4, -4)

  -- Drag strip (whole top edge)
  f:SetMovable(true); f:EnableMouse(true)
  local drag = CreateFrame("Frame", nil, f)
  drag:SetPoint("TOPLEFT", f, "TOPLEFT", 8, -8)
  drag:SetPoint("TOPRIGHT", f, "TOPRIGHT", -28, -8)
  drag:SetHeight(28); drag:EnableMouse(true)
  drag:RegisterForDrag("LeftButton")
  drag:SetScript("OnDragStart", function() f:StartMoving() end)
  drag:SetScript("OnDragStop",  function() f:StopMovingOrSizing(); LockGrowthTopLeft(f) end)

  -- Top bar: +/- button (left) + title
  local topBar = CreateFrame("Frame", nil, f)
  topBar:SetPoint("TOPLEFT", f, "TOPLEFT", PAD_LEFT, -12)
  topBar:SetPoint("TOPRIGHT", f, "TOPRIGHT", -PAD_RIGHT, -12)
  topBar:SetHeight(20)
  topBar:EnableMouse(true)
  topBar:RegisterForDrag("LeftButton")
  topBar:SetScript("OnDragStart", function()
    if not MouseIsOver(topBar._expandBtn) then f:StartMoving() end
  end)
  topBar:SetScript("OnDragStop", function() f:StopMovingOrSizing(); LockGrowthTopLeft(f) end)
  UI.topBar = topBar

  local expandBtn = CreateFrame("Button", nil, topBar)
  expandBtn:SetWidth(20); expandBtn:SetHeight(20)
  expandBtn:SetPoint("LEFT", topBar, "LEFT", 8, 0)
  expandBtn:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
  topBar._expandBtn = expandBtn

  local glyph = expandBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  glyph:SetPoint("CENTER", expandBtn, "CENTER", 0, 0)
  glyph:SetTextColor(0.35, 0.9, 1.0) -- teal

  local function UpdateExpandGlyph()
    if UI.expand then
      glyph:SetText("-"); expandBtn.tooltip = "Show only my buffs (players)"
    else
      glyph:SetText("+"); expandBtn.tooltip = "Show all buffs (players)"
    end
  end
  expandBtn:SetScript("OnClick", function()
    UI.expand = not UI.expand
    UpdateExpandGlyph()
    RefreshGrid()
  end)
  expandBtn:SetScript("OnEnter", function()
    if expandBtn.tooltip then
      GameTooltip:SetOwner(expandBtn, "ANCHOR_BOTTOMRIGHT")
      GameTooltip:SetText(expandBtn.tooltip)
    end
  end)
  expandBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
  UpdateExpandGlyph()

  local title = topBar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  title:SetPoint("LEFT", expandBtn, "RIGHT", 8, 0)
  title:SetText("Buffs")

  -- Content area (headers / rows / empty overlay live here)
  local content = CreateFrame("Frame", nil, f)
  content:SetPoint("TOPLEFT", topBar, "BOTTOMLEFT", 0, -4)
  content:SetPoint("TOPRIGHT", topBar, "BOTTOMRIGHT", 0, -4)
  content:SetHeight(ROW_HEIGHT)
  UI.content = content

  -- Header
  UI.header = CreateHeader(content)
  UI.header:ClearAllPoints()
  UI.header:SetPoint("TOPLEFT", content, "TOPLEFT", 0, 0)
  UI.header:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, 0)

  -- Rows list (below header)
  local list = CreateFrame("Frame", nil, content)
  list:SetPoint("TOPLEFT", UI.header, "BOTTOMLEFT", 0, 0)
  list:SetPoint("TOPRIGHT", UI.header, "BOTTOMRIGHT", 0, 0)
  list:SetHeight(ROW_HEIGHT)
  UI.list = list

  -- Empty overlay anchored to content (left-aligned with Name column)
  local function EnsureEmpty() EnsureEmptyOverlay(UI.content) end
  EnsureEmpty()

  -- Live updates while visible + live range ticker
  f:SetScript("OnShow", function()
    local l, t = f:GetLeft(), f:GetTop()
    if l and t then
      f:ClearAllPoints()
      f:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", l, t)
    end
    if FRT.CheckerCore then FRT.CheckerCore.SetLiveEvents(true) end
    UI._rangeAccum = 0
    RefreshGrid()
  end)
  f:SetScript("OnHide", function()
    if FRT.CheckerCore then FRT.CheckerCore.SetLiveEvents(false) end
  end)

  -- Throttled OnUpdate for range-only refresh
  f:SetScript("OnUpdate", function(_, elapsed)
    if not UI.frame or not UI.frame:IsShown() then return end
    UI._rangeAccum = (UI._rangeAccum or 0) + (elapsed or 0)
    if UI._rangeAccum >= RANGE_TICK_SEC then
      UI._rangeAccum = 0
      RefreshRangeForVisibleRows()
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
    if UI.frame and UI.frame:IsShown() then RefreshGrid() end
  end)
end

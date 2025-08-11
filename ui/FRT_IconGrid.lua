-- FRT IconGrid (generic, reusable)
-- Vanilla 1.12 / Lua 5.0

FRT = FRT or {}
FRT.UI = FRT.UI or {}

do
  local ROW_HEIGHT_DEFAULT = 18
  local HEADER_H = 24
  local NAME_W   = 150
  local COL_W    = 18
  local START_X  = 160

  local TEX_CHECK = "Interface\\Buttons\\UI-CheckBox-Check"
  local TEX_CROSS = "Interface\\Buttons\\UI-GroupLoot-Pass-Up"

  local function ClassColorRGB(class)
    local t = RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
    if t then return t.r, t.g, t.b end
    return 1,1,1
  end

  -- Create a grid control inside 'parent' (fills parent).
  -- opts: rowHeight, nameWidth, colWidth, initialRows
  function FRT.UI.CreateIconGrid(parent, opts)
    opts = opts or {}
    local ROW_H   = opts.rowHeight   or ROW_HEIGHT_DEFAULT
    local NAME_WW = opts.nameWidth   or NAME_W
    local COL_WW  = opts.colWidth    or COL_W
    local INIT_VR = opts.initialRows or 12

    local state = {
      cols = {},
      getCount = function() return 0 end,
      getRow   = function() return nil end,
      getMissingCount = nil, -- optional
      handlers = {},
      visibleRows = INIT_VR,
      rows = nil,
    }

    local root = CreateFrame("Frame", nil, parent)
    root:SetAllPoints(parent)

    -- Header
    local header = CreateFrame("Frame", nil, root)
    header:SetHeight(HEADER_H)
    header:SetPoint("TOPLEFT", root, "TOPLEFT", 10, -38)
    header:SetPoint("TOPRIGHT", root, "TOPRIGHT", -10, -38)

    local nameFS = header:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    nameFS:SetPoint("LEFT", header, "LEFT", 8, 0)
    nameFS:SetText("Name")
    header.name = nameFS
    header.cols = {}

    -- Scroll (needs a NAME on Vanilla templates)
    FRT.__ui_id = (FRT.__ui_id or 0) + 1
    local scrollName = "FRT_IconGridScroll"..FRT.__ui_id
    local scroll = CreateFrame("ScrollFrame", scrollName, root, "FauxScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", root, "TOPLEFT", 10, -60)
    scroll:SetPoint("BOTTOMRIGHT", root, "BOTTOMRIGHT", -26, 32)

    -- Child holder for our row frames (not a true scroll child; FauxScrollFrame is virtual)
    local child = CreateFrame("Frame", nil, root)
    child:SetPoint("TOPLEFT", scroll, "TOPLEFT", 0, 0)
    child:SetWidth(1); child:SetHeight(ROW_H * state.visibleRows)

    -- Row pool
    local rows = nil

    local function clearRows()
      if not rows then return end
      local i = 1
      while i <= table.getn(rows) do
        local r = rows[i]
        if r then
          if r.cells then
            local j=1; while j <= table.getn(r.cells) do
              if r.cells[j] then r.cells[j]:Hide() end
              j = j + 1
            end
          end
          r:Hide()
        end
        i = i + 1
      end
    end

    local function ensureRows()
      if rows and table.getn(rows) >= state.visibleRows then return end
      rows = rows or {}
      local start = (table.getn(rows) or 0) + 1
      local i = start
      while i <= state.visibleRows do
        local r = CreateFrame("Frame", nil, child)
        r:SetHeight(ROW_H)
        if i == 1 then
          r:SetPoint("TOPLEFT", child, "TOPLEFT", 0, 0)
          r:SetPoint("TOPRIGHT", child, "TOPRIGHT", 0, 0)
        else
          r:SetPoint("TOPLEFT", rows[i-1], "BOTTOMLEFT", 0, 0)
          r:SetPoint("TOPRIGHT", rows[i-1], "BOTTOMRIGHT", 0, 0)
        end

        local nm = r:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        nm:SetPoint("LEFT", r, "LEFT", 8, 0)
        nm:SetText("Player")
        r.name = nm
        r.cells = {}

        rows[i] = r
        i = i + 1
      end
      state.rows = rows
    end

    local function setRowCells(row, numCols)
      if row.cells then
        local k=1; while k <= table.getn(row.cells) do row.cells[k]:Hide(); k = k + 1 end
      end
      row.cells = {}

      local i=1
      while i <= numCols do
        local f = CreateFrame("Button", nil, row)
        f:SetWidth(COL_WW); f:SetHeight(COL_WW)
        f:SetPoint("LEFT", row, "LEFT", START_X + (i-1)*(COL_WW + 10), 0)
        f:RegisterForClicks()

        local t = f:CreateTexture(nil, "ARTWORK")
        t:SetAllPoints()
        t:SetTexture(TEX_CHECK)
        f.tex = t

        -- Delegate events
        f:SetScript("OnClick", function()
          if state.handlers.OnCellClick and f._key and f._rowIndex then
            state.handlers.OnCellClick(f._rowIndex, f._key, arg1, f)
          end
        end)
        f:SetScript("OnEnter", function()
          if state.handlers.OnCellEnter and f._key and f._rowIndex then
            state.handlers.OnCellEnter(f._rowIndex, f._key, f)
          end
        end)
        f:SetScript("OnLeave", function()
          if state.handlers.OnCellLeave and f._key and f._rowIndex then
            state.handlers.OnCellLeave(f._rowIndex, f._key, f)
          end
        end)

        row.cells[i] = f
        i = i + 1
      end
    end

    local function setHeaderColumns(cols)
      -- clear old
      local i=1
      while i <= table.getn(header.cols) do
        if header.cols[i] then header.cols[i]:Hide() end
        i = i + 1
      end
      header.cols = {}

      -- icons only
      local startX = START_X
      local colW = 22
      i=1
      while i <= table.getn(cols) do
        local h = CreateFrame("Frame", nil, header)
        h:SetWidth(colW); h:SetHeight(18)
        h:SetPoint("LEFT", header, "LEFT", startX + (i-1)*(colW+6), 0)
        local t = h:CreateTexture(nil, "ARTWORK")
        t:SetAllPoints()
        t:SetTexture(cols[i].icon or "Interface\\Icons\\INV_Misc_QuestionMark")
        t:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        h.tex = t
        header.cols[i] = h

        -- tooltip
        local colDef = cols[i]
        h:EnableMouse(true)
        h:SetScript("OnEnter", function()
          if state.handlers.OnHeaderEnter then
            state.handlers.OnHeaderEnter(colDef, h)
          else
            GameTooltip:SetOwner(h, "ANCHOR_BOTTOM")
            GameTooltip:SetText(colDef.label or colDef.key or "Column")
            if state.getMissingCount then
              local miss = state.getMissingCount(colDef.key) or 0
              GameTooltip:AddLine("Missing: "..miss, 1,0.6,0.6)
            end
            GameTooltip:Show()
          end
        end)
        h:SetScript("OnLeave", function()
          if state.handlers.OnHeaderLeave then
            state.handlers.OnHeaderLeave(colDef, h)
          else
            GameTooltip:Hide()
          end
        end)

        i = i + 1
      end
    end

    local function renderRow(rowFrame, rowIndex)
      local cols = state.cols
      local totalCols = table.getn(cols)
      if not rowFrame or not rowIndex then return end

      local rowObj = state.getRow(rowIndex)
      if not rowObj then rowFrame:Hide(); return end
      rowFrame:Show()

      rowFrame.name:SetText(rowObj.labelText or "?")
      local rr,gg,bb = ClassColorRGB(rowObj.class or "")
      rowFrame.name:SetTextColor(rr,gg,bb)

      if not rowFrame.cells or table.getn(rowFrame.cells) ~= totalCols then
        setRowCells(rowFrame, totalCols)
      end

      local i=1
      while i <= totalCols do
        local col = cols[i]
        local cell = rowFrame.cells[i]
        cell._rowIndex = rowIndex
        cell._key = col.key

        local st = rowObj.state and rowObj.state[col.key]
        local clickable = rowObj.clickable and rowObj.clickable[col.key]

        if st == "na" then
          cell.tex:SetTexture(TEX_CHECK); cell.tex:SetVertexColor(0.7, 0.7, 0.7, 0.35)
        elseif st == "present" then
          cell.tex:SetTexture(TEX_CHECK); cell.tex:SetVertexColor(0.2, 1.0, 0.2, 1.0)
        else
          cell.tex:SetTexture(TEX_CROSS); cell.tex:SetVertexColor(1.0, 0.2, 0.2, 1.0)
        end

        cell:EnableMouse(clickable and true or false)
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

    local function refresh()
      if not root:IsShown() then return end
      local total = state.getCount() or 0
      FauxScrollFrame_Update(scroll, total, state.visibleRows, ROW_H)

      ensureRows()
      local offset = FauxScrollFrame_GetOffset(scroll) or 0
      local i=1
      while i <= state.visibleRows do
        local idx = offset + i
        renderRow(rows[i], idx)
        i = i + 1
      end
    end

    scroll:SetScript("OnVerticalScroll", function()
      FauxScrollFrame_OnVerticalScroll(this, arg1, ROW_H, refresh)
    end)

    root:SetScript("OnShow", refresh)
    root:SetScript("OnSizeChanged", function()
      child:SetHeight(ROW_H * state.visibleRows)
      refresh()
    end)

    -- Public object
    local grid = {}

    function grid:SetColumns(cols)
      state.cols = cols or {}
      setHeaderColumns(state.cols)
      -- next paint will rebuild cell buttons per row
      if rows then
        local i=1; while i <= table.getn(rows) do
          rows[i].cells = nil
          i = i + 1
        end
      end
      refresh()
    end

    function grid:SetDataProviders(getCountFn, getRowFn, getMissingCountFn)
      state.getCount = getCountFn or state.getCount
      state.getRow   = getRowFn or state.getRow
      state.getMissingCount = getMissingCountFn
    end

    function grid:SetHandlers(h)
      state.handlers = h or {}
    end

    function grid:SetVisibleRows(n)
      if not n or n < 1 then return end
      if n == state.visibleRows then return end
      -- hide/delete existing rows to avoid ghost overlays
      clearRows()
      rows = nil
      state.visibleRows = n
      child:SetHeight(ROW_H * state.visibleRows)
      ensureRows()
      refresh()
    end

    function grid:RecalcVisibleRows()
      local h = (scroll:GetHeight() or 0)
      local rowsFit = math.floor(h / ROW_H)
      if rowsFit < 4 then rowsFit = 4 end
      if rowsFit > 40 then rowsFit = 40 end
      self:SetVisibleRows(rowsFit)
    end

    function grid:Refresh()
      refresh()
    end

    grid.root   = root
    grid.header = header
    grid.scroll = scroll
    grid.child  = child

    return grid
  end
end

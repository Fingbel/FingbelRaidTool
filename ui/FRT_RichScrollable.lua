-- FRT_Scrollable.lua
FRT = FRT or {}
FRT.Utils = FRT.Utils or {}

function FRT.Utils.CreateRichTextViewer(parent, opts)
  opts = opts or {}
  local DEFAULT_FONT = opts.fontObject or "GameFontNormal"
  local RIGHT_COL_W  = opts.rightColumnWidth or 18
  local INSET_L      = (opts.insets and opts.insets.left)   or 4
  local INSET_R      = (opts.insets and opts.insets.right)  or 4
  local INSET_T      = (opts.insets and opts.insets.top)    or 4
  local INSET_B      = (opts.insets and opts.insets.bottom) or 4
  local SAFE_PAD     = (opts.safePad ~= nil) and opts.safePad or 1
  local ICON_SCALE  = (opts.iconScale ~= nil) and opts.iconScale or 0.85  -- 85% of line height

  local function snapi(v) return math.floor((v or 0) + 0.5) end

  -- Root
  local root = CreateFrame("Frame", nil, parent)
  root:SetAllPoints(parent)

  -- Unique scrollframe name
  FRT.Utils.__scroll_id = (FRT.Utils.__scroll_id or 0) + 1
  local sfName = opts.name or ("FRT_Scroll"..FRT.Utils.__scroll_id)

  -- ScrollFrame
  local scroll = CreateFrame("ScrollFrame", sfName, root, "UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", 0, 0)
  scroll:SetPoint("BOTTOMRIGHT", -RIGHT_COL_W, 0)

  -- 1.12 shim
  if not scroll.UpdateScrollChildRect then
    function scroll:UpdateScrollChildRect()
      local c = self:GetScrollChild(); if not c then return end
      local ch = c:GetHeight() or 0
      local vh = self:GetHeight() or 0
      local max = ch - vh; if max < 0 then max = 0 end
      local name = self:GetName() or ""
      local sb   = getglobal(name.."ScrollBar")
      local up   = getglobal(name.."ScrollBarScrollUpButton")   or getglobal(name.."ScrollUpButton")
      local down = getglobal(name.."ScrollBarScrollDownButton") or getglobal(name.."ScrollDownButton")
      if sb then
        local cur = sb:GetValue() or 0
        sb:SetMinMaxValues(0, max)
        if cur > max then cur = max end
        sb:SetValue(cur)
        if max <= 0 then sb:Hide(); if up then up:Hide() end; if down then down:Hide() end
        else sb:Show(); if up then up:Show() end; if down then down:Show() end end
      end
    end
  end

  -- Child
  local child = CreateFrame("Frame", nil, scroll)
  child:SetWidth(1); child:SetHeight(1)
  scroll:SetScrollChild(child)

  -- Pools
  local fsPool, txPool = {}, {}
  local active = {}

  -- Measurer
  local measure = child:CreateFontString(nil, "ARTWORK", DEFAULT_FONT)
  measure:Hide()

  local function baselineH(fontObject)
    measure:SetFontObject(fontObject or DEFAULT_FONT)
    measure:SetText("Ag")
    local h = measure:GetHeight() or 16
    if h <= 0 then h = 16 end
    return h
  end

  local function widthOf(fontObj, s)
    measure:SetFontObject(fontObj or DEFAULT_FONT)
    measure:SetText(s or "")
    local w = measure:GetStringWidth() or 0
    if w < 0 then w = 0 end
    return math.ceil(w)
  end

  local function clearActive()
    for i = 1, (table.getn(active) or 0) do
      local f = active[i]
      if f then
        f:Hide()
        if f.GetObjectType and f:GetObjectType() == "FontString" then
          table.insert(fsPool, f)
        else
          table.insert(txPool, f)
        end
        active[i] = nil
      end
    end
    active = {}
  end

  local function acquireFS()
    local n = table.getn(fsPool) or 0
    if n > 0 then
      local fs = fsPool[n]; fsPool[n] = nil
      if fs then fs:Show(); return fs end
    end
    local fs = child:CreateFontString(nil, "ARTWORK", DEFAULT_FONT)
    fs:SetJustifyH("LEFT"); fs:SetJustifyV("TOP")
    return fs
  end

  local function acquireTX()
    local n = table.getn(txPool) or 0
    if n > 0 then
      local t = txPool[n]; txPool[n] = nil
      if t then t:Show(); return t end
    end
    return child:CreateTexture(nil, "ARTWORK")
  end

  -- Split into { word, spaces } pairs (words are non-space runs; spaces immediately after)
  local function splitWordSpacePairs(s)
    local out = {}
    local i, n = 1, string.len(s or "")
    while i <= n do
      local a,b, word, spaces = string.find(s, "^([^%s]+)([%s]*)", i)
      if a then
        table.insert(out, { word = word or "", spaces = spaces or "" })
        i = b + 1
      else
        local a2,b2, sp = string.find(s, "^(%s+)", i)
        if a2 then
          table.insert(out, { word = "", spaces = sp or "" })
          i = b2 + 1
        else
          break
        end
      end
    end
    return out
  end

  local function isScrollShown()
    local name = scroll:GetName() or ""
    local sb = getglobal(name.."ScrollBar")
    if not sb then return false end
    local _, max = sb:GetMinMaxValues()
    return (max or 0) > 0
  end

  -- Render (single pass with provided content width)
  local function renderWithContentW(tokens, contentW)
    clearActive()

    local viewW = root:GetWidth() or 0
    if contentW < 1 then contentW = 1 end

    local x = INSET_L
    local y = -INSET_T
    local lineH = 0

    local function newLine(fontObj)
      x = INSET_L
      y = y - (lineH > 0 and lineH or baselineH(fontObj or DEFAULT_FONT))
      lineH = 0
    end

    local count = tokens and table.getn(tokens) or 0
    for i = 1, count do
      local tk = tokens[i]
      local kind = tk and tk.kind

      if kind == "linebreak" then
        newLine(DEFAULT_FONT)

      elseif kind == "icon" then
        -- determine current line reference height (use ongoing lineH or default font)
        local lineRefH = (lineH > 0) and lineH or baselineH(DEFAULT_FONT)

        -- target size: use provided token size if given; otherwise derive from line height
        local w = tonumber(tk.w)
        local h = tonumber(tk.h)
        if not h or h <= 0 then h = math.floor(lineRefH * ICON_SCALE + 0.5) end
        if not w or w <= 0 then w = h end

        -- wrap if needed (respect right pad)
        if x + w > INSET_L + contentW - SAFE_PAD and x > INSET_L then
          newLine(DEFAULT_FONT)
          lineRefH = (lineH > 0) and lineH or baselineH(DEFAULT_FONT)
          if not tk.h then h = math.floor(lineRefH * ICON_SCALE + 0.5) end
          if not tk.w then w = h end
        end

        -- vertical centering within the line box
        local vOff = math.floor(((lineRefH - h) / 2) + 0.5)

        local t = acquireTX()
        t:ClearAllPoints()
        t:SetPoint("TOPLEFT", child, "TOPLEFT", snapi(x), y - vOff)
        t:SetWidth(w); t:SetHeight(h)
        if tk.tex then t:SetTexture(tk.tex) end
        if tk.tc and tk.tc[1] then t:SetTexCoord(tk.tc[1], tk.tc[2], tk.tc[3], tk.tc[4]) else t:SetTexCoord(0,1,0,1) end
        t:SetVertexColor(1,1,1,1)
        table.insert(active, t)

        x = snapi(x + w)
        if h > lineH then lineH = h end

      elseif kind == "text" then
        local fontObj = tk.font or DEFAULT_FONT
        local color   = tk.color
        local pairs   = splitWordSpacePairs(tk.value or "")

        local run, runW = "", 0
        local function flushRun()
          if run == "" then return end
          local fs = acquireFS()
          fs:SetFontObject(fontObj)
          fs:ClearAllPoints()
          fs:SetPoint("TOPLEFT", child, "TOPLEFT", snapi(x), y)
          fs:SetText(run)
          if color and color[1] then fs:SetTextColor(color[1], color[2], color[3]) else fs:SetTextColor(1,1,1) end
          table.insert(active, fs)
          x = snapi(x + runW)
          local lh = baselineH(fontObj)
          if lh > lineH then lineH = lh end
          run, runW = "", 0
        end

        local jmax = table.getn(pairs)
        for j = 1, jmax do
          local piece = (pairs[j].word or "") .. (pairs[j].spaces or "")
          local candW = widthOf(fontObj, run .. piece)
          local maxW  = (INSET_L + contentW) - snapi(x) - SAFE_PAD

          if candW > maxW and run ~= "" then
            -- wrap BEFORE this piece (never split)
            flushRun()
            newLine(fontObj)
            maxW = contentW - SAFE_PAD

            -- Long word that doesn't fit even on empty line? Place as-is (overflow) and continue on next line
            local pieceW = widthOf(fontObj, piece)
            if pieceW > maxW and (pairs[j].word or "") ~= "" and (pairs[j].spaces or "") == "" then
              run = piece; runW = pieceW
              flushRun()
              newLine(fontObj)
            else
              run = piece; runW = pieceW
            end
          else
            run  = run .. piece
            runW = candW
          end
        end

        flushRun()
        if x >= INSET_L + contentW - SAFE_PAD then
          newLine(fontObj)
        end
      end
    end

    if lineH == 0 then lineH = baselineH(DEFAULT_FONT) end
    local totalH = (INSET_T + INSET_B) + (-y + lineH); if totalH < 1 then totalH = 1 end
    child:SetWidth(viewW)
    child:SetHeight(totalH)
    scroll:UpdateScrollChildRect()
  end

  -- Top-level render that adapts to actual scrollbar visibility
  local function renderTokens(tokens)
    local assumeScroll = isScrollShown()
    local viewW = root:GetWidth() or 0
    local contentW = viewW - (assumeScroll and RIGHT_COL_W or 0) - INSET_L - INSET_R
    renderWithContentW(tokens, contentW)

    local nowScroll = isScrollShown()
    if nowScroll ~= assumeScroll then
      local contentW2 = viewW - (nowScroll and RIGHT_COL_W or 0) - INSET_L - INSET_R
      renderWithContentW(tokens, contentW2)
    end
  end

  -- API
  local currentTokens, lastRawText = nil, ""

  local function SetTokens(tokens)
    currentTokens = tokens
    renderTokens(tokens)
  end

  local function SetText(s)
    lastRawText = s or ""
    SetTokens({ { kind="text", value=lastRawText, font=DEFAULT_FONT } })
  end

  local function GetText()
    return lastRawText or ""
  end

  local function Refresh()
    if currentTokens then
      renderTokens(currentTokens)
    else
      renderTokens({ { kind="text", value=lastRawText or "", font=DEFAULT_FONT } })
    end
  end

  -- 1.12 wheel uses arg1
  scroll:EnableMouseWheel(true)
  scroll:SetScript("OnMouseWheel", function()
    local name = scroll:GetName() or ""
    local sb = getglobal(name.."ScrollBar"); if not sb then return end
    local delta = arg1 or 0
    sb:SetValue((sb:GetValue() or 0) - delta * 20)
  end)

  root:SetScript("OnSizeChanged", Refresh)
  root:SetScript("OnShow", Refresh)

  return {
    root      = root,
    scroll    = scroll,
    child     = child,
    SetTokens = SetTokens,
    SetText   = SetText,
    GetText   = GetText,
    Refresh   = Refresh,
  }
end

-- FRT_Utils.lua
FRT = FRT or {}
FRT.Utils = FRT.Utils or {}


function FRT.Utils.CreateScrollableEdit(parent, opts)
  opts = opts or {}
  local RIGHT_COL_W   = opts.rightColumnWidth or 0
  local MIN_H         = opts.minHeight       or 200
  local INSET_L       = (opts.insets and opts.insets.left)   or 4
  local INSET_R       = (opts.insets and opts.insets.right)  or 4
  local INSET_T       = (opts.insets and opts.insets.top)    or 4
  local INSET_B       = (opts.insets and opts.insets.bottom) or 4
  local FONT_OBJECT   = opts.fontObject or "ChatFontNormal"
  local BACKGROUND    = opts.background or nil
  local BORDER        = opts.border or nil
  local READONLY      = opts.readonly or false

  -- Root container
  local root = CreateFrame("Frame", nil, parent)
  root:SetAllPoints(parent)

  -- Backdrop under the scrollframe (optional)
  local box = nil
  if BACKGROUND or BORDER then
    box = CreateFrame("Frame", nil, root)
    box:SetPoint("TOPLEFT", root, "TOPLEFT", 0, 0)
    box:SetPoint("BOTTOMRIGHT", root, "BOTTOMRIGHT", 0, 0)
    box:SetBackdrop({
      bgFile   = BACKGROUND,
      edgeFile = BORDER,
      tile     = true, tileSize = 16, edgeSize = 12,
      insets   = { left = 3, right = 3, top = 3, bottom = 3 }
    })
    box:SetBackdropColor(0, 0, 0, 0.5)
    box:EnableMouse(false)
    box:SetFrameLevel((root:GetFrameLevel() or 0) - 1)
  end

  -- Generate a unique name for the scrollframe (template requires a name)
  FRT.Utils.__scroll_id = (FRT.Utils.__scroll_id or 0) + 1
  local sfName = opts.name or ("FRT_ScrollEdit"..FRT.Utils.__scroll_id)

  -- Scroll frame (with Blizzard scrollbar)
  local scroll = CreateFrame("ScrollFrame", sfName, root, "UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", 0, 0)
  scroll:SetPoint("BOTTOMRIGHT", -RIGHT_COL_W, 0)
  scroll:EnableMouse(true)       -- so wheel works even if child ignores mouse
  scroll:EnableMouseWheel(true)
  
  -- Scroll child frame
  local child = CreateFrame("Frame", nil, scroll)
  local function innerWidth()
    local w = (root:GetWidth() or 0) + 4 --manual adjusting
    if w < 1 then w = 1 end
    return w
  end
  child:SetWidth(innerWidth())
  child:SetHeight(MIN_H)
  scroll:SetScrollChild(child)

  local function UpdateScrollButtonsVisibility()
    local name = scroll:GetName() or ""
    local sb   = getglobal(name .. "ScrollBar"); if not sb then return end
    local up   = getglobal(name .. "ScrollBarScrollUpButton")   or getglobal(name .. "ScrollUpButton")
    local down = getglobal(name .. "ScrollBarScrollDownButton") or getglobal(name .. "ScrollDownButton")

    local _, max = sb:GetMinMaxValues()
    if (max or 0) <= 0 then
      sb:Hide(); if up then up:Hide() end; if down then down:Hide() end
    else
      sb:Show(); if up then up:Show() end; if down then down:Show() end
    end
  end
  -- 1.12 compat: shim UpdateScrollChildRect on this scrollframe
  if not scroll.UpdateScrollChildRect then
    function scroll:UpdateScrollChildRect()
      local c = self:GetScrollChild(); if not c then return end
      local contentH = c:GetHeight() or 0
      local viewH    = self:GetHeight() or 0
      local max      = contentH - viewH
      if max < 0 then max = 0 end

      local name  = self:GetName() or ""
      local sb    = getglobal(name .. "ScrollBar")
      local up    = getglobal(name .. "ScrollBarScrollUpButton")   or getglobal(name .. "ScrollUpButton")
      local down  = getglobal(name .. "ScrollBarScrollDownButton") or getglobal(name .. "ScrollDownButton")

      if sb then
        local cur = sb:GetValue() or 0
        sb:SetMinMaxValues(0, max)
        if cur > max then cur = max end
        sb:SetValue(cur)

        if max <= 0 then
          sb:Hide(); if up then up:Hide() end; if down then down:Hide() end
        else
          sb:Show(); if up then up:Show() end; if down then down:Show() end
        end
      end
    end
  end

  -- Text widget: FontString for readonly (non-selectable), EditBox for editable
  local edit, text
  if READONLY then
    text = child:CreateFontString(nil, "ARTWORK", FONT_OBJECT)
    text:SetPoint("TOPLEFT", INSET_L, -INSET_T)
    text:SetJustifyH("LEFT")
    text:SetJustifyV("TOP")
    text:SetNonSpaceWrap(true)
    text:SetText("")
  else
    edit = CreateFrame("EditBox", nil, child)
    edit:SetMultiLine(true)
    edit:SetAutoFocus(false)
    edit:SetFontObject(FONT_OBJECT)
    edit:SetTextInsets(INSET_L, INSET_R, INSET_T, INSET_B)
    edit:SetJustifyH("LEFT")
    edit:SetJustifyV("TOP")
    edit:EnableMouse(true)
    edit:SetAllPoints(child)
    edit:SetScript("OnEscapePressed", function() edit:ClearFocus() end)
    edit:SetScript("OnEnterPressed",  function() edit:Insert("\n") end)
    edit:SetScript("OnMouseDown",     function() edit:SetFocus() end)
    -- Keep caret visible (editable only)
    edit:SetScript("OnCursorChanged", function(self, x, y, w, h)
      if not y or not h then scroll:UpdateScrollChildRect(); return end
      local cursorTop = -y
      local viewTop   = scroll:GetVerticalScroll() or 0
      local viewH     = scroll:GetHeight() or 0
      if cursorTop + h > viewTop + viewH then
        scroll:SetVerticalScroll(cursorTop + h - viewH)
      elseif cursorTop < viewTop then
        scroll:SetVerticalScroll(cursorTop)
      end
    end)
  end

  -- Hidden measurer (wrapped height via width), uses same font
  local measure = child:CreateFontString(nil, "ARTWORK", FONT_OBJECT)
  measure:Hide()
  measure:SetNonSpaceWrap(false)
  measure:SetJustifyH("LEFT")
  measure:SetJustifyV("TOP")

  local function lineHeight()
    measure:SetWidth(1000)  -- no wrap
    measure:SetText("Ag")
    local h = tonumber(measure:GetHeight()) or 16
    if h <= 0 then h = 16 end
    return h
  end
  local function stringPixelWidth(s)
    measure:SetText(s or "")
    return tonumber(measure:GetStringWidth()) or 0
  end

  local function getText()
    if READONLY then
      return text:GetText() or ""
    else
      return edit:GetText() or ""
    end
  end

  local function computeWrappedHeight()
    local w = innerWidth() - (INSET_L + INSET_R)
    if w < 1 then w = 1 end

    measure:SetText("W")
    local avgW = tonumber(measure:GetStringWidth()) or 8
    if avgW <= 0 then avgW = 8 end

    local lh   = lineHeight()
    local s    = getText()
    local rows = 0
    local pos  = 1

    while true do
      local a, b = string.find(s, "\n", pos, true)
      local line
      if a then line = string.sub(s, pos, a - 1); pos = b + 1
      else      line = string.sub(s, pos);         pos = nil end

      if line == "" or line == nil then
        rows = rows + 1
      else
        measure:SetText(line)
        local px = tonumber(measure:GetStringWidth()) or 0
        if px == 0 then px = string.len(line) * avgW end
        local r = math.ceil(px / w); if r < 1 then r = 1 end
        rows = rows + r
      end

      if not pos then break end
    end

    if rows < 1 then rows = 1 end
    local h = rows * lh + INSET_T + INSET_B
    if h < MIN_H then h = MIN_H end
    return h
  end

  -- Refresh sizing + scrollbar range
  local function Refresh()
    child:SetWidth(innerWidth())
    -- Update text/edit width so wrapping is computed against inner width
    if READONLY then
      text:SetWidth(innerWidth() - (INSET_L + INSET_R))
    end
    child:SetHeight(computeWrappedHeight())
    scroll:UpdateScrollChildRect()
    UpdateScrollButtonsVisibility()
  end

  -- Mouse wheel → adjust scrollbar
  scroll:SetScript("OnMouseWheel", function()
    local sb = getglobal(scroll:GetName() .. "ScrollBar"); if not sb then return end
    local delta = arg1 or 0
    sb:SetValue((sb:GetValue() or 0) - delta * 20)
  end)

  -- Text / size updates
  if READONLY then
    -- Make absolutely sure it can't be focused/selected
    -- (FontString can't anyway, but keep scroll responsive)
    -- Nothing needed here.
  else
    edit:SetScript("OnTextChanged", Refresh)
  end
  root:SetScript("OnSizeChanged", Refresh)
  root:SetScript("OnShow", function() Refresh() end)
  UpdateScrollButtonsVisibility()

  -- Public API
  local function SetText(s)
    s = s or ""
    if READONLY then
      text:SetText(s)
    else
      edit:SetText(s)
    end
    Refresh()
  end

  local function GetText()
    return getText()
  end

  -- Return both for convenience; in readonly, .edit == .text (safe SetText/GetText)
  return {
    root     = root,
    backdrop = box,
    scroll   = scroll,
    child    = child,
    edit     = READONLY and text or edit,
    text     = READONLY and text or edit, -- alias, so callers can use .text
    Refresh  = Refresh,
    SetText  = SetText,
    GetText  = GetText,
  }
end

function FRT.Utils.CreateScrollable(parent, opts)
  opts = opts or {}
  local DEFAULT_FONT = opts.fontObject or "GameFontNormal"
  local RIGHT_COL_W  = opts.rightColumnWidth or 18
  local INSET_L      = (opts.insets and opts.insets.left)   or 4
  local INSET_R      = (opts.insets and opts.insets.right)  or 4
  local INSET_T      = (opts.insets and opts.insets.top)    or 4
  local INSET_B      = (opts.insets and opts.insets.bottom) or 4
  local SAFE_PAD     = (opts.safePad ~= nil) and opts.safePad or 1

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
        local w = tonumber(tk.w) or 12
        local h = tonumber(tk.h) or 12
        if x + w > INSET_L + contentW - SAFE_PAD and x > INSET_L then
          newLine(DEFAULT_FONT)
        end
        local t = acquireTX()
        t:ClearAllPoints()
        t:SetPoint("TOPLEFT", child, "TOPLEFT", snapi(x), y)
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

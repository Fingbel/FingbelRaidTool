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

-- FRT_Utils.lua
FRT = FRT or {}
FRT.Utils = FRT.Utils or {}

-- Create a 1.12-safe scrollable EditBox inside `parent`.
-- opts:
--   name (optional): base name for the ScrollFrame (required by UIPanelScrollFrameTemplate)
--   rightColumnWidth, scrollbarWidth, padding, minHeight
--   insets = {left,right,top,bottom}, topPadOverlay, fontObject
-- Returns {root, scroll, child, edit, Refresh, SetText, GetText}
function FRT.Utils.CreateScrollableEdit(parent, opts)
  opts = opts or {}
  local RIGHT_COL_W   = opts.rightColumnWidth or 0
  local SCROLLBAR_W   = opts.scrollbarWidth  or 20
  local PADDING       = opts.padding         or 4
  local MIN_H         = opts.minHeight       or 200
  local INSET_L       = (opts.insets and opts.insets.left)   or 4
  local INSET_R       = (opts.insets and opts.insets.right)  or 4
  local INSET_T       = (opts.insets and opts.insets.top)    or 4
  local INSET_B       = (opts.insets and opts.insets.bottom) or 4
  local TOP_PAD       = opts.topPadOverlay or 0
  local FONT_OBJECT   = opts.fontObject or "ChatFontNormal"

  -- Root container
  local root = CreateFrame("Frame", nil, parent)
  root:SetAllPoints(parent)

  -- Generate a unique name for the scrollframe (template requires a name)
  FRT.Utils.__scroll_id = (FRT.Utils.__scroll_id or 0) + 1
  local sfName = opts.name or ("FRT_ScrollEdit"..FRT.Utils.__scroll_id)

  -- Scroll frame (with Blizzard scrollbar)
  local scroll = CreateFrame("ScrollFrame", sfName, root, "UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", 0, 0)
  scroll:SetPoint("BOTTOMRIGHT", -RIGHT_COL_W, 0)
  scroll:EnableMouse(false)
  scroll:EnableMouseWheel(true)

  -- Optional top padding overlay for visual gap when scrolled
  if TOP_PAD and TOP_PAD > 0 then
    local topPad = CreateFrame("Frame", nil, root)
    topPad:SetPoint("TOPLEFT", scroll, "TOPLEFT", 0, 0)
    topPad:SetPoint("TOPRIGHT", scroll, "TOPRIGHT", 0, 0)
    topPad:SetHeight(TOP_PAD)
    topPad:SetFrameLevel((scroll:GetFrameLevel() or 0) + 5)
    topPad:EnableMouse(false)
    local tex = topPad:CreateTexture(nil, "OVERLAY")
    tex:SetAllPoints(true)
    tex:SetTexture("Interface\\ChatFrame\\ChatFrameBackground")
    tex:SetVertexColor(0, 0, 0, 0.5)
  end

  -- Scroll child
  local child = CreateFrame("Frame", nil, scroll)
  local function innerWidth()
    local w = (root:GetWidth() or 0) - RIGHT_COL_W - SCROLLBAR_W - PADDING*2
    if w < 1 then w = 1 end
    return w
  end
  child:SetWidth(innerWidth())
  child:SetHeight(MIN_H)
  scroll:SetScrollChild(child)

  -- EditBox
  local edit = CreateFrame("EditBox", nil, child)
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

  -- 1.12 compat: shim UpdateScrollChildRect on this scrollframe
  if not scroll.UpdateScrollChildRect then
    function scroll:UpdateScrollChildRect()
      local c = self:GetScrollChild(); if not c then return end
      local contentH = c:GetHeight() or 0
      local viewH    = self:GetHeight() or 0
      local max      = contentH - viewH
      if max < 0 then max = 0 end
      local sb = getglobal(self:GetName() .. "ScrollBar")
      if sb then
        local cur = sb:GetValue() or 0
        sb:SetMinMaxValues(0, max)
        if cur > max then cur = max end
        sb:SetValue(cur)
      end
    end
  end

  -- Hidden measurer (wrapped height by width)
  local measure = child:CreateFontString(nil, "ARTWORK", FONT_OBJECT)
  measure:Hide()
  measure:SetNonSpaceWrap(false)
  measure:SetJustifyH("LEFT")
  measure:SetJustifyV("TOP")

  local function lineHeight()
    measure:SetWidth(1000)
    measure:SetText("Ag")
    local h = tonumber(measure:GetHeight()) or 16
    if h <= 0 then h = 16 end
    return h
  end
  local function stringPixelWidth(s)
    measure:SetText(s or "")
    return tonumber(measure:GetStringWidth()) or 0
  end

  local function computeWrappedHeight()
    local w = innerWidth() - (INSET_L + INSET_R)
    if w < 1 then w = 1 end

    measure:SetText("W")
    local avgW = tonumber(measure:GetStringWidth()) or 8
    if avgW <= 0 then avgW = 8 end

    local lh   = lineHeight()
    local text = edit:GetText() or ""
    local rows = 0
    local pos  = 1

    while true do
      local s, e = string.find(text, "\n", pos, true)
      local line
      if s then line = string.sub(text, pos, s - 1); pos = e + 1
      else      line = string.sub(text, pos);         pos = nil end

      if line == "" or line == nil then
        rows = rows + 1
      else
        local px = stringPixelWidth(line)
        if px == 0 then px = string.len(line) * avgW end
        local r = math.ceil(px / w); if r < 1 then r = 1 end
        rows = rows + r
      end

      if not pos then break end
    end

    if rows < 1 then rows = 1 end
    local h = rows * lh + 12
    if h < MIN_H then h = MIN_H end
    return h
  end

  -- Refresh sizing + scrollbar range
  local function Refresh()
    child:SetWidth(innerWidth())
    child:SetHeight(computeWrappedHeight())
    scroll:UpdateScrollChildRect()
  end

  -- Wheel scroll → adjust scrollbar (template provides it)
  scroll:SetScript("OnMouseWheel", function()
    local sb = getglobal(scroll:GetName() .. "ScrollBar"); if not sb then return end
    local delta = arg1 or 0
    sb:SetValue((sb:GetValue() or 0) - delta * 20)
  end)

  -- Keep caret visible
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

  -- Text / size updates
  edit:SetScript("OnTextChanged", Refresh)
  root:SetScript("OnSizeChanged", Refresh)
  root:SetScript("OnShow", function() Refresh() end)

  -- Public API
  local function SetText(s) edit:SetText(s or "") end
  local function GetText() return edit:GetText() end

  return {
    root   = root,
    scroll = scroll,
    child  = child,
    edit   = edit,
    Refresh = Refresh,
    SetText = SetText,
    GetText = GetText,
  }
end

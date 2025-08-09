FRT = FRT or {}
FRT.Note = FRT.Note or {}
local Note = FRT.Note

-- ===============================
-- Main pane builder
-- ===============================
function Note.BuildNoteEditorPane(parent)
  -- Title
  local title = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  title:SetPoint("TOPLEFT", 0, 0)
  title:SetText("Raid Note — Editor")

  -- Layout constants
  local SCROLLBAR_W = 20
  local PADDING     = 4
  local MIN_H       = 200
  local RIGHT_COL_W = 120
  local INSET_L, INSET_R = 4, 4  -- must match edit:SetTextInsets

  -- Scroll area + background
  local scroll = CreateFrame("ScrollFrame", "FRT_NoteEditorScroll", parent, "UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", 0, -24)
  scroll:SetPoint("BOTTOMRIGHT", -RIGHT_COL_W, 36)
  scroll:EnableMouse(false)        -- let clicks go to the edit box
  scroll:EnableMouseWheel(true)

  local editBG = CreateFrame("Frame", nil, parent)
  editBG:SetPoint("TOPLEFT", 0, -24)
  editBG:SetPoint("BOTTOMRIGHT", -RIGHT_COL_W, 36)
  editBG:SetBackdrop({
    bgFile   = "Interface\\ChatFrame\\ChatFrameBackground",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile     = true, tileSize = 16, edgeSize = 12,
    insets   = { left = 3, right = 3, top = 3, bottom = 3 }
  })
  editBG:SetBackdropColor(0,0,0,0.5)
  editBG:EnableMouse(false)
  editBG:SetFrameLevel(parent:GetFrameLevel() - 1)

  -- Dedicated scroll child container
  local child = CreateFrame("Frame", nil, scroll)
  child:SetWidth((parent:GetWidth() - RIGHT_COL_W) - SCROLLBAR_W - PADDING*2)
  child:SetHeight(MIN_H)
  scroll:SetScrollChild(child)

  -- Edit box inside the child, fill it
  local edit = CreateFrame("EditBox", "FRT_NoteEditorEditBox", child)
  edit:SetMultiLine(true)
  edit:SetAutoFocus(false)
  edit:SetFontObject("ChatFontNormal")
  edit:SetTextInsets(INSET_L, INSET_R, 4, 4)
  edit:SetJustifyH("LEFT")
  edit:SetJustifyV("TOP")
  edit:EnableMouse(true)
  edit:SetAllPoints(child)  -- fill child to avoid click dead-zones

  edit:SetScript("OnEscapePressed", function() edit:ClearFocus() end)
  edit:SetScript("OnEnterPressed",  function() edit:Insert("\n") end)
  edit:SetScript("OnMouseDown",     function() edit:SetFocus() end)

  -- 1.12 compat: ScrollFrame:UpdateScrollChildRect() doesn't exist -> shim it
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

  -- Hidden measurer (for wrapped height; 1.12-safe)
  local measure = child:CreateFontString(nil, "ARTWORK", "ChatFontNormal")
  measure:Hide()
  measure:SetNonSpaceWrap(false) -- we'll compute wraps by width, not rely on FS wrapping
  measure:SetJustifyH("LEFT"); measure:SetJustifyV("TOP")

  local function innerWidth()
    local w = (parent:GetWidth() - RIGHT_COL_W) - SCROLLBAR_W - PADDING*2
    if w < 1 then w = 1 end
    return w
  end

  local function lineHeight()
    measure:SetWidth(1000) -- ensure no wrap
    measure:SetText("Ag")
    local h = tonumber(measure:GetHeight()) or 16
    if h <= 0 then h = 16 end
    return h
  end

  local function stringPixelWidth(s)
    measure:SetText(s or "")
    return tonumber(measure:GetStringWidth()) or 0
  end

  -- Compute true content height (counts soft-wrapped rows)
  local function ComputeWrappedHeight()
    local innerW = innerWidth() - (INSET_L + INSET_R)
    if innerW < 1 then innerW = 1 end

    -- fallback average glyph width for super-long no-metric strings
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
        local r = math.ceil(px / innerW); if r < 1 then r = 1 end
        rows = rows + r
      end

      if not pos then break end
    end

    if rows < 1 then rows = 1 end
    local h = rows * lh + 12
    if h < MIN_H then h = MIN_H end
    return h
  end

  -- Recompute sizes + scroll rect
  local function Refresh()
    -- width affects wrapping/height; update child width first
    child:SetWidth(innerWidth())

    -- measure real wrapped height
    local h = ComputeWrappedHeight()
    child:SetHeight(h)

    -- tell scrollbar its range
    scroll:UpdateScrollChildRect()
  end

  edit:SetScript("OnTextChanged", Refresh)

  -- Auto-scroll caret into view (guard nils on 1.12)
  edit:SetScript("OnCursorChanged", function(self, x, y, w, h)
    if not y or not h then
      scroll:UpdateScrollChildRect()
      return
    end
    local cursorTop = -y
    local viewTop   = scroll:GetVerticalScroll() or 0
    local viewH     = scroll:GetHeight() or 0

    if cursorTop + h > viewTop + viewH then
      scroll:SetVerticalScroll(cursorTop + h - viewH)
    elseif cursorTop < viewTop then
      scroll:SetVerticalScroll(cursorTop)
    end
  end)

  scroll:SetScript("OnMouseWheel", function()
    local sb = getglobal(scroll:GetName() .. "ScrollBar")
    if not sb then return end
    local step  = 20
    local delta = arg1 or 0
    sb:SetValue(sb:GetValue() - delta * step)
  end)

  -- Resize behavior inside host pane
  parent:SetScript("OnSizeChanged", function()
    Refresh()
  end)

  parent:SetScript("OnShow", function()
    edit:SetText(tostring(FRT_Saved.note or ""))
    Refresh()
  end)

  -- Buttons (right column)
  local save = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
  save:SetWidth(96); save:SetHeight(22)
  save:SetPoint("TOPRIGHT", 0, -24)
  save:SetText("Save")
  save:SetScript("OnClick", function()
    if not FRT.IsLeaderOrOfficer() then
      FRT.Print("Editor requires raid lead or assist.")
      return
    end
    FRT_Saved.note = edit:GetText() or ""
    FRT.Print("Saved note.")
    Note.UpdateViewerText(Note)
  end)

  local share = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
  share:SetWidth(96); share:SetHeight(22)
  share:SetPoint("TOPRIGHT", 0, -50)
  share:SetText("Share")
  share:SetScript("OnClick", function()
    local text = edit:GetText() or ""
    if text == "" then FRT.Print("Nothing to share."); return end
    if (GetNumRaidMembers() or 0) > 0 then
      FRT.SendAddon("RAID", text);  FRT.Print("Shared to RAID.")
    elseif (GetNumPartyMembers() or 0) > 0 then
      FRT.SendAddon("PARTY", text); FRT.Print("Shared to PARTY.")
    else
      FRT.Print("You are not in a group.")
    end
  end)

  local openViewer = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
  openViewer:SetWidth(96); openViewer:SetHeight(22)
  openViewer:SetPoint("TOPRIGHT", 0, -76)
  openViewer:SetText("Open Viewer")
  openViewer:SetScript("OnClick", function()
    Note.ShowViewer(Note)
  end)
end

-- Exposed helper so /frt editor routes to the global host
function Note.ShowEditor(mod)
  if not FRT.IsLeaderOrOfficer() then FRT.Print("Editor requires raid lead or assist."); return end
  if FRT and FRT.Editor and FRT.Editor.Show then
    FRT.Editor.Show("Note")
  else
    FRT.Print("Global editor not available.")
  end
end

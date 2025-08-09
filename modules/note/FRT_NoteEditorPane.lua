FRT = FRT or {}
FRT.Note = FRT.Note or {}
local Note = FRT.Note

function Note.BuildNoteEditorPane(parent)
  -- Title
  local title = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  title:SetPoint("TOPLEFT", 0, 0)
  title:SetText("Raid Note — Editor")

  -- =========================
  -- Toolbar (raid markers)
  -- =========================
  local toolbar = CreateFrame("Frame", "FRT_NoteToolbar", parent)
  toolbar:SetHeight(24)
  toolbar:SetPoint("TOPLEFT", 0, -18)
  toolbar:SetPoint("TOPRIGHT", -120, -18) -- stop before right-side button column

  -- Atlas coords for UI-RaidTargetingIcons (4x2 grid)
  local ICON_COORDS = {
    [1] = {0.00, 0.25, 0.00, 0.25}, -- star
    [2] = {0.25, 0.50, 0.00, 0.25}, -- circle
    [3] = {0.50, 0.75, 0.00, 0.25}, -- diamond
    [4] = {0.75, 1.00, 0.00, 0.25}, -- triangle
    [5] = {0.00, 0.25, 0.25, 0.50}, -- moon
    [6] = {0.25, 0.50, 0.25, 0.50}, -- square
    [7] = {0.50, 0.75, 0.25, 0.50}, -- cross
    [8] = {0.75, 1.00, 0.25, 0.50}, -- skull
  }

  local function MakeMarkerButton(parentFrame, index, anchor, xoff)
    local b = CreateFrame("Button", nil, parentFrame)
    b:SetWidth(22); b:SetHeight(22)
    if anchor then
      b:SetPoint("LEFT", anchor, "RIGHT", xoff or 2, 0)
    else
      b:SetPoint("LEFT", 0, 0)
    end
    local tex = b:CreateTexture(nil, "ARTWORK")
    tex:SetAllPoints(b)
    tex:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcons")
    local c = ICON_COORDS[index]
    if c then tex:SetTexCoord(c[1], c[2], c[3], c[4]) end
    b.tex = tex

    b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")

    b:SetScript("OnEnter", function()
      if not GameTooltip or not b:IsVisible() then return end
      GameTooltip:SetOwner(b, "ANCHOR_TOP")
      GameTooltip:ClearLines()
      GameTooltip:AddLine("Insert Raid Marker", 1, 1, 1)
      GameTooltip:AddLine(string.format("{rt%d}", index), 0.9, 0.9, 0.9)
      GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)

    b._rtIndex = index
    return b
  end

  -- create and keep references to 8 buttons
  local buttons = {}
  local last
  for i = 1, 8 do
    last = MakeMarkerButton(toolbar, i, last, 2)
    buttons[i] = last
  end

  -- Editor region (left side) – moved down below toolbar
  local editorArea = CreateFrame("Frame", nil, parent)
  editorArea:SetPoint("TOPLEFT", 0, -24 - 24) -- title line (24) + toolbar (24)
  editorArea:SetPoint("BOTTOMRIGHT", -120, 36)

  -- Build the scrollable editor via util (give it a name to be safe)
  local ed = FRT.Utils.CreateScrollableEdit(editorArea, {
    name             = "FRT_NoteEditorScroll", -- important for template!
    rightColumnWidth = 20,      -- keep scrollbar aligned with viewer
    padding          = 4,
    minHeight        = 200,
    insets           = { left=4, right=4, top=4, bottom=4 },
    fontObject       = "ChatFontNormal",
    background       = "Interface\\ChatFrame\\ChatFrameBackground",
    border           = "Interface\\Tooltips\\UI-Tooltip-Border",
    readonly         = false,
  })

  -- Wire toolbar clicks to insert at caret
  -- Wire toolbar clicks to insert at caret
local function InsertMarker(rtIndex)
  if not ed or not ed.edit or not ed.edit.Insert then return end
  ed.edit:SetFocus()
  ed.edit:Insert(string.format("{rt%d}", rtIndex))
  if ed.Refresh then ed.Refresh() end
end

for i = 1, 8 do
  local b = buttons[i]
  if b then
    b:SetScript("OnClick", function()
      InsertMarker((this and this._rtIndex) or i)
    end)
  end
end

  -- Load existing text
  ed.SetText(tostring(FRT_Saved and FRT_Saved.note or ""))

  -- Right column buttons
  local save = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
  save:SetWidth(96); save:SetHeight(22)
  save:SetPoint("TOPRIGHT", 0, -24)
  save:SetText("Save")
  save:SetScript("OnClick", function()
    if not FRT.IsLeaderOrOfficer() then FRT.Print("Editor requires raid lead or assist."); return end
    FRT_Saved.note = ed.GetText()
    FRT.Print("Saved note.")
    Note.UpdateViewerText(Note)
  end)

  local share = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
  share:SetWidth(96); share:SetHeight(22)
  share:SetPoint("TOPRIGHT", 0, -50)
  share:SetText("Share")
  share:SetScript("OnClick", function()
    local text = ed.GetText()
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

function Note.ShowEditor(mod)
  if not FRT.IsLeaderOrOfficer() then FRT.Print("Editor requires raid lead or assist."); return end
  if FRT and FRT.Editor and FRT.Editor.Show then
    FRT.Editor.Show("Note")
  else
    FRT.Print("Global editor not available.")
  end
end

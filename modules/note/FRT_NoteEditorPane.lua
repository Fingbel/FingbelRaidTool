FRT = FRT or {}
FRT.Note = FRT.Note or {}
local Note = FRT.Note

function Note.BuildNoteEditorPane(parent)
  -- Title
  local title = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  title:SetPoint("TOPLEFT", 0, 0)
  title:SetText("Raid Note — Editor")

  -- Toolbar (raid markers)
  local toolbar = CreateFrame("Frame", "FRT_NoteToolbar", parent)
  toolbar:SetHeight(24)
  toolbar:SetPoint("TOPLEFT", 0, -18)
  toolbar:SetPoint("TOPRIGHT", -120, -18)

  local ICON_COORDS = {
    [1]={0.00,0.25,0.00,0.25}, [2]={0.25,0.50,0.00,0.25},
    [3]={0.50,0.75,0.00,0.25}, [4]={0.75,1.00,0.00,0.25},
    [5]={0.00,0.25,0.25,0.50}, [6]={0.25,0.50,0.25,0.50},
    [7]={0.50,0.75,0.25,0.50}, [8]={0.75,1.00,0.25,0.50},
  }
  local function MakeMarkerButton(parentFrame, index, anchor, xoff)
    local b = CreateFrame("Button", nil, parentFrame)
    b:SetWidth(22); b:SetHeight(22)
    if anchor then b:SetPoint("LEFT", anchor, "RIGHT", xoff or 2, 0) else b:SetPoint("LEFT", 0, 0) end
    local tex = b:CreateTexture(nil, "ARTWORK"); tex:SetAllPoints(b)
    tex:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcons")
    local c = ICON_COORDS[index]; if c then tex:SetTexCoord(c[1],c[2],c[3],c[4]) end
    b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    b._rtIndex = index
    return b
  end
  local buttons, last = {}, nil
  for i=1,8 do last = MakeMarkerButton(toolbar, i, last, 2); buttons[i]=last end

  -- Editor area
  local editorArea = CreateFrame("Frame", nil, parent)
  editorArea:SetPoint("TOPLEFT", 0, -48)
  editorArea:SetPoint("BOTTOMRIGHT", -120, 36)

  local ed = FRT.Utils.CreateScrollableEdit(editorArea, {
    name             = "FRT_NoteEditorScroll",
    rightColumnWidth = 20,
    padding          = 4,
    minHeight        = 200,
    insets           = { left=4, right=4, top=4, bottom=4 },
    fontObject       = "ChatFontNormal",
    background       = "Interface\\ChatFrame\\ChatFrameBackground",
    border           = "Interface\\Tooltips\\UI-Tooltip-Border",
    readonly         = false,
  })

  -- ===== Live preview: show viewer (floating) + update as you type =====
  local function EnsureViewerVisible()
    if Note.EnsureViewer then Note.EnsureViewer() end
    if Note.ShowViewer then Note.ShowViewer() end
  end
  local function UpdatePreviewFromEditor()
    local raw = ed.GetText() or ""
    if Note.SetViewerRaw then
      Note.SetViewerRaw(raw)  -- parse+render without touching saved note
    else
      -- fallback if helper not present
      if type(FRT_Saved) ~= "table" then FRT_Saved = {} end
      FRT_Saved.note = raw
      if Note.UpdateViewerText then Note.UpdateViewerText() end
    end
  end

  -- Replace OnTextChanged for instant preview (1.12-safe)
  if ed and ed.edit and ed.edit.SetScript then
    ed.edit:SetScript("OnTextChanged", function()
      UpdatePreviewFromEditor()
      if ed.Refresh then ed.Refresh() end
    end)
  end

  -- Marker buttons insert + refresh preview
  local function InsertMarker(rtIndex)
    if not ed or not ed.edit or not ed.edit.Insert then return end
    ed.edit:SetFocus()
    ed.edit:Insert(string.format("{rt%d}", rtIndex))
    if ed.Refresh then ed.Refresh() end
    UpdatePreviewFromEditor()
  end
  for i=1,8 do
    local b = buttons[i]
    if b then
      b:SetScript("OnClick", function()
        InsertMarker((this and this._rtIndex) or i)
      end)
    end
  end

  -- Initial content + show preview
  ed.SetText(tostring(FRT_Saved and FRT_Saved.note or ""))
  EnsureViewerVisible()
  UpdatePreviewFromEditor()

  -- Right column buttons
  local save = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
  save:SetWidth(96); save:SetHeight(22)
  save:SetPoint("TOPRIGHT", 0, -24)
  save:SetText("Save")
  save:SetScript("OnClick", function()
    if not FRT.IsLeaderOrOfficer() then FRT.Print("Editor requires raid lead or assist."); return end
    FRT_Saved.note = ed.GetText()
    FRT.Print("Saved note.")
    if Note.UpdateViewerText then Note.UpdateViewerText() end
    UpdatePreviewFromEditor()
  end)

  local share = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
  share:SetWidth(96); share:SetHeight(22)
  share:SetPoint("TOPRIGHT", 0, -50)
  share:SetText("Share")
  share:SetScript("OnClick", function()
    local text = ed.GetText()
    if text == "" then FRT.Print("Nothing to share."); return end
    if not (FRT and FRT.NoteNet and FRT.NoteNet.Send) then
      FRT.Print("Sharing unavailable (NoteNet not loaded)."); return
    end
    if (GetNumRaidMembers() or 0) > 0 then
      FRT.NoteNet.Send(text, "RAID");  FRT.Print("Shared to RAID.")
    elseif (GetNumPartyMembers() or 0) > 0 then
      FRT.NoteNet.Send(text, "PARTY"); FRT.Print("Shared to PARTY.")
    elseif IsInGuild and IsInGuild() then
      FRT.NoteNet.Send(text, "GUILD"); FRT.Print("Shared to GUILD.")
    else
      FRT.Print("You are not in a group.")
    end
  end)

  local openViewer = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
  openViewer:SetWidth(96); openViewer:SetHeight(22)
  openViewer:SetPoint("TOPRIGHT", 0, -76)
  openViewer:SetText("Open Viewer")
  openViewer:SetScript("OnClick", function()
    EnsureViewerVisible()
    UpdatePreviewFromEditor()
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

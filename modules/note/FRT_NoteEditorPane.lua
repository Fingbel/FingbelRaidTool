FRT = FRT or {}
FRT.Note = FRT.Note or {}
local Note = FRT.Note

function Note.BuildNoteEditorPane(parent)
  -- Title
  local title = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  title:SetPoint("TOPLEFT", 0, 0)
  title:SetText("Raid Note — Editor")

  -- Editor region (left side)
  local editorArea = CreateFrame("Frame", nil, parent)
  editorArea:SetPoint("TOPLEFT", 0, -24)
  editorArea:SetPoint("BOTTOMRIGHT", -120, 36)

  -- Build the scrollable editor via util (give it a name to be safe)
  local ed = FRT.Utils.CreateScrollableEdit(editorArea, {
    name             = "FRT_NoteEditorScroll", -- important for template!
    rightColumnWidth = 0,
    scrollbarWidth   = 20,
    padding          = 4,
    minHeight        = 200,
    insets           = { left=4, right=4, top=4, bottom=4 },
    fontObject       = "ChatFontNormal",
    background =  "Interface\\ChatFrame\\ChatFrameBackground",
    border =  "Interface\\Tooltips\\UI-Tooltip-Border",
  })

  -- Load existing text
  ed.SetText(tostring(FRT_Saved and FRT_Saved.note or ""))

  -- Right column buttons
  local save = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
  save:SetWidth(96); save:SetHeight(22)
  save:SetPoint("TOPRIGHT", 0, -24)
  save:SetText("Save")
  save:SetScript("OnClick", function()
    if not FRT.IsLeaderOrOfficer() then
      FRT.Print("Editor requires raid lead or assist."); return
    end
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

-- Exposed helper so /frt editor routes to the global host
function Note.ShowEditor(mod)
  if not FRT.IsLeaderOrOfficer() then
    FRT.Print("Editor requires raid lead or assist.")
    return
  end
  if FRT and FRT.Editor and FRT.Editor.Show then
    FRT.Editor.Show("Note")
  else
    FRT.Print("Global editor not available.")
  end
end

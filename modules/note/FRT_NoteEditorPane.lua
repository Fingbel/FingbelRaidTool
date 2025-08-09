FRT = FRT or {}
FRT.Note = FRT.Note or {}
local Note = FRT.Note

-- ===============================
-- Helpers (1.12/Turtle WoW APIs)
-- ===============================
local function IsLeaderOrOfficer()
  if (GetNumRaidMembers() or 0) > 0 then
    if IsRaidLeader and IsRaidLeader() then return true end
    if IsRaidOfficer and IsRaidOfficer() then return true end
  end
  return false
end

-- ===============================
-- Main pane builder
-- ===============================
function Note.BuildNoteEditorPane(parent)
  -- Title
  local title = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  title:SetPoint("TOPLEFT", 0, 0)
  title:SetText("Raid Note — Editor")

  -- Scroll area + background
  local scroll = CreateFrame("ScrollFrame", "FRT_NoteEditorScroll", parent, "UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", 0, -24)
  scroll:SetPoint("BOTTOMRIGHT", -120, 36)

  local editBG = CreateFrame("Frame", nil, parent)
  editBG:SetPoint("TOPLEFT", 0, -24)
  editBG:SetPoint("BOTTOMRIGHT", -120, 36)
  editBG:SetBackdrop({
    bgFile   = "Interface\\ChatFrame\\ChatFrameBackground",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 12,
    insets = { left = 3, right = 3, top = 3, bottom = 3 }
  })
  editBG:SetBackdropColor(0,0,0,0.5)

  local edit = CreateFrame("EditBox", "FRT_NoteEditorEditBox", scroll)
  edit:SetMultiLine(true)
  edit:SetAutoFocus(false)
  edit:SetWidth(parent:GetWidth() - 140)
  edit:SetHeight(200)
  edit:SetFontObject("ChatFontNormal")
  edit:SetTextInsets(4,4,4,4)
  edit:EnableMouse(true)
  edit:SetScript("OnEscapePressed", function() edit:ClearFocus() end)
  edit:SetScript("OnEnterPressed",  function() edit:Insert("\n") end)
  edit:SetScript("OnTextChanged", function()
    local text = edit:GetText() or ""
    local lines = 1
    for _ in string.gfind(text, "\n") do lines = lines + 1 end
    local h = lines * 16 + 12
    if h < 200 then h = 200 end
    edit:SetHeight(h)
  end)

  scroll:SetScrollChild(edit)
  scroll:EnableMouseWheel(true)
  scroll:SetScript("OnMouseWheel", function()
    local sb = getglobal(scroll:GetName() .. "ScrollBar")
    if not sb then return end
    local step = 20
    local delta = arg1 or 0
    sb:SetValue(sb:GetValue() - delta * step)
  end)

  -- Resize behavior inside host pane
  parent:SetScript("OnSizeChanged", function()
    edit:SetWidth(parent:GetWidth() - 140)
  end)
  parent:SetScript("OnShow", function()
    edit:SetWidth(parent:GetWidth() - 140)
    edit:SetText(tostring(FRT_Saved.note or ""))
  end)

  -- Buttons (right column)
  local save = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
  save:SetWidth(96); save:SetHeight(22)
  save:SetPoint("TOPRIGHT", 0, -24)
  save:SetText("Save")
  save:SetScript("OnClick", function()
    if not IsLeaderOrOfficer() then
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
      FRT.SendAddon("RAID", text)
      FRT.Print("Shared to RAID.")
    elseif (GetNumPartyMembers() or 0) > 0 then
      FRT.SendAddon("PARTY", text)
      FRT.Print("Shared to PARTY.")
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
  if not IsLeaderOrOfficer() then FRT.Print("Editor requires raid lead or assist."); return end
  if FRT and FRT.Editor and FRT.Editor.Show then
    FRT.Editor.Show("Note")
  else
    FRT.Print("Global editor not available.")
  end
end


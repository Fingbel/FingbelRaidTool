-- Fingbel Raid Tool — Note Editor Pane (Entry)
-- Public entry + namespace + exports

FRT = FRT or {}
FRT.Note = FRT.Note or {}
FRT.Note.EditorPane = FRT.Note.EditorPane or {}

local EP = FRT.Note.EditorPane

-- Public: keep the same external API
function FRT.Note.BuildNoteEditorPane(parent)
  if EP and EP.Build then
    EP.Build(parent)
  else
    -- soft guard if load order is wrong
    DEFAULT_CHAT_FRAME:AddMessage("|cffff5555[FRT] Note EditorPane not initialized (load order?)|r")
  end
end

function FRT.Note.ShowEditor()
  -- identical gating to your monolith
  if FRT.IsInRaid and FRT.IsInRaid() and not (FRT.IsLeaderOrOfficer and FRT.IsLeaderOrOfficer()) then
    if FRT.Print then FRT.Print("Editor requires raid lead or assist.") end
    return
  end
  if FRT and FRT.Editor and FRT.Editor.Show then
    FRT.Editor.Show("Note")
  else
    if FRT.Print then FRT.Print("Global editor not available.") end
  end
end

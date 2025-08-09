-- FRT_TestParser.lua (Vanilla 1.12)

-- Show that this file loaded
if DEFAULT_CHAT_FRAME then
  DEFAULT_CHAT_FRAME:AddMessage("|cff55ff55[FRT] FRT_TestParser.lua loaded|r")
end

-- Slash command
SLASH_FRTPARSE1 = "/frtparse"
SlashCmdList.FRTPARSE = function(msg)
  local sample = "Pull {rt8} then {rt7}\nHealers to {rt3}"

  if FRT and FRT.Parser and type(FRT.Parser.ParseNote) == "function" then
    local out = FRT.Parser.ParseNote(sample)
    FRT.SimpleNoteViewer.Show(out)
  end
end

--    f:SetWidth(520)
--    f:SetHeight(360)
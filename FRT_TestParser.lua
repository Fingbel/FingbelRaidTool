-- FRT_TestParser.lua (Vanilla 1.12)

-- Show that this file loaded
if DEFAULT_CHAT_FRAME then
  DEFAULT_CHAT_FRAME:AddMessage("|cff55ff55[FRT] FRT_TestParser.lua loaded|r")
end

-- Slash command
SLASH_FRTPARSE1 = "/frtparse"
SlashCmdList.FRTPARSE = function(msg)
  local sample = "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum."


  if FRT and FRT.Parser and type(FRT.Parser.ParseNote) == "function" then
    local out = FRT.Parser.ParseNote(sample)
    FRT.SimpleNoteViewer.Show(out)
  end
end
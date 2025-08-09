-- FRT_Parser.lua (minimal, 1.12-safe)
local _G = getfenv(0)
_G.FRT = _G.FRT or {}
local FRT = _G.FRT

FRT.Parser = FRT.Parser or {}

function FRT.Parser.ParseNote(s)
  if type(s) ~= "string" then
    return ""
  end
  return s
end

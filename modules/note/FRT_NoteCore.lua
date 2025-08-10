-- Fingbel Raid Tool - Note Core Module

FRT.Note = FRT.Note or {}
local Note = FRT.Note
Note.name = "Note"

FRT.safePrint("FRT_NoteCore.lua loaded (NoteNet)")

-- ===============================
-- SavedVariables (module scope)
-- ===============================
local function EnsureSaved()
  if type(FRT_Saved) ~= "table" then FRT_Saved = {} end
  if FRT_Saved.note == nil then FRT_Saved.note = "" end
  FRT_Saved.ui = FRT_Saved.ui or { editor = {}, viewer = { autoOpen = true, locked = false } }
  if FRT_Saved.ui.viewer.autoOpen == nil then FRT_Saved.ui.viewer.autoOpen = true end
  if FRT_Saved.ui.viewer.locked   == nil then FRT_Saved.ui.viewer.locked   = false end
end

local function WireNoteNetCallback()
  if FRT and FRT.NoteNet and not Note.__wiredNoteNet then
    FRT.NoteNet.onNoteReceived = function(sender, text, meta)
      FRT_Saved.note = tostring(text or "")
      Note.UpdateViewerText(Note)
      if FRT_Saved.ui.viewer.autoOpen then Note.ShowViewer(Note) end
      FRT.Print("Note received from " .. (sender or "?"))
    end
    Note.__wiredNoteNet = true
    FRT.safePrint("NoteNet callback wired.")
  end
end

-- ===============================
-- Module events (comms)
-- ===============================
function Note.OnLoad(mod)
  EnsureSaved()
  FRT.RegisterAddonPrefix()      -- ensure prefix registered
  Note.BuildViewer()

  if FRT and FRT.Editor and FRT.Editor.RegisterPanel then
    FRT.Editor.RegisterPanel("Note", Note.BuildNoteEditorPane, { title = "📝 Raid Note", order = 10 })
  end

  WireNoteNetCallback()

  -- late-bind on next frame 
  local retry = CreateFrame("Frame")
  retry:SetScript("OnUpdate", function()
    if Note.__wiredNoteNet then
      retry:SetScript("OnUpdate", nil)
    else
      WireNoteNetCallback()
    end
  end)
end

-- ===============================
-- Slash subcommands
-- ===============================
function Note.GetHelp(mod)
  return {
    "/frt set <text>                  - set note",
    "/frt show                        - show note in chat",
    "/frt share [raid|party|guild|bg] - share note (auto if omitted)",
    "/frt share whisper <name>        - whisper note (if supported)",
    "/frt clear                       - clear the note",
    "/frt view                        - open read-only viewer",
    "/frt editor                      - open global editor on Note (lead/assist)",
    "/frt autoopen on|off             - toggle auto-open viewer",
    "/frt lock [on|off]               - lock/unlock viewer move/resize",
  }
end

local function AutoShareChannel()
  if (GetNumRaidMembers() or 0) > 0 then
    if (GetBattlefieldStatus and GetBattlefieldStatus(1) == "active") or (UnitInBattleground and UnitInBattleground("player")) then
      return "BATTLEGROUND"
    end
    return "RAID"
  elseif (GetNumPartyMembers() or 0) > 0 then
    return "PARTY"
  elseif IsInGuild and IsInGuild() then
    return "GUILD"
  end
  return nil
end

local function DoShare(rest)
  if not FRT.NoteNet then
    FRT.Print("Sharing unavailable (NoteNet not loaded).")
    return true
  end
  local txt = FRT_Saved.note or ""
  if txt == "" then FRT.Print("Note is empty."); return true end

  local a = string.lower(tostring(rest or ""))

  if a == "raid" then
    FRT.NoteNet.Send(txt, "RAID"); FRT.Print("Note shared to RAID."); return true
  elseif a == "party" then
    FRT.NoteNet.Send(txt, "PARTY"); FRT.Print("Note shared to PARTY."); return true
  elseif a == "guild" or a == "g" then
    FRT.NoteNet.Send(txt, "GUILD"); FRT.Print("Note shared to GUILD."); return true
  elseif a == "bg" or a == "battleground" then
    FRT.NoteNet.Send(txt, "BATTLEGROUND"); FRT.Print("Note shared to BATTLEGROUND."); return true
  end

  local wcmd, wtarget = string.match(rest or "", "^(%S+)%s+(.+)$")
  if wcmd and string.lower(wcmd) == "whisper" and wtarget and wtarget ~= "" then
    FRT.NoteNet.Send(txt, "WHISPER", wtarget)
    FRT.Print("Note whispered to " .. wtarget .. ".")
    return true
  end

  local ch = AutoShareChannel()
  if ch then
    FRT.NoteNet.Send(txt, ch)
    FRT.Print("Note shared to " .. ch .. ".")
  else
    FRT.Print("You are not in a group/guild.")
  end
  return true
end

function Note.OnSlash(mod, cmd, rest)
  if cmd == "set" and rest ~= "" then
    FRT_Saved.note = rest
    FRT.Print("Set note: " .. FRT_Saved.note)
    Note.UpdateViewerText(Note)
    return true
  elseif cmd == "show" then
    FRT.Print("Current note: " .. (FRT_Saved.note or "<nil>"))
    return true
  elseif cmd == "share" then
    return DoShare(rest)
  elseif cmd == "clear" then
    FRT_Saved.note = ""
    FRT.Print("Note cleared.")
    Note.UpdateViewerText(Note)
    return true
  elseif cmd == "view" then
    Note.ShowViewer(Note); return true
  elseif cmd == "editor" then
    Note.ShowEditor(Note); return true
  elseif cmd == "autoopen" then
    local a = string.lower(rest or "")
    if a == "on" or a == "1" or a == "true" then
      FRT_Saved.ui.viewer.autoOpen = true; FRT.Print("Auto-open ON.")
    elseif a == "off" or a == "0" or a == "false" then
      FRT_Saved.ui.viewer.autoOpen = false; FRT.Print("Auto-open OFF.")
    else
      FRT.Print("Auto-open is " .. (FRT_Saved.ui.viewer.autoOpen and "ON" or "OFF") .. ". Use /frt autoopen on|off")
    end
    return true
  elseif cmd == "lock" then
    local a = string.lower(rest or "")
    if a == "on" or a == "1" or a == "true" then
      FRT_Saved.ui.viewer.locked = true
    elseif a == "off" or a == "0" or a == "false" then
      FRT_Saved.ui.viewer.locked = false
    else
      FRT_Saved.ui.viewer.locked = not FRT_Saved.ui.viewer.locked
    end
    Note.UpdateViewerLockUI()
    FRT.Print("Viewer " .. (FRT_Saved.ui.viewer.locked and "locked" or "unlocked") .. ".")
    return true
  end
  return false
end

-- Register module with core (immediately on file load)
if FRT and FRT.RegisterModule then
  FRT.RegisterModule(Note.name, Note)
else
  local wait = CreateFrame("Frame")
  wait:SetScript("OnUpdate", function()
    if FRT and FRT.RegisterModule then
      wait:SetScript("OnUpdate", nil)
      FRT.RegisterModule(Note.name, Note)
      FRT.safePrint("FRTNote registered late")
    end
  end)
end

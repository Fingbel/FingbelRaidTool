-- Fingbel Raid Tool - Note Module (embedded editor pane)
FRT.Note = FRT.Note or {}
local Note = FRT.Note
Note.name = "Note"

FRT.safePrint("FRT_Note.lua loaded")

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

-- ===============================
-- Module events (comms)
-- ===============================
local ev = CreateFrame("Frame")

function Note.OnLoad(mod)
  EnsureSaved()
  FRT.RegisterAddonPrefix()
  Note.BuildViewer()

  -- Register our editor pane with the global editor host (if present)
  if FRT and FRT.Editor and FRT.Editor.RegisterPanel then
    FRT.Editor.RegisterPanel("Note", Note.BuildNoteEditorPane, { title = "📝 Raid Note", order = 10 })
  end

  -- Listen for incoming addon notes
  ev:RegisterEvent("CHAT_MSG_ADDON")
  ev:SetScript("OnEvent", function()
    if event == "CHAT_MSG_ADDON" then
      local prefix, message, channel, sender = arg1, arg2, arg3, arg4
      if prefix == FRT.ADDON_PREFIX and sender ~= UnitName("player") then
        FRT_Saved.note = tostring(message or "")
        FRT.Print("Note from " .. (sender or "unknown") .. ": " .. FRT_Saved.note)
        Note.UpdateViewerText(Note)
        if FRT_Saved.ui.viewer.autoOpen then Note.ShowViewer(Note) end
      end
    end
  end)
end

-- ===============================
-- Slash subcommands
-- ===============================
function Note.GetHelp(mod)
  return {
    "/frt set <text>        - set note",
    "/frt show              - show note in chat",
    "/frt share             - send note to raid/party",
    "/frt clear             - clear the note",
    "/frt view              - open read-only viewer",
    "/frt editor            - open global editor on Note (lead/assist)",
    "/frt autoopen on|off   - toggle auto-open viewer",
    "/frt lock [on|off]     - lock/unlock viewer move/resize",
  }
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
    if GetNumRaidMembers() > 0 then
      FRT.SendAddon("RAID", FRT_Saved.note)
      FRT.Print("Note shared to RAID.")
    elseif GetNumPartyMembers() > 0 then
      FRT.SendAddon("PARTY", FRT_Saved.note)
      FRT.Print("Note shared to PARTY.")
    else
      FRT.Print("You are not in a group.")
    end
    return true

  elseif cmd == "clear" then
    FRT_Saved.note = ""
    FRT.Print("Note cleared.")
    Note.UpdateViewerText(Note)
    return true

  elseif cmd == "view" then
    Note.ShowViewer(Note)
    return true

  elseif cmd == "editor" then
    Note.ShowEditor(Note)
    return true

  elseif cmd == "autoopen" then
    local a = string.lower(rest or "")
    if a == "on" or a == "1" or a == "true" then
      FRT_Saved.ui.viewer.autoOpen = true
      FRT.Print("Auto-open ON.")
    elseif a == "off" or a == "0" or a == "false" then
      FRT_Saved.ui.viewer.autoOpen = false
      FRT.Print("Auto-open OFF.")
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

  return false -- not handled
end

-- Register module with core (immediately on file load)
if FRT and FRT.RegisterModule then
  FRT.RegisterModule(Note.name, Note)
else
  -- Extreme fallback: if core isn't loaded yet, create a tiny loader
  local wait = CreateFrame("Frame")
  wait:SetScript("OnUpdate", function()
    if FRT and FRT.RegisterModule then
      wait:SetScript("OnUpdate", nil)
      FRT.RegisterModule(Note.name, Note)
      FRT.safePrint("FRTNote registered late")
    end
  end)
end

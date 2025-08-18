-- Fingbel Raid Tool - Note Core (Shared Library)
FRT = FRT or {}
FRT.Note = FRT.Note or {}
local Note = FRT.Note
Note.name = "Note"

if FRT and FRT.safePrint then FRT.safePrint("FRT_NoteCore.lua (Shared Library) loaded") end

-- ===== SV ensure =====
local function EnsureSaved()
  if type(FRT_Saved) ~= "table" then FRT_Saved = {} end
  FRT_Saved.note   = (FRT_Saved.note ~= nil) and FRT_Saved.note or ""   -- scratch
  FRT_Saved.notes  = FRT_Saved.notes or {}                              -- shared library (array)
  FRT_Saved.shared = FRT_Saved.shared or {}                             -- keep in case of other modules

  FRT_Saved.ui = FRT_Saved.ui or {}
  FRT_Saved.ui.mainEditor = FRT_Saved.ui.mainEditor or { x=nil, y=nil, w=800, h=500, selected=nil }
  FRT_Saved.ui.notes = FRT_Saved.ui.notes or { selectedRaid = "Custom/Misc", selectedId = nil, selectedBossByRaid = {}, sourceFilter = "All", scopeFilter = "All" }
  FRT_Saved.ui.notes.selectedBossByRaid = FRT_Saved.ui.notes.selectedBossByRaid or {}
  FRT_Saved.ui.viewer = FRT_Saved.ui.viewer or { autoOpen = true, locked = false }
end
EnsureSaved()

-- ===== tiny hash (16-bit) =====
local function Hash16(s)
  local sum = 0; s = tostring(s or "")
  for i = 1, string.len(s) do sum = math.mod(sum + string.byte(s, i), 65536) end
  local t = "0123456789ABCDEF"
  local hi = math.mod(math.floor(sum / 256), 256); local lo = math.mod(sum, 256)
  local function hx(v) local a = math.floor(v/16); local b = math.mod(v,16); return string.sub(t,a+1,a+1) .. string.sub(t,b+1,b+1) end
  return hx(hi)..hx(lo)
end

-- ===== auto channel =====
local function AutoShareChannel()
  if (GetNumRaidMembers and (GetNumRaidMembers() or 0) > 0) then
    return "RAID"
  elseif (GetNumPartyMembers and (GetNumPartyMembers() or 0) > 0) then
    return "PARTY"
  elseif IsInGuild and IsInGuild() then
    return "GUILD"
  end
  return nil
end

-- ===== origin helpers =====
local function _me() return (UnitName and UnitName("player")) or "" end

local function _isGuildmate(name)
  if not (IsInGuild and IsInGuild()) then return false end
  local nn = string.lower(tostring(name or ""))
  for i = 1, (GetNumGuildMembers and GetNumGuildMembers(true) or 0) do
    local n = GetGuildRosterInfo(i)
    if n and string.lower(n) == nn then return true end
  end
  return false
end

local function _classifyOrigin(sender, inChan)
  local me = _me()
  if sender and string.lower(sender) == string.lower(me) then return "self" end
  if inChan == "GUILD" or _isGuildmate(sender) then return "guild" end
  return "outside"
end

-- NEW: scope from channel/sender (“guild” if guild channel or guildmate; else “external”)
local function _classifyScope(sender, inChan)
  if inChan == "GUILD" or _isGuildmate(sender) then return "guild" end
  return "external"
end

-- Cache REF origins (REF may arrive via GUILD/RAID; NOTE follows over WHISPER)
local _refOriginById = {}

local function WireNoteNetCallback()
  if FRT and FRT.NoteNet and not Note.__wiredNoteNet then

    FRT.NoteNet.onRef = function(sender, meta, inChan)
      _refOriginById[meta.id or ""] = _classifyOrigin(sender, inChan)

      local found
      if FRT.SharedLib and FRT.SharedLib.FindById then
        local note = FRT.SharedLib.FindById(meta.id)
        if note then found = note end
      end

      local function up(s) return string.upper(tostring(s or "")) end
      if found and up(found.hash) == up(meta.hash) then
        FRT_Saved.note = found.text or ""
        if FRT.Note and FRT.Note.UpdateViewerText then FRT.Note.UpdateViewerText() end
        if FRT_Saved.ui.viewer.autoOpen and FRT.Note and FRT.Note.ShowViewer then FRT.Note.ShowViewer() end
      else
        FRT_Saved.note = string.format("[FRT] Fetching “%s”…", (meta.title and meta.title ~= "" and meta.title) or (meta.id or "?"))
        if FRT.Note and FRT.Note.UpdateViewerText then FRT.Note.UpdateViewerText() end
        if FRT.NoteNet and FRT.NoteNet.SendReq then
          FRT.NoteNet.SendReq(meta.id, meta.version, sender)
        end
      end
    end

    FRT.NoteNet.onNote = function(sender, meta, text, inChan)
      meta.owner  = sender
      meta.source = "shared"
      meta.origin = _refOriginById[meta.id or ""] or _classifyOrigin(sender, inChan)
      -- NEW: stamp scope on received body
      meta.scope  = _classifyScope(sender, inChan)

      if FRT.SharedLib and FRT.SharedLib.Upsert then
        FRT.SharedLib.Upsert(meta, text or "")
      end
      FRT_Saved.note = tostring(text or "")
      if Note.UpdateViewerText then Note.UpdateViewerText(Note) end
      if FRT_Saved.ui.viewer.autoOpen and Note.ShowViewer then Note.ShowViewer(Note) end
    end

    FRT.NoteNet.onLibAdd = function(sender, meta, body, inChan)
      meta.owner  = sender
      meta.source = "shared"
      meta.origin = _classifyOrigin(sender, inChan)
      -- NEW: stamp scope on library replication
      meta.scope  = _classifyScope(sender, inChan)

      if FRT.SharedLib and FRT.SharedLib.Upsert then
        FRT.SharedLib.Upsert(meta, body or "")
      end

      FRT_Saved.note = tostring(body or "")
      if Note.UpdateViewerText then Note.UpdateViewerText(Note) end
      if FRT_Saved.ui.viewer.autoOpen and Note.ShowViewer then Note.ShowViewer(Note) end

      if FRT.Note and FRT.Note.EditorPane and FRT.Note.EditorPane.RebuildList then
        FRT.Note.EditorPane.RebuildList()
      end
      if FRT.Note and FRT.Note.EditorPane and FRT.Note.EditorPane.UpdateButtonsState then
        FRT.Note.EditorPane.UpdateButtonsState()
      end
    end

    FRT.NoteNet.onReq = function(requester, meta, inChan)
      local wanted = meta and meta.id
      if not wanted or wanted == "" then return end
      local arr = FRT_Saved.notes or {}
      local src
      for i = 1, table.getn(arr) do local n = arr[i]; if n and n.id == wanted then src = n; break end end
      if not src then return end
      local hash = src.hash or Hash16(src.text or "")
      local ver  = src.version or 1
      if FRT.NoteNet.SendNote then
        FRT.NoteNet.SendNote({
          id = src.id, version = ver, hash = hash,
          title = src.title or "", raid = src.raid or "", boss = src.boss or ""
        }, src.text or "", "WHISPER", requester)
      end
    end

    Note.__wiredNoteNet = true
    if FRT and FRT.safePrint then FRT.safePrint("NoteNet wired (Shared Library + REF/REQ/NOTE + origin+scope tagging)") end
  end
end

-- ===== Module load =====
function Note.OnLoad()
  EnsureSaved()
  if FRT.RegisterAddonPrefix then FRT.RegisterAddonPrefix() end
  if Note.BuildViewer then Note.BuildViewer() end

  if FRT and FRT.Editor and FRT.Editor.RegisterPanel then
    FRT.Editor.RegisterPanel("Note", Note.BuildNoteEditorPane, { title = "📝 Raid Note", order = 10 })
  end

  WireNoteNetCallback()
  local retry = CreateFrame("Frame")
  retry:SetScript("OnUpdate", function()
    if Note.__wiredNoteNet then retry:SetScript("OnUpdate", nil) else WireNoteNetCallback() end
  end)
end

-- ===== Help & slash =====
function Note.GetHelp()
  return {
    "/frt ref <id>                    - broadcast REF for saved note id",
    "/frt view                        - open read-only viewer",
    "/frt editor                      - open global editor",
    "/frt clear                       - clear scratch note",
  }
end

local function FindSavedById(id)
  local arr = FRT_Saved.notes or {}
  for i = 1, table.getn(arr) do local n = arr[i]; if n and n.id == id then return n end end
  return nil
end

local function DoBroadcastRefById(id, channel)
  local n = FindSavedById(id)
  if not n then if FRT.Print then FRT.Print("No saved note with id "..tostring(id)) end return true end
  local meta = {
    id = n.id, version = n.version or 1, hash = n.hash or Hash16(n.text or ""),
    title = n.title or "", raid = n.raid or "", boss = n.boss or ""
  }
  local ch = channel or AutoShareChannel()
  if not ch then if FRT.Print then FRT.Print("No channel.") end return true end
  if FRT.NoteNet and FRT.NoteNet.SendRef then
    FRT.NoteNet.SendRef(meta, ch)
    FRT_Saved.note = n.text or ""   -- show what we just referenced
    if Note.UpdateViewerText then Note.UpdateViewerText(Note) end
    if FRT.Print then FRT.Print("Broadcasted REF: "..(meta.title ~= "" and meta.title or "(untitled)")) end
  end
  return true
end

function Note.OnSlash(_, cmd, rest)
  if cmd == "ref"   and rest and rest ~= "" then return DoBroadcastRefById(rest, nil)
  elseif cmd == "view"   then if Note.ShowViewer then Note.ShowViewer(Note) end; return true
  elseif cmd == "editor" then if Note.ShowEditor then Note.ShowEditor(Note) end; return true
  elseif cmd == "clear"  then FRT_Saved.note = ""; if Note.UpdateViewerText then Note.UpdateViewerText(Note) end; return true
  end
  return false
end

-- ===== Register with core =====
if FRT and FRT.RegisterModule then
  FRT.RegisterModule(Note.name, Note)
else
  local wait = CreateFrame("Frame")
  wait:SetScript("OnUpdate", function()
    if FRT and FRT.RegisterModule then
      wait:SetScript("OnUpdate", nil)
      FRT.RegisterModule(Note.name, Note)
      if FRT.safePrint then FRT.safePrint("FRTNote registered late") end
    end
  end)
end

-- Fingbel Raid Tool — Note Editor Pane (Logic)
FRT = FRT or {}
FRT.Note = FRT.Note or {}
FRT.Note.EditorPane = FRT.Note.EditorPane or {}
local EP  = FRT.Note.EditorPane
local S   = EP.state or (function() local t = {}; EP.state = t; return t end)()

-- ============
-- Saved / data
-- ============
function EP.EnsureSaved()
  if type(FRT_Saved) ~= "table" then FRT_Saved = {} end
  FRT_Saved.notes = FRT_Saved.notes or {}
  FRT_Saved.ui    = FRT_Saved.ui or {}
  FRT_Saved.ui.notes = FRT_Saved.ui.notes or {
    selectedRaid = "Custom/Misc",
    selectedId   = nil,
    selectedBossByRaid = {},
    sourceFilter = "All",
    scopeFilter  = "All",
  }
  FRT_Saved.ui.notes.selectedBossByRaid = FRT_Saved.ui.notes.selectedBossByRaid or {}
  FRT_Saved.ui.notes.sourceFilter = FRT_Saved.ui.notes.sourceFilter or "All"
  FRT_Saved.ui.notes.scopeFilter  = FRT_Saved.ui.notes.scopeFilter  or FRT_Saved.ui.notes.sourceFilter or "All"
end

-- Channel selection (prefers guild, then raid, then party)
function PickChannel()
  if IsInGuild and IsInGuild() then return "GUILD" end
  if (GetNumRaidMembers and (GetNumRaidMembers() or 0) > 0) then return "RAID" end
  if (GetNumPartyMembers and (GetNumPartyMembers() or 0) > 0) then return "PARTY" end
  return nil
end

-- Tiny 16-bit hash (Lua 5.0-safe) used everywhere in this file
local function Hash16(s)
  s = tostring(s or "")
  local sum = 0
  for i = 1, string.len(s) do
    sum = math.mod(sum + string.byte(s, i), 65536)
  end
  local t = "0123456789ABCDEF"
  local hi = math.mod(math.floor(sum / 256), 256)
  local lo = math.mod(sum, 256)
  local function hx(v)
    local a = math.floor(v / 16)
    local b = math.mod(v, 16)
    return string.sub(t, a + 1, a + 1) .. string.sub(t, b + 1, b + 1)
  end
  return hx(hi) .. hx(lo)
end

local function genId()
  local base = math.mod(math.floor(GetTime() * 1000), 100000000)
  return tostring(base) .. tostring(math.random(100,999))
end

-- ===== origin fallback helpers (UI-side) =====
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
local function _safeOrigin(n)
  if n and n.origin and n.origin ~= "" then return n.origin end
  local owner = tostring(n and n.owner or "")
  if owner ~= "" and string.lower(owner) == string.lower(_me()) then return "self" end
  if owner ~= "" and _isGuildmate(owner) then return "guild" end
  return "outside"
end

-- ========= Raids / bosses =========
function EP.RaidList()
  local raids, RB = {}, FRT.RaidBosses
  if RB then
    if type(RB._order) == "table" and table.getn(RB._order) > 0 then
      for i = 1, table.getn(RB._order) do
        local rname = RB._order[i]
        if rname and RB[rname] and rname ~= "_order" then table.insert(raids, rname) end
      end
      for k,_ in pairs(RB) do
        if k ~= "_order" then
          local found = false
          for i=1, table.getn(raids) do if raids[i] == k then found = true; break end end
          if not found then table.insert(raids, k) end
        end
      end
    else
      for k,_ in pairs(RB) do if k ~= "_order" then table.insert(raids, k) end end
      table.sort(raids)
    end
  end
  local misc = "Custom/Misc"
  local miscIdx
  for i=1, table.getn(raids) do if raids[i] == misc then miscIdx = i; break end end
  if miscIdx then table.remove(raids, miscIdx) end
  if (not RB) or RB[misc] then table.insert(raids, misc) end
  return raids
end

function EP.FirstRaidName()
  local raids = EP.RaidList()
  if table.getn(raids) > 0 then return raids[1] end
  return "Custom/Misc"
end

function EP.BossList(raid)
  local entry = FRT.RaidBosses and FRT.RaidBosses[raid]
  if entry then
    if type(entry) == "table" and entry.bosses then return entry.bosses
    elseif type(entry) == "table" then return entry end
  end
  return { "General" }
end

function EP.GetRaidFullName(raid)
  local entry = FRT.RaidBosses and FRT.RaidBosses[raid]
  if entry and type(entry) == "table" and entry.name then return entry.name end
  return raid
end

function EP.NotesForRaid(raid)
  local out = {}
  local arr = FRT_Saved.notes or {}
  for i=1, table.getn(arr) do
    local n = arr[i]
    if n and n.raid == raid then table.insert(out, n) end
  end
  return out
end

function EP.FindNoteById(id)
  if not id then return nil end
  local want = tostring(id)
  local arr = FRT_Saved.notes or {}
  for i = 1, table.getn(arr) do
    local n = arr[i]
    if n and tostring(n.id) == want then
      return n, i
    end
  end
  return nil
end

function EP.EnsureDropDownListFrames()
  if not DropDownList1 then
    if UIDropDownMenu_CreateFrames then
      UIDropDownMenu_CreateFrames(1, 1)
    else
      local tmp = CreateFrame("Frame", nil, UIParent, "UIDropDownMenuTemplate")
      ToggleDropDownMenu(1, nil, tmp); ToggleDropDownMenu(1, nil, tmp)
      tmp:Hide()
    end
  end
end

-- ==============
-- List / Sorting (+ Source filter)
-- ==============
function EP.GetFilteredNotes()
  local all = EP.NotesForRaid(S.currentRaid)

  -- Boss filter
  local bossFiltered = {}
  if S.currentBossFilter == "All" then
    for i=1, table.getn(all) do bossFiltered[table.getn(bossFiltered)+1] = all[i] end
  else
    for i=1, table.getn(all) do
      local n = all[i]
      if n.boss == S.currentBossFilter then bossFiltered[table.getn(bossFiltered)+1] = n end
    end
  end

  -- Source filter
  local src = S.currentSourceFilter or "All"
  local final = {}
  if src == "All" then
    final = bossFiltered
  else
    local want = string.lower(src)
    for i=1, table.getn(bossFiltered) do
      local n = bossFiltered[i]
      if string.lower(_safeOrigin(n) or "") == want then
        final[table.getn(final)+1] = n
      end
    end
  end

  -- Sort by title (then boss if "All")
  table.sort(final, function(a,b)
    local at = string.lower(a.title or ""); local bt = string.lower(b.title or "")
    if S.currentBossFilter == "All" and at == bt then
      return string.lower(a.boss or "") < string.lower(b.boss or "")
    end
    return at < bt
  end)

  return final
end

function EP.UpdateListSelection()
  local listButtons = S.listButtons
  for i=1, table.getn(listButtons) do
    local b = listButtons[i]
    if b and b.fs and b.id then
      if S.currentId and b.id == S.currentId then
        b:LockHighlight()
        if b.fs.SetFontObject then b.fs:SetFontObject(GameFontHighlight) end
      else
        b:UnlockHighlight()
        if b.fs.SetFontObject then b.fs:SetFontObject(GameFontNormal) end
      end
    end
  end
end

function EP.ClearListButtons()
  local listButtons = S.listButtons
  for i=1, table.getn(listButtons) do if listButtons[i] then listButtons[i]:Hide() end end
  S.listButtons = {}
end

function EP.MakeRow(parentFrame, y, text, id)
  local btn = CreateFrame("Button", nil, parentFrame)
  btn:SetPoint("TOPLEFT", 0, y)
  btn:SetWidth(180); btn:SetHeight(18)

  local fs = btn:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  fs:SetPoint("LEFT", 10, 0)
  fs:SetText(text)
  btn.fs = fs
  btn.id = id

  btn:SetHighlightTexture("Interface\\Buttons\\UI-Listbox-Highlight2", "ADD")
  btn:SetScript("OnClick", function()
    local targetId = id
    if EP.IsDirty and EP.IsDirty() then
      S.pending.noteSwitch = targetId
      S.pending.noteIsNew  = false
      if EP.ShowBlocker then EP.ShowBlocker() end
      StaticPopup_Show("FRT_UNSAVED_SWITCHNOTE")
    else
      if EP.LoadSelected then EP.LoadSelected(targetId) end
    end
  end)

  table.insert(S.listButtons, btn)
  return btn
end

function EP.RebuildList()
  EP.ClearListButtons()
  if S.listScroll and S.listScroll.SetVerticalScroll then
    S.listScroll:SetVerticalScroll(0)
  end

  local filtered = EP.GetFilteredNotes()
  local y = 0
  if table.getn(filtered) == 0 then
    local msg
    if S.currentBossFilter == "All" then
      msg = (S.currentSourceFilter == "All") and "(No notes in this raid)" or "(No notes for this source)"
    else
      msg = (S.currentSourceFilter == "All") and "(No notes for this boss)" or "(No notes for this boss/source)"
    end
    local btn = CreateFrame("Button", nil, S.listChild)
    btn:SetPoint("TOPLEFT", 0, y)
    btn:SetWidth(180); btn:SetHeight(18)
    local fs = btn:CreateFontString(nil, "ARTWORK", "GameFontDisable")
    fs:SetPoint("LEFT", 10, 0); fs:SetText(msg)
    btn.fs = fs; btn:EnableMouse(false)
    table.insert(S.listButtons, btn)
    y = y - 18
  else
    for i=1, table.getn(filtered) do
      local n = filtered[i]
      local ttl = tostring(n.title or "")
      ttl = string.gsub(ttl, "^%s*(.-)%s*$", "%1")
      if ttl == "" then ttl = "(untitled)" end
      if S.currentBossFilter == "All" and n.boss and n.boss ~= "" then
        ttl = ttl .. "  |cffffd200[" .. n.boss .. "]|r"
      end
      -- NEW: append origin tag
      local ori = _safeOrigin(n)
      if ori == "guild" then
        ttl = ttl .. " |cff7fbfff[guild]|r"
      elseif ori == "outside" then
        ttl = ttl .. " |cffffb347[outside]|r"
      else
        ttl = ttl .. " |cff8f8f8f[self]|r"
      end

      EP.MakeRow(S.listChild, y, ttl, n.id)
      y = y - 18
    end
  end

  if S.listChild then
    S.listChild:SetHeight(-y + 4)
    S.listChild:SetWidth(180)
  end
  EP.UpdateListSelection()
end

-- ================
-- Editor + preview
-- ================
function EP.UpdatePreviewFromEditor()
  local ed = S.editor
  local raw = (ed and ed.GetText and ed.GetText()) or ""

  -- Scratch now mirrors "currently edited" content
  if type(FRT_Saved) ~= "table" then FRT_Saved = {} end
  FRT_Saved.note = raw

  -- Push to viewer using best available renderer
  if FRT.Note and FRT.Note.SetViewerRaw then
    FRT.Note.SetViewerRaw(raw)
  elseif FRT.Note and FRT.Note.UpdateViewerText then
    FRT.Note.UpdateViewerText()
  end
end

function EP.LoadSelected(id)
  S.currentId = id
  S.uiSV.selectedId = id
  if EP.BeginSquelch then EP.BeginSquelch() end
  local n = id and EP.FindNoteById(id) or nil
  if n then
    if not (FRT.RaidBosses and FRT.RaidBosses[n.raid or ""]) then
      n.raid = EP.FirstRaidName()
    end
    if S.bossInfoLabel then S.bossInfoLabel:SetText(n.boss or "General") end
    if S.titleBox and S.titleBox.SetText then S.titleBox:SetText(n.title or "") end
    if S.editor and S.editor.SetText then S.editor.SetText(n.text or "") end
    if EP.SetEditorEnabled then EP.SetEditorEnabled(true) end
  else
    if S.bossInfoLabel then S.bossInfoLabel:SetText("") end
    if S.titleBox and S.titleBox.SetText then S.titleBox:SetText("") end
    if S.editor and S.editor.SetText then S.editor.SetText("") end
    if EP.SetEditorEnabled then EP.SetEditorEnabled(false) end
    S.baseline = nil
  end
  if EP.EndSquelch then EP.EndSquelch() end
  if S.editorEnabled then
    if EP.SnapBaseline then EP.SnapBaseline() end
    EP.UpdatePreviewFromEditor()
  end
  if EP.UpdateButtonsState then EP.UpdateButtonsState() end
  EP.UpdateListSelection()
end

local function GatherEditor()
  local ed = S.editor
  local t = ed and ed.GetText and (ed.GetText() or "") or ""
  local ttl = (S.titleBox and S.titleBox.GetText and (S.titleBox:GetText() or "")) or ""
  return { raid = S.currentRaid, title = ttl, text = t }
end

-- =======
-- Actions
-- =======
function EP.CreateAndSelectNewNote()
  if S.currentBossFilter == "All" then
    if FRT.Print then FRT.Print("Pick a boss in the filter to create a note.") end
    return
  end
  local now = GetTime()
  local new = {
    id = genId(), raid = S.currentRaid, boss = S.currentBossFilter,
    title = "New Note", text = "", created = now, modified = now,
    version = 1, hash = Hash16(""),
    owner = (UnitName and UnitName("player")) or "me",
    source = "local",
    origin = "self",
  }
  table.insert(FRT_Saved.notes, new)
  S.currentId = new.id; S.uiSV.selectedId = new.id
  EP.RebuildList()
  EP.LoadSelected(new.id)
  if FRT.Print then FRT.Print("New note created.") end
end

function EP.SaveCurrent()
  if not S.editorEnabled then return end

  local data = GatherEditor()
  local now  = GetTime() or 0
  local noteRef

  if S.currentId then
    -- update existing
    local n = EP.FindNoteById(S.currentId)
    if n then
      n.title    = data.title
      n.text     = data.text
      n.modified = now
      n.version  = (tonumber(n.version) or 0) + 1
      n.hash     = Hash16(n.text or "")

      -- ensure provenance
      n.owner    = n.owner  or ((UnitName and UnitName("player")) or "me")
      n.source   = n.source or "local"
      n.origin   = n.origin or "self"

      noteRef    = n
    end
  else
    -- create new (must not be on "All" boss filter)
    if S.currentBossFilter == "All" then
      if FRT.Print then FRT.Print("Pick a boss in the filter to save this note.") end
      return
    end
    local me = (UnitName and UnitName("player")) or "me"
    local new = {
      id       = genId(),
      raid     = S.currentRaid,
      boss     = S.currentBossFilter,
      title    = data.title,
      text     = data.text,
      created  = now,
      modified = now,
      version  = 1,
      hash     = Hash16(data.text or ""),
      owner    = me,
      source   = "local",
      origin   = "self",
    }
    table.insert(FRT_Saved.notes, new)
    S.currentId = new.id
    S.uiSV.selectedId = new.id
    noteRef = new
    if FRT.Print then FRT.Print("New note created.") end
  end

  -- scratch mirrors the currently edited (and now saved) text
  FRT_Saved.note = data.text or ""

  -- broadcast to shared library (guild preferred; otherwise group)
  if noteRef and FRT.NoteNet and FRT.NoteNet.SendLibAdd then
    local meta = {
      id      = noteRef.id,
      version = noteRef.version or 1,
      hash    = noteRef.hash or Hash16(noteRef.text or ""),
      title   = noteRef.title or "",
      raid    = noteRef.raid  or "",
      boss    = noteRef.boss  or "",
    }
    local ch = PickChannel()
    if ch then
      FRT.NoteNet.SendLibAdd(meta, noteRef.text or "", ch)
    end
  end

  if FRT.Print then FRT.Print("Note saved.") end
  if EP.SnapBaseline then EP.SnapBaseline() end
  EP.RebuildList()
  if EP.UpdateButtonsState then EP.UpdateButtonsState() end
  EP.UpdateListSelection()

  -- keep live preview in sync
  if S.editor and S.editor.Refresh then S.editor.Refresh() end
  if FRT.Note and FRT.Note.UpdateViewerText then FRT.Note.UpdateViewerText() end
end

function EP.SaveAs()
  if not S.editorEnabled then return end
  local src = S.currentId and EP.FindNoteById(S.currentId); if not src then return end
  local now = GetTime() or 0
  local ed  = S.editor
  local text = (ed and ed.GetText and ed.GetText()) or ""

  local me = (UnitName and UnitName("player")) or "me"
  local copy = {
    id       = tostring(math.mod(math.floor(GetTime()*1000), 100000000))..tostring(math.random(100,999)),
    raid     = src.raid, boss = src.boss,
    title    = ((src.title or "") ~= "" and (src.title .. " (copy)")) or "New Note (copy)",
    text     = text,
    created  = now, modified = now,
    version  = 1,
    hash     = Hash16(text),
    owner    = me,
    source   = "local",
    origin   = "self",
  }
  table.insert(FRT_Saved.notes, copy)
  S.currentId = copy.id; S.uiSV.selectedId = copy.id
  if FRT.Print then FRT.Print("Note duplicated.") end
  if EP.SnapBaseline then EP.SnapBaseline() end
  EP.RebuildList()
  EP.LoadSelected(copy.id)

  -- publish to library immediately (like SaveCurrent does)
  if FRT.NoteNet and FRT.NoteNet.SendLibAdd then
    local meta = { id=copy.id, version=copy.version, hash=copy.hash, title=copy.title, raid=copy.raid, boss=copy.boss }
    FRT.NoteNet.SendLibAdd(meta, copy.text or "", (IsInGuild and IsInGuild() and "GUILD") or ((GetNumRaidMembers and (GetNumRaidMembers() or 0) > 0) and "RAID") or ((GetNumPartyMembers and (GetNumPartyMembers() or 0) > 0) and "PARTY") or nil)
  end

  if EP.UpdateButtonsState then EP.UpdateButtonsState() end
end

function EP.DeleteNote()
  if not S.currentId then
    if FRT.Print then FRT.Print("No note selected.") end
    return
  end

  local id = S.currentId
  local n, idx = EP.FindNoteById(id)
  if not idx then
    if FRT.Print then FRT.Print("Could not find selected note.") end
    return
  end

  S.pending.deleteId    = id
  S.pending.deleteIndex = idx

  local ttl = (n and n.title and n.title ~= "" and n.title) or "(untitled)"
  if EP.ShowBlocker then EP.ShowBlocker() end
  -- Pass a payload table; some clients don’t pass `self` reliably, so we also keep S.pending
  StaticPopup_Show("FRT_CONFIRM_DELETE_NOTE", ttl, nil, { id = id, index = idx })
end

function EP.CanShareNow()
  if not S.editorEnabled then return false end
  if not S.currentId then return false end
  local n = EP.FindNoteById(S.currentId); if not n then return false end
  if not (FRT and FRT.NoteNet and FRT.NoteNet.SendRef) then return false end
  -- channel check
  if (GetNumRaidMembers and (GetNumRaidMembers() or 0) > 0) then return true end
  if (GetNumPartyMembers and (GetNumPartyMembers() or 0) > 0) then return true end
  if IsInGuild and IsInGuild() then return true end
  return false
end

function EP.ShareCurrent()
  if not S.editorEnabled then return end

  -- If there are unsaved edits, save (this stamps version + hash and does LIBADD)
  if EP.IsDirty and EP.IsDirty() then
    EP.SaveCurrent()
  end

  if not S.currentId then if FRT.Print then FRT.Print("No note selected.") end return end
  local n = EP.FindNoteById(S.currentId); if not n then return end
  local meta = {
    id      = n.id,
    version = tonumber(n.version) or 1,
    hash    = n.hash or Hash16(n.text or ""),
    title   = n.title or "",
    raid    = n.raid  or "",
    boss    = n.boss  or "",
  }

  local ch = PickChannel()
  if not ch then if FRT.Print then FRT.Print("No group channel available for broadcast.") end return end

  if FRT.NoteNet and FRT.NoteNet.SendRef then
    FRT.NoteNet.SendRef(meta, ch)
    -- keep scratch in sync with what we just referenced
    FRT_Saved.note = n.text or ""
    if FRT.Print then
      FRT.Print(string.format("Broadcasted REF to %s: %s", ch, (meta.title ~= "" and meta.title) or "(untitled)"))
    end
  end
end

-- ==========
-- Popups/UX
-- ==========
StaticPopupDialogs = StaticPopupDialogs or {}

-- Unsaved changes when switching RAID
StaticPopupDialogs["FRT_UNSAVED_SWITCHRAID"] = {
  text = "You have unsaved changes. Save before switching raid?",
  button1 = "Save",
  button2 = "Discard",
  OnAccept = function()
    if EP.IsDirty and EP.IsDirty() and EP.SaveCurrent then EP.SaveCurrent() end
    if S.pending and S.pending.raidSwitch then
      local targetRaid = S.pending.raidSwitch; S.pending.raidSwitch = nil
      if not (FRT.RaidBosses and FRT.RaidBosses[targetRaid]) then
        targetRaid = EP.FirstRaidName()
      end
      S.currentRaid = targetRaid
      if S.uiSV then S.uiSV.selectedRaid = targetRaid end
      S.currentId = nil
      S.currentBossFilter = (S.uiSV and S.uiSV.selectedBossByRaid[S.currentRaid]) or "All"
      if CloseDropDownMenus then CloseDropDownMenus() end
      
      if EP.RebuildRaidDropdown       then EP.RebuildRaidDropdown()       end
      if EP.RebuildBossFilterDropdown then EP.RebuildBossFilterDropdown() end
      if EP.RebuildSourceDropdown     then EP.RebuildSourceDropdown()     end
      if EP.RebuildList               then EP.RebuildList()               end

      local filtered = (EP.GetFilteredNotes and EP.GetFilteredNotes()) or {}
      if table.getn(filtered) == 0 then
        S.currentId = nil; if S.uiSV then S.uiSV.selectedId = nil end
        if EP.LoadSelected then EP.LoadSelected(nil) end
      else
        S.currentId = filtered[1].id; if S.uiSV then S.uiSV.selectedId = S.currentId end
        if EP.LoadSelected then EP.LoadSelected(S.currentId) end
      end
    end
    if EP.HideBlocker then EP.HideBlocker() end
  end,
  OnCancel = function()
    -- Discard changes and still switch
    if S.pending and S.pending.raidSwitch then
      local targetRaid = S.pending.raidSwitch; S.pending.raidSwitch = nil
      if not (FRT.RaidBosses and FRT.RaidBosses[targetRaid]) then
        targetRaid = EP.FirstRaidName()
      end
      S.currentRaid = targetRaid
      if S.uiSV then S.uiSV.selectedRaid = targetRaid end
      S.currentId = nil
      S.currentBossFilter = (S.uiSV and S.uiSV.selectedBossByRaid[S.currentRaid]) or "All"

      if EP.RebuildRaidDropdown       then EP.RebuildRaidDropdown()       end
      if EP.RebuildBossFilterDropdown then EP.RebuildBossFilterDropdown() end
      if EP.RebuildSourceDropdown     then EP.RebuildSourceDropdown()     end
      if EP.RebuildList               then EP.RebuildList()               end

      local filtered = (EP.GetFilteredNotes and EP.GetFilteredNotes()) or {}
      if table.getn(filtered) == 0 then
        S.currentId = nil; if S.uiSV then S.uiSV.selectedId = nil end
        if EP.LoadSelected then EP.LoadSelected(nil) end
      else
        S.currentId = filtered[1].id; if S.uiSV then S.uiSV.selectedId = S.currentId end
        if EP.LoadSelected then EP.LoadSelected(S.currentId) end
      end
    end
    if EP.HideBlocker then EP.HideBlocker() end
  end,
  timeout = 0, whileDead = 1, hideOnEscape = 1, showAlert = 0,
}

-- Unsaved changes when switching NOTE / creating new / changing filters
StaticPopupDialogs["FRT_UNSAVED_SWITCHNOTE"] = {
  text = "You have unsaved changes. Save before changing selection?",
  button1 = "Save",
  button2 = "Discard",
  OnAccept = function()
    if EP.IsDirty and EP.IsDirty() and EP.SaveCurrent then EP.SaveCurrent() end

    if S.pending then
      if S.pending.noteIsNew then
        S.pending.noteIsNew = false
        if S.currentBossFilter ~= "All" and EP.CreateAndSelectNewNote then
          EP.CreateAndSelectNewNote()
        end
      elseif S.pending.noteSwitch then
        local id = S.pending.noteSwitch; S.pending.noteSwitch = nil
        if EP.LoadSelected then EP.LoadSelected(id) end
      elseif S.pending.bossFilter then
        local bf = S.pending.bossFilter; S.pending.bossFilter = nil
        if EP.ApplyBossFilter then EP.ApplyBossFilter(bf) end
      elseif S.pending.sourceFilter then
        local sf = S.pending.sourceFilter; S.pending.sourceFilter = nil
        if EP.ApplySourceFilter then EP.ApplySourceFilter(sf) end
      elseif S.pending.scopeFilter then
        local sf = S.pending.scopeFilter; S.pending.scopeFilter = nil
        if EP.ApplyScopeFilter then EP.ApplyScopeFilter(sf) end
      end
    end

    if EP.HideBlocker then EP.HideBlocker() end
  end,
  OnCancel = function()
    -- Discard changes and still perform the pending action
    if S.pending then
      if S.pending.noteIsNew then
        S.pending.noteIsNew = false
        if S.currentBossFilter ~= "All" and EP.CreateAndSelectNewNote then
          EP.CreateAndSelectNewNote()
        end
      elseif S.pending.noteSwitch then
        local id = S.pending.noteSwitch; S.pending.noteSwitch = nil
        if EP.LoadSelected then EP.LoadSelected(id) end
      elseif S.pending.bossFilter then
        local bf = S.pending.bossFilter; S.pending.bossFilter = nil
        if EP.ApplyBossFilter then EP.ApplyBossFilter(bf) end
      elseif S.pending.sourceFilter then
        local sf = S.pending.sourceFilter; S.pending.sourceFilter = nil
        if EP.ApplySourceFilter then EP.ApplySourceFilter(sf) end
      end
    end

    if EP.HideBlocker then EP.HideBlocker() end
  end,
  timeout = 0, whileDead = 1, hideOnEscape = 1, showAlert = 0,
}

-- Delete confirmation
StaticPopupDialogs["FRT_CONFIRM_DELETE_NOTE"] = {
  text = "Delete note: |cffffff00%s|r?\n|cffff4040This cannot be undone.|r",
  button1 = "Delete",
  button2 = "Cancel",
  OnAccept = function(self)
    local payload     = self and self.data
    local targetId    = (type(payload)=="table" and payload.id)    or (S.pending and S.pending.deleteId)
    local targetIndex = (type(payload)=="table" and payload.index) or (S.pending and S.pending.deleteIndex)

    -- Try by id first
    local _, delIndex = EP.FindNoteById and EP.FindNoteById(targetId)

    -- Fallback to the captured index if it still points to the same id
    if (not delIndex) and targetIndex and FRT_Saved.notes[targetIndex]
       and tostring(FRT_Saved.notes[targetIndex].id) == tostring(targetId) then
      delIndex = targetIndex
    end

    if delIndex then
      table.remove(FRT_Saved.notes, delIndex)
      if FRT.Print then FRT.Print("Note deleted.") end
      S.currentId = nil; if S.uiSV then S.uiSV.selectedId = nil end
      if EP.RebuildList then EP.RebuildList() end
      if EP.LoadSelected then EP.LoadSelected(nil) end
      if EP.UpdateButtonsState then EP.UpdateButtonsState() end
    else
      if FRT.Print then FRT.Print("Could not find note to delete.") end
    end

    if S.pending then S.pending.deleteId = nil; S.pending.deleteIndex = nil end
    if EP.HideBlocker then EP.HideBlocker() end
  end,
  OnCancel = function(self)
    if S.pending then S.pending.deleteId = nil; S.pending.deleteIndex = nil end
    if EP.HideBlocker then EP.HideBlocker() end
  end,
  timeout = 0, whileDead = 1, hideOnEscape = 1, showAlert = 0,
}

-- ===========
-- Drop-downs
-- ===========
function EP.ApplyBossFilter(val)
  S.currentBossFilter = val or "All"
  S.uiSV.selectedBossByRaid[S.currentRaid] = S.currentBossFilter
  if S.bossDD then
    UIDropDownMenu_SetSelectedValue(S.bossDD, S.currentBossFilter)
    UIDropDownMenu_SetText(S.currentBossFilter, S.bossDD)
  end

  if EP.RebuildList then EP.RebuildList() end

  local filtered = EP.GetFilteredNotes()
  if table.getn(filtered) == 0 then
    S.currentId = nil; S.uiSV.selectedId = nil
    EP.LoadSelected(nil)
  else
    local found = false
    for i=1, table.getn(filtered) do
      if filtered[i].id == S.currentId then found = true; break end
    end
    if not found then
      S.currentId = filtered[1].id; S.uiSV.selectedId = S.currentId
      EP.LoadSelected(S.currentId)
    end
  end
  if EP.UpdateButtonsState then EP.UpdateButtonsState() end
end

-- NEW: Source filter
function EP.ApplySourceFilter(val)
  S.currentSourceFilter = val or "All"
  S.uiSV.sourceFilter   = S.currentSourceFilter
  if S.sourceDD then
    UIDropDownMenu_SetSelectedValue(S.sourceDD, S.currentSourceFilter)
    UIDropDownMenu_SetText(S.currentSourceFilter, S.sourceDD)
  end
  if EP.RebuildList then EP.RebuildList() end
  if EP.UpdateButtonsState then EP.UpdateButtonsState() end
end

EP.ApplyScopeFilter = EP.ApplyScopeFilter or EP.ApplySourceFilter

local function InitBossFilterDropdown()
  local info

  info = {}
  info.text = "All bosses"
  info.value = "All"
  info.func = function()
    if EP.IsDirty and EP.IsDirty() then
      S.pending.bossFilter = "All"
      if EP.ShowBlocker then EP.ShowBlocker() end
      StaticPopup_Show("FRT_UNSAVED_SWITCHNOTE")
    else
      EP.ApplyBossFilter("All")
    end
  end
  info.checked = (S.currentBossFilter == "All")
  UIDropDownMenu_AddButton(info)

  local list = EP.BossList(S.currentRaid)
  for i=1, table.getn(list) do
    local val = list[i]
    info = {}
    info.text = val
    info.value = val
    info.func = function()
      if EP.IsDirty and EP.IsDirty() then
        S.pending.bossFilter = val
        if EP.ShowBlocker then EP.ShowBlocker() end
        StaticPopup_Show("FRT_UNSAVED_SWITCHNOTE")
      else
        EP.ApplyBossFilter(val)
      end
    end
    info.checked = (S.currentBossFilter == val)
    UIDropDownMenu_AddButton(info)
  end
end

local function InitSourceFilterDropdown()
  local opts = { "All", "Self", "Guild", "Outside" }
  for i=1, table.getn(opts) do
    local val = opts[i]
    local info = {}
    info.text  = (val == "All") and "All sources" or val
    info.value = val
    info.func  = function() EP.ApplySourceFilter(val) end
    info.checked = (S.currentSourceFilter == val)
    UIDropDownMenu_AddButton(info)
  end
end

function EP.RebuildBossFilterDropdown()
  EP.EnsureDropDownListFrames()
  UIDropDownMenu_Initialize(S.bossDD, InitBossFilterDropdown)
  -- validate filter
  local valid = (S.currentBossFilter == "All")
  if not valid then
    local list = EP.BossList(S.currentRaid)
    for i=1, table.getn(list) do if list[i] == S.currentBossFilter then valid = true; break end end
  end
  if not valid then S.currentBossFilter = "All" end
  EP.ApplyBossFilter(S.currentBossFilter)
end

function EP.RebuildSourceDropdown()
  EP.EnsureDropDownListFrames()
  UIDropDownMenu_Initialize(S.sourceDD, InitSourceFilterDropdown)
  UIDropDownMenu_SetSelectedValue(S.sourceDD, S.currentSourceFilter or "All")
  UIDropDownMenu_SetText(S.currentSourceFilter or "All", S.sourceDD)
end

function EP.ApplyRaid(val)
  if not val or val == "" then return end
  if EP.IsDirty and EP.IsDirty() then
    S.pending.raidSwitch = val
    if EP.ShowBlocker then EP.ShowBlocker() end
    StaticPopup_Show("FRT_UNSAVED_SWITCHRAID")
    return
  end

  if not (FRT.RaidBosses and FRT.RaidBosses[val]) then
    val = EP.FirstRaidName()
  end

  S.currentRaid = val
  S.uiSV.selectedRaid = val
  S.currentId = nil
  S.currentBossFilter = S.uiSV.selectedBossByRaid[S.currentRaid] or "All"

  -- IMPORTANT: do NOT call EP.RebuildRaidDropdown() here.
  -- The click handler already updated the selection text.

  if EP.RebuildBossFilterDropdown then EP.RebuildBossFilterDropdown() end
  if EP.RebuildSourceDropdown     then EP.RebuildSourceDropdown()     end
  if EP.RebuildList               then EP.RebuildList()               end

  local filtered = EP.GetFilteredNotes()
  if table.getn(filtered) == 0 then
    S.currentId = nil; S.uiSV.selectedId = nil
    EP.LoadSelected(nil)
  else
    S.currentId = filtered[1].id; S.uiSV.selectedId = S.currentId
    EP.LoadSelected(S.currentId)
  end
end

local function InitRaidDropdown()
  local raids = EP.RaidList()
  for i = 1, table.getn(raids) do
    local rname = raids[i]
    local info = {}
    info.text   = EP.GetRaidFullName(rname)
    info.value  = rname
    info.func   = function()
      -- Close the menu first to avoid re-entrancy issues.
      if CloseDropDownMenus then CloseDropDownMenus() end

      -- Update the visible label immediately.
      if S.raidDD then
        UIDropDownMenu_SetSelectedValue(S.raidDD, rname)
        UIDropDownMenu_SetText(EP.GetRaidFullName(rname), S.raidDD)
      end

      -- Apply WITHOUT re-initializing this same dropdown.
      EP.ApplyRaid(rname)
    end
    info.checked = (rname == S.currentRaid)
    UIDropDownMenu_AddButton(info)
  end
end

function EP.RebuildRaidDropdown()
  if not (S and S.raidDD) then return end
  EP.EnsureDropDownListFrames()
  UIDropDownMenu_Initialize(S.raidDD, InitRaidDropdown)
  UIDropDownMenu_SetSelectedValue(S.raidDD, S.currentRaid)
  UIDropDownMenu_SetText(EP.GetRaidFullName(S.currentRaid), S.raidDD)
end

-- =======
-- Buttons
-- =======
function EP.UpdateButtonsState()
  local b = S.buttons or {}
  if b.new then b.new:Enable() end
  if b.save then if S.editorEnabled and EP.IsDirty and EP.IsDirty() then b.save:Enable() else b.save:Disable() end end
  if b.dup  then if S.editorEnabled then b.dup:Enable() else b.dup:Disable() end end
  if b.del  then if S.editorEnabled then b.del:Enable() else b.del:Disable() end end
  if b.share then if EP.CanShareNow() then b.share:Enable() else b.share:Disable() end end
end

function EP.UpdateShareButtonState()
  EP.UpdateButtonsState()
end

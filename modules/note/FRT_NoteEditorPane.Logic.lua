-- Fingbel Raid Tool — Note Editor Pane (Logic)
-- Data helpers, dropdowns, list/filter, load/save/new/dup/del, share, popups

local FRT = FRT
local EP  = FRT.Note.EditorPane
local S   = EP.state

-- ============
-- Saved / data
-- ============
function EP.EnsureSaved()
  if type(FRT_Saved) ~= "table" then FRT_Saved = {} end
  FRT_Saved.notes = FRT_Saved.notes or {}
  FRT_Saved.ui    = FRT_Saved.ui or {}
  FRT_Saved.ui.notes = FRT_Saved.ui.notes or { selectedRaid = "Custom/Misc", selectedId = nil }
  FRT_Saved.ui.notes.selectedBossByRaid = FRT_Saved.ui.notes.selectedBossByRaid or {}
end

local function genId()
  local base = math.mod(math.floor(GetTime() * 1000), 100000000)
  return tostring(base) .. tostring(math.random(100,999))
end

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
  local arr = FRT_Saved.notes or {}
  for i=1, table.getn(arr) do
    if arr[i] and arr[i].id == id then return arr[i], i end
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
-- List / Sorting
-- ==============
function EP.GetFilteredNotes()
  local all = EP.NotesForRaid(S.currentRaid)
  if S.currentBossFilter == "All" then
    local out = {}
    for i=1, table.getn(all) do out[table.getn(out)+1] = all[i] end
    table.sort(out, function(a,b)
      local at = string.lower(a.title or ""); local bt = string.lower(b.title or "")
      if at == bt then
        return string.lower(a.boss or "") < string.lower(b.boss or "")
      end
      return at < bt
    end)
    return out
  else
    local out = {}
    for i=1, table.getn(all) do
      local n = all[i]
      if n.boss == S.currentBossFilter then out[table.getn(out)+1] = n end
    end
    table.sort(out, function(a,b)
      local at = string.lower(a.title or ""); local bt = string.lower(b.title or "")
      return at < bt
    end)
    return out
  end
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
    if EP.IsDirty() then
      S.pending.noteSwitch = targetId
      S.pending.noteIsNew  = false
      EP.ShowBlocker()
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
    local msg = (S.currentBossFilter == "All") and "(No notes in this raid)" or "(No notes for this boss)"
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

  -- Always keep the raw current so the viewer can parse from storage if needed
  if type(FRT_Saved) ~= "table" then FRT_Saved = {} end
  FRT_Saved.note = raw

  -- Best available render path
  if FRT.Note and FRT.Note.SetViewerRaw then
    FRT.Note.SetViewerRaw(raw)      -- tokenized path (preferred)
  elseif FRT.Note and FRT.Note.UpdateViewerText then
    FRT.Note.UpdateViewerText()     -- pulls from FRT_Saved.note and parses
  end
end

function EP.LoadSelected(id)
  S.currentId = id
  S.uiSV.selectedId = id
  EP.BeginSquelch()
  local n = id and EP.FindNoteById(id) or nil
  if n then
    if not (FRT.RaidBosses and FRT.RaidBosses[n.raid or ""]) then
      n.raid = EP.FirstRaidName()
    end
    if S.bossInfoLabel then S.bossInfoLabel:SetText(n.boss or "General") end
    if S.titleBox and S.titleBox.SetText then S.titleBox:SetText(n.title or "") end
    if S.editor and S.editor.SetText then S.editor.SetText(n.text or "") end
    EP.SetEditorEnabled(true)
  else
    if S.bossInfoLabel then S.bossInfoLabel:SetText("") end
    if S.titleBox and S.titleBox.SetText then S.titleBox:SetText("") end
    if S.editor and S.editor.SetText then S.editor.SetText("") end
    EP.SetEditorEnabled(false)
    S.baseline = nil
  end
  EP.EndSquelch()
  if S.editorEnabled then
    EP.SnapBaseline()
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
  local now  = GetTime()
  if S.currentId then
    local n = EP.FindNoteById(S.currentId)
    if n then
      n.title = data.title
      n.text  = data.text
      n.modified = now
    end
  else
    if S.currentBossFilter == "All" then
      if FRT.Print then FRT.Print("Pick a boss in the filter to save this note.") end
      return
    end
    local new = {
      id = genId(), raid = S.currentRaid, boss = S.currentBossFilter, title = data.title, text = data.text,
      created = now, modified = now,
    }
    table.insert(FRT_Saved.notes, new)
    S.currentId = new.id; S.uiSV.selectedId = new.id
  end
  if FRT.Print then FRT.Print("Note saved.") end
  EP.SnapBaseline()
  EP.RebuildList()
  if EP.UpdateButtonsState then EP.UpdateButtonsState() end
  EP.UpdateListSelection()
end

function EP.SaveAs()
  if not S.editorEnabled then return end
  local now  = GetTime()
  local src = S.currentId and EP.FindNoteById(S.currentId)
  if not src then return end
  local ed = S.editor
  local copy = {
    id = genId(), raid = src.raid, boss = src.boss,
    title = ((src.title or "") ~= "" and (src.title .. " (copy)")) or "New Note (copy)",
    text = (ed and ed.GetText and ed.GetText()) or "",
    created = now, modified = now,
  }
  table.insert(FRT_Saved.notes, copy)
  S.currentId = copy.id; S.uiSV.selectedId = copy.id
  if FRT.Print then FRT.Print("Note duplicated.") end
  EP.SnapBaseline()
  EP.RebuildList()
  EP.LoadSelected(copy.id)
  if EP.UpdateButtonsState then EP.UpdateButtonsState() end
end

function EP.DeleteNote()
  if not S.currentId then if FRT.Print then FRT.Print("No note selected.") end return end
  S.pending.deleteId = S.currentId
  local n = EP.FindNoteById(S.currentId)
  local ttl = (n and n.title and n.title ~= "" and n.title) and n.title or "(untitled)"
  EP.ShowBlocker()
  StaticPopup_Show("FRT_CONFIRM_DELETE_NOTE", ttl)
end

function EP.CanShareNow()
  if not S.editorEnabled then return false end
  local ed = S.editor
  local txt = (ed and ed.GetText and ed.GetText()) or ""
  if txt == "" then return false end
  if not (FRT and FRT.NoteNet and FRT.NoteNet.Send) then return false end
  if FRT.IsInRaid and FRT.IsInRaid() then
    return (FRT.IsLeaderOrOfficer and FRT.IsLeaderOrOfficer()) and true or false
  end
  if (GetNumPartyMembers and GetNumPartyMembers() or 0) > 0 then return true end
  if IsInGuild and IsInGuild() then return true end
  return false
end

function EP.ShareCurrent()
  if not S.editorEnabled then return end
  local ed = S.editor
  local txt = (ed and ed.GetText and ed.GetText()) or ""
  if txt == "" then if FRT.Print then FRT.Print("Nothing to share.") end return end
  if not (FRT and FRT.NoteNet and FRT.NoteNet.Send) then
    if FRT.Print then FRT.Print("Sharing unavailable (NoteNet not loaded).") end
    return
  end
  if (GetNumRaidMembers() or 0) > 0 then
    FRT.NoteNet.Send(txt, "RAID");  if FRT.Print then FRT.Print("Shared to RAID.") end
  elseif (GetNumPartyMembers() or 0) > 0 then
    FRT.NoteNet.Send(txt, "PARTY"); if FRT.Print then FRT.Print("Shared to PARTY.") end
  elseif IsInGuild and IsInGuild() then
    FRT.NoteNet.Send(txt, "GUILD"); if FRT.Print then FRT.Print("Shared to GUILD.") end
  else
    if FRT.Print then FRT.Print("You are not in a group.") end
  end
end

-- ==========
-- Popups/UX
-- ==========
StaticPopupDialogs = StaticPopupDialogs or {}

StaticPopupDialogs["FRT_UNSAVED_SWITCHRAID"] = {
  text = "You have unsaved changes. Save before switching raid?",
  button1 = "Save",
  button2 = "Discard",
  OnAccept = function()
    if EP.IsDirty() and EP.SaveCurrent then EP.SaveCurrent() end
    if S.pending.raidSwitch then
      local targetRaid = S.pending.raidSwitch; S.pending.raidSwitch = nil
      if not (FRT.RaidBosses and FRT.RaidBosses[targetRaid]) then
        targetRaid = EP.FirstRaidName()
      end
      S.currentRaid = targetRaid
      S.uiSV.selectedRaid = targetRaid
      S.currentId = nil
      S.currentBossFilter = S.uiSV.selectedBossByRaid[S.currentRaid] or "All"
      if EP.RebuildRaidDropdown then EP.RebuildRaidDropdown() end
      if EP.RebuildBossFilterDropdown then EP.RebuildBossFilterDropdown() end
      if EP.RebuildList then EP.RebuildList() end
      local filtered = EP.GetFilteredNotes()
      if table.getn(filtered) == 0 then
        S.currentId = nil; S.uiSV.selectedId = nil
        EP.LoadSelected(nil)
      else
        S.currentId = filtered[1].id; S.uiSV.selectedId = S.currentId
        EP.LoadSelected(S.currentId)
      end
    end
    EP.HideBlocker()
  end,
  OnCancel = function()
    if S.pending.raidSwitch then
      local targetRaid = S.pending.raidSwitch; S.pending.raidSwitch = nil
      if not (FRT.RaidBosses and FRT.RaidBosses[targetRaid]) then
        targetRaid = EP.FirstRaidName()
      end
      S.currentRaid = targetRaid
      S.uiSV.selectedRaid = targetRaid
      S.currentId = nil
      S.currentBossFilter = S.uiSV.selectedBossByRaid[S.currentRaid] or "All"
      if EP.RebuildRaidDropdown then EP.RebuildRaidDropdown() end
      if EP.RebuildBossFilterDropdown then EP.RebuildBossFilterDropdown() end
      if EP.RebuildList then EP.RebuildList() end
      local filtered = EP.GetFilteredNotes()
      if table.getn(filtered) == 0 then
        S.currentId = nil; S.uiSV.selectedId = nil
        EP.LoadSelected(nil)
      else
        S.currentId = filtered[1].id; S.uiSV.selectedId = S.currentId
        EP.LoadSelected(S.currentId)
      end
    end
    EP.HideBlocker()
  end,
  timeout = 0, whileDead = 1, hideOnEscape = 1, showAlert = 0,
}

StaticPopupDialogs["FRT_UNSAVED_SWITCHNOTE"] = {
  text = "You have unsaved changes. Save before changing selection?",
  button1 = "Save",
  button2 = "Discard",
  OnAccept = function()
    if EP.IsDirty() and EP.SaveCurrent then EP.SaveCurrent() end
    if S.pending.noteIsNew then
      if S.currentBossFilter ~= "All" then
        EP.CreateAndSelectNewNote()
      end
    elseif S.pending.noteSwitch then
      EP.LoadSelected(S.pending.noteSwitch)
    elseif S.pending.bossFilter then
      EP.ApplyBossFilter(S.pending.bossFilter)
    end
    S.pending.noteSwitch = nil
    S.pending.noteIsNew  = false
    S.pending.bossFilter = nil
    EP.HideBlocker()
  end,
  OnCancel = function()
    if S.pending.noteIsNew then
      EP.CreateAndSelectNewNote()
    elseif S.pending.noteSwitch then
      EP.LoadSelected(S.pending.noteSwitch)
    elseif S.pending.bossFilter then
      EP.ApplyBossFilter(S.pending.bossFilter)
    end
    S.pending.noteSwitch = nil
    S.pending.noteIsNew  = false
    S.pending.bossFilter = nil
    EP.HideBlocker()
  end,
  timeout = 0, whileDead = 1, hideOnEscape = 1, showAlert = 0,
}

StaticPopupDialogs["FRT_CONFIRM_DELETE_NOTE"] = {
  text = "Delete note: |cffffff00%s|r?\n|cffff4040This cannot be undone.|r",
  button1 = "Delete",
  button2 = "Cancel",
  OnAccept = function()
    if S.pending.deleteId then
      local _, delIndex = EP.FindNoteById(S.pending.deleteId)
      if delIndex then
        table.remove(FRT_Saved.notes, delIndex)
        if FRT.Print then FRT.Print("Note deleted.") end
        S.currentId = nil; S.uiSV.selectedId = nil
        EP.RebuildList()
        EP.LoadSelected(nil)
        if EP.UpdateButtonsState then EP.UpdateButtonsState() end
      end
      S.pending.deleteId = nil
    end
    EP.HideBlocker()
  end,
  OnCancel = function()
    S.pending.deleteId = nil
    EP.HideBlocker()
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

local function InitBossFilterDropdown()
  local info

  info = {}
  info.text = "All bosses"
  info.value = "All"
  info.func = function()
    if EP.IsDirty() then
      S.pending.bossFilter = "All"
      EP.ShowBlocker()
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
      if EP.IsDirty() then
        S.pending.bossFilter = val
        EP.ShowBlocker()
        StaticPopup_Show("FRT_UNSAVED_SWITCHNOTE")
      else
        EP.ApplyBossFilter(val)
      end
    end
    info.checked = (S.currentBossFilter == val)
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

function EP.ApplyRaid(val)
  if not val or val == "" then return end
  if EP.IsDirty() then
    S.pending.raidSwitch = val
    EP.ShowBlocker()
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
  if EP.RebuildRaidDropdown then EP.RebuildRaidDropdown() end
  if EP.RebuildBossFilterDropdown then EP.RebuildBossFilterDropdown() end
  if EP.RebuildList then EP.RebuildList() end
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
  for i=1, table.getn(raids) do
    local rname = raids[i]
    local info = {}
    info.text   = EP.GetRaidFullName(rname)
    info.value  = rname
    info.func   = function()
      UIDropDownMenu_SetSelectedValue(S.raidDD, rname)
      UIDropDownMenu_SetText(EP.GetRaidFullName(rname), S.raidDD)
      EP.ApplyRaid(rname)
    end
    info.checked = (rname == S.currentRaid)
    UIDropDownMenu_AddButton(info)
  end
end

function EP.RebuildRaidDropdown()
  EP.EnsureDropDownListFrames()
  UIDropDownMenu_Initialize(S.raidDD, InitRaidDropdown)
  UIDropDownMenu_SetSelectedValue(S.raidDD, S.currentRaid)
  UIDropDownMenu_SetText(EP.GetRaidFullName(S.currentRaid), S.raidDD)
end

-- =======
-- Buttons
-- =======
function EP.UpdateButtonsState()
  local b = S.buttons
  if b.new then b.new:Enable() end
  if b.save then if S.editorEnabled and EP.IsDirty() then b.save:Enable() else b.save:Disable() end end
  if b.dup  then if S.editorEnabled then b.dup:Enable() else b.dup:Disable() end end
  if b.del  then if S.editorEnabled then b.del:Enable() else b.del:Disable() end end
  if b.share then if EP.CanShareNow() then b.share:Enable() else b.share:Disable() end end
end

function EP.UpdateShareButtonState()
  EP.UpdateButtonsState()
end

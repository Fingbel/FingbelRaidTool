-- Fingbel Raid Tool - Note Editor Pane (Vanilla 1.12 / Lua 5.0)
-- Uses nicknames from FRT_RaidData.lua for raid tab buttons
-- Raid tab order follows FRT.RaidBosses._order; "Custom/Misc" is always placed last.

FRT = FRT or {}
FRT.Note = FRT.Note or {}
local Note = FRT.Note

-- ============================
-- Saved & static data helpers
-- ============================
local function EnsureSaved()
  if type(FRT_Saved) ~= "table" then FRT_Saved = {} end
  FRT_Saved.notes = FRT_Saved.notes or {}   -- array of { id, raid, boss, title, text, created, modified }
  FRT_Saved.ui = FRT_Saved.ui or {}
  FRT_Saved.ui.notes = FRT_Saved.ui.notes or { selectedRaid = "Custom/Misc", selectedId = nil }
end

-- Build an ordered raid list:
-- - If FRT.RaidBosses._order exists (array), follow it exactly (only include keys that actually exist)
-- - Append any remaining raid keys not in _order (before Misc)
-- - Ensure "Custom/Misc" exists and is placed last
local function RaidList()
  local raids = {}
  local RB = FRT.RaidBosses

  if RB then
    -- 1) Use _order if present
    if type(RB._order) == "table" and table.getn(RB._order) > 0 then
      for i = 1, table.getn(RB._order) do
        local rname = RB._order[i]
        if rname and RB[rname] and rname ~= "_order" then
          table.insert(raids, rname)
        end
      end
      -- 2) Add any missing keys not listed in _order (unordered; pairs)
      for k,_ in pairs(RB) do
        if k ~= "_order" then
          local found = false
          for i=1, table.getn(raids) do if raids[i] == k then found = true; break end end
          if not found then table.insert(raids, k) end
        end
      end
    else
      -- Fallback: collect keys (excluding _order) and sort alphabetically
      for k,_ in pairs(RB) do if k ~= "_order" then table.insert(raids, k) end end
      table.sort(raids)
    end
  end

  -- 3) Move/ensure "Custom/Misc" last
  local misc = "Custom/Misc"
  local hasMisc = false
  local miscIdx = nil
  for i=1, table.getn(raids) do
    if raids[i] == misc then hasMisc = true; miscIdx = i; break end
  end
  if miscIdx then table.remove(raids, miscIdx) end
  if (not RB) or RB[misc] then
    table.insert(raids, misc)
  end

  return raids
end

local function FirstRaidName()
  local raids = RaidList()
  if table.getn(raids) > 0 then return raids[1] end
  return "Custom/Misc"
end

local function BossList(raid)
  local entry = FRT.RaidBosses and FRT.RaidBosses[raid]
  if entry then
    if type(entry) == "table" and entry.bosses then
      return entry.bosses
    elseif type(entry) == "table" then
      -- backward compatibility if someone still provides a plain array
      return entry
    end
  end
  return { "General" }
end

local function FirstBoss(raid)
  local bl = BossList(raid)
  return (bl and bl[1]) and bl[1] or "General"
end

local function GetRaidNick(raid)
  local entry = FRT.RaidBosses and FRT.RaidBosses[raid]
  if entry and type(entry) == "table" and entry.nick then return entry.nick end
  return raid
end

local function GetRaidFullName(raid)
  local entry = FRT.RaidBosses and FRT.RaidBosses[raid]
  if entry and type(entry) == "table" and entry.name then return entry.name end
  return raid
end

local function BossOrderIndex(raid, boss)
  local list = BossList(raid)
  for i=1, table.getn(list) do
    if list[i] == boss then return i end
  end
  return 999
end

local function NextBoss(raid, current)
  local list = BossList(raid)
  local n = table.getn(list)
  if n == 0 then return current end
  local idx = BossOrderIndex(raid, current); if idx > n then idx = n end
  idx = idx + 1; if idx > n then idx = 1 end
  return list[idx]
end

local function genId()
  local base = math.mod(math.floor(GetTime() * 1000), 100000000)
  return tostring(base) .. tostring(math.random(100,999))
end

local function NotesForRaid(raid)
  local out = {}
  local arr = FRT_Saved.notes or {}
  for i=1, table.getn(arr) do
    local n = arr[i]
    if n and n.raid == raid then table.insert(out, n) end
  end
  table.sort(out, function(a,b)
    local ai = BossOrderIndex(raid, a.boss or "")
    local bi = BossOrderIndex(raid, b.boss or "")
    if ai ~= bi then return ai < bi end
    local at = string.lower(a.title or "")
    local bt = string.lower(b.title or "")
    return at < bt
  end)
  return out
end

local function FindNoteById(id)
  if not id then return nil end
  local arr = FRT_Saved.notes or {}
  for i=1, table.getn(arr) do
    if arr[i] and arr[i].id == id then return arr[i], i end
  end
  return nil
end

-- =========================
-- UI builder
-- =========================
function Note.BuildNoteEditorPane(parent)
  EnsureSaved()

  local uiSV  = FRT_Saved.ui.notes

  -- Validate selected raid against data
  local selRaid = uiSV.selectedRaid or "Custom/Misc"
  if not (FRT.RaidBosses and FRT.RaidBosses[selRaid]) then
    selRaid = FirstRaidName()
    uiSV.selectedRaid = selRaid
  end

  local currentRaid = selRaid
  local currentId   = uiSV.selectedId or nil
  local currentBoss = "General"

  -- forward locals for cross-calls + refs
  local RebuildList, LoadSelected, SaveCurrent, UpdateShareButtonState
  local bossBtn, titleBox, ed
  local btnSave, btnShare, btnDup, btnDel, btnNew
  local UpdateButtonsState

  -- editor enable/disable overlay
  local editorEnabled = false
  local right, rightOverlay, rightOverlayMsg

  -- baseline tracking + squelch
  local baseline = nil
  local suppressDirty = 0
  local function BeginSquelch() suppressDirty = suppressDirty + 1 end
  local function EndSquelch() if suppressDirty > 0 then suppressDirty = suppressDirty - 1 end end

  local function EditorSnapshot()
    local t = (ed and ed.GetText and (ed.GetText() or "")) or ""
    local ttl = (titleBox and titleBox.GetText and (titleBox:GetText() or "")) or ""
    return { raid=currentRaid, boss=(currentBoss or "General"), title=ttl, text=t }
  end
  local function SnapBaseline() baseline = EditorSnapshot() end
  local function IsDirty()
    if not editorEnabled then return false end
    if not baseline then return false end
    local cur = EditorSnapshot()
    return not (cur.raid == baseline.raid and cur.boss == baseline.boss and cur.title == baseline.title and cur.text == baseline.text)
  end
  local function UpdateDirtyFromUserEdit()
    if suppressDirty > 0 then return end
    if UpdateButtonsState then UpdateButtonsState() end
  end

  -- ==== Modal blocker
  local blocker = nil
  local function EnsureBlocker()
    if blocker then return end
    blocker = CreateFrame("Frame", nil, parent)
    blocker:SetAllPoints(parent)
    blocker:EnableMouse(true)
    blocker:SetFrameStrata("DIALOG")
    blocker:SetFrameLevel((parent:GetFrameLevel() or 0) + 200)
    local t = blocker:CreateTexture(nil, "BACKGROUND")
    t:SetAllPoints(blocker)
    t:SetTexture(0,0,0,0)
    blocker:Hide()
  end
  local function ShowBlocker()
    EnsureBlocker()
    if ed and ed.edit and ed.edit.ClearFocus then ed.edit:ClearFocus() end
    if titleBox and titleBox.ClearFocus then titleBox:ClearFocus() end
    blocker:Show()
  end
  local function HideBlocker() if blocker then blocker:Hide() end end
  EnsureBlocker()

  -- pending flows
  local pendingRaidSwitch, pendingNoteSwitch, pendingNoteIsNew, pendingDeleteId
  pendingRaidSwitch, pendingNoteSwitch, pendingNoteIsNew, pendingDeleteId = nil, nil, false, nil

  -- Title
  local title = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  title:SetPoint("TOP", 0, -10)
  title:SetText("Fingbel Raid Tool - Notes Editor")

  -- Raid tabs
  local tabs = CreateFrame("Frame", "FRT_RaidTabs", parent)
  tabs:SetPoint("TOPLEFT", 0, -26)
  tabs:SetPoint("TOPRIGHT", 0, -26)
  tabs:SetHeight(24)

  -- Forward decl
  local CreateAndSelectNewNote

  local function SwitchRaid(targetRaid, doSave)
    if doSave and IsDirty() and SaveCurrent then SaveCurrent() end
    if not (FRT.RaidBosses and FRT.RaidBosses[targetRaid]) then
      targetRaid = FirstRaidName()
    end
    currentRaid = targetRaid
    uiSV.selectedRaid = targetRaid
    currentId = nil
    if RebuildList then RebuildList() end
    if LoadSelected then LoadSelected(nil) end
  end

  local function SwitchNote(targetId, doSave, isNew)
    if doSave and IsDirty() and SaveCurrent then SaveCurrent() end
    if isNew then
      if CreateAndSelectNewNote then CreateAndSelectNewNote() end
    else
      if LoadSelected then LoadSelected(targetId) end
    end
  end

  -- Popups
  StaticPopupDialogs = StaticPopupDialogs or {}

  StaticPopupDialogs["FRT_UNSAVED_SWITCHRAID"] = {
    text = "You have unsaved changes. Save before switching raid?",
    button1 = "Save",
    button2 = "Discard",
    OnAccept = function()
      if pendingRaidSwitch then
        SwitchRaid(pendingRaidSwitch, true)
        pendingRaidSwitch = nil
      end
      HideBlocker()
    end,
    OnCancel = function()
      if pendingRaidSwitch then
        SwitchRaid(pendingRaidSwitch, false)
        pendingRaidSwitch = nil
      end
      HideBlocker()
    end,
    timeout = 0, whileDead = 1, hideOnEscape = 1, showAlert = 0,
  }

  StaticPopupDialogs["FRT_UNSAVED_SWITCHNOTE"] = {
    text = "You have unsaved changes. Save before switching note?",
    button1 = "Save",
    button2 = "Discard",
    OnAccept = function()
      if pendingNoteIsNew then
        if IsDirty() and SaveCurrent then SaveCurrent() end
        if CreateAndSelectNewNote then CreateAndSelectNewNote() end
      else
        SwitchNote(pendingNoteSwitch, true, false)
      end
      pendingNoteSwitch = nil
      pendingNoteIsNew  = false
      HideBlocker()
    end,
    OnCancel = function()
      if pendingNoteIsNew then
        if CreateAndSelectNewNote then CreateAndSelectNewNote() end
      else
        SwitchNote(pendingNoteSwitch, false, false)
      end
      pendingNoteSwitch = nil
      pendingNoteIsNew  = false
      HideBlocker()
    end,
    timeout = 0, whileDead = 1, hideOnEscape = 1, showAlert = 0,
  }

  StaticPopupDialogs["FRT_CONFIRM_DELETE_NOTE"] = {
    text = "Delete note: |cffffff00%s|r?\n|cffff4040This cannot be undone.|r",
    button1 = "Delete",
    button2 = "Cancel",
    OnAccept = function()
      if pendingDeleteId then
        local deleted, delIndex = FindNoteById(pendingDeleteId)
        if delIndex then
          table.remove(FRT_Saved.notes, delIndex)
          FRT.Print("Note deleted.")
          local notes = NotesForRaid(currentRaid)
          if table.getn(notes) > 0 then
            local pick = notes[delIndex]
            if not pick then pick = notes[table.getn(notes)] end
            currentId = pick.id; uiSV.selectedId = pick.id
            RebuildList()
            LoadSelected(pick.id)
          else
            currentId = nil; uiSV.selectedId = nil
            RebuildList()
            LoadSelected(nil)
          end
          if UpdateButtonsState then UpdateButtonsState() end
        end
        pendingDeleteId = nil
      end
      HideBlocker()
    end,
    OnCancel = function()
      pendingDeleteId = nil
      HideBlocker()
    end,
    timeout = 0, whileDead = 1, hideOnEscape = 1, showAlert = 0,
  }

  -- Build raid tabs using NICKNAMES for the labels, in RaidList() order
  local raidButtons = {}
  local function RebuildRaidTabsLocal()
    for _,b in pairs(raidButtons) do b:Hide() end
    raidButtons = {}
    local raids = RaidList()
    local prev
    for i=1, table.getn(raids) do
      local rname = raids[i]               -- full key
      local nick  = GetRaidNick(rname)     -- button label
      local full  = GetRaidFullName(rname) -- tooltip/full name

      local b = CreateFrame("Button", nil, tabs, "UIPanelButtonTemplate")
      b:SetHeight(20)
      b:SetWidth(math.max(60, string.len(nick) * 6 + 20))
      if prev then b:SetPoint("LEFT", prev, "RIGHT", 6, 0) else b:SetPoint("LEFT", 0, 0) end
      b:SetText(nick)

      b:SetScript("OnEnter", function()
        if full ~= nick and GameTooltip then
          GameTooltip:SetOwner(b, "ANCHOR_TOP")
          GameTooltip:SetText(full, 1,1,1)
          GameTooltip:Show()
        end
      end)
      b:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)

      b:SetScript("OnClick", function()
        if IsDirty() then
          pendingRaidSwitch = rname
          ShowBlocker()
          StaticPopup_Show("FRT_UNSAVED_SWITCHRAID")
        else
          SwitchRaid(rname, false)
        end
      end)
      raidButtons[rname] = b
      prev = b
    end
  end

  -- ==== Left: Note list ====
  local left = CreateFrame("Frame", "FRT_NoteList", parent)
  left:SetPoint("TOPLEFT", 0, -52)
  left:SetPoint("BOTTOMLEFT", 0, 28)
  left:SetWidth(220)
  left:SetBackdrop({
    bgFile   = "Interface\\ChatFrame\\ChatFrameBackground",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 12,
    insets   = { left=3, right=3, top=3, bottom=3 }
  })
  left:SetBackdropColor(0,0,0,0.4)

  local listHeader = left:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
  listHeader:SetPoint("TOPLEFT", 8, -6)
  listHeader:SetText("Notes for:")

  local listRaidName = left:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  listRaidName:SetPoint("LEFT", listHeader, "RIGHT", 6, 0)
  listRaidName:SetText(GetRaidFullName(currentRaid))

  local listScroll = CreateFrame("ScrollFrame", "FRT_NoteListScroll", left, "UIPanelScrollFrameTemplate")
  listScroll:SetPoint("TOPLEFT", 6, -24)
  listScroll:SetPoint("BOTTOMRIGHT", -28, 6)
  local listChild = CreateFrame("Frame", nil, listScroll)
  listChild:SetWidth(1); listChild:SetHeight(1)
  listScroll:SetScrollChild(listChild)

  local listButtons = {}
  local function ClearListButtons()
    for i=1, table.getn(listButtons) do if listButtons[i] then listButtons[i]:Hide() end end
    listButtons = {}
  end

  local function UpdateListSelection()
    for i=1, table.getn(listButtons) do
      local b = listButtons[i]
      if b and b.fs and b.id then
        if currentId and b.id == currentId then
          b:LockHighlight()
          if b.fs.SetFontObject then b.fs:SetFontObject(GameFontHighlight) end
        else
          b:UnlockHighlight()
          if b.fs.SetFontObject then b.fs:SetFontObject(GameFontNormal) end
        end
      end
    end
  end

  local function MakeItem(parentFrame, y, text, id, isBossHeader)
    local btn = CreateFrame("Button", nil, parentFrame)
    btn:SetPoint("TOPLEFT", 0, y)
    btn:SetWidth(180); btn:SetHeight(isBossHeader and 18 or 20)
    if isBossHeader then
      local fs = btn:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
      fs:SetPoint("LEFT", 2, 0); fs:SetText(text)
      btn.fs = fs
      btn:EnableMouse(false)
    else
      local fs = btn:CreateFontString(nil, "ARTWORK", "GameFontNormal")
      fs:SetPoint("LEFT", 2, 0); fs:SetText(text)
      btn.fs = fs
      btn.id = id
      btn:SetHighlightTexture("Interface\\Buttons\\UI-Listbox-Highlight2", "ADD")
      btn:SetScript("OnClick", function()
        local targetId = id
        if IsDirty() then
          pendingNoteSwitch = targetId
          pendingNoteIsNew  = false
          ShowBlocker()
          StaticPopup_Show("FRT_UNSAVED_SWITCHNOTE")
        else
          SwitchNote(targetId, false, false)
        end
      end)
    end
    table.insert(listButtons, btn)
    return btn
  end

  RebuildList = function()
    ClearListButtons()
    listRaidName:SetText(GetRaidFullName(currentRaid))
    local notes = NotesForRaid(currentRaid)
    local y = 0
    local lastBoss = "__NONE__"
    for i=1, table.getn(notes) do
      local n = notes[i]
      if (n.boss or "") ~= lastBoss then
        MakeItem(listChild, y, (n.boss or "General"), nil, true)
        y = y - 18
        lastBoss = n.boss or ""
      end
      local label = (n.title and n.title ~= "" and (n.boss or "General").." — "..n.title) or (n.boss or "General")
      MakeItem(listChild, y, label, n.id, false)
      y = y - 20
    end
    if y == 0 then
      MakeItem(listChild, y, "(No notes yet)", nil, true); y = y - 18
    end
    listChild:SetHeight(-y + 4)
    listChild:SetWidth(180)
    UpdateListSelection()
  end

  -- ==== Bottom bar ====
  local bottomBar = CreateFrame("Frame", "FRT_NoteEditor_BottomBar", parent)
  bottomBar:SetPoint("BOTTOMLEFT", 0, 0)
  bottomBar:SetPoint("BOTTOMRIGHT", 0, 0)
  bottomBar:SetHeight(36)

  local divider = bottomBar:CreateTexture(nil, "ARTWORK")
  divider:SetPoint("TOPLEFT", parent, "BOTTOMLEFT", 0, 1)
  divider:SetPoint("TOPRIGHT", parent, "BOTTOMRIGHT", 0, 1)
  divider:SetHeight(1)
  divider:SetTexture("Interface\\Buttons\\WHITE8x8")
  divider:SetVertexColor(1,1,1,0.10)

  -- ==== Right: Editor ====
  right = CreateFrame("Frame", "FRT_NoteEditorPane", parent)
  right:SetPoint("TOPLEFT", left, "TOPRIGHT", 10, 0)
  right:SetPoint("BOTTOMRIGHT", bottomBar, "TOPRIGHT", -14, 14)

  -- Disabled overlay
  rightOverlay = CreateFrame("Frame", nil, right)
  rightOverlay:SetAllPoints(right)
  rightOverlay:EnableMouse(true)
  rightOverlay:SetFrameStrata("DIALOG")
  rightOverlay:SetFrameLevel((right:GetFrameLevel() or 0) + 100)
  local rtex = rightOverlay:CreateTexture(nil, "BACKGROUND")
  rtex:SetAllPoints(rightOverlay)
  rtex:SetTexture(0,0,0,0.35)
  rightOverlayMsg = rightOverlay:CreateFontString(nil, "ARTWORK", "GameFontHighlightLarge")
  rightOverlayMsg:SetPoint("CENTER", 0, 0)
  rightOverlayMsg:SetText("No note selected")
  rightOverlay:Hide()

  local function SetEditorEnabled(flag)
    editorEnabled = flag and true or false
    if not editorEnabled then
      if titleBox and titleBox.ClearFocus then titleBox:ClearFocus() end
      if ed and ed.edit and ed.edit.ClearFocus then ed.edit:ClearFocus() end
      rightOverlay:Show()
    else
      rightOverlay:Hide()
    end
    if UpdateButtonsState then UpdateButtonsState() end
  end

  -- Boss row
  local bossLabel = right:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
  bossLabel:SetPoint("TOPLEFT", 0, 0); bossLabel:SetText("Boss:")

  bossBtn = CreateFrame("Button", "FRT_NoteEditor_BossBtn", right, "UIPanelButtonTemplate")
  bossBtn:SetPoint("LEFT", bossLabel, "RIGHT", 6, 0)
  bossBtn:SetWidth(160); bossBtn:SetHeight(20)
  bossBtn:SetText("General")
  currentBoss = "General"
  bossBtn:SetScript("OnClick", function()
    if not editorEnabled then return end
    currentBoss = NextBoss(currentRaid, currentBoss or "General")
    bossBtn:SetText(currentBoss)
    UpdateDirtyFromUserEdit()
  end)

  -- Title row
  local titleLabel = right:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
  titleLabel:SetPoint("TOPLEFT", bossLabel, "BOTTOMLEFT", 0, -8)
  titleLabel:SetText("Title:")

  titleBox = CreateFrame("EditBox", "FRT_NoteEditor_TitleBox", right, "InputBoxTemplate")
  titleBox:SetAutoFocus(false); titleBox:SetHeight(20); titleBox:SetWidth(260)
  titleBox:SetPoint("LEFT", titleLabel, "RIGHT", 6, 0)
  titleBox:SetText("")
  titleBox:SetScript("OnTextChanged", function()
    if not editorEnabled then return end
    UpdateDirtyFromUserEdit()
  end)

  -- Marker toolbar
  local toolbar = CreateFrame("Frame", "FRT_NoteEditor_Toolbar", right)
  toolbar:SetPoint("TOPLEFT", titleLabel, "BOTTOMLEFT", 0, -8)
  toolbar:SetPoint("RIGHT", right, "RIGHT", 0, 0)
  toolbar:SetHeight(22)

  local ICON_COORDS = {
    [1]={0.00,0.25,0.00,0.25}, [2]={0.25,0.50,0.00,0.25},
    [3]={0.50,0.75,0.00,0.25}, [4]={0.75,1.00,0.00,0.25},
    [5]={0.00,0.25,0.25,0.50}, [6]={0.25,0.50,0.25,0.50},
    [7]={0.50,0.75,0.25,0.50}, [8]={0.75,1.00,0.25,0.50},
  }
  local function MakeMarkerButton(parentFrame, index, anchor, xoff)
    local b = CreateFrame("Button", nil, parentFrame)
    b:SetWidth(22); b:SetHeight(22)
    if anchor then b:SetPoint("LEFT", anchor, "RIGHT", xoff or 2, 0) else b:SetPoint("LEFT", 0, 0) end
    local tex = b:CreateTexture(nil, "ARTWORK"); tex:SetAllPoints(b)
    tex:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcons")
    local c = ICON_COORDS[index]; if c then tex:SetTexCoord(c[1],c[2],c[3],c[4]) end
    b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    b._rtIndex = index
    return b
  end
  do
    local lastIcon
    for i=1,8 do
      lastIcon = MakeMarkerButton(toolbar, i, lastIcon, 2)
      lastIcon:SetScript("OnClick", function()
        if not editorEnabled then return end
        local idx = lastIcon._rtIndex or 1
        if not ed or not ed.edit or not ed.edit.Insert then return end
        ed.edit:SetFocus()
        ed.edit:Insert(string.format("{rt%d}", idx))
        if ed.Refresh then ed.Refresh() end
        UpdatePreviewFromEditor()
        UpdateDirtyFromUserEdit()
      end)
    end
  end

  -- Text editor (scrollable)
  local editArea = CreateFrame("Frame", nil, right)
  editArea:SetPoint("TOPLEFT", toolbar, "BOTTOMLEFT", 0, -8)
  editArea:SetPoint("BOTTOMRIGHT", bottomBar, "TOPRIGHT", 0, -8)

  local function CreateScrollableEdit_Fallback(parentFrame)
    local s = CreateFrame("ScrollFrame", nil, parentFrame, "UIPanelScrollFrameTemplate")
    s:SetPoint("TOPLEFT", 0, 0); s:SetPoint("BOTTOMRIGHT", 0, 0)
    local eb = CreateFrame("EditBox", nil, s)
    eb:SetMultiLine(true); eb:SetAutoFocus(false)
    eb:SetFontObject(ChatFontNormal)
    eb:SetWidth(parentFrame:GetWidth() - 24)
    eb:SetText("")
    s:SetScrollChild(eb)
    return {
      edit = eb,
      GetText = function() return eb:GetText() end,
      SetText = function(t) eb:SetText(t or "") end,
      Refresh = function() end,
    }
  end

  if FRT and FRT.Utils and FRT.Utils.CreateScrollableEdit then
    ed = FRT.Utils.CreateScrollableEdit(editArea, {
      name             = "FRT_NoteEditor_Scroll",
      rightColumnWidth = 20,
      padding          = 4,
      minHeight        = 200,
      insets           = { left=4, right=4, top=4, bottom=4 },
      fontObject       = "ChatFontNormal",
      background       = "Interface\\ChatFrame\\ChatFrameBackground",
      border           = "Interface\\Tooltips\\UI-Tooltip-Border",
      readonly         = false,
    })
  else
    ed = CreateScrollableEdit_Fallback(editArea)
  end

  -- Live preview helpers
  local function EnsureViewerVisible()
    if Note.EnsureViewer then Note.EnsureViewer() end
    if Note.ShowViewer then Note.ShowViewer() end
  end
  local function UpdatePreviewFromEditor()
    local raw = ed.GetText() or ""
    if Note.SetViewerRaw then
      Note.SetViewerRaw(raw)
    else
      if type(FRT_Saved) ~= "table" then FRT_Saved = {} end
      FRT_Saved.note = raw
      if Note.UpdateViewerText then Note.UpdateViewerText() end
    end
  end
  EnsureViewerVisible()

  if ed and ed.edit and ed.edit.SetScript then
    ed.edit:SetScript("OnTextChanged", function()
      if not editorEnabled then return end
      UpdatePreviewFromEditor()
      if ed.Refresh then ed.Refresh() end
      UpdateDirtyFromUserEdit()
    end)
  end

  -- Create & select new note (default title)
  CreateAndSelectNewNote = function()
    local now = GetTime()
    currentBoss = FirstBoss(currentRaid)
    local new = {
      id = genId(), raid = currentRaid, boss = currentBoss,
      title = "New Note", text = "", created = now, modified = now,
    }
    table.insert(FRT_Saved.notes, new)
    currentId = new.id; uiSV.selectedId = new.id
    RebuildList()
    LoadSelected(new.id)
    FRT.Print("New note created.")
  end

  -- Load/save/share
  function LoadSelected(id)
    currentId = id
    uiSV.selectedId = id
    BeginSquelch()
    local n = id and FindNoteById(id) or nil
    if n then
      if not (FRT.RaidBosses and FRT.RaidBosses[n.raid or ""]) then
        n.raid = FirstRaidName()
      end
      currentRaid = n.raid or currentRaid
      currentBoss = n.boss or FirstBoss(currentRaid)
      bossBtn:SetText(currentBoss)
      if titleBox and titleBox.SetText then titleBox:SetText(n.title or "") end
      ed.SetText(n.text or "")
      SetEditorEnabled(true)
    else
      bossBtn:SetText(FirstBoss(currentRaid))
      if titleBox and titleBox.SetText then titleBox:SetText("") end
      ed.SetText("")
      SetEditorEnabled(false)
      baseline = nil
    end
    EndSquelch()
    if editorEnabled then
      SnapBaseline()
      UpdatePreviewFromEditor()
    end
    if UpdateButtonsState then UpdateButtonsState() end
    UpdateListSelection()
  end

  local function GatherEditor()
    local t = ed and ed.GetText and (ed.GetText() or "") or ""
    local ttl = (titleBox and titleBox.GetText and (titleBox:GetText() or "")) or ""
    return { raid = currentRaid, boss = currentBoss or "General", title = ttl, text = t }
  end

  function SaveCurrent()
    if not editorEnabled then return end
    local data = GatherEditor()
    local now  = GetTime()
    if currentId then
      local n = FindNoteById(currentId)
      if n then
        n.raid = data.raid; n.boss = data.boss; n.title = data.title; n.text = data.text
        n.modified = now
      end
    else
      local new = {
        id = genId(), raid = data.raid, boss = data.boss, title = data.title, text = data.text,
        created = now, modified = now,
      }
      table.insert(FRT_Saved.notes, new)
      currentId = new.id; uiSV.selectedId = new.id
    end
    FRT.Print("Note saved.")
    SnapBaseline()
    RebuildList()
    if UpdateButtonsState then UpdateButtonsState() end
    UpdateListSelection()
  end

  local function SaveAs()  -- Duplicate
    if not editorEnabled then return end
    local data = GatherEditor()
    local now  = GetTime()
    local copy = {
      id = genId(), raid = data.raid, boss = data.boss, title = (data.title or "") .. " (copy)",
      text = data.text, created = now, modified = now,
    }
    table.insert(FRT_Saved.notes, copy)
    currentId = copy.id; uiSV.selectedId = copy.id
    FRT.Print("Note duplicated.")
    SnapBaseline()
    RebuildList()
    LoadSelected(copy.id)
    if UpdateButtonsState then UpdateButtonsState() end
  end

  local function NewNote()
    if IsDirty() then
      pendingNoteSwitch = nil
      pendingNoteIsNew  = true
      ShowBlocker()
      StaticPopup_Show("FRT_UNSAVED_SWITCHNOTE")
    else
      CreateAndSelectNewNote()
    end
  end

  private_DeleteNote = nil
  local function DeleteNote()
    if not currentId then FRT.Print("No note selected."); return end
    pendingDeleteId = currentId
    local n = FindNoteById(currentId)
    local ttl = (n and n.title and n.title ~= "" and n.title) and n.title or "(untitled)"
    ShowBlocker()
    StaticPopup_Show("FRT_CONFIRM_DELETE_NOTE", ttl)
  end

  local function CanShareNow()
    if not editorEnabled then return false end
    if not (FRT and FRT.NoteNet and FRT.NoteNet.Send) then return false end
    local txt = (ed and ed.GetText and ed.GetText()) or ""
    if txt == "" then return false end
    if FRT.IsInRaid and FRT.IsInRaid() then
      return (FRT.IsLeaderOrOfficer and FRT.IsLeaderOrOfficer()) and true or false
    end
    if (GetNumPartyMembers and GetNumPartyMembers() or 0) > 0 then return true end
    if IsInGuild and IsInGuild() then return true end
    return false
  end

  local function ShareCurrent()
    if not editorEnabled then return end
    local data = GatherEditor()
    if data.text == "" then FRT.Print("Nothing to share."); return end
    if not (FRT and FRT.NoteNet and FRT.NoteNet.Send) then
      FRT.Print("Sharing unavailable (NoteNet not loaded)."); return
    end
    if (GetNumRaidMembers() or 0) > 0 then
      FRT.NoteNet.Send(data.text, "RAID");  FRT.Print("Shared to RAID.")
    elseif (GetNumPartyMembers() or 0) > 0 then
      FRT.NoteNet.Send(data.text, "PARTY"); FRT.Print("Shared to PARTY.")
    elseif IsInGuild and IsInGuild() then
      FRT.NoteNet.Send(data.text, "GUILD"); FRT.Print("Shared to GUILD.")
    else
      FRT.Print("You are not in a group.")
    end
  end

  -- =========================
  -- Buttons + state
  -- =========================
  btnNew    = CreateFrame("Button", "FRT_NoteBtn_New", bottomBar, "UIPanelButtonTemplate")
  btnDup    = CreateFrame("Button", "FRT_NoteBtn_Dup", bottomBar, "UIPanelButtonTemplate")
  btnDel    = CreateFrame("Button", "FRT_NoteBtn_Del", bottomBar, "UIPanelButtonTemplate")
  btnSave   = CreateFrame("Button", "FRT_NoteBtn_Save", bottomBar, "UIPanelButtonTemplate")
  btnShare  = CreateFrame("Button", "FRT_NoteBtn_Share", bottomBar, "UIPanelButtonTemplate")

  UpdateButtonsState = function()
    if btnSave then if editorEnabled and IsDirty() then btnSave:Enable() else btnSave:Disable() end end
    if btnDup  then if editorEnabled then btnDup:Enable() else btnDup:Disable() end end
    if btnDel  then if editorEnabled then btnDel:Enable() else btnDel:Disable() end end
    if btnShare then if CanShareNow() then btnShare:Enable() else btnShare:Disable() end end
  end

  UpdateShareButtonState = function() UpdateButtonsState() end

  -- layout bottom buttons (Left: New/Duplicate/Delete; Right: Save/Share)
  btnNew:SetWidth(80);   btnNew:SetHeight(22);   btnNew:SetPoint("LEFT", 0, 0);                         btnNew:SetText("New")
  btnDup:SetWidth(80);   btnDup:SetHeight(22);   btnDup:SetPoint("LEFT", btnNew, "RIGHT", 6, 0);        btnDup:SetText("Duplicate")
  btnDel:SetWidth(80);   btnDel:SetHeight(22);   btnDel:SetPoint("LEFT", btnDup, "RIGHT", 6, 0);        btnDel:SetText("Delete")

  btnShare:SetWidth(80); btnShare:SetHeight(22); btnShare:SetPoint("RIGHT", bottomBar, "RIGHT", 0, 0);  btnShare:SetText("Share")
  btnSave:SetWidth(80);  btnSave:SetHeight(22);  btnSave:SetPoint("RIGHT", btnShare, "LEFT", -6, 0);    btnSave:SetText("Save")

  -- wire
  btnNew:SetScript("OnClick", NewNote)
  btnDup:SetScript("OnClick", SaveAs) -- Duplicate
  btnDel:SetScript("OnClick", DeleteNote)
  btnSave:SetScript("OnClick", function()
    if not editorEnabled then return end
    if titleBox and titleBox.ClearFocus then titleBox:ClearFocus() end
    if ed and ed.edit and ed.edit.ClearFocus then ed.edit:ClearFocus() end
    SaveCurrent()
  end)
  btnShare:SetScript("OnClick", ShareCurrent)

  -- events
  local watch = CreateFrame("Frame", nil, bottomBar)
  watch:RegisterEvent("PLAYER_ENTERING_WORLD")
  watch:RegisterEvent("PARTY_MEMBERS_CHANGED")
  watch:RegisterEvent("PARTY_LEADER_CHANGED")
  watch:RegisterEvent("RAID_ROSTER_UPDATE")
  watch:RegisterEvent("GUILD_ROSTER_UPDATE")
  watch:SetScript("OnEvent", function() if UpdateButtonsState then UpdateButtonsState() end end)

  -- Initial state
  UpdateButtonsState()

  -- Build UI
  RebuildRaidTabsLocal()
  RebuildList()
  if currentId and FindNoteById(currentId) then
    LoadSelected(currentId)
    -- warm-up popup
    local w = CreateFrame("Frame", nil, parent)
    w:SetScript("OnUpdate", function()
      w:SetScript("OnUpdate", nil)
      local popup = StaticPopup_Show("FRT_CONFIRM_DELETE_NOTE", "warmup")
      if popup then popup:Hide() end
      StaticPopup_Hide("FRT_CONFIRM_DELETE_NOTE")
    end)
  else
    LoadSelected(nil)
  end
end

function Note.ShowEditor()
  if FRT.IsInRaid and FRT.IsInRaid() and not (FRT.IsLeaderOrOfficer and FRT.IsLeaderOrOfficer()) then
    FRT.Print("Editor requires raid lead or assist.")
    return
  end
  if FRT and FRT.Editor and FRT.Editor.Show then
    FRT.Editor.Show("Note")
  else
    FRT.Print("Global editor not available.")
  end
end

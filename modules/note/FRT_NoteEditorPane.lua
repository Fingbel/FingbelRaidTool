-- Fingbel Raid Tool - Note Editor Pane (Vanilla 1.12 / Lua 5.0)

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
  FRT_Saved.ui.notes.selectedBossByRaid = FRT_Saved.ui.notes.selectedBossByRaid or {} -- raid -> "All" | boss
end

-- Build an ordered raid list
local function RaidList()
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

local function FirstRaidName()
  local raids = RaidList()
  if table.getn(raids) > 0 then return raids[1] end
  return "Custom/Misc"
end

local function BossList(raid)
  local entry = FRT.RaidBosses and FRT.RaidBosses[raid]
  if entry then
    if type(entry) == "table" and entry.bosses then return entry.bosses
    elseif type(entry) == "table" then return entry end -- plain array fallback
  end
  return { "General" }
end

local function GetRaidFullName(raid)
  local entry = FRT.RaidBosses and FRT.RaidBosses[raid]
  if entry and type(entry) == "table" and entry.name then return entry.name end
  return raid
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

local function EnsureDropDownListFrames()
  if not DropDownList1 then
    if UIDropDownMenu_CreateFrames then
      UIDropDownMenu_CreateFrames(1, 1) -- Args: maxLevels, maxButtons
    else
      local tmp = CreateFrame("Frame", nil, UIParent, "UIDropDownMenuTemplate")
      ToggleDropDownMenu(1, nil, tmp); ToggleDropDownMenu(1, nil, tmp)
      tmp:Hide()
    end
  end
end

-- =========================
-- UI builder
-- =========================
function Note.BuildNoteEditorPane(parent)
  EnsureSaved()

  -- ==== Top header (title bar) ====
  local header = CreateFrame("Frame", "FRT_NoteEditor_Header", parent)
  header:SetPoint("TOPLEFT", 0, 24)
  header:SetPoint("TOPRIGHT", 0, 0)
  header:SetHeight(26)

  -- subtle underline
  local hdiv = header:CreateTexture(nil, "ARTWORK")
  hdiv:SetPoint("BOTTOMLEFT", header, "BOTTOMLEFT", 0, 0)
  hdiv:SetPoint("BOTTOMRIGHT", header, "BOTTOMRIGHT", 0, 0)
  hdiv:SetHeight(1)
  hdiv:SetTexture("Interface\\Buttons\\WHITE8x8")
  hdiv:SetVertexColor(1, 1, 1, 0.10)

  -- title text
  local titleFS = header:CreateFontString(nil, "ARTWORK", "GameFontHighlightLarge")
  titleFS:SetPoint("CENTER",header, "CENTER", -50, 0)
  titleFS:SetText("Raid Notes")
  
  -- ==== Bottom bar  ====
  local bottomBar = CreateFrame("Frame", "FRT_NoteEditor_BottomBar", parent)
  bottomBar:SetPoint("BOTTOMLEFT", 0, 0)
  bottomBar:SetPoint("BOTTOMRIGHT", 0, 0)
  bottomBar:SetHeight(40)

  local uiSV  = FRT_Saved.ui.notes

  -- Validate selected raid
  local selRaid = uiSV.selectedRaid or "Custom/Misc"
  if not (FRT.RaidBosses and FRT.RaidBosses[selRaid]) then
    selRaid = FirstRaidName()
    uiSV.selectedRaid = selRaid
  end

  local currentRaid        = selRaid
  local currentId          = uiSV.selectedId or nil
  local currentBossFilter  = uiSV.selectedBossByRaid[currentRaid] or "All"  -- "All" or a boss name
  local pendingBossFilter  = nil

  local bossPicker, bossPickDD, bossPickValue
  local ApplyBossFilter, RebuildBossFilterDropdown
  local CreateAndSelectNewNote

  -- forward locals (functions assigned later)
  local RebuildList, LoadSelected, SaveCurrent
  local RebuildRaidDropdown
  local titleBox, ed
  local btnSave, btnShare, btnDup, btnDel, btnNew
  local UpdateButtonsState, UpdateShareButtonState
  local UpdatePreviewFromEditor
  local bossInfoLabel

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
    return { id = currentId, title = ttl, text = t }
  end
  local function SnapBaseline() baseline = EditorSnapshot() end
  local function IsDirty()
    if not editorEnabled then return false end
    if not baseline then return false end
    local cur = EditorSnapshot()
    if cur.id ~= baseline.id then return false end
    return not (cur.title == baseline.title and cur.text == baseline.text)
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

  -- container for the whole left side
  local leftColumn = CreateFrame("Frame", "FRT_NoteLeftColumn", parent)
  leftColumn:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -15)
  leftColumn:SetPoint("BOTTOMLEFT", bottomBar, "TOPLEFT", 0, 0)
  leftColumn:SetWidth(200)

    -- ==== Right: Editor ====
  right = CreateFrame("Frame", "FRT_NoteEditorPane", parent)
  right:SetPoint("TOPLEFT", leftColumn, "TOPRIGHT", 12, 0)
  right:SetPoint("BOTTOMRIGHT", bottomBar, "TOPRIGHT", -14, 0)

  -- ==== Raid selector bar (dropdown) ====
  local raidBar = CreateFrame("Frame", "FRT_RaidBar", leftColumn)
  raidBar:SetPoint("TOPLEFT",  leftColumn, "TOPLEFT",  0, 0)
  raidBar:SetPoint("TOPRIGHT", leftColumn, "TOPRIGHT", 0, 0)
  raidBar:SetHeight(22)

  local raidLabel = raidBar:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
  raidLabel:SetPoint("LEFT", 0, 0)
  raidLabel:SetText("Raid:")

  local raidDD = CreateFrame("Frame", "FRT_NoteFilter_RaidDropDown", raidBar, "UIDropDownMenuTemplate")
  raidDD:SetPoint("LEFT", raidLabel, "RIGHT", -6, 2)
  UIDropDownMenu_SetWidth(130, raidDD)      -- (width, frame) ordering in 1.12
  UIDropDownMenu_JustifyText("LEFT", raidDD)

  -- Boss Filter Bar (under the raid bar)
  local filterBar = CreateFrame("Frame", "FRT_NoteFilterBar", raidBar)
  filterBar:SetPoint("TOPLEFT", raidBar, "BOTTOMLEFT", 0, -8)
  filterBar:SetPoint("TOPRIGHT", raidBar, "BOTTOMRIGHT", 0, -8)
  filterBar:SetHeight(22)

  local bossFilterLabel = filterBar:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
  bossFilterLabel:SetPoint("LEFT", 0, 0)
  bossFilterLabel:SetText("Boss:")

  local bossFilterDD = CreateFrame("Frame", "FRT_NoteFilter_BossDropDown", filterBar, "UIDropDownMenuTemplate")
  bossFilterDD:SetPoint("LEFT", bossFilterLabel, "RIGHT", -6, 2)
  UIDropDownMenu_SetWidth(130, bossFilterDD)
  UIDropDownMenu_JustifyText("LEFT", bossFilterDD)

  -- Apply boss filter
  ApplyBossFilter = function(val)
    currentBossFilter = val or "All"
    uiSV.selectedBossByRaid[currentRaid] = currentBossFilter
    UIDropDownMenu_SetSelectedValue(bossFilterDD, currentBossFilter)
    UIDropDownMenu_SetText(currentBossFilter, bossFilterDD)

    if RebuildList then RebuildList() end

    local filtered = (function()
      local all = NotesForRaid(currentRaid)
      if currentBossFilter == "All" then
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
          if n.boss == currentBossFilter then out[table.getn(out)+1] = n end
        end
        table.sort(out, function(a,b)
          local at = string.lower(a.title or ""); local bt = string.lower(b.title or "")
          return at < bt
        end)
        return out
      end
    end)()

    if table.getn(filtered) == 0 then
      currentId = nil; uiSV.selectedId = nil
      LoadSelected(nil)
    else
      local found = false
      for i=1, table.getn(filtered) do
        if filtered[i].id == currentId then found = true; break end
      end
      if not found then
        currentId = filtered[1].id; uiSV.selectedId = currentId
        LoadSelected(currentId)
      end
    end
    if UpdateButtonsState then UpdateButtonsState() end
  end

  local function InitBossFilterDropdown()
    local info

    info = {}
    info.text = "All bosses"
    info.value = "All"
    info.func = function()
      if IsDirty() then
        pendingBossFilter = "All"
        ShowBlocker()
        StaticPopup_Show("FRT_UNSAVED_SWITCHNOTE")
      else
        ApplyBossFilter("All")
      end
    end
    info.checked = (currentBossFilter == "All")
    UIDropDownMenu_AddButton(info)

    local list = BossList(currentRaid)
    for i=1, table.getn(list) do
      local val = list[i]
      info = {}
      info.text = val
      info.value = val
      info.func = function()
        if IsDirty() then
          pendingBossFilter = val
          ShowBlocker()
          StaticPopup_Show("FRT_UNSAVED_SWITCHNOTE")
        else
          ApplyBossFilter(val)
        end
      end
      info.checked = (currentBossFilter == val)
      UIDropDownMenu_AddButton(info)
    end
  end

  RebuildBossFilterDropdown = function()
    EnsureDropDownListFrames()
    UIDropDownMenu_Initialize(bossFilterDD, InitBossFilterDropdown)
    -- validate currentBossFilter against raid bosses
    local valid = (currentBossFilter == "All")
    if not valid then
      local list = BossList(currentRaid)
      for i=1, table.getn(list) do if list[i] == currentBossFilter then valid = true; break end end
    end
    if not valid then currentBossFilter = "All" end
    ApplyBossFilter(currentBossFilter)
  end

  -- ==== Left: Note list (with backdrop) ====
  local left = CreateFrame("Frame", "FRT_NoteList", leftColumn)
    left:SetPoint("TOPLEFT",  filterBar, "BOTTOMLEFT", 0, -2)  -- top anchored under Boss dropdown
  left:SetPoint("BOTTOMLEFT", 0, 0)                          -- bottom pinned to leftColumn

  left:SetWidth(200)
  left:SetBackdrop({
    bgFile   = "Interface\\ChatFrame\\ChatFrameBackground",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 12,
    insets   = { left=3, right=3, top=3, bottom=3 }
  })
  left:SetBackdropColor(0,0,0,0.4)

  local listScroll = CreateFrame("ScrollFrame", "FRT_NoteListScroll", left, "UIPanelScrollFrameTemplate")
  listScroll:SetPoint("TOPLEFT", 6, -6)
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

  local function MakeRow(parentFrame, y, text, id)
    local btn = CreateFrame("Button", nil, parentFrame)
    btn:SetPoint("TOPLEFT", 0, y)
    btn:SetWidth(180); btn:SetHeight(18)

    local fs = btn:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    fs:SetPoint("LEFT", 10, 0) -- small indent
    fs:SetText(text)
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
        if LoadSelected then LoadSelected(targetId) end
      end
    end)

    table.insert(listButtons, btn)
    return btn
  end

  -- filter + sort
  local function GetFilteredNotes()
    local all = NotesForRaid(currentRaid)
    if currentBossFilter == "All" then
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
        if n.boss == currentBossFilter then out[table.getn(out)+1] = n end
      end
      table.sort(out, function(a,b)
        local at = string.lower(a.title or ""); local bt = string.lower(b.title or "")
        return at < bt
      end)
      return out
    end
  end

  RebuildList = function()
    ClearListButtons()
    listScroll:SetVerticalScroll(0)

    local filtered = GetFilteredNotes()
    local y = 0
    if table.getn(filtered) == 0 then
      local msg = (currentBossFilter == "All") and "(No notes in this raid)" or "(No notes for this boss)"
      local btn = CreateFrame("Button", nil, listChild)
      btn:SetPoint("TOPLEFT", 0, y)
      btn:SetWidth(180); btn:SetHeight(18)
      local fs = btn:CreateFontString(nil, "ARTWORK", "GameFontDisable")
      fs:SetPoint("LEFT", 10, 0); fs:SetText(msg)
      btn.fs = fs; btn:EnableMouse(false)
      table.insert(listButtons, btn)
      y = y - 18
    else
      for i=1, table.getn(filtered) do
        local n = filtered[i]
        local ttl = tostring(n.title or "")
        ttl = string.gsub(ttl, "^%s*(.-)%s*$", "%1")
        if ttl == "" then ttl = "(untitled)" end
        if currentBossFilter == "All" and n.boss and n.boss ~= "" then
          ttl = ttl .. "  |cffffd200[" .. n.boss .. "]|r"
        end
        MakeRow(listChild, y, ttl, n.id)
        y = y - 18
      end
    end

    listChild:SetHeight(-y + 4)
    listChild:SetWidth(180)
    UpdateListSelection()
  end

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

  -- Title row + Boss info (read-only)
  local bossInfoLabelCaption = right:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
  bossInfoLabelCaption:SetPoint("TOPLEFT", 0, 0)
  bossInfoLabelCaption:SetText("Boss:")

  bossInfoLabel = right:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  bossInfoLabel:SetPoint("LEFT", bossInfoLabelCaption, "RIGHT", 6, 0)
  bossInfoLabel:SetText("")

  local titleLabel = right:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
  titleLabel:SetPoint("TOPLEFT", bossInfoLabelCaption, "BOTTOMLEFT", 0, -8)
  titleLabel:SetText("Title:")
  titleLabel:SetWidth(120)

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
  editArea:SetPoint("BOTTOMRIGHT", right, "BOTTOMRIGHT", 0, 0)

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

  -- Live preview helpers
  local function EnsureViewerVisible()
    if Note.EnsureViewer then Note.EnsureViewer() end
    if Note.ShowViewer then Note.ShowViewer() end
  end
  UpdatePreviewFromEditor = function()
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

  -- Create & select new note (boss taken from currentBossFilter)
  CreateAndSelectNewNote = function()
    if currentBossFilter == "All" then
      FRT.Print("Pick a boss in the filter to create a note.")
      return
    end
    local now = GetTime()
    local new = {
      id = genId(), raid = currentRaid, boss = currentBossFilter,
      title = "New Note", text = "", created = now, modified = now,
    }
    table.insert(FRT_Saved.notes, new)
    currentId = new.id; uiSV.selectedId = new.id
    RebuildList()
    LoadSelected(new.id)
    FRT.Print("New note created.")
  end

  -- Load/save/share
  LoadSelected = function(id)
    currentId = id
    uiSV.selectedId = id
    BeginSquelch()
    local n = id and FindNoteById(id) or nil
    if n then
      if not (FRT.RaidBosses and FRT.RaidBosses[n.raid or ""]) then
        n.raid = FirstRaidName()
      end
      if bossInfoLabel then bossInfoLabel:SetText(n.boss or "General") end
      if titleBox and titleBox.SetText then titleBox:SetText(n.title or "") end
      ed.SetText(n.text or "")
      SetEditorEnabled(true)
    else
      if bossInfoLabel then bossInfoLabel:SetText("") end
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
    return { raid = currentRaid, title = ttl, text = t }
  end

  SaveCurrent = function()
    if not editorEnabled then return end
    local data = GatherEditor()
    local now  = GetTime()
    if currentId then
      local n = FindNoteById(currentId)
      if n then
        n.title = data.title
        n.text = data.text
        n.modified = now
      end
    else
      if currentBossFilter == "All" then
        FRT.Print("Pick a boss in the filter to save this note.")
        return
      end
      local new = {
        id = genId(), raid = currentRaid, boss = currentBossFilter, title = data.title, text = data.text,
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

  local function SaveAs()  -- Duplicate (keep original boss/raid)
    if not editorEnabled then return end
    local now  = GetTime()
    local src = currentId and FindNoteById(currentId)
    if not src then return end
    local copy = {
      id = genId(), raid = src.raid, boss = src.boss,
      title = ((src.title or "") ~= "" and (src.title .. " (copy)")) or "New Note (copy)",
      text = (ed and ed.GetText and ed.GetText()) or "",
      created = now, modified = now,
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
      return
    end
    if currentBossFilter == "All" then
      -- show a simple boss picker
      local function ShowBossPicker()
        if not bossPicker then
          bossPicker = CreateFrame("Frame", "FRT_BossPicker", UIParent)
          bossPicker:SetFrameStrata("DIALOG")
          bossPicker:SetToplevel(true)
          bossPicker:SetWidth(320); bossPicker:SetHeight(130)
          bossPicker:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
          bossPicker:SetBackdrop({
            bgFile   = "Interface\\ChatFrame\\ChatFrameBackground",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 12,
            insets   = { left=4, right=4, top=4, bottom=4 }
          })
          bossPicker:SetBackdropColor(0,0,0,0.8)

          local title = bossPicker:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
          title:SetPoint("TOP", 0, -10)
          title:SetText("Select boss for new note")

          local lbl = bossPicker:CreateFontString(nil, "ARTWORK", "GameFontNormal")
          lbl:SetPoint("TOPLEFT", 16, -40)
          lbl:SetText("Boss:")

          bossPickDD = CreateFrame("Frame", "FRT_BossPicker_DropDown", bossPicker, "UIDropDownMenuTemplate")
          bossPickDD:SetPoint("LEFT", lbl, "RIGHT", -6, -2)
          UIDropDownMenu_SetWidth(180, bossPickDD)
          UIDropDownMenu_JustifyText("LEFT", bossPickDD)

          local function InitPick()
            local list = BossList(currentRaid)
            for i=1, table.getn(list) do
              local val = list[i]
              local info = {}
              info.text = val
              info.value = val
              info.func = function()
                bossPickValue = val
                UIDropDownMenu_SetSelectedValue(bossPickDD, bossPickValue)
                UIDropDownMenu_SetText(bossPickValue or "", bossPickDD)
              end
              info.checked = (bossPickValue == val)
              UIDropDownMenu_AddButton(info)
            end
          end
          UIDropDownMenu_Initialize(bossPickDD, InitPick)

          local ok = CreateFrame("Button", nil, bossPicker, "UIPanelButtonTemplate")
          ok:SetWidth(90); ok:SetHeight(22)
          ok:SetPoint("BOTTOMRIGHT", -16, 14)
          ok:SetText("Create")
          ok:SetScript("OnClick", function()
            if bossPickValue and bossPickValue ~= "" then
              if bossPickValue ~= currentBossFilter then
                ApplyBossFilter(bossPickValue)
              end
              bossPicker:Hide()
              CreateAndSelectNewNote()
            end
          end)

          local cancel = CreateFrame("Button", nil, bossPicker, "UIPanelButtonTemplate")
          cancel:SetWidth(90); cancel:SetHeight(22)
          cancel:SetPoint("RIGHT", ok, "LEFT", -6, 0)
          cancel:SetText("Cancel")
          cancel:SetScript("OnClick", function() bossPicker:Hide() end)

          bossPicker:Hide()
          bossPicker._prepare = function()
            EnsureDropDownListFrames()
            local list = BossList(currentRaid)
            bossPickValue = (table.getn(list) > 0) and list[1] or "General"
            UIDropDownMenu_SetSelectedValue(bossPickDD, bossPickValue)
            UIDropDownMenu_SetText(bossPickValue or "", bossPickDD)
          end
        end
        bossPicker:_prepare()
        bossPicker:Show()
      end
      ShowBossPicker()
    else
      CreateAndSelectNewNote()
    end
  end

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

  local function ShareCurrent()
    if not editorEnabled then return end
    local txt = (ed and ed.GetText and ed.GetText()) or ""
    if txt == "" then FRT.Print("Nothing to share."); return end
    if not (FRT and FRT.NoteNet and FRT.NoteNet.Send) then
      FRT.Print("Sharing unavailable (NoteNet not loaded)."); return
    end
    if (GetNumRaidMembers() or 0) > 0 then
      FRT.NoteNet.Send(txt, "RAID");  FRT.Print("Shared to RAID.")
    elseif (GetNumPartyMembers() or 0) > 0 then
      FRT.NoteNet.Send(txt, "PARTY"); FRT.Print("Shared to PARTY.")
    elseif IsInGuild and IsInGuild() then
      FRT.NoteNet.Send(txt, "GUILD"); FRT.Print("Shared to GUILD.")
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
    if btnNew  then  btnNew:Enable() end
    if btnSave then if editorEnabled and IsDirty() then btnSave:Enable() else btnSave:Disable() end end
    if btnDup  then if editorEnabled then btnDup:Enable() else btnDup:Disable() end end
    if btnDel  then if editorEnabled then btnDel:Enable() else btnDel:Disable() end end
    if btnShare then if CanShareNow() then btnShare:Enable() else btnShare:Disable() end end
  end

  UpdateShareButtonState = function() UpdateButtonsState() end

  -- layout bottom buttons (Left: New/Duplicate/Delete; Right: Save/Share)
  btnNew:SetWidth(62);   btnNew:SetHeight(22);   btnNew:SetPoint("LEFT", 0, 0);                         btnNew:SetText("New")
  btnDup:SetWidth(62);   btnDup:SetHeight(22);   btnDup:SetPoint("LEFT", btnNew, "RIGHT", 6, 0);        btnDup:SetText("Duplicate")
  btnDel:SetWidth(62);   btnDel:SetHeight(22);   btnDel:SetPoint("LEFT", btnDup, "RIGHT", 6, 0);        btnDel:SetText("Delete")

  btnShare:SetWidth(80); btnShare:SetHeight(22); btnShare:SetPoint("RIGHT", bottomBar, "RIGHT", -12, 0);  btnShare:SetText("Share")
  btnSave:SetWidth(80);  btnSave:SetHeight(22);  btnSave:SetPoint("RIGHT", btnShare, "LEFT", -6, 0);    btnSave:SetText("Save")

  -- wire
  btnNew:SetScript("OnClick", NewNote)
  btnDup:SetScript("OnClick", SaveAs)
  btnDel:SetScript("OnClick", DeleteNote)
  btnSave:SetScript("OnClick", function()
    if not editorEnabled then return end
    if titleBox and titleBox.ClearFocus then titleBox:ClearFocus() end
    if ed and ed.edit and ed.edit.ClearFocus then ed.edit:ClearFocus() end
    SaveCurrent()
  end)
  btnShare:SetScript("OnClick", ShareCurrent)

  -- ==== Popups
  StaticPopupDialogs = StaticPopupDialogs or {}

  StaticPopupDialogs["FRT_UNSAVED_SWITCHRAID"] = {
    text = "You have unsaved changes. Save before switching raid?",
    button1 = "Save",
    button2 = "Discard",
    OnAccept = function()
      if IsDirty() and SaveCurrent then SaveCurrent() end
      if pendingRaidSwitch then
        local targetRaid = pendingRaidSwitch; pendingRaidSwitch = nil
        -- perform the switch
        if not (FRT.RaidBosses and FRT.RaidBosses[targetRaid]) then
          targetRaid = FirstRaidName()
        end
        currentRaid = targetRaid
        uiSV.selectedRaid = targetRaid
        currentId = nil
        currentBossFilter = uiSV.selectedBossByRaid[currentRaid] or "All"
        if RebuildRaidDropdown then RebuildRaidDropdown() end
        if RebuildBossFilterDropdown then RebuildBossFilterDropdown() end
        if RebuildList then RebuildList() end
        local filtered = GetFilteredNotes()
        if table.getn(filtered) == 0 then
          currentId = nil; uiSV.selectedId = nil
          LoadSelected(nil)
        else
          currentId = filtered[1].id; uiSV.selectedId = currentId
          LoadSelected(currentId)
        end
      end
      HideBlocker()
    end,
    OnCancel = function()
      if pendingRaidSwitch then
        local targetRaid = pendingRaidSwitch; pendingRaidSwitch = nil
        if not (FRT.RaidBosses and FRT.RaidBosses[targetRaid]) then
          targetRaid = FirstRaidName()
        end
        currentRaid = targetRaid
        uiSV.selectedRaid = targetRaid
        currentId = nil
        currentBossFilter = uiSV.selectedBossByRaid[currentRaid] or "All"
        if RebuildRaidDropdown then RebuildRaidDropdown() end
        if RebuildBossFilterDropdown then RebuildBossFilterDropdown() end
        if RebuildList then RebuildList() end
        local filtered = GetFilteredNotes()
        if table.getn(filtered) == 0 then
          currentId = nil; uiSV.selectedId = nil
          LoadSelected(nil)
        else
          currentId = filtered[1].id; uiSV.selectedId = currentId
          LoadSelected(currentId)
        end
      end
      HideBlocker()
    end,
    timeout = 0, whileDead = 1, hideOnEscape = 1, showAlert = 0,
  }

  StaticPopupDialogs["FRT_UNSAVED_SWITCHNOTE"] = {
    text = "You have unsaved changes. Save before changing selection?",
    button1 = "Save",
    button2 = "Discard",
    OnAccept = function()
      if IsDirty() and SaveCurrent then SaveCurrent() end
      if pendingNoteIsNew then
        if currentBossFilter ~= "All" then
          CreateAndSelectNewNote()
        end
      elseif pendingNoteSwitch then
        LoadSelected(pendingNoteSwitch)
      elseif pendingBossFilter then
        ApplyBossFilter(pendingBossFilter)
      end
      pendingNoteSwitch = nil
      pendingNoteIsNew  = false
      pendingBossFilter = nil
      HideBlocker()
    end,
    OnCancel = function()
      if pendingNoteIsNew then
        CreateAndSelectNewNote()
      elseif pendingNoteSwitch then
        LoadSelected(pendingNoteSwitch)
      elseif pendingBossFilter then
        ApplyBossFilter(pendingBossFilter)
      end
      pendingNoteSwitch = nil
      pendingNoteIsNew  = false
      pendingBossFilter = nil
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
        local _, delIndex = FindNoteById(pendingDeleteId)
        if delIndex then
          table.remove(FRT_Saved.notes, delIndex)
          FRT.Print("Note deleted.")
          currentId = nil; uiSV.selectedId = nil
          RebuildList()
          LoadSelected(nil)
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

  -- ==== Raid dropdown logic
  local function ApplyRaid(val)
    if not val or val == "" then return end
    if IsDirty() then
      pendingRaidSwitch = val
      ShowBlocker()
      StaticPopup_Show("FRT_UNSAVED_SWITCHRAID")
      return
    end
    -- direct switch
    if not (FRT.RaidBosses and FRT.RaidBosses[val]) then
      val = FirstRaidName()
    end
    currentRaid = val
    uiSV.selectedRaid = val
    currentId = nil
    currentBossFilter = uiSV.selectedBossByRaid[currentRaid] or "All"
    if RebuildRaidDropdown then RebuildRaidDropdown() end
    if RebuildBossFilterDropdown then RebuildBossFilterDropdown() end
    if RebuildList then RebuildList() end
    local filtered = GetFilteredNotes()
    if table.getn(filtered) == 0 then
      currentId = nil; uiSV.selectedId = nil
      LoadSelected(nil)
    else
      currentId = filtered[1].id; uiSV.selectedId = currentId
      LoadSelected(currentId)
    end
  end

  local function InitRaidDropdown()
    local raids = RaidList()
    for i=1, table.getn(raids) do
      local rname = raids[i]
      local info = {}
      info.text   = GetRaidFullName(rname)
      info.value  = rname
      info.func   = function()
        UIDropDownMenu_SetSelectedValue(raidDD, rname)
        UIDropDownMenu_SetText(GetRaidFullName(rname), raidDD)
        ApplyRaid(rname)
      end
      info.checked = (rname == currentRaid)
      UIDropDownMenu_AddButton(info)
    end
  end

  RebuildRaidDropdown = function()
    EnsureDropDownListFrames()
    UIDropDownMenu_Initialize(raidDD, InitRaidDropdown)
    UIDropDownMenu_SetSelectedValue(raidDD, currentRaid)
    UIDropDownMenu_SetText(GetRaidFullName(currentRaid), raidDD)
  end

  -- ==== Events that affect Share button availability
  local watch = CreateFrame("Frame", nil, bottomBar)
  watch:RegisterEvent("PLAYER_ENTERING_WORLD")
  watch:RegisterEvent("PARTY_MEMBERS_CHANGED")
  watch:RegisterEvent("PARTY_LEADER_CHANGED")
  watch:RegisterEvent("RAID_ROSTER_UPDATE")
  watch:RegisterEvent("GUILD_ROSTER_UPDATE")
  watch:SetScript("OnEvent", function() if UpdateButtonsState then UpdateButtonsState() end end)

  -- ==== Initial state
  RebuildRaidDropdown()
  RebuildBossFilterDropdown()
  UpdateButtonsState()

  -- Build initial list/editor
  RebuildList()
  if currentId and FindNoteById(currentId) then
    LoadSelected(currentId)
    -- warm-up popup so StaticPopup frame exists
    local w = CreateFrame("Frame", nil, parent)
    w:SetScript("OnUpdate", function()
      w:SetScript("OnUpdate", nil)
      local popup = StaticPopup_Show("FRT_CONFIRM_DELETE_NOTE", "warmup")
      if popup then popup:Hide() end
      StaticPopup_Hide("FRT_CONFIRM_DELETE_NOTE")
    end)
  else
    local filtered = GetFilteredNotes()
    if table.getn(filtered) > 0 then
      currentId = filtered[1].id; uiSV.selectedId = currentId
      LoadSelected(currentId)
    else
      LoadSelected(nil)
    end
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

-- Fingbel Raid Tool — Note Editor Pane (UI)
-- Build frames, wire handlers, initial boot, sync/update buttons (Vanilla 1.12 / Lua 5.0)

local FRT = FRT
local EP  = FRT.Note.EditorPane
local S   = EP.state

local function EnsureViewerVisible()
  if FRT.Note and FRT.Note.EnsureViewer then FRT.Note.EnsureViewer() end
  if FRT.Note and FRT.Note.ShowViewer   then FRT.Note.ShowViewer() end
end

function EP.Build(parent)
  EP.EnsureSaved()

  -- ===== Init state refs =====
  S.parent  = parent
  S.uiSV    = FRT_Saved.ui.notes
  S.buttons = S.buttons or {}
  S.pending = S.pending or {}

  -- ===== Validate selected raid =====
  local selRaid = S.uiSV.selectedRaid or "Custom/Misc"
  if not (FRT.RaidBosses and FRT.RaidBosses[selRaid]) then
    selRaid = EP.FirstRaidName()
    S.uiSV.selectedRaid = selRaid
  end
  S.currentRaid       = selRaid
  S.currentId         = S.uiSV.selectedId or nil
  S.currentBossFilter = S.uiSV.selectedBossByRaid[S.currentRaid] or "All"

  -- ===== Header =====
  local header = CreateFrame("Frame", "FRT_NoteEditor_Header", parent)
  header:SetPoint("TOPLEFT", 0, 24)
  header:SetPoint("TOPRIGHT", 0, 0)
  header:SetHeight(26)
  S.header = header

  local hdiv = header:CreateTexture(nil, "ARTWORK")
  hdiv:SetPoint("BOTTOMLEFT", header, "BOTTOMLEFT", 0, 0)
  hdiv:SetPoint("BOTTOMRIGHT", header, "BOTTOMRIGHT", 0, 0)
  hdiv:SetHeight(1)
  hdiv:SetTexture("Interface\\Buttons\\WHITE8x8")
  hdiv:SetVertexColor(1, 1, 1, 0.10)

  local titleFS = header:CreateFontString(nil, "ARTWORK", "GameFontHighlightLarge")
  titleFS:SetPoint("CENTER", header, "CENTER", -50, 0)
  titleFS:SetText("Raid Notes")

  -- ===== Bottom bar =====
  local bottomBar = CreateFrame("Frame", "FRT_NoteEditor_BottomBar", parent)
  bottomBar:SetPoint("BOTTOMLEFT", 0, 0)
  bottomBar:SetPoint("BOTTOMRIGHT", 0, 0)
  bottomBar:SetHeight(40)
  S.bottomBar = bottomBar

  -- ===== Left column =====
  local leftColumn = CreateFrame("Frame", "FRT_NoteLeftColumn", parent)
  leftColumn:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -15)
  leftColumn:SetPoint("BOTTOMLEFT", bottomBar, "TOPLEFT", 0, 0)
  leftColumn:SetWidth(200)
  S.leftColumn = leftColumn

  -- ===== Right pane =====
  local right = CreateFrame("Frame", "FRT_NoteEditorPane", parent)
  right:SetPoint("TOPLEFT", leftColumn, "TOPRIGHT", 12, 0)
  right:SetPoint("BOTTOMRIGHT", bottomBar, "TOPRIGHT", -14, 0)
  S.rightPane = right

  -- Disabled overlay
  local rightOverlay = CreateFrame("Frame", nil, right)
  rightOverlay:SetAllPoints(right)
  rightOverlay:EnableMouse(true)
  rightOverlay:SetFrameStrata("DIALOG")
  rightOverlay:SetFrameLevel((right:GetFrameLevel() or 0) + 100)
  local rtex = rightOverlay:CreateTexture(nil, "BACKGROUND")
  rtex:SetAllPoints(rightOverlay)
  rtex:SetTexture(0,0,0,0.35)
  local rightOverlayMsg = rightOverlay:CreateFontString(nil, "ARTWORK", "GameFontHighlightLarge")
  rightOverlayMsg:SetPoint("CENTER", 0, 0)
  rightOverlayMsg:SetText("No note selected")
  rightOverlay:Hide()
  S.rightOverlay      = rightOverlay
  S.rightOverlayText  = rightOverlayMsg

  -- ===== Raid bar (top of left column) =====
  local raidBar = CreateFrame("Frame", "FRT_RaidBar", leftColumn)
  raidBar:SetPoint("TOPLEFT",  leftColumn, "TOPLEFT",  0, 0)
  raidBar:SetPoint("TOPRIGHT", leftColumn, "TOPRIGHT", 0, 0)
  raidBar:SetHeight(22)

  local raidLabel = raidBar:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
  raidLabel:SetPoint("LEFT", 0, 0)
  raidLabel:SetText("Raid:")

  local raidDD = CreateFrame("Frame", "FRT_NoteFilter_RaidDropDown", raidBar, "UIDropDownMenuTemplate")
  raidDD:SetPoint("LEFT", raidLabel, "RIGHT", -6, 2)
  UIDropDownMenu_SetWidth(130, raidDD)
  UIDropDownMenu_JustifyText("LEFT", raidDD)
  S.raidDD = raidDD

  -- ===== Boss filter bar =====
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
  S.bossDD = bossFilterDD

  -- ===== Note list (left) =====
  local left = CreateFrame("Frame", "FRT_NoteList", leftColumn)
  left:SetPoint("TOPLEFT",  filterBar, "BOTTOMLEFT", 0, -2)
  left:SetPoint("BOTTOMLEFT", 0, 0)
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
  S.listScroll   = listScroll
  S.listChild    = listChild
  S.listButtons  = {}

  -- ===== Right pane: aligned form section =====
  local FORM_LEFT_PAD = -85
  local LABEL_WIDTH   = 120
  local GAP_LABEL     = 6
  local CONTENT_X     = FORM_LEFT_PAD + LABEL_WIDTH + GAP_LABEL

  local form = CreateFrame("Frame", nil, right)
  form:SetPoint("TOPLEFT", right, "TOPLEFT", 0, 0)
  form:SetPoint("RIGHT",   right, "RIGHT",   0, 0)
  form:SetHeight(1) -- grow naturally

  -- contentAnchor defines ONE left edge for all value/inputs/toolbar/editor
  local contentAnchor = CreateFrame("Frame", nil, form)
  contentAnchor:SetPoint("TOPLEFT", form, "TOPLEFT", CONTENT_X, 0)
  contentAnchor:SetWidth(1); contentAnchor:SetHeight(1)

  -- Boss row
  local bossCaption = form:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
  bossCaption:SetPoint("TOPLEFT", form, "TOPLEFT", FORM_LEFT_PAD, 0)
  bossCaption:SetWidth(LABEL_WIDTH)
  bossCaption:SetJustifyH("RIGHT")
  bossCaption:SetText("Boss:")

  S.bossInfoLabel = form:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  S.bossInfoLabel:SetPoint("TOPLEFT", contentAnchor, "TOPLEFT", 0, 0)
  S.bossInfoLabel:SetText("")

  -- Title row
  local titleBox = CreateFrame("EditBox", "FRT_NoteEditor_TitleBox", form, "InputBoxTemplate")
  titleBox:SetAutoFocus(false)
  titleBox:SetHeight(20)
  titleBox:SetWidth(260)
  titleBox:SetPoint("TOPLEFT", S.bossInfoLabel, "BOTTOMLEFT", 0, -8)
  titleBox:SetText("")
  titleBox:SetScript("OnTextChanged", function()
    if not S.editorEnabled then return end
    EP.UpdateDirtyFromUserEdit()
  end)
  S.titleBox = titleBox

  local titleLabel = form:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
  titleLabel:SetPoint("RIGHT", titleBox, "LEFT", -GAP_LABEL, 0)
  titleLabel:SetWidth(LABEL_WIDTH)
  titleLabel:SetJustifyH("RIGHT")
  titleLabel:SetText("Title:")

  -- Helper: always pass a valid owner to GameTooltip (button itself)
  local function AttachSimpleTooltip(btn, text)
    btn:SetScript("OnEnter", function()
      GameTooltip:SetOwner(btn, "ANCHOR_RIGHT")
      GameTooltip:ClearLines()
      if text and text ~= "" then GameTooltip:AddLine(text, 1, 1, 1) end
      GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function()
      GameTooltip:Hide()
    end)
  end

  -- ===== Marker toolbar (aligned to content) =====
  local toolbar = CreateFrame("Frame", "FRT_NoteEditor_Toolbar", form)
  toolbar:SetPoint("TOPLEFT", titleLabel, "BOTTOMLEFT", 95, -8)
  toolbar:SetPoint("RIGHT",   form,          "RIGHT",      0,  0)  
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
    if anchor then
      b:SetPoint("LEFT", anchor, "RIGHT", xoff or 2, 0)
    else
      b:SetPoint("LEFT", parentFrame, "LEFT", 0, 0)
    end
    local tex = b:CreateTexture(nil, "ARTWORK"); tex:SetAllPoints(b)
    tex:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcons")
    local c = ICON_COORDS[index]; if c then tex:SetTexCoord(c[1],c[2],c[3],c[4]) end
    b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    b._rtIndex = index
    return b
  end

  do
    local last
    for i = 1, 8 do
      local b = MakeMarkerButton(toolbar, i, last, 2)
      local idx = i  -- capture this value

      b:SetScript("OnClick", function()
        if not S.editorEnabled then return end
        local ed = S.editor
        if not ed or not ed.edit or not ed.edit.Insert then return end
        ed.edit:SetFocus()
        ed.edit:Insert(string.format("{rt%d}", idx))
        if ed.Refresh then ed.Refresh() end
        EP.UpdatePreviewFromEditor()
        EP.UpdateDirtyFromUserEdit()
      end)

      AttachSimpleTooltip(b, string.format("Raid marker {rt%d}\n|cffaaaaaaClick to insert|r", idx))
      last = b
    end
  end

  -- ===== Class toolbar (aligned to content) =====
  local D = FRT.Data
  local classBar = CreateFrame("Frame", "FRT_NoteEditor_ClassToolbar", form)
  classBar:SetPoint("TOPLEFT", toolbar, "BOTTOMLEFT", 0, -6)
  classBar:SetPoint("RIGHT",   form,    "RIGHT",      0,  0)
  classBar:SetHeight(22)

  local function MakeClassButton(parentFrame, classKey, anchor, xoff)
    local b = CreateFrame("Button", nil, parentFrame)
    b:SetWidth(22); b:SetHeight(22)
    if anchor then
      b:SetPoint("LEFT", anchor, "RIGHT", xoff or 2, 0)
    else
      b:SetPoint("LEFT", parentFrame, "LEFT", 0, 0)
    end
    local tex = b:CreateTexture(nil, "ARTWORK"); tex:SetAllPoints(b)
    local coords = D and D.ClassIcons and D.ClassIcons.COORDS and D.ClassIcons.COORDS[classKey]
    tex:SetTexture(D and D.ClassIcons and D.ClassIcons.TEXTURE or "Interface\\Icons\\INV_Misc_QuestionMark")
    if coords then tex:SetTexCoord(coords[1], coords[2], coords[3], coords[4]) end
    b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    b._classKey = classKey
    return b
  end

  do
    -- Build ordered list from D.ClassOrder
    local ordered = {}
    if D and D.ClassOrder then
      for k, ord in pairs(D.ClassOrder) do
        table.insert(ordered, { key = k, ord = ord })
      end
      table.sort(ordered, function(a,b) return (a.ord or 999) < (b.ord or 999) end)
    else
      ordered = {
        {key="WARRIOR"},{key="PRIEST"},{key="DRUID"},{key="MAGE"},
        {key="ROGUE"},{key="HUNTER"},{key="WARLOCK"},{key="PALADIN"},{key="SHAMAN"},
      }
    end

    local last
    for i=1, table.getn(ordered) do
      local classKey = ordered[i].key
      local b = MakeClassButton(classBar, classKey, last, 2)
      local tag = "{class:" .. classKey .. "}"

      do
        local hex = D and D.ClassColorsHex and D.ClassColorsHex[classKey]
        local rgb = D and D.HexToRGB and D.HexToRGB(hex)
        b:SetScript("OnEnter", function()
            GameTooltip:SetOwner(b, "ANCHOR_RIGHT")
            GameTooltip:ClearLines()
            if rgb then
            GameTooltip:AddLine(classKey, rgb[1], rgb[2], rgb[3])
            else
            GameTooltip:AddLine(classKey, 1, 1, 1)
            end
            GameTooltip:Show()
        end)
        b:SetScript("OnLeave", function() GameTooltip:Hide() end)
        end

      b:SetScript("OnClick", function()
        if not S.editorEnabled then return end
        local ed = S.editor
        if not ed or not ed.edit or not ed.edit.Insert then return end
        ed.edit:SetFocus()
        ed.edit:Insert(tag)
        if ed.Refresh then ed.Refresh() end
        EP.UpdatePreviewFromEditor()
        EP.UpdateDirtyFromUserEdit()
      end)

      last = b
    end
  end

  -- ===== Text editor (scrollable) aligned to content =====
  local editArea = CreateFrame("Frame", nil, right)
  editArea:SetPoint("TOPLEFT",  classBar,    "BOTTOMLEFT", 0, -8)
  editArea:SetPoint("BOTTOMRIGHT", right,    "BOTTOMRIGHT", 0,  0)

  S.editor = FRT.Utils.CreateScrollableEdit(editArea, {
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

  -- ===== Viewer sync =====
  EnsureViewerVisible()
  if FRT.Note and FRT.Note.SetViewerRaw and S.editor and S.editor.GetText then
    FRT.Note.SetViewerRaw(S.editor.GetText() or "")
  end

  if S.editor and S.editor.edit and S.editor.edit.SetScript then
    S.editor.edit:SetScript("OnTextChanged", function()
      if not S.editorEnabled then return end
      EP.UpdatePreviewFromEditor()
      if S.editor.Refresh then S.editor.Refresh() end
      EP.UpdateDirtyFromUserEdit()
    end)
  end

  -- ===== Bottom buttons =====
  local btnNew   = CreateFrame("Button", "FRT_NoteBtn_New",  bottomBar, "UIPanelButtonTemplate")
  local btnDup   = CreateFrame("Button", "FRT_NoteBtn_Dup",  bottomBar, "UIPanelButtonTemplate")
  local btnDel   = CreateFrame("Button", "FRT_NoteBtn_Del",  bottomBar, "UIPanelButtonTemplate")
  local btnSave  = CreateFrame("Button", "FRT_NoteBtn_Save", bottomBar, "UIPanelButtonTemplate")
  local btnShare = CreateFrame("Button", "FRT_NoteBtn_Share",bottomBar, "UIPanelButtonTemplate")

  S.buttons.new   = btnNew
  S.buttons.dup   = btnDup
  S.buttons.del   = btnDel
  S.buttons.save  = btnSave
  S.buttons.share = btnShare

  btnNew:SetWidth(62);   btnNew:SetHeight(22);   btnNew:SetPoint("LEFT", 0, 0);                         btnNew:SetText("New")
  btnDup:SetWidth(62);   btnDup:SetHeight(22);   btnDup:SetPoint("LEFT", btnNew, "RIGHT", 6, 0);        btnDup:SetText("Duplicate")
  btnDel:SetWidth(62);   btnDel:SetHeight(22);   btnDel:SetPoint("LEFT", btnDup, "RIGHT", 6, 0);        btnDel:SetText("Delete")

  btnShare:SetWidth(80); btnShare:SetHeight(22); btnShare:SetPoint("RIGHT", bottomBar, "RIGHT", -12, 0); btnShare:SetText("Share")
  btnSave:SetWidth(80);  btnSave:SetHeight(22);  btnSave:SetPoint("RIGHT", btnShare, "LEFT", -6, 0);     btnSave:SetText("Save")

  -- Wire buttons
  btnNew:SetScript("OnClick", function()
    if EP.IsDirty() then
      S.pending.noteSwitch = nil
      S.pending.noteIsNew  = true
      EP.ShowBlocker()
      StaticPopup_Show("FRT_UNSAVED_SWITCHNOTE")
      return
    end
    if S.currentBossFilter == "All" then
      -- inline boss picker (unchanged from original flow)
      local bossPicker, bossPickDD, bossPickValue
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
            local list = EP.BossList(S.currentRaid)
            for i=1, table.getn(list) do
              local val = list[i]
              local info = {}
              info.text  = val
              info.value = val
              info.func  = function()
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
              if bossPickValue ~= S.currentBossFilter then
                EP.ApplyBossFilter(bossPickValue)
              end
              bossPicker:Hide()
              EP.CreateAndSelectNewNote()
            end
          end)

          local cancel = CreateFrame("Button", nil, bossPicker, "UIPanelButtonTemplate")
          cancel:SetWidth(90); cancel:SetHeight(22)
          cancel:SetPoint("RIGHT", ok, "LEFT", -6, 0)
          cancel:SetText("Cancel")
          cancel:SetScript("OnClick", function() bossPicker:Hide() end)

          bossPicker:Hide()
          bossPicker._prepare = function()
            EP.EnsureDropDownListFrames()
            local list = EP.BossList(S.currentRaid)
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
      EP.CreateAndSelectNewNote()
    end
  end)

  btnDup:SetScript("OnClick", EP.SaveAs)
  btnDel:SetScript("OnClick", EP.DeleteNote)
  btnSave:SetScript("OnClick", function()
    if not S.editorEnabled then return end
    if S.titleBox and S.titleBox.ClearFocus then S.titleBox:ClearFocus() end
    if S.editor and S.editor.edit and S.editor.edit.ClearFocus then S.editor.edit:ClearFocus() end
    EP.SaveCurrent()
  end)
  btnShare:SetScript("OnClick", EP.ShareCurrent)

  -- ===== Events affecting Share button =====
  local watch = CreateFrame("Frame", nil, bottomBar)
  watch:RegisterEvent("PLAYER_ENTERING_WORLD")
  watch:RegisterEvent("PARTY_MEMBERS_CHANGED")
  watch:RegisterEvent("PARTY_LEADER_CHANGED")
  watch:RegisterEvent("RAID_ROSTER_UPDATE")
  watch:RegisterEvent("GUILD_ROSTER_UPDATE")
  watch:SetScript("OnEvent", function()
    if EP.UpdateButtonsState then EP.UpdateButtonsState() end
  end)

  -- ===== Initial state =====
  EP.RebuildRaidDropdown()
  EP.RebuildBossFilterDropdown()
  EP.UpdateButtonsState()

  -- Build initial list/editor
  EP.RebuildList()
  if S.currentId and EP.FindNoteById(S.currentId) then
    EP.LoadSelected(S.currentId)
    -- warm-up popup so StaticPopup frame exists
    local w = CreateFrame("Frame", nil, parent)
    w:SetScript("OnUpdate", function()
      w:SetScript("OnUpdate", nil)
      local p = StaticPopup_Show("FRT_CONFIRM_DELETE_NOTE", "warmup")
      if p then p:Hide() end
      StaticPopup_Hide("FRT_CONFIRM_DELETE_NOTE")
    end)
  else
    local filtered = EP.GetFilteredNotes()
    if table.getn(filtered) > 0 then
      S.currentId = filtered[1].id; S.uiSV.selectedId = S.currentId
      EP.LoadSelected(S.currentId)
    else
      EP.LoadSelected(nil)
    end
  end
end

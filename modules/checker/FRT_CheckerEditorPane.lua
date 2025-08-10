-- Fingbel Raid Tool — Checker Editor Pane

FRT = FRT or {}
FRT.Editor = FRT.Editor or {}

--===============================
-- Saved UI prefs
--===============================
local function EnsureSaved()
  if type(FRT_Saved) ~= "table" then FRT_Saved = {} end
  FRT_Saved.ui = FRT_Saved.ui or {}
  FRT_Saved.ui.checker = FRT_Saved.ui.checker or { selectedId = nil, selectedCategory = nil }
end

--===============================
-- Checker data access (defensive)
--===============================
local function GetAllChecks()
  local list = {}
  if Checker and Checker._order and Checker._checks then
    local n = table.getn(Checker._order)
    local i
    for i = 1, n do
      local id = Checker._order[i]
      local c = Checker._checks[id]
      if c then
        table.insert(list, { id = c.id, desc = c.desc or "", category = c.category or "general" })
      end
    end
  end
  -- Fallback when registry doesn’t exist yet
  if table.getn(list) == 0 then
    table.insert(list, { id = "ping", desc = "Stub ping", category = "core" })
  end
  return list
end

local function GetCategories()
  local cats = {}
  local seen = {}
  local data = GetAllChecks()
  local i
  for i = 1, table.getn(data) do
    local cat = data[i].category or "general"
    if not seen[cat] then
      seen[cat] = true
      table.insert(cats, cat)
    end
  end
  table.sort(cats, function(a,b) return (string.lower(a or "") < string.lower(b or "")) end)
  return cats
end

--===============================
-- UI builder
--===============================
local function BuildCheckerPane(parent)
  EnsureSaved()
  local ui = FRT_Saved.ui.checker
  local selectedId = ui.selectedId
  local selectedCategory = ui.selectedCategory
  local RunAll, RebuildList, LoadSelected

  -- Title
  local title = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  title:SetPoint("TOP", 0, -10)
  title:SetText("Fingbel Raid Tool - Checker")

  -- Left list frame (checks)
  local left = CreateFrame("Frame", "FRT_Checker_List", parent)
  left:SetPoint("TOPLEFT", 0, -36)
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
  listHeader:SetText("Checks:")

  -- Category filter (simple cycle button)
  local catBtn = CreateFrame("Button", "FRT_Checker_CatBtn", left, "UIPanelButtonTemplate")
  catBtn:SetPoint("TOPRIGHT", -6, -4)
  catBtn:SetWidth(110); catBtn:SetHeight(20)
  local categories = GetCategories()
  if table.getn(categories) == 0 then categories = { "general" } end
  local function CatIndex(name)
    local i
    for i = 1, table.getn(categories) do if categories[i] == name then return i end end
    return 1
  end
  if not selectedCategory then selectedCategory = categories[1] end
  catBtn:SetText(selectedCategory or "general")
  catBtn:SetScript("OnClick", function()
    local idx = CatIndex(selectedCategory) + 1
    if idx > table.getn(categories) then idx = 1 end
    selectedCategory = categories[idx]
    ui.selectedCategory = selectedCategory
    catBtn:SetText(selectedCategory)
    if RebuildList then RebuildList() end
  end)

  -- Scroll area for items
  local listScroll = CreateFrame("ScrollFrame", "FRT_Checker_ListScroll", left, "UIPanelScrollFrameTemplate")
  listScroll:SetPoint("TOPLEFT", 6, -26)
  listScroll:SetPoint("BOTTOMRIGHT", -28, 6)
  local listChild = CreateFrame("Frame", nil, listScroll)
  listChild:SetWidth(1); listChild:SetHeight(1)
  listScroll:SetScrollChild(listChild)

  local listButtons = {}
  local function ClearListButtons()
    local i
    for i = 1, table.getn(listButtons) do
      if listButtons[i] then listButtons[i]:Hide() end
    end
    listButtons = {}
  end

  local function MakeItem(parentFrame, y, label, id, isHeader)
    local btn = CreateFrame("Button", nil, parentFrame)
    btn:SetPoint("TOPLEFT", 0, y)
    btn:SetWidth(182); btn:SetHeight(isHeader and 18 or 20)
    local font = isHeader and "GameFontHighlight" or "GameFontNormal"
    local fs = btn:CreateFontString(nil, "ARTWORK", font)
    fs:SetPoint("LEFT", 2, 0); fs:SetText(label or "")
    btn.fs = fs

    if not isHeader then
      btn.id = id
      btn:SetHighlightTexture("Interface\\Buttons\\UI-Listbox-Highlight2", "ADD")
      btn:SetScript("OnClick", function()
        if LoadSelected then LoadSelected(btn.id) end
      end)
    else
      btn:EnableMouse(false)
    end

    table.insert(listButtons, btn)
    return btn
  end

  RebuildList = function()
    ClearListButtons()
    local all = GetAllChecks()
    local y = 0
    local i
    local shown = 0
    for i = 1, table.getn(all) do
      local c = all[i]
      if (not selectedCategory) or (c.category == selectedCategory) then
        MakeItem(listChild, y, c.id .. " — " .. (c.desc or ""), c.id, false)
        y = y - 20
        shown = shown + 1
      end
    end
    if shown == 0 then
      MakeItem(listChild, y, "(No checks in this category)", nil, true)
      y = y - 18
    end
    listChild:SetHeight(-y + 4)
    listChild:SetWidth(182)
  end

  -- Bottom bar (Run buttons)
  local bottomBar = CreateFrame("Frame", "FRT_Checker_BottomBar", parent)
  bottomBar:SetPoint("BOTTOMLEFT", 0, 0)
  bottomBar:SetPoint("BOTTOMRIGHT", 0, 0)
  bottomBar:SetHeight(36)

  local divider = bottomBar:CreateTexture(nil, "ARTWORK")
  divider:SetPoint("TOPLEFT", parent, "BOTTOMLEFT", 0, 1)
  divider:SetPoint("TOPRIGHT", parent, "BOTTOMRIGHT", 0, 1)
  divider:SetHeight(1)
  divider:SetTexture("Interface\\Buttons\\WHITE8x8")
  divider:SetVertexColor(1,1,1,0.10)

  local btnRunSel = CreateFrame("Button", "FRT_Checker_RunSel", bottomBar, "UIPanelButtonTemplate")
  btnRunSel:SetWidth(100); btnRunSel:SetHeight(22)
  btnRunSel:SetPoint("LEFT", 0, 0)
  btnRunSel:SetText("Run Selected")

  local btnRunAll = CreateFrame("Button", "FRT_Checker_RunAll", bottomBar, "UIPanelButtonTemplate")
  btnRunAll:SetWidth(100); btnRunAll:SetHeight(22)
  btnRunAll:SetPoint("LEFT", btnRunSel, "RIGHT", 6, 0)
  btnRunAll:SetText("Run All")

  -- Right pane (output)
  local right = CreateFrame("Frame", "FRT_Checker_Right", parent)
  right:SetPoint("TOPLEFT", left, "TOPRIGHT", 10, 0)
  right:SetPoint("BOTTOMRIGHT", bottomBar, "TOPRIGHT", -14, 14)

  local out = CreateFrame("ScrollFrame", "FRT_Checker_OutScroll", right, "UIPanelScrollFrameTemplate")
  out:SetPoint("TOPLEFT", 0, -2)
  out:SetPoint("BOTTOMRIGHT", -28, 0)
  local outChild = CreateFrame("Frame", nil, out)
  outChild:SetWidth(1); outChild:SetHeight(1)
  out:SetScrollChild(outChild)

  local outText = outChild:CreateFontString(nil, "ARTWORK", "ChatFontNormal")
  outText:SetPoint("TOPLEFT", 4, -4)
  outText:SetJustifyH("LEFT"); outText:SetJustifyV("TOP")
  outText:SetText("|cffaaaaaaNo output yet.|r")

  -- Helpers to write output
  local function WriteLine(s)
    local cur = outText:GetText() or ""
    if cur == "" or cur == "|cffaaaaaaNo output yet.|r" then cur = "" end
    outText:SetText(cur .. s .. "\n")
    -- Expand the child to allow scrolling
    local h = outText:GetHeight() or 0
    if h < 1 then h = 200 end
    outChild:SetHeight(h + 8)
    outChild:SetWidth(400)
  end

  local function ClearOut()
    outText:SetText("")
    outChild:SetHeight(8)
    outChild:SetWidth(400)
  end

  -- Selection handling
  LoadSelected = function(id)
    selectedId = id
    ui.selectedId = id
    ClearOut()
    if id then
      WriteLine("|cffffff00Selected:|r " .. id)
    else
      WriteLine("|cffffff00No check selected.|r")
    end
  end

  -- Actions
  local function RunSelected()
    if not selectedId then
      WriteLine("|cffff5555No selected check.|r")
      return
    end

    ClearOut()
    -- If real registry exists, run just that id via slash handler
    if Checker and Checker.OnSlash then
      Checker.OnSlash(Checker, "check", "run " .. selectedId)
    else
      -- fallback to ping
      WriteLine("Running: " .. selectedId .. " ...")
      if selectedId == "ping" then
        WriteLine("Result: |cff55ff55PASS|r (stub)")
      else
        WriteLine("Result: unknown (stub)")
      end
    end
  end

  RunAll = function()
    ClearOut()
    if selectedCategory and Checker and Checker.OnSlash then
      Checker.OnSlash(Checker, "check", "run " .. selectedCategory)
    elseif Checker and Checker.OnSlash then
      Checker.OnSlash(Checker, "check", "run")
    else
      -- stub path
      WriteLine("Running all checks (stub)...")
      WriteLine("ping: |cff55ff55PASS|r")
    end
  end

  btnRunSel:SetScript("OnClick", RunSelected)
  btnRunAll:SetScript("OnClick", RunAll)

  -- Build initial list & selection
  RebuildList()
  if selectedId then
    LoadSelected(selectedId)
  else
    LoadSelected(nil)
  end

  -- expose for future use (optional)
  parent._checkerOutText = outText
end

--===============================
-- Panel registration (pure, no side-effects)
--===============================
function FRT.Checker_RegisterEditorPanel()
  if FRT and FRT.Editor and FRT.Editor.RegisterPanel then
    FRT.Editor.RegisterPanel("Checker", BuildCheckerPane, { title = "Checker", order = 50 })
  end
end

-- Convenience opener
function FRT.Checker_ShowEditor()
  if FRT and FRT.Editor and FRT.Editor.Show then
    FRT.Editor.Show("Checker")
  end
end

-- Fingbel Raid Tool - Checker Core (Grid + Auto-Refresh + Click-to-Buff)
-- Uses FRT_Data (pure data) with need-tokens + per-buff spellIcons
-- Turtle WoW / Vanilla 1.12 / Lua 5.0

FRT = FRT or {}
local BOOKTYPE_SPELL = BOOKTYPE_SPELL or "spell"

-- ===============================
-- UI constants
-- ===============================
local MAX_BUFFS    = 16
local ROW_HEIGHT   = 18
local VISIBLE_ROWS = 12
local TEX_CHECK    = "Interface\\Buttons\\UI-CheckBox-Check"
local TEX_CROSS    = "Interface\\Buttons\\UI-GroupLoot-Pass-Up"

-- ===============================
-- Shared data (from FRT_Data)
-- ===============================
local D = FRT.Data or {}

-- Preferred column order; if missing, derive from D.Buffs keys (unsorted)
local ORDERED_KEYS = (D.BuffOrder and table.getn(D.BuffOrder) > 0 and D.BuffOrder) or {}
if table.getn(ORDERED_KEYS) == 0 and D.Buffs then
  local k,_ ; for k,_ in pairs(D.Buffs) do table.insert(ORDERED_KEYS, k) end
end

-- ===============================
-- Build REG + SPELL_ICON from FRT_Data
-- - REG: runtime defs including resolved needFn
-- - SPELL_ICON: locale-proof substrings for casting
-- ===============================
local NEEDERS = {
  always = function(unit) return true end,
  mana   = function(unit) local pt = UnitPowerType and UnitPowerType(unit) or 0; return (pt == 0) end,
  -- extend with more tokens if needed (melee, ranged, healer, etc.)
}

local REG, SPELL_ICON = {}, {}
do
  local base = D.Buffs or {}
  -- 1) Add ordered keys first (so BuildActiveColumns respects the order)
  local i
  for i = 1, table.getn(ORDERED_KEYS) do
    local k = ORDERED_KEYS[i]
    local b = base[k]
    if b then
      REG[k] = {
        key        = k,
        label      = b.label or k,
        providers  = b.providers or {},
        tex        = b.texSubstrings or {},
        headerIcon = b.headerIcon or "Interface\\Icons\\INV_Misc_QuestionMark",
        needFn     = NEEDERS[b.need or "always"] or NEEDERS.always,
      }
      SPELL_ICON[k] = b.spellIcons -- may be nil; click-to-buff will auto-disable
    end
  end
  -- 2) Include any remaining buffs not in BuffOrder
  local k2,b2
  for k2,b2 in pairs(base) do
    if not REG[k2] then
      REG[k2] = {
        key        = k2,
        label      = b2.label or k2,
        providers  = b2.providers or {},
        tex        = b2.texSubstrings or {},
        headerIcon = b2.headerIcon or "Interface\\Icons\\INV_Misc_QuestionMark",
        needFn     = NEEDERS[b2.need or "always"] or NEEDERS.always,
      }
      SPELL_ICON[k2] = b2.spellIcons
      table.insert(ORDERED_KEYS, k2)
    end
  end
end

-- ===============================
-- Module
-- ===============================
local Checker = {}
Checker.name = "Checker"

-- ===============================
-- Spellbook lookup + casting
-- ===============================
local function FindSpellIndexByIcon(substrList)
  if not substrList then return nil end
  local numTabs = GetNumSpellTabs and GetNumSpellTabs() or 0
  local best = nil
  local t
  for t = 1, numTabs do
    local tabName, tabTex, offset, numSpells = GetSpellTabInfo(t)
    offset = offset or 0; numSpells = numSpells or 0
    local i
    for i = 1, numSpells do
      local idx = offset + i
      local tex = GetSpellTexture and GetSpellTexture(idx, BOOKTYPE_SPELL) or nil
      if tex then
        local s
        for s = 1, table.getn(substrList) do
          if string.find(tex, substrList[s], 1, true) then
            best = idx -- keep highest rank encountered
          end
        end
      end
    end
  end
  return best
end

-- Cast on the specific unit by temporarily targeting them, then restore
local function TryCastByIcon(iconList, unit)
  if not iconList or not unit then return false end
  local idx = FindSpellIndexByIcon(iconList)
  if not idx then return false end

  if SpellIsTargeting and SpellIsTargeting() then SpellStopTargeting() end

  local had  = UnitExists("target")
  local same = had and UnitIsUnit and UnitIsUnit("target", unit)

  if not same then TargetUnit(unit) end
  CastSpell(idx, BOOKTYPE_SPELL)

  if SpellIsTargeting and SpellIsTargeting() then
    SpellTargetUnit(unit)
    if SpellIsTargeting() then SpellStopTargeting() end
  end

  if not same then
    if had then TargetLastTarget() else ClearTarget() end
  end

  return true
end

-- ===============================
-- Runtime state
-- ===============================
local UI = {
  frame=nil, header=nil, scroll=nil, rows=nil,
  onlyMissing=false, activeCols={}, roster={}, results={}, filteredIndex={},
  evt=nil, ticker=nil, nextRefreshAt=nil,
}

-- ===============================
-- Helpers (1.12-safe)
-- ===============================
local function ClassColorRGB(class)
  local t = RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
  if t then return t.r, t.g, t.b end
  return 1,1,1
end

local function PlayerClassFile()
  local loc, file = UnitClass("player")
  return file or loc or "UNKNOWN"
end

local function PlayerCanProvide(key)
  local def = REG[key]
  if not def or not def.providers then return false end
  return def.providers[ PlayerClassFile() ] and true or false
end

local function CollectBuffTextures(unit)
  local seen = {}
  local i
  for i=1, MAX_BUFFS do
    local tex = UnitBuff(unit, i)
    if not tex then break end
    seen[tex] = true
  end
  return seen
end

local function HasAnyTextureMatch(seen, substrings)
  if not seen then return false end
  local path, _
  for path,_ in pairs(seen) do
    local j
    for j=1, table.getn(substrings) do
      if string.find(path, substrings[j], 1, true) then
        return true, path
      end
    end
  end
  return false, nil
end

-- ===============================
-- Roster & columns
-- ===============================
local function BuildRoster()
  local roster = {}
  local nRaid = GetNumRaidMembers and GetNumRaidMembers() or 0

  if nRaid > 0 then
    local i
    for i = 1, nRaid do
      local name, rank, subgroup, level, class, fileName, zone, online = GetRaidRosterInfo(i)
      local unit = "raid"..i
      local connected = (UnitIsConnected and UnitIsConnected(unit)) and true or false
      if name and online and connected then
        table.insert(roster, {
          name = name, unit = unit,
          class = (fileName or class or "UNKNOWN"),
          subgroup = (subgroup or 9),
        })
      end
    end
  else
    if not (UnitIsConnected and UnitIsConnected("player")) then
      return roster
    end
    local pName = UnitName("player") or "player"
    local ploc, pfile = UnitClass("player")
    table.insert(roster, { name = pName, unit = "player", class = (pfile or ploc or "UNKNOWN"), subgroup = 1 })

    local nParty = GetNumPartyMembers and GetNumPartyMembers() or 0
    local i
    for i = 1, nParty do
      local u = "party"..i
      if (UnitIsConnected and UnitIsConnected(u)) then
        local nm = UnitName(u) or u
        local loc, file = UnitClass(u)
        table.insert(roster, { name = nm, unit = u, class = (file or loc or "UNKNOWN"), subgroup = 1 })
      end
    end
  end

  table.sort(roster, function(a, b)
    if a.subgroup ~= b.subgroup then return (a.subgroup or 9) < (b.subgroup or 9) end
    local ca = D.CLASS_ORDER[a.class or "UNKNOWN"] or 99
    local cb = D.CLASS_ORDER[b.class or "UNKNOWN"] or 99
    if ca ~= cb then return ca < cb end
    return (a.name or "") < (b.name or "")
  end)

  return roster
end

local function DetectProviders(roster)
  local providers = {}
  local i
  for i=1, table.getn(roster) do
    providers[roster[i].class or ""] = true
  end
  return providers
end

-- Put self-castable columns first, then preserve ORDERED_KEYS order
local function BuildActiveColumns(roster)
  local providers = DetectProviders(roster)

  local orderIndex = {}
  local i
  for i = 1, table.getn(ORDERED_KEYS) do
    orderIndex[ORDERED_KEYS[i]] = i
  end

  local ploc, pfile = UnitClass("player")
  local selfClass = pfile or ploc or "UNKNOWN"

  local cols = {}
  for i = 1, table.getn(ORDERED_KEYS) do
    local k = ORDERED_KEYS[i]
    local def = REG[k]
    if def then
      local needed = false
      local cls, _
      for cls,_ in pairs(def.providers or {}) do
        if providers[cls] then needed = true; break end
      end
      if needed then
        local canSelf = (def.providers and def.providers[selfClass] == true)
        table.insert(cols, {
          key=k, label=def.label, icon=def.headerIcon,
          canSelf=canSelf, ord=(orderIndex[k] or 99),
        })
      end
    end
  end

  table.sort(cols, function(a, b)
    local wa = a.canSelf and 0 or 1
    local wb = b.canSelf and 0 or 1
    if wa ~= wb then return wa < wb end
    return (a.ord or 99) < (b.ord or 99)
  end)

  local out = {}
  for i=1, table.getn(cols) do
    local c = cols[i]
    out[i] = { key=c.key, label=c.label, icon=c.icon }
  end
  return out
end

local function Scan(roster, cols)
  local results = {}
  local i
  for i=1, table.getn(roster) do
    local name = roster[i].name
    local unit = roster[i].unit
    local seen = CollectBuffTextures(unit)
    local present, missing = {}, {}
    local c
    for c=1, table.getn(cols) do
      local key = cols[c].key
      local def = REG[key]
      if def and def.needFn(unit) then
        local ok, path = HasAnyTextureMatch(seen, def.tex)
        if ok then present[key] = path else table.insert(missing, key) end
      else
        present[key] = "__NA__"
      end
    end
    results[name] = { present=present, missing=missing }
  end
  return results
end

-- ===============================
-- Click-to-buff
-- ===============================
local function HandleCellClick(cell, mouseButton)
  if not cell or not cell.key or not cell.unit then return end
  if not cell._missing then return end
  if not PlayerCanProvide(cell.key) then return end

  local iconsTable = SPELL_ICON[cell.key]
  if not iconsTable then return end

  local useGroup = (mouseButton == "RightButton")
  local icons = useGroup and iconsTable.group or iconsTable.single
  if not icons then return end

  if UnitIsDeadOrGhost(cell.unit) then return end
  if not UnitIsFriend("player", cell.unit) then return end

  local ok = TryCastByIcon(icons, cell.unit)
  if not ok and useGroup then
    icons = iconsTable.single
    if icons then ok = TryCastByIcon(icons, cell.unit) end
  end
  if not ok and FRT and FRT.Print then
    FRT.Print("Checker: couldn't resolve/cast "..cell.key.." ("..(useGroup and "group" or "single").."). Open your spellbook once?")
  end
end

-- ===============================
-- UI building
-- ===============================
local function CreateHeader(parent)
  local header = CreateFrame("Frame", nil, parent)
  header:SetHeight(24)
  header:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, -38)
  header:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -10, -38)

  local name = header:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  name:SetPoint("LEFT", header, "LEFT", 8, 0)
  name:SetText("Name")
  header.name = name
  header.cols = {}
  return header
end

local function SetHeaderColumns(header, cols)
  local i
  for i=1, table.getn(header.cols) do
    if header.cols[i] then header.cols[i]:Hide() end
  end
  header.cols = {}

  local startX = 160
  local colW = 22
  for i=1, table.getn(cols) do
    local h = CreateFrame("Frame", nil, header)
    h:SetWidth(colW); h:SetHeight(18)
    h:SetPoint("LEFT", header, "LEFT", startX + (i-1)*(colW+6), 0)
    local t = h:CreateTexture(nil, "ARTWORK")
    t:SetAllPoints()
    t:SetTexture(cols[i].icon or "Interface\\Icons\\INV_Misc_QuestionMark")
    t:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    h.tex = t

    local txt = h:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    txt:SetPoint("TOP", h, "BOTTOM", 0, -1)
    txt:SetText(cols[i].label)
    header.cols[i] = h
  end
end

local function CreateRow(parent)
  local row = CreateFrame("Frame", nil, parent)
  row:SetHeight(ROW_HEIGHT)

  local name = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  name:SetPoint("LEFT", row, "LEFT", 8, 0)
  name:SetText("Player")
  row.name = name

  row.cells = {}
  return row
end

local function EnsureRows(scrollChild)
  if UI.rows and table.getn(UI.rows) >= VISIBLE_ROWS then return end
  UI.rows = UI.rows or {}
  local i
  for i=(table.getn(UI.rows)+1), VISIBLE_ROWS do
    local r = CreateRow(scrollChild)
    if i == 1 then
      r:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, 0)
      r:SetPoint("TOPRIGHT", scrollChild, "TOPRIGHT", 0, 0)
    else
      r:SetPoint("TOPLEFT", UI.rows[i-1], "BOTTOMLEFT", 0, 0)
      r:SetPoint("TOPRIGHT", UI.rows[i-1], "BOTTOMRIGHT", 0, 0)
    end
    UI.rows[i] = r
  end
end

local function SetRowCells(row, numCols)
  if row.cells then
    local i
    for i=1, table.getn(row.cells) do row.cells[i]:Hide() end
  end
  row.cells = {}

  local startX = 160
  local colW = 18
  local i
  for i=1, numCols do
    local f = CreateFrame("Button", nil, row) -- Button for hardware click
    f:SetWidth(colW); f:SetHeight(colW)
    f:SetPoint("LEFT", row, "LEFT", startX + (i-1)*(colW+10), 0)

    local t = f:CreateTexture(nil, "ARTWORK")
    t:SetAllPoints()
    t:SetTexture(TEX_CHECK)
    f.tex = t

    f:RegisterForClicks() -- clear; enabled per-cell below
    f:SetScript("OnClick", function() HandleCellClick(f, arg1) end)
    f:SetScript("OnEnter", function()
      if not f.key then return end
      local def = REG[f.key]
      if not def then return end
      GameTooltip:SetOwner(f, "ANCHOR_RIGHT")
      GameTooltip:SetText(def.label)
      local iconsTable = SPELL_ICON[f.key]
      if PlayerCanProvide(f.key) then
        if iconsTable and iconsTable.single then GameTooltip:AddLine("Left-click: single buff", 0,1,0) end
        if iconsTable and iconsTable.group  then GameTooltip:AddLine("Right-click: group buff",  0,1,0) end
      else
        GameTooltip:AddLine("You cannot cast this buff.", 1,0.3,0.3)
      end
      if not f._missing then
        GameTooltip:AddLine("Already present or N/A.", 0.8,0.8,0.8)
      end
      GameTooltip:Show()
    end)
    f:SetScript("OnLeave", function() GameTooltip:Hide() end)

    row.cells[i] = f
  end
end

local function UpdateRowVisual(row, rosterEntry, cols, result)
  if not rosterEntry then row:Hide(); return end
  row:Show()
  row.name:SetText(rosterEntry.name or "?")
  local r,g,b = ClassColorRGB(rosterEntry.class or "")
  row.name:SetTextColor(r,g,b)

  if not row.cells or table.getn(row.cells) ~= table.getn(cols) then
    SetRowCells(row, table.getn(cols))
  end

  local i
  for i=1, table.getn(cols) do
    local key = cols[i].key
    local cell = row.cells[i]
    local tex = cell.tex

    cell.unit = rosterEntry.unit
    cell.key  = key

    local present = result and result.present and result.present[key]
    local isNA = (present == "__NA__")
    local missing = (not isNA) and (not present)
    cell._missing = missing

    if isNA then
      tex:SetTexture(TEX_CHECK)
      tex:SetVertexColor(0.7, 0.7, 0.7, 0.35)
    elseif present then
      tex:SetTexture(TEX_CHECK)
      tex:SetVertexColor(0.2, 1.0, 0.2, 1.0)
    else
      tex:SetTexture(TEX_CROSS)
      tex:SetVertexColor(1.0, 0.2, 0.2, 1.0)
    end

    local clickable = PlayerCanProvide(key) and missing and (SPELL_ICON[key] ~= nil)
    cell:EnableMouse(clickable)
    if clickable then
      cell:RegisterForClicks("LeftButtonDown", "RightButtonDown")
      cell:SetAlpha(1.0)
    else
      cell:RegisterForClicks() -- clear
      cell:SetAlpha(0.6)
    end
  end
end

-- ===============================
-- Data + grid refresh
-- ===============================
local function RefreshDataAndGrid()
  if not UI.frame then return end

  UI.roster     = BuildRoster()
  UI.activeCols = BuildActiveColumns(UI.roster)
  UI.results    = Scan(UI.roster, UI.activeCols)

  -- filter mapping
  UI.filteredIndex = {}
  local i
  for i=1, table.getn(UI.roster) do
    local name = UI.roster[i].name
    local res = UI.results[name]
    local show = true
    if UI.onlyMissing and res then
      show = (table.getn(res.missing) > 0)
    end
    if show then table.insert(UI.filteredIndex, i) end
  end

  SetHeaderColumns(UI.header, UI.activeCols)

  -- Header tooltips with missing counts (use local copies to avoid upvalue trap)
  local hCount = table.getn(UI.header.cols)
  for i=1, hCount do
    local col = UI.activeCols[i]
    local missingCount = 0
    local r
    for r=1, table.getn(UI.filteredIndex) do
      local idx = UI.filteredIndex[r]
      local e = UI.roster[idx]
      local res = e and UI.results[e.name]
      if res then
        local present = res.present[col.key]
        if not present or present == false then missingCount = missingCount + 1 end
      end
    end
    local h = UI.header.cols[i]
    local colLabel = col.label
    local missCopy = missingCount
    h:EnableMouse(true)
    h:SetScript("OnEnter", function()
      GameTooltip:SetOwner(h, "ANCHOR_BOTTOM")
      GameTooltip:SetText(colLabel)
      GameTooltip:AddLine("Missing: "..missCopy, 1,0.6,0.6)
      GameTooltip:Show()
    end)
    h:SetScript("OnLeave", function() GameTooltip:Hide() end)
  end

  local total = table.getn(UI.filteredIndex)
  FauxScrollFrame_Update(UI.scroll, total, VISIBLE_ROWS, ROW_HEIGHT)

  local offset = FauxScrollFrame_GetOffset(UI.scroll)
  EnsureRows(UI.frame.scrollChild)

  for i=1, VISIBLE_ROWS do
    local idx = UI.filteredIndex[offset + i]
    local rosterEntry = idx and UI.roster[idx] or nil
    local result = rosterEntry and UI.results[rosterEntry.name] or nil
    UpdateRowVisual(UI.rows[i], rosterEntry, UI.activeCols, result)
  end

  if UI.frame.footer then
    local names = {}
    for i=1, table.getn(UI.activeCols) do table.insert(names, UI.activeCols[i].label) end
    local s = "Columns: "..((table.getn(names) > 0) and table.concat(names, ", ") or "None")
    UI.frame.footer:SetText(s)
  end
end

-- ===============================
-- Live updates (events + debounce)
-- ===============================
local function IsGroupUnit(u)
  if not u then return false end
  local p4 = string.sub(u,1,4)
  local p5 = string.sub(u,1,5)
  return (u == "player") or (p4 == "raid") or (p5 == "party")
end

local function RequestRefreshSoon(delay)
  if not UI.frame or not UI.frame:IsShown() then return end
  if not delay then delay = 0.20 end
  UI.nextRefreshAt = GetTime() + delay
  if not UI.ticker then UI.ticker = CreateFrame("Frame") end
  UI.ticker:SetScript("OnUpdate", function()
    if UI.nextRefreshAt and GetTime() >= UI.nextRefreshAt then
      UI.nextRefreshAt = nil
      UI.ticker:SetScript("OnUpdate", nil)
      RefreshDataAndGrid()
    end
  end)
end

local function RegisterLiveEvents(enable)
  if not UI.evt then
    UI.evt = CreateFrame("Frame")
    UI.evt:SetScript("OnEvent", function()
      if event == "UNIT_AURA" then
        if IsGroupUnit(arg1) then RequestRefreshSoon(0.10) end
      elseif event == "PLAYER_AURAS_CHANGED" then
        RequestRefreshSoon(0.10)
      elseif event == "RAID_ROSTER_UPDATE" or event == "PARTY_MEMBERS_CHANGED" then
        RequestRefreshSoon(0.05)
      elseif event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" then
        RequestRefreshSoon(0.25)
      end
    end)
  end
  if enable then
    UI.evt:RegisterEvent("UNIT_AURA")
    UI.evt:RegisterEvent("PLAYER_AURAS_CHANGED")
    UI.evt:RegisterEvent("RAID_ROSTER_UPDATE")
    UI.evt:RegisterEvent("PARTY_MEMBERS_CHANGED")
    UI.evt:RegisterEvent("PLAYER_ENTERING_WORLD")
    UI.evt:RegisterEvent("ZONE_CHANGED_NEW_AREA")
  else
    UI.evt:UnregisterEvent("UNIT_AURA")
    UI.evt:UnregisterEvent("PLAYER_AURAS_CHANGED")
    UI.evt:UnregisterEvent("RAID_ROSTER_UPDATE")
    UI.evt:UnregisterEvent("PARTY_MEMBERS_CHANGED")
    UI.evt:UnregisterEvent("PLAYER_ENTERING_WORLD")
    UI.evt:UnregisterEvent("ZONE_CHANGED_NEW_AREA")
  end
end

-- ===============================
-- Build UI
-- ===============================
local function BuildUI()
  if UI.frame then return end

  local f = CreateFrame("Frame", "FRT_CheckerFrame", UIParent)
  f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
  f:SetWidth(560); f:SetHeight(360)
  f:SetFrameStrata("DIALOG")
  f:SetBackdrop({
    bgFile  = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile= "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile=true, tileSize=16, edgeSize=32,
    insets={ left=10, right=10, top=10, bottom=10 }
  })
  f:SetBackdropColor(0,0,0,0.85)
  f:SetBackdropBorderColor(1,1,1,1)

  local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  title:SetPoint("TOPLEFT", f, "TOPLEFT", 16, -12)
  title:SetText("FRT Checker — Missing Buffs")

  local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -4, -4)

  local only = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate")
  only:SetPoint("TOPRIGHT", f, "TOPRIGHT", -110, -12)
  only.text = only:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
  only.text:SetPoint("LEFT", only, "RIGHT", 2, 0)
  only.text:SetText("Only Missing")
  only:SetScript("OnClick", function()
    UI.onlyMissing = (only:GetChecked() and true or false)
    RefreshDataAndGrid()
  end)

  UI.header = CreateHeader(f)

  local scroll = CreateFrame("ScrollFrame", "FRT_CheckerScroll", f, "FauxScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -60)
  scroll:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -26, 32)
  UI.scroll = scroll

  local child = CreateFrame("Frame", nil, f)
  child:SetPoint("TOPLEFT", scroll, "TOPLEFT", 0, 0)
  child:SetWidth(1); child:SetHeight(ROW_HEIGHT * VISIBLE_ROWS)
  f.scrollChild = child

  scroll:SetScript("OnVerticalScroll", function()
    FauxScrollFrame_OnVerticalScroll(this, arg1, ROW_HEIGHT, RefreshDataAndGrid)
  end)

  local footer = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  footer:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 12, 12)
  footer:SetText("")
  f.footer = footer

  -- Events + 1s auto-refresh while visible
  f._accum = 0
  f:SetScript("OnShow", function()
    RegisterLiveEvents(true)
    f._accum = 1.0
    RefreshDataAndGrid()
  end)
  f:SetScript("OnHide", function()
    RegisterLiveEvents(false)
  end)
  f:SetScript("OnUpdate", function()
    if not f:IsShown() then return end
    local dt = arg1 or 0
    f._accum = (f._accum or 0) + dt
    if f._accum >= 1.0 then
      f._accum = 0
      RefreshDataAndGrid()
    end
  end)

  UI.frame = f
  UI.rows = nil -- force build on first refresh
end

-- ===============================
-- Public
-- ===============================
function Checker.ShowUI()
  BuildUI()
  UI.frame:Show()
  RefreshDataAndGrid()
end

-- ===============================
-- Slash handling
-- ===============================
function Checker.OnSlash(module, cmd, rest)
  if cmd ~= "check" then return false end
  local sub = ""
  if rest and rest ~= "" then
    local _,_,cap = string.find(rest, "^(%S+)")
    sub = string.lower(cap or "")
  end

  if sub == "" or sub == "buffs" or sub == "ui" then
    Checker.ShowUI()
    return true
  elseif sub == "help" then
    if FRT and FRT.Print then
      FRT.Print("Checker:")
      FRT.Print("  /frt check ui      - open the Missing Buffs grid")
      FRT.Print("  /frt check buffs   - same as above")
    end
    return true
  end

  if FRT and FRT.Print then FRT.Print("Checker: unknown subcommand. Try /frt check ui") end
  return true
end

function Checker.GetHelp(module)
  return {
    "/frt check ui     - open the Missing Buffs grid",
    "/frt check buffs  - open the grid",
  }
end

-- ===============================
-- Lifecycle
-- ===============================
function Checker.OnLoad(module)
  if FRT and FRT.Print then FRT.Print("Checker loaded (auto-refresh + click-to-buff; using FRT_Data).") end
end

-- ===============================
-- Register with core
-- ===============================
if FRT.RegisterModule then
  FRT.RegisterModule(Checker.name, Checker)
end

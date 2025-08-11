-- Fingbel Raid Tool - Checker Core (logic only)
-- Uses FRT_Data (pure data)
-- Turtle WoW / Vanilla 1.12 / Lua 5.0

FRT = FRT or {}
local BOOKTYPE_SPELL = BOOKTYPE_SPELL or "spell"

--===============================
-- Shared data (from FRT_Data)
--===============================
local D = FRT.Data or {}

local CLASS_ORDER  = D.ClassOrder or { WARRIOR=1, PRIEST=2, DRUID=3, MAGE=4, ROGUE=5, HUNTER=6, WARLOCK=7, PALADIN=8, SHAMAN=9 }

-- If BuffOrder missing, derive from keys
local ORDERED_KEYS = (D.BuffOrder and table.getn(D.BuffOrder) > 0 and D.BuffOrder) or {}
if table.getn(ORDERED_KEYS) == 0 and D.Buffs then
  local k,_ ; for k,_ in pairs(D.Buffs) do table.insert(ORDERED_KEYS, k) end
end

-- Need tokens
local NEEDERS = {
  always = function(unit) return true end,
  mana   = function(unit) local pt = UnitPowerType and UnitPowerType(unit) or 0; return (pt == 0) end,
}

-- Build runtime registry from pure data
local REG, SPELL_ICON = {}, {}
do
  local base = D.Buffs or {}
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
      SPELL_ICON[k] = b.spellIcons
    end
  end
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

--===============================
-- Internal constants/helpers
--===============================
local MAX_BUFFS = 16

local function CollectBuffTextures(unit)
  local seen, i = {}, 1
  while i <= MAX_BUFFS do
    local tex = UnitBuff(unit, i)
    if not tex then break end
    seen[tex] = true
    i = i + 1
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

local function PlayerClassFile()
  local loc, file = UnitClass("player")
  return file or loc or "UNKNOWN"
end

local function PlayerCanProvide(key)
  local def = REG[key]
  if not def or not def.providers then return false end
  return def.providers[ PlayerClassFile() ] and true or false
end

--===============================
-- Spellbook lookup + casting
--===============================
local function FindSpellIndexByIcon(substrList)
  if not substrList then return nil end
  local tabs = GetNumSpellTabs and GetNumSpellTabs() or 0
  local best, t = nil, 1
  while t <= tabs do
    local tabName, tabTex, offset, numSpells = GetSpellTabInfo(t)
    offset = offset or 0; numSpells = numSpells or 0
    local i=1
    while i <= numSpells do
      local idx = offset + i
      local tex = GetSpellTexture and GetSpellTexture(idx, BOOKTYPE_SPELL) or nil
      if tex then
        local s=1
        while s <= table.getn(substrList) do
          if string.find(tex, substrList[s], 1, true) then best = idx end
          s = s + 1
        end
      end
      i = i + 1
    end
    t = t + 1
  end
  return best
end

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

--===============================
-- Core state (no frames!)
--===============================
local Core = {
  roster = {},
  columns = {},
  results = {}, -- map[name] = { present=..., missing={...} }
  listeners = {}, -- functions to call when data changes
  evt = nil, ticker = nil, nextRefreshAt=nil,
}

-- Build roster (skip offline)
local function BuildRoster()
  local roster = {}
  local nRaid = GetNumRaidMembers and GetNumRaidMembers() or 0

  if nRaid > 0 then
    local i=1
    while i <= nRaid do
      local name, rank, subgroup, level, class, fileName, zone, online = GetRaidRosterInfo(i)
      local unit = "raid"..i
      local connected = (UnitIsConnected and UnitIsConnected(unit)) and true or false
      if name and online and connected then
        table.insert(roster, {
          name=name, unit=unit, class=(fileName or class or "UNKNOWN"), subgroup=(subgroup or 9),
        })
      end
      i = i + 1
    end
  else
    if not (UnitIsConnected and UnitIsConnected("player")) then return roster end
    local pName = UnitName("player") or "player"
    local ploc, pfile = UnitClass("player")
    table.insert(roster, { name=pName, unit="player", class=(pfile or ploc or "UNKNOWN"), subgroup=1 })

    local nParty = GetNumPartyMembers and GetNumPartyMembers() or 0
    local j=1
    while j <= nParty do
      local u = "party"..j
      if (UnitIsConnected and UnitIsConnected(u)) then
        local nm = UnitName(u) or u
        local loc, file = UnitClass(u)
        table.insert(roster, { name=nm, unit=u, class=(file or loc or "UNKNOWN"), subgroup=1 })
      end
      j = j + 1
    end
  end

  table.sort(roster, function(a,b)
    if a.subgroup ~= b.subgroup then return (a.subgroup or 9) < (b.subgroup or 9) end
    local ca = CLASS_ORDER[a.class or "UNKNOWN"] or 99
    local cb = CLASS_ORDER[b.class or "UNKNOWN"] or 99
    if ca ~= cb then return ca < cb end
    return (a.name or "") < (b.name or "")
  end)
  return roster
end

local function DetectProviders(roster)
  local providers = {}
  local i=1
  while i <= table.getn(roster) do
    providers[roster[i].class or ""] = true
    i = i + 1
  end
  return providers
end

local function BuildActiveColumns(roster)
  local providers = DetectProviders(roster)

  local orderIndex = {}
  local i=1
  while i <= table.getn(ORDERED_KEYS) do
    orderIndex[ORDERED_KEYS[i]] = i
    i = i + 1
  end

  local ploc, pfile = UnitClass("player")
  local selfClass = pfile or ploc or "UNKNOWN"

  local cols = {}
  i=1
  while i <= table.getn(ORDERED_KEYS) do
    local k = ORDERED_KEYS[i]
    local def = REG[k]
    if def then
      local needed = false
      local cls,_ ; for cls,_ in pairs(def.providers or {}) do if providers[cls] then needed = true; break end end
      if needed then
        local canSelf = (def.providers and def.providers[selfClass] == true)
        table.insert(cols, { key=k, label=def.label, icon=def.headerIcon, canSelf=canSelf, ord=orderIndex[k] or 99 })
      end
    end
    i = i + 1
  end

  table.sort(cols, function(a,b)
    local wa = a.canSelf and 0 or 1
    local wb = b.canSelf and 0 or 1
    if wa ~= wb then return wa < wb end
    return (a.ord or 99) < (b.ord or 99)
  end)

  local out = {}
  i=1
  while i <= table.getn(cols) do
    local c = cols[i]
    out[i] = { key=c.key, label=c.label, icon=c.icon }
    i = i + 1
  end
  return out
end

local function Scan(roster, cols)
  local results = {}
  local i=1
  while i <= table.getn(roster) do
    local name = roster[i].name
    local unit = roster[i].unit
    local seen = CollectBuffTextures(unit)
    local present, missing = {}, {}
    local c=1
    while c <= table.getn(cols) do
      local key = cols[c].key
      local def = REG[key]
      if def and def.needFn(unit) then
        local ok, path = HasAnyTextureMatch(seen, def.tex)
        if ok then present[key] = path else table.insert(missing, key) end
      else
        present[key] = "__NA__"
      end
      c = c + 1
    end
    results[name] = { present=present, missing=missing }
    i = i + 1
  end
  return results
end

local function NotifyListeners()
  local i=1
  while i <= table.getn(Core.listeners) do
    local fn = Core.listeners[i]
    if type(fn) == "function" then
      -- no args; viewer pulls via getters
      pcall(fn)
    end
    i = i + 1
  end
end

local function RefreshNow()
  Core.roster  = BuildRoster()
  Core.columns = BuildActiveColumns(Core.roster)
  Core.results = Scan(Core.roster, Core.columns)
  NotifyListeners()
end

local function RequestRefreshSoon(delay)
  if not delay then delay = 0.20 end
  Core.nextRefreshAt = GetTime() + delay
  if not Core.ticker then Core.ticker = CreateFrame("Frame") end
  Core.ticker:SetScript("OnUpdate", function()
    if Core.nextRefreshAt and GetTime() >= Core.nextRefreshAt then
      Core.nextRefreshAt = nil
      Core.ticker:SetScript("OnUpdate", nil)
      RefreshNow()
    end
  end)
end

local function IsGroupUnit(u)
  if not u then return false end
  local p4 = string.sub(u,1,4)
  local p5 = string.sub(u,1,5)
  return (u == "player") or (p4 == "raid") or (p5 == "party")
end

local function SetLiveEvents(enable)
  if not Core.evt then
    Core.evt = CreateFrame("Frame")
    Core.evt:SetScript("OnEvent", function()
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
    Core.evt:RegisterEvent("UNIT_AURA")
    Core.evt:RegisterEvent("PLAYER_AURAS_CHANGED")
    Core.evt:RegisterEvent("RAID_ROSTER_UPDATE")
    Core.evt:RegisterEvent("PARTY_MEMBERS_CHANGED")
    Core.evt:RegisterEvent("PLAYER_ENTERING_WORLD")
    Core.evt:RegisterEvent("ZONE_CHANGED_NEW_AREA")
  else
    Core.evt:UnregisterEvent("UNIT_AURA")
    Core.evt:UnregisterEvent("PLAYER_AURAS_CHANGED")
    Core.evt:UnregisterEvent("RAID_ROSTER_UPDATE")
    Core.evt:UnregisterEvent("PARTY_MEMBERS_CHANGED")
    Core.evt:UnregisterEvent("PLAYER_ENTERING_WORLD")
    Core.evt:UnregisterEvent("ZONE_CHANGED_NEW_AREA")
  end
end

--===============================
-- Public API (no frames)
--===============================
FRT.CheckerCore = {
  -- data access
  GetRoster  = function() return Core.roster end,
  GetColumns = function() return Core.columns end,
  GetResults = function() return Core.results end,

  -- lifecycle
  RefreshNow     = RefreshNow,
  SetLiveEvents  = SetLiveEvents,
  Subscribe      = function(fn) table.insert(Core.listeners, fn) end,

  -- capabilities
  PlayerCanProvide = PlayerCanProvide,
  TryCast = function(key, unit, useGroup)
    if not key or not unit then return false end
    if not PlayerCanProvide(key) then return false end
    local iconsTable = SPELL_ICON[key]
    if not iconsTable then return false end
    if UnitIsDeadOrGhost(unit) then return false end
    if not UnitIsFriend("player", unit) then return false end

    local icons = (useGroup and iconsTable.group) or iconsTable.single
    if icons and TryCastByIcon(icons, unit) then return true end
    if useGroup and iconsTable.single then
      return TryCastByIcon(iconsTable.single, unit) or false
    end
    return false
  end,
}

--===============================
-- Optional: slash routes UI if loaded
--===============================
local Checker = { name = "Checker" }

function Checker.OnSlash(module, cmd, rest)
  if cmd ~= "check" then return false end
  local sub = ""
  if rest and rest ~= "" then
    local _,_,cap = string.find(rest, "^(%S+)")
    sub = string.lower(cap or "")
  end

  if sub == "" or sub == "buffs" or sub == "ui" then
    if FRT.CheckerViewer and FRT.CheckerViewer.Show then
      FRT.CheckerViewer.Show()
    else
      if FRT and FRT.Print then FRT.Print("Checker: viewer not loaded. Load FRT_CheckerViewer.lua") end
    end
    return true
  elseif sub == "help" then
    if FRT and FRT.Print then
      FRT.Print("Checker:")
      FRT.Print("  /frt check ui      - open Missing Buffs viewer (if loaded)")
      FRT.Print("  /frt check help    - this help")
    end
    return true
  end
  if FRT and FRT.Print then FRT.Print("Checker: unknown subcommand. Try /frt check ui") end
  return true
end

function Checker.GetHelp(module)
  return { "/frt check ui  - open the viewer" }
end

function Checker.OnLoad(module)
  if FRT and FRT.Print then FRT.Print("Checker core loaded (logic only).") end
  -- do not auto-enable events; viewer toggles these while visible
end

if FRT.RegisterModule then
  FRT.RegisterModule(Checker.name, Checker)
end

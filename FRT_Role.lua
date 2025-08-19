-- Fingbel Raid Tool — Role inference (Turtle WoW; class + talents only)
-- FRT_Role.lua  (WoW 1.12 / Lua 5.0)

FRT = FRT or {}
FRT.Role = FRT.Role or {}
local Role = FRT.Role

Role.OnChanged = Role.OnChanged or nil
Role._lastSig = nil
Role.Debug = true 

-- ===== utils =====
local function ClassToken()
  local _, file = UnitClass("player")
  return file or ""
end

-- Vanilla: GetTalentTabInfo(index[, isInspect[, isPet]])
local function TalentPoints(i)
  local _, _, pts = GetTalentTabInfo(i)
  return pts or 0
end

-- strict majority: 1/2/3 or 0 on tie
local function MajorIndex(t1, t2, t3)
  if t1 > t2 and t1 > t3 then return 1 end
  if t2 > t1 and t2 > t3 then return 2 end
  if t3 > t1 and t3 > t2 then return 3 end
  return 0
end

-- ===== Turtle WoW mappings (per talent tab 1..3) =====
-- Each entry: { ROLE, KIND, SCHOOL }
-- KIND only for DPS: "RDPS" (ranged) or "MDPS" (melee)
-- SCHOOL only for DPS: "PHYS" or "MAG"
local MAP = {
  -- DRUID: Balance, Feral, Restoration
  DRUID   = { {"DPS","RDPS","MAG"}, {"DPS","MDPS","PHYS"}, {"HEALER","",""} },

  -- PRIEST (Turtle): Discipline DPS, Holy Healer, Shadow DPS
  PRIEST  = { {"DPS","RDPS","MAG"}, {"HEALER","",""},      {"DPS","RDPS","MAG"} },

  -- PALADIN: Holy Healer, Prot Tank, Ret MDPS
  PALADIN = { {"HEALER","",""},     {"TANK","",""},        {"DPS","MDPS","PHYS"} },

  -- SHAMAN (Turtle): Ele MRDPS, Enh PMDPS, Resto Healer
  SHAMAN  = { {"DPS","RDPS","MAG"}, {"DPS","MDPS","PHYS"}, {"HEALER","",""} },

  -- WARRIOR: Arms/Fury MDPS, Prot Tank
  WARRIOR = { {"DPS","MDPS","PHYS"},{"DPS","MDPS","PHYS"},{"TANK","",""} },

  -- ROGUE: all MDPS phys
  ROGUE   = { {"DPS","MDPS","PHYS"},{"DPS","MDPS","PHYS"},{"DPS","MDPS","PHYS"} },

  -- MAGE: all MRDPS
  MAGE    = { {"DPS","RDPS","MAG"},{"DPS","RDPS","MAG"},{"DPS","RDPS","MAG"} },

  -- WARLOCK: all MRDPS
  WARLOCK = { {"DPS","RDPS","MAG"},{"DPS","RDPS","MAG"},{"DPS","RDPS","MAG"} },

  -- HUNTER (Turtle): BM/Marks PRDPS, Survival PMDPS (melee)
  HUNTER  = { {"DPS","RDPS","PHYS"},{"DPS","RDPS","PHYS"},{"DPS","MDPS","PHYS"} },
}

-- Tie / no-points defaults by class
local DEFAULT = {
  DRUID   = {"DPS","MDPS","PHYS"},
  PRIEST  = {"DPS","RDPS","MAG"},
  PALADIN = {"DPS","MDPS","PHYS"},
  SHAMAN  = {"DPS","MDPS","PHYS"},
  WARRIOR = {"DPS","MDPS","PHYS"},
  ROGUE   = {"DPS","MDPS","PHYS"},
  MAGE    = {"DPS","RDPS","MAG"},
  WARLOCK = {"DPS","RDPS","MAG"},
  HUNTER  = {"DPS","RDPS","PHYS"},
}

-- ===== pure inference =====
function Role.Infer(class, t1, t2, t3)
  class = class or ClassToken()
  t1, t2, t3 = t1 or 0, t2 or 0, t3 or 0

  local idx = MajorIndex(t1, t2, t3)
  local m = MAP[class]

  if idx ~= 0 and m and m[idx] then
    local triple = m[idx]
    return triple[1], triple[2], triple[3]
  end

  local d = DEFAULT[class]
  if d then return d[1], d[2], d[3] end
  return "DPS","MDPS","PHYS"
end

-- ===== player cache & API =====
Role.Role   = "DPS"
Role.Kind   = "MDPS"
Role.School = "PHYS"

Role._lastClass, Role._t1, Role._t2, Role._t3 = nil, nil, nil, nil

function Role.Recalc()
  local class = ClassToken()
  local t1, t2, t3 = TalentPoints(1), TalentPoints(2), TalentPoints(3)
  local r, k, s = Role.Infer(class, t1, t2, t3)
  Role.Role, Role.Kind, Role.School = r or "DPS", k or "", s or ""
  Role._lastClass, Role._t1, Role._t2, Role._t3 = class, t1, t2, t3
end

function Role.GetRole()   if Role.Role   == nil then Role.Recalc() end return Role.Role   end
function Role.GetKind()   if Role.Kind   == nil then Role.Recalc() end return Role.Kind   end
function Role.GetSchool() if Role.School == nil then Role.Recalc() end return Role.School end

function Role.GetSplit()
  local class = ClassToken()
  local t1, t2, t3 = TalentPoints(1), TalentPoints(2), TalentPoints(3)
  return class, t1 or 0, t2 or 0, t3 or 0
end

-- ===== events =====


local function dbg(msg)
  if Role.Debug and DEFAULT_CHAT_FRAME then
    DEFAULT_CHAT_FRAME:AddMessage("|cff66ccffFRT Role|r: "..msg)
  end
end

local function TalentSig()
  local _,_,a = GetTalentTabInfo(1)
  local _,_,b = GetTalentTabInfo(2)
  local _,_,c = GetTalentTabInfo(3)
  a,b,c = a or 0, b or 0, c or 0
  return a.."/"..b.."/"..c
end

function Role.RecalcIfChanged()
  local now = TalentSig()
  if now ~= Role._lastSig then
    Role._lastSig = now

    local beforeR, beforeK, beforeS = Role.Role, Role.Kind, Role.School
    Role.Recalc()
    -- only print debug if something actually changed
    if Role.Debug then
      local after = beforeR.."/"..beforeK.."/"..beforeS
      local curr  = Role.Role.."/"..Role.Kind.."/"..Role.School
      if after ~= curr and DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cff66ccffFRT Role|r: talents changed -> "..now.." ("
          ..after.." -> "..curr..")")
      end
    end
    if Role.OnChanged then
      Role.OnChanged(Role.Role, Role.Kind, Role.School)
    end
  end
end

function Role.OnLoad()
  if Role._frm then return end
  local f = CreateFrame("Frame"); Role._frm = f

  -- start + spec picker closes (Turtle’s device)
  f:RegisterEvent("PLAYER_ENTERING_WORLD")
  f:RegisterEvent("GOSSIP_CLOSED")

  f:SetScript("OnEvent", function()
    if event == "PLAYER_ENTERING_WORLD" then
      Role._lastSig = TalentSig()
      Role.Recalc()
      if Role.Debug and DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cff66ccffFRT Role|r: ready, sig "..(Role._lastSig or "?"))
      end
      return
    end
    Role.RecalcIfChanged()
  end)

  -- very light safety poll every 10s
  local acc = 0
  f:SetScript("OnUpdate", function()
    acc = acc + (arg1 or 0)
    if acc < 10 then return end
    acc = 0
    Role.RecalcIfChanged()
  end)

  f:Show()

  -- prime in case load happens post-world
  Role._lastSig = TalentSig()
  Role.Recalc()
end


-- ===== debug slash=====
SLASH_FRTROLE1 = "/frtrole"
SlashCmdList["FRTROLE"] = function()
  Role.Recalc()
  local class, a, b, c = Role.GetSplit()
  if DEFAULT_CHAT_FRAME then
    DEFAULT_CHAT_FRAME:AddMessage(string.format(
      "|cff66ccffFRT|r role=%s kind=%s school=%s  class=%s  talents %d/%d/%d",
      Role.GetRole(), Role.GetKind(), Role.GetSchool(), class or "?", a or 0, b or 0, c or 0))
  end
end

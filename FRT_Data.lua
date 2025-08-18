-- Fingbel Raid Tool - Shared Data
-- FRT_Data.lua

FRT      = FRT or {}
FRT.Data = FRT.Data or {}
local D  = FRT.Data

--===============================
-- Raid target icons
--===============================
D.RaidTargets = {
  TEXTURE = "Interface\\TargetingFrame\\UI-RaidTargetingIcons",
  COORDS  = {
    [1]={0.00,0.25,0.00,0.25}, [2]={0.25,0.50,0.00,0.25},
    [3]={0.50,0.75,0.00,0.25}, [4]={0.75,1.00,0.00,0.25},
    [5]={0.00,0.25,0.25,0.50}, [6]={0.25,0.50,0.25,0.50},
    [7]={0.50,0.75,0.25,0.50}, [8]={0.75,1.00,0.25,0.50},
  }
}

--===============================
-- Class icons (character creation sheet)
--===============================
D.ClassIcons = {
  TEXTURE = "Interface\\Glues\\CharacterCreate\\UI-CharacterCreate-Classes",
  COORDS  = {
    WARRIOR={0.00,0.25,0.00,0.25}, MAGE   ={0.25,0.50,0.00,0.25},
    ROGUE  ={0.50,0.75,0.00,0.25}, DRUID  ={0.75,1.00,0.00,0.25},
    HUNTER ={0.00,0.25,0.25,0.50}, SHAMAN ={0.25,0.50,0.25,0.50},
    PRIEST ={0.50,0.75,0.25,0.50}, WARLOCK={0.75,1.00,0.25,0.50},
    PALADIN={0.00,0.25,0.50,0.75},
  }
}

--===============================
-- Class colors
--===============================
D.ClassColorsHex = {
  WARRIOR="C79C6E", MAGE="69CCF0", ROGUE="FFF569",
  DRUID  ="FF7D0A", HUNTER="ABD473", SHAMAN="0070DE",
  PRIEST ="FFFFFF", WARLOCK="9482C9", PALADIN="F58CBA",
}

--===============================
-- Role colors (for placeholders)
--===============================
D.RoleColorsHex = {
  TANK   = "3B82F6",  -- blue-ish
  HEALER = "22C55E",  -- green
  DPS    = "EF4444",  -- red
  MELEE  = "F59E0B",  -- orange
  RANGED = "8B5CF6",  -- purple
}
--===============================
-- Common role synonyms to canonical keys
--===============================
D.RoleSynonyms = {
  MT="TANK", OT="TANK", T="TANK",
  HEAL="HEALER", HEALERS="HEALER", H="HEALER",
  DPS="DPS", DD="DPS",
  MDPS="MELEE", MELEE="MELEE", M="MELEE",
  RDPS="RANGED", RANGED="RANGED", R="RANGED",
}
-- Unknown/custom placeholders use gold so authors see they were recognized.
D.PlaceholderNeutralHex = "FFD100"

--===============================
-- Canonical section keys 
--===============================
D.Sections = {
  HEALER = { label = "Healer" },
  TANK   = { label = "Tank"   },
  RDPS   = { label = "Ranged DPS" },
  MDPS   = { label = "Melee DPS"  },
}

-- Human-friendly aliases accepted in [Section=...] (case-insensitive)
D.SectionAliases = {
  HEALER="HEALER", HEALERS="HEALER", HEAL="HEALER",
  TANK="TANK", TANKS="TANK", MT="TANK", OT="TANK",
  RDPS="RDPS", RANGED="RDPS", RANGEDDPS="RDPS",
  MDPS="MDPS", MELEE="MDPS", MELEEDPS="MDPS",
}

--Colors for section chips/headers in the viewer
D.SectionColorsHex = {
  HEALER="4CD964", TANK="C79C6E", RDPS="69CCF0", MDPS="F1C40F",
}

-- Simple helper (Parser reuses it)
function D.HexToRGB(hex)
  if not hex or string.len(hex) ~= 6 then return nil end
  local r = tonumber(string.sub(hex,1,2),16) or 255
  local g = tonumber(string.sub(hex,3,4),16) or 255
  local b = tonumber(string.sub(hex,5,6),16) or 255
  return { r/255, g/255, b/255 }
end

--===============================
-- Class sorting order (grid sort)
--===============================
D.ClassOrder = { WARRIOR=1, PRIEST=2, DRUID=3, MAGE=4, ROGUE=5, HUNTER=6, WARLOCK=7, PALADIN=8, SHAMAN=9 }


D.Buffs = {
  --========================
  -- PRIEST
  --========================
  fort = {
    key="fort",
    label="Fortitude",
    providers = { PRIEST=true },
    texSubstrings = { "Spell_Holy_WordFortitude", "Spell_Holy_PrayerOfFortitude" },
    headerIcon = "Interface\\Icons\\Spell_Holy_WordFortitude",
    need = "always",
    spellIcons = {
      single = { "Spell_Holy_WordFortitude" },
      group  = { "Spell_Holy_PrayerOfFortitude" },
    },
  },

  spirit = {
    key="spirit",
    label="Divine Spirit",
    providers = { PRIEST=true },
    texSubstrings = { "Spell_Holy_DivineSpirit", "Spell_Holy_PrayerofSpirit" }, -- group may not exist on some cores
    headerIcon = "Interface\\Icons\\Spell_Holy_DivineSpirit",
    need = "mana",
    spellIcons = {
      single = { "Spell_Holy_DivineSpirit" },
      group  = { "Spell_Holy_PrayerofSpirit" },
    },
  },

  shadowprot = {
    key="shadowprot",
    label="Shadow Protection",
    providers = { PRIEST=true },
    texSubstrings = { "Spell_Shadow_AntiShadow", "Spell_Holy_PrayerofShadowProtection" }, -- group may be core-dependent
    headerIcon = "Interface\\Icons\\Spell_Shadow_AntiShadow",
    need = "situational",
    spellIcons = {
      single = { "Spell_Shadow_AntiShadow" },
      group  = { "Spell_Holy_PrayerofShadowProtection" },
    },
  },

  --========================
  -- DRUID
  --========================
  motw = {
    key="motw",
    label="Mark of the Wild",
    providers = { DRUID=true },
    texSubstrings = { "Spell_Nature_Regeneration", "Spell_Nature_GiftoftheWild" },
    headerIcon = "Interface\\Icons\\Spell_Nature_Regeneration",
    need = "always",
    spellIcons = {
      single = { "Spell_Nature_Regeneration" },
      group  = { "Spell_Nature_GiftoftheWild" },
    },
    spellNames = {
    single = { "Mark of the Wild" },
    group  = { "Gift of the Wild" },
  },
  },

  --========================
  -- MAGE
  --========================
  ai = {
    key="ai",
    label="Arcane Intellect",
    providers = { MAGE=true },
    texSubstrings = { "Spell_Holy_MagicalSentry", "Spell_Holy_ArcaneIntellect", "Spell_Holy_ArcaneBrilliance" },
    headerIcon = "Interface\\Icons\\Spell_Holy_MagicalSentry",
    need = "mana",
    spellIcons = {
      single = { "Spell_Holy_MagicalSentry", "Spell_Holy_ArcaneIntellect" },
      group  = { "Spell_Holy_ArcaneBrilliance" },
    },
  },
}

-- Preferred column order (left -> right)
D.BuffOrder = {
  -- Priest
  "fort", "spirit", "shadowprot",
  -- Druid
  "motw", "thorns", "lotp",
  -- Mage
  "ai", "amplify", "dampen",
  -- Paladin (Alliance)
  "bok", "bow", "bom", "bos", "bol", "bosanc",
  -- Shaman (Horde)
  "soe", "goa", "wf", "ms", "ta",
  -- Warlock / Hunter / Warrior
  "bloodpact", "tsa", "aotw", "bshout",
}

-- Fingbel Raid Tool - Shared Data (Vanilla/Turtle, Lua 5.0)

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

--===============================
-- Buff metadata (pure data)
-- Each buff can specify:
--   label, providers, texSubstrings, headerIcon,
--   need = "always" | "mana" | ... (checker maps tokens to tiny functions),
--   spellIcons = { single = {...}, group = {...} } for locale-proof casting.
--===============================
D.Buffs = {
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
  },

  ai = {
    key="ai",
    label="Arcane Intellect",
    providers = { MAGE=true },
    texSubstrings = { "Spell_Holy_MagicalSentry", "Spell_Holy_ArcaneIntellect" },
    headerIcon = "Interface\\Icons\\Spell_Holy_MagicalSentry",
    need = "mana", -- mana users only
    spellIcons = {
      single = { "Spell_Holy_MagicalSentry", "Spell_Holy_ArcaneIntellect" },
      group  = { "Spell_Holy_ArcaneBrilliance" },
    },
  },
}

-- Preferred column order
D.BuffOrder = { "fort", "motw", "ai" }

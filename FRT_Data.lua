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
--   need = "always" | "mana" | "melee" | "physical" | "tank" | "dps" | "situational"
--   spellIcons = { single = {...}, group = {...} } for locale-proof casting.
--===============================
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

  -- thorns = {
  --   key="thorns",
  --   label="Thorns",
  --   providers = { DRUID=true },
  --   texSubstrings = { "Spell_Nature_Thorns" },
  --   headerIcon = "Interface\\Icons\\Spell_Nature_Thorns",
  --   need = "tank",
  --   spellIcons = {
  --     single = { "Spell_Nature_Thorns" },
  --     group  = {},
  --   },
  -- },

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

  -- amplify = {
  --   key="amplify",
  --   label="Amplify Magic",
  --   providers = { MAGE=true },
  --   texSubstrings = { "Spell_Holy_FlashHeal" },
  --   headerIcon = "Interface\\Icons\\Spell_Holy_FlashHeal",
  --   need = "situational",
  --   spellIcons = {
  --     single = { "Spell_Holy_FlashHeal" },
  --     group  = {},
  --   },
  -- },

  -- dampen = {
  --   key="dampen",
  --   label="Dampen Magic",
  --   providers = { MAGE=true },
  --   texSubstrings = { "Spell_Nature_AbolishMagic", "Spell_Nature_AstralRecalGroup" },
  --   headerIcon = "Interface\\Icons\\Spell_Nature_AbolishMagic",
  --   need = "situational",
  --   spellIcons = {
  --     single = { "Spell_Nature_AbolishMagic", "Spell_Nature_AstralRecalGroup" },
  --     group  = {},
  --   },
  -- },

  --========================
  -- PALADIN
  --========================
  bok = {
    key="bok",
    label="Blessing of Kings",
    providers = { PALADIN=true },
    texSubstrings = { "Spell_Magic_MageArmor", "Spell_Magic_GreaterBlessingofKings" },
    headerIcon = "Interface\\Icons\\Spell_Magic_MageArmor",
    need = "always",
    spellIcons = {
      single = { "Spell_Magic_MageArmor" },
      group  = { "Spell_Magic_GreaterBlessingofKings" },
    },
  },

  bom = {
    key="bom",
    label="Blessing of Might",
    providers = { PALADIN=true },
    texSubstrings = { "Spell_Holy_FistOfJustice", "Spell_Holy_GreaterBlessingofMight" },
    headerIcon = "Interface\\Icons\\Spell_Holy_FistOfJustice",
    need = "melee",
    spellIcons = {
      single = { "Spell_Holy_FistOfJustice" },
      group  = { "Spell_Holy_GreaterBlessingofMight" },
    },
  },

  bow = {
    key="bow",
    label="Blessing of Wisdom",
    providers = { PALADIN=true },
    texSubstrings = { "Spell_Holy_SealOfWisdom", "Spell_Holy_GreaterBlessingofWisdom" },
    headerIcon = "Interface\\Icons\\Spell_Holy_SealOfWisdom",
    need = "mana",
    spellIcons = {
      single = { "Spell_Holy_SealOfWisdom" },
      group  = { "Spell_Holy_GreaterBlessingofWisdom" },
    },
  },

  bos = {
    key="bos",
    label="Blessing of Salvation",
    providers = { PALADIN=true },
    texSubstrings = { "Spell_Holy_SealOfSalvation", "Spell_Holy_GreaterBlessingofSalvation" },
    headerIcon = "Interface\\Icons\\Spell_Holy_SealOfSalvation",
    need = "dps",
    spellIcons = {
      single = { "Spell_Holy_SealOfSalvation" },
      group  = { "Spell_Holy_GreaterBlessingofSalvation" },
    },
  },

  bol = {
    key="bol",
    label="Blessing of Light",
    providers = { PALADIN=true },
    texSubstrings = { "Spell_Holy_PrayerOfHealing", "Spell_Holy_GreaterBlessingOfLight" },
    headerIcon = "Interface\\Icons\\Spell_Holy_PrayerOfHealing",
    need = "tank",
    spellIcons = {
      single = { "Spell_Holy_PrayerOfHealing" },
      group  = { "Spell_Holy_GreaterBlessingOfLight" },
    },
  },

  bosanc = {
    key="bosanc",
    label="Blessing of Sanctuary",
    providers = { PALADIN=true },
    texSubstrings = { "Spell_Nature_LightningShield", "Spell_Holy_GreaterBlessingofSanctuary" },
    headerIcon = "Interface\\Icons\\Spell_Nature_LightningShield",
    need = "tank",
    spellIcons = {
      single = { "Spell_Nature_LightningShield" },
      group  = { "Spell_Holy_GreaterBlessingofSanctuary" },
    },
  },

  --========================
  -- SHAMAN 
  --========================

  --No totem tracking for now

  -- soe = {
  --   key="soe",
  --   label="Strength of Earth",
  --   providers = { SHAMAN=true },
  --   texSubstrings = { "Spell_Nature_StrengthOfEarthTotem02" },
  --   headerIcon = "Interface\\Icons\\Spell_Nature_StrengthOfEarthTotem02",
  --   need = "melee",
  --   spellIcons = {
  --     single = { "Spell_Nature_StrengthOfEarthTotem02" },
  --     group  = {},
  --   },
  -- },

  -- goa = {
  --   key="goa",
  --   label="Grace of Air",
  --   providers = { SHAMAN=true },
  --   texSubstrings = { "Spell_Nature_InvisibilityTotem" },
  --   headerIcon = "Interface\\Icons\\Spell_Nature_InvisibilityTotem",
  --   need = "melee",
  --   spellIcons = {
  --     single = { "Spell_Nature_InvisibilityTotem" },
  --     group  = {},
  --   },
  -- },

  -- wf = {
  --   key="wf",
  --   label="Windfury",
  --   providers = { SHAMAN=true },
  --   texSubstrings = { "Spell_Nature_Windfury" },
  --   headerIcon = "Interface\\Icons\\Spell_Nature_Windfury",
  --   need = "melee",
  --   spellIcons = {
  --     single = { "Spell_Nature_Windfury" },
  --     group  = {},
  --   },
  -- },

  -- ms = {
  --   key="ms",
  --   label="Mana Spring",
  --   providers = { SHAMAN=true },
  --   texSubstrings = { "Spell_Nature_ManaRegenTotem" },
  --   headerIcon = "Interface\\Icons\\Spell_Nature_ManaRegenTotem",
  --   need = "mana",
  --   spellIcons = {
  --     single = { "Spell_Nature_ManaRegenTotem" },
  --     group  = {},
  --   },
  -- },

  -- ta = {
  --   key="ta",
  --   label="Tranquil Air",
  --   providers = { SHAMAN=true },
  --   texSubstrings = { "Spell_Nature_Brilliance" },
  --   headerIcon = "Interface\\Icons\\Spell_Nature_Brilliance",
  --   need = "dps",
  --   spellIcons = {
  --     single = { "Spell_Nature_Brilliance" },
  --     group  = {},
  --   },
  -- },

  --========================
  -- WARLOCK
  --========================
  -- bloodpact = {
  --   key="bloodpact",
  --   label="Blood Pact",
  --   providers = { WARLOCK=true },
  --   texSubstrings = { "Spell_Shadow_BloodBoil" },
  --   headerIcon = "Interface\\Icons\\Spell_Shadow_BloodBoil",
  --   need = "always",
  --   spellIcons = {
  --     single = { "Spell_Shadow_BloodBoil" },
  --     group  = {},
  --   },
  -- },

  --========================
  -- HUNTER
  --========================
  -- tsa = {
  --   key="tsa",
  --   label="Trueshot Aura",
  --   providers = { HUNTER=true },
  --   texSubstrings = { "Ability_TrueShot", "Ability_TrueShotAura" },
  --   headerIcon = "Interface\\Icons\\Ability_TrueShot",
  --   need = "physical",
  --   spellIcons = {
  --     single = { "Ability_TrueShot", "Ability_TrueShotAura" },
  --     group  = {},
  --   },
  -- },

  -- aotw = {
  --   key="aotw",
  --   label="Aspect of the Wild",
  --   providers = { HUNTER=true },
  --   texSubstrings = { "Spell_Nature_ProtectionformNature", "Spell_Nature_ResistNature" },
  --   headerIcon = "Interface\\Icons\\Spell_Nature_ProtectionformNature",
  --   need = "situational",
  --   spellIcons = {
  --     single = { "Spell_Nature_ProtectionformNature", "Spell_Nature_ResistNature" },
  --     group  = {},
  --   },
  -- },

  --========================
  -- WARRIOR
  --========================
  -- bshout = {
  --   key="bshout",
  --   label="Battle Shout",
  --   providers = { WARRIOR=true },
  --   texSubstrings = { "Ability_Warrior_BattleShout" },
  --   headerIcon = "Interface\\Icons\\Ability_Warrior_BattleShout",
  --   need = "physical",
  --   spellIcons = {
  --     single = { "Ability_Warrior_BattleShout" },
  --     group  = {},
  --   },
  -- },
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

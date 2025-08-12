-- FRT_RaidData.lua
-- Fingbel Raid Tool – Raid/Boss data (Vanilla 1.12)
-- Now includes nicknames for editor display

FRT = FRT or {}

FRT.RaidBosses = {
  _order = {
    "Molten Core",
    "Onyxia's Lair",
    "Blackwing Lair",
    "Zul'Gurub",
    "Ruins of Ahn'Qiraj",
    "Temple of Ahn'Qiraj",
    "Naxxramas",
    "Custom/Misc", 
  },

  -- ===== Classic Raids =====
  ["Molten Core"] = {
    name   = "Molten Core",
    nick   = "MC",
    bosses = {
      "Lucifron",
      "Magmadar",
      "Gehennas",
      "Garr",
      "Shazzrah",
      "Baron Geddon",
      "Sulfuron Harbinger",
      "Golemagg the Incinerator",
      "Majordomo Executus",
      "Ragnaros",
    }
  },

  ["Onyxia's Lair"] = {
    name   = "Onyxia's Lair",
    nick   = "Ony",
    bosses = { "Onyxia" }
  },

  ["Blackwing Lair"] = {
    name   = "Blackwing Lair",
    nick   = "BWL",
    bosses = {
      "Razorgore the Untamed",
      "Vaelastrasz the Corrupt",
      "Broodlord Lashlayer",
      "Firemaw",
      "Ebonroc",
      "Flamegor",
      "Chromaggus",
      "Nefarian",
    }
  },

  ["Zul'Gurub"] = {
    name   = "Zul'Gurub",
    nick   = "ZG",
    bosses = {
      "High Priestess Jeklik",
      "High Priest Venoxis",
      "High Priestess Mar'li",
      "High Priest Thekal",
      "High Priestess Arlokk",
      "Bloodlord Mandokir",
      "Edge of Madness",
      "Gahz'ranka",
      "Jin'do the Hexxer",
      "Hakkar",
    }
  },

  ["Ruins of Ahn'Qiraj"] = {
    name   = "Ruins of Ahn'Qiraj",
    nick   = "AQ20",
    bosses = {
      "Kurinnaxx",
      "General Rajaxx",
      "Moam",
      "Buru the Gorger",
      "Ayamiss the Hunter",
      "Ossirian the Unscarred",
    }
  },

  ["Temple of Ahn'Qiraj"] = {
    name   = "Temple of Ahn'Qiraj",
    nick   = "AQ40",
    bosses = {
      "The Prophet Skeram",
      "Bug Trio",
      "Battleguard Sartura",
      "Fankriss the Unyielding",
      "Viscidus",
      "Princess Huhuran",
      "Twin Emperors",
      "Ouro",
      "C'Thun",
    }
  },

  ["Naxxramas"] = {
    name   = "Naxxramas",
    nick   = "Naxx",
    bosses = {
      "Anub'Rekhan",
      "Grand Widow Faerlina",
      "Maexxna",
      "Noth the Plaguebringer",
      "Heigan the Unclean",
      "Loatheb",
      "Instructor Razuvious",
      "Gothik the Harvester",
      "The Four Horsemen",
      "Patchwerk",
      "Grobbulus",
      "Gluth",
      "Thaddius",
      "Sapphiron",
      "Kel'Thuzad",
    }
  },

  ["World Bosses"] = {
    name   = "World Bosses",
    nick   = "WB",
    bosses = {
      "Azuregos",
      "Lord Kazzak",
      "Lethon",
      "Emeriss",
      "Ysondre",
      "Taerar",
    }
  },

  ["Custom/Misc"] = {
    name   = "Custom/Misc",
    nick   = "Misc",
    bosses = { "General" }
  },
}

-- Helper
function FRT.GetRaidBossList(raidName)
  local entry = FRT.RaidBosses and FRT.RaidBosses[raidName]
  if entry and type(entry.bosses) == "table" and table.getn(entry.bosses) > 0 then
    return entry.bosses
  end
  return { "General" }
end

function FRT.GetRaidNick(raidName)
  local entry = FRT.RaidBosses and FRT.RaidBosses[raidName]
  if entry and entry.nick then
    return entry.nick
  end
  return raidName
end

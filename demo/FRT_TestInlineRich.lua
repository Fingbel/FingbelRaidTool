-- FRT_TestInlineRich.lua
SLASH_FRTSMF1 = "/frtsmf"
SlashCmdList["FRTSMF"] = function()
  if FRT_TestInlineRich then
    if FRT_TestInlineRich:IsShown() then FRT_TestInlineRich:Hide() else FRT_TestInlineRich:Show() end
    return
  end

  local PADDING_X = 16

  -- === Icônes de raid ===
  local RT_TEXCOORD = {
    [1]={0.00,0.25,0.00,0.25}, [2]={0.25,0.50,0.00,0.25},
    [3]={0.50,0.75,0.00,0.25}, [4]={0.75,1.00,0.00,0.25},
    [5]={0.00,0.25,0.25,0.50}, [6]={0.25,0.50,0.25,0.50},
    [7]={0.50,0.75,0.25,0.50}, [8]={0.75,1.00,0.25,0.50},
  }
  local function RaidIcon(tex, idx)
    tex:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcons")
    local c = RT_TEXCOORD[idx] or RT_TEXCOORD[1]
    tex:SetTexCoord(c[1], c[2], c[3], c[4])
  end

  -- === Icônes de classe (feuille de création de personnage) ===
  local CLASS_TEX = "Interface\\Glues\\CharacterCreate\\UI-CharacterCreate-Classes"
  local CLASS_TEXCOORD = {
    WARRIOR = {0.00, 0.25, 0.00, 0.25},
    MAGE    = {0.25, 0.50, 0.00, 0.25},
    ROGUE   = {0.50, 0.75, 0.00, 0.25},
    DRUID   = {0.75, 1.00, 0.00, 0.25},

    HUNTER  = {0.00, 0.25, 0.25, 0.50},
    SHAMAN  = {0.25, 0.50, 0.25, 0.50},
    PRIEST  = {0.50, 0.75, 0.25, 0.50},
    WARLOCK = {0.75, 1.00, 0.25, 0.50},

    PALADIN = {0.00, 0.25, 0.50, 0.75},
  }
  local CLASS_ORDER = { "WARRIOR","MAGE","ROGUE","DRUID","HUNTER","SHAMAN","PRIEST","WARLOCK","PALADIN" }
  local function SetClassIcon(tex, class)
    local c = CLASS_TEXCOORD[string.upper(class or "")] or CLASS_TEXCOORD.WARRIOR
    tex:SetTexture(CLASS_TEX)
    tex:SetTexCoord(c[1], c[2], c[3], c[4])
  end

  -- === Couleurs de classes pour les noms ===
  local CLASS_COLORS = {
    WARRIOR = "|cffc79c6e",
    MAGE    = "|cff69ccf0",
    ROGUE   = "|cfffff569",
    DRUID   = "|cffff7d0a",
    HUNTER  = "|cffabd473",
    SHAMAN  = "|cff0070de",
    PRIEST  = "|cffffffff",
    WARLOCK = "|cff9482c9",
    PALADIN = "|cfff58cba",
  }

  -- === Frame principale ===
  local f = CreateFrame("Frame", "FRT_TestInlineRich", UIParent)
  f:SetWidth(300); f:SetHeight(340)
  f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
  f:SetBackdrop({
    bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 32, edgeSize = 32,
    insets   = { left = 11, right = 12, top = 12, bottom = 11 }
  })
  f:EnableMouse(true)
  f:SetMovable(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", function() f:StartMoving() end)
  f:SetScript("OnDragStop",  function() f:StopMovingOrSizing() end)

  local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -5, -5)

  local title = f:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
  title:SetPoint("TOP", f, "TOP", 0, -10)
  title:SetText("Aperçu des éléments de notes")

  -- En-tête pleine largeur, texte avec padding
  local function SectionHeader(anchor, text)
    local row = CreateFrame("Frame", nil, f)
    row:SetHeight(18)

    if anchor and anchor.GetObjectType and anchor:GetObjectType() == "FontString" then
      row:SetPoint("TOPLEFT",  f, "TOPLEFT",  0, -36)
      row:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, -36)
    else
      if anchor then
        row:SetPoint("TOPLEFT",  anchor, "BOTTOMLEFT",  0, -10)
        row:SetPoint("TOPRIGHT", f,      "TOPRIGHT",    0, -10)
      else
        row:SetPoint("TOPLEFT",  f, "TOPLEFT",  0, -10)
        row:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, -10)
      end
    end

    local fs = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    fs:SetPoint("LEFT", row, "LEFT", PADDING_X, 0)
    fs:SetText(text or "")
    return row
  end

  local function Divider(anchor)
    local line = f:CreateTexture(nil, "ARTWORK")
    line:SetHeight(1)
    line:SetPoint("TOPLEFT",  anchor, "BOTTOMLEFT",  PADDING_X, -6)
    line:SetPoint("TOPRIGHT", anchor, "BOTTOMRIGHT", -PADDING_X, -6)
    line:SetTexture("Interface\\Buttons\\WHITE8x8")
    line:SetVertexColor(1,1,1,0.15)
    return line
  end

  -- 1) Icône de raid entre deux textes
  local h1 = SectionHeader(title, "1) Icône de raid entre deux textes")

  local row1 = CreateFrame("Frame", nil, f); row1:SetHeight(22)
  row1:SetPoint("TOPLEFT",  h1, "BOTTOMLEFT",  0, -8)
  row1:SetPoint("TOPRIGHT", f,  "TOPRIGHT",    0, -8)

  local fsL = row1:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  fsL:SetPoint("LEFT", row1, "LEFT", PADDING_X*2, 0)
  fsL:SetText("Pull sur")

  local icon1 = row1:CreateTexture(nil, "ARTWORK"); icon1:SetWidth(16); icon1:SetHeight(16)
  icon1:SetPoint("LEFT", fsL, "RIGHT", 6, 0); RaidIcon(icon1, 8)

  local fsR = row1:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  fsR:SetPoint("LEFT", icon1, "RIGHT", 6, 0)
  fsR:SetText("— lancez vos CD à 50%")
  Divider(row1)

  -- 2) Plusieurs icônes de raid en ligne
  local h2 = SectionHeader(row1, "2) Plusieurs icônes de raid en ligne")

  local row2 = CreateFrame("Frame", nil, f); row2:SetHeight(22)
  row2:SetPoint("TOPLEFT",  h2, "BOTTOMLEFT",  0, -8)
  row2:SetPoint("TOPRIGHT", f,  "TOPRIGHT",    0, -8)

  local lead2 = row2:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
  lead2:SetPoint("LEFT", row2, "LEFT", PADDING_X*2, 0)
  lead2:SetText("Ordre de kill :")

  local prev = lead2
  for i = 1, 8 do
    local t = row2:CreateTexture(nil, "ARTWORK"); t:SetWidth(16); t:SetHeight(16)
    t:SetPoint("LEFT", prev, "RIGHT", (prev == lead2) and 8 or 4, 0)
    RaidIcon(t, i); prev = t
  end
  Divider(row2)

  -- 3) Texte coloré et mise en évidence
  local h3 = SectionHeader(row2, "3) Texte coloré et mise en évidence")

  local row3 = CreateFrame("Frame", nil, f); row3:SetHeight(22)
  row3:SetPoint("TOPLEFT",  h3, "BOTTOMLEFT",  0, -8)
  row3:SetPoint("TOPRIGHT", f,  "TOPRIGHT",    0, -8)

  local c1 = row3:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
  c1:SetPoint("LEFT", row3, "LEFT", PADDING_X*2, 0)
  c1:SetText("|cffffd100Soigneurs :|r gardez le tank au-dessus de |cffff404080% PV|r.")
  Divider(row3)

  -- 4) Icônes de classe
  local h4 = SectionHeader(row3, "4) Icônes de classe")

  local row4 = CreateFrame("Frame", nil, f); row4:SetHeight(22)
  row4:SetPoint("TOPLEFT",  h4, "BOTTOMLEFT",  0, -8)
  row4:SetPoint("TOPRIGHT", f,  "TOPRIGHT",    0, -8)

  local lead4 = row4:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
  lead4:SetPoint("LEFT", row4, "LEFT", PADDING_X*2, 0)
  lead4:SetText("Classes :")

  local prev4 = lead4
  for _, class in ipairs(CLASS_ORDER) do
    local t = row4:CreateTexture(nil, "ARTWORK")
    t:SetWidth(16); t:SetHeight(16)
    t:SetPoint("LEFT", prev4, "RIGHT", (prev4 == lead4) and 8 or 6, 0)
    SetClassIcon(t, class)
    prev4 = t
  end
  Divider(row4)

  -- 5) Noms de raiders colorés par classe
  local h5 = SectionHeader(row4, "5) Noms de raiders colorés par classe")

  local row5 = CreateFrame("Frame", nil, f); row5:SetHeight(22)
  row5:SetPoint("TOPLEFT",  h5, "BOTTOMLEFT",  0, -8)
  row5:SetPoint("TOPRIGHT", f,  "TOPRIGHT",    0, -8)

  local lead5 = row5:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
  lead5:SetPoint("LEFT", row5, "LEFT", PADDING_X*2, 0)
  lead5:SetText("Exemple :")

  local fakeNames = {
    { name = "Bonfi", class = "PALADIN" },
    { name = "Mazuno",   class = "WARLOCK"    },
    { name = "Fufux",  class = "ROGUE"   },
    { name = "Fingbel", class = "DRUID"   },
    { name = "Dapriest",  class = "PRIEST"  },
  }

  local prev5 = lead5
  for _, entry in ipairs(fakeNames) do
    local fsn = row5:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    fsn:SetPoint("LEFT", prev5, "RIGHT", 10, 0)
    local color = CLASS_COLORS[string.upper(entry.class or "")] or "|cffffffff"
    fsn:SetText(color .. entry.name .. "|r")
    prev5 = fsn
  end
  Divider(row5)

  f:Show()
end

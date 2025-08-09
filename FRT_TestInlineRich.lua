-- FRT_TestInlineRich.lua
SLASH_FRTSMF1 = "/frtsmf"
SlashCmdList["FRTSMF"] = function()
  if FRT_TestInlineRich then
    if FRT_TestInlineRich:IsShown() then FRT_TestInlineRich:Hide() else FRT_TestInlineRich:Show() end
    return
  end

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

  local f = CreateFrame("Frame", "FRT_TestInlineRich", UIParent)
  f:SetWidth(520); f:SetHeight(420)
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
  close:SetPoint("TOPRIGHT", -5, -5)

  local title = f:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
  title:SetPoint("TOP", 0, -10)
  title:SetText("Inline UI Elements Showcase")

  local function SectionHeader(anchor, text)
    local h = f:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    h:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -10)
    h:SetText(text or "")
    return h
  end
  local function Divider(anchor)
    local line = f:CreateTexture(nil, "ARTWORK")
    line:SetHeight(1)
    line:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -6)
    line:SetPoint("TOPRIGHT", anchor, "BOTTOMRIGHT", 0, -6)
    line:SetTexture("Interface\\Buttons\\WHITE8x8") -- safer on 1.12
    line:SetVertexColor(1,1,1,0.15)
    return line
  end

  -- 1) Inline icon between texts
  local h1 = SectionHeader(title, "1) Inline icon between two texts")
  local row1 = CreateFrame("Frame", nil, f); row1:SetHeight(22)
  row1:SetPoint("TOPLEFT", h1, "BOTTOMLEFT", 14, -8)
  row1:SetPoint("RIGHT", f, "RIGHT", -14, 0)

  local fsL = row1:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  fsL:SetPoint("LEFT", row1, "LEFT", 0, 0); fsL:SetText("Pull on")
  local icon1 = row1:CreateTexture(nil, "ARTWORK"); icon1:SetWidth(16); icon1:SetHeight(16)
  icon1:SetPoint("LEFT", fsL, "RIGHT", 6, 0); RaidIcon(icon1, 8)
  local fsR = row1:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  fsR:SetPoint("LEFT", icon1, "RIGHT", 6, 0); fsR:SetText("— pop cooldowns at 50%")
  Divider(row1)

  -- 2) Multiple icons inline
  local h2 = SectionHeader(row1, "2) Multiple inline icons")
  local row2 = CreateFrame("Frame", nil, f); row2:SetHeight(22)
  row2:SetPoint("TOPLEFT", h2, "BOTTOMLEFT", 14, -8)
  row2:SetPoint("RIGHT", f, "RIGHT", -14, 0)
  local lead2 = row2:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
  lead2:SetPoint("LEFT", row2, "LEFT", 0, 0); lead2:SetText("Kill order:")
  local prev = lead2
  for i = 1, 8 do
    local t = row2:CreateTexture(nil, "ARTWORK"); t:SetWidth(16); t:SetHeight(16)
    t:SetPoint("LEFT", prev, "RIGHT", (prev == lead2) and 8 or 4, 0)
    RaidIcon(t, i); prev = t
  end
  Divider(row2)

--   3) Colored text
  local h3 = SectionHeader(row2, "3) Colored text and emphasis")
  local row3 = CreateFrame("Frame", nil, f); row3:SetHeight(22)
  row3:SetPoint("TOPLEFT", h3, "BOTTOMLEFT", 14, -8)
  row3:SetPoint("RIGHT", f, "RIGHT", -14, 0)
  local c1 = row3:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
  c1:SetPoint("LEFT", row3, "LEFT", 0, 0)
  c1:SetText("|cffffd100Healers:|r keep tank above |cffff404080% HP|r.")
  Divider(row3)

  f:Show()
end

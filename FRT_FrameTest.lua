-- BGPathTester.lua (Vanilla 1.12)

SLASH_BGTEST1 = "/bgtest"
SlashCmdList.BGTEST = function()
    if BGTestFrame and BGTestFrame:IsShown() then
        BGTestFrame:Hide()
        return
    end

    local f = CreateFrame("Frame", "BGTestFrame", UIParent)
    f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    f:SetWidth(520); f:SetHeight(340)
    f:SetFrameStrata("DIALOG")

    -- Solid, guaranteed base + border
    f:SetBackdrop({
        bgFile  = "Interface\\Buttons\\WHITE8x8",
        edgeFile= "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile    = true, tileSize = 8,
        edgeSize= 32,
        insets  = { left=10, right=10, top=10, bottom=10 }
    })
    f:SetBackdropColor(0.12, 0.10, 0.07, 1) -- warm brown base
    f:SetBackdropBorderColor(1,1,1,1)

    -- Overlay texture we’re testing
    local bg = f:CreateTexture(nil, "BACKGROUND")
    bg:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -10)
    bg:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -10, 10)
    bg:SetTexCoord(0,1,0,1)
    bg:SetAlpha(1)
    f.bgTex = bg

    -- UI bits
    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", f, "TOP", 0, -12)
    title:SetText("Background Path Tester")

    local info = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    info:SetPoint("TOP", title, "BOTTOM", 0, -6)
    info:SetText("Click Cycle. Chat shows SetTexture() success.")

    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -4, -4)

    local btn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    btn:SetWidth(120); btn:SetHeight(22)
    btn:SetPoint("BOTTOM", f, "BOTTOM", 0, 16)
    btn:SetText("Cycle")

    -- Candidate textures (Vanilla-era; some may differ on Turtle)
    local BGs = {
        { label="Dialog BG",        path="Interface\\DialogFrame\\UI-DialogBox-Background" },
        { label="Frame Rock",       path="Interface\\FrameGeneral\\UI-Background-Rock" },
        { label="Quest Parchment",  path="Interface\\QuestFrame\\UI-QuestLog-Background" },
        { label="FriendsFrame BG",  path="Interface\\FriendsFrame\\UI-FriendsFrame-Background" },
        { label="Bank BG",          path="Interface\\BankFrame\\UI-BankFrame-Bg" },
        { label="Auction BG",       path="Interface\\AuctionFrame\\UI-AuctionFrame-Bid-BotRight" }, -- half tile just to test exist
        { label="Icon (sanity)",    path="Interface\\Icons\\INV_Misc_QuestionMark" }, -- should always work
        { label="Solid White8x8",   path=nil }, -- fallback solid
    }
    local idx = 1

    local function Apply(i)
        local opt = BGs[i]
        local ok
        if opt.path then
            ok = f.bgTex:SetTexture(opt.path)
            f.bgTex:SetVertexColor(1,1,1,1)
        else
            ok = f.bgTex:SetTexture("Interface\\Buttons\\WHITE8x8")
            f.bgTex:SetVertexColor(0.90, 0.85, 0.70, 1) -- parchment-ish solid
        end
        info:SetText(string.format("Using: %s", opt.label))
        if DEFAULT_CHAT_FRAME then
            DEFAULT_CHAT_FRAME:AddMessage(string.format("|cff55ff55[BGTEST]|r SetTexture(\"%s\") -> %s",
                tostring(opt.path), tostring(ok)))
        end
    end

    btn:SetScript("OnClick", function()
        idx = idx + 1
        if idx > table.getn(BGs) then idx = 1 end
        Apply(idx)
    end)

    Apply(idx)
    f:Show()
end

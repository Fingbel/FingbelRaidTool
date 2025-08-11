-- FRT_CasinoDemo.lua (Vanilla 1.12 / Lua 5.0) — Quest-style, artifact-free

SLASH_FRTDEMO1 = "/frtdemo"
SlashCmdList.FRTDEMO = function() FRT_Demo_Toggle() end

----------------------------------------------------------------
-- One lightweight animation driver (single OnUpdate)
----------------------------------------------------------------
FRT_Anim = FRT_Anim or { list = {}, busy = false }

local function EaseOutQuad(t)
    if t < 0 then return 0 elseif t > 1 then return 1 else return 1 - (1 - t) * (1 - t) end
end

local function StartDriver()
    if FRT_Anim.busy then return end
    FRT_Anim.busy = true
    if not FRT_Anim.ticker then
        FRT_Anim.ticker = CreateFrame("Frame", "FRT_AnimTicker", UIParent)
    end
    FRT_Anim.ticker:SetScript("OnUpdate", function()
        local now = GetTime()
        local i = 1
        while i <= table.getn(FRT_Anim.list) do
            local a = FRT_Anim.list[i]
            if now < a.st then
                i = i + 1
            else
                local p = (now - a.st) / a.d
                if p > 1 then p = 1 end
                local e = a.ease and a.ease(p) or p

                if a.kind == "move" then
                    a.f:ClearAllPoints()
                    a.f:SetPoint(a.point, a.rel, a.relPoint, a.sx + a.dx * e, a.sy + a.dy * e)
                elseif a.kind == "alpha" then
                    a.f:SetAlpha(a.sa + (a.da * e))
                elseif a.kind == "scalex" then
                    a.f:SetWidth(a.sw + (a.dw * e))
                end

                if p >= 1 then
                    if a.done then a.done(a) end
                    table.remove(FRT_Anim.list, i)
                else
                    i = i + 1
                end
            end
        end
        if table.getn(FRT_Anim.list) == 0 then
            FRT_Anim.busy = false
            FRT_Anim.ticker:SetScript("OnUpdate", nil)
        end
    end)
end

local function Anim_Move(frame, x1, y1, x2, y2, duration, delay, point, rel, relPoint, ease, done)
    table.insert(FRT_Anim.list, {
        kind="move", f=frame, sx=x1, sy=y1, dx=x2-x1, dy=y2-y1,
        d=(duration or 0.4), st=GetTime()+(delay or 0),
        point=point or "TOPLEFT", rel=rel or UIParent, relPoint=relPoint or "TOPLEFT",
        ease=ease, done=done
    })
    StartDriver()
end

local function Anim_Alpha(frame, a1, a2, duration, delay, done)
    frame:SetAlpha(a1)
    table.insert(FRT_Anim.list, {
        kind="alpha", f=frame, sa=a1, da=(a2-a1),
        d=duration or 0.3, st=GetTime()+(delay or 0), done=done
    })
    StartDriver()
end

local function Anim_ScaleX(frame, w1, w2, duration, delay, done)
    frame:SetWidth(w1)
    table.insert(FRT_Anim.list, {
        kind="scalex", f=frame, sw=w1, dw=(w2-w1),
        d=duration or 0.15, st=GetTime()+(delay or 0), done=done
    })
    StartDriver()
end

----------------------------------------------------------------
-- Quest-style skin (no additive highlights, correct layering)
----------------------------------------------------------------
local function AddQuestSkin(frame)
    -- Solid base so parchment transparency never shows the world
    frame:SetBackdrop({
        bgFile  = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile= "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile    = true, tileSize = 16,
        edgeSize= 32,
        insets  = { left=12, right=12, top=12, bottom=12 }
    })
    frame:SetBackdropColor(0, 0, 0, 0.80)
    frame:SetBackdropBorderColor(1,1,1,1)

    -- Full inner parchment, sits above the solid base, inside the border
    local bg = frame:CreateTexture(nil, "BACKGROUND")
    bg:SetDrawLayer("BACKGROUND", 1)
    bg:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -12)
    bg:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -12, 12)
    bg:SetTexture("Interface\\QuestFrame\\UI-QuestLog-Background")
    bg:SetVertexColor(1, 1, 1, 1) -- ensure no darkening

    -- Thin gold line below title (non-additive to avoid artifacts)
    local titleLine = frame:CreateTexture(nil, "BORDER")
    titleLine:SetDrawLayer("BORDER", 1)
    titleLine:SetHeight(2)
    titleLine:SetPoint("TOPLEFT", frame, "TOPLEFT", 14, -36)
    titleLine:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -14, -36)
    titleLine:SetTexture("Interface\\Tooltips\\UI-Tooltip-Border")
    titleLine:SetVertexColor(0.90, 0.80, 0.40, 0.9)

    -- Book icon sells the quest vibe
    local book = frame:CreateTexture(nil, "ARTWORK")
    book:SetDrawLayer("ARTWORK", 1)
    book:SetTexture("Interface\\QuestFrame\\UI-QuestLog-BookIcon")
    book:SetWidth(32); book:SetHeight(32)
    book:SetPoint("TOPLEFT", frame, "TOPLEFT", 18, -12)
end

----------------------------------------------------------------
-- Demo UI (coin + 3 fake cards) on parchment
----------------------------------------------------------------
local demo, deckX, deckY

local function EnsureDemo()
    if demo then return end
    demo = CreateFrame("Frame", "FRT_Demo", UIParent)
    demo:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    demo:SetWidth(560); demo:SetHeight(360)
    demo:SetFrameStrata("DIALOG")
    AddQuestSkin(demo)

    local title = demo:CreateFontString(nil,"OVERLAY","GameFontNormalLarge")
    title:SetPoint("TOPLEFT", demo, "TOPLEFT", 56, -14)
    title:SetText("FRT Casino — Visual Demo")
    title:SetShadowOffset(1, -1)
    title:SetShadowColor(0, 0, 0, 1)

    -- Coin (inside parchment area)
    demo.coin = CreateFrame("Frame", nil, demo)
    demo.coin:SetPoint("TOP", demo, "TOP", 0, -80)
    demo.coin:SetWidth(64); demo.coin:SetHeight(64)
    demo.coin.tex = demo.coin:CreateTexture(nil,"ARTWORK")
    demo.coin.tex:SetAllPoints()
    demo.coin.tex:SetTexture("Interface\\Icons\\INV_Misc_Coin_01")
    demo.coin.shadow = demo.coin:CreateTexture(nil,"BORDER")
    demo.coin.shadow:SetPoint("TOP", demo.coin, "BOTTOM", 0, -6)
    demo.coin.shadow:SetWidth(64); demo.coin.shadow:SetHeight(16)
    demo.coin.shadow:SetTexture("Interface\\Buttons\\WHITE8x8")
    demo.coin.shadow:SetVertexColor(0,0,0,0.35)

    -- Deck + slots (on parchment)
    deckX, deckY = 46, -250
    demo.deck = CreateFrame("Frame", nil, demo)
    demo.deck:SetWidth(48); demo.deck:SetHeight(48)
    demo.deck:SetPoint("TOPLEFT", demo, "TOPLEFT", deckX, deckY)
    local deckTex = demo.deck:CreateTexture(nil,"ARTWORK")
    deckTex:SetAllPoints()
    deckTex:SetTexture("Interface\\Buttons\\UI-Quickslot2")

    local slotX = { 220, 280, 340 }
    demo.cardSlots = {}
    for i=1,3 do
        local f = CreateFrame("Frame", nil, demo)
        f:SetWidth(48); f:SetHeight(64)
        f:SetPoint("TOPLEFT", demo, "TOPLEFT", slotX[i], -232)
        local t = f:CreateTexture(nil,"ARTWORK")
        t:SetAllPoints()
        t:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
        f.face = t

        -- subtle non-additive shadow to “seat” the card
        local sh = f:CreateTexture(nil, "BACKGROUND")
        sh:SetAllPoints()
        sh:SetTexture("Interface\\Buttons\\WHITE8x8")
        sh:SetVertexColor(0,0,0,0.08)

        demo.cardSlots[i] = f
    end

    -- Buttons (quest window bottom bar style)
    local b1 = CreateFrame("Button", nil, demo, "UIPanelButtonTemplate")
    b1:SetWidth(140); b1:SetHeight(24)
    b1:SetPoint("BOTTOMLEFT", demo, "BOTTOMLEFT", 20, 18)
    b1:SetText("Deal Slide Test")
    b1:SetScript("OnClick", function() FRT_Demo_Deal() end)

    local b2 = CreateFrame("Button", nil, demo, "UIPanelButtonTemplate")
    b2:SetWidth(160); b2:SetHeight(24)
    b2:SetPoint("BOTTOM", demo, "BOTTOM", 0, 18)
    b2:SetText("Coin Flip Bounce")
    b2:SetScript("OnClick", function() FRT_Demo_Flip() end)

    local b3 = CreateFrame("Button", nil, demo, "UIPanelButtonTemplate")
    b3:SetWidth(120); b3:SetHeight(24)
    b3:SetPoint("BOTTOMRIGHT", demo, "BOTTOMRIGHT", -20, 18)
    b3:SetText("Close")
    b3:SetScript("OnClick", function() demo:Hide() end)
end

----------------------------------------------------------------
-- Actions
----------------------------------------------------------------
function FRT_Demo_Deal()
    EnsureDemo()
    for i=1,3 do
        local card = CreateFrame("Frame", nil, demo)
        card:SetWidth(48); card:SetHeight(64)
        card:SetPoint("TOPLEFT", demo, "TOPLEFT", deckX, deckY)
        local back = card:CreateTexture(nil,"ARTWORK")
        back:SetAllPoints()
        back:SetTexture("Interface\\Buttons\\UI-Quickslot2")

        card:SetAlpha(0)
        Anim_Alpha(card, 0, 1, 0.20, (i-1)*0.05)

        local targetX = demo.cardSlots[i]:GetLeft() - demo:GetLeft()
        local targetY = demo.cardSlots[i]:GetTop()  - demo:GetTop()  - 64

        Anim_Move(card, deckX, deckY, targetX+10, targetY-6, 0.35, (i-1)*0.05, "TOPLEFT", demo, "TOPLEFT", EaseOutQuad, function()
            Anim_Move(card, targetX+10, targetY-6, targetX, targetY, 0.12, 0)
            Anim_Alpha(card, 1, 0, 0.08, 0.05, function()
                back:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
                Anim_Alpha(card, 0, 1, 0.08, 0)
            end)
        end)
    end
end

function FRT_Demo_Flip()
    EnsureDemo()
    local coin = demo.coin
    local tex  = coin.tex
    local w = 64

    local baseX = 0
    local baseY = -80
    local hops  = { {dy=40, t=0.26}, {dy=24, t=0.20}, {dy=14, t=0.16} }

    local totalDelay = 0
    for i=1, table.getn(hops) do
        local up = hops[i]
        Anim_Move(coin, baseX, baseY, baseX, baseY + up.dy, up.t*0.5, totalDelay, "TOP", demo, "TOP", EaseOutQuad)
        Anim_Move(coin, baseX, baseY + up.dy, baseX, baseY, up.t*0.5, totalDelay + up.t*0.5, "TOP", demo, "TOP", EaseOutQuad)

        Anim_Alpha(coin.shadow, 0.35, 0.15, up.t*0.5, totalDelay)
        Anim_Alpha(coin.shadow, 0.15, 0.40, up.t*0.5, totalDelay + up.t*0.5)

        Anim_ScaleX(coin, w, 8, up.t*0.5, totalDelay + up.t*0.25, function()
            local cur = tex.__side or 1
            tex:SetTexture(cur == 1 and "Interface\\Icons\\INV_Misc_Coin_02" or "Interface\\Icons\\INV_Misc_Coin_01")
            tex.__side = (cur == 1) and 2 or 1
        end)
        Anim_ScaleX(coin, 8, w, up.t*0.5, totalDelay + up.t*0.50)

        totalDelay = totalDelay + up.t + 0.02
    end
end

----------------------------------------------------------------
-- Toggle
----------------------------------------------------------------
function FRT_Demo_Toggle()
    EnsureDemo()
    if demo:IsShown() then demo:Hide() else demo:Show() end
end

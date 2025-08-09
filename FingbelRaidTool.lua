-- Fingbel Raid Tool (Core)
-- SavedVariables: FRT_Saved

FRT = FRT or {}
FRT.Modules = FRT.Modules or {}
FRT.ADDON_PREFIX = "FRT"

-- =================
-- Core: Utils
-- =================
function FRT.Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[FRT]|r " .. tostring(msg))
end

function FRT.SafeSetPoint(frame, point, relTo, relPoint, x, y)
    frame:ClearAllPoints()
    frame:SetPoint(point or "CENTER", relTo or UIParent, relPoint or (point or "CENTER"), tonumber(x) or 0, tonumber(y) or 0)
end

function FRT.RegisterAddonPrefix()
    if RegisterAddonMessagePrefix then
        RegisterAddonMessagePrefix(FRT.ADDON_PREFIX)
    end
end

function FRT.SendAddon(channel, text)
    text = tostring(text or "")
    if string.len(text) > 240 then
        text = string.sub(text, 1, 240)
        FRT.Print("Note truncated to 240 chars for sending.")
    end
    FRT.RegisterAddonPrefix()
    SendAddonMessage(FRT.ADDON_PREFIX, text, channel)
end

FRT.safePrint = (FRT and FRT.Print) or function(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[FRT]|r " .. tostring(msg))
end

-- =================
-- Module system
-- =================
function FRT.RegisterModule(name, moduleTable)
    FRT.Modules[name] = moduleTable
end

local function ForEachModule(fn)
    for _, m in pairs(FRT.Modules) do
        fn(m)
    end
end

-- =================
-- Late-safe dispatcher
-- =================
local function DispatchSlash(msg)
    msg = tostring(msg or "")
    local _, _, cmd, rest = string.find(msg, "^(%S*)%s*(.*)$")
    cmd = string.lower(cmd or "")

    if cmd == "" or cmd == "help" then
        FRT.Print("Commands:")
        ForEachModule(function(m)
            if m.GetHelp then
                local lines = m.GetHelp(m)
                if type(lines) == "table" then
                    for _, line in ipairs(lines) do
                        FRT.Print("  " .. line)
                    end
                end
            end
        end)
        return
    end

    local handled = false
    ForEachModule(function(m)
        if not handled and m.OnSlash then
            local ok = m.OnSlash(m, cmd, rest) -- pass module as first arg
            if ok then handled = true end
        end
    end)

    if not handled then
        FRT.Print("Unknown command. Use /frt help")
    end
end

-- =================
-- Slash command
-- =================
SLASH_FRT1 = "/frt"
SlashCmdList["FRT"] = function(msg)
    if not next(FRT.Modules) then
        local mcopy = msg
        local f = CreateFrame("Frame")
        f:SetScript("OnUpdate", function()
            f:SetScript("OnUpdate", nil)  -- use captured 'f'
            DispatchSlash(mcopy)
        end)
    else
        DispatchSlash(msg)
    end
end

-- =================
-- Core events
-- =================
local core = CreateFrame("Frame")
core:RegisterEvent("VARIABLES_LOADED")
core:SetScript("OnEvent", function()
    if event == "VARIABLES_LOADED" then
        ForEachModule(function(m)
            FRT.Print("Loading Module ")
            if m.OnLoad then m.OnLoad(m) end -- pass module table
        end)
        FRT.Print("Loaded. Type /frt help")
    end
end)
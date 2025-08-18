-- FRT_Debug.lua (Vanilla 1.12 / Lua 5.0 safe)
FRT = FRT or {}
FRT.Debug = FRT.Debug or {}

do
  local PREFIX = "FRTDBG"

  local function Safe(s)
    s = tostring(s or "")
    -- Chat needs pipes doubled or it throws "Invalid escape code"
    s = string.gsub(s, "|", "||")
    return s
  end

  local function Print(msg, r, g, b)
    msg = Safe(msg)
    if FRT and FRT.safePrint then
      FRT.safePrint(msg)
    elseif DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
      DEFAULT_CHAT_FRAME:AddMessage("|cff80c0ff[FRTDBG]|r "..msg, r or 1, g or 1, b or 1)
    end
  end

  -- On 1.12 we only have SendAddonMessage; no registration API is needed/available
  local function SendAddon(prefix, msg, channel, target)
    local fn = SendAddonMessage
    if not fn then return false, "SendAddonMessage not available" end
    if channel == "WHISPER" then
      -- Very likely unsupported on 1.12; let caller decide when to force
      return pcall(fn, prefix, msg, "WHISPER", target)
    else
      return pcall(fn, prefix, msg, channel)
    end
  end

  local function InRaid()  return (GetNumRaidMembers and (GetNumRaidMembers() or 0) > 0) end
  local function InParty() return (GetNumPartyMembers and (GetNumPartyMembers() or 0) > 0) and not InRaid() end
  local function InGuild() return (IsInGuild and IsInGuild()) end

  local function AutoTarget()
    if UnitIsPlayer and UnitIsPlayer("target") then
      return UnitName and UnitName("target")
    end
    if UnitName then
      return UnitName("party1") or UnitName("raid1")
    end
    return nil
  end

  local function NowStamp()
    if GetTime then return tostring(math.floor(GetTime() * 1000)) end
    return "0"
  end

  -- Receiver: just log messages that use our debug prefix
  local rx = CreateFrame("Frame", "FRTDBG_RX")
  rx:RegisterEvent("CHAT_MSG_ADDON")
  rx:SetScript("OnEvent", function()
    if event ~= "CHAT_MSG_ADDON" then return end
    local prefix, msg, channel, sender = arg1, arg2, arg3, arg4
    if prefix == PREFIX then
      -- Escape any pipes before printing
      Print(string.format("[recv] %s via %s from %s: %s",
        tostring(prefix), tostring(channel), tostring(sender), Safe(msg)))
    end
  end)

  local function Try(channel, target)
    -- Avoid '|' in payload to keep logs simple
    local payload = "PING-"..channel.."-"..NowStamp()
    local ok, err = SendAddon(PREFIX, payload, channel, target)
    if ok then
      if channel == "WHISPER" then
        Print(string.format("[sent] %s -> %s", channel, tostring(target)))
      else
        Print(string.format("[sent] %s", channel))
      end
    else
      if channel == "WHISPER" then
        Print(string.format("[fail] %s -> %s : %s", channel, tostring(target), tostring(err)))
      else
        Print(string.format("[fail] %s : %s", channel, tostring(err)))
      end
    end
  end

  local function TestGroup()
    local any = false
    if InRaid()  then any = true; Try("RAID")  end
    if InParty() then any = true; Try("PARTY") end
    if InGuild() then any = true; Try("GUILD") end
    if not any then
      Print("No raid/party/guild detected. Use '/frtdbg all' to force tests.")
    end
  end

  -- Whisper is DANGEROUS on some 1.12 clients; only run if explicitly forced
  local function TestWhisper(name, force)
    if not force then
      Print("WHISPER test skipped (likely unsupported on this client).")
      Print("To force anyway: /frtdbg whisper! <name>")
      return
    end
    local tgt = name or AutoTarget()
    if not tgt or tgt == "" then
      Print("Need a target: /target a player OR use /frtdbg whisper! Name")
      return
    end
    Print("Testing WHISPER to "..tostring(tgt).." …")
    Try("WHISPER", tgt)
  end

  local function TestAll()
    Print("Testing RAID, PARTY, GUILD (may fail out of context):")
    Try("RAID"); Try("PARTY"); Try("GUILD")
    Print("WHISPER not attempted. Use '/frtdbg whisper! <name>' to force.")
  end

  local function ShowEnv()
    local ver = GetBuildInfo and GetBuildInfo() or "unknown"
    Print("Build: "..tostring(ver))
    Print("Has C_ChatInfo.* APIs: false")
    Print("Has RegisterAddonMessagePrefix: false")
    Print("Has SendAddonMessage: "..tostring(not not SendAddonMessage))
    Print("Addon WHISPER support: probably NO on this client.")
  end

  -- Lua 5.0 trim
  local function trim(s)
    s = tostring(s or ""); s = string.gsub(s, "^%s+", ""); s = string.gsub(s, "%s+$", ""); return s
  end

  -- Slash
  SLASH_FRTDBG1 = "/frtdbg"
  SlashCmdList["FRTDBG"] = function(msg)
    msg = trim(msg)
    if msg == "" or msg == "help" then
      Print("Usage:")
      Print("  /frtdbg test           - probe RAID/PARTY/GUILD (if applicable)")
      Print("  /frtdbg all            - try RAID/PARTY/GUILD regardless of context")
      Print("  /frtdbg env            - print environment info")
      Print("  /frtdbg whisper! NAME  - DANGEROUS: try addon WHISPER to NAME")
      return
    end
    local _, _, cmd, rest = string.find(msg, "^(%S+)%s*(.-)$")
    cmd = string.lower(cmd or "")
    if cmd == "test" then
      TestGroup()
    elseif cmd == "all" then
      TestAll()
    elseif cmd == "env" then
      ShowEnv()
    elseif cmd == "whisper!" then
      TestWhisper(rest, true)
    elseif cmd == "whisper" then
      TestWhisper(rest, false)
    else
      Print("Unknown subcommand. Try '/frtdbg help'.")
    end
  end

  -- Init (no prefix registration on 1.12)
  local f = CreateFrame("Frame")
  f:RegisterEvent("PLAYER_LOGIN")
  f:SetScript("OnEvent", function()
    f:SetScript("OnEvent", nil)
    Print("FRT Debug ready. Type /frtdbg help")
  end)
end

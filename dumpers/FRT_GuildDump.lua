-- Fingbel Raid Tool — Guild Info Dump 

FRT = FRT or {}

-- Ensure SV bucket
local function EnsureSV()
  if type(FRT_Saved) ~= "table" then FRT_Saved = {} end
  FRT_Saved.guildDump = FRT_Saved.guildDump or { ts = 0, realm = "", guild = "", rows = {} }
end

-- CSV escape
local function CsvEscape(s)
  s = tostring(s or "")
  if string.find(s, "[,\n\r\"]") then
    s = "\"" .. string.gsub(s, "\"", "\"\"") .. "\""
  end
  return s
end

-- Build CSV line
local function CsvLine(fields)
  local out = {}
  local i
  for i = 1, table.getn(fields) do
    table.insert(out, CsvEscape(fields[i]))
  end
  return table.concat(out, ",")
end

-- Format “last online”
local function LastOnlineString(i)
  if not GetGuildRosterLastOnline then return "" end
  local y, m, d, h = GetGuildRosterLastOnline(i)
  if not y then return "" end
  local parts = {}
  if y and y > 0 then table.insert(parts, y .. "y") end
  if m and m > 0 then table.insert(parts, m .. "m") end
  if d and d > 0 then table.insert(parts, d .. "d") end
  if h and h > 0 then table.insert(parts, h .. "h") end
  if table.getn(parts) == 0 then return "today" end
  return table.concat(parts, " ")
end

-- Collector frame (async after GuildRoster())
local collector = CreateFrame("Frame")
local pending = false

collector:RegisterEvent("GUILD_ROSTER_UPDATE")
collector:SetScript("OnEvent", function()
  if event == "GUILD_ROSTER_UPDATE" and pending then
    pending = false

    EnsureSV()

    local rows = {}
    local n = GetNumGuildMembers() or 0
    local i
    for i = 1, n do
      local name, rank, rankIndex, level, class, zone, note, officerNote, online =
        GetGuildRosterInfo(i)

      local lastSeen = (online and "online") or LastOnlineString(i)

      table.insert(rows, {
        name = name or "",
        rank = rank or "",
        rankIndex = rankIndex or 0,
        level = level or 0,
        class = class or "",
        zone = zone or "",
        note = note or "",
        officerNote = officerNote or "",
        online = (online and true) or false,
        lastOnline = lastSeen or "",
      })
    end

    local realm = GetCVar and GetCVar("RealmName") or ""
    local gname = ""
    if GetGuildInfo then gname = (GetGuildInfo("player")) or "" end

    FRT_Saved.guildDump.ts = GetTime() or 0
    FRT_Saved.guildDump.realm = realm
    FRT_Saved.guildDump.guild = gname
    FRT_Saved.guildDump.rows = rows

    FRT.Print("Guild dump: saved " .. tostring(table.getn(rows)) .. " members for " .. (gname or ""))
  end
end)

-- Slash command: /frtguild dump|csv|clear
SLASH_FRTGUILD1 = "/frtguild"
SlashCmdList["FRTGUILD"] = function(msg)
  msg = tostring(msg or "")
  local _, _, cmd, rest = string.find(msg, "^(%S*)%s*(.*)$")
  cmd = string.lower(cmd or "")

  if cmd == "" or cmd == "help" then
    FRT.Print("Guild dump usage:")
    FRT.Print("  /frtguild dump   - query & save roster to SavedVariables")
    FRT.Print("  /frtguild csv    - print a few CSV lines")
    FRT.Print("  /frtguild clear  - clear last dump")
    return
  end

  if cmd == "dump" then
    if not IsInGuild or not IsInGuild() then
      FRT.Print("You are not in a guild.")
      return
    end
    pending = true
    GuildRoster() -- triggers GUILD_ROSTER_UPDATE
    FRT.Print("Requesting guild roster...")
    return
  end

  if cmd == "csv" then
    EnsureSV()
    local rows = FRT_Saved.guildDump.rows or {}
    local total = table.getn(rows)
    if total == 0 then
      FRT.Print("No dump yet. Use /frtguild dump first.")
      return
    end
    FRT.Print("CSV preview (name,rank,rankIndex,level,class,zone,note,officerNote,online,lastOnline):")
    FRT.Print(CsvLine({
      "name","rank","rankIndex","level","class","zone","note","officerNote","online","lastOnline"
    }))
    local limit = (total < 10) and total or 10
    local i
    for i = 1, limit do
      local r = rows[i]
      FRT.Print(CsvLine({
        r.name, r.rank, r.rankIndex, r.level, r.class, r.zone, r.note, r.officerNote,
        (r.online and "1" or "0"), r.lastOnline
      }))
    end
    if total > limit then
      FRT.Print("... (" .. tostring(total - limit) .. " more)")
    end
    return
  end

  if cmd == "clear" then
    EnsureSV()
    FRT_Saved.guildDump = { ts = 0, realm = "", guild = "", rows = {} }
    FRT.Print("Guild dump cleared.")
    return
  end

  FRT.Print("Unknown command. Use /frtguild help")
end

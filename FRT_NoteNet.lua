-- FRT_NoteNet.lua (Vanilla 1.12-safe, no '|' in addon traffic)
FRT = FRT or {}
FRT.NoteNet = FRT.NoteNet or {}

do
  local Net = FRT.NoteNet

  if FRT.RegisterAddonPrefix then FRT.RegisterAddonPrefix() end

  -- ---------- Config ----------
  local PREFIX          = FRT.ADDON_PREFIX or "FRT"
  local FRAME_TAG       = "N"        -- first byte/tag
  local SEP             = "\t"       -- safe separator (no pipes!)
  local MAX_LEN         = 240
  local SEND_STEP       = 0.20
  local CLEAN_AFTER     = 30

  -- Worst-case header for budget: "N\tv1\tID=999999\tS=999/999\tC=FFFF\t"
  local HEADER_WORST   = string.len(FRAME_TAG..SEP.."v1"..SEP.."ID=999999"..SEP.."S=999/999"..SEP.."C=FFFF"..SEP)
  -- Leave extra headroom for payload encoding (~ and | expansion)
  local PAYLOAD_BUDGET = (MAX_LEN - HEADER_WORST) - 16
  if PAYLOAD_BUDGET < 32 then PAYLOAD_BUDGET = 32 end

  -- ---------- Tiny checksum (16-bit) ----------
  local function csum16(s)
    local sum = 0
    for i = 1, string.len(s or "") do
      sum = math.mod(sum + string.byte(s, i), 65536)
    end
    return sum
  end
  local function tohex16(n)
    local t = "0123456789ABCDEF"
    local hi = math.mod(math.floor((n or 0) / 256), 256)
    local lo = math.mod((n or 0), 256)
    local function hx(v)
      local a = math.floor(v / 16)
      local b = math.mod(v, 16)
      return string.sub(t, a + 1, a + 1) .. string.sub(t, b + 1, b + 1)
    end
    return hx(hi) .. hx(lo)
  end

  -- ---------- Payload encoding (avoid raw '|') ----------
  local function encPayload(s)
    -- escape order matters: escape '~' first
    s = string.gsub(s or "", "~", "~~")
    s = string.gsub(s, "|", "~p")
    return s
  end
  local function decPayload(s)
    -- unescape order: '~p' -> '|', then '~~' -> '~'
    s = string.gsub(s or "", "~p", "|")
    s = string.gsub(s, "~~", "~")
    return s
  end

  -- ---------- Tag-safe split helpers ----------
  local function collectProtectedRanges(s)
    local ranges = {}
    local i = 1
    while true do
      local a, b = string.find(s, "%b{}", i)
      if not a then break end
      ranges[table.getn(ranges) + 1] = { a = a, b = b }
      i = b + 1
    end
    i = 1
    while true do
      local a, b = string.find(s, "%[color=#%x%x%x%x%x%x%]", i)
      if not a then break end
      ranges[table.getn(ranges) + 1] = { a = a, b = b }
      i = b + 1
    end
    i = 1
    while true do
      local a, b = string.find(s, "%[/color%]", i)
      if not a then break end
      ranges[table.getn(ranges) + 1] = { a = a, b = b }
      i = b + 1
    end
    table.sort(ranges, function(r1, r2) return r1.a < r2.a end)
    return ranges
  end
  local function inProtected(pos, ranges)
    for idx = 1, table.getn(ranges or {}) do
      local r = ranges[idx]
      if pos >= r.a and pos <= r.b then return r end
      if r.a > pos then break end
    end
    return nil
  end
  local function chooseCut(s, lo, hi, ranges)
    if hi < lo then return lo - 1 end
    local j = hi
    while j >= lo do
      local r = inProtected(j, ranges)
      if r then j = r.a - 1 else break end
    end
    if j < lo then
      local rlo = inProtected(lo, ranges)
      if rlo and (rlo.b - lo + 1) <= (hi - lo + 1) then
        return rlo.b
      else
        return hi
      end
    end
    local k = j
    while k >= lo do
      local ch = string.sub(s, k, k)
      if ch == " " or ch == "\t" or ch == "\n" then return k end
      local r = inProtected(k, ranges)
      if r then k = r.a - 1 else k = k - 1 end
    end
    return j
  end

  -- ---------- Sender (throttled queue, 1.12 uses arg1) ----------
  local sendQ = {}
  local pump = CreateFrame("Frame"); pump:Hide()
  local acc = 0
  pump:SetScript("OnUpdate", function()
    acc = acc + (arg1 or 0)
    if acc < SEND_STEP then return end
    acc = 0
    local n = table.getn(sendQ)
    if n == 0 then pump:Hide(); return end
    local job = sendQ[1]
    for i = 1, n - 1 do sendQ[i] = sendQ[i + 1] end
    sendQ[n] = nil

    FRT.RegisterAddonPrefix()
    if job.channel == "WHISPER" and job.target then
      SendAddonMessage(PREFIX, job.msg, "WHISPER", job.target)
    else
      SendAddonMessage(PREFIX, job.msg, job.channel or "RAID")
    end
  end)
  local function enqueue(msg, channel, target)
    sendQ[table.getn(sendQ) + 1] = { msg = msg, channel = channel or "RAID", target = target }
    pump:Show()
  end

  local nextId = math.mod(math.floor(GetTime() * 1000), 900000) + 100000
  local function newId()
    nextId = nextId + 1
    if nextId > 999999 then nextId = 100000 end
    return tostring(nextId)
  end

  -- ---------- Public send ----------
  function Net.Send(noteText, channel, target)
    local raw = tostring(noteText or "")
    local id  = newId()
    local chk = tohex16(csum16(raw))

    -- 1) Chunk on raw (safe for tags)
    local ranges = collectProtectedRanges(raw)
    local parts  = {}
    local i, n = 1, string.len(raw)
    local budget = PAYLOAD_BUDGET

    while i <= n do
      local hi = i + budget - 1; if hi > n then hi = n end
      local cut = chooseCut(raw, i, hi, ranges)
      if cut < i then cut = math.min(i + budget - 1, n) end
      parts[table.getn(parts) + 1] = string.sub(raw, i, cut)
      i = cut + 1
    end
    if table.getn(parts) == 0 then parts[1] = "" end
    local total = table.getn(parts)

    -- 2) Send frames (tab-separated header, encoded payload)
    for seq = 1, total do
      local header = FRAME_TAG..SEP.."v1"..SEP.."ID="..id..SEP.."S="..seq.."/"..total..SEP.."C="..chk..SEP
      local payload = encPayload(parts[seq])
      local msg = header .. payload
      -- Just-in-case fit check; if oversized, shrink by backing off a bit (won't break tags, worst-case re-send next call)
      if string.len(msg) > MAX_LEN then
        local room = MAX_LEN - string.len(header)
        payload = string.sub(payload, 1, room)
        msg = header .. payload
      end
      enqueue(msg, channel or "RAID", target)
    end

    return { id = id, total = total, checksum = chk }
  end

  -- ---------- Receiver / reassembly ----------
  local assemblies = {} -- key = sender..":"..id
  local function keyOf(sender, id) return (sender or "?") .. ":" .. (id or "?") end

  local function cleanupOld()
    local now = GetTime()
    for k, as in pairs(assemblies) do
      if (now - (as.startedAt or now)) > CLEAN_AFTER then assemblies[k] = nil end
    end
  end

  local function tryEmit(k, sender)
    local as = assemblies[k]; if not as or as.got ~= as.total then return end
    local buf = {}
    for i = 1, as.total do buf[i] = as.parts[i] or "" end
    local encAll = table.concat(buf, "")
    local raw = decPayload(encAll)
    if tohex16(csum16(raw)) ~= (as.chk or "") then assemblies[k] = nil; return end
    assemblies[k] = nil
    if Net.onNoteReceived then Net.onNoteReceived(sender, raw, { id = as.id, total = as.total, checksum = as.chk }) end
  end

  local rx = CreateFrame("Frame")
  rx:RegisterEvent("CHAT_MSG_ADDON")
  rx:SetScript("OnEvent", function()
    if event ~= "CHAT_MSG_ADDON" then return end
    local prefix, msg, channel, sender = arg1, arg2, arg3, arg4
    if prefix ~= PREFIX then return end
    if type(msg) ~= "string" then return end
    if string.sub(msg, 1, 1) ~= FRAME_TAG then return end

    -- Parse "N\tv1\tID=..\tS=seq/total\tC=chk\t<encoded-payload>"
    local _, p1 = string.find(msg, "^"..FRAME_TAG..SEP.."v1"..SEP.."ID=")
    if not p1 then return end
    local a1, b1, id = string.find(msg, "^"..FRAME_TAG..SEP.."v1"..SEP.."ID=([0-9]+)"..SEP)
    if not a1 then return end
    local pat2 = "^"..FRAME_TAG..SEP.."v1"..SEP.."ID="..id..SEP.."S=([0-9]+)/([0-9]+)"..SEP
    local a2, b2, seq, total = string.find(msg, pat2)
    if not a2 then return end
    local pat3 = "^"..FRAME_TAG..SEP.."v1"..SEP.."ID="..id..SEP.."S="..seq.."/"..total..SEP.."C=([0-9A-Fa-f]+)"..SEP
    local a3, b3, chk = string.find(msg, pat3)
    if not a3 then return end

    local payload = string.sub(msg, (b3 or 0) + 1)
    seq   = tonumber(seq) or 0
    total = tonumber(total) or 0
    if seq < 1 or total < 1 or seq > total then return end

    local k = keyOf(sender, id)
    local as = assemblies[k]
    if not as then
      as = { id = id, total = total, chk = string.upper(chk or ""), parts = {}, got = 0, startedAt = GetTime() }
      assemblies[k] = as
    end
    if not as.parts[seq] then
      as.parts[seq] = payload
      as.got = as.got + 1
    end
    tryEmit(k, sender)
    cleanupOld()
  end)

  Net.onNoteReceived = Net.onNoteReceived or nil
end

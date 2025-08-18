-- Fingbel Raid Tool - Shared Library Helpers (Vanilla 1.12 / Lua 5.0)
--FRT_SharedLibrary.lua
FRT = FRT or {}
FRT.SharedLib = FRT.SharedLib or {}
local SL = FRT.SharedLib

-- Ensure library array exists.
function SL.EnsureSaved()
  if type(FRT_Saved) ~= "table" then FRT_Saved = {} end
  FRT_Saved.notes = FRT_Saved.notes or {}
end

-- Find by id, return (note, index) or (nil)
function SL.FindById(id)
  SL.EnsureSaved()
  local arr = FRT_Saved.notes
  for i = 1, table.getn(arr) do
    local n = arr[i]
    if n and n.id == id then return n, i end
  end
  return nil
end

-- Upsert shared note into array form (keeps your UI intact).
-- meta: { id, version, hash, title, raid, boss }, text: string
function SL.Upsert(meta, text)
  SL.EnsureSaved()
  local arr = FRT_Saved.notes
  local n, idx = SL.FindById(meta.id)
  if n then
    n.title    = meta.title or n.title
    n.raid     = meta.raid  or n.raid
    n.boss     = meta.boss  or n.boss
    n.text     = text or n.text
    n.version  = tonumber(meta.version) or (n.version or 1)
    n.hash     = meta.hash or n.hash
    n.modified = GetTime and GetTime() or (n.modified or 0)
  else
    table.insert(arr, {
      id       = meta.id,
      title    = meta.title or "",
      raid     = meta.raid  or "Custom/Misc",
      boss     = meta.boss  or "General",
      text     = text or "",
      created  = GetTime and GetTime() or 0,
      modified = GetTime and GetTime() or 0,
      version  = tonumber(meta.version) or 1,
      hash     = meta.hash or "",
    })
  end
end

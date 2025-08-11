-- FRT_Group.lua
-- Group/roster helpers (party/raid stitching, offline filtering, sorting)

FRT = FRT or {}
FRT.Group = FRT.Group or {}

do
  local D = FRT.Data or {}

  local function isConnected(unit)
    return (UnitIsConnected and UnitIsConnected(unit)) and true or false
  end

  function FRT.Group.IsGroupUnit(u)
    if not u then return false end
    local p4 = string.sub(u,1,4) ; local p5 = string.sub(u,1,5)
    return (u == "player") or (p4 == "raid") or (p5 == "party")
  end

  function FRT.Group.BuildRoster()
    local roster = {}
    local nRaid = GetNumRaidMembers and GetNumRaidMembers() or 0

    if nRaid > 0 then
      local i=1
      while i <= nRaid do
        local name, rank, subgroup, level, class, fileName, zone, online = GetRaidRosterInfo(i)
        local unit = "raid"..i
        if name and online and isConnected(unit) then
          table.insert(roster, { name=name, unit=unit, class=(fileName or class or "UNKNOWN"), subgroup=(subgroup or 9) })
        end
        i=i+1
      end
    else
      if not isConnected("player") then return roster end
      local pName = UnitName("player") or "player"
      local loc, file = UnitClass("player")
      table.insert(roster, { name=pName, unit="player", class=(file or loc or "UNKNOWN"), subgroup=1 })

      local nParty = GetNumPartyMembers and GetNumPartyMembers() or 0
      local j=1
      while j <= nParty do
        local u = "party"..j
        if isConnected(u) then
          local nm = UnitName(u) or u
          local pl, pf = UnitClass(u)
          table.insert(roster, { name=nm, unit=u, class=(pf or pl or "UNKNOWN"), subgroup=1 })
        end
        j=j+1
      end
    end

    table.sort(roster, function(a,b)
      if a.subgroup ~= b.subgroup then return (a.subgroup or 9) < (b.subgroup or 9) end
      local order = D.ClassOrder or {}
      local ca = order[a.class or "UNKNOWN"] or 999
      local cb = order[b.class or "UNKNOWN"] or 999
      if ca ~= cb then return ca < cb end
      return (a.name or "") < (b.name or "")
    end)
    return roster
  end
end

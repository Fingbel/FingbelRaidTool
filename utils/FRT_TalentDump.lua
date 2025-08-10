-- Fingbel Raid Tool — Talent Dump 

SLASH_FRTTALENTS1 = "/frttalents"

local function DumpPickedTalents()
  if not GetNumTalentTabs or not GetTalentTabInfo or not GetNumTalents or not GetTalentInfo then
    DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[FRT]|r Talent API unavailable.")
    return
  end

  local classLoc = (select and select(1, UnitClass("player"))) or UnitClass("player") or "Class"
  DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[FRT]|r Talents for "..classLoc..":")

  local totalSpent = 0
  local tabs = GetNumTalentTabs() or 0
  for tabIndex = 1, tabs do
    local tabName, tabIcon, pointsSpent = GetTalentTabInfo(tabIndex)
    pointsSpent = pointsSpent or 0
    totalSpent = totalSpent + pointsSpent

    -- Collect picked talents in this tab
    local picked = {}
    local numTalents = GetNumTalents(tabIndex) or 0
    for talentIndex = 1, numTalents do
      local name, iconTexture, tier, column, rank, maxRank = GetTalentInfo(tabIndex, talentIndex)
      -- rank = points taken in this talent
      if (rank or 0) > 0 then
        table.insert(picked, { name = name or ("Talent "..talentIndex),
                               tier = tier or 0, col = column or 0,
                               rank = rank or 0, max = maxRank or 0 })
      end
    end

    if table.getn(picked) > 0 then
      DEFAULT_CHAT_FRAME:AddMessage(string.format("  |cffffff00%s|r (%d points):", tabName or ("Tree "..tabIndex), pointsSpent))
      -- Sort by tier then column for readability
      table.sort(picked, function(a,b) if a.tier ~= b.tier then return a.tier < b.tier end return a.col < b.col end)
      for i = 1, table.getn(picked) do
        local t = picked[i]
        DEFAULT_CHAT_FRAME:AddMessage(string.format("    Tier %d, Col %d: %s |cffffffff(%d/%d)|r",
          t.tier, t.col, t.name, t.rank, t.max))
      end
    else
      -- Uncomment if you want to also print empty trees
      -- DEFAULT_CHAT_FRAME:AddMessage(string.format("  %s: (no points)", tabName or ("Tree "..tabIndex)))
    end
  end

  DEFAULT_CHAT_FRAME:AddMessage(string.format("|cff00ff00[FRT]|r Total points spent: %d", totalSpent))
end

SlashCmdList["FRTTALENTS"] = function(msg)
  DumpPickedTalents()
end
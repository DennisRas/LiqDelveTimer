---@class LDT_Addon
local addon = select(2, ...)

---@class LDT_ApiLog
local ApiLog = {}
addon.ApiLog = ApiLog

local Capture = addon.Capture
local Data = addon.Data

ApiLog.lastPacked = nil
ApiLog.lastLines = nil

---@param line string
---@return string
local function LineKey(line)
  return line:match("^(%S+)") or line
end

---@param value any
---@return string
local function ValueText(value)
  if value == nil then
    return "nil"
  end
  local valueType = type(value)
  if valueType == "string" then
    return format("%q", value)
  end
  if valueType == "number" or valueType == "boolean" then
    return tostring(value)
  end
  return valueType
end

---@param ... any
---@return string
local function ArgsText(...)
  local count = select("#", ...)
  if count == 0 then
    return ""
  end
  local parts = {}
  for index = 1, count do
    parts[index] = ValueText(select(index, ...))
  end
  return table.concat(parts, " ")
end

---@param spellIDs number[]|nil
---@return string
local function SpellText(spellIDs)
  if not spellIDs then
    return "nil"
  end
  local parts = {}
  for index = 1, #spellIDs do
    local spellID = spellIDs[index]
    local spellName
    local ok, name = pcall(C_Spell.GetSpellName, spellID)
    if ok then
      spellName = name
    end
    if spellName and spellName ~= "" then
      parts[index] = format("%s:%d", spellName, spellID)
    else
      parts[index] = tostring(spellID)
    end
  end
  if #parts == 0 then
    return "none"
  end
  return table.concat(parts, ", ")
end

---@param prefix string
---@param message string
function ApiLog:Log(prefix, message)
  local logger = addon.logger
  if not logger then
    return
  end
  logger:Log(prefix, message)
end

---@param lines string[]
---@param label string
---@param fn fun(lines: string[])
local function Catch(lines, label, fn)
  local ok, err = pcall(fn, lines)
  if not ok then
    lines[#lines + 1] = format("%s error=%s", label, ValueText(err))
  end
end

---@param lines string[]
local function DescribeDelve(lines)
  local hasActive = C_DelvesUI.HasActiveDelve()
  local inProgress = C_PartyInfo.IsDelveInProgress()
  local delveComplete = C_PartyInfo.IsDelveComplete()
  local tieredScenario = C_ScenarioInfo.IsTieredEntranceScenario()
  local entranceType = C_DelvesUI.GetTieredEntranceType()
  local seasonNumber = C_DelvesUI.GetCurrentDelvesSeasonNumber()
  local worldTier = C_DelvesUI.GetWorldTierDifficultyForActivePlayer()
  local pdeID = C_DelvesUI.GetTieredEntrancePDEID()
  local entranceMapID = C_DelvesUI.GetDelveEntranceMapID()
  local factionID = C_DelvesUI.GetDelvesFactionForSeason()
  local minLevel = C_DelvesUI.GetDelvesMinRequiredLevel()
  local hasLair = C_DelvesUI.HasActiveLair()
  local hasLFGLair = C_DelvesUI.HasActiveLFGLair()
  local inLair = C_DelvesUI.IsInLair()
  local affixTreeID = C_DelvesUI.GetTieredEntranceOptionalAffixTraitTreeID()
  local backgroundWidgetSetID = C_DelvesUI.GetDelveEntranceBackgroundWidgetSetID()
  local eligible = C_DelvesUI.IsEligibleForActiveDelveRewards("player")
  lines[#lines + 1] = format(
    "delve hasActive=%s inProgress=%s complete=%s tieredScenario=%s entranceType=%s season=%s worldTier=%s pde=%s entranceMap=%s faction=%s minLevel=%s hasLair=%s hasLFGLair=%s inLair=%s affixTree=%s backgroundWidget=%s eligible=%s",
    ValueText(hasActive),
    ValueText(inProgress),
    ValueText(delveComplete),
    ValueText(tieredScenario),
    ValueText(entranceType),
    ValueText(seasonNumber),
    ValueText(worldTier),
    ValueText(pdeID),
    ValueText(entranceMapID),
    ValueText(factionID),
    ValueText(minLevel),
    ValueText(hasLair),
    ValueText(hasLFGLair),
    ValueText(inLair),
    ValueText(affixTreeID),
    ValueText(backgroundWidgetSetID),
    ValueText(eligible)
  )
  lines[#lines + 1] = format(
    "entrance title=%s header=%s description=%s",
    ValueText(C_DelvesUI.GetDelveEntranceTitleString()),
    ValueText(C_DelvesUI.GetDelveEntranceHeaderString()),
    ValueText(C_DelvesUI.GetDelveEntranceDescriptionString())
  )
  lines[#lines + 1] = format(
    "spells affix=%s active=%s",
    SpellText(C_DelvesUI.GetDelvesAffixSpellsForSeason()),
    SpellText(C_ScenarioInfo.GetTieredEntranceActiveSpells())
  )
  if hasActive then
    local tierInfo = C_DelvesUI.GetActiveDelveTier()
    if tierInfo then
      lines[#lines + 1] = format(
        "activeTier tier=%s difficulty=%s unlocked=%s queueLFG=%s suggested=%s widget=%s tooltipSpell=%s locked=%s desc=%s",
        ValueText(tierInfo.tier),
        ValueText(tierInfo.difficultyID),
        ValueText(tierInfo.unlocked),
        ValueText(tierInfo.queueAsLFG),
        ValueText(tierInfo.suggestedILvl),
        ValueText(tierInfo.modifierUIWidgetSetID),
        ValueText(tierInfo.overrideTooltipSpellID),
        ValueText(tierInfo.lockedReason),
        ValueText(tierInfo.tierDescription)
      )
      local enabled, failureReason = C_DelvesUI.IsDelveEntranceTierEnabled(tierInfo.tier)
      lines[#lines + 1] = format("activeTierEnabled enabled=%s reason=%s", ValueText(enabled), ValueText(failureReason))
      local rewards = tierInfo.rewards
      if rewards then
        local rewardParts = {}
        for index = 1, #rewards do
          local reward = rewards[index]
          rewardParts[index] = format(
            "%d:id=%s:qty=%s:type=%s:context=%s",
            index,
            ValueText(reward.id),
            ValueText(reward.quantity),
            ValueText(reward.rewardType),
            ValueText(reward.context)
          )
        end
        local rewardText = "none"
        if #rewardParts > 0 then
          rewardText = table.concat(rewardParts, " | ")
        end
        lines[#lines + 1] = format("activeTierRewards %s", rewardText)
      end
    else
      lines[#lines + 1] = "activeTier nil"
    end
  end
  local entranceTiers = C_DelvesUI.GetDelveEntranceTiers()
  local tierParts = {}
  if entranceTiers then
    for index = 1, #entranceTiers do
      local tierInfo = entranceTiers[index]
      tierParts[index] = format(
        "%s:%s:%s",
        ValueText(tierInfo.tier),
        ValueText(tierInfo.unlocked),
        ValueText(tierInfo.difficultyID)
      )
    end
  end
  local tierText = "none"
  if #tierParts > 0 then
    tierText = table.concat(tierParts, ", ")
  end
  lines[#lines + 1] = format("entranceTiers %s", tierText)
end

---@param lines string[]
local function DescribeCompanion(lines)
  local companionID = C_DelvesUI.GetCompanionInfoForActivePlayer()
  if not companionID or companionID <= 0 then
    lines[#lines + 1] = format("companion id=%s", ValueText(companionID))
    return
  end
  local displayID = C_DelvesUI.GetCreatureDisplayInfoForCompanion(companionID)
  local factionID = C_DelvesUI.GetFactionForCompanion(companionID)
  local flavorName = C_DelvesUI.GetFlavorNodeNameForCompanion(companionID)
  local flavorNodeID = C_DelvesUI.GetFlavorNodeForCompanion(companionID)
  local roleNodeID = C_DelvesUI.GetRoleNodeForCompanion(companionID)
  local treeID = C_DelvesUI.GetTraitTreeForCompanion(companionID)
  local combatNodeID = C_DelvesUI.GetCurioNodeForCompanion(Enum.CurioType.Combat, companionID)
  local utilityNodeID = C_DelvesUI.GetCurioNodeForCompanion(Enum.CurioType.Utility, companionID)
  local modelSceneID = C_DelvesUI.GetModelSceneForCompanion(companionID)
  local companionPDE = C_DelvesUI.GetPlayerCompanionPDEID(companionID)
  local dpsTreeID = C_DelvesUI.GetRoleSubtreeForCompanion(Enum.CompanionRoleType.Dps, companionID)
  local healTreeID = C_DelvesUI.GetRoleSubtreeForCompanion(Enum.CompanionRoleType.Heal, companionID)
  local tankTreeID = C_DelvesUI.GetRoleSubtreeForCompanion(Enum.CompanionRoleType.Tank, companionID)
  local lockedText = C_DelvesUI.GetLockedTextForCompanion(companionID)
  local factionName
  local factionDescription
  if factionID and factionID > 0 then
    local faction = C_Reputation.GetFactionDataByID(factionID)
    if faction then
      factionName = faction.name
      factionDescription = faction.description
    end
  end
  local level
  local maxLevel
  if factionID and factionID > 0 then
    local ranks = C_GossipInfo.GetFriendshipReputationRanks(factionID)
    if ranks then
      level = ranks.currentLevel
      maxLevel = ranks.maxLevel
    end
  end
  lines[#lines + 1] = format(
    "companion id=%s display=%s model=%s pde=%s faction=%s name=%s level=%s/%s flavor=%s flavorNode=%s roleNode=%s tree=%s dps=%s heal=%s tank=%s combatNode=%s utilityNode=%s",
    ValueText(companionID),
    ValueText(displayID),
    ValueText(modelSceneID),
    ValueText(companionPDE),
    ValueText(factionID),
    ValueText(factionName),
    ValueText(level),
    ValueText(maxLevel),
    ValueText(flavorName),
    ValueText(flavorNodeID),
    ValueText(roleNodeID),
    ValueText(treeID),
    ValueText(dpsTreeID),
    ValueText(healTreeID),
    ValueText(tankTreeID),
    ValueText(combatNodeID),
    ValueText(utilityNodeID)
  )
  lines[#lines + 1] = format(
    "companionText description=%s locked=%s",
    ValueText(factionDescription),
    ValueText(lockedText)
  )
end

---@param lines string[]
local function DescribeInstance(lines)
  local name, instanceType, difficultyID, difficultyName, maxPlayers, dynamicDifficulty, isDynamic, instanceID, instanceGroupSize, lfgDungeonID, hasWorldTier = GetInstanceInfo()
  local mapID = C_Map.GetBestMapForUnit("player")
  local mapName
  if mapID then
    local mapInfo = C_Map.GetMapInfo(mapID)
    if mapInfo then
      mapName = mapInfo.name
    end
  end
  lines[#lines + 1] = format(
    "instance name=%s type=%s difficulty=%s:%s maxPlayers=%s dynamic=%s:%s id=%s size=%s lfg=%s worldTier=%s map=%s:%s zone=%s subzone=%s",
    ValueText(name),
    ValueText(instanceType),
    ValueText(difficultyID),
    ValueText(difficultyName),
    ValueText(maxPlayers),
    ValueText(dynamicDifficulty),
    ValueText(isDynamic),
    ValueText(instanceID),
    ValueText(instanceGroupSize),
    ValueText(lfgDungeonID),
    ValueText(hasWorldTier),
    ValueText(mapID),
    ValueText(mapName),
    ValueText(GetZoneText()),
    ValueText(GetSubZoneText())
  )
end

---@param lines string[]
local function DescribeScenario(lines)
  local info = C_ScenarioInfo.GetScenarioInfo()
  if info then
    lines[#lines + 1] = format(
      "scenario name=%s id=%s stage=%s/%s complete=%s type=%s area=%s flags=%s xp=%s money=%s kit=%s",
      ValueText(info.name),
      ValueText(info.scenarioID),
      ValueText(info.currentStage),
      ValueText(info.numStages),
      ValueText(info.isComplete),
      ValueText(info.type),
      ValueText(info.area),
      ValueText(info.flags),
      ValueText(info.xp),
      ValueText(info.money),
      ValueText(info.uiTextureKit)
    )
  else
    lines[#lines + 1] = "scenario nil"
  end
  local step = C_ScenarioInfo.GetScenarioStepInfo()
  if not step then
    lines[#lines + 1] = "step nil"
    return
  end
  lines[#lines + 1] = format(
    "step id=%s title=%s criteria=%s failed=%s bonus=%s currentOnly=%s showBonus=%s quest=%s widget=%s desc=%s",
    ValueText(step.stepID),
    ValueText(step.title),
    ValueText(step.numCriteria),
    ValueText(step.stepFailed),
    ValueText(step.isBonusStep),
    ValueText(step.isForCurrentStepOnly),
    ValueText(step.shouldShowBonusObjective),
    ValueText(step.rewardQuestID),
    ValueText(step.widgetSetID),
    ValueText(step.description)
  )
  local spells = step.spells
  if spells and #spells > 0 then
    local spellParts = {}
    for index = 1, #spells do
      local spell = spells[index]
      spellParts[index] = format("%s:%s", ValueText(spell.name), ValueText(spell.spellID))
    end
    lines[#lines + 1] = format("stepSpells %s", table.concat(spellParts, ", "))
  end
  local criteriaParts = {}
  for index = 1, step.numCriteria do
    local ok, text = pcall(function()
      local criteria = C_ScenarioInfo.GetCriteriaInfo(index)
      if not criteria then
        return format("%d:nil", index)
      end
      return format(
        "%d:id=%s:done=%s:failed=%s:qty=%s/%s:text=%s:flags=%s:asset=%s:type=%s:weighted=%s:%s",
        index,
        ValueText(criteria.criteriaID),
        ValueText(criteria.completed),
        ValueText(criteria.failed),
        ValueText(criteria.quantity),
        ValueText(criteria.totalQuantity),
        ValueText(criteria.quantityString),
        ValueText(criteria.flags),
        ValueText(criteria.assetID),
        ValueText(criteria.criteriaType),
        ValueText(criteria.isWeightedProgress),
        ValueText(criteria.description)
      )
    end)
    if ok then
      criteriaParts[index] = text
    else
      criteriaParts[index] = format("%d:error=%s", index, ValueText(text))
    end
  end
  local criteriaText = "none"
  if #criteriaParts > 0 then
    criteriaText = table.concat(criteriaParts, " | ")
  end
  lines[#lines + 1] = format("criteria %s", criteriaText)
end

---@param lines string[]
local function DescribeVault(lines)
  local activities = C_WeeklyRewards.GetActivities(Enum.WeeklyRewardChestThresholdType.World)
  local parts = {}
  if activities then
    for index = 1, #activities do
      local activity = activities[index]
      local rewardParts = {}
      local rewards = activity.rewards
      if rewards then
        for rewardIndex = 1, #rewards do
          local reward = rewards[rewardIndex]
          rewardParts[rewardIndex] = format(
            "%s:%s:%s",
            ValueText(reward.type),
            ValueText(reward.id),
            ValueText(reward.quantity)
          )
        end
      end
      local rewardText = "none"
      if #rewardParts > 0 then
        rewardText = table.concat(rewardParts, ",")
      end
      parts[index] = format(
        "%d:progress=%s:threshold=%s:level=%s:activityTier=%s:id=%s:index=%s:claim=%s:raid=%s:rewards=%s",
        index,
        ValueText(activity.progress),
        ValueText(activity.threshold),
        ValueText(activity.level),
        ValueText(activity.activityTierID),
        ValueText(activity.id),
        ValueText(activity.index),
        ValueText(activity.claimID),
        ValueText(activity.raidString),
        rewardText
      )
    end
  end
  local text = "none"
  if #parts > 0 then
    text = table.concat(parts, " | ")
  end
  lines[#lines + 1] = format("vault %s", text)
end

---@param lines string[]
local function DescribeCapture(lines)
  local record = Data:GetActiveRecord()
  local recordID = "nil"
  local result = "nil"
  local labyrinth = "nil"
  local chambers = "nil"
  local credits = "nil"
  local boss = "nil"
  if record then
    recordID = record.id
    result = record.result
    labyrinth = ValueText(record.labyrinth)
    local completed = 0
    for index = 1, #record.chambers do
      if record.chambers[index].completedElapsed then
        completed = completed + 1
      end
    end
    chambers = format("%d/%d", completed, #record.chambers)
    credits = tostring(record.vault.credits)
    if record.bossName then
      boss = format("%s@%s", record.bossName, ValueText(record.bossElapsed))
    end
  end
  lines[#lines + 1] = format(
    "capture ready=%s inside=%s clock=%s record=%s result=%s labyrinth=%s chambers=%s vaultCredits=%s boss=%s",
    ValueText(Capture.ready),
    ValueText(Capture:IsInside()),
    ValueText(Capture.clockReady),
    recordID,
    result,
    labyrinth,
    chambers,
    credits,
    boss
  )
end

---@return string[]
function ApiLog:CollectState()
  local lines = {}
  Catch(lines, "delve", DescribeDelve)
  Catch(lines, "companion", DescribeCompanion)
  Catch(lines, "instance", DescribeInstance)
  Catch(lines, "scenario", DescribeScenario)
  Catch(lines, "vault", DescribeVault)
  Catch(lines, "capture", DescribeCapture)
  return lines
end

---@param lines string[]
---@param packed string
function ApiLog:EmitState(lines, packed)
  local previous = self.lastLines
  self.lastPacked = packed
  self.lastLines = lines
  if not previous then
    for index = 1, #lines do
      self:Log("state", lines[index])
    end
    return
  end
  for index = 1, #lines do
    local line = lines[index]
    local key = LineKey(line)
    local same = false
    for previousIndex = 1, #previous do
      local previousLine = previous[previousIndex]
      if LineKey(previousLine) == key then
        same = previousLine == line
        break
      end
    end
    if not same then
      self:Log("state", line)
    end
  end
  for previousIndex = 1, #previous do
    local key = LineKey(previous[previousIndex])
    local found = false
    for index = 1, #lines do
      if LineKey(lines[index]) == key then
        found = true
        break
      end
    end
    if not found then
      self:Log("state", format("%s cleared", key))
    end
  end
end

function ApiLog:LogState()
  local lines = self:CollectState()
  local packed = table.concat(lines, "\n")
  if packed == self.lastPacked then
    return
  end
  self:EmitState(lines, packed)
end

---@param event string
---@param ... any
function ApiLog:OnEvent(event, ...)
  local args = ArgsText(...)
  if args == "" then
    self:Log("event", event)
  else
    self:Log("event", format("%s %s", event, args))
  end
  self:LogState()
end

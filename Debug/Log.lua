---@class LDT_Addon
local addon = select(2, ...)

---@class LDT_Log
local Log = {}
addon.Log = Log

local Capture = addon.Capture
local Data = addon.Data

Log.lastPacked = nil
Log.lastLines = nil

local seenStepList = {}
local seenStepSet = {}

local MAX_CRITERIA = 40

local scenarioFields = {
  "name",
  "scenarioID",
  "currentStage",
  "numStages",
  "flags",
  "isComplete",
  "xp",
  "money",
  "type",
  "area",
  "uiTextureKit",
}

local scenarioInfoLabels = {
  "name",
  "currentStage",
  "numStages",
  "flags",
  "hasBonusStep",
  "isBonusStepComplete",
  "isComplete",
  "xp",
  "money",
  "type",
  "area",
  "uiTextureKit",
  "scenarioID",
}

local stepFields = {
  "stepID",
  "title",
  "description",
  "numCriteria",
  "stepFailed",
  "isBonusStep",
  "isForCurrentStepOnly",
  "shouldShowBonusObjective",
  "weightedProgress",
  "rewardQuestID",
  "widgetSetID",
  "spells",
}

local stepInfoLabels = {
  "title",
  "description",
  "numCriteria",
  "stepFailed",
  "isBonusStep",
  "isForCurrentStepOnly",
  "shouldShowBonusObjective",
  "numSpells",
  "spells",
  "weightedProgress",
  "rewardQuestID",
  "widgetSetID",
}

local criteriaFields = {
  "criteriaID",
  "description",
  "completed",
  "failed",
  "quantity",
  "totalQuantity",
  "quantityString",
  "flags",
  "assetID",
  "criteriaType",
  "duration",
  "elapsed",
  "isWeightedProgress",
  "isFormatted",
}

local displayFields = {
  "startSoundKitID",
  "themeColor",
}

local tierFields = {
  "tier",
  "unlocked",
  "queueAsLFG",
  "suggestedILvl",
  "difficultyID",
  "modifierUIWidgetSetID",
  "overrideTooltipSpellID",
  "lockedReason",
  "tierDescription",
}

---@param index number
---@param ... any
---@return string
local function textAt(index, ...)
  if select(index, ...) == nil then
    return "nil"
  end
  if issecretvalue(select(index, ...)) then
    return "secret"
  end
  if type(select(index, ...)) == "string" then
    return format("%q", select(index, ...))
  end
  if type(select(index, ...)) == "number" or type(select(index, ...)) == "boolean" then
    return tostring(select(index, ...))
  end
  if type(select(index, ...)) ~= "table" then
    return type(select(index, ...))
  end
  ---@type table
  local value = select(index, ...)
  if #value > 0 then
    local parts = {}
    for itemIndex = 1, #value do
      parts[itemIndex] = textAt(1, value[itemIndex])
    end
    return table.concat(parts, ",")
  end
  if next(value) == nil then
    return "none"
  end
  local named = {
    "headerText",
    "text",
    "leadingText",
    "tooltip",
    "title",
    "description",
    "name",
    "tierText",
    "spellID",
    "spellInfo",
    "iconFileID",
    "isCurrencyMaxed",
    "stackDisplay",
    "shownState",
    "enabledState",
    "earnedTooltip",
    "unearnedTooltip",
    "id",
    "criteriaID",
    "quantity",
    "r",
    "g",
    "b",
  }
  local parts = {}
  for namedIndex = 1, #named do
    local key = named[namedIndex]
    if value[key] ~= nil then
      parts[#parts + 1] = format("%s=%s", key, textAt(1, value[key]))
    end
  end
  if #parts == 0 then
    return "unindexed"
  end
  return table.concat(parts, ",")
end

---@param value string|number|boolean|table|nil
---@return string
local function valueText(value)
  return textAt(1, value)
end

---@param stepID number
local function rememberStep(stepID)
  if type(stepID) ~= "number" or issecretvalue(stepID) or seenStepSet[stepID] then
    return
  end
  seenStepSet[stepID] = true
  seenStepList[#seenStepList + 1] = stepID
end

---@param lines string[]
---@param key string
---@param info table|nil
---@param fields string[]
local function addStruct(lines, key, info, fields)
  if info == nil then
    lines[#lines + 1] = format("%s nil", key)
    return
  end
  local parts = {}
  for index = 1, #fields do
    local fieldName = fields[index]
    parts[index] = format("%s=%s", fieldName, textAt(1, info[fieldName]))
  end
  lines[#lines + 1] = format("%s %s", key, table.concat(parts, " "))
end

---@param labels string[]|nil
---@param ... any
---@return string
local function positionalText(labels, ...)
  local count = select("#", ...)
  if count == 0 then
    return "nil"
  end
  local parts = {}
  for index = 1, count do
    local label = labels and labels[index] or ""
    if label == "" then
      label = tostring(index)
    end
    parts[index] = format("%s=%s", label, textAt(index, ...))
  end
  return table.concat(parts, " ")
end

---@param labels string[]|nil
---@param fn function
---@param ... any
---@return string
local function describeCall(labels, fn, ...)
  if labels then
    return positionalText(labels, fn(...))
  end
  return textAt(1, fn(...))
end

---@param lines string[]
---@param key string
---@param labels string[]|nil
---@param fn function
---@param ... any
local function addCall(lines, key, labels, fn, ...)
  local ok, text = pcall(describeCall, labels, fn, ...)
  if not ok or type(text) ~= "string" then
    local err = "error"
    if type(text) == "string" then
      err = format("error=%s", text)
    end
    lines[#lines + 1] = format("%s %s", key, err)
    return
  end
  lines[#lines + 1] = format("%s %s", key, text)
end

---@param lines string[]
---@param key string
---@param numCriteria number|nil
---@param stepID number|nil
local function addCriteria(lines, key, numCriteria, stepID)
  local count = numCriteria or 0
  if count < 0 then
    count = 0
  end
  if count > MAX_CRITERIA then
    count = MAX_CRITERIA
  end
  if count == 0 then
    if stepID then
      lines[#lines + 1] = format("GetCriteriaInfoByStep(%s) none", valueText(stepID))
    else
      lines[#lines + 1] = "GetCriteriaInfo none"
    end
    return
  end
  for index = 1, count do
    local lineKey = format("%s(%d)", key, index)
    local ok, info
    if stepID then
      lineKey = format("GetCriteriaInfoByStep(%s,%d)", valueText(stepID), index)
      ok, info = pcall(C_ScenarioInfo.GetCriteriaInfoByStep, stepID, index)
    else
      ok, info = pcall(C_ScenarioInfo.GetCriteriaInfo, index)
    end
    if not ok then
      local err = "error"
      if type(info) == "string" then
        err = format("error=%s", info)
      end
      lines[#lines + 1] = format("%s %s", lineKey, err)
    elseif type(info) == "table" then
      addStruct(lines, lineKey, info, criteriaFields)
    else
      lines[#lines + 1] = format("%s nil", lineKey)
    end
  end
end

---@param lines string[]
---@param stepID number
local function addStepByID(lines, stepID)
  local key = format("GetScenarioStepInfo(%s)", valueText(stepID))
  local ok, info = pcall(C_ScenarioInfo.GetScenarioStepInfo, stepID)
  if not ok then
    local err = "error"
    if type(info) == "string" then
      err = format("error=%s", info)
    end
    lines[#lines + 1] = format("%s %s", key, err)
    return
  end
  if type(info) ~= "table" then
    lines[#lines + 1] = format("%s nil", key)
    return
  end
  addStruct(lines, key, info, stepFields)
  local numCriteria = 0
  if type(info.numCriteria) == "number" then
    numCriteria = info.numCriteria
  end
  if type(info.stepID) == "number" then
    rememberStep(info.stepID)
  end
  addCriteria(lines, "GetCriteriaInfoByStep", numCriteria, stepID)
end

---@param lines string[]
local function addScenario(lines)
  if type(GetNumScenarios) == "function" then
    addCall(lines, "GetNumScenarios", nil, GetNumScenarios)
  else
    lines[#lines + 1] = "GetNumScenarios nil"
  end
  local ok, info = pcall(C_ScenarioInfo.GetScenarioInfo)
  if not ok then
    local err = "error"
    if type(info) == "string" then
      err = format("error=%s", info)
    end
    lines[#lines + 1] = format("GetScenarioInfo %s", err)
  elseif type(info) == "table" then
    addStruct(lines, "GetScenarioInfo", info, scenarioFields)
  else
    lines[#lines + 1] = "GetScenarioInfo nil"
  end
  local displayOK, displayInfo = pcall(C_ScenarioInfo.GetDisplayInfo)
  if not displayOK then
    local err = "error"
    if type(displayInfo) == "string" then
      err = format("error=%s", displayInfo)
    end
    lines[#lines + 1] = format("GetDisplayInfo %s", err)
  elseif type(displayInfo) == "table" then
    addStruct(lines, "GetDisplayInfo", displayInfo, displayFields)
  else
    lines[#lines + 1] = "GetDisplayInfo nil"
  end
  addCall(lines, "IsTieredEntranceScenario", nil, C_ScenarioInfo.IsTieredEntranceScenario)
  addCall(lines, "GetTieredEntranceActiveSpells", nil, C_ScenarioInfo.GetTieredEntranceActiveSpells)
  if not C_Scenario then
    lines[#lines + 1] = "C_Scenario nil"
    return
  end
  addCall(lines, "IsInScenario", nil, C_Scenario.IsInScenario)
  addCall(lines, "ShouldShowCriteria", nil, C_Scenario.ShouldShowCriteria)
  addCall(lines, "TreatScenarioAsDungeon", nil, C_Scenario.TreatScenarioAsDungeon)
  addCall(lines, "GetInfo", scenarioInfoLabels, C_Scenario.GetInfo)
  addCall(lines, "GetProvingGroundsInfo", { "difficultyID", "currWave", "maxWave", "duration" }, C_Scenario.GetProvingGroundsInfo)
  addCall(lines, "GetBonusSteps", nil, C_Scenario.GetBonusSteps)
  addCall(lines, "GetSupersededObjectives", nil, C_Scenario.GetSupersededObjectives)
  if type(IsInJailersTower) == "function" then
    addCall(lines, "IsInJailersTower", nil, IsInJailersTower)
  end
end

---@param lines string[]
local function addCurrentStep(lines)
  local ok, info = pcall(C_ScenarioInfo.GetScenarioStepInfo)
  if not ok then
    local err = "error"
    if type(info) == "string" then
      err = format("error=%s", info)
    end
    lines[#lines + 1] = format("GetScenarioStepInfo %s", err)
  elseif type(info) ~= "table" then
    lines[#lines + 1] = "GetScenarioStepInfo nil"
  else
    addStruct(lines, "GetScenarioStepInfo", info, stepFields)
    if type(info.stepID) == "number" then
      rememberStep(info.stepID)
    end
    local numCriteria = 0
    if type(info.numCriteria) == "number" then
      numCriteria = info.numCriteria
    end
    addCriteria(lines, "GetCriteriaInfo", numCriteria, nil)
  end
  if C_Scenario then
    addCall(lines, "GetStepInfo", stepInfoLabels, C_Scenario.GetStepInfo)
    if type(select(2, pcall(C_Scenario.GetBonusSteps))) == "table" then
      ---@type number[]
      local bonusSteps = select(2, pcall(C_Scenario.GetBonusSteps))
      for index = 1, #bonusSteps do
        local bonusStepIndex = bonusSteps[index]
        local key = format("GetStepInfo(%s)", tostring(bonusStepIndex))
        addCall(lines, key, stepInfoLabels, C_Scenario.GetStepInfo, bonusStepIndex)
        local rewardKey = format("GetBonusStepRewardQuestID(%s)", tostring(bonusStepIndex))
        addCall(lines, rewardKey, nil, C_Scenario.GetBonusStepRewardQuestID, bonusStepIndex)
      end
    end
  end
end

---@param lines string[]
local function addSeenSteps(lines)
  for index = 1, #seenStepList do
    addStepByID(lines, seenStepList[index])
  end
end

---@param lines string[]
---@param tierInfo TieredEntranceTierInfo
local function addTier(lines, key, tierInfo)
  addStruct(lines, key, tierInfo, tierFields)
  local enabledKey = format("IsDelveEntranceTierEnabled(%s)", valueText(tierInfo.tier))
  addCall(lines, enabledKey, { "enabled", "failureReason" }, C_DelvesUI.IsDelveEntranceTierEnabled, tierInfo.tier)
  local rewards = tierInfo.rewards
  if not rewards or #rewards == 0 then
    lines[#lines + 1] = format("%sRewards none", key)
    return
  end
  for index = 1, #rewards do
    local reward = rewards[index]
    local rewardKey = format("%sReward(%d)", key, index)
    lines[#lines + 1] = format(
      "%s id=%s quantity=%s rewardType=%s context=%s",
      rewardKey,
      valueText(reward.id),
      valueText(reward.quantity),
      valueText(reward.rewardType),
      valueText(reward.context)
    )
    local linkKey = format("GetDelvePreviewItemLink(%s,%s)", valueText(reward.id), valueText(reward.context))
    addCall(lines, linkKey, nil, C_Item.GetDelvePreviewItemLink, reward.id, reward.context)
    local qualityKey = format("GetDelvePreviewItemQuality(%s,%s)", valueText(reward.id), valueText(reward.context))
    addCall(lines, qualityKey, nil, C_Item.GetDelvePreviewItemQuality, reward.id, reward.context)
  end
end

---@param lines string[]
local function addDelve(lines)
  addCall(lines, "HasActiveDelve", nil, C_DelvesUI.HasActiveDelve)
  addCall(lines, "GetTieredEntranceType", nil, C_DelvesUI.GetTieredEntranceType)
  addCall(lines, "GetCurrentDelvesSeasonNumber", nil, C_DelvesUI.GetCurrentDelvesSeasonNumber)
  addCall(lines, "GetWorldTierDifficultyForActivePlayer", nil, C_DelvesUI.GetWorldTierDifficultyForActivePlayer)
  addCall(lines, "GetTieredEntrancePDEID", nil, C_DelvesUI.GetTieredEntrancePDEID)
  addCall(lines, "GetDelveEntranceMapID", nil, C_DelvesUI.GetDelveEntranceMapID)
  addCall(lines, "GetDelvesFactionForSeason", nil, C_DelvesUI.GetDelvesFactionForSeason)
  addCall(lines, "GetDelvesMinRequiredLevel", nil, C_DelvesUI.GetDelvesMinRequiredLevel)
  addCall(lines, "HasActiveLair", nil, C_DelvesUI.HasActiveLair)
  addCall(lines, "HasActiveLFGLair", nil, C_DelvesUI.HasActiveLFGLair)
  addCall(lines, "IsInLair", nil, C_DelvesUI.IsInLair)
  addCall(lines, "GetTieredEntranceOptionalAffixTraitTreeID", nil, C_DelvesUI.GetTieredEntranceOptionalAffixTraitTreeID)
  addCall(lines, "GetDelveEntranceTitleString", nil, C_DelvesUI.GetDelveEntranceTitleString)
  addCall(lines, "GetDelveEntranceHeaderString", nil, C_DelvesUI.GetDelveEntranceHeaderString)
  addCall(lines, "GetDelveEntranceDescriptionString", nil, C_DelvesUI.GetDelveEntranceDescriptionString)
  addCall(lines, "GetDelvesAffixSpellsForSeason", nil, C_DelvesUI.GetDelvesAffixSpellsForSeason)
  addCall(lines, "IsEligibleForActiveDelveRewards", nil, C_DelvesUI.IsEligibleForActiveDelveRewards, "player")
  if C_DelvesUI.HasActiveDelve() then
    local tierOK, tierInfo = pcall(C_DelvesUI.GetActiveDelveTier)
    if not tierOK then
      lines[#lines + 1] = format("GetActiveDelveTier error=%s", valueText(tierInfo))
    elseif tierInfo then
      addTier(lines, "GetActiveDelveTier", tierInfo)
    else
      lines[#lines + 1] = "GetActiveDelveTier nil"
    end
  else
    lines[#lines + 1] = "GetActiveDelveTier nil"
  end
  local tiersOK, tiers = pcall(C_DelvesUI.GetDelveEntranceTiers)
  if not tiersOK then
    lines[#lines + 1] = format("GetDelveEntranceTiers error=%s", valueText(tiers))
  elseif not tiers or #tiers == 0 then
    lines[#lines + 1] = "GetDelveEntranceTiers none"
  else
    for index = 1, #tiers do
      addTier(lines, format("GetDelveEntranceTiers(%d)", index), tiers[index])
    end
  end
  addCall(lines, "GetDeathCount", { "numDeaths", "timeLost" }, C_ChallengeMode.GetDeathCount)
end

---@param lines string[]
local function addParty(lines)
  addCall(lines, "IsDelveInProgress", nil, C_PartyInfo.IsDelveInProgress)
  addCall(lines, "IsDelveComplete", nil, C_PartyInfo.IsDelveComplete)
  addCall(lines, "IsPartyInJailersTower", nil, C_PartyInfo.IsPartyInJailersTower)
  addCall(lines, "CanPlayerUseScenarioFinder", { "canUse", "failureReason" }, C_LFGInfo.CanPlayerUseScenarioFinder)
end

---@param lines string[]
---@param scenarioID number|nil
local function addInstance(lines, scenarioID)
  addCall(lines, "GetInstanceInfo", {
    "name",
    "instanceType",
    "difficultyID",
    "difficultyName",
    "maxPlayers",
    "dynamicDifficulty",
    "isDynamic",
    "instanceID",
    "instanceGroupSize",
    "lfgDungeonID",
  }, GetInstanceInfo)
  local mapOK, mapID = pcall(C_Map.GetBestMapForUnit, "player")
  if not mapOK then
    lines[#lines + 1] = format("GetBestMapForUnit error=%s", valueText(mapID))
  else
    local mapName
    if mapID then
      local infoOK, mapInfo = pcall(C_Map.GetMapInfo, mapID)
      if infoOK and mapInfo then
        mapName = mapInfo.name
      end
    end
    lines[#lines + 1] = format("GetBestMapForUnit mapID=%s name=%s zone=%s subzone=%s", valueText(mapID), valueText(mapName), valueText(GetZoneText()), valueText(GetSubZoneText()))
  end
  if scenarioID and C_LFGList and C_LFGList.CanCreateScenarioGroup then
    local key = format("CanCreateScenarioGroup(%s)", valueText(scenarioID))
    addCall(lines, key, nil, C_LFGList.CanCreateScenarioGroup, scenarioID)
  end
end

---@param lines string[]
---@param companionID number|nil
local function addCompanionReads(lines, companionID)
  local key = format("companion(%s)", valueText(companionID))
  local displayID = C_DelvesUI.GetCreatureDisplayInfoForCompanion(companionID)
  local factionID = C_DelvesUI.GetFactionForCompanion(companionID)
  local flavorName = C_DelvesUI.GetFlavorNodeNameForCompanion(companionID)
  local flavorNodeID = C_DelvesUI.GetFlavorNodeForCompanion(companionID)
  local roleNodeID = C_DelvesUI.GetRoleNodeForCompanion(companionID)
  local traitTreeID = C_DelvesUI.GetTraitTreeForCompanion(companionID)
  local combatNodeID = C_DelvesUI.GetCurioNodeForCompanion(Enum.CurioType.Combat, companionID)
  local utilityNodeID = C_DelvesUI.GetCurioNodeForCompanion(Enum.CurioType.Utility, companionID)
  local modelSceneID = C_DelvesUI.GetModelSceneForCompanion(companionID)
  local companionPDEID = C_DelvesUI.GetPlayerCompanionPDEID(companionID)
  local lockedText = C_DelvesUI.GetLockedTextForCompanion(companionID)
  local dpsSubtreeID = C_DelvesUI.GetRoleSubtreeForCompanion(Enum.CompanionRoleType.Dps, companionID)
  local healSubtreeID = C_DelvesUI.GetRoleSubtreeForCompanion(Enum.CompanionRoleType.Heal, companionID)
  local tankSubtreeID = C_DelvesUI.GetRoleSubtreeForCompanion(Enum.CompanionRoleType.Tank, companionID)
  local factionName
  local currentStanding
  local currentReactionThreshold
  local nextReactionThreshold
  if type(factionID) == "number" and factionID > 0 then
    local faction = C_Reputation.GetFactionDataByID(factionID)
    if faction then
      factionName = faction.name
      currentStanding = faction.currentStanding
      currentReactionThreshold = faction.currentReactionThreshold
      nextReactionThreshold = faction.nextReactionThreshold
    end
  end
  lines[#lines + 1] = format(
    "%s creatureDisplayInfoID=%s modelSceneID=%s playerCompanionPDEID=%s factionID=%s factionName=%s currentStanding=%s currentReactionThreshold=%s nextReactionThreshold=%s flavorNodeName=%s flavorNodeID=%s roleNodeID=%s traitTreeID=%s combatCurioNodeID=%s utilityCurioNodeID=%s lockedText=%s dpsSubtreeID=%s healSubtreeID=%s tankSubtreeID=%s",
    key,
    valueText(displayID),
    valueText(modelSceneID),
    valueText(companionPDEID),
    valueText(factionID),
    valueText(factionName),
    valueText(currentStanding),
    valueText(currentReactionThreshold),
    valueText(nextReactionThreshold),
    valueText(flavorName),
    valueText(flavorNodeID),
    valueText(roleNodeID),
    valueText(traitTreeID),
    valueText(combatNodeID),
    valueText(utilityNodeID),
    valueText(lockedText),
    valueText(dpsSubtreeID),
    valueText(healSubtreeID),
    valueText(tankSubtreeID)
  )
end

---@param lines string[]
local function addCompanion(lines)
  addCall(lines, "GetCompanionInfoForActivePlayer", nil, C_DelvesUI.GetCompanionInfoForActivePlayer)
  addCompanionReads(lines, nil)
  local companionID = C_DelvesUI.GetCompanionInfoForActivePlayer()
  if type(companionID) == "number" and companionID > 0 then
    addCompanionReads(lines, companionID)
  end
end

---@param lines string[]
local function addCapture(lines)
  local run = Data:GetActiveRun()
  local runID = "nil"
  local result = "nil"
  local header = "nil"
  local title = "nil"
  local scenarioID = "nil"
  local stepID = "nil"
  if run then
    runID = run.id
    result = run.result
    if run.entrance then
      header = valueText(run.entrance.header)
      title = valueText(run.entrance.title)
    end
    local scenario = run.scenarios[#run.scenarios]
    if scenario then
      scenarioID = valueText(scenario.scenarioID)
    end
    if run.watch and run.watch.stepID then
      stepID = valueText(run.watch.stepID)
    end
  end
  lines[#lines + 1] = format(
    "capture inside=%s run=%s result=%s entranceTitle=%s entranceHeader=%s scenarioID=%s stepID=%s",
    valueText(Capture:IsInside()),
    runID,
    result,
    title,
    header,
    scenarioID,
    stepID
  )
end

---@param prefix string
---@param message string
function Log:Log(prefix, message)
  local logger = addon.logger
  if not logger then
    return
  end
  logger:Log(prefix, message)
end

---@param lines string[]
---@param label string
---@param fn fun(lines: string[])
local function catch(lines, label, fn)
  local ok, err = pcall(fn, lines)
  if not ok then
    lines[#lines + 1] = format("%s error=%s", label, valueText(err))
  end
end

---@return string[]
function Log:CollectState()
  ---@type string[]
  local lines = {}
  catch(lines, "scenario", addScenario)
  catch(lines, "step", addCurrentStep)
  catch(lines, "seen", addSeenSteps)
  catch(lines, "delve", addDelve)
  catch(lines, "party", addParty)
  local scenarioID
  local infoOK, scenarioInfo = pcall(C_ScenarioInfo.GetScenarioInfo)
  if infoOK and scenarioInfo then
    scenarioID = scenarioInfo.scenarioID
  end
  catch(lines, "instance", function(instanceLines)
    addInstance(instanceLines, scenarioID)
  end)
  catch(lines, "companion", addCompanion)
  catch(lines, "capture", addCapture)
  return lines
end

---@param line string
---@return string
local function lineKey(line)
  return line:match("^(%S+)") or line
end

---@param lines string[]
---@param packed string
function Log:EmitState(lines, packed)
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
    local key = lineKey(line)
    local same = false
    for previousIndex = 1, #previous do
      local previousLine = previous[previousIndex]
      if lineKey(previousLine) == key then
        same = previousLine == line
        break
      end
    end
    if not same then
      self:Log("state", line)
    end
  end
  for previousIndex = 1, #previous do
    local key = lineKey(previous[previousIndex])
    local found = false
    for index = 1, #lines do
      if lineKey(lines[index]) == key then
        found = true
        break
      end
    end
    if not found then
      self:Log("state", format("%s cleared", key))
    end
  end
end

function Log:LogState()
  local lines = self:CollectState()
  local packed = table.concat(lines, "\n")
  if packed == self.lastPacked then
    return
  end
  self:EmitState(lines, packed)
end

---@param event string
---@param ... any
function Log:OnEvent(event, ...)
  local count = select("#", ...)
  if count == 0 then
    self:Log("event", event)
  else
    local parts = {}
    for index = 1, count do
      parts[index] = textAt(index, ...)
    end
    self:Log("event", format("%s %s", event, table.concat(parts, " ")))
  end
  self:LogState()
end

---@param stepID number
function Log:ReadStep(stepID)
  rememberStep(stepID)
  ---@type string[]
  local lines = {}
  addStepByID(lines, stepID)
  for index = 1, #lines do
    local line = lines[index]
    self:Log("probe", line)
    if addon.Core then
      addon.Core:Print(line)
    end
  end
end

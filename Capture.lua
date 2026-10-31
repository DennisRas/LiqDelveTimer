---@class LDT_Addon
local addon = select(2, ...)

---@class LDT_Capture
local Capture = {}
addon.Capture = Capture

local Data = addon.Data
local Constants = addon.Constants
local Helpers = addon.Helpers
local ReadPlainString = Helpers.ReadPlainString
local ReadPlainNumber = Helpers.ReadPlainNumber
local ReadPlainBoolean = Helpers.ReadPlainBoolean
local FindBestDuration = Helpers.FindBestDuration
local RoundShown = Helpers.RoundShown
local ParseBoonAmount = Helpers.ParseBoonAmount
local FormatBoonAmount = Helpers.FormatBoonAmount
local IsCurrencyListed = Helpers.IsCurrencyListed
local IsItemHidden = Helpers.IsItemHidden
local LiqUI = addon.libs.LiqUI
local Events = LiqUI.Events
local TableCopy = LiqUI.Utils.TableCopy
local TableGet = LiqUI.Utils.TableGet

local trackerHooked

local function readMonotonicTime()
  return math.floor(GetTime() * 1000 + 0.5)
end

local function readServerTime()
  return math.floor(GetServerTime() * 1000 + 0.5)
end

---@type LDT_CaptureState
local state = {
  loot = {},
}

---@param rewards LDT_Reward[]
---@param rewardType LDT_RewardTypeId
---@param id number|nil
---@param itemLink string|nil
---@return LDT_Reward|nil
local function findReward(rewards, rewardType, id, itemLink)
  for index = 1, #rewards do
    local row = rewards[index]
    if row.type == rewardType then
      if rewardType == Constants.rewardType.Loot then
        if row.itemLink == itemLink then
          return row
        end
      elseif rewardType == Constants.rewardType.Gold or row.id == id then
        return row
      end
    end
  end
end

---@param rewards LDT_Reward[]
---@param rewardType LDT_RewardTypeId
---@param id number|nil
---@param delta number
---@param itemLink string|nil
---@return LDT_Reward
local function addReward(rewards, rewardType, id, delta, itemLink)
  local row = findReward(rewards, rewardType, id, itemLink)
  if row then
    row.amount = row.amount + delta
    return row
  end
  ---@type LDT_Reward
  local created = {
    type = rewardType,
    amount = delta,
  }
  if id then
    created.id = id
  end
  if itemLink then
    created.itemLink = itemLink
  end
  rewards[#rewards + 1] = created
  return created
end

---@param run LDT_Run
---@return LDT_Reward[]
local function listRewards(run)
  local rewards = run.rewards
  if rewards then
    return rewards
  end
  ---@type LDT_Reward[]
  local created = {}
  run.rewards = created
  return created
end

Capture.ready = false
Capture.clockReady = false
Capture.clockOrigin = 0

---@param spellIDs number[]|nil
---@return number[]
local function copySpellIDs(spellIDs)
  local copy = {}
  if not spellIDs then
    return copy
  end
  for index = 1, #spellIDs do
    local spellID = spellIDs[index]
    if spellID and not issecretvalue(spellID) then
      copy[#copy + 1] = spellID
    end
  end
  return copy
end

---@param run LDT_Run
---@param instance LDT_Instance
local function setDelveMode(run, instance)
  local delve = Data:FindDelve(instance)
  if delve then
    run.mode = delve.mode
  end
end

---@param run LDT_Run
---@return number
function Capture:ReadRunElapsed(run)
  if not self.clockReady then
    self:SetRunClock(run)
  end
  local elapsed = readMonotonicTime() - self.clockOrigin
  if elapsed < 0 then
    return 0
  end
  return elapsed
end

---@param run LDT_Run
function Capture:SetRunClock(run)
  if not self.clockReady then
    local already = readServerTime() - run.startedAt
    if already < 0 then
      already = 0
    end
    self.clockOrigin = readMonotonicTime() - already
    self.clockReady = true
  end
end

---@return boolean
function Capture:IsInstanceReported()
  local instance = self:ReadInstance()
  local name = instance.name
  if name and name ~= "" then
    return true
  end
  return false
end

---@return boolean
function Capture:IsInsideDelve()
  local _, _, difficultyID = GetInstanceInfo()
  return difficultyID == Constants.delveDifficultyID
end

---@return boolean
function Capture:IsInsideLabyrinth()
  local _, _, _, _, _, _, _, instanceID = GetInstanceInfo()
  return instanceID == Constants.labyrinthInstanceID
end

---@return boolean
function Capture:IsInsideDelveOrLabyrinth()
  return self:IsInsideDelve() or self:IsInsideLabyrinth()
end

---@return LDT_Character
function Capture:ReadCharacter()
  local name, realm = UnitName("player")
  local _, classFile, classID = UnitClass("player")
  local _, equippedItemLevel = GetAverageItemLevel()
  local specID
  local specName
  local specIndex = GetSpecialization()
  if specIndex then
    specID, specName = GetSpecializationInfo(specIndex)
  end
  ---@type LDT_Character
  local character = {
    guid = UnitGUID("player"),
    name = name,
    realm = realm,
    homeRealm = GetRealmName(),
    classFile = classFile,
    classID = classID,
    level = UnitLevel("player"),
    itemLevel = equippedItemLevel,
    specID = specID,
    specName = specName,
  }
  return character
end

---@param treeID number|nil
---@param nodeID number|nil
---@return string|nil, number|nil
local function findTraitName(treeID, nodeID)
  if not treeID or not nodeID or treeID <= 0 or nodeID <= 0 then
    return nil, nil
  end
  local ok, name, spellID = pcall(function()
    local configID = C_Traits.GetConfigIDByTreeID(treeID)
    if not configID then
      return nil
    end
    local node = C_Traits.GetNodeInfo(configID, nodeID)
    local entryID = node and node.activeEntry and node.activeEntry.entryID
    if not entryID then
      return nil
    end
    local entry = C_Traits.GetEntryInfo(configID, entryID)
    if not entry or not entry.definitionID then
      return nil
    end
    local definition = C_Traits.GetDefinitionInfo(entry.definitionID)
    if not definition then
      return nil
    end
    local resolvedSpellID = definition.overriddenSpellID or definition.spellID
    local nodeName = definition.overrideName
    if (not nodeName or nodeName == "") and resolvedSpellID then
      nodeName = C_Spell.GetSpellName(resolvedSpellID)
    end
    return nodeName, resolvedSpellID
  end)
  if ok then
    ---@type string?
    local nodeName = name
    ---@type number?
    local nodeSpellID = spellID
    return nodeName, nodeSpellID
  end
  return nil, nil
end

---@param treeID number|nil
---@param nodeID number|nil
---@param companionID number|nil
---@return string|nil, string|nil
local function readRole(treeID, nodeID, companionID)
  if not treeID or not nodeID or treeID <= 0 or nodeID <= 0 then
    return nil, nil
  end
  local ok, roleName, roleAtlas = pcall(function()
    local configID = C_Traits.GetConfigIDByTreeID(treeID)
    if not configID then
      return nil, nil
    end
    local node = C_Traits.GetNodeInfo(configID, nodeID)
    local entryID = node and node.activeEntry and node.activeEntry.entryID
    if not entryID then
      return nil, nil
    end
    local entry = C_Traits.GetEntryInfo(configID, entryID)
    local subTreeID = entry and entry.subTreeID
    if not subTreeID or subTreeID <= 0 then
      return nil, nil
    end
    local info = C_Traits.GetSubTreeInfo(configID, subTreeID)
    local resolvedName = info and info.name
    local atlas
    if companionID then
      if subTreeID == C_DelvesUI.GetRoleSubtreeForCompanion(Enum.CompanionRoleType.Dps, companionID) then
        atlas = "ui-lfg-roleicon-dps-micro-raid"
      elseif subTreeID == C_DelvesUI.GetRoleSubtreeForCompanion(Enum.CompanionRoleType.Heal, companionID) then
        atlas = "ui-lfg-roleicon-healer-micro-raid"
      elseif subTreeID == C_DelvesUI.GetRoleSubtreeForCompanion(Enum.CompanionRoleType.Tank, companionID) then
        atlas = "ui-lfg-roleicon-tank-micro-raid"
      end
    end
    return resolvedName, atlas
  end)
  if ok then
    ---@type string?
    local resolvedName = roleName
    ---@type string?
    local resolvedAtlas = roleAtlas
    return resolvedName, resolvedAtlas
  end
  return nil, nil
end

---@return LDT_Entrance
function Capture:ReadEntrance()
  ---@type LDT_Entrance
  local entrance = {
    entranceType = C_DelvesUI.GetTieredEntranceType(),
    title = C_DelvesUI.GetDelveEntranceTitleString(),
    header = C_DelvesUI.GetDelveEntranceHeaderString(),
    description = C_DelvesUI.GetDelveEntranceDescriptionString(),
    mapID = C_DelvesUI.GetDelveEntranceMapID(),
    pdeID = C_DelvesUI.GetTieredEntrancePDEID(),
    seasonNumber = C_DelvesUI.GetCurrentDelvesSeasonNumber(),
    worldTierDifficulty = C_DelvesUI.GetWorldTierDifficultyForActivePlayer(),
    affixSpellIDs = copySpellIDs(C_DelvesUI.GetDelvesAffixSpellsForSeason()),
    activeSpellIDs = copySpellIDs(C_ScenarioInfo.GetTieredEntranceActiveSpells()),
  }
  if C_DelvesUI.HasActiveDelve() then
    local tierInfo = C_DelvesUI.GetActiveDelveTier()
    if tierInfo then
      entrance.tierInfo = TableCopy(tierInfo)
    end
  end
  return entrance
end

---@param value number|nil
---@return number|nil
local function readOptionalID(value)
  if value == nil or issecretvalue(value) or value <= 0 then
    return nil
  end
  return value
end

---@return LDT_Companion
function Capture:ReadCompanion()
  local companionID = readOptionalID(C_DelvesUI.GetCompanionInfoForActivePlayer())
  ---@type LDT_Companion
  local companion = {
    companionID = companionID,
  }
  local factionID = readOptionalID(C_DelvesUI.GetFactionForCompanion(companionID))
  if not factionID then
    factionID = readOptionalID(C_DelvesUI.GetFactionForCompanion(nil))
  end
  companion.factionID = factionID
  if companionID then
    companion.creatureDisplayInfoID = readOptionalID(C_DelvesUI.GetCreatureDisplayInfoForCompanion(companionID))
  end
  local flavorName = C_DelvesUI.GetFlavorNodeNameForCompanion(nil)
  if (not flavorName or issecretvalue(flavorName) or flavorName == "") and companionID then
    flavorName = C_DelvesUI.GetFlavorNodeNameForCompanion(companionID)
  end
  if flavorName and not issecretvalue(flavorName) and flavorName ~= "" then
    companion.flavorName = flavorName
  end
  companion.flavorNodeID = readOptionalID(C_DelvesUI.GetFlavorNodeForCompanion(nil)) or readOptionalID(companionID and C_DelvesUI.GetFlavorNodeForCompanion(companionID))
  companion.traitTreeID = readOptionalID(C_DelvesUI.GetTraitTreeForCompanion(nil)) or readOptionalID(companionID and C_DelvesUI.GetTraitTreeForCompanion(companionID))
  companion.roleNodeID = readOptionalID(C_DelvesUI.GetRoleNodeForCompanion(nil)) or readOptionalID(companionID and C_DelvesUI.GetRoleNodeForCompanion(companionID))
  companion.combatCurioNodeID = readOptionalID(C_DelvesUI.GetCurioNodeForCompanion(Enum.CurioType.Combat, nil))
    or readOptionalID(companionID and C_DelvesUI.GetCurioNodeForCompanion(Enum.CurioType.Combat, companionID))
  companion.utilityCurioNodeID = readOptionalID(C_DelvesUI.GetCurioNodeForCompanion(Enum.CurioType.Utility, nil))
    or readOptionalID(companionID and C_DelvesUI.GetCurioNodeForCompanion(Enum.CurioType.Utility, companionID))
  if factionID then
    local faction = C_Reputation.GetFactionDataByID(factionID)
    if faction and faction.name and not issecretvalue(faction.name) and faction.name ~= "" then
      companion.name = faction.name
      if faction.description and not issecretvalue(faction.description) then
        companion.description = faction.description
      end
    end
    local ranks = C_GossipInfo.GetFriendshipReputationRanks(factionID)
    if ranks then
      companion.level = ranks.currentLevel
      companion.maxLevel = ranks.maxLevel
    end
    local friendship = C_GossipInfo.GetFriendshipReputation(factionID)
    if friendship then
      companion.standing = friendship.standing
      companion.reactionThreshold = friendship.reactionThreshold
      companion.nextThreshold = friendship.nextThreshold
    end
  end
  companion.roleName, companion.roleSpellID = findTraitName(companion.traitTreeID, companion.roleNodeID)
  local subtreeName, roleAtlas = readRole(companion.traitTreeID, companion.roleNodeID, companionID)
  if subtreeName and subtreeName ~= "" then
    companion.roleName = subtreeName
  end
  if roleAtlas then
    companion.roleAtlas = roleAtlas
  end
  local flavorSelectionName, flavorSpellID = findTraitName(companion.traitTreeID, companion.flavorNodeID)
  companion.flavorSpellID = flavorSpellID
  if flavorSelectionName and flavorSelectionName ~= "" then
    companion.flavorName = flavorSelectionName
  end
  companion.combatCurioName, companion.combatCurioSpellID = findTraitName(companion.traitTreeID, companion.combatCurioNodeID)
  companion.utilityCurioName, companion.utilityCurioSpellID = findTraitName(companion.traitTreeID, companion.utilityCurioNodeID)
  return companion
end

---@return LDT_Instance
function Capture:ReadInstance()
  local name, instanceType, difficultyID, difficultyName, maxPlayers, dynamicDifficulty, isDynamic, instanceID, instanceGroupSize, lfgDungeonID = GetInstanceInfo()
  local mapID = C_Map.GetBestMapForUnit("player")
  local mapName
  if mapID then
    local mapInfo = C_Map.GetMapInfo(mapID)
    if mapInfo then
      mapName = mapInfo.name
    end
  end
  ---@type LDT_Instance
  local instance = {
    name = name,
    instanceType = instanceType,
    difficultyID = difficultyID,
    difficultyName = difficultyName,
    maxPlayers = maxPlayers,
    dynamicDifficulty = dynamicDifficulty,
    isDynamic = isDynamic,
    instanceID = instanceID,
    instanceGroupSize = instanceGroupSize,
    lfgDungeonID = lfgDungeonID,
    mapID = mapID,
    mapName = mapName,
    zone = GetZoneText(),
    subzone = GetSubZoneText(),
  }
  return instance
end

---@return LDT_Scenario
function Capture:ReadScenario()
  ---@type LDT_Scenario
  local scenario = {
    criteria = {},
  }
  local info = C_ScenarioInfo.GetScenarioInfo()
  if info then
    scenario.info = TableCopy(info)
  end
  local step = C_ScenarioInfo.GetScenarioStepInfo()
  if step then
    scenario.step = TableCopy(step)
    for index = 1, step.numCriteria do
      local criteriaInfo = C_ScenarioInfo.GetCriteriaInfo(index)
      if criteriaInfo then
        scenario.criteria[index] = TableCopy(criteriaInfo)
      end
    end
  end
  return scenario
end

local LIVES_SPELL_ID = 458103
local LIVES_ICON_FILE = 6013778

---@param text string|nil
---@return number|nil
local function parseFirstCount(text)
  local plain = ReadPlainString(text)
  if not plain then
    return nil
  end
  local digits = plain:match("(%d+)")
  if not digits then
    return nil
  end
  return tonumber(digits)
end

---@param tooltip string|nil
---@return number|nil
local function parseDeathCount(tooltip)
  local plain = ReadPlainString(tooltip)
  if not plain then
    return nil
  end
  local stripped = plain:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|n", " ")
  local last
  for digits in stripped:gmatch("(%d+)") do
    local count = tonumber(digits)
    if count and count ~= LIVES_SPELL_ID then
      last = count
    end
  end
  return last
end

---@param currency UIWidgetCurrencyInfo
---@return boolean
local function isLivesCurrency(currency)
  local iconFileID = currency.iconFileID
  if iconFileID and not issecretvalue(iconFileID) and iconFileID == LIVES_ICON_FILE then
    return true
  end
  local tooltip = ReadPlainString(currency.tooltip)
  if tooltip and tooltip:find("spell:" .. LIVES_SPELL_ID, 1, true) then
    return true
  end
  return false
end

---@param widgetID number
---@return ScenarioHeaderDelvesWidgetVisualizationInfo|nil
local function readHeaderWidget(widgetID)
  local ok, info = pcall(function()
    return C_UIWidgetManager.GetScenarioHeaderDelvesWidgetVisualizationInfo(widgetID)
  end)
  if ok and type(info) == "table" then
    return info
  end
  return nil
end

---@param setID number|nil
---@return ScenarioHeaderDelvesWidgetVisualizationInfo|nil
local function readHeaderSet(setID)
  if not setID or issecretvalue(setID) or setID <= 0 then
    return nil
  end
  local widgets = C_UIWidgetManager.GetAllWidgetsBySetID(setID)
  if not widgets or issecretvalue(widgets) then
    return nil
  end
  local typed
  local fallback
  for index = 1, #widgets do
    local widget = widgets[index]
    local widgetID = widget.widgetID
    if widgetID and not issecretvalue(widgetID) then
      local info = readHeaderWidget(widgetID)
      if info and info.currencies and not issecretvalue(info.currencies) then
        local widgetType = widget.widgetType
        if widgetType and not issecretvalue(widgetType) and widgetType == Enum.UIWidgetVisualizationType.ScenarioHeaderDelves then
          typed = info
          break
        elseif not fallback then
          fallback = info
        end
      end
    end
  end
  return typed or fallback
end

---@param info ScenarioHeaderDelvesWidgetVisualizationInfo|nil
---@return LDT_DelveHeader|nil
local function readHeaderInfo(info)
  if not info then
    return nil
  end
  local tier
  if info.tierText and info.tierText ~= "" and not issecretvalue(info.tierText) then
    local parsed = tonumber(info.tierText)
    if parsed and parsed > 0 then
      tier = parsed
    end
  end
  local lives
  local deaths
  local currencies = info.currencies
  if currencies and not issecretvalue(currencies) then
    local livesCurrency
    for index = 1, #currencies do
      local currency = currencies[index]
      if isLivesCurrency(currency) then
        livesCurrency = currency
        break
      end
    end
    if not livesCurrency and #currencies == 1 then
      livesCurrency = currencies[1]
    end
    if livesCurrency then
      lives = parseFirstCount(livesCurrency.text)
      if lives == nil then
        lives = parseFirstCount(livesCurrency.leadingText)
      end
      deaths = parseDeathCount(livesCurrency.tooltip)
    end
  end
  ---@type number[]
  local spellIDs = {}
  local spells = info.spells
  if spells and not issecretvalue(spells) then
    for index = 1, #spells do
      local spell = spells[index]
      local spellID = spell.spellID
      local shownState = spell.shownState
      local hidden = shownState and not issecretvalue(shownState) and shownState == Enum.WidgetShownState.Hidden
      if spellID and not issecretvalue(spellID) and spellID > 0 and not hidden then
        spellIDs[#spellIDs + 1] = spellID
      end
    end
  end
  ---@type LDT_DelveHeader
  local header = {
    tier = tier,
    lives = lives,
    deaths = deaths,
    spellIDs = spellIDs,
  }
  return header
end

---@return LDT_DelveHeader|nil
function Capture:ReadDelveHeader()
  local step = C_ScenarioInfo.GetScenarioStepInfo()
  local stepSetID
  if step and step.widgetSetID and not issecretvalue(step.widgetSetID) then
    stepSetID = step.widgetSetID
  end
  local header = readHeaderInfo(readHeaderSet(stepSetID))
  local trackerSetID = C_UIWidgetManager.GetObjectiveTrackerWidgetSetID()
  local tracker = readHeaderInfo(readHeaderSet(trackerSetID))
  if header and tracker and header.lives == nil and tracker.lives ~= nil then
    header.lives = tracker.lives
    header.deaths = tracker.deaths
  end
  return header or tracker
end

---@param run LDT_Run
---@return LDT_DelveHeader|nil
function Capture:SetDelveHeader(run)
  local header = self:ReadDelveHeader()
  if not header then
    return nil
  end
  local entrance = run.entrance
  if entrance and header.tier then
    if not entrance.tierInfo then
      local tierInfo = C_DelvesUI.GetActiveDelveTier()
      if tierInfo then
        entrance.tierInfo = TableCopy(tierInfo)
      end
    end
    local tierInfo = entrance.tierInfo
    if tierInfo and (not tierInfo.tier or tierInfo.tier <= 0) then
      tierInfo.tier = header.tier
    end
  end
  if header.lives ~= nil then
    run.lives = header.lives
  end
  if header.deaths ~= nil then
    run.deaths = header.deaths
  end
  if entrance and #header.spellIDs > 0 then
    entrance.activeSpellIDs = header.spellIDs
  end
  return header
end

---@param run LDT_Run
function Capture:RefreshRunSnapshots(run)
  self:SetDelveHeader(run)
  local entrance = run.entrance
  if entrance and not entrance.tierInfo and C_DelvesUI.HasActiveDelve() then
    local tierInfo = C_DelvesUI.GetActiveDelveTier()
    if tierInfo and tierInfo.tier and tierInfo.tier > 0 then
      entrance.tierInfo = TableCopy(tierInfo)
    end
  end
  local companion = run.companion
  if companion and not companion.name then
    local latest = self:ReadCompanion()
    local gainedName = latest.name and latest.name ~= ""
    local gainedId = (not companion.companionID or companion.companionID <= 0) and latest.companionID and latest.companionID > 0
    if gainedName or gainedId then
      run.companion = latest
    end
  end
  local instance = run.instance
  if instance and (not instance.name or instance.name == "") then
    run.instance = self:ReadInstance()
    setDelveMode(run, run.instance)
  end
end

---@param run LDT_Run
---@param instance LDT_Instance
function Capture:SetRunPlace(run, instance)
  if state.zone == instance.zone and state.subzone == instance.subzone then
    return
  end
  state.zone = instance.zone
  state.subzone = instance.subzone
  setDelveMode(run, instance)
end

---@param stored LDT_RunCriteria[]
---@param incoming LDT_CriteriaSnap[]
---@param elapsed number
local function writeCriteria(stored, incoming, elapsed)
  for index = 1, #incoming do
    local info = incoming[index]
    local criteriaID = ReadPlainNumber(info.criteriaID)
    if criteriaID ~= nil then
      local match
      if criteriaID ~= 0 then
        for storedIndex = 1, #stored do
          if stored[storedIndex].criteriaID == criteriaID then
            match = stored[storedIndex]
            break
          end
        end
      elseif stored[index] and stored[index].criteriaID == 0 then
        match = stored[index]
      end
      local quantity = ReadPlainNumber(info.quantity)
      local completed = ReadPlainBoolean(info.completed)
      local failed = ReadPlainBoolean(info.failed)
      if not match then
        ---@type LDT_RunCriteria
        local row = {
          criteriaID = criteriaID,
          quantity = quantity,
          completed = completed == true,
          failed = failed == true,
          enteredElapsed = elapsed,
        }
        if completed == true then
          row.completedElapsed = elapsed
        end
        stored[#stored + 1] = row
      elseif not match.completed then
        if quantity ~= nil then
          match.quantity = quantity
        end
        if completed ~= nil then
          match.completed = completed
        end
        if completed == true and not match.completedElapsed then
          match.completedElapsed = elapsed
        end
        if failed ~= nil then
          match.failed = failed
        end
      end
    end
  end
end

---@param run LDT_Run
---@param scenario LDT_Scenario
---@param elapsed number
local function recordScenario(run, scenario, elapsed)
  local info = scenario.info
  if not info then
    return
  end
  local scenarioID = ReadPlainNumber(info.scenarioID)
  if not scenarioID or scenarioID <= 0 then
    return
  end
  local scenarios = run.scenarios
  local current = scenarios[#scenarios]
  if current and current.scenarioID ~= scenarioID then
    if not current.completedElapsed then
      current.completedElapsed = elapsed
    end
    local previousStep = current.steps[#current.steps]
    if previousStep and not previousStep.completedElapsed then
      previousStep.completedElapsed = elapsed
    end
    current = nil
  end
  if not current then
    local known = TableGet(Data.scenarios, "scenarioID", scenarioID)
    ---@type LDT_RunScenario
    local row = {
      index = #scenarios + 1,
      scenarioID = scenarioID,
      role = known and known.role,
      enteredElapsed = elapsed,
      steps = {},
    }
    scenarios[#scenarios + 1] = row
    current = row
  end
  local complete = ReadPlainBoolean(info.isComplete)
  if complete and not current.completedElapsed then
    current.completedElapsed = elapsed
  end
  local step = scenario.step
  local stepID = step and ReadPlainNumber(step.stepID)
  if not stepID or stepID <= 0 then
    return
  end
  local steps = current.steps
  local runStep = steps[#steps]
  if not runStep or runStep.stepID ~= stepID then
    if runStep and not runStep.completedElapsed then
      runStep.completedElapsed = elapsed
    end
    local stage = ReadPlainNumber(info.currentStage)
    ---@type LDT_RunStep
    local created = {
      stepID = stepID,
      enteredElapsed = elapsed,
      criteria = {},
    }
    if stage and stage > 0 then
      created.stage = stage
    end
    steps[#steps + 1] = created
    runStep = created
  end
  writeCriteria(runStep.criteria, scenario.criteria, elapsed)
  if complete and not runStep.completedElapsed then
    runStep.completedElapsed = elapsed
  end
end

---@param run LDT_Run
---@return number|nil
local function findLatestRunElapsed(run)
  local latest = 0
  for index = 1, #run.scenarios do
    local scenario = run.scenarios[index]
    if scenario.enteredElapsed > latest then
      latest = scenario.enteredElapsed
    end
    if scenario.completedElapsed and scenario.completedElapsed > latest then
      latest = scenario.completedElapsed
    end
    for stepIndex = 1, #scenario.steps do
      local step = scenario.steps[stepIndex]
      if step.enteredElapsed > latest then
        latest = step.enteredElapsed
      end
      if step.completedElapsed and step.completedElapsed > latest then
        latest = step.completedElapsed
      end
      local criteria = step.criteria
      if criteria then
        for criteriaIndex = 1, #criteria do
          local criterion = criteria[criteriaIndex]
          if criterion.enteredElapsed ~= nil and criterion.enteredElapsed > latest then
            latest = criterion.enteredElapsed
          end
          if criterion.completedElapsed ~= nil and criterion.completedElapsed > latest then
            latest = criterion.completedElapsed
          end
        end
      end
    end
  end
  if latest > 0 then
    return latest
  end
  return nil
end

---@param scenarioID number|nil
---@return LDT_ScenarioRoleId|nil
local function findScenarioRole(scenarioID)
  if not scenarioID then
    return nil
  end
  local known = TableGet(Data.scenarios, "scenarioID", scenarioID)
  return known and known.role
end

---@return boolean
function Capture:IsDelveCompleted()
  return C_PartyInfo.IsDelveComplete()
end

---@return boolean
function Capture:IsLabyrinthCompleted()
  if not self:IsInsideLabyrinth() then
    return false
  end
  local info = C_ScenarioInfo.GetScenarioInfo()
  if not info then
    return false
  end
  local scenarioID = ReadPlainNumber(info.scenarioID)
  local role = findScenarioRole(scenarioID)
  if role == Constants.scenarioRole.Reward then
    return true
  end
  if role == Constants.scenarioRole.Boss and ReadPlainBoolean(info.isComplete) then
    return true
  end
  local step = C_ScenarioInfo.GetScenarioStepInfo()
  if not step or not step.numCriteria then
    return false
  end
  local delve = Data:FindDelve(self:ReadInstance())
  local kinduruCriteriaID = delve and delve.kinduruCriteriaID
  if not kinduruCriteriaID then
    return false
  end
  for index = 1, step.numCriteria do
    local criteriaInfo = C_ScenarioInfo.GetCriteriaInfo(index)
    if criteriaInfo then
      local criteriaID = ReadPlainNumber(criteriaInfo.criteriaID)
      local completed = ReadPlainBoolean(criteriaInfo.completed)
      if criteriaID == kinduruCriteriaID and completed then
        return true
      end
    end
  end
  return false
end

---@return boolean
function Capture:IsDelveOrLabyrinthCompleted()
  if self:IsInsideLabyrinth() then
    return self:IsLabyrinthCompleted()
  end
  if self:IsInsideDelve() then
    return self:IsDelveCompleted()
  end
  return false
end

---@param run LDT_Run
---@param scenario LDT_Scenario
function Capture:UpdateScenario(run, scenario)
  recordScenario(run, scenario, self:ReadRunElapsed(run))
  Data:StoreScenario(run, scenario)
  if run.endedAt then
    return
  end
  local entrance = run.entrance
  if entrance then
    local spells = C_ScenarioInfo.GetTieredEntranceActiveSpells()
    if spells then
      entrance.activeSpellIDs = copySpellIDs(spells)
    end
  end
end

---@param run LDT_Run
---@return boolean
function Capture:IsRunEnded(run)
  return run.endedAt ~= nil
end

---@param run LDT_Run
---@param abandoned boolean
function Capture:SetRunEndedAt(run, abandoned)
  if run.endedAt then
    return
  end
  local resumed = not self.clockReady
  self:SetRunClock(run)
  local elapsed = self:ReadRunElapsed(run)
  if resumed then
    local last = findLatestRunElapsed(run)
    if last then
      elapsed = last
    end
  end
  run.endedAt = run.startedAt + elapsed
  if abandoned then
    run.result = Constants.runResult.Abandoned
  else
    local bestTime = FindBestDuration(run)
    if not bestTime or RoundShown(elapsed) < RoundShown(bestTime) then
      run.result = Constants.runResult.PersonalBest
    else
      run.result = Constants.runResult.Completed
    end
  end
  if self.onRunStored then
    self.onRunStored()
  end
end

function Capture:WriteRunClock()
  local run = Data:FindActiveRun()
  if not run or run.endedAt or #run.scenarios == 0 then
    return
  end
  if self:IsDelveOrLabyrinthCompleted() then
    self:SetRunEndedAt(run, false)
    return
  end
  local info = C_ScenarioInfo.GetScenarioInfo()
  if not info then
    return
  end
  local scenarioID = ReadPlainNumber(info.scenarioID)
  local role = findScenarioRole(scenarioID)
  if role == Constants.scenarioRole.Reward then
    self:SetRunEndedAt(run, false)
    return
  end
  if role == Constants.scenarioRole.Stages and ReadPlainBoolean(info.isComplete) then
    self:SetRunEndedAt(run, false)
  end
end

---@param run LDT_Run
function Capture:UpdateCompanion(run)
  local latest = self:ReadCompanion()
  local companion = run.companion
  if not companion then
    if latest.level ~= nil then
      latest.startLevel = latest.level
    end
    if latest.standing ~= nil then
      latest.startStanding = latest.standing
    end
    run.companion = latest
    return
  end
  if latest.name and latest.name ~= "" then
    companion.name = latest.name
  end
  if latest.level ~= nil then
    if companion.startLevel == nil then
      companion.startLevel = latest.level
    elseif companion.level and latest.level > companion.level then
      local delta = latest.level - companion.level
      addReward(listRewards(run), Constants.rewardType.CompanionLevel, nil, delta)
    end
    companion.level = latest.level
  end
  companion.maxLevel = latest.maxLevel or companion.maxLevel
  if latest.standing ~= nil then
    if companion.startStanding == nil then
      companion.startStanding = latest.standing
    elseif companion.standing and latest.standing > companion.standing then
      local delta = latest.standing - companion.standing
      addReward(listRewards(run), Constants.rewardType.CompanionExperience, nil, delta)
    end
    companion.standing = latest.standing
  end
  companion.reactionThreshold = latest.reactionThreshold
  companion.nextThreshold = latest.nextThreshold
  companion.roleName = latest.roleName or companion.roleName
  companion.roleSpellID = latest.roleSpellID or companion.roleSpellID
  companion.flavorSpellID = latest.flavorSpellID or companion.flavorSpellID
  companion.combatCurioName = latest.combatCurioName or companion.combatCurioName
  companion.combatCurioSpellID = latest.combatCurioSpellID or companion.combatCurioSpellID
  companion.utilityCurioName = latest.utilityCurioName or companion.utilityCurioName
  companion.utilityCurioSpellID = latest.utilityCurioSpellID or companion.utilityCurioSpellID
  companion.flavorName = latest.flavorName or companion.flavorName
end

---@param run LDT_Run
function Capture:StoreRunBoons(run)
  if not run.boons then
    return
  end
  local aura = C_UnitAuras.GetPlayerAuraBySpellID(Data.boonSpellID)
  if not aura or issecretvalue(aura) then
    return
  end
  local auraInstanceID = aura.auraInstanceID
  if not auraInstanceID or issecretvalue(auraInstanceID) then
    return
  end
  local tooltip = C_TooltipInfo.GetUnitBuffByAuraInstanceID("player", auraInstanceID)
  local tooltipLines = tooltip and tooltip.lines
  local lines = {}
  if tooltipLines then
    for lineIndex = 2, #tooltipLines do
      local leftText = tooltipLines[lineIndex].leftText
      if leftText and not issecretvalue(leftText) and leftText ~= "" then
        for line in leftText:gmatch("[^\r\n]+") do
          local label, value = line:match("^%s*(.-)%s*:%s*(.-)%s*$")
          if label and label ~= "" and value and value ~= "" then
            local amount, percent = ParseBoonAmount(value)
            if amount then
              ---@type LDT_BoonStat
              local stat = {
                label = label,
                amount = amount,
                percent = percent,
                text = format("%s: %s", label, FormatBoonAmount(amount)),
              }
              lines[#lines + 1] = stat
            end
          end
        end
      end
    end
  end
  if #lines == 0 then
    return
  end
  run.boons = lines
end

---@param run LDT_Run
---@param factionID number|nil
---@param newLevel number|nil
---@param oldLevel number|nil
function Capture:AddRunRenown(run, factionID, newLevel, oldLevel)
  if type(factionID) ~= "number" or type(newLevel) ~= "number" or type(oldLevel) ~= "number" then
    return
  end
  local delta = newLevel - oldLevel
  if delta == 0 then
    return
  end
  addReward(listRewards(run), Constants.rewardType.Renown, factionID, delta)
end

---@param text string
---@param formatString string|nil
---@return number
local function coinAmount(text, formatString)
  if type(formatString) ~= "string" then
    return 0
  end
  local pattern = formatString:gsub("%%d", "(%%d+)")
  return tonumber(text:match(pattern)) or 0
end

---@param text string
---@return number|nil
local function readLootedCopper(text)
  if issecretvalue(text) then
    return nil
  end
  local gold = tonumber(text:match("(%d+)%s*|T[^|]-GoldIcon")) or 0
  local silver = tonumber(text:match("(%d+)%s*|T[^|]-SilverIcon")) or 0
  local copper = tonumber(text:match("(%d+)%s*|T[^|]-CopperIcon")) or 0
  if gold == 0 and silver == 0 and copper == 0 then
    gold = coinAmount(text, GOLD_AMOUNT)
    silver = coinAmount(text, SILVER_AMOUNT)
    copper = coinAmount(text, COPPER_AMOUNT)
  end
  local total = gold * 10000 + silver * 100 + copper
  if total <= 0 then
    return nil
  end
  return total
end

---@param message string|nil
---@param guid WOWGUID|nil
function Capture:RecordRunMoney(message, guid)
  local run = Data:FindActiveRun()
  if not run or not message or issecretvalue(message) then
    return
  end
  local playerGUID = UnitGUID("player")
  if guid and playerGUID and not issecretvalue(guid) and guid ~= playerGUID then
    return
  end
  local copper = readLootedCopper(message)
  if not copper then
    return
  end
  self:SetRunClock(run)
  addReward(listRewards(run), Constants.rewardType.Gold, nil, copper)
end

function Capture:MarkRunSpecChanged()
  local run = Data:FindActiveRun()
  if not run or run.specChanged then
    return
  end
  local character = run.character
  if not character or character.specID == nil then
    return
  end
  local specIndex = GetSpecialization()
  if not specIndex or issecretvalue(specIndex) then
    return
  end
  local specID = GetSpecializationInfo(specIndex)
  if type(specID) ~= "number" or issecretvalue(specID) then
    return
  end
  if specID ~= character.specID then
    run.specChanged = true
  end
end

function Capture:StoreRunCharacter()
  local run = Data:FindActiveRun()
  if not run then
    return
  end
  local level = UnitLevel("player")
  local xp = UnitXP("player")
  local xpMax = UnitXPMax("player")
  if issecretvalue(level) or issecretvalue(xp) or issecretvalue(xpMax) then
    return
  end
  if state.level == nil or state.experience == nil or state.experienceMax == nil then
    state.level = level
    state.experience = xp
    state.experienceMax = xpMax
    return
  end
  self:SetRunClock(run)
  if level > state.level then
    local levels = level - state.level
    addReward(listRewards(run), Constants.rewardType.Level, nil, levels)
    local gained = 0
    if xp < state.experience and state.experienceMax > state.experience then
      gained = (state.experienceMax - state.experience) + xp
    elseif xp > state.experience then
      gained = xp - state.experience
    end
    if gained > 0 then
      addReward(listRewards(run), Constants.rewardType.Experience, nil, gained)
    end
  elseif xp < state.experience and state.experienceMax > state.experience then
    local gained = (state.experienceMax - state.experience) + xp
    if gained > 0 then
      addReward(listRewards(run), Constants.rewardType.Experience, nil, gained)
    end
  elseif xp > state.experience then
    local gained = xp - state.experience
    addReward(listRewards(run), Constants.rewardType.Experience, nil, gained)
  end
  state.level = level
  state.experience = xp
  state.experienceMax = xpMax
end

---@param currencyType number|nil
---@param _quantity number|nil
---@param quantityChange number|nil
function Capture:RecordRunCurrency(currencyType, _quantity, quantityChange)
  local run = Data:FindActiveRun()
  if not run or not currencyType or not quantityChange or quantityChange <= 0 then
    return
  end
  if issecretvalue(currencyType) or issecretvalue(quantityChange) then
    return
  end
  if not IsCurrencyListed(currencyType) then
    return
  end
  self:SetRunClock(run)
  addReward(listRewards(run), Constants.rewardType.Currency, currencyType, quantityChange)
end

---@param message string|nil
---@param guid WOWGUID|nil
function Capture:RecordRunLoot(message, guid)
  local run = Data:FindActiveRun()
  if not run or not message or issecretvalue(message) then
    return
  end
  local playerGUID = UnitGUID("player")
  if guid and playerGUID and not issecretvalue(guid) and guid ~= playerGUID then
    return
  end
  local itemLink = message:match("(|Hitem:.-|h%[.-%]|h)")
  if not itemLink then
    return
  end
  self:SetRunClock(run)
  local itemID = tonumber(itemLink:match("item:(%d+)"))
  if IsItemHidden(itemID) then
    return
  end
  local count = tonumber(message:match("x(%d+)")) or 1
  local elapsed = self:ReadRunElapsed(run)
  local row = findReward(listRewards(run), Constants.rewardType.Loot, nil, itemLink)
  local seen = state.loot[itemLink]
  if row and seen and elapsed - seen < 2000 then
    if count > row.amount then
      row.amount = count
    end
  elseif row then
    row.amount = row.amount + count
  else
    addReward(listRewards(run), Constants.rewardType.Loot, itemID, count, itemLink)
  end
  state.loot[itemLink] = elapsed
end

function Capture:RecordRunDeath()
  local run = Data:FindActiveRun()
  if not run or self:IsRunEnded(run) then
    return
  end
  self:SetRunClock(run)
  run.deaths = (run.deaths or 0) + 1
end

function Capture:CreateActiveRun()
  local run = Data:CreateRun(readServerTime())
  if not run then
    return
  end
  self.clockOrigin = readMonotonicTime()
  self.clockReady = true
  run.character = self:ReadCharacter()
  run.entrance = self:ReadEntrance()
  run.companion = self:ReadCompanion()
  run.instance = self:ReadInstance()
  state.zone = run.instance.zone
  state.subzone = run.instance.subzone
  setDelveMode(run, run.instance)
  local level = UnitLevel("player")
  local xp = UnitXP("player")
  local xpMax = UnitXPMax("player")
  if not issecretvalue(level) and not issecretvalue(xp) and not issecretvalue(xpMax) then
    state.level = level
    state.experience = xp
    state.experienceMax = xpMax
  end
  self:RefreshRunSnapshots(run)
  self:UpdateScenario(run, self:ReadScenario())
  Data:SetRunBest(run)
  self:WriteRunClock()
  if self.onRunStored then
    self.onRunStored()
  end
end

function Capture:ApplyTracker()
  local tracker = _G.ObjectiveTrackerFrame
  if tracker and not trackerHooked then
    trackerHooked = true
    tracker:HookScript("OnShow", function(frame)
      if not Data.db or not Data.db.global.timer.replaceTracker or not Capture:IsInsideDelveOrLabyrinth() then
        return
      end
      frame:Hide()
      Capture.trackerHidden = true
    end)
  end
  if not tracker or not Data.db then
    return
  end
  local hideTracker = Data.db.global.timer.replaceTracker and self:IsInsideDelveOrLabyrinth()
  if hideTracker then
    if tracker:IsShown() then
      tracker:Hide()
    end
    self.trackerHidden = true
    return
  end
  if self.trackerHidden then
    self.trackerHidden = false
    tracker:Show()
  end
end

---@param inside boolean
local function showTimer(inside)
  ---@type "run"|nil
  local context = nil
  if inside then
    context = "run"
  end
  if context == Capture.timerContext then
    return
  end
  Capture.timerContext = context
  local timer = addon.Module_Timer
  if not timer then
    return
  end
  if context then
    timer:ShowRun()
    return
  end
  if Capture.timerFromGame then
    Capture.timerFromGame = false
    timer:HideRun()
  end
end

function Capture:ApplyPlace()
  if not self.ready or not self:IsInstanceReported() then
    return
  end
  local inside = self:IsInsideDelveOrLabyrinth()
  self:ApplyTracker()
  if inside then
    local run = Data:FindActiveRun()
    if not run then
      self:CreateActiveRun()
    else
      self:SetRunClock(run)
      self:SetRunPlace(run, self:ReadInstance())
    end
    showTimer(true)
    return
  end
  local run = Data:FindActiveRun()
  if run then
    self:SetRunEndedAt(run, true)
    Data.db.global.activeRunID = nil
    if self.onRunStored then
      self.onRunStored()
    end
  end
  showTimer(false)
end

local ENTER_CHAMBER_TEXT = "Enter Chamber"
local answeredChoiceID
local choiceHooked

---@param info PlayerChoiceInfo
local function closePlayerChoice(info)
  if not PlayerChoiceFrame or not PlayerChoiceFrame:IsShown() then
    return
  end
  if not issecretvalue(info.keepOpenAfterChoice) and info.keepOpenAfterChoice then
    return
  end
  if InCombatLockdown() then
    PlayerChoiceFrame:Hide()
    return
  end
  HideUIPanel(PlayerChoiceFrame)
end

local function acceptEnterChamber()
  if not Data.db or Data.db.global.timer.autoOpenChambers == false then
    return
  end
  local run = Data:FindActiveRun()
  if not run or run.mode ~= Constants.runMode.Lab then
    return
  end
  local info = C_PlayerChoice.GetCurrentPlayerChoiceInfo()
  if not info or issecretvalue(info.choiceID) then
    return
  end
  if info.choiceID == answeredChoiceID then
    closePlayerChoice(info)
    return
  end
  if issecretvalue(info.options) or #info.options ~= 1 then
    return
  end
  local option = info.options[1]
  if issecretvalue(option.buttons) or #option.buttons ~= 1 then
    return
  end
  local button = option.buttons[1]
  if issecretvalue(button.text) or button.text ~= ENTER_CHAMBER_TEXT or button.disabled or button.confirmation then
    return
  end
  local buttonID = button.id
  if type(buttonID) ~= "number" or issecretvalue(buttonID) then
    return
  end
  if C_PlayerChoice.IsWaitingForPlayerChoiceResponse() then
    closePlayerChoice(info)
    return
  end
  answeredChoiceID = info.choiceID
  C_PlayerChoice.SendPlayerChoiceResponse(buttonID)
  closePlayerChoice(info)
  addon.Core:Print("Chamber opened automatically. You can turn this off in the timer settings.")
end

local function hookPlayerChoiceFrame()
  if choiceHooked or not PlayerChoiceFrame then
    return
  end
  choiceHooked = true
  PlayerChoiceFrame:HookScript("OnShow", function()
    acceptEnterChamber()
  end)
end

function Capture:RegisterCaptureEvents()
  local function onPlayerEnteringWorld()
    Capture.ready = true
    Capture:ApplyPlace()
  end

  local function onPlace()
    if not Capture.ready then
      return
    end
    Capture:ApplyPlace()
  end

  local function onScenario()
    local run = Data:FindActiveRun()
    if not run then
      return
    end
    Capture:SetRunClock(run)
    Capture:UpdateScenario(run, Capture:ReadScenario())
    Capture:WriteRunClock()
  end

  local function onActiveDelveData()
    local run = Data:FindActiveRun()
    if not run or run.endedAt then
      return
    end
    Capture:RefreshRunSnapshots(run)
  end

  ---@param _frame Frame
  ---@param _event string
  ---@param _encounterID number
  ---@param _encounterName string
  ---@param _difficultyID number
  ---@param _groupSize number
  ---@param success number
  local function onEncounterEnd(_frame, _event, _encounterID, _encounterName, _difficultyID, _groupSize, success)
    if success ~= 1 then
      return
    end
    local run = Data:FindActiveRun()
    if not run or run.endedAt or not Capture:IsInsideLabyrinth() then
      return
    end
    local info = C_ScenarioInfo.GetScenarioInfo()
    local scenarioID = info and ReadPlainNumber(info.scenarioID)
    if findScenarioRole(scenarioID) ~= Constants.scenarioRole.Boss then
      return
    end
    Capture:SetRunEndedAt(run, false)
  end

  ---@param _frame Frame
  ---@param _event string
  ---@param text string|nil
  ---@param _playerName string|nil
  ---@param _languageName string|nil
  ---@param _channelName string|nil
  ---@param _playerName2 string|nil
  ---@param _specialFlags string|nil
  ---@param _zoneChannelID number|nil
  ---@param _channelIndex number|nil
  ---@param _channelBaseName string|nil
  ---@param _languageID number|nil
  ---@param _lineID number|nil
  ---@param guid WOWGUID|nil
  local function onChatMsgLoot(_frame, _event, text, _playerName, _languageName, _channelName, _playerName2, _specialFlags, _zoneChannelID, _channelIndex, _channelBaseName, _languageID, _lineID, guid)
    Capture:RecordRunLoot(text, guid)
  end

  ---@param _frame Frame
  ---@param _event string
  ---@param text string|nil
  ---@param _playerName string|nil
  ---@param _languageName string|nil
  ---@param _channelName string|nil
  ---@param _playerName2 string|nil
  ---@param _specialFlags string|nil
  ---@param _zoneChannelID number|nil
  ---@param _channelIndex number|nil
  ---@param _channelBaseName string|nil
  ---@param _languageID number|nil
  ---@param _lineID number|nil
  ---@param guid WOWGUID|nil
  local function onChatMsgMoney(_frame, _event, text, _playerName, _languageName, _channelName, _playerName2, _specialFlags, _zoneChannelID, _channelIndex, _channelBaseName, _languageID, _lineID, guid)
    Capture:RecordRunMoney(text, guid)
  end

  ---@param _frame Frame
  ---@param _event string
  ---@param currencyType number|nil
  ---@param quantity number|nil
  ---@param quantityChange number|nil
  local function onCurrencyDisplayUpdate(_frame, _event, currencyType, quantity, quantityChange)
    Capture:RecordRunCurrency(currencyType, quantity, quantityChange)
  end

  local function onPlayerXp()
    Capture:StoreRunCharacter()
  end

  ---@param _frame Frame
  ---@param _event string
  ---@param oldLevel number|nil
  ---@param newLevel number|nil
  ---@param real boolean|nil
  local function onLevelChanged(_frame, _event, oldLevel, newLevel, real)
    if real == false or type(oldLevel) ~= "number" or type(newLevel) ~= "number" then
      return
    end
    Capture:StoreRunCharacter()
  end

  local function onPlayerDead()
    Capture:RecordRunDeath()
  end

  local function onSpecializationChanged()
    Capture:MarkRunSpecChanged()
  end

  ---@param _frame Frame
  ---@param _event string
  ---@param unit string
  local function onPlayerAura(_frame, _event, unit)
    if unit ~= "player" then
      return
    end
    local run = Data:FindActiveRun()
    if not run or run.endedAt then
      return
    end
    Capture:StoreRunBoons(run)
  end

  local function onUpdateFaction()
    local run = Data:FindActiveRun()
    if not run or run.endedAt then
      return
    end
    Capture:UpdateCompanion(run)
  end

  ---@param _frame Frame
  ---@param _event string
  ---@param factionID number|nil
  ---@param newLevel number|nil
  ---@param oldLevel number|nil
  local function onRenownLevelChanged(_frame, _event, factionID, newLevel, oldLevel)
    local run = Data:FindActiveRun()
    if not run or run.endedAt then
      return
    end
    Capture:UpdateCompanion(run)
    Capture:AddRunRenown(run, factionID, newLevel, oldLevel)
  end

  local function onPlayerChoiceUpdate()
    acceptEnterChamber()
  end

  local function onPlayerChoiceClose()
    answeredChoiceID = nil
  end

  ---@param _frame Frame
  ---@param _event string
  ---@param name string
  local function onAddonLoaded(_frame, _event, name)
    if name == "Blizzard_PlayerChoice" then
      hookPlayerChoiceFrame()
    end
  end

  Events:RegisterEvent("PLAYER_ENTERING_WORLD", onPlayerEnteringWorld, true)
  Events:RegisterEvent({
    "ZONE_CHANGED",
    "ZONE_CHANGED_INDOORS",
    "ZONE_CHANGED_NEW_AREA",
    "UPDATE_INSTANCE_INFO",
  }, onPlace, true)
  Events:RegisterEvent({
    "SCENARIO_UPDATE",
    "SCENARIO_CRITERIA_UPDATE",
    "SCENARIO_CRITERIA_SHOW_STATE_UPDATE",
    "SCENARIO_COMPLETED",
    "SCENARIO_BONUS_OBJECTIVE_COMPLETE",
    "SCENARIO_SPELL_UPDATE",
  }, onScenario, true)
  Events:RegisterEvent("ACTIVE_DELVE_DATA_UPDATE", onActiveDelveData, true)
  Events:RegisterEvent("ENCOUNTER_END", onEncounterEnd, true)
  Events:RegisterEvent("CHAT_MSG_LOOT", onChatMsgLoot, true)
  Events:RegisterEvent("CHAT_MSG_MONEY", onChatMsgMoney, true)
  Events:RegisterEvent("CURRENCY_DISPLAY_UPDATE", onCurrencyDisplayUpdate, true)
  Events:RegisterEvent("PLAYER_XP_UPDATE", onPlayerXp, true)
  Events:RegisterEvent("PLAYER_LEVEL_CHANGED", onLevelChanged, true)
  Events:RegisterEvent("PLAYER_DEAD", onPlayerDead, true)
  Events:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED", onSpecializationChanged, true)
  Events:RegisterEvent("UNIT_AURA", onPlayerAura, true)
  Events:RegisterEvent("UPDATE_FACTION", onUpdateFaction, true)
  Events:RegisterEvent("MAJOR_FACTION_RENOWN_LEVEL_CHANGED", onRenownLevelChanged, true)
  Events:RegisterEvent("PLAYER_CHOICE_UPDATE", onPlayerChoiceUpdate, true)
  Events:RegisterEvent("PLAYER_CHOICE_CLOSE", onPlayerChoiceClose, true)
  Events:RegisterEvent("ADDON_LOADED", onAddonLoaded, true)
  hookPlayerChoiceFrame()
  Capture:ApplyTracker()
end

---@class LDT_Addon
local addon = select(2, ...)

---@class LDT_Capture
local Capture = {}
addon.Capture = Capture

local Data = addon.Data
local Constants = addon.Constants
local Helpers = addon.Helpers
local PlainString = Helpers.PlainString
local PlainNumber = Helpers.PlainNumber
local PlainBoolean = Helpers.PlainBoolean
local GetDuration = Helpers.GetDuration
local RoundShown = Helpers.RoundShown
local ParseBoonAmount = Helpers.ParseBoonAmount
local FormatBoonAmount = Helpers.FormatBoonAmount
local IsCurrencyListed = Helpers.IsCurrencyListed
local IsItemHidden = Helpers.IsItemHidden
local LiqUI = addon.libs.LiqUI
local Events = LiqUI.Events
local TableCopy = LiqUI.Utils.TableCopy
local TableGet = LiqUI.Utils.TableGet
local GetTier = Helpers.GetTier

---@param message string
local function logCapture(message)
  local logger = addon.logger
  if not logger then
    return
  end
  logger:Log("capture", message)
end

local function getTimeMilliseconds()
  return math.floor(GetTime() * 1000 + 0.5)
end

local function getServerTimeMilliseconds()
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
function Capture:GetElapsed(run)
  local elapsed
  if self.clockReady then
    elapsed = getTimeMilliseconds() - self.clockOrigin
  else
    elapsed = getServerTimeMilliseconds() - run.startedAt
  end
  if elapsed < 0 then
    return 0
  end
  return elapsed
end

---@param run LDT_Run
function Capture:SetClockOrigin(run)
  if not self.clockReady then
    local already = getServerTimeMilliseconds() - run.startedAt
    if already < 0 then
      already = 0
    end
    self.clockOrigin = getTimeMilliseconds() - already
    self.clockReady = true
  end
end

---@return boolean
function Capture:IsInstanceReported()
  local instance = self:GetInstance()
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
function Capture:GetCharacter()
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
local function getRole(treeID, nodeID, companionID)
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
function Capture:GetEntrance()
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
local function plainID(value)
  if value == nil or issecretvalue(value) or value <= 0 then
    return nil
  end
  return value
end

---@return LDT_Companion
function Capture:GetCompanion()
  local companionID = plainID(C_DelvesUI.GetCompanionInfoForActivePlayer())
  ---@type LDT_Companion
  local companion = {
    companionID = companionID,
  }
  local factionID = plainID(C_DelvesUI.GetFactionForCompanion(companionID))
  if not factionID then
    factionID = plainID(C_DelvesUI.GetFactionForCompanion(nil))
  end
  companion.factionID = factionID
  if companionID then
    companion.creatureDisplayInfoID = plainID(C_DelvesUI.GetCreatureDisplayInfoForCompanion(companionID))
  end
  local flavorName = C_DelvesUI.GetFlavorNodeNameForCompanion(nil)
  if (not flavorName or issecretvalue(flavorName) or flavorName == "") and companionID then
    flavorName = C_DelvesUI.GetFlavorNodeNameForCompanion(companionID)
  end
  if flavorName and not issecretvalue(flavorName) and flavorName ~= "" then
    companion.flavorName = flavorName
  end
  companion.flavorNodeID = plainID(C_DelvesUI.GetFlavorNodeForCompanion(nil)) or plainID(companionID and C_DelvesUI.GetFlavorNodeForCompanion(companionID))
  companion.traitTreeID = plainID(C_DelvesUI.GetTraitTreeForCompanion(nil)) or plainID(companionID and C_DelvesUI.GetTraitTreeForCompanion(companionID))
  companion.roleNodeID = plainID(C_DelvesUI.GetRoleNodeForCompanion(nil)) or plainID(companionID and C_DelvesUI.GetRoleNodeForCompanion(companionID))
  companion.combatCurioNodeID = plainID(C_DelvesUI.GetCurioNodeForCompanion(Enum.CurioType.Combat, nil))
    or plainID(companionID and C_DelvesUI.GetCurioNodeForCompanion(Enum.CurioType.Combat, companionID))
  companion.utilityCurioNodeID = plainID(C_DelvesUI.GetCurioNodeForCompanion(Enum.CurioType.Utility, nil))
    or plainID(companionID and C_DelvesUI.GetCurioNodeForCompanion(Enum.CurioType.Utility, companionID))
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
  local subtreeName, roleAtlas = getRole(companion.traitTreeID, companion.roleNodeID, companionID)
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
function Capture:GetInstance()
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
function Capture:GetScenario()
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
  local plain = PlainString(text)
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
  local plain = PlainString(tooltip)
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
  local tooltip = PlainString(currency.tooltip)
  if tooltip and tooltip:find("spell:" .. LIVES_SPELL_ID, 1, true) then
    return true
  end
  return false
end

---@param info ScenarioHeaderDelvesWidgetVisualizationInfo|nil
---@return LDT_Lives|nil
local function parseDelveWidget(info)
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
  ---@type LDT_Lives
  local widget = {
    tier = tier,
    lives = lives,
    deaths = deaths,
    spellIDs = spellIDs,
  }
  return widget
end

---@param run LDT_Run
---@param lives number|nil
---@param deaths number|nil
local function setLives(run, lives, deaths)
  local previousLives = run.lives
  local previousDeaths = run.deaths
  if lives ~= nil then
    run.lives = lives
  end
  if deaths ~= nil then
    run.deaths = deaths
  end
  if run.lives ~= previousLives or run.deaths ~= previousDeaths then
    logCapture(format("lives %s deaths %s", run.lives or "none", run.deaths or "none"))
  end
end

---@return LDT_Lives|nil
local function findDelveWidget()
  ---@type number[]
  local setIDs = {}
  local step = C_ScenarioInfo.GetScenarioStepInfo()
  if step and step.widgetSetID and not issecretvalue(step.widgetSetID) and step.widgetSetID > 0 then
    setIDs[#setIDs + 1] = step.widgetSetID
  end
  local trackerSetID = C_UIWidgetManager.GetObjectiveTrackerWidgetSetID()
  if trackerSetID and not issecretvalue(trackerSetID) and trackerSetID > 0 and trackerSetID ~= setIDs[1] then
    setIDs[#setIDs + 1] = trackerSetID
  end
  local found
  for setIndex = 1, #setIDs do
    local widgets = C_UIWidgetManager.GetAllWidgetsBySetID(setIDs[setIndex])
    if widgets and not issecretvalue(widgets) then
      for index = 1, #widgets do
        local listed = widgets[index]
        local widgetType = listed.widgetType
        local widgetID = listed.widgetID
        if widgetID and not issecretvalue(widgetID) and widgetType and not issecretvalue(widgetType) and widgetType == Enum.UIWidgetVisualizationType.ScenarioHeaderDelves then
          local info = C_UIWidgetManager.GetScenarioHeaderDelvesWidgetVisualizationInfo(widgetID)
          if info then
            local shownState = info.shownState
            if not shownState or issecretvalue(shownState) or shownState ~= Enum.WidgetShownState.Hidden then
              local widget = parseDelveWidget(info)
              if widget then
                if not found then
                  found = widget
                elseif found.lives == nil and widget.lives ~= nil then
                  found.lives = widget.lives
                  found.deaths = widget.deaths
                end
              end
            end
          end
        end
      end
    end
  end
  return found
end

---@param run LDT_Run
---@param tier number|nil
local function setTier(run, tier)
  local previous = GetTier(run)
  local entrance = run.entrance
  if entrance and not entrance.tierInfo then
    local tierInfo = C_DelvesUI.GetActiveDelveTier()
    if tierInfo then
      entrance.tierInfo = TableCopy(tierInfo)
    end
  end
  if entrance and tier and tier > 0 and entrance.tierInfo then
    local storedTier = entrance.tierInfo.tier
    if not storedTier or issecretvalue(storedTier) or storedTier <= 0 then
      entrance.tierInfo.tier = tier
    end
  end
  local storedTier = GetTier(run)
  if not previous and storedTier and not run.best then
    Data:SetBest(run)
    if run.best then
      logCapture(format("best %s", run.best.id or "none"))
    end
  end
  if storedTier ~= previous then
    logCapture(format("delve tier %s", storedTier or "none"))
  end
  local companion = run.companion
  if companion and not companion.name then
    local latest = Capture:GetCompanion()
    local gainedName = latest.name and latest.name ~= ""
    local gainedId = (not companion.companionID or companion.companionID <= 0) and latest.companionID and latest.companionID > 0
    if gainedName or gainedId then
      run.companion = latest
    end
  end
  local instance = run.instance
  if instance and (not instance.name or instance.name == "") then
    run.instance = Capture:GetInstance()
    setDelveMode(run, run.instance)
  end
end

---@param stored LDT_RunCriteria[]
---@param incoming LDT_CriteriaSnap[]
---@param elapsed number
local function setCriteria(stored, incoming, elapsed)
  for index = 1, #incoming do
    local info = incoming[index]
    local criteriaID = PlainNumber(info.criteriaID)
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
      local quantity = PlainNumber(info.quantity)
      local completed = PlainBoolean(info.completed)
      local failed = PlainBoolean(info.failed)
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
local function setScenario(run, scenario, elapsed)
  local info = scenario.info
  if not info then
    return
  end
  local scenarioID = PlainNumber(info.scenarioID)
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
  local complete = PlainBoolean(info.isComplete)
  if complete and not current.completedElapsed then
    current.completedElapsed = elapsed
  end
  local step = scenario.step
  local stepID = step and PlainNumber(step.stepID)
  if not stepID or stepID <= 0 then
    return
  end
  local steps = current.steps
  local runStep = steps[#steps]
  if not runStep or runStep.stepID ~= stepID then
    if runStep and not runStep.completedElapsed then
      runStep.completedElapsed = elapsed
    end
    local stage = PlainNumber(info.currentStage)
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
  setCriteria(runStep.criteria, scenario.criteria, elapsed)
  if complete and not runStep.completedElapsed then
    runStep.completedElapsed = elapsed
  end
end

---@param run LDT_Run
---@return number|nil
local function findLatestElapsed(run)
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
  local scenarioID = PlainNumber(info.scenarioID)
  local role = findScenarioRole(scenarioID)
  if role == Constants.scenarioRole.Reward then
    return true
  end
  if role == Constants.scenarioRole.Boss and PlainBoolean(info.isComplete) then
    return true
  end
  local step = C_ScenarioInfo.GetScenarioStepInfo()
  if not step or not step.numCriteria then
    return false
  end
  local delve = Data:FindDelve(self:GetInstance())
  local kinduruCriteriaID = delve and delve.kinduruCriteriaID
  if not kinduruCriteriaID then
    return false
  end
  for index = 1, step.numCriteria do
    local criteriaInfo = C_ScenarioInfo.GetCriteriaInfo(index)
    if criteriaInfo then
      local criteriaID = PlainNumber(criteriaInfo.criteriaID)
      local completed = PlainBoolean(criteriaInfo.completed)
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
function Capture:SetScenario(run, scenario)
  setScenario(run, scenario, self:GetElapsed(run))
  Data:SetScenario(run, scenario)
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
function Capture:IsEnded(run)
  return run.endedAt ~= nil
end

---@param run LDT_Run
---@param abandoned boolean
function Capture:SetEndedAt(run, abandoned)
  if run.endedAt then
    return
  end
  local resumed = not self.clockReady
  self:SetClockOrigin(run)
  local elapsed = self:GetElapsed(run)
  if resumed then
    local last = findLatestElapsed(run)
    if last then
      elapsed = last
    end
  end
  run.endedAt = run.startedAt + elapsed
  if abandoned then
    run.result = Constants.runResult.Abandoned
  else
    local bestTime = GetDuration(run.best)
    if not bestTime or RoundShown(elapsed) < RoundShown(bestTime) then
      run.result = Constants.runResult.PersonalBest
    else
      run.result = Constants.runResult.Completed
    end
  end
  logCapture(format("ended %s result %s", run.id, run.result))
  if self.onRunChanged then
    self.onRunChanged()
  end
end

---@param run LDT_Run
function Capture:SetCompanion(run)
  local latest = self:GetCompanion()
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
      logCapture(format("companion level +%d", delta))
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
      logCapture(format("companion standing +%d", delta))
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
function Capture:SetBoons(run)
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
  local previous = ""
  for index = 1, #run.boons do
    local boon = run.boons[index]
    previous = previous .. (boon.text or "") .. "\n"
  end
  local nextText = ""
  for index = 1, #lines do
    local boon = lines[index]
    nextText = nextText .. (boon.text or "") .. "\n"
  end
  run.boons = lines
  if nextText ~= previous then
    logCapture(format("boons %d", #lines))
  end
end

---@param run LDT_Run
---@param factionID number|nil
---@param newLevel number|nil
---@param oldLevel number|nil
function Capture:AddRenownReward(run, factionID, newLevel, oldLevel)
  if type(factionID) ~= "number" or type(newLevel) ~= "number" or type(oldLevel) ~= "number" then
    return
  end
  local delta = newLevel - oldLevel
  if delta == 0 then
    return
  end
  addReward(listRewards(run), Constants.rewardType.Renown, factionID, delta)
  logCapture(format("renown faction %d %+d", factionID, delta))
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
local function parseLootedCopper(text)
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
function Capture:AddGoldReward(message, guid)
  local run = Data:FindActiveRun()
  if not run or not message or issecretvalue(message) then
    return
  end
  local playerGUID = UnitGUID("player")
  if guid and playerGUID and not issecretvalue(guid) and guid ~= playerGUID then
    return
  end
  local copper = parseLootedCopper(message)
  if not copper then
    return
  end
  addReward(listRewards(run), Constants.rewardType.Gold, nil, copper)
  logCapture(format("gold %d copper", copper))
end

function Capture:SetSpecChanged()
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
    logCapture(format("spec %d", specID))
  end
end

function Capture:AddExperienceReward()
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
  if level ~= state.level or xp ~= state.experience then
    logCapture(format("experience level %d xp %d", level, xp))
  end
  state.level = level
  state.experience = xp
  state.experienceMax = xpMax
end

---@param currencyType number|nil
---@param _quantity number|nil
---@param quantityChange number|nil
function Capture:AddCurrencyReward(currencyType, _quantity, quantityChange)
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
  addReward(listRewards(run), Constants.rewardType.Currency, currencyType, quantityChange)
  logCapture(format("currency %d +%d", currencyType, quantityChange))
end

---@param message string|nil
---@param guid WOWGUID|nil
function Capture:AddLootReward(message, guid)
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
  local itemID = tonumber(itemLink:match("item:(%d+)"))
  if IsItemHidden(itemID) then
    return
  end
  local count = tonumber(message:match("x(%d+)")) or 1
  local elapsed = self:GetElapsed(run)
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
  logCapture(format("loot %s x%d", itemLink, count))
end

function Capture:AddDeath()
  local run = Data:FindActiveRun()
  if not run or self:IsEnded(run) then
    return
  end
  run.deaths = (run.deaths or 0) + 1
  logCapture(format("death %d", run.deaths))
end

function Capture:CreateRun()
  if not Data.db or Data:FindActiveRun() then
    return
  end
  local instance = self:GetInstance()
  local scenario = self:GetScenario()
  local runs = Data.db.global.runs
  local nextRunID = Data.db.global.nextRunID
  Data.db.global.nextRunID = nextRunID + 1
  ---@type LDT_Run
  local run = {
    id = format("run-%d", nextRunID),
    result = Constants.runResult.Active,
    startedAt = getServerTimeMilliseconds(),
    scenarios = {},
    boons = {},
    rewards = {},
  }
  runs[#runs + 1] = run
  Data.db.global.activeRunID = run.id
  run.character = self:GetCharacter()
  run.entrance = self:GetEntrance()
  run.companion = self:GetCompanion()
  run.instance = instance
  setDelveMode(run, instance)
  local level = UnitLevel("player")
  local xp = UnitXP("player")
  local xpMax = UnitXPMax("player")
  if not issecretvalue(level) and not issecretvalue(xp) and not issecretvalue(xpMax) then
    state.level = level
    state.experience = xp
    state.experienceMax = xpMax
  end
  self.clockReady = false
  self:SetClockOrigin(run)
  self:SetScenario(run, scenario)
  local instanceName = instance.name or "none"
  local first = run.scenarios[1]
  logCapture(format("started %s mode %s instance %s tier %s scenario %s", run.id, run.mode or "none", instanceName, GetTier(run) or "none", first and first.scenarioID or "none"))
  Data:SetBest(run)
  if run.best then
    logCapture(format("best %s", run.best.id or "none"))
  end
  if self.onRunChanged then
    self.onRunChanged()
  end
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
  local function onZoneOrInstance()
    if not Capture.ready then
      if Data:FindActiveRun() then
        logCapture("zone waiting, client not ready")
      end
      return
    end
    if not Capture:IsInstanceReported() then
      if Data:FindActiveRun() then
        logCapture("zone waiting, instance has no name")
      end
      return
    end
    if Capture:IsInsideDelveOrLabyrinth() then
      local run = Data:FindActiveRun()
      if not run then
        Capture:CreateRun()
        run = Data:FindActiveRun()
      end
      if run then
        Capture:SetClockOrigin(run)
        local instance = Capture:GetInstance()
        if run.instance then
          run.instance.zone = instance.zone
          run.instance.subzone = instance.subzone
        end
        if not run.endedAt then
          local lives = findDelveWidget()
          if lives then
            setLives(run, lives.lives, lives.deaths)
            setTier(run, lives.tier)
            if run.entrance and #lives.spellIDs > 0 then
              run.entrance.activeSpellIDs = lives.spellIDs
            end
          end
        end
        logCapture(format("inside %s zone %s subzone %s", run.id, instance.zone or "", instance.subzone or ""))
      end
    else
      local run = Data:FindActiveRun()
      if run then
        Capture:SetEndedAt(run, true)
        Data.db.global.activeRunID = nil
        Capture.clockReady = false
        logCapture(format("outside cleared %s", run.id))
        if Capture.onRunChanged then
          Capture.onRunChanged()
        end
      end
    end
    local timer = addon.Module_Timer
    if timer then
      timer:Render()
    end
  end

  ---@param run LDT_Run
  local function logScenario(run)
    local info = C_ScenarioInfo.GetScenarioInfo()
    local scenarioID = info and PlainNumber(info.scenarioID)
    local role = findScenarioRole(scenarioID)
    local complete = info and PlainBoolean(info.isComplete)
    local clock = "running"
    if run.endedAt then
      clock = "stopped"
    end
    logCapture(format("scenario %s role %s complete %s clock %s", scenarioID or "none", role or "none", tostring(complete == true), clock))
  end

  local function onScenario()
    local run = Data:FindActiveRun()
    if not run then
      return
    end
    local first = run.scenarios[1]
    Capture:SetScenario(run, Capture:GetScenario())
    if not first and run.scenarios[1] and not run.best then
      Data:SetBest(run)
      if run.best then
        logCapture(format("best %s", run.best.id or "none"))
      end
    end
    if run.endedAt or #run.scenarios == 0 then
      logScenario(run)
      return
    end
    if Capture:IsDelveOrLabyrinthCompleted() then
      Capture:SetEndedAt(run, false)
      logScenario(run)
      return
    end
    local info = C_ScenarioInfo.GetScenarioInfo()
    if not info then
      logScenario(run)
      return
    end
    local scenarioID = PlainNumber(info.scenarioID)
    local role = findScenarioRole(scenarioID)
    if role == Constants.scenarioRole.Reward then
      Capture:SetEndedAt(run, false)
      logScenario(run)
      return
    end
    if role == Constants.scenarioRole.Stages and PlainBoolean(info.isComplete) then
      Capture:SetEndedAt(run, false)
    end
    logScenario(run)
  end

  local function onActiveDelveData()
    local run = Data:FindActiveRun()
    if not run or run.endedAt then
      return
    end
    setTier(run)
  end

  ---@param _frame Frame
  ---@param _event string
  ---@param widgetInfo UIWidgetInfo
  local function onDelveWidget(_frame, _event, widgetInfo)
    if not widgetInfo or issecretvalue(widgetInfo) then
      return
    end
    local widgetType = widgetInfo.widgetType
    if not widgetType or issecretvalue(widgetType) or widgetType ~= Enum.UIWidgetVisualizationType.ScenarioHeaderDelves then
      return
    end
    local widgetID = widgetInfo.widgetID
    if not widgetID or issecretvalue(widgetID) then
      return
    end
    local run = Data:FindActiveRun()
    if not run or run.endedAt then
      return
    end
    local info = C_UIWidgetManager.GetScenarioHeaderDelvesWidgetVisualizationInfo(widgetID)
    if not info then
      return
    end
    local shownState = info.shownState
    if shownState and not issecretvalue(shownState) and shownState == Enum.WidgetShownState.Hidden then
      return
    end
    local lives = parseDelveWidget(info)
    if not lives then
      return
    end
    setLives(run, lives.lives, lives.deaths)
    setTier(run, lives.tier)
    if run.entrance and #lives.spellIDs > 0 then
      run.entrance.activeSpellIDs = lives.spellIDs
    end
  end

  local function onScenarioWidgets()
    local run = Data:FindActiveRun()
    if not run or run.endedAt then
      return
    end
    local lives = findDelveWidget()
    if not lives then
      return
    end
    setLives(run, lives.lives, lives.deaths)
    setTier(run, lives.tier)
    if run.entrance and #lives.spellIDs > 0 then
      run.entrance.activeSpellIDs = lives.spellIDs
    end
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
    if not run then
      logCapture("encounter kill, no run")
      return
    end
    if run.endedAt then
      logCapture(format("encounter kill, %s clock already stopped", run.id))
      return
    end
    if not Capture:IsInsideLabyrinth() then
      logCapture(format("encounter kill, %s not in the Labyrinth", run.id))
      return
    end
    local info = C_ScenarioInfo.GetScenarioInfo()
    local scenarioID = info and PlainNumber(info.scenarioID)
    local role = findScenarioRole(scenarioID)
    if role ~= Constants.scenarioRole.Boss then
      logCapture(format("encounter kill, %s scenario role %s", run.id, role or "none"))
      return
    end
    Capture:SetEndedAt(run, false)
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
    Capture:AddLootReward(text, guid)
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
    Capture:AddGoldReward(text, guid)
  end

  ---@param _frame Frame
  ---@param _event string
  ---@param currencyType number|nil
  ---@param quantity number|nil
  ---@param quantityChange number|nil
  local function onCurrencyDisplayUpdate(_frame, _event, currencyType, quantity, quantityChange)
    Capture:AddCurrencyReward(currencyType, quantity, quantityChange)
  end

  local function onPlayerXp()
    Capture:AddExperienceReward()
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
    Capture:AddExperienceReward()
  end

  local function onPlayerDead()
    Capture:AddDeath()
  end

  local function onSpecializationChanged()
    Capture:SetSpecChanged()
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
    Capture:SetBoons(run)
  end

  local function onUpdateFaction()
    local run = Data:FindActiveRun()
    if not run or run.endedAt then
      return
    end
    Capture:SetCompanion(run)
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
    Capture:SetCompanion(run)
    Capture:AddRenownReward(run, factionID, newLevel, oldLevel)
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

  Events:RegisterEvent("PLAYER_ENTERING_WORLD", function()
    Capture.ready = true
    onZoneOrInstance()
  end, true)
  Events:RegisterEvent({
    "ZONE_CHANGED",
    "ZONE_CHANGED_INDOORS",
    "ZONE_CHANGED_NEW_AREA",
    "UPDATE_INSTANCE_INFO",
  }, onZoneOrInstance, true)
  Events:RegisterEvent({
    "SCENARIO_UPDATE",
    "SCENARIO_CRITERIA_UPDATE",
    "SCENARIO_CRITERIA_SHOW_STATE_UPDATE",
    "SCENARIO_COMPLETED",
    "SCENARIO_BONUS_OBJECTIVE_COMPLETE",
    "SCENARIO_SPELL_UPDATE",
  }, onScenario, true)
  Events:RegisterEvent("ACTIVE_DELVE_DATA_UPDATE", onActiveDelveData, true)
  Events:RegisterEvent("SCENARIO_UPDATE", onScenarioWidgets, true)
  Events:RegisterEvent("UPDATE_UI_WIDGET", onDelveWidget, true)
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
end

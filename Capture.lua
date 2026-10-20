---@class LDT_Addon
local addon = select(2, ...)

---@class LDT_Capture
local Capture = {}
addon.Capture = Capture

local Data = addon.Data
local Constants = addon.Constants
local Helpers = addon.Helpers
local LiqUI = addon.libs.LiqUI
local Events = LiqUI.Events

Capture.ready = false
Capture.clockReady = false
Capture.reloadNoted = false
Capture.seenWorld = false

---@param spellIDs number[]|nil
---@return number[]
local function CopySpellIDs(spellIDs)
  local copy = {}
  if not spellIDs then
    return copy
  end
  for index = 1, #spellIDs do
    copy[index] = spellIDs[index]
  end
  return copy
end

---@param spellIDs number[]|nil
---@return string
local function SpellList(spellIDs)
  if not spellIDs or #spellIDs == 0 then
    return ""
  end
  local labels = {}
  for index = 1, #spellIDs do
    local spellName = C_Spell.GetSpellName(spellIDs[index])
    labels[index] = spellName or tostring(spellIDs[index])
  end
  return table.concat(labels, ", ")
end

---@param instance LDT_Instance
---@return boolean
local function DetectLabyrinth(instance)
  return instance.mapID == Constants.labyrinthMapID
end

---@param scenario LDT_Scenario
---@return string
local function CriteriaSignature(scenario)
  local parts = {}
  for index = 1, #scenario.criteria do
    local criteriaID = scenario.criteria[index].criteriaID
    if criteriaID then
      parts[index] = tostring(criteriaID)
    else
      parts[index] = ""
    end
  end
  return table.concat(parts, ",")
end

---@param scenario LDT_Scenario
---@return boolean
local function IsStepComplete(scenario)
  local step = scenario.step
  if not step or not step.numCriteria or step.numCriteria <= 0 then
    return false
  end
  if #scenario.criteria < step.numCriteria then
    return false
  end
  for index = 1, step.numCriteria do
    local criteria = scenario.criteria[index]
    if not criteria or not criteria.completed then
      return false
    end
  end
  return true
end

---@param record LDT_Record
---@return number
function Capture:Elapsed(record)
  return record.sessionOffset + (GetTime() - record.sessionStart)
end

---@param record LDT_Record
---@param noteReload boolean|nil
function Capture:EnsureClock(record, noteReload)
  if not self.clockReady then
    record.sessionOffset = GetServerTime() - record.startedAt
    record.sessionStart = GetTime()
    self.clockReady = true
  end
  if noteReload and not self.reloadNoted then
    self.reloadNoted = true
    self:AppendLog(record, Constants.logKind.Reload, "Reloaded")
  end
end

---@param record LDT_Record
---@param kind LDT_LogKindId
---@param text string
---@param detail LDT_LogDetail|nil
---@param elapsed number|nil
function Capture:AppendLog(record, kind, text, detail, elapsed)
  if elapsed == nil then
    elapsed = self:Elapsed(record)
  end
  ---@type LDT_LogEntry
  local entry = {
    at = GetServerTime(),
    elapsed = elapsed,
    kind = kind,
    text = text,
    detail = detail,
  }
  local log = record.log
  log[#log + 1] = entry
  if addon.ApiLog then
    addon.ApiLog:Log("record", format("%s %s", Helpers.FormatElapsed(elapsed), text))
  end
end

---@return boolean
function Capture:IsInside()
  local _, instanceType = GetInstanceInfo()
  if not instanceType or instanceType == "" or instanceType == "none" then
    return false
  end
  if C_PartyInfo.IsDelveInProgress() then
    return true
  end
  if C_ScenarioInfo.IsTieredEntranceScenario() then
    return true
  end
  if C_DelvesUI.HasActiveDelve() then
    return true
  end
  return false
end

---@return LDT_Player
function Capture:ReadPlayer()
  local name, realm = UnitName("player")
  local _, classFile, classID = UnitClass("player")
  local _, equippedItemLevel = GetAverageItemLevel()
  local specID
  local specName
  local specIndex = GetSpecialization()
  if specIndex then
    specID, specName = GetSpecializationInfo(specIndex)
  end
  ---@type LDT_Player
  local player = {
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
  return player
end

---@param treeID number|nil
---@param nodeID number|nil
---@return string|nil
local function TraitNodeName(treeID, nodeID)
  if not treeID or not nodeID or treeID <= 0 or nodeID <= 0 then
    return nil
  end
  local ok, name = pcall(function()
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
    if definition.overrideName and definition.overrideName ~= "" then
      return definition.overrideName
    end
    if definition.spellID then
      return C_Spell.GetSpellName(definition.spellID)
    end
    return nil
  end)
  if ok then
    return name
  end
  return nil
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
    affixSpellIDs = CopySpellIDs(C_DelvesUI.GetDelvesAffixSpellsForSeason()),
    activeSpellIDs = CopySpellIDs(C_ScenarioInfo.GetTieredEntranceActiveSpells()),
  }
  if C_DelvesUI.HasActiveDelve() then
    local tierInfo = C_DelvesUI.GetActiveDelveTier()
    if tierInfo then
      entrance.tierInfo = LiqUI.Utils.TableCopy(tierInfo)
    end
  end
  return entrance
end

---@return LDT_Companion
function Capture:ReadCompanion()
  local companionID = C_DelvesUI.GetCompanionInfoForActivePlayer()
  ---@type LDT_Companion
  local companion = {
    companionID = companionID,
  }
  if not companionID or companionID <= 0 then
    return companion
  end
  companion.creatureDisplayInfoID = C_DelvesUI.GetCreatureDisplayInfoForCompanion(companionID)
  companion.factionID = C_DelvesUI.GetFactionForCompanion(companionID)
  companion.flavorName = C_DelvesUI.GetFlavorNodeNameForCompanion(companionID)
  companion.flavorNodeID = C_DelvesUI.GetFlavorNodeForCompanion(companionID)
  companion.roleNodeID = C_DelvesUI.GetRoleNodeForCompanion(companionID)
  companion.traitTreeID = C_DelvesUI.GetTraitTreeForCompanion(companionID)
  companion.combatCurioNodeID = C_DelvesUI.GetCurioNodeForCompanion(Enum.CurioType.Combat, companionID)
  companion.utilityCurioNodeID = C_DelvesUI.GetCurioNodeForCompanion(Enum.CurioType.Utility, companionID)
  if companion.factionID and companion.factionID > 0 then
    local faction = C_Reputation.GetFactionDataByID(companion.factionID)
    if faction then
      companion.name = faction.name
      companion.description = faction.description
    end
    local ranks = C_GossipInfo.GetFriendshipReputationRanks(companion.factionID)
    if ranks then
      companion.level = ranks.currentLevel
      companion.maxLevel = ranks.maxLevel
    end
    local friendship = C_GossipInfo.GetFriendshipReputation(companion.factionID)
    if friendship then
      companion.standing = friendship.standing
      companion.reactionThreshold = friendship.reactionThreshold
      companion.nextThreshold = friendship.nextThreshold
    end
  end
  companion.roleName = TraitNodeName(companion.traitTreeID, companion.roleNodeID)
  companion.combatCurioName = TraitNodeName(companion.traitTreeID, companion.combatCurioNodeID)
  companion.utilityCurioName = TraitNodeName(companion.traitTreeID, companion.utilityCurioNodeID)
  return companion
end

---@return LDT_Instance
function Capture:ReadInstance()
  local name, instanceType, difficultyID, difficultyName, maxPlayers, dynamicDifficulty, isDynamic, instanceID, instanceGroupSize, lfgDungeonID, hasWorldTier = GetInstanceInfo()
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
    hasWorldTier = hasWorldTier,
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
    scenario.info = LiqUI.Utils.TableCopy(info)
  end
  local step = C_ScenarioInfo.GetScenarioStepInfo()
  if step then
    scenario.step = LiqUI.Utils.TableCopy(step)
    for index = 1, step.numCriteria do
      local criteriaInfo = C_ScenarioInfo.GetCriteriaInfo(index)
      if criteriaInfo then
        scenario.criteria[index] = LiqUI.Utils.TableCopy(criteriaInfo)
      end
    end
  end
  return scenario
end

---@return number|nil, LDT_VaultActivity[]
function Capture:ReadVault()
  local activities = C_WeeklyRewards.GetActivities(Enum.WeeklyRewardChestThresholdType.World)
  ---@type LDT_VaultActivity[]
  local rows = {}
  local progress = nil
  if activities then
    for index = 1, #activities do
      local activity = activities[index]
      ---@type LDT_VaultActivity
      local row = {
        threshold = activity.threshold,
        progress = activity.progress,
        level = activity.level,
        activityTierID = activity.activityTierID,
        id = activity.id,
        index = activity.index,
      }
      rows[index] = row
      if activity.progress ~= nil and (progress == nil or activity.progress > progress) then
        progress = activity.progress
      end
    end
  end
  return progress, rows
end

---@param record LDT_Record
---@param name string
---@return LDT_Chamber
function Capture:EnsureChamber(record, name)
  local chambers = record.chambers
  for index = 1, #chambers do
    local chamber = chambers[index]
    if chamber.name == name then
      return chamber
    end
  end
  ---@type LDT_Chamber
  local chamber = {
    name = name,
    enteredElapsed = self:Elapsed(record),
  }
  chambers[#chambers + 1] = chamber
  return chamber
end

---@param record LDT_Record
function Capture:FillStart(record)
  record.player = self:ReadPlayer()
  record.entrance = self:ReadEntrance()
  record.companion = self:ReadCompanion()
  record.instance = self:ReadInstance()
  record.place = {
    zone = record.instance.zone,
    subzone = record.instance.subzone,
    mapID = record.instance.mapID,
    mapName = record.instance.mapName,
  }
  record.labyrinth = DetectLabyrinth(record.instance)
  local progress, rows = self:ReadVault()
  if progress ~= nil then
    record.vault.startProgress = progress
    record.vault.progress = progress
    record.vault.activities = rows
  end

  local instance = record.instance
  local parts = {}
  if instance.name and instance.name ~= "" then
    parts[#parts + 1] = instance.name
  end
  if instance.difficultyName and instance.difficultyName ~= "" then
    parts[#parts + 1] = instance.difficultyName
  end
  local tier = record.entrance.tierInfo and record.entrance.tierInfo.tier
  if tier and tier > 0 then
    parts[#parts + 1] = format("tier %d", tier)
  end
  local started = "Started"
  if #parts > 0 then
    started = format("Started %s", table.concat(parts, ", "))
  end
  self:AppendLog(record, Constants.logKind.Start, started)

  local companion = record.companion
  if companion.name and companion.name ~= "" then
    local companionText = format("Companion: %s", companion.name)
    if companion.flavorName and companion.flavorName ~= "" then
      companionText = format("%s, %s", companionText, companion.flavorName)
    end
    self:AppendLog(record, Constants.logKind.Start, companionText)
  end

  local activeSpells = SpellList(record.entrance.activeSpellIDs)
  if activeSpells ~= "" then
    self:AppendLog(record, Constants.logKind.Start, format("Active spells: %s", activeSpells))
  end
  local affixSpells = SpellList(record.entrance.affixSpellIDs)
  if affixSpells ~= "" then
    self:AppendLog(record, Constants.logKind.Start, format("Season affixes: %s", affixSpells))
  end
end

---@param record LDT_Record
function Capture:RefreshSnapshots(record)
  local entrance = record.entrance
  if entrance and not entrance.tierInfo and C_DelvesUI.HasActiveDelve() then
    local tierInfo = C_DelvesUI.GetActiveDelveTier()
    if tierInfo and tierInfo.tier and tierInfo.tier > 0 then
      entrance.tierInfo = LiqUI.Utils.TableCopy(tierInfo)
    end
  end
  local companion = record.companion
  if companion and not companion.name then
    local latest = self:ReadCompanion()
    local gainedName = latest.name and latest.name ~= ""
    local gainedId = (not companion.companionID or companion.companionID <= 0) and latest.companionID and latest.companionID > 0
    if gainedName or gainedId then
      record.companion = latest
    end
  end
  local instance = record.instance
  if instance and (not instance.name or instance.name == "") then
    record.instance = self:ReadInstance()
    record.labyrinth = DetectLabyrinth(record.instance)
  end
end

---@param record LDT_Record
---@param instance LDT_Instance
---@return boolean
function Capture:ObservePlace(record, instance)
  local watch = record.watch
  if instance.zone == watch.zone and instance.subzone == watch.subzone then
    return false
  end
  watch.zone = instance.zone
  watch.subzone = instance.subzone
  record.place = {
    zone = instance.zone,
    subzone = instance.subzone,
    mapID = instance.mapID,
    mapName = instance.mapName,
  }
  if DetectLabyrinth(instance) then
    record.labyrinth = true
  end
  local subzone = instance.subzone
  if not subzone or subzone == "" then
    return true
  end
  ---@type LDT_LogDetail
  local detail = {
    zone = instance.zone,
    subzone = subzone,
    mapID = instance.mapID,
  }
  self:AppendLog(record, Constants.logKind.Zone, format("Entered %s", subzone), detail)
  return true
end

---@param record LDT_Record
---@param scenario LDT_Scenario
---@param placeChanged boolean
function Capture:ObserveScenario(record, scenario, placeChanged)
  record.scenario = scenario
  local watch = record.watch
  local step = scenario.step
  local stepID = step and step.stepID
  if stepID ~= watch.stepID then
    watch.stepID = stepID
    local stepTitle = step and step.title
    if stepTitle and stepTitle ~= "" then
      ---@type LDT_LogDetail
      local detail = {
        stepID = stepID,
        stepTitle = stepTitle,
      }
      self:AppendLog(record, Constants.logKind.Step, format("Step: %s", stepTitle), detail)
      if record.labyrinth then
        self:EnsureChamber(record, stepTitle)
      end
    end
  end

  local criteriaWatch = watch.criteria
  local criteriaFinished = false
  for index = 1, #scenario.criteria do
    local criteria = scenario.criteria[index]
    local criteriaID = criteria.criteriaID
    local previous = criteriaWatch[criteriaID]
    if not previous then
      criteriaWatch[criteriaID] = {
        completed = criteria.completed,
        failed = criteria.failed,
      }
      if not criteria.completed and criteria.description and criteria.description ~= "" then
        ---@type LDT_LogDetail
        local detail = {
          criteriaID = criteriaID,
          description = criteria.description,
        }
        self:AppendLog(record, Constants.logKind.Objective, format("Objective: %s", criteria.description), detail)
      end
    else
      if criteria.completed and not previous.completed then
        previous.completed = true
        ---@type LDT_LogDetail
        local detail = {
          criteriaID = criteriaID,
          description = criteria.description,
        }
        local description = criteria.description
        if not description or description == "" then
          description = tostring(criteriaID)
        end
        self:AppendLog(record, Constants.logKind.ObjectiveDone, format("Objective done: %s", description), detail)
        criteriaFinished = true
      elseif not criteria.completed and previous.completed then
        previous.completed = false
      end
      if criteria.failed and not previous.failed then
        previous.failed = true
        local description = criteria.description
        if not description or description == "" then
          description = tostring(criteriaID)
        end
        self:AppendLog(record, Constants.logKind.ObjectiveFailed, format("Objective failed: %s", description), {
          criteriaID = criteriaID,
          description = criteria.description,
        })
      end
    end
  end

  local signature = CriteriaSignature(scenario)
  local signatureChanged = signature ~= (watch.criteriaSignature or "")
  watch.criteriaSignature = signature
  local stepComplete = IsStepComplete(scenario)
  local freshCriteria = signatureChanged and signature ~= ""
  local chamberCleared = false
  if placeChanged then
    chamberCleared = freshCriteria and stepComplete
  else
    chamberCleared = stepComplete and (criteriaFinished or freshCriteria)
  end
  local stepTitle = step and step.title
  if record.labyrinth and chamberCleared and stepTitle and stepTitle ~= "" then
    local chamber = self:EnsureChamber(record, stepTitle)
    if not chamber.completedElapsed then
      chamber.completedElapsed = self:Elapsed(record)
      self:AppendLog(record, Constants.logKind.Chamber, format("Chamber complete: %s", stepTitle), { stepTitle = stepTitle })
    end
  end

  local scenarioComplete = scenario.info and scenario.info.isComplete
  if scenarioComplete and not watch.scenarioComplete then
    watch.scenarioComplete = true
    self:AppendLog(record, Constants.logKind.Scenario, "Scenario complete")
  elseif scenario.info and not scenario.info.isComplete then
    watch.scenarioComplete = false
  end
end

---@param record LDT_Record
function Capture:ObserveVault(record)
  local progress, rows = self:ReadVault()
  if progress == nil then
    return
  end
  local vault = record.vault
  if vault.startProgress == nil then
    vault.startProgress = progress
    vault.progress = progress
    vault.activities = rows
    return
  end
  if vault.progress ~= nil and progress > vault.progress then
    local gain = progress - vault.progress
    vault.progress = progress
    vault.credits = vault.credits + gain
    vault.activities = rows
    self:AppendLog(record, Constants.logKind.Vault, format("Vault credit +%d (%d)", gain, progress), {
      progress = progress,
      gain = gain,
    })
  end
end

---@param record LDT_Record
function Capture:ObserveDelveComplete(record)
  local delveComplete = C_PartyInfo.IsDelveComplete()
  if delveComplete and not record.watch.delveComplete then
    record.watch.delveComplete = true
    record.sawDelveComplete = true
    if not record.finishedElapsed then
      record.finishedElapsed = self:Elapsed(record)
    end
    self:AppendLog(record, Constants.logKind.DelveComplete, "Delve complete")
  end
end

---@param record LDT_Record
function Capture:UpdateCompanion(record)
  local latest = self:ReadCompanion()
  local companion = record.companion
  if not companion then
    if latest.standing ~= nil then
      latest.startStanding = latest.standing
    end
    record.companion = latest
    return
  end
  if latest.name and latest.name ~= "" then
    companion.name = latest.name
  end
  companion.level = latest.level or companion.level
  companion.maxLevel = latest.maxLevel or companion.maxLevel
  companion.standing = latest.standing
  companion.reactionThreshold = latest.reactionThreshold
  companion.nextThreshold = latest.nextThreshold
  if companion.startStanding == nil and latest.standing ~= nil then
    companion.startStanding = latest.standing
  end
  companion.roleName = latest.roleName or companion.roleName
  companion.combatCurioName = latest.combatCurioName or companion.combatCurioName
  companion.utilityCurioName = latest.utilityCurioName or companion.utilityCurioName
  companion.flavorName = latest.flavorName or companion.flavorName
end

---@param record LDT_Record
function Capture:ObserveBoons(record)
  if not record.boons then
    return
  end
  local aura = C_UnitAuras.GetPlayerAuraBySpellID(Constants.boonSpellID)
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
            ---@type LDT_BoonStat
            local stat = { text = format("%s: %s", label, value) }
            lines[#lines + 1] = stat
          end
        end
      end
    end
  end
  if #lines == 0 then
    return
  end
  local previous = record.boons
  local changed = #previous ~= #lines
  if not changed then
    for index = 1, #lines do
      if previous[index].text ~= lines[index].text then
        changed = true
        break
      end
    end
  end
  record.boons = lines
  if changed and #lines > 0 then
    local parts = {}
    for index = 1, #lines do
      parts[index] = lines[index].text
    end
    self:AppendLog(record, Constants.logKind.Boon, table.concat(parts, " | "))
  end
end

---@param record LDT_Record
function Capture:ObserveRenown(record)
  if not record.renownStart or not record.renowns then
    return
  end
  local factionIDs = C_MajorFactions.GetMajorFactionIDs()
  if not factionIDs then
    return
  end
  for index = 1, #factionIDs do
    local factionID = factionIDs[index]
    local data = C_MajorFactions.GetMajorFactionData(factionID)
    if data and data.isUnlocked then
      local key = tostring(factionID)
      local start = record.renownStart[key]
      if not start then
        for rowIndex = 1, #record.renowns do
          local row = record.renowns[rowIndex]
          if row.factionID == factionID then
            ---@type LDT_RenownBaseline
            start = { level = row.startLevel, earned = row.startEarned }
            break
          end
        end
      end
      if not start then
        ---@type LDT_RenownBaseline
        start = { level = data.renownLevel, earned = data.renownReputationEarned }
      end
      record.renownStart[key] = start
      if data.renownLevel ~= start.level or data.renownReputationEarned ~= start.earned then
        local existing
        for rowIndex = 1, #record.renowns do
          if record.renowns[rowIndex].factionID == factionID then
            existing = record.renowns[rowIndex]
            break
          end
        end
        local levelChanged = not existing or existing.level ~= data.renownLevel
        if existing then
          existing.level = data.renownLevel
          existing.earned = data.renownReputationEarned
          existing.threshold = data.renownLevelThreshold
          existing.maxLevel = data.maxLevel
        else
          ---@type LDT_RenownChange
          local row = {
            factionID = factionID,
            name = data.name,
            startLevel = start.level,
            startEarned = start.earned,
            level = data.renownLevel,
            earned = data.renownReputationEarned,
            threshold = data.renownLevelThreshold,
            maxLevel = data.maxLevel,
          }
          record.renowns[#record.renowns + 1] = row
        end
        if levelChanged then
          self:AppendLog(record, Constants.logKind.Renown, format("%s renown %d", data.name, data.renownLevel))
        end
      end
    end
  end
end

function Capture:OnMoney()
  local record = Data:GetActiveRecord()
  if not record or not record.gold then
    return
  end
  self:EnsureClock(record, false)
  local now = GetMoney()
  local delta = now - record.gold.last
  record.gold.last = now
  if delta <= 0 then
    return
  end
  record.gold.gained = record.gold.gained + delta
  ---@type LDT_GoldGain
  local gain = {
    elapsed = self:Elapsed(record),
    copper = delta,
    afterComplete = record.sawDelveComplete,
  }
  record.gold.gains[#record.gold.gains + 1] = gain
  self:AppendLog(record, Constants.logKind.Gold, format("Gold %s", Helpers.FormatMoney(delta)))
end

---@param currencyType number|nil
---@param quantity number|nil
---@param quantityChange number|nil
function Capture:OnCurrency(currencyType, quantity, quantityChange)
  local record = Data:GetActiveRecord()
  if not record or not record.currencies or not currencyType or not quantityChange or quantityChange == 0 then
    return
  end
  if not Helpers.CurrencyListed(currencyType) then
    return
  end
  self:EnsureClock(record, false)
  local info = C_CurrencyInfo.GetCurrencyInfo(currencyType)
  local name
  if info then
    name = info.name
  end
  ---@type LDT_CurrencyChange
  local row = {
    currencyID = currencyType,
    name = name,
    change = quantityChange,
    quantity = quantity,
    elapsed = self:Elapsed(record),
    afterComplete = record.sawDelveComplete,
  }
  record.currencies[#record.currencies + 1] = row
  local amount = tostring(quantityChange)
  if quantityChange > 0 then
    amount = format("+%d", quantityChange)
  end
  local label = name or tostring(currencyType)
  self:AppendLog(record, Constants.logKind.Currency, format("%s %s", amount, label))
end

---@param message string|nil
---@param guid WOWGUID|nil
function Capture:OnLoot(message, guid)
  local record = Data:GetActiveRecord()
  if not record or not record.loot or not message then
    return
  end
  local playerGUID = UnitGUID("player")
  if guid and playerGUID and guid ~= playerGUID then
    return
  end
  local itemLink = message:match("(|Hitem:.-|h%[.-%]|h)")
  if not itemLink then
    return
  end
  if not guid and not message:find("You receive", 1, true) then
    return
  end
  self:EnsureClock(record, false)
  local itemID = tonumber(itemLink:match("item:(%d+)"))
  local quantity = tonumber(message:match("x(%d+)"))
  local elapsed = self:Elapsed(record)
  for index = #record.loot, 1, -1 do
    local previous = record.loot[index]
    local sameItem = (itemID and previous.itemID == itemID) or (not itemID and previous.itemLink == itemLink)
    if sameItem and math.abs((previous.elapsed or 0) - elapsed) < 2 then
      local previousQuantity = previous.quantity or 1
      local nextQuantity = quantity or 1
      if nextQuantity > previousQuantity then
        previous.quantity = nextQuantity
      end
      return
    end
    if previous.elapsed and elapsed - previous.elapsed > 2 then
      break
    end
  end
  ---@type LDT_LootRow
  local row = {
    elapsed = elapsed,
    itemLink = itemLink,
    itemID = itemID,
    quantity = quantity,
    afterComplete = record.sawDelveComplete,
  }
  record.loot[#record.loot + 1] = row
  self:AppendLog(record, Constants.logKind.Loot, itemLink)
end

function Capture:OnDeath()
  local record = Data:GetActiveRecord()
  if not record then
    return
  end
  self:EnsureClock(record, false)
  record.deaths = (record.deaths or 0) + 1
  self:AppendLog(record, Constants.logKind.Death, format("Death %d", record.deaths))
end

---@param record LDT_Record
function Capture:Observe(record)
  self:RefreshSnapshots(record)
  self:UpdateCompanion(record)
  local instance = self:ReadInstance()
  local placeChanged = self:ObservePlace(record, instance)
  self:ObserveScenario(record, self:ReadScenario(), placeChanged)
  self:ObserveVault(record)
  self:ObserveDelveComplete(record)
  self:ObserveBoons(record)
  self:ObserveRenown(record)
  self:OnMoney()
end

function Capture:EnsureRun()
  local character = Data:GetCharacter()
  if not character then
    return
  end
  local active = Data:GetActiveRecord()
  if active then
    self:EnsureClock(active, true)
    self:Observe(active)
    return
  end
  local record = Data:CreateRecord()
  if not record then
    return
  end
  self.clockReady = true
  self.reloadNoted = true
  self:FillStart(record)
  self:Observe(record)
  if addon.Module_Main then
    addon.Module_Main:ShowRun()
  end
end

function Capture:Finish()
  local record = Data:GetActiveRecord()
  if not record then
    return
  end
  local resumed = not self.clockReady
  self:EnsureClock(record, false)
  local ended = self:Elapsed(record)
  if resumed then
    local last = record.log[#record.log]
    if last then
      ended = last.elapsed
    end
  end
  record.endedElapsed = ended
  if record.sawDelveComplete or record.bossElapsed then
    record.result = Constants.runResult.Complete
  else
    record.result = Constants.runResult.Left
  end
  local text = "Left the delve"
  if record.result == Constants.runResult.Complete then
    text = "Run finished"
  end
  self:AppendLog(record, Constants.logKind.End, text, nil, ended)
  local character = Data:GetCharacter()
  if character then
    character.activeRecordID = nil
  end
end

---@param encounterID number
---@param encounterName string
---@param difficultyID number
---@param groupSize number
---@param success number
function Capture:OnEncounterEnd(encounterID, encounterName, difficultyID, groupSize, success)
  local record = Data:GetActiveRecord()
  if not record then
    return
  end
  self:EnsureClock(record, true)
  local elapsed = self:Elapsed(record)
  ---@type LDT_Encounter
  local encounter = {
    encounterID = encounterID,
    encounterName = encounterName,
    difficultyID = difficultyID,
    groupSize = groupSize,
    success = success,
    elapsed = elapsed,
  }
  record.encounters[#record.encounters + 1] = encounter
  if success == 1 then
    record.bossName = encounterName
    record.bossElapsed = elapsed
    self:AppendLog(record, Constants.logKind.Boss, format("Defeated %s", encounterName), {
      encounterID = encounterID,
      encounterName = encounterName,
    })
    return
  end
  self:AppendLog(record, Constants.logKind.Encounter, format("Encounter failed: %s", encounterName), {
    encounterID = encounterID,
    encounterName = encounterName,
  })
end

---@return boolean
function Capture:EntranceOpen()
  if C_DelvesUI.HasActiveDelve() then
    return true
  end
  ---@type Frame|nil
  local picker = _G.DelvesDifficultyPickerFrame
  return picker ~= nil and picker:IsShown()
end

---@return boolean
function Capture:InInstance()
  local _, instanceType = GetInstanceInfo()
  return instanceType ~= nil and instanceType ~= "" and instanceType ~= "none"
end

function Capture:Sync()
  if not self.ready then
    return
  end
  if self:IsInside() then
    self.outsideSince = nil
    self.entranceNoted = false
    self:EnsureRun()
    return
  end
  if self:InInstance() then
    self.outsideSince = nil
    local active = Data:GetActiveRecord()
    if active then
      self:EnsureClock(active, true)
      self:Observe(active)
    end
    return
  end
  local entranceOpen = self:EntranceOpen()
  if entranceOpen and not self.entranceNoted then
    self.entranceNoted = true
    if addon.Module_Main then
      addon.Module_Main:ShowRun()
    end
  elseif not entranceOpen then
    self.entranceNoted = false
  end
  if Data:GetActiveRecord() then
    if not self.outsideSince then
      self.outsideSince = GetTime()
      return
    end
    if GetTime() - self.outsideSince < 5 then
      return
    end
  end
  self.outsideSince = nil
  self:Finish()
end

function Capture:Register()
  Events:RegisterEvent({
    "PLAYER_ENTERING_WORLD",
    "ACTIVE_DELVE_DATA_UPDATE",
    "WALK_IN_DATA_UPDATE",
    "SCENARIO_UPDATE",
    "SCENARIO_CRITERIA_UPDATE",
    "SCENARIO_CRITERIA_SHOW_STATE_UPDATE",
    "SCENARIO_COMPLETED",
    "SCENARIO_BONUS_OBJECTIVE_COMPLETE",
    "SCENARIO_BONUS_VISIBILITY_UPDATE",
    "SCENARIO_SPELL_UPDATE",
    "SCENARIO_POI_UPDATE",
    "ENCOUNTER_START",
    "ENCOUNTER_END",
    "ZONE_CHANGED",
    "ZONE_CHANGED_INDOORS",
    "ZONE_CHANGED_NEW_AREA",
    "WEEKLY_REWARDS_UPDATE",
    "DELVE_ASSIST_ACTION",
    "DELVES_ACCOUNT_DATA_ELEMENT_CHANGED",
    "PARTY_ELIGIBILITY_FOR_DELVE_TIERS_CHANGED",
    "SHOW_DELVES_COMPANION_CONFIGURATION_UI",
    "PLAYER_MONEY",
    "CURRENCY_DISPLAY_UPDATE",
    "CHAT_MSG_LOOT",
    "PLAYER_DEAD",
  }, function(_, event, ...)
    if addon.ApiLog then
      addon.ApiLog:OnEvent(event, ...)
    end
    if event == "ENCOUNTER_END" then
      local encounterID, encounterName, difficultyID, groupSize, success = ...
      Capture:OnEncounterEnd(encounterID, encounterName, difficultyID, groupSize, success)
    elseif event == "PLAYER_MONEY" then
      Capture:OnMoney()
    elseif event == "CURRENCY_DISPLAY_UPDATE" then
      local currencyType, quantity, quantityChange = ...
      Capture:OnCurrency(currencyType, quantity, quantityChange)
    elseif event == "CHAT_MSG_LOOT" then
      local message = ...
      local guid = select(12, ...)
      Capture:OnLoot(message, guid)
    elseif event == "PLAYER_DEAD" then
      Capture:OnDeath()
    end
    if event == "PLAYER_ENTERING_WORLD" and not Capture.seenWorld then
      Capture.seenWorld = true
      C_Timer.After(1, function()
        Capture.ready = true
        Capture:Sync()
        if addon.ApiLog then
          addon.ApiLog:LogState()
        end
      end)
      return
    end
    Capture:Sync()
    if addon.ApiLog then
      addon.ApiLog:LogState()
    end
  end, true)

  C_Timer.NewTicker(0.5, function()
    Capture:Sync()
    if addon.ApiLog then
      addon.ApiLog:OnPoll()
    end
  end)
end

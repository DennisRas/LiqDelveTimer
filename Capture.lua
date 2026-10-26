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
local TableCopy = LiqUI.Utils.TableCopy
local TableForEach = LiqUI.Utils.TableForEach

local pickerHooked
local trackerHooked

local function monotonicMs()
  return math.floor(GetTime() * 1000 + 0.5)
end

local function serverMs()
  return math.floor(GetServerTime() * 1000 + 0.5)
end

local goldLast
local levelSeen
local xpSeen
local xpMaxSeen
---@type table<string, number>
local lootAt = {}

---@param gains LDT_Gain[]
---@param gainType LDT_GainTypeId
---@param id number|nil
---@param itemLink string|nil
---@return LDT_Gain|nil
local function findGain(gains, gainType, id, itemLink)
  for index = 1, #gains do
    local row = gains[index]
    if row.type == gainType then
      if gainType == Constants.gainType.Loot then
        if row.itemLink == itemLink then
          return row
        end
      elseif gainType == Constants.gainType.Gold or row.id == id then
        return row
      end
    end
  end
end

---@param gains LDT_Gain[]
---@param gainType LDT_GainTypeId
---@param id number|nil
---@param delta number
---@param itemLink string|nil
---@return LDT_Gain
local function addGain(gains, gainType, id, delta, itemLink)
  local row = findGain(gains, gainType, id, itemLink)
  if row then
    row.amount = row.amount + delta
    return row
  end
  ---@type LDT_Gain
  local created = {
    type = gainType,
    amount = delta,
  }
  if id then
    created.id = id
  end
  if itemLink then
    created.itemLink = itemLink
  end
  gains[#gains + 1] = created
  return created
end

Capture.ready = false
Capture.clockReady = false
Capture.clockOrigin = 0
Capture.reloadNoted = false
Capture.zoneKnown = false

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

---@param spellIDs number[]|nil
---@return string
local function spellList(spellIDs)
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

---@param run LDT_Run
---@param instance LDT_Instance
local function applyDelve(run, instance)
  local delve = Data:DelveForInstance(instance)
  if delve then
    run.mode = delve.mode
  end
end

---@param scenario LDT_Scenario
---@return string
local function criteriaSignature(scenario)
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
local function isStepComplete(scenario)
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

---@param run LDT_Run
---@return number
function Capture:Elapsed(run)
  if not self.clockReady then
    self:EnsureClock(run, false)
  end
  local elapsed = monotonicMs() - self.clockOrigin
  if elapsed < 0 then
    return 0
  end
  return elapsed
end

---@param run LDT_Run
---@param noteReload boolean|nil
function Capture:EnsureClock(run, noteReload)
  if not self.clockReady then
    local already = serverMs() - run.startedAt
    if already < 0 then
      already = 0
    end
    self.clockOrigin = monotonicMs() - already
    self.clockReady = true
  end
  if noteReload and not self.reloadNoted then
    self.reloadNoted = true
    self:AppendLog(run, Constants.logKind.Reload, "Reloaded")
  end
end

---@param run LDT_Run
---@param kind LDT_LogKindId
---@param text string
---@param detail LDT_LogDetail|nil
---@param elapsed number|nil
function Capture:AppendLog(run, kind, text, detail, elapsed)
  if elapsed == nil then
    elapsed = self:Elapsed(run)
  end
  ---@type LDT_LogEntry
  local entry = {
    at = run.startedAt + elapsed,
    elapsed = elapsed,
    kind = kind,
    text = text,
    detail = detail,
  }
  local log = run.log
  log[#log + 1] = entry
  if addon.Log then
    addon.Log:Log("run", format("%s %s", Helpers.FormatElapsed(elapsed), text))
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
local function traitNodeName(treeID, nodeID)
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
local function optionalID(value)
  if value == nil or issecretvalue(value) or value <= 0 then
    return nil
  end
  return value
end

---@return LDT_Companion
function Capture:ReadCompanion()
  local companionID = optionalID(C_DelvesUI.GetCompanionInfoForActivePlayer())
  ---@type LDT_Companion
  local companion = {
    companionID = companionID,
  }
  local factionID = optionalID(C_DelvesUI.GetFactionForCompanion(companionID))
  if not factionID then
    factionID = optionalID(C_DelvesUI.GetFactionForCompanion(nil))
  end
  companion.factionID = factionID
  if companionID then
    companion.creatureDisplayInfoID = optionalID(C_DelvesUI.GetCreatureDisplayInfoForCompanion(companionID))
  end
  local flavorName = C_DelvesUI.GetFlavorNodeNameForCompanion(nil)
  if (not flavorName or issecretvalue(flavorName) or flavorName == "") and companionID then
    flavorName = C_DelvesUI.GetFlavorNodeNameForCompanion(companionID)
  end
  if flavorName and not issecretvalue(flavorName) and flavorName ~= "" then
    companion.flavorName = flavorName
  end
  companion.flavorNodeID = optionalID(C_DelvesUI.GetFlavorNodeForCompanion(nil)) or optionalID(companionID and C_DelvesUI.GetFlavorNodeForCompanion(companionID))
  companion.traitTreeID = optionalID(C_DelvesUI.GetTraitTreeForCompanion(nil)) or optionalID(companionID and C_DelvesUI.GetTraitTreeForCompanion(companionID))
  companion.roleNodeID = optionalID(C_DelvesUI.GetRoleNodeForCompanion(nil)) or optionalID(companionID and C_DelvesUI.GetRoleNodeForCompanion(companionID))
  companion.combatCurioNodeID = optionalID(C_DelvesUI.GetCurioNodeForCompanion(Enum.CurioType.Combat, nil))
    or optionalID(companionID and C_DelvesUI.GetCurioNodeForCompanion(Enum.CurioType.Combat, companionID))
  companion.utilityCurioNodeID = optionalID(C_DelvesUI.GetCurioNodeForCompanion(Enum.CurioType.Utility, nil))
    or optionalID(companionID and C_DelvesUI.GetCurioNodeForCompanion(Enum.CurioType.Utility, companionID))
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
  companion.roleName, companion.roleSpellID = traitNodeName(companion.traitTreeID, companion.roleNodeID)
  local subtreeName, roleAtlas = readRole(companion.traitTreeID, companion.roleNodeID, companionID)
  if subtreeName and subtreeName ~= "" then
    companion.roleName = subtreeName
  end
  if roleAtlas then
    companion.roleAtlas = roleAtlas
  end
  local flavorSelectionName, flavorSpellID = traitNodeName(companion.traitTreeID, companion.flavorNodeID)
  companion.flavorSpellID = flavorSpellID
  if flavorSelectionName and flavorSelectionName ~= "" then
    companion.flavorName = flavorSelectionName
  end
  companion.combatCurioName, companion.combatCurioSpellID = traitNodeName(companion.traitTreeID, companion.combatCurioNodeID)
  companion.utilityCurioName, companion.utilityCurioSpellID = traitNodeName(companion.traitTreeID, companion.utilityCurioNodeID)
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
---@return string|nil
local function plainText(text)
  if not text or text == "" or issecretvalue(text) then
    return nil
  end
  return text
end

---@param text string|nil
---@return number|nil
local function firstCount(text)
  local plain = plainText(text)
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
local function deathCount(tooltip)
  local plain = plainText(tooltip)
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
local function currencyIsLives(currency)
  local iconFileID = currency.iconFileID
  if iconFileID and not issecretvalue(iconFileID) and iconFileID == LIVES_ICON_FILE then
    return true
  end
  local tooltip = plainText(currency.tooltip)
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
local function headerFromSet(setID)
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
local function headerFromInfo(info)
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
      if currencyIsLives(currency) then
        livesCurrency = currency
        break
      end
    end
    if not livesCurrency and #currencies == 1 then
      livesCurrency = currencies[1]
    end
    if livesCurrency then
      lives = firstCount(livesCurrency.text)
      if lives == nil then
        lives = firstCount(livesCurrency.leadingText)
      end
      deaths = deathCount(livesCurrency.tooltip)
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
  local header = headerFromInfo(headerFromSet(stepSetID))
  local trackerSetID = C_UIWidgetManager.GetObjectiveTrackerWidgetSetID()
  local tracker = headerFromInfo(headerFromSet(trackerSetID))
  if header and tracker and header.lives == nil and tracker.lives ~= nil then
    header.lives = tracker.lives
    header.deaths = tracker.deaths
  end
  return header or tracker
end

---@param run LDT_Run
---@return LDT_DelveHeader|nil
function Capture:ApplyDelveHeader(run)
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
  Data:SnapshotBest(run)
  if entrance and #header.spellIDs > 0 then
    entrance.activeSpellIDs = header.spellIDs
  end
  return header
end

---@param run LDT_Run
---@param name string
---@param stepID number|nil
---@return LDT_Chamber
function Capture:EnsureChamber(run, name, stepID)
  local chambers = run.chambers
  for index = 1, #chambers do
    local chamber = chambers[index]
    if stepID and chamber.stepID == stepID then
      return chamber
    end
    if not stepID and chamber.name == name then
      return chamber
    end
  end
  ---@type LDT_Chamber
  local chamber = {
    name = name,
    stepID = stepID,
    enteredElapsed = self:Elapsed(run),
  }
  chambers[#chambers + 1] = chamber
  return chamber
end

---@param run LDT_Run
function Capture:FillStart(run)
  run.character = self:ReadCharacter()
  run.entrance = self:ReadEntrance()
  run.companion = self:ReadCompanion()
  run.instance = self:ReadInstance()
  run.place = {
    zone = run.instance.zone,
    subzone = run.instance.subzone,
    mapID = run.instance.mapID,
    mapName = run.instance.mapName,
  }
  applyDelve(run, run.instance)
  local money = GetMoney()
  if not issecretvalue(money) then
    goldLast = money
  end
  local level = UnitLevel("player")
  local xp = UnitXP("player")
  local xpMax = UnitXPMax("player")
  if not issecretvalue(level) and not issecretvalue(xp) and not issecretvalue(xpMax) then
    levelSeen = level
    xpSeen = xp
    xpMaxSeen = xpMax
  end

  local instance = run.instance
  local parts = {}
  if instance.name and instance.name ~= "" then
    parts[#parts + 1] = instance.name
  end
  if instance.difficultyName and instance.difficultyName ~= "" then
    parts[#parts + 1] = instance.difficultyName
  end
  local tier = run.entrance.tierInfo and run.entrance.tierInfo.tier
  if tier and tier > 0 then
    parts[#parts + 1] = format("tier %d", tier)
  end
  local started = "Started"
  if #parts > 0 then
    started = format("Started %s", table.concat(parts, ", "))
  end
  self:AppendLog(run, Constants.logKind.Start, started)

  local companion = run.companion
  if companion.name and companion.name ~= "" then
    local companionText = format("Companion: %s", companion.name)
    if companion.flavorName and companion.flavorName ~= "" then
      companionText = format("%s, %s", companionText, companion.flavorName)
    end
    self:AppendLog(run, Constants.logKind.Start, companionText)
  end

  local activeSpells = spellList(run.entrance.activeSpellIDs)
  if activeSpells ~= "" then
    self:AppendLog(run, Constants.logKind.Start, format("Active spells: %s", activeSpells))
  end
  local affixSpells = spellList(run.entrance.affixSpellIDs)
  if affixSpells ~= "" then
    self:AppendLog(run, Constants.logKind.Start, format("Season affixes: %s", affixSpells))
  end
end

---@param run LDT_Run
function Capture:RefreshSnapshots(run)
  self:ApplyDelveHeader(run)
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
    applyDelve(run, run.instance)
  end
end

---@param run LDT_Run
---@param instance LDT_Instance
---@return boolean
function Capture:ObservePlace(run, instance)
  local watch = run.watch
  if instance.zone == watch.zone and instance.subzone == watch.subzone then
    return false
  end
  watch.zone = instance.zone
  watch.subzone = instance.subzone
  run.place = {
    zone = instance.zone,
    subzone = instance.subzone,
    mapID = instance.mapID,
    mapName = instance.mapName,
  }
  applyDelve(run, instance)
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
  self:AppendLog(run, Constants.logKind.Zone, format("Entered %s", subzone), detail)
  return true
end

---@param run LDT_Run
---@param scenario LDT_Scenario
---@param placeChanged boolean
function Capture:ObserveScenario(run, scenario, placeChanged)
  if run.endedAt then
    return
  end
  run.scenario = scenario
  local entrance = run.entrance
  if entrance then
    local spells = C_ScenarioInfo.GetTieredEntranceActiveSpells()
    if spells then
      entrance.activeSpellIDs = copySpellIDs(spells)
    end
  end
  local watch = run.watch
  local step = scenario.step
  local stepID = step and step.stepID
  if stepID ~= watch.stepID then
    if watch.stepID then
      local current = {}
      for index = 1, #scenario.criteria do
        local criteriaID = scenario.criteria[index].criteriaID
        if criteriaID and not issecretvalue(criteriaID) then
          current[criteriaID] = true
        end
      end
      TableForEach(watch.criteria, function(state, criteriaID)
        if current[criteriaID] or state.completed then
          return
        end
        state.completed = true
        local description
        for logIndex = #run.log, 1, -1 do
          local entry = run.log[logIndex]
          local detail = entry.detail
          if detail and detail.criteriaID == criteriaID and detail.description and detail.description ~= "" then
            description = detail.description
            break
          end
        end
        if not description then
          description = tostring(criteriaID)
        end
        ---@type LDT_LogDetail
        local detail = {
          criteriaID = criteriaID,
          description = description,
        }
        self:AppendLog(run, Constants.logKind.ObjectiveDone, format("Objective done: %s", description), detail)
      end)
      local runSteps = run.steps
      if runSteps then
        for stepIndex = 1, #runSteps do
          local runStep = runSteps[stepIndex]
          if runStep.stepID == watch.stepID then
            for criteriaIndex = 1, #runStep.criteria do
              local row = runStep.criteria[criteriaIndex]
              if not current[row.criteriaID] then
                row.completed = true
              end
            end
            break
          end
        end
      end
      Data:FinishStep(run, watch.stepID, self:Elapsed(run))
    end
    watch.stepID = stepID
    local stepTitle = step and step.title
    if stepID then
      ---@type LDT_LogDetail
      local detail = {
        stepID = stepID,
        stepTitle = stepTitle,
      }
      local label = stepTitle
      local stage = scenario.info and scenario.info.currentStage
      if (not label or label == "") and type(stage) == "number" and not issecretvalue(stage) then
        label = format("Stage %d", stage)
      end
      if label and label ~= "" then
        self:AppendLog(run, Constants.logKind.Step, format("Step: %s", label), detail)
      end
      if run.mode == Constants.runMode.Lab and stepTitle and stepTitle ~= "" then
        self:EnsureChamber(run, stepTitle, stepID)
        run.watch.routeStep = stepTitle
      end
    end
  end

  Data:NoteScenario(run, scenario, self:Elapsed(run))

  local criteriaWatch = watch.criteria
  local criteriaFinished = false
  for index = 1, #scenario.criteria do
    local criteria = scenario.criteria[index]
    local criteriaID = criteria.criteriaID
    local completed = criteria.completed
    local failed = criteria.failed
    local description = criteria.description
    if not criteriaID or issecretvalue(criteriaID) or issecretvalue(completed) or issecretvalue(failed) then
      criteriaID = nil
    end
    if description and issecretvalue(description) then
      description = nil
    end
    local previous = criteriaID and criteriaWatch[criteriaID]
    if criteriaID and not previous then
      criteriaWatch[criteriaID] = {
        completed = completed,
        failed = failed,
      }
      if description and description ~= "" then
        ---@type LDT_LogDetail
        local detail = {
          criteriaID = criteriaID,
          description = description,
        }
        self:AppendLog(run, Constants.logKind.Objective, format("Objective: %s", description), detail)
        if completed then
          self:AppendLog(run, Constants.logKind.ObjectiveDone, format("Objective done: %s", description), detail)
        end
      end
    elseif previous then
      if completed and not previous.completed then
        previous.completed = true
        if not description or description == "" then
          description = tostring(criteriaID)
        end
        ---@type LDT_LogDetail
        local detail = {
          criteriaID = criteriaID,
          description = description,
        }
        self:AppendLog(run, Constants.logKind.ObjectiveDone, format("Objective done: %s", description), detail)
        criteriaFinished = true
      elseif not completed and previous.completed then
        previous.completed = false
      end
      if failed and not previous.failed then
        previous.failed = true
        if not description or description == "" then
          description = tostring(criteriaID)
        end
        ---@type LDT_LogDetail
        local detail = {
          criteriaID = criteriaID,
          description = description,
        }
        self:AppendLog(run, Constants.logKind.ObjectiveFailed, format("Objective failed: %s", description), detail)
      end
    end
  end

  local signature = criteriaSignature(scenario)
  local signatureChanged = signature ~= (watch.criteriaSignature or "")
  watch.criteriaSignature = signature
  local stepComplete = isStepComplete(scenario)
  local freshCriteria = signatureChanged and signature ~= ""
  local chamberCleared = false
  if placeChanged then
    chamberCleared = freshCriteria and stepComplete
  else
    chamberCleared = stepComplete and (criteriaFinished or freshCriteria)
  end
  local stepTitle = step and step.title
  if run.mode == Constants.runMode.Lab and chamberCleared and stepTitle and stepTitle ~= "" then
    local chamber = self:EnsureChamber(run, stepTitle, step and step.stepID)
    if not chamber.completedElapsed then
      chamber.completedElapsed = self:Elapsed(run)
      self:AppendLog(run, Constants.logKind.Chamber, format("Chamber complete: %s", stepTitle), { stepTitle = stepTitle })
    end
  end

  local scenarioComplete = scenario.info and scenario.info.isComplete
  if scenarioComplete and not watch.scenarioComplete then
    watch.scenarioComplete = true
    self:AppendLog(run, Constants.logKind.Scenario, "Scenario complete")
  elseif scenario.info and not scenario.info.isComplete then
    watch.scenarioComplete = false
  end
end

---@param run LDT_Run
---@return boolean
function Capture:Ended(run)
  return run.endedAt ~= nil
end

---@param run LDT_Run
---@param elapsed number
---@param abandoned boolean
function Capture:Stop(run, elapsed, abandoned)
  if run.endedAt then
    return
  end
  Data:SnapshotBest(run)
  run.endedAt = run.startedAt + elapsed
  if abandoned then
    run.result = Constants.runResult.Abandoned
  else
    local bestTime = Helpers.BestDuration(run)
    if not bestTime or Helpers.Shown(elapsed) < Helpers.Shown(bestTime) then
      run.result = Constants.runResult.PersonalBest
    else
      run.result = Constants.runResult.Completed
    end
  end
  if self.onRunStored then
    self.onRunStored()
  end
end

---@param run LDT_Run
function Capture:MarkRunFinished(run)
  if run.endedAt then
    return
  end
  local elapsed = self:Elapsed(run)
  local stepID = run.watch.stepID
  if stepID then
    Data:FinishStep(run, stepID, elapsed)
  end
  self:AppendLog(run, Constants.logKind.DelveComplete, "Delve complete", nil, elapsed)
  self:Stop(run, elapsed, false)
end

---@param run LDT_Run
function Capture:ObserveDelveComplete(run)
  if C_PartyInfo.IsDelveComplete() then
    self:MarkRunFinished(run)
  end
end

function Capture:OnScenarioCompleted()
  local run = Data:GetActiveRun()
  if not run then
    return
  end
  self:EnsureClock(run, false)
  self:MarkRunFinished(run)
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
      addGain(run.gains, Constants.gainType.CompanionLevel, nil, delta)
      self:AppendLog(run, Constants.logKind.CompanionLevel, format("Companion level +%d", delta))
    end
    companion.level = latest.level
  end
  companion.maxLevel = latest.maxLevel or companion.maxLevel
  if latest.standing ~= nil then
    if companion.startStanding == nil then
      companion.startStanding = latest.standing
    elseif companion.standing and latest.standing > companion.standing then
      local delta = latest.standing - companion.standing
      addGain(run.gains, Constants.gainType.CompanionExperience, nil, delta)
      self:AppendLog(run, Constants.logKind.CompanionExperience, format("Companion XP +%d", delta))
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
---@return boolean?
function Capture:ObserveBoons(run)
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
            local amount, percent = Helpers.BoonAmount(value)
            if amount then
              ---@type LDT_BoonStat
              local stat = {
                label = label,
                amount = amount,
                percent = percent,
                text = format("%s: %s", label, Helpers.FormatBoonAmount(amount)),
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
  local previous = run.boons
  local changed = #previous ~= #lines
  if not changed then
    for index = 1, #lines do
      if previous[index].label ~= lines[index].label or previous[index].amount ~= lines[index].amount then
        changed = true
        break
      end
    end
  end
  run.boons = lines
  if changed and #lines > 0 then
    local parts = {}
    for index = 1, #lines do
      parts[index] = lines[index].text
    end
    self:AppendLog(run, Constants.logKind.Boon, table.concat(parts, " | "))
  end
  return changed
end

---@param run LDT_Run
---@param factionID number|nil
---@param newLevel number|nil
---@param oldLevel number|nil
function Capture:NoteRenown(run, factionID, newLevel, oldLevel)
  if type(factionID) ~= "number" or type(newLevel) ~= "number" or type(oldLevel) ~= "number" then
    return
  end
  local delta = newLevel - oldLevel
  if delta == 0 then
    return
  end
  addGain(run.gains, Constants.gainType.Renown, factionID, delta)
  local name = "Renown"
  local data = C_MajorFactions.GetMajorFactionData(factionID)
  if data and data.name and data.name ~= "" then
    name = data.name
  end
  local amount = tostring(delta)
  if delta > 0 then
    amount = format("+%d", delta)
  end
  self:AppendLog(run, Constants.logKind.Renown, format("%s %s", name, amount))
end

function Capture:OnMoney()
  local run = Data:GetActiveRun()
  if not run then
    return
  end
  local now = GetMoney()
  if issecretvalue(now) then
    return
  end
  if goldLast == nil then
    goldLast = now
    return
  end
  local delta = now - goldLast
  goldLast = now
  if delta <= 0 then
    return
  end
  self:EnsureClock(run, false)
  addGain(run.gains, Constants.gainType.Gold, nil, delta)
  self:AppendLog(run, Constants.logKind.Gold, format("Gold %s", Helpers.FormatMoney(delta)))
end

function Capture:NoteCharacter()
  local run = Data:GetActiveRun()
  if not run then
    return
  end
  local level = UnitLevel("player")
  local xp = UnitXP("player")
  local xpMax = UnitXPMax("player")
  if issecretvalue(level) or issecretvalue(xp) or issecretvalue(xpMax) then
    return
  end
  if levelSeen == nil or xpSeen == nil or xpMaxSeen == nil then
    levelSeen = level
    xpSeen = xp
    xpMaxSeen = xpMax
    return
  end
  self:EnsureClock(run, false)
  if level > levelSeen then
    local levels = level - levelSeen
    addGain(run.gains, Constants.gainType.Level, nil, levels)
    self:AppendLog(run, Constants.logKind.Level, format("Level +%d", levels))
    local gained = 0
    if xp < xpSeen and xpMaxSeen > xpSeen then
      gained = (xpMaxSeen - xpSeen) + xp
    elseif xp > xpSeen then
      gained = xp - xpSeen
    end
    if gained > 0 then
      addGain(run.gains, Constants.gainType.Experience, nil, gained)
      self:AppendLog(run, Constants.logKind.Experience, format("Experience +%d", gained))
    end
  elseif xp < xpSeen and xpMaxSeen > xpSeen then
    local gained = (xpMaxSeen - xpSeen) + xp
    if gained > 0 then
      addGain(run.gains, Constants.gainType.Experience, nil, gained)
      self:AppendLog(run, Constants.logKind.Experience, format("Experience +%d", gained))
    end
  elseif xp > xpSeen then
    local gained = xp - xpSeen
    addGain(run.gains, Constants.gainType.Experience, nil, gained)
    self:AppendLog(run, Constants.logKind.Experience, format("Experience +%d", gained))
  end
  levelSeen = level
  xpSeen = xp
  xpMaxSeen = xpMax
end

---@param currencyType number|nil
---@param _quantity number|nil
---@param quantityChange number|nil
function Capture:OnCurrency(currencyType, _quantity, quantityChange)
  local run = Data:GetActiveRun()
  if not run or not run.gains or not currencyType or not quantityChange or quantityChange == 0 then
    return
  end
  if not Helpers.CurrencyListed(currencyType) then
    return
  end
  self:EnsureClock(run, false)
  addGain(run.gains, Constants.gainType.Currency, currencyType, quantityChange)
  local info = C_CurrencyInfo.GetCurrencyInfo(currencyType)
  local label = tostring(currencyType)
  if info and info.name and info.name ~= "" then
    label = info.name
  end
  local amount = tostring(quantityChange)
  if quantityChange > 0 then
    amount = format("+%d", quantityChange)
  end
  self:AppendLog(run, Constants.logKind.Currency, format("%s %s", amount, label))
end

---@param message string|nil
---@param guid WOWGUID|nil
function Capture:OnLoot(message, guid)
  local run = Data:GetActiveRun()
  if not run or not message then
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
  self:EnsureClock(run, false)
  local itemID = tonumber(itemLink:match("item:(%d+)"))
  if Helpers.ItemHidden(itemID) then
    return
  end
  local count = tonumber(message:match("x(%d+)")) or 1
  local elapsed = self:Elapsed(run)
  local row = findGain(run.gains, Constants.gainType.Loot, nil, itemLink)
  local seen = lootAt[itemLink]
  local logged = false
  if row and seen and elapsed - seen < 2000 then
    if count > row.amount then
      row.amount = count
      logged = true
    end
  elseif row then
    row.amount = row.amount + count
    logged = true
  else
    addGain(run.gains, Constants.gainType.Loot, itemID, count, itemLink)
    logged = true
  end
  lootAt[itemLink] = elapsed
  if logged then
    self:AppendLog(run, Constants.logKind.Loot, itemLink)
  end
end

function Capture:OnDeath()
  local run = Data:GetActiveRun()
  if not run or self:Ended(run) then
    return
  end
  self:EnsureClock(run, false)
  run.deaths = (run.deaths or 0) + 1
  self:AppendLog(run, Constants.logKind.Death, format("Death %d", run.deaths))
end

---@param run LDT_Run
function Capture:Observe(run)
  Data:SnapshotBest(run)
  if not self:Ended(run) then
    self:RefreshSnapshots(run)
    self:UpdateCompanion(run)
    local instance = self:ReadInstance()
    local placeChanged = self:ObservePlace(run, instance)
    self:ObserveDelveComplete(run)
    if not self:Ended(run) then
      self:ObserveScenario(run, self:ReadScenario(), placeChanged)
      self:ObserveBoons(run)
    end
  end
  self:OnMoney()
  self:NoteCharacter()
end

function Capture:EnsureRun()
  local active = Data:GetActiveRun()
  if active then
    self:EnsureClock(active, true)
    self:Observe(active)
    return
  end
  local run = Data:CreateRun(serverMs())
  if not run then
    return
  end
  self.clockOrigin = monotonicMs()
  self.clockReady = true
  self.reloadNoted = true
  self:FillStart(run)
  self:Observe(run)
  if self.onRunStored then
    self.onRunStored()
  end
end

function Capture:Finish()
  local run = Data:GetActiveRun()
  if not run then
    return
  end
  local resumed = not self.clockReady
  self:EnsureClock(run, false)
  local ended = self:Elapsed(run)
  if resumed then
    local last = run.log[#run.log]
    if last then
      ended = last.elapsed
    end
  end
  if not run.endedAt then
    self:Stop(run, ended, true)
  end
  local text = "Left the delve"
  self:AppendLog(run, Constants.logKind.End, text, nil, ended)
  Data.db.global.activeRunID = nil
  if self.onRunStored then
    self.onRunStored()
  end
end

---@param encounterID number
---@param encounterName string
---@param difficultyID number
---@param groupSize number
---@param success number
function Capture:OnEncounterEnd(encounterID, encounterName, difficultyID, groupSize, success)
  local run = Data:GetActiveRun()
  if not run or self:Ended(run) then
    return
  end
  self:EnsureClock(run, true)
  local elapsed = self:Elapsed(run)
  ---@type LDT_Encounter
  local encounter = {
    encounterID = encounterID,
    encounterName = encounterName,
    difficultyID = difficultyID,
    groupSize = groupSize,
    success = success,
    elapsed = elapsed,
  }
  run.encounters[#run.encounters + 1] = encounter
  if success == 1 then
    self:AppendLog(run, Constants.logKind.Boss, format("Defeated %s", encounterName), {
      encounterID = encounterID,
      encounterName = encounterName,
    })
    return
  end
  self:AppendLog(run, Constants.logKind.Encounter, format("Encounter failed: %s", encounterName), {
    encounterID = encounterID,
    encounterName = encounterName,
  })
end

---@return boolean
function Capture:InInstance()
  local _, instanceType = GetInstanceInfo()
  return instanceType ~= nil and instanceType ~= "" and instanceType ~= "none"
end

function Capture:Sync()
  local picker = _G.DelvesDifficultyPickerFrame
  if picker and not pickerHooked then
    pickerHooked = true
    picker:HookScript("OnShow", function()
      Capture:Sync()
      if addon.Log then
        addon.Log:LogState()
      end
    end)
    picker:HookScript("OnHide", function()
      Capture:Sync()
      if addon.Log then
        addon.Log:LogState()
      end
    end)
    if picker.Dropdown and picker.Dropdown.RegisterCallback and DropdownButtonMixin then
      picker.Dropdown:RegisterCallback(DropdownButtonMixin.Event.OnMenuClose, function()
        Capture:Sync()
        if addon.Log then
          addon.Log:LogState()
        end
      end)
    end
  end
  local tracker = _G.ObjectiveTrackerFrame
  if tracker and not trackerHooked then
    trackerHooked = true
    tracker:HookScript("OnShow", function(frame)
      if not Data.db or not Data.db.global.timer.replaceTracker or not Capture:IsInside() then
        return
      end
      frame:Hide()
      Capture.trackerHidden = true
    end)
  end
  if not self.ready then
    return
  end
  local inDelve = self:IsInside()
  local inInstance = self:InInstance()
  if inInstance then
    self.zoneKnown = true
  end
  local hideTracker = false
  if Data.db.global.timer.replaceTracker then
    if inDelve then
      hideTracker = true
    end
  end
  if tracker and hideTracker then
    if tracker:IsShown() then
      tracker:Hide()
    end
    self.trackerHidden = true
  elseif tracker and self.trackerHidden then
    self.trackerHidden = false
    tracker:Show()
  end
  if inDelve or inInstance then
    self.entranceNoted = false
    if inDelve then
      self:EnsureRun()
    else
      local active = Data:GetActiveRun()
      if active then
        self:EnsureClock(active, true)
        self:Observe(active)
      end
    end
  elseif self.zoneKnown and Data:GetActiveRun() then
    self:Finish()
  end
  local context = nil
  if inDelve then
    context = "run"
  end
  if context == self.timerContext then
    return
  end
  self.timerContext = context
  local timer = addon.Module_Timer
  if not timer then
    return
  end
  if context then
    timer:ShowRun()
    return
  end
  if self.timerFromGame then
    self.timerFromGame = false
    timer:HideRun()
  end
end

function Capture:Register()
  ---@param _frame Frame
  ---@param _event string
  ---@param currencyType number|nil
  ---@param quantity number|nil
  ---@param quantityChange number|nil
  local function onCurrencyDisplayUpdate(_frame, _event, currencyType, quantity, quantityChange)
    Capture:OnCurrency(currencyType, quantity, quantityChange)
    Capture:Sync()
  end

  ---@param _frame Frame
  ---@param _event string
  ---@param unit string
  local function onPlayerAura(_frame, _event, unit)
    if unit ~= "player" then
      return
    end
    local run = Data:GetActiveRun()
    if not run or Capture:Ended(run) then
      return
    end
    Capture:ObserveBoons(run)
  end

  ---@param _frame Frame
  ---@param _event string
  ---@param name string
  local function onAddonLoaded(_frame, _event, name)
    if name == "Blizzard_DelvesDifficultyPicker" then
      Capture:Sync()
    end
  end

  Events:RegisterEvent("SCENARIO_COMPLETED", function()
    Capture:OnScenarioCompleted()
    Capture:Sync()
  end, true)
  Events:RegisterEvent("ENCOUNTER_END", function(_, _, encounterID, encounterName, difficultyID, groupSize, success)
    Capture:OnEncounterEnd(encounterID, encounterName, difficultyID, groupSize, success)
    Capture:Sync()
  end, true)
  Events:RegisterEvent("PLAYER_MONEY", function()
    Capture:OnMoney()
    Capture:Sync()
  end, true)
  Events:RegisterEvent("PLAYER_XP_UPDATE", function()
    Capture:NoteCharacter()
    Capture:Sync()
  end, true)
  ---@param _frame Frame
  ---@param _event string
  ---@param oldLevel number|nil
  ---@param newLevel number|nil
  ---@param real boolean|nil
  local function onLevelChanged(_frame, _event, oldLevel, newLevel, real)
    if real == false or type(oldLevel) ~= "number" or type(newLevel) ~= "number" then
      return
    end
    Capture:NoteCharacter()
    Capture:Sync()
  end
  Events:RegisterEvent("PLAYER_LEVEL_CHANGED", onLevelChanged, true)
  Events:RegisterEvent("CURRENCY_DISPLAY_UPDATE", onCurrencyDisplayUpdate, true)
  Events:RegisterEvent("CHAT_MSG_LOOT", function(_, _, ...)
    ---@type string?
    local message = ...
    Capture:OnLoot(message, select(12, ...))
    Capture:Sync()
  end, true)
  Events:RegisterEvent("PLAYER_DEAD", function()
    Capture:OnDeath()
    Capture:Sync()
  end, true)
  Events:RegisterEvent("PLAYER_ENTERING_WORLD", function()
    local first = not Capture.ready
    Capture.ready = true
    Capture:Sync()
    if first and addon.Log then
      addon.Log:LogState()
    end
  end, true)
  Events:RegisterEvent("UNIT_AURA", onPlayerAura, true)
  ---@param _frame Frame
  ---@param _event string
  ---@param factionID number|nil
  ---@param newLevel number|nil
  ---@param oldLevel number|nil
  local function onRenownLevelChanged(_frame, _event, factionID, newLevel, oldLevel)
    local run = Data:GetActiveRun()
    if not run or Capture:Ended(run) then
      return
    end
    Capture:UpdateCompanion(run)
    Capture:NoteRenown(run, factionID, newLevel, oldLevel)
  end

  Events:RegisterEvent("UPDATE_FACTION", function()
    local run = Data:GetActiveRun()
    if not run or Capture:Ended(run) then
      return
    end
    Capture:UpdateCompanion(run)
  end, true)
  Events:RegisterEvent("MAJOR_FACTION_RENOWN_LEVEL_CHANGED", onRenownLevelChanged, true)
  Events:RegisterEvent({
    "ZONE_CHANGED",
    "ZONE_CHANGED_INDOORS",
    "ZONE_CHANGED_NEW_AREA",
  }, function()
    if not Capture.ready then
      return
    end
    Capture.zoneKnown = true
    Capture:Sync()
  end, true)
  Events:RegisterEvent("ADDON_LOADED", onAddonLoaded, true)
  Events:RegisterEvent({
    "ACTIVE_DELVE_DATA_UPDATE",
    "WALK_IN_DATA_UPDATE",
    "SCENARIO_UPDATE",
    "SCENARIO_CRITERIA_UPDATE",
    "SCENARIO_CRITERIA_SHOW_STATE_UPDATE",
    "SCENARIO_BONUS_OBJECTIVE_COMPLETE",
    "SCENARIO_BONUS_VISIBILITY_UPDATE",
    "SCENARIO_SPELL_UPDATE",
    "SCENARIO_POI_UPDATE",
    "ENCOUNTER_START",
    "DELVE_ASSIST_ACTION",
    "DELVES_ACCOUNT_DATA_ELEMENT_CHANGED",
    "PARTY_ELIGIBILITY_FOR_DELVE_TIERS_CHANGED",
    "SHOW_DELVES_COMPANION_CONFIGURATION_UI",
  }, function()
    Capture:Sync()
  end, true)
  if not addon.Log then
    return
  end
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
    "PLAYER_XP_UPDATE",
    "PLAYER_LEVEL_CHANGED",
    "CURRENCY_DISPLAY_UPDATE",
    "CHAT_MSG_LOOT",
    "PLAYER_DEAD",
  }, function(_, event, ...)
    addon.Log:OnEvent(event, ...)
  end, true)
end

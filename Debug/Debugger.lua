---@class LDT_Addon
local addon = select(2, ...)

---@class LDT_Debugger
local Debugger = {}
addon.Debugger = Debugger
Debugger.logging = false

local Data = addon.Data
local TableForEach = addon.libs.LiqUI.Utils.TableForEach

local DUMP_DEPTH = 4

---@type table<string, string>
local baseline = {}
local boonText = ""
local boonInstanceID

---@type fun(value: string|number|boolean|table|nil, depth: number): string
local dumpValue

---@param parts string[]
---@param fields table<string|number, string|number|boolean|table|nil>
---@param depth number
local function appendFields(parts, fields, depth)
  for key, item in pairs(fields) do
    local listed = type(key) == "number" and key >= 1 and key <= #fields and key == math.floor(key)
    if not listed then
      parts[#parts + 1] = format("%s=%s", tostring(key), dumpValue(item, depth + 1))
    end
  end
end

---@param value string|number|boolean|table|nil
---@param depth number
---@return string
function dumpValue(value, depth)
  if value == nil then
    return "nil"
  end
  if issecretvalue(value) then
    return "secret"
  end
  if depth >= DUMP_DEPTH then
    return "..."
  end
  local valueType = type(value)
  if valueType == "string" then
    return format("%q", value)
  end
  if valueType == "number" or valueType == "boolean" then
    return tostring(value)
  end
  if valueType ~= "table" then
    return valueType
  end
  ---@type string[]
  local parts = {}
  for index = 1, #value do
    parts[#parts + 1] = dumpValue(value[index], depth + 1)
  end
  appendFields(parts, value, depth)
  if #parts == 0 then
    return "none"
  end
  return table.concat(parts, " ")
end

---@param collection LDT_CallResult[]
---@param name string
---@param fn function?
---@param ... any
local function call(collection, name, fn, ...)
  if type(fn) ~= "function" then
    collection[#collection + 1] = {
      name = name,
      text = "nil",
    }
    return nil
  end
  local ok, countOrErr, values = pcall(function(...)
    local function forward(...)
      local count = select("#", ...)
      ---@type (string|number|boolean|table|nil)[]
      local packed = {}
      for index = 1, count do
        packed[index] = select(index, ...)
      end
      return count, packed
    end
    return forward(fn(...))
  end, ...)
  if not ok then
    collection[#collection + 1] = {
      name = name,
      text = format("error=%s", dumpValue(countOrErr, 0)),
    }
    return nil
  end
  if type(countOrErr) ~= "number" or countOrErr == 0 or type(values) ~= "table" then
    collection[#collection + 1] = {
      name = name,
      text = "nil",
    }
    return nil
  end
  ---@type string[]
  local parts = {}
  for index = 1, countOrErr do
    parts[index] = dumpValue(values[index], 0)
  end
  collection[#collection + 1] = {
    name = name,
    text = table.concat(parts, " "),
  }
end

---@param collection LDT_CallResult[]
---@param step ScenarioStepInfo|string|nil
local function callStepCriteria(collection, step)
  local numCriteria = 0
  local stepID
  if type(step) == "table" then
    if not issecretvalue(step.numCriteria) and type(step.numCriteria) == "number" then
      numCriteria = step.numCriteria
    end
    if not issecretvalue(step.stepID) and type(step.stepID) == "number" then
      stepID = step.stepID
    end
  end
  if numCriteria < 1 then
    call(collection, "C_ScenarioInfo.GetCriteriaInfo", C_ScenarioInfo.GetCriteriaInfo, 1)
    call(collection, "C_ScenarioInfo.GetCriteriaInfoByStep", C_ScenarioInfo.GetCriteriaInfoByStep, stepID, 1)
    return
  end
  for index = 1, numCriteria do
    call(collection, format("C_ScenarioInfo.GetCriteriaInfo(%d)", index), C_ScenarioInfo.GetCriteriaInfo, index)
    call(collection, format("C_ScenarioInfo.GetCriteriaInfoByStep(%s,%d)", dumpValue(stepID, 0), index), C_ScenarioInfo.GetCriteriaInfoByStep, stepID, index)
  end
end

---@param collection LDT_CallResult[]
---@param step ScenarioStepInfo|string|nil
local function callHeaderWidget(collection, step)
  local widgetSetID
  if type(step) == "table" and not issecretvalue(step.widgetSetID) and type(step.widgetSetID) == "number" then
    widgetSetID = step.widgetSetID
  end
  local called = false
  if widgetSetID and widgetSetID > 0 then
    local widgetsOK, widgets = pcall(C_UIWidgetManager.GetAllWidgetsBySetID, widgetSetID)
    if widgetsOK and type(widgets) == "table" and not issecretvalue(widgets) then
      for index = 1, #widgets do
        local listed = widgets[index]
        if type(listed) == "table" then
          local widgetID = listed.widgetID
          local widgetType = listed.widgetType
          local header = widgetID and not issecretvalue(widgetID) and widgetType and not issecretvalue(widgetType) and widgetType == Enum.UIWidgetVisualizationType.ScenarioHeaderDelves
          if header then
            call(collection, format("C_UIWidgetManager.GetScenarioHeaderDelvesWidgetVisualizationInfo(%s)", dumpValue(widgetID, 0)), C_UIWidgetManager.GetScenarioHeaderDelvesWidgetVisualizationInfo, widgetID)
            called = true
          end
        end
      end
    end
  end
  if not called then
    call(collection, "C_UIWidgetManager.GetScenarioHeaderDelvesWidgetVisualizationInfo", C_UIWidgetManager.GetScenarioHeaderDelvesWidgetVisualizationInfo)
  end
end

---@return LDT_CallResult[]
local function callAll()
  ---@type LDT_CallResult[]
  local collection = {}
  call(collection, "C_DelvesUI.GetActiveDelveTier", C_DelvesUI.GetActiveDelveTier)
  call(collection, "C_DelvesUI.GetCompanionInfoForActivePlayer", C_DelvesUI.GetCompanionInfoForActivePlayer)
  call(collection, "C_DelvesUI.GetCreatureDisplayInfoForCompanion", C_DelvesUI.GetCreatureDisplayInfoForCompanion, nil)
  call(collection, "C_DelvesUI.GetCurioLink", C_DelvesUI.GetCurioLink)
  call(collection, "C_DelvesUI.GetCurioNodeForCompanion(Combat)", C_DelvesUI.GetCurioNodeForCompanion, Enum.CurioType.Combat, nil)
  call(collection, "C_DelvesUI.GetCurioNodeForCompanion(Utility)", C_DelvesUI.GetCurioNodeForCompanion, Enum.CurioType.Utility, nil)
  call(collection, "C_DelvesUI.GetCurioRarityByTraitCondAccountElementID", C_DelvesUI.GetCurioRarityByTraitCondAccountElementID)
  call(collection, "C_DelvesUI.GetCurrentDelvesSeasonNumber", C_DelvesUI.GetCurrentDelvesSeasonNumber)
  call(collection, "C_DelvesUI.GetDelveEntranceBackgroundWidgetSetID", C_DelvesUI.GetDelveEntranceBackgroundWidgetSetID)
  call(collection, "C_DelvesUI.GetDelveEntranceDescriptionString", C_DelvesUI.GetDelveEntranceDescriptionString)
  call(collection, "C_DelvesUI.GetDelveEntranceHeaderString", C_DelvesUI.GetDelveEntranceHeaderString)
  call(collection, "C_DelvesUI.GetDelveEntranceMapID", C_DelvesUI.GetDelveEntranceMapID)
  local tiersOK, tiers = pcall(C_DelvesUI.GetDelveEntranceTiers)
  if not tiersOK then
    local err = "error"
    if type(tiers) == "string" then
      err = format("error=%s", tiers)
    end
    collection[#collection + 1] = {
      name = "C_DelvesUI.GetDelveEntranceTiers",
      text = err,
    }
  else
    collection[#collection + 1] = {
      name = "C_DelvesUI.GetDelveEntranceTiers",
      text = dumpValue(tiers, 0),
    }
  end
  call(collection, "C_DelvesUI.GetDelveEntranceTitleString", C_DelvesUI.GetDelveEntranceTitleString)
  call(collection, "C_DelvesUI.GetDelvesAffixSpellsForSeason", C_DelvesUI.GetDelvesAffixSpellsForSeason)
  call(collection, "C_DelvesUI.GetDelvesFactionForSeason", C_DelvesUI.GetDelvesFactionForSeason)
  call(collection, "C_DelvesUI.GetDelvesMinRequiredLevel", C_DelvesUI.GetDelvesMinRequiredLevel)
  call(collection, "C_DelvesUI.GetFactionForCompanion", C_DelvesUI.GetFactionForCompanion, nil)
  call(collection, "C_DelvesUI.GetFlavorNodeForCompanion", C_DelvesUI.GetFlavorNodeForCompanion, nil)
  call(collection, "C_DelvesUI.GetFlavorNodeNameForCompanion", C_DelvesUI.GetFlavorNodeNameForCompanion, nil)
  call(collection, "C_DelvesUI.GetLockedTextForCompanion", C_DelvesUI.GetLockedTextForCompanion, nil)
  call(collection, "C_DelvesUI.GetModelSceneForCompanion", C_DelvesUI.GetModelSceneForCompanion, nil)
  call(collection, "C_DelvesUI.GetPlayerCompanionPDEID", C_DelvesUI.GetPlayerCompanionPDEID, nil)
  call(collection, "C_DelvesUI.GetRoleNodeForCompanion", C_DelvesUI.GetRoleNodeForCompanion, nil)
  call(collection, "C_DelvesUI.GetRoleSubtreeForCompanion(Dps)", C_DelvesUI.GetRoleSubtreeForCompanion, Enum.CompanionRoleType.Dps, nil)
  call(collection, "C_DelvesUI.GetRoleSubtreeForCompanion(Heal)", C_DelvesUI.GetRoleSubtreeForCompanion, Enum.CompanionRoleType.Heal, nil)
  call(collection, "C_DelvesUI.GetRoleSubtreeForCompanion(Tank)", C_DelvesUI.GetRoleSubtreeForCompanion, Enum.CompanionRoleType.Tank, nil)
  call(collection, "C_DelvesUI.GetTieredEntranceOptionalAffixTraitTreeID", C_DelvesUI.GetTieredEntranceOptionalAffixTraitTreeID)
  call(collection, "C_DelvesUI.GetTieredEntrancePDEID", C_DelvesUI.GetTieredEntrancePDEID)
  call(collection, "C_DelvesUI.GetTieredEntranceType", C_DelvesUI.GetTieredEntranceType)
  local traitTreeOK, traitTreeID = pcall(C_DelvesUI.GetTraitTreeForCompanion, nil)
  if not traitTreeOK then
    local err = "error"
    if type(traitTreeID) == "string" then
      err = format("error=%s", traitTreeID)
    end
    collection[#collection + 1] = {
      name = "C_DelvesUI.GetTraitTreeForCompanion",
      text = err,
    }
    traitTreeID = nil
  else
    collection[#collection + 1] = {
      name = "C_DelvesUI.GetTraitTreeForCompanion",
      text = dumpValue(traitTreeID, 0),
    }
  end
  call(collection, "C_DelvesUI.GetUnseenCuriosBySlotType(Role)", C_DelvesUI.GetUnseenCuriosBySlotType, Enum.CompanionConfigSlotTypes.Role, {})
  call(collection, "C_DelvesUI.GetUnseenCuriosBySlotType(Utility)", C_DelvesUI.GetUnseenCuriosBySlotType, Enum.CompanionConfigSlotTypes.Utility, {})
  call(collection, "C_DelvesUI.GetUnseenCuriosBySlotType(Combat)", C_DelvesUI.GetUnseenCuriosBySlotType, Enum.CompanionConfigSlotTypes.Combat, {})
  call(collection, "C_DelvesUI.GetUnseenCuriosBySlotType(Flavor)", C_DelvesUI.GetUnseenCuriosBySlotType, Enum.CompanionConfigSlotTypes.Flavor, {})
  call(collection, "C_DelvesUI.GetWorldTierDifficultyForActivePlayer", C_DelvesUI.GetWorldTierDifficultyForActivePlayer)
  call(collection, "C_DelvesUI.HasActiveDelve", C_DelvesUI.HasActiveDelve)
  call(collection, "C_DelvesUI.HasActiveLFGLair", C_DelvesUI.HasActiveLFGLair)
  call(collection, "C_DelvesUI.HasActiveLair", C_DelvesUI.HasActiveLair)
  local tierCalled = false
  if type(tiers) == "table" and not issecretvalue(tiers) then
    for index = 1, #tiers do
      local tierInfo = tiers[index]
      if type(tierInfo) == "table" and not issecretvalue(tierInfo) then
        call(collection, format("C_DelvesUI.IsDelveEntranceTierEnabled(%s)", dumpValue(tierInfo.tier, 0)), C_DelvesUI.IsDelveEntranceTierEnabled, tierInfo.tier)
        tierCalled = true
        local rewards = tierInfo.rewards
        if type(rewards) == "table" and not issecretvalue(rewards) then
          for rewardIndex = 1, #rewards do
            local reward = rewards[rewardIndex]
            if type(reward) == "table" and not issecretvalue(reward) then
              call(collection, format("C_Item.GetDelvePreviewItemLink(%s,%s)", dumpValue(reward.id, 0), dumpValue(reward.context, 0)), C_Item.GetDelvePreviewItemLink, reward.id, reward.context)
              call(collection, format("C_Item.GetDelvePreviewItemQuality(%s,%s)", dumpValue(reward.id, 0), dumpValue(reward.context, 0)), C_Item.GetDelvePreviewItemQuality, reward.id, reward.context)
            end
          end
        end
      end
    end
  end
  if not tierCalled then
    call(collection, "C_DelvesUI.IsDelveEntranceTierEnabled", C_DelvesUI.IsDelveEntranceTierEnabled)
    call(collection, "C_Item.GetDelvePreviewItemLink", C_Item.GetDelvePreviewItemLink)
    call(collection, "C_Item.GetDelvePreviewItemQuality", C_Item.GetDelvePreviewItemQuality)
  end
  call(collection, "C_DelvesUI.IsEligibleForActiveDelveRewards", C_DelvesUI.IsEligibleForActiveDelveRewards, "player")
  call(collection, "C_DelvesUI.IsInLair", C_DelvesUI.IsInLair)
  call(collection, "C_DelvesUI.IsTraitTreeForCompanion", C_DelvesUI.IsTraitTreeForCompanion, traitTreeID)
  call(collection, "C_PartyInfo.IsDelveInProgress", C_PartyInfo.IsDelveInProgress)
  call(collection, "C_PartyInfo.IsDelveComplete", C_PartyInfo.IsDelveComplete)
  call(collection, "C_PartyInfo.IsPartyWalkIn", C_PartyInfo.IsPartyWalkIn)
  local mapOK, mapID = pcall(C_Map.GetBestMapForUnit, "player")
  if not mapOK then
    local err = "error"
    if type(mapID) == "string" then
      err = format("error=%s", mapID)
    end
    collection[#collection + 1] = {
      name = "C_Map.GetBestMapForUnit",
      text = err,
    }
    mapID = nil
  else
    collection[#collection + 1] = {
      name = "C_Map.GetBestMapForUnit",
      text = dumpValue(mapID, 0),
    }
  end
  call(collection, "C_AreaPoiInfo.GetDelvesForMap", C_AreaPoiInfo.GetDelvesForMap, mapID)
  call(collection, "C_ScenarioInfo.IsTieredEntranceScenario", C_ScenarioInfo.IsTieredEntranceScenario)
  call(collection, "C_ScenarioInfo.GetTieredEntranceActiveSpells", C_ScenarioInfo.GetTieredEntranceActiveSpells)
  call(collection, "C_ScenarioInfo.GetScenarioInfo", C_ScenarioInfo.GetScenarioInfo)
  local stepOK, step = pcall(C_ScenarioInfo.GetScenarioStepInfo)
  if not stepOK then
    local err = "error"
    if type(step) == "string" then
      err = format("error=%s", step)
    end
    collection[#collection + 1] = {
      name = "C_ScenarioInfo.GetScenarioStepInfo",
      text = err,
    }
    step = nil
  else
    collection[#collection + 1] = {
      name = "C_ScenarioInfo.GetScenarioStepInfo",
      text = dumpValue(step, 0),
    }
  end
  callStepCriteria(collection, step)
  call(collection, "C_ScenarioInfo.GetDisplayInfo", C_ScenarioInfo.GetDisplayInfo)
  call(collection, "C_Scenario.IsInScenario", C_Scenario and C_Scenario.IsInScenario)
  call(collection, "C_Scenario.GetInfo", C_Scenario and C_Scenario.GetInfo)
  call(collection, "C_Scenario.GetStepInfo", C_Scenario and C_Scenario.GetStepInfo)
  call(collection, "C_Scenario.GetBonusSteps", C_Scenario and C_Scenario.GetBonusSteps)
  call(collection, "C_Scenario.GetBonusStepRewardQuestID", C_Scenario and C_Scenario.GetBonusStepRewardQuestID)
  call(collection, "C_Scenario.GetSupersededObjectives", C_Scenario and C_Scenario.GetSupersededObjectives)
  call(collection, "C_Scenario.ShouldShowCriteria", C_Scenario and C_Scenario.ShouldShowCriteria)
  call(collection, "C_Scenario.TreatScenarioAsDungeon", C_Scenario and C_Scenario.TreatScenarioAsDungeon)
  callHeaderWidget(collection, step)
  call(collection, "InstanceDifficultyMixin:IsInDelve", InstanceDifficultyMixin and InstanceDifficultyMixin.IsInDelve, InstanceDifficultyMixin)
  call(collection, "C_GossipInfo.GetOptions", C_GossipInfo.GetOptions)
  call(collection, "C_GossipInfo.GetAvailableQuests", C_GossipInfo.GetAvailableQuests)
  call(collection, "C_GossipInfo.GetActiveQuests", C_GossipInfo.GetActiveQuests)
  call(collection, "C_GossipInfo.GetNumAvailableQuests", C_GossipInfo.GetNumAvailableQuests)
  call(collection, "C_GossipInfo.GetNumActiveQuests", C_GossipInfo.GetNumActiveQuests)
  call(collection, "C_GossipInfo.GetText", C_GossipInfo.GetText)
  call(collection, "C_GossipInfo.ForceGossip", C_GossipInfo.ForceGossip)
  call(collection, "UnitName(\"npc\")", UnitName, "npc")
  call(collection, "UnitGUID(\"npc\")", UnitGUID, "npc")
  call(collection, "GetQuestID", GetQuestID)
  call(collection, "GetTitleText", GetTitleText)
  local taxiOK, taxiCount = pcall(NumTaxiNodes)
  if taxiOK and type(taxiCount) == "number" and not issecretvalue(taxiCount) and taxiCount > 0 then
    collection[#collection + 1] = {
      name = "NumTaxiNodes",
      text = dumpValue(taxiCount, 0),
    }
    for index = 1, taxiCount do
      call(collection, format("TaxiNodeName(%d)", index), TaxiNodeName, index)
      call(collection, format("TaxiNodeGetType(%d)", index), TaxiNodeGetType, index)
    end
  else
    call(collection, "NumTaxiNodes", NumTaxiNodes)
  end
  call(collection, "GetMoney", GetMoney)
  return collection
end

---@param prefix string
---@param message string
function Debugger:AddLine(prefix, message)
  local logger = addon.logger
  if not logger then
    return
  end
  logger:Log(prefix, message)
end

---@param addedAuras AuraData[]|nil
---@return boolean
local function addedHasBoon(addedAuras)
  if addedAuras == nil then
    return false
  end
  if issecretvalue(addedAuras) or type(addedAuras) ~= "table" then
    return true
  end
  for index = 1, #addedAuras do
    local aura = addedAuras[index]
    if issecretvalue(aura) or type(aura) ~= "table" then
      return true
    end
    local spellID = aura.spellId
    if spellID == nil or issecretvalue(spellID) or type(spellID) ~= "number" then
      return true
    end
    if spellID == Data.boonSpellID then
      return true
    end
  end
  return false
end

---@param instanceIDs number[]|nil
---@return boolean
local function instanceListHasBoon(instanceIDs)
  if instanceIDs == nil then
    return false
  end
  if issecretvalue(instanceIDs) or type(instanceIDs) ~= "table" then
    return true
  end
  for index = 1, #instanceIDs do
    local instanceID = instanceIDs[index]
    if issecretvalue(instanceID) or type(instanceID) ~= "number" then
      return true
    end
    if boonInstanceID ~= nil and instanceID == boonInstanceID then
      return true
    end
  end
  return false
end

---@param updateInfo UnitAuraUpdateInfo|nil
---@return boolean
local function boonAuraChanged(updateInfo)
  if updateInfo == nil or issecretvalue(updateInfo) or type(updateInfo) ~= "table" then
    return true
  end
  local fullUpdate = updateInfo.isFullUpdate
  if issecretvalue(fullUpdate) or type(fullUpdate) ~= "boolean" then
    return true
  end
  if fullUpdate then
    return true
  end
  if addedHasBoon(updateInfo.addedAuras) then
    return true
  end
  if instanceListHasBoon(updateInfo.updatedAuraInstanceIDs) then
    return true
  end
  if instanceListHasBoon(updateInfo.removedAuraInstanceIDs) then
    return true
  end
  return false
end

---@param lines string[]
local function appendBoon(lines)
  local name = format("C_UnitAuras.GetPlayerAuraBySpellID(%d)", Data.boonSpellID)
  local ok, aura = pcall(C_UnitAuras.GetPlayerAuraBySpellID, Data.boonSpellID)
  ---@type string[]
  local parts = {}
  if not ok then
    boonInstanceID = nil
    parts[1] = format("%s error=%s", name, dumpValue(aura, 0))
  elseif aura == nil or issecretvalue(aura) or type(aura) ~= "table" then
    boonInstanceID = nil
    parts[1] = format("%s nil", name)
  else
    local instanceID = aura.auraInstanceID
    if type(instanceID) == "number" and not issecretvalue(instanceID) then
      boonInstanceID = instanceID
    else
      boonInstanceID = nil
    end
    parts[1] = format("%s spellId=%s name=%s applications=%s", name, dumpValue(aura.spellId, 0), dumpValue(aura.name, 0), dumpValue(aura.applications, 0))
    if boonInstanceID ~= nil then
      local tooltipOK, tooltip = pcall(C_TooltipInfo.GetUnitBuffByAuraInstanceID, "player", boonInstanceID)
      if not tooltipOK then
        parts[#parts + 1] = format("tooltip error=%s", dumpValue(tooltip, 0))
      elseif type(tooltip) == "table" and not issecretvalue(tooltip) then
        local tooltipLines = tooltip.lines
        if type(tooltipLines) == "table" and not issecretvalue(tooltipLines) then
          for lineIndex = 2, #tooltipLines do
            local row = tooltipLines[lineIndex]
            if type(row) == "table" and not issecretvalue(row) then
              local leftText = row.leftText
              if type(leftText) == "string" and not issecretvalue(leftText) and leftText ~= "" then
                parts[#parts + 1] = leftText
              end
            end
          end
        end
      end
    end
  end
  local text = table.concat(parts, "\n")
  if text == boonText then
    return
  end
  boonText = text
  for index = 1, #parts do
    lines[#lines + 1] = parts[index]
  end
end

---@param lines string[]
---@param collection LDT_CallResult[]
local function appendDiff(lines, collection)
  ---@type table<string, boolean>
  local seen = {}
  for index = 1, #collection do
    local row = collection[index]
    seen[row.name] = true
    if baseline[row.name] ~= row.text then
      lines[#lines + 1] = format("%s %s", row.name, row.text)
      baseline[row.name] = row.text
    end
  end
  ---@type string[]
  local removed = {}
  TableForEach(baseline, function(_text, name)
    if not seen[name] then
      removed[#removed + 1] = name
    end
  end)
  table.sort(removed)
  for index = 1, #removed do
    local name = removed[index]
    lines[#lines + 1] = format("%s nil", name)
    baseline[name] = nil
  end
end

---@param headline string
function Debugger:AddEvent(headline)
  local collection = callAll()
  ---@type string[]
  local lines = { headline }
  appendDiff(lines, collection)
  appendBoon(lines)
  self:AddLine("event", table.concat(lines, "\n"))
end

local function logBoon()
  ---@type string[]
  local lines = { "UNIT_AURA player" }
  appendBoon(lines)
  if #lines == 1 then
    return
  end
  Debugger:AddLine("event", table.concat(lines, "\n"))
end

---@param event string
---@param ... any
function Debugger:OnEvent(event, ...)
  if not self.logging then
    return
  end
  local count = select("#", ...)
  if count == 0 then
    self:AddEvent(event)
    return
  end
  ---@type string[]
  local parts = {}
  for index = 1, count do
    parts[index] = dumpValue(select(index, ...), 0)
  end
  self:AddEvent(format("%s %s", event, table.concat(parts, " ")))
end

local logEvents = {
  "ACTIVE_DELVE_DATA_UPDATE",
  "WALK_IN_DATA_UPDATE",
  "DELVE_ASSIST_ACTION",
  "DELVES_ACCOUNT_DATA_ELEMENT_CHANGED",
  "PARTY_ELIGIBILITY_FOR_DELVE_TIERS_CHANGED",
  "SHOW_DELVES_COMPANION_CONFIGURATION_UI",
  "SCENARIO_UPDATE",
  "SCENARIO_CRITERIA_UPDATE",
  "SCENARIO_CRITERIA_SHOW_STATE_UPDATE",
  "SCENARIO_COMPLETED",
  "SCENARIO_BONUS_OBJECTIVE_COMPLETE",
  "SCENARIO_BONUS_VISIBILITY_UPDATE",
  "SCENARIO_SPELL_UPDATE",
  "SCENARIO_POI_UPDATE",
  "PLAYER_ENTERING_WORLD",
  "PLAYER_LEAVING_WORLD",
  "ZONE_CHANGED",
  "ZONE_CHANGED_INDOORS",
  "ZONE_CHANGED_NEW_AREA",
  "PLAYER_MAP_CHANGED",
  "UPDATE_INSTANCE_INFO",
  "PLAYER_INTERACTION_MANAGER_FRAME_SHOW",
  "PLAYER_INTERACTION_MANAGER_FRAME_HIDE",
  "ENCOUNTER_END",
  "CHAT_MSG_LOOT",
  "CHAT_MSG_MONEY",
  "PLAYER_MONEY",
  "CURRENCY_DISPLAY_UPDATE",
  "PLAYER_XP_UPDATE",
  "PLAYER_LEVEL_CHANGED",
  "PLAYER_DEAD",
  "PLAYER_SPECIALIZATION_CHANGED",
  "UPDATE_FACTION",
  "MAJOR_FACTION_RENOWN_LEVEL_CHANGED",
  "PLAYER_CHOICE_UPDATE",
  "PLAYER_CHOICE_CLOSE",
  "GOSSIP_SHOW",
  "GOSSIP_CLOSED",
  "GOSSIP_OPTIONS_REFRESHED",
  "GOSSIP_CONFIRM",
  "QUEST_GREETING",
  "QUEST_DETAIL",
  "QUEST_PROGRESS",
  "QUEST_COMPLETE",
  "QUEST_FINISHED",
  "QUEST_ACCEPTED",
  "TAXIMAP_OPENED",
  "TAXIMAP_CLOSED",
}

---@param _frame Frame
---@param event string
---@param ... any
local function onLogEvent(_frame, event, ...)
  Debugger:OnEvent(event, ...)
end

---@param _frame Frame
---@param _event string
---@param _unit string
---@param updateInfo UnitAuraUpdateInfo
local function onPlayerBoonAura(_frame, _event, _unit, updateInfo)
  if not Debugger.logging then
    return
  end
  if not boonAuraChanged(updateInfo) then
    return
  end
  logBoon()
end

function Debugger:Start()
  if self.logging then
    addon.Core:Print("Logging is already running.")
    return
  end
  local LiqUI = addon.libs.LiqUI
  local logger = addon.logger
  if not LiqUI or not LiqUI.Events or not addon.Data.db or not logger then
    addon.Core:Print("Logging could not start.")
    return
  end
  logger.maxLines = 1000000
  self.logging = true
  wipe(baseline)
  boonText = ""
  boonInstanceID = nil
  LiqUI.Events:RegisterEvent(logEvents, onLogEvent, true)
  LiqUI.Events:RegisterEvent("UNIT_AURA", onPlayerBoonAura, true, "player")
  self:AddEvent("start")
  logger:Show()
  addon.Core:Print("Logging started.")
end

function Debugger:Stop()
  if not self.logging then
    addon.Core:Print("Logging is not running.")
    return
  end
  self:AddEvent("stop")
  self.logging = false
  local Events = addon.libs.LiqUI and addon.libs.LiqUI.Events
  if Events then
    Events:UnregisterEvent(logEvents, onLogEvent)
    Events:UnregisterEvent("UNIT_AURA", onPlayerBoonAura)
  end
  addon.Core:Print("Logging stopped.")
end

---@class LDT_Addon
local addon = select(2, ...)

---@class LDT_Data
local Data = {}
addon.Data = Data

local LibAceDB = addon.libs.AceDB
local LiqUI = addon.libs.LiqUI
local TableForEach = LiqUI.Utils.TableForEach
local TableGet = LiqUI.Utils.TableGet
local Constants = addon.Constants
local Helpers = addon.Helpers

Data.dbVersion = 1

---@type table
Data.defaultDB = {
  ---@type LDT_Global
  global = {
    dbVersion = 1,
    minimap = {
      minimapPos = 220,
      hide = false,
      lock = false,
    },
    liqui = {
      windows = {
        Run = {},
        History = {},
      },
      tables = {
        History = { hiddenColumns = {} },
      },
    },
    logs = {
      lines = {},
      autoScroll = true,
      autoShow = false,
    },
    timer = {
      point = "TOPRIGHT",
      relativePoint = "TOPRIGHT",
      x = -24,
      y = -180,
      replaceTracker = true,
      showObjectives = true,
      showObjectiveCounts = true,
      aheadColor = { r = 0.35, g = 0.9, b = 0.5, a = 1 },
      behindColor = { r = 1, g = 0.4, b = 0.4, a = 1 },
      backgroundColor = { r = 0, g = 0, b = 0, a = 0.5 },
      borderColor = { r = 1, g = 1, b = 1, a = 0 },
    },
    scenarios = {},
    steps = {},
    runs = {},
    activeRunID = nil,
    nextRunID = 1,
  },
}

function Data:Initialize()
  ---@type LDT_AceDB
  local db = LibAceDB:New("LiqDelveTimerDB", self.defaultDB, true)
  self.db = db
end

---@return LDT_Run|nil
function Data:GetActiveRun()
  if not self.db or not self.db.global.activeRunID then
    return nil
  end
  local activeRunID = self.db.global.activeRunID
  local runs = self.db.global.runs
  for index = #runs, 1, -1 do
    local run = runs[index]
    if run.id == activeRunID then
      return run
    end
  end
  return nil
end

---@param instance LDT_Instance|nil
---@return LDT_Delve|nil
function Data:DelveForInstance(instance)
  if not instance then
    return nil
  end
  if instance.instanceID then
    local delve = TableGet(self.delves, "delveID", instance.instanceID)
    if delve then
      return delve
    end
  end
  if not instance.mapID then
    return nil
  end
  local uiMap = TableGet(self.uiMaps, "uiMapID", instance.mapID)
  if not uiMap then
    return nil
  end
  return TableGet(self.delves, "delveID", uiMap.delveID)
end

---@return LDT_Run|nil
function Data:GetLatestRun()
  if not self.db then
    return nil
  end
  local runs = self.db.global.runs
  return runs[#runs]
end

---@param startedAt number
---@return LDT_Run|nil
function Data:CreateRun(startedAt)
  if not self.db then
    return nil
  end
  local runs = self.db.global.runs
  local nextRunID = self.db.global.nextRunID
  local runID = format("run-%d", nextRunID)
  if not runID then
    return nil
  end
  self.db.global.nextRunID = nextRunID + 1
  ---@type LDT_Run
  local run = {
    id = runID,
    result = Constants.runResult.Active,
    startedAt = startedAt,
    scenarios = {},
    boons = {},
    gains = {},
    encounters = {},
    log = {},
    watch = {
      criteria = {},
      scenarioComplete = false,
    },
  }
  runs[#runs + 1] = run
  self.db.global.activeRunID = run.id
  return run
end

---@param value string|nil
---@return string|nil
local function plainString(value)
  if type(value) ~= "string" or issecretvalue(value) or value == "" then
    return nil
  end
  return value
end

---@param value number|nil
---@return number|nil
local function plainNumber(value)
  if type(value) ~= "number" or issecretvalue(value) then
    return nil
  end
  return value
end

---@param value boolean|nil
---@return boolean|nil
local function plainBoolean(value)
  if type(value) ~= "boolean" or issecretvalue(value) then
    return nil
  end
  return value
end

---@param criteria LDT_CriteriaSnap[]
---@return LDT_Criteria[]
local function learnedCriteria(criteria)
  ---@type LDT_Criteria[]
  local rows = {}
  for index = 1, #criteria do
    local info = criteria[index]
    local criteriaID = plainNumber(info.criteriaID)
    if criteriaID ~= nil then
      ---@type LDT_Criteria
      local row = {
        criteriaID = criteriaID,
        description = plainString(info.description),
        totalQuantity = plainNumber(info.totalQuantity),
        criteriaType = plainNumber(info.criteriaType),
        flags = plainNumber(info.flags),
        assetID = plainNumber(info.assetID),
        isWeightedProgress = plainBoolean(info.isWeightedProgress),
      }
      rows[#rows + 1] = row
    end
  end
  return rows
end

---@param run LDT_Run
---@param scenario LDT_Scenario
function Data:NoteScenario(run, scenario)
  if not self.db then
    return
  end
  local info = scenario.info
  local step = scenario.step
  if not info or not step then
    return
  end
  local scenarioID = plainNumber(info.scenarioID)
  local stepID = plainNumber(step.stepID)
  if not scenarioID or not stepID then
    return
  end
  local stage = plainNumber(info.currentStage)
  local numStages = plainNumber(info.numStages)
  local knownScenario = TableGet(self.scenarios, "scenarioID", scenarioID)
  local knownStep = TableGet(self.steps, "stepID", stepID)
  if not knownScenario then
    local scenarios = self.db.global.scenarios
    local record = scenarios[scenarioID]
    if not record then
      ---@type LDT_ScenarioRow
      record = {
        scenarioID = scenarioID,
      }
      scenarios[scenarioID] = record
    end
    local scenarioName = plainString(info.name)
    if scenarioName and (record.name == nil or record.name == "") then
      record.name = scenarioName
    end
    if numStages and record.numStages == nil then
      record.numStages = numStages
    end
    local instance = run.instance
    if instance then
      if instance.mapID and record.mapID == nil then
        record.mapID = instance.mapID
      end
      if instance.instanceID and record.instanceID == nil then
        record.instanceID = instance.instanceID
      end
      if instance.difficultyID and record.difficultyID == nil then
        record.difficultyID = instance.difficultyID
      end
    end
  end
  local criteriaRows = learnedCriteria(scenario.criteria)
  if not knownStep or #criteriaRows > 0 then
    local storedSteps = self.db.global.steps
    local storedStep = storedSteps[stepID]
    if not storedStep then
      ---@type LDT_ScenarioStep
      storedStep = {
        stepID = stepID,
        scenarioID = scenarioID,
      }
      storedSteps[stepID] = storedStep
    end
    if not knownStep then
      if stage then
        storedStep.stage = stage
      end
      local title = plainString(step.title)
      if title and (storedStep.title == nil or storedStep.title == "") then
        storedStep.title = title
      end
    end
    if #criteriaRows > 0 then
      storedStep.criteria = criteriaRows
    end
  end
  self:SnapshotBest(run)
end

---@param callback fun(run: LDT_Run)
function Data:ForEachRun(callback)
  if not self.db then
    return
  end
  TableForEach(self.db.global.runs, function(run)
    callback(run)
  end)
end

---@param run LDT_Run
function Data:SnapshotBest(run)
  if run.best or not Helpers.RunTier(run) then
    return
  end
  if Helpers.RunMode(run) ~= Constants.runMode.Lab then
    local first = run.scenarios[1]
    if not first then
      return
    end
  end
end

---@param run LDT_Run
---@return LDT_StepRow[]
function Data:StepRows(run)
  ---@type LDT_StepRow[]
  local rows = {}
  if #run.scenarios == 0 then
    return rows
  end
  return rows
end

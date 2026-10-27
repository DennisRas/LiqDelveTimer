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

---@param stored LDT_Criteria[]|nil
---@param incoming LDT_Criteria[]
---@return LDT_Criteria[]
local function mergeCriteria(stored, incoming)
  if not stored then
    return incoming
  end
  for index = 1, #incoming do
    local row = incoming[index]
    local match
    if row.criteriaID ~= 0 then
      for storedIndex = 1, #stored do
        local storedRow = stored[storedIndex]
        if storedRow.criteriaID == row.criteriaID then
          match = storedRow
          break
        end
      end
    elseif stored[index] and stored[index].criteriaID == 0 then
      match = stored[index]
    end
    if not match then
      stored[#stored + 1] = row
    else
      match.description = match.description or row.description
      match.totalQuantity = match.totalQuantity or row.totalQuantity
      match.criteriaType = match.criteriaType or row.criteriaType
      match.flags = match.flags or row.flags
      match.assetID = match.assetID or row.assetID
      if match.isWeightedProgress == nil then
        match.isWeightedProgress = row.isWeightedProgress
      end
    end
  end
  return stored
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
    local scenarioName = plainString(info.name)
    local flags = plainNumber(info.flags)
    local instance = run.instance
    local mapID = instance and instance.mapID
    local instanceID = instance and instance.instanceID
    local difficultyID = instance and instance.difficultyID
    if scenarioName or numStages or flags or mapID or instanceID or difficultyID then
      if not record then
        ---@type LDT_ScenarioRow
        record = {
          scenarioID = scenarioID,
        }
        scenarios[scenarioID] = record
      end
      record.name = record.name or scenarioName
      record.numStages = record.numStages or numStages
      record.flags = record.flags or flags
      record.mapID = record.mapID or mapID
      record.instanceID = record.instanceID or instanceID
      record.difficultyID = record.difficultyID or difficultyID
    end
  end
  local criteriaRows = learnedCriteria(scenario.criteria)
  local title = plainString(step.title)
  local description = plainString(step.description)
  local learnTitle = title and not knownStep
  local learnDescription = description and (not knownStep or not knownStep.description or knownStep.description == "")
  local learnStage = stage and not knownStep
  if learnTitle or learnDescription or learnStage or #criteriaRows > 0 then
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
    if learnTitle then
      storedStep.title = storedStep.title or title
    end
    if learnDescription then
      storedStep.description = storedStep.description or description
    end
    if learnStage then
      storedStep.stage = storedStep.stage or stage
    end
    if #criteriaRows > 0 then
      storedStep.criteria = mergeCriteria(storedStep.criteria, criteriaRows)
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

---@param source LDT_Run|nil
---@return LDT_RunBest
local function copyBest(source)
  ---@type LDT_RunBest
  local copy = {
    scenarios = {},
  }
  if not source then
    return copy
  end
  copy.id = source.id
  copy.startedAt = source.startedAt
  copy.endedAt = source.endedAt
  for index = 1, #source.scenarios do
    local scenario = source.scenarios[index]
    ---@type LDT_BestStep[]
    local steps = {}
    for stepIndex = 1, #scenario.steps do
      local step = scenario.steps[stepIndex]
      ---@type LDT_BestStep
      local bestStep = {
        stepID = step.stepID,
        stage = step.stage,
        enteredElapsed = step.enteredElapsed,
        completedElapsed = step.completedElapsed,
      }
      steps[#steps + 1] = bestStep
    end
    ---@type LDT_BestScenario
    local bestScenario = {
      index = scenario.index,
      scenarioID = scenario.scenarioID,
      enteredElapsed = scenario.enteredElapsed,
      completedElapsed = scenario.completedElapsed,
      steps = steps,
    }
    copy.scenarios[#copy.scenarios + 1] = bestScenario
  end
  return copy
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
  run.best = copyBest(Helpers.BestRun(run))
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

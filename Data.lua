---@class LDT_Addon
local addon = select(2, ...)

---@class LDT_Data
local Data = {}
addon.Data = Data

local LibAceDB = addon.libs.AceDB
local LiqUI = addon.libs.LiqUI
local TableForEach = LiqUI.Utils.TableForEach
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
    labyrinth = false,
    startedAt = startedAt,
    boons = {},
    gains = {},
    chambers = {},
    encounters = {},
    log = {},
    steps = {},
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
---@return LDT_CatalogCriteria[]
local function catalogCriteria(criteria)
  ---@type LDT_CatalogCriteria[]
  local rows = {}
  for index = 1, #criteria do
    local info = criteria[index]
    local criteriaID = plainNumber(info.criteriaID)
    if criteriaID ~= nil then
      ---@type LDT_CatalogCriteria
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

---@param criteria LDT_CriteriaSnap[]
---@return LDT_RunCriteria[]
local function runCriteria(criteria)
  ---@type LDT_RunCriteria[]
  local rows = {}
  for index = 1, #criteria do
    local info = criteria[index]
    local criteriaID = plainNumber(info.criteriaID)
    if criteriaID ~= nil then
      local completed = plainBoolean(info.completed)
      local failed = plainBoolean(info.failed)
      ---@type LDT_RunCriteria
      local row = {
        criteriaID = criteriaID,
        description = plainString(info.description),
        completed = completed == true,
        failed = failed == true,
        quantity = plainNumber(info.quantity),
        totalQuantity = plainNumber(info.totalQuantity),
        quantityString = plainString(info.quantityString),
        criteriaType = plainNumber(info.criteriaType),
        isWeightedProgress = plainBoolean(info.isWeightedProgress),
      }
      rows[#rows + 1] = row
    end
  end
  return rows
end

---@param name string
---@param step LDT_RunStep|nil
---@return string
local function withCriteriaCount(name, step)
  local criteria = step and step.criteria
  if not criteria or #criteria == 0 then
    return name
  end
  local done = 0
  for index = 1, #criteria do
    if criteria[index].completed then
      done = done + 1
    end
  end
  return format("%s (%d/%d)", name, done, #criteria)
end

---@return boolean
local function showObjectiveCounts()
  local timer = Data.db and Data.db.global.timer
  return not timer or timer.showObjectiveCounts ~= false
end

---@param name string
---@param step LDT_RunStep|nil
---@param catalogStep LDT_CatalogStep|nil
---@return string
local function stageName(name, step, catalogStep)
  if not showObjectiveCounts() then
    return name
  end
  if step and step.criteria and #step.criteria > 0 then
    return withCriteriaCount(name, step)
  end
  local storedCriteria = catalogStep and catalogStep.criteria
  local total = storedCriteria and #storedCriteria or 0
  if total > 0 then
    return format("%s (0/%d)", name, total)
  end
  return name
end

---@param run LDT_Run
---@param scenario LDT_Scenario
---@param elapsed number
function Data:NoteScenario(run, scenario, elapsed)
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
  run.scenarioID = scenarioID
  local stage = plainNumber(info.currentStage)
  local numStages = plainNumber(info.numStages)
  local scenarios = self.db.global.scenarios
  local record = scenarios[scenarioID]
  if not record then
    ---@type LDT_CatalogScenario
    record = {
      scenarioID = scenarioID,
      steps = {},
    }
    scenarios[scenarioID] = record
  end
  local scenarioName = plainString(info.name)
  if scenarioName then
    record.name = scenarioName
  end
  if numStages then
    record.numStages = numStages
  end
  local instance = run.instance
  if instance then
    if instance.mapID then
      record.mapID = instance.mapID
    end
    if instance.instanceID then
      record.instanceID = instance.instanceID
    end
    if instance.difficultyID then
      record.difficultyID = instance.difficultyID
    end
  end
  local catalogStep
  for index = 1, #record.steps do
    if record.steps[index].stepID == stepID then
      catalogStep = record.steps[index]
      break
    end
  end
  if not catalogStep then
    ---@type LDT_CatalogStep
    catalogStep = {
      stepID = stepID,
      criteria = {},
    }
    record.steps[#record.steps + 1] = catalogStep
  end
  if stage then
    catalogStep.stage = stage
  end
  local title = plainString(step.title)
  if title then
    catalogStep.title = title
  end
  catalogStep.criteria = catalogCriteria(scenario.criteria)
  if run.steps == nil then
    run.steps = {}
  end
  local runStep
  for index = 1, #run.steps do
    if run.steps[index].stepID == stepID then
      runStep = run.steps[index]
      break
    end
  end
  if not runStep then
    ---@type LDT_RunStep
    runStep = {
      stepID = stepID,
      stage = stage,
      enteredElapsed = elapsed,
      criteria = {},
    }
    run.steps[#run.steps + 1] = runStep
  elseif stage and not runStep.stage then
    runStep.stage = stage
  end
  runStep.criteria = runCriteria(scenario.criteria)
  self:SnapshotBest(run)
end

---@param run LDT_Run
---@param stepID number
---@param elapsed number
function Data:FinishStep(run, stepID, elapsed)
  if run.steps == nil then
    return
  end
  for index = 1, #run.steps do
    local runStep = run.steps[index]
    if runStep.stepID == stepID and runStep.completedElapsed == nil then
      runStep.completedElapsed = elapsed
      break
    end
  end
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
  if run.best then
    return
  end
  if not run.scenarioID or not Helpers.RunTier(run) then
    return
  end
  local source = Helpers.BestRun(run)
  ---@type LDT_BestStep[]
  local steps = {}
  ---@type LDT_BestChamber[]
  local chambers = {}
  ---@type LDT_RunBest
  local best = {
    steps = steps,
    chambers = chambers,
  }
  if source and source.endedAt then
    best.id = source.id
    best.startedAt = source.startedAt
    best.endedAt = source.endedAt
    local sourceSteps = source.steps
    if sourceSteps then
      for index = 1, #sourceSteps do
        local step = sourceSteps[index]
        if step.completedElapsed then
          ---@type LDT_BestStep
          local row = {
            stepID = step.stepID,
            stage = step.stage,
            completedElapsed = step.completedElapsed,
          }
          steps[#steps + 1] = row
        end
      end
    end
    local sourceChambers = source.chambers
    if sourceChambers then
      for index = 1, #sourceChambers do
        local chamber = sourceChambers[index]
        if chamber.name and chamber.name ~= "" and chamber.completedElapsed then
          ---@type LDT_BestChamber
          local row = {
            name = chamber.name,
            completedElapsed = chamber.completedElapsed,
          }
          chambers[#chambers + 1] = row
        end
      end
    end
  end
  run.best = best
end

---@param run LDT_Run
---@param stepID number|nil
---@param stage number|nil
---@return number|nil
local function storedBestTime(run, stepID, stage)
  local best = run.best
  if not best then
    return nil
  end
  local steps = best.steps
  for index = 1, #steps do
    local step = steps[index]
    if stepID and step.stepID == stepID then
      return step.completedElapsed
    end
  end
  if not stage then
    return nil
  end
  for index = 1, #steps do
    local step = steps[index]
    if step.stage == stage then
      return step.completedElapsed
    end
  end
  return nil
end

---@param run LDT_Run
---@return LDT_StepRow[]
function Data:StepRows(run)
  ---@type LDT_StepRow[]
  local rows = {}
  local steps = run.steps
  if not run.scenarioID or not steps then
    return rows
  end
  ---@type table<number, LDT_RunStep>
  local byStage = {}
  local maxStage = 0
  for index = 1, #steps do
    local step = steps[index]
    local stage = step.stage
    if stage and stage > 0 then
      local finished = Helpers.Duration(run)
      local entered = step.enteredElapsed
      local afterFinish = finished and entered and entered > finished and not run.labyrinth
      if not afterFinish then
        byStage[stage] = step
        if stage > maxStage then
          maxStage = stage
        end
      end
    end
  end
  local info = run.scenario and run.scenario.info
  local numStages = info and plainNumber(info.numStages)
  if numStages and numStages > maxStage then
    maxStage = numStages
  end
  local watchID = run.watch and run.watch.stepID
  local catalog
  if run.scenarioID and self.db then
    catalog = self.db.global.scenarios[run.scenarioID]
  end
  ---@type table<number, string>
  local titleByStep = {}
  local useTitles = false
  if catalog then
    ---@type table<string, boolean>
    local seenTitle = {}
    local distinct = 0
    for index = 1, #catalog.steps do
      local catalogStep = catalog.steps[index]
      local title = catalogStep.title
      if title and title ~= "" then
        titleByStep[catalogStep.stepID] = title
        if not seenTitle[title] then
          seenTitle[title] = true
          distinct = distinct + 1
        end
      end
    end
    useTitles = distinct >= 2
  end
  for stage = 1, maxStage do
    local step = byStage[stage]
    local name = format("Stage %d", stage)
    if useTitles then
      local title
      if step then
        title = titleByStep[step.stepID]
      elseif catalog then
        for index = 1, #catalog.steps do
          local catalogStep = catalog.steps[index]
          if catalogStep.stage == stage then
            title = catalogStep.title
            break
          end
        end
      end
      if title and title ~= "" then
        name = title
      end
    end
    local stepID = step and step.stepID
    local catalogStep
    if catalog then
      for index = 1, #catalog.steps do
        local catalogRow = catalog.steps[index]
        local sameStep = stepID and catalogRow.stepID == stepID
        if sameStep or (not catalogStep and catalogRow.stage == stage) then
          catalogStep = catalogRow
          if not stepID then
            stepID = catalogRow.stepID
          end
          if sameStep then
            break
          end
        end
      end
    end
    local best = storedBestTime(run, stepID, stage)
    local countedName = stageName(name, step, catalogStep)
    if step then
      local elapsed = step.completedElapsed
      local current = step.stepID == watchID and elapsed == nil and not run.endedAt
      rows[#rows + 1] = {
        name = countedName,
        elapsed = elapsed,
        best = best,
        current = current,
      }
    else
      rows[#rows + 1] = {
        name = countedName,
        elapsed = nil,
        best = best,
        current = false,
      }
    end
  end
  return rows
end

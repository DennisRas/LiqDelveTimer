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
      showObjectiveCounts = false,
      autoOpenChambers = true,
      aheadColor = { r = 0.35, g = 0.9, b = 0.5, a = 1 },
      behindColor = { r = 1, g = 0.4, b = 0.4, a = 1 },
      backgroundColor = { r = 0, g = 0, b = 0, a = 0.9 },
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
    rewards = {},
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

local CHAMBER_SPLIT_LIMIT = 9

---@param role LDT_ScenarioRoleId|nil
---@param chambers number
---@return boolean, number
local function keepSplit(role, chambers)
  if role == Constants.scenarioRole.Hub or role == Constants.scenarioRole.Reward then
    return false, chambers
  end
  if role == Constants.scenarioRole.Chamber then
    chambers = chambers + 1
    if chambers > CHAMBER_SPLIT_LIMIT then
      return false, chambers
    end
  end
  return true, chambers
end

---@param scenarioID number
---@param storedRole LDT_ScenarioRoleId|nil
---@return LDT_ScenarioRoleId|nil
local function resolvedRole(scenarioID, storedRole)
  local known = TableGet(Data.scenarios, "scenarioID", scenarioID)
  local catalogRole = known and known.role
  if catalogRole == Constants.scenarioRole.Boss then
    return catalogRole
  end
  if storedRole then
    return storedRole
  end
  return catalogRole
end

---@param scenario LDT_RunScenario
---@param pathCriteriaID number
---@return boolean
local function pathCriteriaOpen(scenario, pathCriteriaID)
  local steps = scenario.steps
  for stepIndex = 1, #steps do
    local criteria = steps[stepIndex].criteria
    if criteria then
      for index = 1, #criteria do
        local row = criteria[index]
        if row.criteriaID == pathCriteriaID and not row.completed then
          return true
        end
      end
    end
  end
  return false
end

---@param run LDT_Run
---@return string|nil
function Data:ClockPrompt(run)
  if Helpers.RunMode(run) ~= Constants.runMode.Lab then
    return nil
  end
  local delve = Data:DelveForInstance(run.instance)
  local pathCriteriaID = delve and delve.pathCriteriaID
  if not pathCriteriaID then
    return nil
  end
  local openScenario
  for index = #run.scenarios, 1, -1 do
    local scenario = run.scenarios[index]
    if not scenario.completedElapsed then
      openScenario = scenario
      break
    end
  end
  if not openScenario then
    return nil
  end
  if resolvedRole(openScenario.scenarioID, openScenario.role) ~= Constants.scenarioRole.Hub then
    return nil
  end
  if not pathCriteriaOpen(openScenario, pathCriteriaID) then
    return nil
  end
  return "Pick the next chamber"
end

---@param scenarioID number
---@return string|nil
local function scenarioName(scenarioID)
  local known = TableGet(Data.scenarios, "scenarioID", scenarioID)
  if known and known.name and known.name ~= "" then
    return known.name
  end
  local saved = Data.db and Data.db.global.scenarios[scenarioID]
  if saved and saved.name and saved.name ~= "" then
    return saved.name
  end
end

---@param stepID number
---@return string|nil
local function stepTitle(stepID)
  local known = TableGet(Data.steps, "stepID", stepID)
  if known and known.title and known.title ~= "" then
    return known.title
  end
  local saved = Data.db and Data.db.global.steps[stepID]
  if saved and saved.title and saved.title ~= "" then
    return saved.title
  end
end

---@param list LDT_Criteria[]
---@param criteriaID number
---@param slot number
---@return LDT_Criteria|nil
local function criterionMatch(list, criteriaID, slot)
  if criteriaID ~= 0 then
    for index = 1, #list do
      local row = list[index]
      if row.criteriaID == criteriaID then
        return row
      end
    end
    return nil
  end
  local row = list[slot]
  if row and row.criteriaID == 0 then
    return row
  end
  return nil
end

---@param description string|nil
---@param totalQuantity number|nil
---@param weighted boolean
---@param match LDT_Criteria|nil
---@return string|nil, number|nil, boolean
local function applyCriterion(description, totalQuantity, weighted, match)
  if not match then
    return description, totalQuantity, weighted
  end
  if not description then
    description = match.description
  end
  if totalQuantity == nil then
    totalQuantity = match.totalQuantity
  end
  if match.isWeightedProgress ~= nil then
    weighted = match.isWeightedProgress
  end
  return description, totalQuantity, weighted
end

---@param stepID number
---@param criteriaID number
---@param slot number
---@return string|nil, number|nil, boolean
local function criterionFacts(stepID, criteriaID, slot)
  local description
  local totalQuantity
  local weighted = false
  local known = TableGet(Data.steps, "stepID", stepID)
  local knownCriteria = known and known.criteria
  if knownCriteria then
    description, totalQuantity, weighted = applyCriterion(description, totalQuantity, weighted, criterionMatch(knownCriteria, criteriaID, slot))
  end
  if Data.db then
    local learned = Data.db.global.steps[stepID]
    local storedCriteria = learned and learned.criteria
    if storedCriteria then
      description, totalQuantity, weighted = applyCriterion(description, totalQuantity, weighted, criterionMatch(storedCriteria, criteriaID, slot))
    end
  end
  return description, totalQuantity, weighted
end

---@param stepID number
---@param criteria LDT_RunCriteria
---@param slot number
---@return string|nil
local function objectiveLabel(stepID, criteria, slot)
  local description, totalQuantity, weighted = criterionFacts(stepID, criteria.criteriaID, slot)
  description = description or ""
  local progress
  if weighted then
    if criteria.quantity ~= nil then
      progress = format("%d%%", criteria.quantity)
    end
  elseif criteria.quantity ~= nil and totalQuantity ~= nil and totalQuantity > 0 then
    progress = format("%d/%d", criteria.quantity, totalQuantity)
  end
  if progress and progress ~= "" then
    if description ~= "" then
      return format("(%s) %s", progress, description)
    end
    return format("(%s)", progress)
  end
  if description == "" then
    return nil
  end
  return description
end

---@generic T
---@param list T[]|nil
---@return number|nil
local function listCount(list)
  if not list or #list < 1 then
    return nil
  end
  return #list
end

---@param criteria LDT_RunCriteria[]|nil
---@return number
---@return number|nil
local function criteriaProgress(criteria)
  if not criteria or #criteria < 1 then
    return 0, nil
  end
  local done = 0
  for index = 1, #criteria do
    if criteria[index].completed then
      done = done + 1
    end
  end
  return done, #criteria
end

---@param step LDT_RunStep
---@return LDT_TimerLine[]|nil
local function objectiveLines(step)
  local criteria = step.criteria
  if not criteria or #criteria == 0 then
    return nil
  end
  ---@type LDT_TimerLine[]
  local lines = {}
  for index = 1, #criteria do
    local criteriaRow = criteria[index]
    local label = objectiveLabel(step.stepID, criteriaRow, index)
    if label then
      ---@type LDT_TimerLine
      local line = { text = label, completed = criteriaRow.completed == true }
      lines[#lines + 1] = line
    end
  end
  if #lines == 0 then
    return nil
  end
  return lines
end

---@param scenarioID number
---@return LDT_ScenarioStep[]
local function catalogSteps(scenarioID)
  ---@type LDT_ScenarioStep[]
  local list = {}
  for index = 1, #Data.steps do
    local step = Data.steps[index]
    if step.scenarioID == scenarioID then
      list[#list + 1] = step
    end
  end
  table.sort(list, function(first, second)
    local firstOrder = first.order or 0
    local secondOrder = second.order or 0
    if firstOrder == secondOrder then
      return first.stepID < second.stepID
    end
    return firstOrder < secondOrder
  end)
  return list
end

---@param scenarioID number
---@return number
local function learnedStepCount(scenarioID)
  if not Data.db then
    return 0
  end
  local count = 0
  TableForEach(Data.db.global.steps, function(step)
    if step.scenarioID == scenarioID then
      count = count + 1
    end
  end)
  return count
end

---@param scenarioID number
---@param visited number
---@param bestSteps LDT_BestStep[]|nil
---@return number
local function expectedStepCount(scenarioID, visited, bestSteps)
  local count = visited
  local bestCount = bestSteps and #bestSteps or 0
  if bestCount > count then
    count = bestCount
  end
  local catalog = #catalogSteps(scenarioID)
  if catalog > count then
    count = catalog
  end
  local learned = learnedStepCount(scenarioID)
  if learned > count then
    count = learned
  end
  return count
end

---@param name string
---@param elapsed number|nil
---@param bestElapsed number|nil
---@return LDT_TimerNode
local function splitRow(name, elapsed, bestElapsed)
  ---@type LDT_TimerNode
  local row = {
    name = name,
    elapsed = elapsed,
    best = bestElapsed,
    current = false,
  }
  return row
end

---@param run LDT_Run
---@return LDT_RunScenario[]
local function splitScenarios(run)
  ---@type LDT_RunScenario[]
  local list = {}
  local chambers = 0
  for index = 1, #run.scenarios do
    local scenario = run.scenarios[index]
    local keep
    keep, chambers = keepSplit(resolvedRole(scenario.scenarioID, scenario.role), chambers)
    if keep then
      list[#list + 1] = scenario
    end
  end
  return list
end

---@param run LDT_Run
---@return LDT_BestScenario[]
local function splitBest(run)
  ---@type LDT_BestScenario[]
  local list = {}
  local best = run.best
  if not best then
    return list
  end
  local chambers = 0
  for index = 1, #best.scenarios do
    local scenario = best.scenarios[index]
    local keep
    keep, chambers = keepSplit(resolvedRole(scenario.scenarioID, nil), chambers)
    if keep then
      list[#list + 1] = scenario
    end
  end
  return list
end

---@param scenario LDT_RunScenario
---@param role LDT_ScenarioRoleId|nil
---@param chamberNumber number
---@return string
local function scenarioSplitName(scenario, role, chamberNumber)
  if role == Constants.scenarioRole.Chamber then
    return format("Chamber %d", chamberNumber)
  end
  if role == Constants.scenarioRole.Boss then
    return "Boss"
  end
  local name = scenarioName(scenario.scenarioID)
  if name then
    return name
  end
  local first = scenario.steps[1]
  if first then
    local title = stepTitle(first.stepID)
    if title then
      return title
    end
  end
  return format("Stage %d", scenario.index)
end

---@param row LDT_TimerNode
---@param done number|nil
---@param total number|nil
local function setChildProgress(row, done, total)
  if total == nil or total < 1 then
    return
  end
  row.done = done or 0
  row.total = total
end

---@param scenarioID number
---@param steps LDT_RunStep[]|nil
---@param bestSteps LDT_BestStep[]|nil
---@return number
---@return number|nil
local function stageProgress(scenarioID, steps, bestSteps)
  local visited = 0
  if steps then
    visited = #steps
  end
  local total = expectedStepCount(scenarioID, visited, bestSteps)
  if total < 1 then
    return 0, nil
  end
  local done = 0
  if steps then
    for index = 1, #steps do
      if steps[index].completedElapsed then
        done = done + 1
      end
    end
  end
  return done, total
end

---@param scenarioID number
---@param steps LDT_RunStep[]
---@param bestSteps LDT_BestStep[]|nil
---@return LDT_TimerNode[]
local function stageRows(scenarioID, steps, bestSteps)
  local expected = expectedStepCount(scenarioID, #steps, bestSteps)
  local catalog = catalogSteps(scenarioID)
  ---@type LDT_TimerNode[]
  local rows = {}
  for stepIndex = 1, expected do
    local step = steps[stepIndex]
    local bestStep = bestSteps and bestSteps[stepIndex]
    local name = format("Stage %d", stepIndex)
    local catalogStep = catalog[stepIndex]
    local elapsed
    if step then
      elapsed = step.completedElapsed
    end
    local bestElapsed
    if bestStep then
      bestElapsed = bestStep.completedElapsed
    end
    local row = splitRow(name, elapsed, bestElapsed)
    local done
    local total
    if step then
      done, total = criteriaProgress(step.criteria)
    end
    if total == nil and catalogStep then
      total = listCount(catalogStep.criteria)
      done = 0
    end
    setChildProgress(row, done, total)
    rows[#rows + 1] = row
  end
  local openIndex
  for stepIndex = #steps, 1, -1 do
    if not steps[stepIndex].completedElapsed then
      openIndex = stepIndex
      break
    end
  end
  if openIndex and rows[openIndex] then
    rows[openIndex].current = true
    local lines = objectiveLines(steps[openIndex])
    if lines then
      rows[openIndex].lines = lines
    end
  end
  return rows
end

---@param run LDT_Run
---@return LDT_TimerNode[]
local function labSplitRows(run)
  local scenarios = splitScenarios(run)
  ---@type LDT_RunScenario[]
  local chambers = {}
  ---@type LDT_RunScenario|nil
  local boss
  for index = 1, #scenarios do
    local scenario = scenarios[index]
    local role = resolvedRole(scenario.scenarioID, scenario.role)
    if role == Constants.scenarioRole.Boss then
      boss = scenario
    elseif #chambers < CHAMBER_SPLIT_LIMIT then
      chambers[#chambers + 1] = scenario
    end
  end
  local bestScenarios = splitBest(run)
  ---@type LDT_BestScenario[]
  local bestChambers = {}
  ---@type LDT_BestScenario|nil
  local bestBoss
  for index = 1, #bestScenarios do
    local scenario = bestScenarios[index]
    local role = resolvedRole(scenario.scenarioID, nil)
    if role == Constants.scenarioRole.Boss then
      bestBoss = scenario
    elseif #bestChambers < CHAMBER_SPLIT_LIMIT then
      bestChambers[#bestChambers + 1] = scenario
    end
  end
  ---@type LDT_TimerNode[]
  local rows = {}
  local openChamber
  for chamberIndex = 1, CHAMBER_SPLIT_LIMIT do
    local scenario = chambers[chamberIndex]
    local bestScenario = bestChambers[chamberIndex]
    local elapsed
    if scenario then
      elapsed = scenario.completedElapsed
    end
    local bestElapsed
    if bestScenario then
      bestElapsed = bestScenario.completedElapsed
    end
    local row = splitRow(format("Chamber %d", chamberIndex), elapsed, bestElapsed)
    if scenario then
      local done, total = stageProgress(scenario.scenarioID, scenario.steps, bestScenario and bestScenario.steps)
      setChildProgress(row, done, total)
    end
    rows[#rows + 1] = row
    if scenario and not scenario.completedElapsed then
      openChamber = chamberIndex
    end
  end
  if openChamber then
    local scenario = chambers[openChamber]
    rows[openChamber].current = true
    local bestScenario = bestChambers[openChamber]
    local nested = stageRows(scenario.scenarioID, scenario.steps, bestScenario and bestScenario.steps)
    if #nested > 0 then
      rows[openChamber].nodes = nested
    end
  end
  local bossElapsed
  if boss then
    bossElapsed = boss.completedElapsed
  end
  local bossBest
  if bestBoss then
    bossBest = bestBoss.completedElapsed
  end
  local bossRow = splitRow("Boss", bossElapsed, bossBest)
  if boss then
    local done, total = stageProgress(boss.scenarioID, boss.steps, bestBoss and bestBoss.steps)
    setChildProgress(bossRow, done, total)
  end
  if boss and not boss.completedElapsed then
    if openChamber then
      rows[openChamber].current = false
      rows[openChamber].nodes = nil
    end
    bossRow.current = true
    local nested = stageRows(boss.scenarioID, boss.steps, bestBoss and bestBoss.steps)
    if #nested > 0 then
      bossRow.nodes = nested
    end
  end
  rows[#rows + 1] = bossRow
  return rows
end

---@param run LDT_Run
---@return LDT_TimerNode[]
function Data:StepRows(run)
  if Helpers.RunMode(run) == Constants.runMode.Lab then
    return labSplitRows(run)
  end
  local scenarios = splitScenarios(run)
  local bestScenarios = splitBest(run)
  local expected = #scenarios
  if #bestScenarios > expected then
    expected = #bestScenarios
  end
  if expected == 0 then
    ---@type LDT_TimerNode[]
    local empty = {}
    return empty
  end
  if expected == 1 then
    local scenario = scenarios[1]
    local bestScenario = bestScenarios[1]
    local scenarioID = scenario and scenario.scenarioID or bestScenario.scenarioID
    local steps = scenario and scenario.steps or {}
    local bestSteps = bestScenario and bestScenario.steps
    return stageRows(scenarioID, steps, bestSteps)
  end
  ---@type LDT_TimerNode[]
  local rows = {}
  local openIndex
  for index = 1, expected do
    local scenario = scenarios[index]
    local bestScenario = bestScenarios[index]
    local name
    local elapsed
    if scenario then
      local role = resolvedRole(scenario.scenarioID, scenario.role)
      local chamberNumber = 0
      if role == Constants.scenarioRole.Chamber then
        chamberNumber = index
      end
      name = scenarioSplitName(scenario, role, chamberNumber)
      elapsed = scenario.completedElapsed
      if not scenario.completedElapsed then
        openIndex = index
      end
    elseif bestScenario then
      local role = resolvedRole(bestScenario.scenarioID, nil)
      name = scenarioSplitName({
        index = index,
        scenarioID = bestScenario.scenarioID,
        enteredElapsed = bestScenario.enteredElapsed,
        steps = {},
      }, role, index)
    else
      name = format("Stage %d", index)
    end
    local bestElapsed
    if bestScenario then
      bestElapsed = bestScenario.completedElapsed
    end
    local row = splitRow(name, elapsed, bestElapsed)
    local scenarioID = scenario and scenario.scenarioID or (bestScenario and bestScenario.scenarioID)
    if scenarioID then
      local done, total = stageProgress(scenarioID, scenario and scenario.steps, bestScenario and bestScenario.steps)
      setChildProgress(row, done, total)
    end
    rows[#rows + 1] = row
  end
  if openIndex then
    local scenario = scenarios[openIndex]
    rows[openIndex].current = true
    local bestScenario = bestScenarios[openIndex]
    local nested = stageRows(scenario.scenarioID, scenario.steps, bestScenario and bestScenario.steps)
    if #nested > 0 then
      rows[openIndex].nodes = nested
    end
  end
  return rows
end

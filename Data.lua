---@class LDT_Addon
local addon = select(2, ...)

---@class LDT_Data
local Data = {}
addon.Data = Data

local LibAceDB = addon.libs.AceDB
local LiqUI = addon.libs.LiqUI
local Constants = addon.Constants
local Helpers = addon.Helpers

Data.dbVersion = 1

---@type LDT_Character
Data.defaultCharacter = {
  GUID = "",
  activeRecordID = nil,
  records = {},
}

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
        Report = {},
        Records = {},
        RecordDetail = {},
      },
      tables = {
        Records = { hiddenColumns = {} },
      },
    },
    report = {
      collapsed = {
        run = false,
        timers = false,
        companion = false,
        boons = false,
        gains = false,
        renown = false,
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
      fontSize = 12,
      replaceTracker = true,
      aheadColor = { r = 0.35, g = 0.9, b = 0.5, a = 1 },
      behindColor = { r = 1, g = 0.4, b = 0.4, a = 1 },
      backgroundColor = { r = 0, g = 0, b = 0, a = 0.5 },
      borderColor = { r = 1, g = 1, b = 1, a = 0 },
    },
    routes = {},
    characters = {},
  },
}

function Data:Initialize()
  self.db = LibAceDB:New("LiqDelveTimerDB", self.defaultDB, true)
end

function Data:MigrateDB()
  ---@diagnostic disable: undefined-field, inject-field
  local stored = self.db.global.dbVersion
  if stored == Data.dbVersion then
    return
  end
  self.db.global.dbVersion = Data.dbVersion
  ---@diagnostic enable: undefined-field, inject-field
end

---@return LDT_Character|nil
function Data:GetCharacter()
  if not self.db then
    return nil
  end
  local guid = UnitGUID("player")
  if not guid then
    return nil
  end
  local characters = self.db.global.characters
  local character = characters[guid]
  if character then
    return character
  end
  character = LiqUI.Utils.TableCopy(self.defaultCharacter)
  character.GUID = guid
  characters[guid] = character
  return character
end

---@return LDT_Record|nil
function Data:GetActiveRecord()
  local character = self:GetCharacter()
  if not character or not character.activeRecordID then
    return nil
  end
  local records = character.records
  for index = #records, 1, -1 do
    local record = records[index]
    if record.id == character.activeRecordID then
      return record
    end
  end
  return nil
end

---@return LDT_Record|nil
function Data:GetLatestRecord()
  local character = self:GetCharacter()
  if not character then
    return nil
  end
  local records = character.records
  return records[#records]
end

---@return LDT_Record|nil
function Data:CreateRecord()
  local character = self:GetCharacter()
  if not character then
    return nil
  end
  local startedAt = GetServerTime()
  local money = GetMoney()
  ---@type LDT_Record
  local record = {
    id = format("%d-%d", startedAt, #character.records + 1),
    result = Constants.runResult.Active,
    labyrinth = false,
    startedAt = startedAt,
    sessionStart = GetTime(),
    sessionOffset = 0,
    sawDelveComplete = false,
    deaths = 0,
    gold = {
      start = money,
      last = money,
      gained = 0,
      gains = {},
    },
    currencies = {},
    renownStart = {},
    renowns = {},
    boons = {},
    loot = {},
    vault = {
      credits = 0,
      activities = {},
    },
    chambers = {},
    encounters = {},
    log = {},
    splits = {},
    watch = {
      criteria = {},
      delveComplete = false,
      scenarioComplete = false,
    },
  }
  character.records[#character.records + 1] = record
  character.activeRecordID = record.id
  return record
end

---@param record LDT_Record
---@param stepName string
---@return LDT_Route|nil
function Data:RouteForStep(record, stepName)
  if record.labyrinth or not self.db then
    return nil
  end
  local routes = self.db.global.routes
  if record.routeID and routes[record.routeID] then
    return routes[record.routeID]
  end
  local mapID = record.instance and record.instance.mapID
  local match
  LiqUI.Utils.TableForEach(routes, function(route)
    if match or not mapID or route.mapID ~= mapID then
      return
    end
    for index = 1, #route.steps do
      if route.steps[index] == stepName then
        match = route
        return
      end
    end
  end)
  if match then
    record.routeID = match.id
    return match
  end
  local id = format("route-%s-%d", tostring(mapID or 0), GetServerTime())
  ---@type LDT_Route
  local route = {
    id = id,
    mapID = mapID,
    name = record.instance and record.instance.name,
    steps = {},
  }
  routes[id] = route
  record.routeID = id
  return route
end

---@param record LDT_Record
---@param stepName string
function Data:NoteShownStep(record, stepName)
  if record.labyrinth or stepName == "" then
    return
  end
  local route = self:RouteForStep(record, stepName)
  if not route then
    return
  end
  local steps = route.steps
  local shownIndex
  for index = 1, #steps do
    if steps[index] == stepName then
      shownIndex = index
      break
    end
  end
  if not shownIndex then
    local insertAt = #steps + 1
    local previous = record.watch.routeStep
    if previous then
      for index = 1, #steps do
        if steps[index] == previous then
          insertAt = index + 1
          break
        end
      end
    end
    table.insert(steps, insertAt, stepName)
  end
  record.watch.routeStep = stepName
end

---@param record LDT_Record
---@param stepName string|nil
---@param elapsed number
function Data:StampStep(record, stepName, elapsed)
  if record.labyrinth or not stepName or stepName == "" then
    return
  end
  if not record.splits then
    record.splits = {}
  end
  if record.splits[stepName] == nil then
    record.splits[stepName] = elapsed
  end
end

---@param routeID string|nil
---@param tier number|nil
---@param stepName string
---@return number|nil
function Data:BestSplitFor(routeID, tier, stepName)
  local character = self:GetCharacter()
  if not character or not routeID or not tier then
    return nil
  end
  local best
  LiqUI.Utils.TableForEach(character.records, function(candidate)
    if candidate.result ~= Constants.runResult.Complete then
      return
    end
    if candidate.routeID ~= routeID or Helpers.RunTier(candidate) ~= tier then
      return
    end
    local time = candidate.splits and candidate.splits[stepName]
    if time and (not best or time < best) then
      best = time
    end
  end)
  return best
end

---@param name string|nil
---@param mapID number|nil
---@param tier number|nil
---@return LDT_Route|nil, number|nil
function Data:PreviewRoute(name, mapID, tier)
  local character = self:GetCharacter()
  local routes = self.db and self.db.global.routes
  if not character or not routes or not tier then
    return nil, nil
  end
  local bestRoute
  local bestTime
  LiqUI.Utils.TableForEach(character.records, function(candidate)
    if candidate.result ~= Constants.runResult.Complete or Helpers.RunTier(candidate) ~= tier then
      return
    end
    local instance = candidate.instance
    local same = false
    if mapID and instance and instance.mapID == mapID then
      same = true
    elseif name and name ~= "" and instance and instance.name == name then
      same = true
    end
    if not same then
      return
    end
    local time = Helpers.CompletionTime(candidate)
    if not time or (bestTime and time >= bestTime) then
      return
    end
    bestTime = time
    if candidate.routeID then
      bestRoute = routes[candidate.routeID]
    end
  end)
  return bestRoute, bestTime
end

---@param record LDT_Record
---@param stepName string
---@return number|nil
function Data:BestSplit(record, stepName)
  return self:BestSplitFor(record.routeID, Helpers.RunTier(record), stepName)
end

---@class LDT_Addon
local addon = select(2, ...)

---@class LDT_Data
local Data = {}
addon.Data = Data

local LibAceDB = addon.libs.AceDB
local LiqUI = addon.libs.LiqUI
local Constants = addon.Constants

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
        Records = {},
        RecordDetail = {},
      },
      tables = {
        Records = { hiddenColumns = {} },
      },
    },
    widget = {
      shown = false,
      minimized = false,
      point = "TOPRIGHT",
      relativePoint = "TOPRIGHT",
      x = -24,
      y = -180,
      spacing = "default",
      sectionGap = 0,
      theme = "flat",
      backgroundColor = { r = 0, g = 0, b = 0, a = 0.55 },
      headerBackgroundColor = { r = 0, g = 0, b = 0, a = 0.35 },
      headerFontColor = { r = 1, g = 0.82, b = 0, a = 1 },
      panelHeaderBackgroundColor = { r = 1, g = 1, b = 1, a = 0.06 },
      panelHeaderFontColor = { r = 1, g = 0.82, b = 0, a = 1 },
      sectionRuleColor = { r = 1, g = 0.82, b = 0, a = 0 },
      sectionBackgroundColor = { r = 0, g = 0, b = 0, a = 0 },
      bodyFontColor = { r = 0.9, g = 0.9, b = 0.9, a = 1 },
      border = {
        enabled = false,
        color = { r = 1, g = 1, b = 1, a = 0.35 },
      },
      sections = {
        run = { enabled = true, collapsed = false },
        timers = { enabled = true, collapsed = false },
        companion = { enabled = true, collapsed = false },
        boons = { enabled = true, collapsed = false },
        gains = { enabled = true, collapsed = false },
        renown = { enabled = true, collapsed = false },
      },
    },
    logs = {
      lines = {},
      autoScroll = true,
      autoShow = false,
    },
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

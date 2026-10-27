---@class LDT_Addon
local addon = select(2, ...)

---@class LDT_Constants
local Constants = {}
addon.Constants = Constants

Constants.prefix = format("<%s> ", addon.name)

---@enum LDT_RunModeId
Constants.runMode = {
  Delve = "delve",
  Lab = "lab",
}

---@enum LDT_RunResultId
Constants.runResult = {
  Active = "active",
  PersonalBest = "personalBest",
  Completed = "completed",
  Abandoned = "abandoned",
}

---@enum LDT_ScenarioRoleId
Constants.scenarioRole = {
  Stages = "stages",
  Reward = "reward",
  Hub = "hub",
  Chamber = "chamber",
  Boss = "boss",
}

---@enum LDT_DateLengthId
Constants.dateLength = {
  Full = "full",
  Medium = "medium",
}

---@enum LDT_RewardTypeId
Constants.rewardType = {
  Gold = "gold",
  Currency = "currency",
  Renown = "renown",
  Loot = "loot",
  Level = "level",
  Experience = "xp",
  CompanionLevel = "companionLevel",
  CompanionExperience = "companionXp",
}

Constants.boonStatColors = {
  { key = "ITEM_MOD_STRENGTH_SHORT", r = 1, g = 0.5, b = 0.25 },
  { key = "STAT_STRENGTH", r = 1, g = 0.5, b = 0.25 },
  { key = "ITEM_MOD_AGILITY_SHORT", r = 0.55, g = 1, b = 0.45 },
  { key = "STAT_AGILITY", r = 0.55, g = 1, b = 0.45 },
  { key = "ITEM_MOD_INTELLECT_SHORT", r = 0.25, g = 0.78, b = 1 },
  { key = "STAT_INTELLECT", r = 0.25, g = 0.78, b = 1 },
  { key = "ITEM_MOD_CRIT_RATING_SHORT", r = 0.878, g = 0.11, b = 0.11 },
  { key = "STAT_CRITICAL_STRIKE", r = 0.878, g = 0.11, b = 0.11 },
  { key = "ITEM_MOD_HASTE_RATING_SHORT", r = 1, g = 0.92, b = 0.15 },
  { key = "STAT_HASTE", r = 1, g = 0.92, b = 0.15 },
  { key = "ITEM_MOD_MASTERY_RATING_SHORT", r = 0.72, g = 0.5, b = 1 },
  { key = "STAT_MASTERY", r = 0.72, g = 0.5, b = 1 },
  { key = "ITEM_MOD_VERSATILITY", r = 0.1, g = 1, b = 0.15 },
  { key = "STAT_VERSATILITY", r = 0.1, g = 1, b = 0.15 },
  { key = "ITEM_MOD_STAMINA_SHORT", r = 0.9, g = 0.25, b = 0.25 },
  { key = "STAT_STAMINA", r = 0.9, g = 0.25, b = 0.25 },
  { key = "STAT_HEALTH", r = 0.9, g = 0.25, b = 0.25 },
  { key = "ITEM_MOD_HEALTH_SHORT", r = 0.9, g = 0.25, b = 0.25 },
  { key = "STAT_MOVEMENT_SPEED", r = 0.3, g = 0.85, b = 1 },
  { key = "MOVEMENT_SPEED", r = 0.3, g = 0.85, b = 1 },
  { key = "STAT_SPEED", r = 0.3, g = 0.85, b = 1 },
  { key = "ITEM_MOD_CR_SPEED_SHORT", r = 0.3, g = 0.85, b = 1 },
  { key = "STAT_ARMOR", r = 0.65, g = 0.75, b = 0.9 },
  { key = "ITEM_MOD_ARMOR_SHORT", r = 0.65, g = 0.75, b = 0.9 },
}

Constants.media = {
  Icon = "Interface/Icons/INV_Misc_PocketWatch_01",
}

---@class LDT_Addon
local addon = select(2, ...)

---@class LDT_Constants
local Constants = {}
addon.Constants = Constants

Constants.prefix = format("<%s> ", addon.name)
Constants.labyrinthMapID = 2647

---@enum LDT_RunResultId
Constants.runResult = {
  Active = "active",
  Complete = "complete",
  Left = "left",
}

---@enum LDT_LogKindId
Constants.logKind = {
  Start = "start",
  Reload = "reload",
  Zone = "zone",
  Step = "step",
  Objective = "objective",
  ObjectiveDone = "objectiveDone",
  ObjectiveFailed = "objectiveFailed",
  Chamber = "chamber",
  Scenario = "scenario",
  Vault = "vault",
  Encounter = "encounter",
  Boss = "boss",
  DelveComplete = "delveComplete",
  End = "end",
  Gold = "gold",
  Currency = "currency",
  Renown = "renown",
  Loot = "loot",
  Death = "death",
  Boon = "boon",
}

---@enum LDT_SectionId
Constants.sectionId = {
  Run = "run",
  Timers = "timers",
  Companion = "companion",
  Boons = "boons",
  Gains = "gains",
  Renown = "renown",
}

Constants.sections = {
  { id = Constants.sectionId.Run, label = "Run" },
  { id = Constants.sectionId.Timers, label = "Timers" },
  { id = Constants.sectionId.Companion, label = "Companion" },
  { id = Constants.sectionId.Boons, label = "Boons" },
  { id = Constants.sectionId.Gains, label = "Gains" },
  { id = Constants.sectionId.Renown, label = "Renown" },
}

---@enum LDT_ThemeId
Constants.themeId = {
  Flat = "flat",
}

Constants.themes = {
  { id = Constants.themeId.Flat, label = "Flat" },
}

---@enum LDT_SpacingId
Constants.spacingId = {
  Compact = "compact",
  Default = "default",
  Comfortable = "comfortable",
}

Constants.spacings = {
  { id = Constants.spacingId.Compact, label = "Compact", horizontal = 4, column = 4, row = 0 },
  { id = Constants.spacingId.Default, label = "Default", horizontal = 8, column = 6, row = 2 },
  { id = Constants.spacingId.Comfortable, label = "Comfortable", horizontal = 12, column = 8, row = 4 },
}

Constants.sectionGaps = {
  { label = "None", value = 0 },
  { label = "Small", value = 4 },
  { label = "Medium", value = 8 },
}

Constants.boonSpellID = 1280098

Constants.media = {
  Icon = "Interface/Icons/INV_Misc_PocketWatch_01",
}

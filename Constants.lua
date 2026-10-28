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

Constants.colors = {
  ahead = { r = 0.35, g = 0.9, b = 0.5, a = 1 },
  behind = { r = 1, g = 0.4, b = 0.4, a = 1 },
  background = { r = 0, g = 0, b = 0, a = 0.9 },
  border = { r = 1, g = 1, b = 1, a = 0 },
  step = { r = 1, g = 0.82, b = 0, a = 1 },
  objective = { r = 0.75, g = 0.85, b = 1, a = 1 },
  objectiveDone = { r = 0.65, g = 0.85, b = 0.65, a = 1 },
  wash = { r = 0, g = 0, b = 0, a = 0.35 },
  stripe = { r = 1, g = 1, b = 1, a = 0.08 },
  header = { r = 0, g = 0, b = 0, a = 1 },
  clear = { r = 0, g = 0, b = 0, a = 0 },
  title = { r = 1, g = 1, b = 1, a = 1 },
  activeRow = { r = 0.12, g = 0.32, b = 0.72, a = 0.7 },
  divider = { r = 0, g = 0, b = 0, a = 0.5 },
  block = { r = 1, g = 1, b = 1, a = 1 },
  nestedTime = { r = 0.5, g = 0.5, b = 0.5, a = 1 },
  gain = { r = 0.4, g = 0.8, b = 1, a = 1 },
  bar = { r = 0.25, g = 0.55, b = 0.9, a = 0.95 },
}

local timerStageWidth = 180
local timerNumberWidth = 75
local runStageWidth = 168
local runNumberWidth = 70
local runPadding = 8
local runBodyWidth = runStageWidth + (runNumberWidth * 3)
local runLabelWidth = 110
local runBoonValueWidth = 64

Constants.sizes = {
  iconInset = 1,
  timer = {
    header = 40,
    headerPad = 10,
    icon = 20,
    iconGap = 4,
    spellGap = 12,
    row = 28,
    line = 16,
    detailPad = 4,
    nodeIndent = 8,
    lineIndent = 26,
    mark = 14,
    markGap = 4,
    border = 1,
    phraseGap = 12,
    cueGap = 8,
    clock = 36,
    titleFont = 16,
    metaFont = 14,
    clockFont = 22,
    phraseFont = 14,
    padding = 8,
    width = timerStageWidth + (timerNumberWidth * 3),
    columnX = {
      0,
      timerStageWidth,
      timerStageWidth + timerNumberWidth,
      timerStageWidth + (timerNumberWidth * 2),
    },
    columnWidth = {
      timerStageWidth,
      timerNumberWidth,
      timerNumberWidth,
      timerNumberWidth,
    },
  },
  run = {
    stage = runStageWidth,
    number = runNumberWidth,
    body = runBodyWidth,
    label = runLabelWidth,
    value = runBodyWidth - runLabelWidth,
    rewardAmount = runNumberWidth * 2,
    rewardName = runBodyWidth - (runNumberWidth * 2),
    boonValue = runBoonValueWidth,
    boonLabel = (runBodyWidth - (runBoonValueWidth * 2)) / 2,
    timelineTime = runNumberWidth,
    timelineName = runBodyWidth - runNumberWidth,
    padding = runPadding,
    stageText = runStageWidth - (runPadding * 2),
    companionPad = 8,
    icon = 16,
    bar = 16,
    blockHeader = 22,
    screenMargin = 100,
    divider = 3,
    indent = 16,
    companionLine = 14,
    companionGap = 6,
    barTextPad = 4,
    iconGap = 2,
    atlas = 14,
    window = 200,
  },
  history = {
    body = 420,
  },
}

Constants.timing = {
  paint = 0.1,
}

Constants.media = {
  Icon = "Interface/Icons/INV_Misc_PocketWatch_01",
  -- Icon = format("Interface/AddOns/%s/Media/Icon.blp", addon.name),
  Rewards = format("Interface/AddOns/%s/Media/Icon_Rewards.blp", addon.name),
  Timeline = format("Interface/AddOns/%s/Media/Icon_Timeline.blp", addon.name),
  WhiteSquare = "Interface/Buttons/WHITE8X8",
  CircleMask = "Interface/CharacterFrame/TempPortraitAlphaMask",
  AffixRing = "ChallengeMode-AffixRing-Sm",
  NumberFont = "Fonts\\ARIALN.TTF",
  MarkNub = "ui-questtracker-objective-nub",
  MarkCheck = "ui-questtracker-tracker-check",
  Skull = "DungeonSkull",
  Heart = "delves-scenario-heart-icon",
}

---@class LDT_AceDB : AceDBObject-3.0
---@field global LDT_Global

---@class LDT_CatalogCriteria
---@field criteriaID number
---@field description string|nil
---@field totalQuantity number|nil
---@field criteriaType number|nil
---@field flags number|nil
---@field assetID number|nil
---@field isWeightedProgress boolean|nil

---@class LDT_CatalogStep
---@field stepID number
---@field stage number|nil
---@field title string|nil
---@field criteria LDT_CatalogCriteria[]

---@class LDT_CatalogScenario
---@field scenarioID number
---@field name string|nil
---@field numStages number|nil
---@field mapID number|nil
---@field instanceID number|nil
---@field difficultyID number|nil
---@field steps LDT_CatalogStep[]

---@class LDT_ObjectiveLine
---@field text string
---@field completed boolean

---@class LDT_StepRow
---@field name string
---@field elapsed number|nil
---@field best number|nil
---@field current boolean
---@field objectives LDT_ObjectiveLine[]|nil

---@class LDT_TimerOptions
---@field point string
---@field relativePoint string
---@field x number
---@field y number
---@field replaceTracker boolean
---@field showObjectives boolean
---@field showObjectiveCounts boolean
---@field aheadColor ColorRGBAData
---@field behindColor ColorRGBAData
---@field backgroundColor ColorRGBAData
---@field borderColor ColorRGBAData

---@class LDT_Global
---@field dbVersion number
---@field minimap { minimapPos: number, hide: boolean, lock: boolean }
---@field liqui LiqUI_DB
---@field logs LiqUI_LoggerDB
---@field timer LDT_TimerOptions
---@field scenarios table<number, LDT_CatalogScenario>
---@field runs LDT_Run[]
---@field activeRunID string|nil
---@field nextRunID number

---@class LDT_Data
---@field dbVersion number
---@field defaultDB table
---@field db LDT_AceDB
---@field labyrinthMapID number
---@field boonSpellID number
---@field hiddenItemIDs table<number, boolean>

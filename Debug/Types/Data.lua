---@class LDT_AceDB : AceDBObject-3.0
---@field global LDT_Global

---@class LDT_ReportOptions
---@field collapsed table<LDT_SectionId, boolean>

---@class LDT_Route
---@field id string
---@field mapID number|nil
---@field name string|nil
---@field steps string[]

---@class LDT_TimerOptions
---@field point string
---@field relativePoint string
---@field x number
---@field y number
---@field fontSize number
---@field replaceTracker boolean
---@field aheadColor ColorRGBAData
---@field behindColor ColorRGBAData
---@field backgroundColor ColorRGBAData
---@field borderColor ColorRGBAData

---@class LDT_Global
---@field dbVersion number
---@field minimap { minimapPos: number, hide: boolean, lock: boolean }
---@field liqui LiqUI_DB
---@field report LDT_ReportOptions
---@field logs LiqUI_LoggerDB
---@field timer LDT_TimerOptions
---@field routes table<string, LDT_Route>
---@field characters table<WOWGUID, LDT_Character>

---@class LDT_Character
---@field GUID WOWGUID
---@field activeRecordID string|nil
---@field records LDT_Record[]

---@class LDT_Data
---@field dbVersion number
---@field defaultDB table
---@field defaultCharacter LDT_Character
---@field db LDT_AceDB
---@field labyrinthMapID number
---@field boonSpellID number
---@field hiddenItemIDs table<number, boolean>

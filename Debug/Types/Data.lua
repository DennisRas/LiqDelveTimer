---@class LDT_WidgetSection
---@field enabled boolean
---@field collapsed boolean

---@class LDT_WidgetBorder
---@field enabled boolean
---@field color ColorTable

---@class LDT_Widget
---@field shown boolean
---@field minimized boolean
---@field point string
---@field relativePoint string
---@field x number
---@field y number
---@field spacing LDT_SpacingId
---@field sectionGap number
---@field theme LDT_ThemeId
---@field backgroundColor ColorTable
---@field headerBackgroundColor ColorTable
---@field headerFontColor ColorTable
---@field panelHeaderBackgroundColor ColorTable
---@field panelHeaderFontColor ColorTable
---@field sectionRuleColor ColorTable
---@field sectionBackgroundColor ColorTable
---@field bodyFontColor ColorTable
---@field border LDT_WidgetBorder
---@field sections table<LDT_SectionId, LDT_WidgetSection>

---@class LDT_Global
---@field dbVersion number
---@field minimap { minimapPos: number, hide: boolean, lock: boolean }
---@field liqui LiqUI_DB
---@field widget LDT_Widget
---@field logs LiqUI_LoggerDB
---@field characters table<WOWGUID, LDT_Character>

---@class LDT_Character
---@field GUID WOWGUID
---@field activeRecordID string|nil
---@field records LDT_Record[]

---@class LDT_Data
---@field dbVersion number
---@field defaultDB table
---@field defaultCharacter LDT_Character
---@field db AceDBObject-3.0

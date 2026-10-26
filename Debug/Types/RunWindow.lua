---@class LDT_RunIconButton : Button
---@field icon Texture
---@field spellID number|nil
---@field tip string|nil

---@class LDT_RunCompanion : Frame
---@field name FontString
---@field level FontString
---@field gain FontString
---@field empty FontString
---@field row Frame
---@field icons Frame
---@field bar StatusBar
---@field barText FontString
---@field role LDT_RunIconButton
---@field spells LDT_RunIconButton[]

---@class LDT_RunBlockHeader : Frame
---@field title FontString

---@class LDT_HistoryTableRow : LiqUI_TableDataRowExtended
---@field character string
---@field startedAt number
---@field delve string
---@field tier number
---@field result string
---@field duration number

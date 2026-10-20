---@class LDT_Constants
---@field prefix string
---@field labyrinthMapID number
---@field runResult table<string, LDT_RunResultId>
---@field logKind table<string, LDT_LogKindId>
---@field sectionId table<string, LDT_SectionId>
---@field sections { id: LDT_SectionId, label: string }[]
---@field themeId table<string, LDT_ThemeId>
---@field themes { id: LDT_ThemeId, label: string }[]
---@field spacingId table<string, LDT_SpacingId>
---@field spacings LDT_Spacing[]
---@field sectionGaps LDT_SectionGap[]
---@field boonSpellID number
---@field media LDT_Media

---@class LDT_Media
---@field Icon string

---@class LDT_SectionGap
---@field label string
---@field value number

---@class LDT_Spacing
---@field id LDT_SpacingId
---@field label string
---@field horizontal number
---@field column number
---@field row number

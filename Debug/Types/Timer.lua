---@class LDT_ResetColorsStaticPopupDialog
---@field text string
---@field button1 string
---@field button2 string
---@field OnAccept fun()
---@field timeout number
---@field whileDead number
---@field hideOnEscape number

---@class LDT_TimerDetailLine
---@field frame Frame
---@field icon Texture
---@field text FontString
---@field time FontString

---@class LDT_TimerFrame : Frame, BackdropTemplate

---@class LDT_TimerHeader : Frame
---@field background Texture

---@class LDT_TimerLine
---@field text string
---@field completed boolean

---@class LDT_TimerNode
---@field name string
---@field title string|nil
---@field elapsed number|nil
---@field best number|nil
---@field current boolean
---@field done number|nil
---@field total number|nil
---@field nodes LDT_TimerNode[]|nil
---@field lines LDT_TimerLine[]|nil

---@class LDT_TimerSpell
---@field button Button
---@field icon Texture
---@field spellID number|nil

---@class LDT_TimerSplitRow
---@field frame Frame
---@field bar Frame
---@field background Texture
---@field highlight Texture
---@field name FontString
---@field delta FontString
---@field time FontString
---@field best FontString
---@field detail Frame
---@field lines LDT_TimerDetailLine[]

---@class LDT_Libs
---@field LibDataBroker LibDataBroker-1.1
---@field LibDBIcon LibDBIcon-1.0
---@field AceDB AceDB-3.0
---@field AceAddon AceAddon-3.0
---@field LiqUI LiqUI

---@class LDT_Addon
---@field name string
---@field title string
---@field version string
---@field notes string
---@field libs LDT_Libs
---@field Core LDT_Core
---@field Data LDT_Data
---@field Constants LDT_Constants
---@field Helpers LDT_Helpers
---@field Capture LDT_Capture
---@field ApiLog LDT_ApiLog
---@field logger LiqUI_LoggerHandle
---@field Module_Timer LDT_Module_Timer
---@field Module_Report LDT_Module_Report
---@field Module_Records LDT_Module_Records
---@field Debug LDT_Debug|nil

---@class LDT_ApiLog
---@field lastPacked string|nil
---@field lastLines string[]|nil

---@class LDT_Core : AceAddon, AceConsole-3.0

---@class LDT_Module_Timer : AceModule
---@field frame Frame|nil
---@field title FontString|nil
---@field header Frame|nil
---@field clock FontString|nil
---@field phrase FontString|nil
---@field deaths FontString|nil
---@field spells Frame|nil
---@field spellButtons LDT_TimerSpell[]|nil
---@field timeHeader FontString|nil
---@field bestHeader FontString|nil
---@field rows LDT_TimerRow[]|nil
---@field ticker TickerCallback|nil

---@class LDT_Module_Report : AceModule
---@field window LiqUI_WindowInstance|nil
---@field panels table<LDT_SectionId, LDT_WidgetPanel>|nil
---@field pinnedRecord LDT_Record|nil
---@field ticker TickerCallback|nil

---@class LDT_Module_Records : AceModule
---@field window LiqUI_WindowInstance|nil
---@field table LiqUI_TableInstance|nil

---@class LDT_Capture
---@field ready boolean
---@field clockReady boolean
---@field reloadNoted boolean
---@field zoneKnown boolean
---@field entranceNoted boolean
---@field timerFromGame boolean|nil
---@field timerContext "run"|"preview"|nil
---@field preview LDT_Preview|nil
---@field trackerHidden boolean|nil
---@field onRunStored function|nil

---@class LDT_Debug

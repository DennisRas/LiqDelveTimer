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
---@field Module_Main LDT_Module_Main
---@field Module_Records LDT_Module_Records
---@field Debug LDT_Debug|nil

---@class LDT_ApiLog
---@field lastPacked string|nil
---@field lastLines string[]|nil

---@class LDT_Core : AceAddon, AceConsole-3.0

---@class LDT_Module_Main : AceModule
---@field frame Frame|nil
---@field title FontString|nil
---@field header Frame|nil
---@field headerBackground Texture|nil
---@field headerRule Texture|nil
---@field closeButton Button|nil
---@field minimizeIcon Texture|nil
---@field pinTopRight fun()|nil
---@field dragging boolean|nil
---@field panels table<LDT_SectionId, LDT_WidgetPanel>|nil

---@class LDT_Module_Records : AceModule
---@field window LiqUI_WindowInstance|nil
---@field table LiqUI_TableInstance|nil
---@field detail LiqUI_WindowInstance|nil
---@field detailScroll LiqUI_ScrollArea|nil
---@field detailText FontString|nil

---@class LDT_Capture
---@field ready boolean
---@field clockReady boolean
---@field reloadNoted boolean
---@field seenWorld boolean
---@field entranceNoted boolean
---@field outsideSince number|nil

---@class LDT_Debug

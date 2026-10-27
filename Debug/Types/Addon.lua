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
---@field Log LDT_Log
---@field logger LiqUI_LoggerHandle|nil
---@field Module_Timer LDT_Module_Timer
---@field Module_Run LDT_Module_Run
---@field Module_History LDT_Module_History
---@field Debug LDT_Debug|nil

---@class LDT_CaptureState
---@field gold number|nil
---@field level number|nil
---@field experience number|nil
---@field experienceMax number|nil
---@field zone string|nil
---@field subzone string|nil
---@field loot table<string, number>

---@class LDT_Core : AceAddon, AceConsole-3.0

---@class LDT_Log
---@field lastPacked string|nil
---@field lastLines string[]|nil

---@class LDT_Module_Timer : AceModule
---@field frame LDT_TimerFrame|nil
---@field header Frame|nil
---@field title FontString|nil
---@field deaths FontString|nil
---@field deathsIcon Texture|nil
---@field lives FontString|nil
---@field livesIcon Texture|nil
---@field spells Frame|nil
---@field spellButtons LDT_TimerSpell[]|nil
---@field table LiqUI_TableInstance|nil
---@field clockFrame Frame|nil
---@field clock FontString|nil
---@field phrase FontString|nil

---@class LDT_Module_Run : AceModule
---@field window LiqUI_WindowInstance|nil
---@field summary LiqUI_TableInstance|nil
---@field stages LiqUI_TableInstance|nil
---@field boons LiqUI_TableInstance|nil
---@field rewards LiqUI_TableInstance|nil
---@field companion LDT_RunCompanion|nil
---@field companionHeader LDT_RunBlockHeader|nil
---@field boonsHeader LDT_RunBlockHeader|nil
---@field rewardsHeader LDT_RunBlockHeader|nil
---@field summaryData LiqUI_TableData|nil
---@field stagesData LiqUI_TableData|nil
---@field boonsData LiqUI_TableData|nil
---@field rewardsData LiqUI_TableData|nil
---@field pinnedRun LDT_Run|nil
---@field showingRun boolean|nil

---@class LDT_Module_History : AceModule
---@field window LiqUI_WindowInstance|nil
---@field table LiqUI_TableInstance|nil

---@class LDT_Capture
---@field ready boolean
---@field clockReady boolean
---@field clockOrigin number
---@field zoneKnown boolean
---@field entranceNoted boolean
---@field timerFromGame boolean|nil
---@field timerContext "run"|nil
---@field trackerHidden boolean|nil
---@field onRunStored function|nil

---@class LDT_Debug

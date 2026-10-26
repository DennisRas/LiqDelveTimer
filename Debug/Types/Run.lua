---@class LDT_Character
---@field guid WOWGUID|nil
---@field name string|nil
---@field realm string|nil
---@field homeRealm string|nil
---@field classFile string|nil
---@field classID number|nil
---@field level number|nil
---@field itemLevel number|nil
---@field specID number|nil
---@field specName string|nil

---@class LDT_TierReward
---@field id number
---@field quantity number
---@field rewardType number
---@field context number

---@class LDT_Entrance
---@field entranceType number|nil
---@field title string|nil
---@field header string|nil
---@field description string|nil
---@field mapID number|nil
---@field pdeID number|nil
---@field seasonNumber number|nil
---@field worldTierDifficulty number|nil
---@field affixSpellIDs number[]|nil
---@field activeSpellIDs number[]|nil
---@field tierInfo TieredEntranceTierInfo|nil

---@class LDT_DelveHeader
---@field tier number|nil
---@field lives number|nil
---@field deaths number|nil
---@field spellIDs number[]

---@class LDT_BestStep
---@field stepID number|nil
---@field stage number|nil
---@field completedElapsed number

---@class LDT_BestChamber
---@field name string
---@field completedElapsed number

---@class LDT_RunBest
---@field id string|nil
---@field startedAt number|nil
---@field endedAt number|nil
---@field steps LDT_BestStep[]
---@field chambers LDT_BestChamber[]

---@class LDT_Companion
---@field companionID number|nil
---@field creatureDisplayInfoID number|nil
---@field factionID number|nil
---@field name string|nil
---@field description string|nil
---@field level number|nil
---@field maxLevel number|nil
---@field flavorName string|nil
---@field flavorNodeID number|nil
---@field flavorSpellID number|nil
---@field roleNodeID number|nil
---@field traitTreeID number|nil
---@field combatCurioNodeID number|nil
---@field utilityCurioNodeID number|nil
---@field roleName string|nil
---@field roleSpellID number|nil
---@field roleAtlas string|nil
---@field combatCurioName string|nil
---@field combatCurioSpellID number|nil
---@field utilityCurioName string|nil
---@field utilityCurioSpellID number|nil
---@field standing number|nil
---@field reactionThreshold number|nil
---@field nextThreshold number|nil
---@field startLevel number|nil
---@field startStanding number|nil

---@class LDT_Instance
---@field name string|nil
---@field instanceType string|nil
---@field difficultyID number|nil
---@field difficultyName string|nil
---@field maxPlayers number|nil
---@field dynamicDifficulty number|nil
---@field isDynamic boolean|nil
---@field instanceID number|nil
---@field instanceGroupSize number|nil
---@field lfgDungeonID number|nil
---@field hasWorldTier boolean|nil
---@field mapID number|nil
---@field mapName string|nil
---@field zone string|nil
---@field subzone string|nil

---@class LDT_Place
---@field zone string|nil
---@field subzone string|nil
---@field mapID number|nil
---@field mapName string|nil

---@class LDT_CriteriaSnap
---@field description string
---@field criteriaType number
---@field completed boolean
---@field quantity number
---@field totalQuantity number
---@field flags number
---@field assetID number
---@field criteriaID number
---@field duration number
---@field elapsed number
---@field failed boolean
---@field isWeightedProgress boolean
---@field isFormatted boolean
---@field quantityString string

---@class LDT_Scenario
---@field info ScenarioInformation|nil
---@field step ScenarioStepInfo|nil
---@field criteria LDT_CriteriaSnap[]

---@class LDT_RunCriteria
---@field criteriaID number
---@field description string|nil
---@field completed boolean
---@field failed boolean
---@field quantity number|nil
---@field totalQuantity number|nil
---@field quantityString string|nil
---@field criteriaType number|nil
---@field isWeightedProgress boolean|nil

---@class LDT_RunStep
---@field stepID number
---@field stage number|nil
---@field enteredElapsed number
---@field completedElapsed number|nil
---@field criteria LDT_RunCriteria[]

---@class LDT_Gain
---@field type LDT_GainTypeId
---@field id number|nil
---@field amount number
---@field itemLink string|nil

---@class LDT_BoonStat
---@field label string|nil
---@field amount number|nil
---@field percent boolean|nil
---@field text string|nil

---@class LDT_Chamber
---@field name string
---@field stepID number|nil
---@field enteredElapsed number
---@field completedElapsed number|nil

---@class LDT_DelvesDifficultyPickerFrame : Frame
---@field GetSelectedTierInfo fun(self: LDT_DelvesDifficultyPickerFrame): TieredEntranceTierInfo?

---@class LDT_Encounter
---@field encounterID number
---@field encounterName string
---@field difficultyID number
---@field groupSize number
---@field success number
---@field elapsed number

---@class LDT_CriteriaWatch
---@field completed boolean
---@field failed boolean

---@class LDT_Watch
---@field zone string|nil
---@field subzone string|nil
---@field stepID number|nil
---@field criteriaSignature string|nil
---@field scenarioComplete boolean
---@field routeStep string|nil
---@field criteria table<number, LDT_CriteriaWatch>

---@class LDT_LogDetail
---@field zone string|nil
---@field subzone string|nil
---@field mapID number|nil
---@field stepID number|nil
---@field stepTitle string|nil
---@field criteriaID number|nil
---@field description string|nil
---@field encounterID number|nil
---@field encounterName string|nil

---@class LDT_LogEntry
---@field at number
---@field elapsed number
---@field kind LDT_LogKindId
---@field text string
---@field detail LDT_LogDetail|nil

---@class LDT_Run
---@field id string
---@field result LDT_RunResultId
---@field mode LDT_RunModeId|nil
---@field startedAt number
---@field endedAt number|nil
---@field best LDT_RunBest|nil
---@field variant string|nil
---@field scenarioID number|nil
---@field deaths number|nil
---@field lives number|nil
---@field character LDT_Character|nil
---@field entrance LDT_Entrance|nil
---@field companion LDT_Companion|nil
---@field instance LDT_Instance|nil
---@field place LDT_Place|nil
---@field scenario LDT_Scenario|nil
---@field boons LDT_BoonStat[]
---@field gains LDT_Gain[]
---@field chambers LDT_Chamber[]
---@field encounters LDT_Encounter[]
---@field steps LDT_RunStep[]|nil
---@field log LDT_LogEntry[]
---@field watch LDT_Watch

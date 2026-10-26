---@class LDT_Addon
local addon = select(2, ...)

---@class LDT_Debug
local Debug = {}
addon.Debug = Debug

local Data = addon.Data
local Helpers = addon.Helpers

---@param input string|nil
---@return boolean
function Debug:OnChatCommand(input)
  ---@type string?
  local command = addon.Core:GetArgs(input or "", 1)
  if type(command) ~= "string" then
    return false
  end
  local token = command:lower()
  local stepID
  if type(select(2, addon.Core:GetArgs(input or "", 2))) == "string" then
    stepID = tonumber(select(2, addon.Core:GetArgs(input or "", 2)))
  end
  if token == "probe" then
    if not stepID or not addon.Log then
      addon.Core:Print(format("Usage: /%s probe <stepID>", addon.name:lower()))
      return true
    end
    addon.Log:ReadStep(stepID)
    return true
  end
  if token ~= "dump" then
    return false
  end
  local run = Data:GetActiveRun() or Data:GetLatestRun()
  if not run then
    addon.Core:Print("No delve run yet.")
    return true
  end
  local mode = Helpers.RunMode(run) or "none"
  addon.Core:Print(format("Run %s (%s) mode %s scenarios %d", run.id, run.result, mode, #run.scenarios))
  return true
end

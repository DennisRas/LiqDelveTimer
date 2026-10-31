---@class LDT_Addon
local addon = select(2, ...)

---@class LDT_Debug
local Debug = {}
addon.Debug = Debug

---@param input string|nil
---@return boolean
function Debug:OnChatCommand(input)
  ---@type string?
  local command = addon.Core:GetArgs(input or "", 1)
  if type(command) ~= "string" then
    return false
  end
  local token = command:lower()
  if token == "start" then
    if addon.Debugger then
      addon.Debugger:Start()
    end
    return true
  end
  if token == "stop" then
    if addon.Debugger then
      addon.Debugger:Stop()
    end
    return true
  end
  return false
end

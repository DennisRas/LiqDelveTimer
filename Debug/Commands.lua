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
  if not command or command:lower() ~= "dump" then
    return false
  end
  local record = Data:GetActiveRecord() or Data:GetLatestRecord()
  if not record then
    addon.Core:Print("No delve record yet.")
    return true
  end
  addon.Core:Print(format("Record %s (%s)", record.id, record.result))
  local chambers = record.chambers
  for index = 1, #chambers do
    local chamber = chambers[index]
    local completed = "open"
    if chamber.completedElapsed then
      completed = Helpers.FormatElapsed(chamber.completedElapsed)
    end
    addon.Core:Print(format("Chamber %s entered %s complete %s", chamber.name, Helpers.FormatElapsed(chamber.enteredElapsed), completed))
  end
  local log = record.log
  local first = #log - 29
  if first < 1 then
    first = 1
  end
  for index = first, #log do
    local entry = log[index]
    addon.Core:Print(format("%s %s", Helpers.FormatElapsed(entry.elapsed), entry.text))
  end
  return true
end

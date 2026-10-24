---@class LDT_Addon
local addon = select(2, ...)

---@class LDT_Module_History
local Module = addon.Core:NewModule("History")
addon.Module_History = Module

local Data = addon.Data
local Constants = addon.Constants
local Helpers = addon.Helpers
local LiqUI = addon.libs.LiqUI

---@param rowA LDT_HistoryTableRow
---@param rowB LDT_HistoryTableRow
---@return boolean
local function compareStartedAscending(rowA, rowB)
  return rowA.startedAt < rowB.startedAt
end

---@param rowA LDT_HistoryTableRow
---@param rowB LDT_HistoryTableRow
---@return boolean
local function compareDelve(rowA, rowB)
  return strcmputf8i(rowA.delve, rowB.delve) < 0
end

---@param rowA LDT_HistoryTableRow
---@param rowB LDT_HistoryTableRow
---@return boolean
local function compareResult(rowA, rowB)
  return strcmputf8i(rowA.result, rowB.result) < 0
end

---@param rowA LDT_HistoryTableRow
---@param rowB LDT_HistoryTableRow
---@return boolean
local function compareDuration(rowA, rowB)
  return rowA.duration < rowB.duration
end

---@param rowA LDT_HistoryTableRow
---@param rowB LDT_HistoryTableRow
---@return boolean
local function compareStartedDescending(rowA, rowB)
  return rowA.startedAt > rowB.startedAt
end

---@param run LDT_Run
---@return number
local function activeElapsed(run)
  if addon.Capture.clockReady and run.result == Constants.runResult.Active then
    return addon.Capture:Elapsed(run)
  end
  if run.endedElapsed then
    return run.endedElapsed
  end
  return 0
end

function Module:Render()
  if not self.window then
    local windows = Data.db.global.liqui.windows
    ---@type LiqUI_WindowOptions
    local windowOptions = {
      name = addon.name .. "History",
      storage = windows.History,
      title = "History",
      icon = Constants.media.Icon,
      width = 560,
      height = 420,
      onShow = function()
        Module:Render()
      end,
    }
    self.window = LiqUI:NewElement("Window", windowOptions)
    local sizes = LiqUI.Constants.layout.sizes
    ---@type LiqUI_TableOptions
    local tableOptions = {
      name = addon.name .. "History",
      storage = Data.db.global.liqui.tables.History,
      header = { enabled = true, sticky = true, height = sizes.header },
      rowStyle = { height = sizes.row, striped = true },
      columns = {
        {
          id = "when",
          headerText = "When",
          width = 150,
          sorting = {
            enabled = true,
            compare = compareStartedAscending,
          },
        },
        {
          id = "delve",
          headerText = "Delve",
          width = 190,
          sorting = {
            enabled = true,
            compare = compareDelve,
          },
        },
        {
          id = "result",
          headerText = "Result",
          width = 100,
          sorting = {
            enabled = true,
            compare = compareResult,
          },
        },
        {
          id = "time",
          headerText = "Time",
          width = 100,
          sorting = {
            enabled = true,
            compare = compareDuration,
          },
        },
      },
      sorting = {
        enabled = true,
        defaultOrder = "desc",
        defaultCompare = compareStartedDescending,
      },
    }
    self.table = LiqUI:NewElement("Table", tableOptions)
    self.table:SetParent(self.window.body)
    self.table:SetPoint("TOPLEFT", self.window.body, "TOPLEFT", 0, 0)
    self.table:SetPoint("BOTTOMRIGHT", self.window.body, "BOTTOMRIGHT", 0, 0)
  end
  if not self.window:IsShown() or not self.table then
    return
  end
  local character = Data:GetCharacter()
  local runs = character and character.runs or {}
  if #runs == 0 then
    self.table:Hide()
    self.window:ShowOverlay("No delve runs yet.")
    return
  end
  self.window:HideOverlay()
  self.table:Show()
  ---@type LDT_HistoryTableRow[]
  local data = {}
  for index = #runs, 1, -1 do
    local run = runs[index]
    local delve = "Delve"
    local instance = run.instance
    if instance then
      local instanceName = instance.name
      if instanceName and instanceName ~= "" then
        delve = instanceName
      end
    end
    local duration = Helpers.CompletionTime(run)
    if not duration then
      if run.result == Constants.runResult.Active then
        duration = activeElapsed(run)
      else
        duration = run.endedElapsed or 0
      end
    end
    local whenValue = date("%Y-%m-%d %H:%M", run.startedAt)
    local whenText = ""
    if type(whenValue) == "string" then
      whenText = whenValue
    end
    ---@type LDT_HistoryTableRow
    local row = {
      startedAt = run.startedAt,
      delve = delve,
      result = run.result,
      duration = duration,
      data = {
        whenText,
        delve,
        tostring(run.result),
        Helpers.FormatElapsed(duration),
      },
      onClick = function()
        if addon.Module_Run then
          addon.Module_Run:ShowRun(run)
        end
      end,
    }
    data[#data + 1] = row
  end
  self.table:SetData(data)
end

function Module:ToggleWindow()
  if not self.window then
    self:Render()
  end
  if self.window then
    self.window:Toggle()
  end
end

function Module:OnEnable()
  addon.Capture.onRunStored = function()
    if Module.window and Module.window:IsShown() then
      Module:Render()
    end
  end
end

---@class LDT_Addon
local addon = select(2, ...)

---@class LDT_Module_Records
local Module = addon.Core:NewModule("Records")
addon.Module_Records = Module

local Data = addon.Data
local Constants = addon.Constants
local Helpers = addon.Helpers
local LiqUI = addon.libs.LiqUI

---@param record LDT_Record
---@return number
local function ActiveElapsed(record)
  if addon.Capture.clockReady and record.result == Constants.runResult.Active then
    return addon.Capture:Elapsed(record)
  end
  if record.endedElapsed then
    return record.endedElapsed
  end
  return 0
end

function Module:Render()
  if not self.window then
    local windows = Data.db.global.liqui.windows
    self.window = LiqUI:NewElement("Window", {
      name = addon.name .. "Records",
      storage = windows.Records,
      title = "Records",
      icon = Constants.media.Icon,
      width = 560,
      height = 420,
      onShow = function()
        Module:Render()
      end,
    })
    local sizes = LiqUI.Constants.layout.sizes
    self.table = LiqUI:NewElement("Table", {
      name = addon.name .. "Records",
      storage = Data.db.global.liqui.tables.Records,
      header = { enabled = true, sticky = true, height = sizes.header },
      rowStyle = { height = sizes.row, striped = true },
      columns = {
        {
          id = "when",
          headerText = "When",
          width = 150,
          sorting = {
            enabled = true,
            compare = function(rowA, rowB)
              return rowA.startedAt < rowB.startedAt
            end,
          },
        },
        {
          id = "delve",
          headerText = "Delve",
          width = 190,
          sorting = {
            enabled = true,
            compare = function(rowA, rowB)
              return strcmputf8i(rowA.delve, rowB.delve) < 0
            end,
          },
        },
        {
          id = "result",
          headerText = "Result",
          width = 100,
          sorting = {
            enabled = true,
            compare = function(rowA, rowB)
              return strcmputf8i(rowA.result, rowB.result) < 0
            end,
          },
        },
        {
          id = "time",
          headerText = "Time",
          width = 100,
          sorting = {
            enabled = true,
            compare = function(rowA, rowB)
              return rowA.duration < rowB.duration
            end,
          },
        },
      },
      sorting = {
        enabled = true,
        defaultOrder = "desc",
        defaultCompare = function(rowA, rowB)
          return rowA.startedAt > rowB.startedAt
        end,
      },
    })
    self.table:SetParent(self.window.body)
    self.table:SetPoint("TOPLEFT", self.window.body, "TOPLEFT", 0, 0)
    self.table:SetPoint("BOTTOMRIGHT", self.window.body, "BOTTOMRIGHT", 0, 0)
  end
  if not self.window:IsShown() or not self.table then
    return
  end
  local character = Data:GetCharacter()
  local records = character and character.records or {}
  if #records == 0 then
    self.table:Hide()
    self.window:ShowOverlay("No delve records yet.")
    return
  end
  self.window:HideOverlay()
  self.table:Show()
  ---@type LDT_RecordsTableRow[]
  local data = {}
  for index = #records, 1, -1 do
    local record = records[index]
    local delve = record.instance and record.instance.name
    if not delve or delve == "" then
      delve = "Delve"
    end
    local duration = Helpers.CompletionTime(record)
    if not duration then
      if record.result == Constants.runResult.Active then
        duration = ActiveElapsed(record)
      else
        duration = record.endedElapsed or 0
      end
    end
    ---@type LDT_RecordsTableRow
    local row = {
      startedAt = record.startedAt,
      delve = delve,
      result = record.result,
      duration = duration,
      data = {
        date("%Y-%m-%d %H:%M", record.startedAt),
        delve,
        record.result,
        Helpers.FormatElapsed(duration),
      },
      onClick = function()
        if addon.Module_Report then
          addon.Module_Report:ShowRecord(record)
        end
      end,
    }
    data[#data + 1] = row
  end
  self.table:SetData(data)
end

function Module:ToggleWindow()
  self:Render()
  if not self.window then
    return
  end
  if self.window:IsShown() then
    self.window:Hide()
    return
  end
  self.window:Show()
end

function Module:OnEnable()
  addon.Capture.onRunStored = function()
    if Module.window and Module.window:IsShown() then
      Module:Render()
    end
  end
end

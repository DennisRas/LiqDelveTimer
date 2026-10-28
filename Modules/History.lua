---@class LDT_Addon
local addon = select(2, ...)

---@class LDT_Module_History
local Module = addon.Core:NewModule("History")
addon.Module_History = Module

local Data = addon.Data
local Constants = addon.Constants
local Helpers = addon.Helpers
local FindDuration = Helpers.FindDuration
local FormatDate = Helpers.FormatDate
local FindTier = Helpers.FindTier
local FormatResult = Helpers.FormatResult
local FindResultColor = Helpers.FindResultColor
local FormatElapsed = Helpers.FormatElapsed
local LiqUI = addon.libs.LiqUI
local layoutSizes = LiqUI.Constants.layout.sizes

---@param text string
---@param red number
---@param green number
---@param blue number
---@return string
local function colorText(text, red, green, blue)
  return CreateColor(red, green, blue):WrapTextInColorCode(text)
end

---@param rowA LDT_HistoryTableRow
---@param rowB LDT_HistoryTableRow
---@return boolean
local function compareCharacter(rowA, rowB)
  return strcmputf8i(rowA.character, rowB.character) < 0
end

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
local function compareTier(rowA, rowB)
  return rowA.tier < rowB.tier
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

function Module:Render()
  if not self.window then
    local windows = Data.db.global.liqui.windows
    ---@type LiqUI_WindowOptions
    local windowOptions = {
      name = addon.name .. "History",
      storage = windows.History,
      title = "History",
      icon = Constants.media.Icon,
      width = 740,
      height = 420,
      onShow = function()
        Module:Render()
      end,
    }
    self.window = LiqUI:NewElement("Window", windowOptions)
    ---@type LiqUI_TableOptions
    local buildTableOptions = {
      name = addon.name .. "History",
      storage = Data.db.global.liqui.tables.History,
      header = { enabled = true, sticky = true, height = layoutSizes.header },
      rowStyle = { height = layoutSizes.row, striped = true },
      columns = {
        {
          id = "tier",
          headerText = "Tier",
          width = 52,
          align = "CENTER",
          sorting = {
            enabled = true,
            compare = compareTier,
          },
        },
        {
          id = "delve",
          headerText = "Delve",
          width = 170,
          sorting = {
            enabled = true,
            compare = compareDelve,
          },
        },
        {
          id = "character",
          headerText = "Character",
          width = 130,
          sorting = {
            enabled = true,
            compare = compareCharacter,
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
          width = 90,
          align = "RIGHT",
          sorting = {
            enabled = true,
            compare = compareDuration,
          },
        },
        {
          id = "when",
          headerText = "Date",
          width = 140,
          sorting = {
            enabled = true,
            compare = compareStartedAscending,
          },
        },
      },
      sorting = {
        enabled = true,
        defaultOrder = "desc",
        defaultCompare = compareStartedDescending,
      },
    }
    self.table = LiqUI:NewElement("Table", buildTableOptions)
    self.table:SetParent(self.window.body)
    self.table:SetPoint("TOPLEFT", self.window.body, "TOPLEFT", 0, 0)
    self.table:SetPoint("BOTTOMRIGHT", self.window.body, "BOTTOMRIGHT", 0, 0)
  end
  if not self.window:IsShown() or not self.table then
    return
  end
  ---@type LDT_HistoryTableRow[]
  local data = {}
  Data:ForEachRun(function(run)
    local delve = "Delve"
    local instance = run.instance
    if instance then
      local instanceName = instance.name
      if instanceName and instanceName ~= "" then
        delve = instanceName
      end
    end
    local inProgress = run.endedAt == nil
    local duration = FindDuration(run) or 0
    local whenText = FormatDate(run.startedAt, Constants.dateLength.Medium)
    local characterName = ""
    local characterText = ""
    local character = run.character
    if character and character.name and character.name ~= "" then
      characterName = character.name
      characterText = characterName
      local classFile = character.classFile
      if classFile then
        local classColor = C_ClassColor.GetClassColor(classFile)
        if classColor and classColor.r and classColor.g and classColor.b then
          characterText = colorText(characterName, classColor.r, classColor.g, classColor.b)
        end
      end
    end
    local tier = FindTier(run) or 0
    local tierText = "-"
    if tier > 0 then
      tierText = tostring(tier)
    end
    local label = FormatResult(run.result)
    local red, green, blue = FindResultColor(run.result)
    local resultText = colorText(label, red, green, blue)
    local durationText = "-"
    if not inProgress then
      durationText = FormatElapsed(duration)
    end
    ---@type LDT_HistoryTableRow
    local row = {
      tier = tier,
      delve = delve,
      character = characterName,
      startedAt = run.startedAt,
      result = label,
      duration = duration,
      data = {
        tierText,
        delve,
        characterText,
        resultText,
        durationText,
        whenText,
      },
      onClick = function()
        if addon.Module_Run then
          addon.Module_Run:ShowRun(run)
        end
      end,
    }
    data[#data + 1] = row
  end)
  if #data == 0 then
    self.table:Hide()
    self.window:ShowOverlay("No delve runs yet.")
    return
  end
  self.window:HideOverlay()
  self.table:Show()
  self.table:SetData(data)
  local tableWidth, tableHeight = self.table:GetSize()
  if tableWidth < 1 then
    tableWidth = 682
  end
  local bodyHeight = tableHeight
  if bodyHeight > Constants.sizes.history.body then
    bodyHeight = Constants.sizes.history.body
    tableWidth = tableWidth + layoutSizes.scrollbar.thickness
  end
  self.window:SetBodySize(tableWidth, bodyHeight)
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

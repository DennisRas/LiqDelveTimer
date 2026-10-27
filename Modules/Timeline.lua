---@class LDT_Addon
local addon = select(2, ...)

---@class LDT_Module_Timeline
local Module = addon.Core:NewModule("Timeline")
addon.Module_Timeline = Module

local Data = addon.Data
local Helpers = addon.Helpers
local LiqUI = addon.libs.LiqUI

local NAME_WIDTH = 420
local TIME_WIDTH = 80
local INDENT_STEP = 16
local SCREEN_MARGIN = 100
---@type ColorRGBAData
local BLOCK_COLOR = { r = 1, g = 1, b = 1, a = 1 }
---@type ColorRGBAData
local STEP_COLOR = { r = 1, g = 0.82, b = 0, a = 1 }
---@type ColorRGBAData
local OBJECTIVE_COLOR = { r = 0.75, g = 0.85, b = 1, a = 1 }
---@type ColorRGBAData
local OBJECTIVE_DONE_COLOR = { r = 0.65, g = 0.85, b = 0.65, a = 1 }

local PAINT_INTERVAL = 0.1
local paintRemaining = 0

---@param _frame Frame
---@param elapsed number
local function onPaintUpdate(_frame, elapsed)
  paintRemaining = paintRemaining - elapsed
  if paintRemaining > 0 then
    return
  end
  paintRemaining = PAINT_INTERVAL
  Module:Render()
end

---@param line LDT_TimelineRow
---@return ColorRGBAData
local function labelColor(line)
  if line.depth == 0 then
    return BLOCK_COLOR
  end
  if line.depth == 1 then
    return STEP_COLOR
  end
  if line.done then
    return OBJECTIVE_DONE_COLOR
  end
  return OBJECTIVE_COLOR
end

---@param text string
---@param color ColorRGBAData
---@return string
local function colorText(text, color)
  return CreateColor(color.r, color.g, color.b):WrapTextInColorCode(text)
end

---@return LDT_Run|nil
local function shownRun()
  local runModule = addon.Module_Run
  if runModule and runModule.pinnedRun then
    return runModule.pinnedRun
  end
  return Data:GetActiveRun()
end

---@param cellFrame LiqUI_TableCellFrame
---@param _rowFrame LiqUI_TableRowFrame
---@param _rowIndex integer
---@param columnIndex integer
---@param _columnId string|nil
---@param rowData LiqUI_TableDataRowExtended
local function showLine(cellFrame, _rowFrame, _rowIndex, columnIndex, _columnId, rowData)
  if columnIndex ~= 1 then
    return
  end
  local cells = rowData.data
  local text = cells[1]
  if type(text) ~= "string" or text == "" then
    return
  end
  GameTooltip:SetOwner(cellFrame, "ANCHOR_RIGHT")
  GameTooltip:SetText(text, 1, 1, 1, 1, true)
  GameTooltip:Show()
end

function Module:Render()
  if not self.window then
    local windows = Data.db.global.liqui.windows
    if not windows.Timeline then
      ---@type LiqUI_WindowDB
      local storage = {}
      windows.Timeline = storage
    end
    ---@type LiqUI_WindowOptions
    local windowOptions = {
      name = addon.name .. "Timeline",
      storage = windows.Timeline,
      title = "Timeline",
      width = NAME_WIDTH + TIME_WIDTH,
      height = 240,
      onShow = function()
        Module:Render()
      end,
    }
    self.window = LiqUI:NewElement("Window", windowOptions)
    self.window:HookScript("OnHide", function(hiddenFrame)
      hiddenFrame:SetScript("OnUpdate", nil)
    end)
    local sizes = LiqUI.Constants.layout.sizes
    ---@type LiqUI_TableOptions
    local tableOptions = {
      name = addon.name .. "Timeline",
      header = { enabled = true, sticky = true, height = sizes.header },
      rowStyle = { height = sizes.row, striped = true },
      columns = {
        { id = "name", headerText = "Path", width = NAME_WIDTH, align = "LEFT" },
        { id = "time", headerText = "Time", width = TIME_WIDTH, align = "RIGHT" },
      },
    }
    local timeline = LiqUI:NewElement("Table", tableOptions)
    timeline:SetParent(self.window.body)
    timeline:SetPoint("TOPLEFT", self.window.body, "TOPLEFT", 0, 0)
    timeline:SetPoint("BOTTOMRIGHT", self.window.body, "BOTTOMRIGHT", 0, 0)
    self.table = timeline
  end
  if not self.window or not self.table or not self.window:IsShown() then
    return
  end
  local run = shownRun()
  if not run then
    self.table:Hide()
    self.window:ShowOverlay("No run yet.")
    self.window:SetScript("OnUpdate", nil)
    return
  end
  local lines = Data:TimelineRows(run)
  if #lines == 0 then
    self.table:Hide()
    self.window:ShowOverlay("No path yet.")
    self.window:SetScript("OnUpdate", nil)
    return
  end
  ---@type LiqUI_TableData
  local data = {}
  for lineIndex = 1, #lines do
    local line = lines[lineIndex]
    local color = labelColor(line)
    local timeText = ""
    if line.elapsed ~= nil then
      timeText = colorText(Helpers.FormatElapsed(line.elapsed), color)
    end
    ---@type LiqUI_TableDataRowExtended
    local row = {
      data = { colorText(line.name, color), timeText },
      indent = line.depth * INDENT_STEP,
      onEnter = showLine,
      onLeave = GameTooltip_Hide,
    }
    data[#data + 1] = row
  end
  self.window:HideOverlay()
  self.table:Show()
  self.table:SetData(data)
  local tableWidth, tableHeight = self.table:GetSize()
  if tableWidth < 1 then
    tableWidth = NAME_WIDTH + TIME_WIDTH
  end
  local scale = self.window:GetWindowScale() / 100
  if scale <= 0 then
    scale = 1
  end
  local maxBody = (UIParent:GetHeight() - SCREEN_MARGIN) / scale - LiqUI.Constants.layout.sizes.titlebar.height
  if maxBody < 22 then
    maxBody = 22
  end
  local bodyHeight = tableHeight
  if bodyHeight > maxBody then
    bodyHeight = maxBody
  end
  local width = tableWidth
  if tableHeight > bodyHeight then
    width = tableWidth + LiqUI.Constants.layout.sizes.scrollbar.thickness
  end
  self.window:SetBodySize(width, bodyHeight)
  local active = Data:GetActiveRun()
  if active and run == active then
    if self.window:GetScript("OnUpdate") ~= onPaintUpdate then
      paintRemaining = 0
      self.window:SetScript("OnUpdate", onPaintUpdate)
    end
    return
  end
  self.window:SetScript("OnUpdate", nil)
end

function Module:Follow()
  if not self.window or not self.window:IsShown() then
    return
  end
  self:Render()
end

function Module:Hide()
  if self.window then
    self.window:Hide()
  end
end

function Module:Toggle()
  if not self.window then
    self:Render()
  end
  if self.window then
    self.window:Toggle()
  end
end

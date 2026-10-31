---@class LDT_Addon
local addon = select(2, ...)

local Data = addon.Data
local Constants = addon.Constants
local Capture = addon.Capture
local LibAceAddon = addon.libs.AceAddon
local LibDataBroker = addon.libs.LibDataBroker
local LibDBIcon = addon.libs.LibDBIcon
local LiqUI = addon.libs.LiqUI
local Events = LiqUI.Events

---@class LDT_Core
local Core = LibAceAddon:NewAddon(addon.name, "AceConsole-3.0")
addon.Core = Core

function Core:OnInitialize()
  if not LiqUI or not Events or not LiqUI.Utils then
    self:Print("This version needs a newer LiqUI embed. Reload after updating LiqUI.")
    return
  end

  self:RegisterChatCommand(addon.name:lower(), "OnChatCommand")
  Data:Initialize()
  addon.logger = LiqUI:NewLogger({
    name = addon.name,
    title = addon.title,
    storage = Data.db.global.logs,
    maxLines = 10000,
  })

  ---@param displayFrame Frame
  ---@param mouseButton MouseButton
  local function onLauncherClick(displayFrame, mouseButton)
    local shifted = IsShiftKeyDown()
    if shifted then
      if addon.Module_Timer then
        addon.Module_Timer:ToggleWindow()
      end
      return
    end
    if mouseButton == "RightButton" then
      if addon.Module_Timer then
        addon.Module_Timer:OpenMenu(displayFrame)
      end
      return
    end
    if addon.Module_History then
      addon.Module_History:ToggleWindow()
    end
  end

  ---@param tooltip GameTooltip
  local function showLauncherTooltip(tooltip)
    tooltip:SetText(addon.title, 1, 1, 1)
    tooltip:AddLine("|cff00ff00Left click|r to open History.", NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b)
    tooltip:AddLine("|cff00ff00Right click|r to open timer settings.", NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b)
    tooltip:AddLine("|cff00ff00Shift click|r to show or hide the timer.", NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b)
  end

  ---@type LibDataBroker.DataObject
  local libDataObject = {
    label = addon.title,
    type = "launcher",
    icon = Constants.media.Icon,
    OnClick = onLauncherClick,
    OnTooltipShow = showLauncherTooltip,
  }
  LibDataBroker:NewDataObject(addon.name, libDataObject)
  LibDBIcon:Register(addon.name, libDataObject, Data.db.global.minimap)
  LibDBIcon:AddButtonToCompartment(addon.name)
end

function Core:OnEnable()
  if not Events then
    return
  end
  Capture:RegisterCaptureEvents()
  if addon.Log then
    addon.Log:Enable()
  end
  if addon.logger and addon.Log then
    addon.logger:Show()
  end
end

---@param input string|nil
function Core:OnChatCommand(input)
  ---@type string?
  local command = self:GetArgs(input or "", 1)
  if not command then
    self:ToggleWindow()
    return
  end
  local token = command:lower()
  if token == "log" then
    if addon.logger then
      addon.logger:Toggle()
    end
    return
  end
  if token == "history" then
    if addon.Module_History then
      addon.Module_History:ToggleWindow()
    end
    return
  end
  if addon.Debug and addon.Debug:OnChatCommand(input) then
    return
  end
  self:Print(format("Usage: /%s [history|log]", addon.name:lower()))
end

function Core:ToggleWindow()
  if not addon.Module_Timer then
    return
  end
  addon.Module_Timer:ToggleWindow()
end

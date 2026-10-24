---@class LDT_Addon
local addon = select(2, ...)

---@class LDT_Module_Timer
local Timer = addon.Core:NewModule("Timer")
addon.Module_Timer = Timer

local Data = addon.Data
local Constants = addon.Constants
local Helpers = addon.Helpers
local Capture = addon.Capture
local LiqUI = addon.libs.LiqUI
local TableForEach = LiqUI.Utils.TableForEach

local HEADER_HEIGHT = 28
local ICON_SIZE = 16
local ICON_GAP = 4
local TIME_WIDTH = 72
local COLUMN_GAP = 20
local ROW_HEIGHT = 16
local NUMBER_FONT = "Fonts\\ARIALN.TTF"

---@param color ColorRGBAData
---@param apply function
local function showColorPicker(color, apply)
  local previous = { r = color.r, g = color.g, b = color.b, a = color.a }
  local function applyPickedColor()
    ---@type number?, number?, number?
    local red, green, blue = ColorPickerFrame:GetColorRGB()
    local alpha = ColorPickerFrame:GetColorAlpha()
    if type(red) ~= "number" or type(green) ~= "number" or type(blue) ~= "number" then
      return
    end
    color.r = red
    color.g = green
    color.b = blue
    if type(alpha) == "number" then
      color.a = alpha
    end
    apply()
  end
  local function applyPickedOpacity()
    local alpha = ColorPickerFrame:GetColorAlpha()
    if type(alpha) ~= "number" then
      return
    end
    color.a = alpha
    apply()
  end
  local function restorePreviousColor()
    color.r = previous.r
    color.g = previous.g
    color.b = previous.b
    color.a = previous.a
    apply()
  end
  ---@type LiqUI_ColorPickerInfo
  local colorInfo = {
    r = color.r,
    g = color.g,
    b = color.b,
    a = color.a,
    opacity = color.a,
    hasOpacity = 1,
    swatchFunc = applyPickedColor,
    opacityFunc = applyPickedOpacity,
    cancelFunc = restorePreviousColor,
  }
  ColorPickerFrame:SetupColorPickerAndShow(colorInfo)
end

---@param owner Frame
---@param text string
local function bindTooltip(owner, text)
  owner:SetScript("OnEnter", function()
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    GameTooltip:SetText(text, 1, 1, 1)
    GameTooltip:Show()
  end)
  owner:SetScript("OnLeave", GameTooltip_Hide)
end

---@param record LDT_Record
---@param stepName string
---@return number|nil
local function bestChamberTime(record, stepName)
  local character = Data:GetCharacter()
  if not character then
    return nil
  end
  local tier = Helpers.RunTier(record)
  local mapID = record.instance and record.instance.mapID
  local best
  TableForEach(character.records, function(candidate)
    if candidate == record or candidate.result ~= Constants.runResult.Complete or not candidate.labyrinth then
      return
    end
    if tier and Helpers.RunTier(candidate) ~= tier then
      return
    end
    local candidateMap = candidate.instance and candidate.instance.mapID
    if mapID and candidateMap ~= mapID then
      return
    end
    TableForEach(candidate.chambers, function(chamber)
      if chamber.name == stepName and chamber.completedElapsed and (not best or chamber.completedElapsed < best) then
        best = chamber.completedElapsed
      end
    end)
  end)
  return best
end

function Timer:StartTicker()
  if self.ticker then
    return
  end
  self.ticker = C_Timer.NewTicker(0.1, function()
    Timer:Render()
  end)
end

function Timer:StopTicker()
  if self.ticker then
    self.ticker:Cancel()
    self.ticker = nil
  end
end

---@param rootMenu RootMenuDescriptionProxy
---@param text string
---@param color ColorRGBAData
local function addColorSwatch(rootMenu, text, color)
  rootMenu:CreateColorSwatch(text, function()
    showColorPicker(color, function()
      Timer:Render()
    end)
  end, color)
end

---@param owner Frame
function Timer:OpenMenu(owner)
  local options = Data.db.global.timer
  MenuUtil.CreateContextMenu(owner, function(_, rootMenu)
    rootMenu:CreateTitle("Timer")
    rootMenu:CreateCheckbox("Hide the objective tracker", function()
      return options.replaceTracker
    end, function()
      options.replaceTracker = not options.replaceTracker
      Capture:Sync()
    end)
    addColorSwatch(rootMenu, "Faster than best", options.aheadColor)
    addColorSwatch(rootMenu, "Slower than best", options.behindColor)
    addColorSwatch(rootMenu, "Background", options.backgroundColor)
    addColorSwatch(rootMenu, "Border", options.borderColor)
    local sizeMenu = rootMenu:CreateButton("Font size")
    local sizes = { 10, 12, 14, 16 }
    for index = 1, #sizes do
      local size = sizes[index]
      sizeMenu:CreateRadio(tostring(size), function()
        return options.fontSize == size
      end, function()
        options.fontSize = size
        Timer:Render()
      end)
    end
  end)
end

function Timer:SaveScreenPoint()
  local frame = self.frame
  if not frame then
    return
  end
  local right = frame:GetRight()
  local top = frame:GetTop()
  if not right or not top then
    return
  end
  local options = Data.db.global.timer
  options.point = "TOPRIGHT"
  options.relativePoint = "TOPRIGHT"
  options.x = right - UIParent:GetRight()
  options.y = top - UIParent:GetTop()
end

function Timer:Place()
  local frame = self.frame
  if not frame then
    return
  end
  local options = Data.db.global.timer
  frame:ClearAllPoints()
  frame:SetPoint(options.point, UIParent, options.relativePoint, options.x, options.y)
end

function Timer:Build()
  if self.frame then
    return
  end
  local options = Data.db.global.timer
  ---@type LDT_TimerFrame
  local frame = CreateFrame("Frame", addon.name .. "Timer", UIParent, "BackdropTemplate")
  frame:SetSize(280, 80)
  frame:SetPoint(options.point, UIParent, options.relativePoint, options.x, options.y)
  frame:SetMovable(true)
  frame:SetClampedToScreen(true)
  frame:SetFrameStrata("HIGH")
  self.frame = frame

  local header = CreateFrame("Button", nil, frame)
  header:SetPoint("TOPLEFT", frame, "TOPLEFT", 6, -4)
  header:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -6, -4)
  header:SetHeight(HEADER_HEIGHT)
  header:RegisterForDrag("LeftButton")
  header:SetScript("OnDragStart", function()
    frame:StartMoving()
  end)
  header:SetScript("OnDragStop", function()
    frame:StopMovingOrSizing()
    Timer:SaveScreenPoint()
  end)
  self.header = header

  local title = header:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  title:SetPoint("LEFT", header, "LEFT", 0, 0)
  title:SetJustifyH("LEFT")
  title:SetWordWrap(false)
  self.title = title

  local closeButton = CreateFrame("Button", nil, header)
  closeButton:SetSize(ICON_SIZE, ICON_SIZE)
  closeButton:SetPoint("RIGHT", header, "RIGHT", 0, 0)
  local closeIcon = closeButton:CreateTexture(nil, "ARTWORK")
  closeIcon:SetAllPoints()
  closeIcon:SetAtlas("common-search-clearbutton")
  closeButton:SetScript("OnClick", function()
    Capture.timerFromGame = false
    frame:Hide()
  end)
  bindTooltip(closeButton, "Close")

  local settingsButton = CreateFrame("DropdownButton", nil, header)
  settingsButton:SetSize(ICON_SIZE, ICON_SIZE)
  settingsButton:SetPoint("RIGHT", closeButton, "LEFT", -ICON_GAP, 0)
  local settingsIcon = settingsButton:CreateTexture(nil, "ARTWORK")
  settingsIcon:SetAllPoints()
  settingsIcon:SetTexture(LiqUI.Constants.layout.media.iconSettings)
  settingsButton:SetScript("OnClick", function()
    Timer:OpenMenu(settingsButton)
  end)
  bindTooltip(settingsButton, "Settings")

  local recordsButton = CreateFrame("Button", nil, header)
  recordsButton:SetSize(ICON_SIZE, ICON_SIZE)
  recordsButton:SetPoint("RIGHT", settingsButton, "LEFT", -ICON_GAP, 0)
  local recordsIcon = recordsButton:CreateTexture(nil, "ARTWORK")
  recordsIcon:SetAllPoints()
  recordsIcon:SetTexture(Constants.media.Icon)
  recordsButton:SetScript("OnClick", function()
    if addon.Module_Records then
      addon.Module_Records:ToggleWindow()
    end
  end)
  bindTooltip(recordsButton, "Records")

  local reportButton = CreateFrame("Button", nil, header)
  reportButton:SetSize(ICON_SIZE, ICON_SIZE)
  reportButton:SetPoint("RIGHT", recordsButton, "LEFT", -ICON_GAP, 0)
  local reportIcon = reportButton:CreateTexture(nil, "ARTWORK")
  reportIcon:SetAllPoints()
  reportIcon:SetAtlas("poi-door-arrow-down")
  reportButton:SetScript("OnClick", function()
    if addon.Module_Report then
      addon.Module_Report:ShowRecord(Data:GetActiveRecord())
    end
  end)
  bindTooltip(reportButton, "Report")

  local deaths = header:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  deaths:SetPoint("RIGHT", reportButton, "LEFT", -8, 0)
  deaths:SetJustifyH("RIGHT")
  self.deaths = deaths
  title:SetPoint("RIGHT", deaths, "LEFT", -8, 0)

  local spells = CreateFrame("Frame", nil, frame)
  spells:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -2)
  spells:SetPoint("TOPRIGHT", header, "BOTTOMRIGHT", 0, -2)
  spells:SetHeight(ICON_SIZE)
  self.spells = spells
  ---@type LDT_TimerSpell[]
  self.spellButtons = {}

  local clock = frame:CreateFontString(nil, "OVERLAY")
  clock:SetJustifyH("LEFT")
  self.clock = clock

  local phrase = frame:CreateFontString(nil, "OVERLAY")
  phrase:SetJustifyH("LEFT")
  self.phrase = phrase

  local timeHeader = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  timeHeader:SetJustifyH("RIGHT")
  timeHeader:SetText("Time")
  self.timeHeader = timeHeader

  local bestHeader = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  bestHeader:SetJustifyH("RIGHT")
  bestHeader:SetText("Best")
  self.bestHeader = bestHeader

  ---@type LDT_TimerRow[]
  self.rows = {}

  frame:SetScript("OnShow", function()
    Timer:Place()
    Timer:StartTicker()
    Timer:Render()
  end)
  frame:SetScript("OnHide", function()
    Timer:StopTicker()
  end)
end

---@param parent Frame
---@return LDT_TimerRow
function Timer:CreateRow(parent)
  local highlight = parent:CreateTexture(nil, "BACKGROUND")
  highlight:SetColorTexture(1, 1, 1, 0.06)
  highlight:Hide()
  local name = parent:CreateFontString(nil, "OVERLAY")
  name:SetJustifyH("LEFT")
  name:SetWordWrap(false)
  local timeText = parent:CreateFontString(nil, "OVERLAY")
  timeText:SetJustifyH("RIGHT")
  local bestText = parent:CreateFontString(nil, "OVERLAY")
  bestText:SetJustifyH("RIGHT")
  ---@type LDT_TimerRow
  local row = {
    name = name,
    time = timeText,
    best = bestText,
    highlight = highlight,
  }
  return row
end

---@param record LDT_Record
---@return { name: string, elapsed: number|nil, best: number|nil, current: boolean }[]
function Timer:StepRows(record)
  ---@type { name: string, elapsed: number|nil, best: number|nil, current: boolean }[]
  local rows = {}
  if record.labyrinth then
    local currentName = record.watch and record.watch.routeStep
    local chambers = record.chambers or {}
    for index = 1, #chambers do
      local chamber = chambers[index]
      rows[#rows + 1] = {
        name = chamber.name,
        elapsed = chamber.completedElapsed,
        best = bestChamberTime(record, chamber.name),
        current = chamber.name == currentName and chamber.completedElapsed == nil,
      }
    end
    return rows
  end
  local route
  if record.routeID then
    route = Data.db.global.routes[record.routeID]
  end
  ---@type string[]
  local steps = {}
  if route then
    steps = route.steps
  end
  local currentName = record.watch and record.watch.routeStep
  for index = 1, #steps do
    local stepName = steps[index]
    local elapsed = record.splits and record.splits[stepName]
    rows[#rows + 1] = {
      name = stepName,
      elapsed = elapsed,
      best = Data:BestSplit(record, stepName),
      current = stepName == currentName and elapsed == nil,
    }
  end
  return rows
end

---@param preview LDT_Preview
---@return { name: string, elapsed: number|nil, best: number|nil, current: boolean }[]
function Timer:PreviewRows(preview)
  ---@type { name: string, elapsed: number|nil, best: number|nil, current: boolean }[]
  local rows = {}
  local route
  if preview.routeID then
    route = Data.db.global.routes[preview.routeID]
  end
  ---@type string[]
  local steps = {}
  if route then
    steps = route.steps
  end
  for index = 1, #steps do
    local stepName = steps[index]
    rows[#rows + 1] = {
      name = stepName,
      elapsed = nil,
      best = Data:BestSplitFor(preview.routeID, preview.tier, stepName),
      current = false,
    }
  end
  return rows
end

function Timer:Render()
  self:Build()
  local frame = self.frame
  if not frame or not frame:IsShown() then
    return
  end
  local titleText = self.title
  local deathsText = self.deaths
  local spells = self.spells
  local spellButtons = self.spellButtons
  local clock = self.clock
  local phrase = self.phrase
  local timeHeader = self.timeHeader
  local bestHeader = self.bestHeader
  local rows = self.rows
  if not titleText or not deathsText or not spells or not spellButtons or not clock or not phrase or not timeHeader or not bestHeader or not rows then
    return
  end
  local options = Data.db.global.timer
  local inside = Capture:IsInside() or Capture:InInstance()
  local record = inside and Data:GetActiveRecord() or nil
  local preview = (not record) and Capture.preview or nil
  local fontSize = options.fontSize or 12
  local background = options.backgroundColor or { r = 0, g = 0, b = 0, a = 0.5 }
  local border = options.borderColor or { r = 0, g = 0, b = 0, a = 0 }
  frame:SetBackdrop({
    bgFile = "Interface/Buttons/WHITE8X8",
    edgeFile = "Interface/Buttons/WHITE8X8",
    edgeSize = 1,
  })
  frame:SetBackdropColor(background.r, background.g, background.b, background.a)
  frame:SetBackdropBorderColor(border.r, border.g, border.b, border.a)

  local title = "Delve"
  if record then
    local delve = record.instance and record.instance.name
    if not delve or delve == "" then
      delve = record.place and (record.place.subzone or record.place.zone) or "Delve"
    end
    local tier = Helpers.RunTier(record)
    if tier then
      title = format("%s  Tier %d", delve, tier)
    else
      title = delve
    end
    deathsText:SetText(format("Deaths %d", record.deaths or 0))
  elseif preview then
    local delve = preview.name or "Delve"
    if preview.variant then
      delve = format("%s  %s", delve, preview.variant)
    end
    if preview.tier then
      title = format("%s  Tier %d", delve, preview.tier)
    else
      title = delve
    end
    deathsText:SetText("")
  else
    deathsText:SetText("")
  end
  titleText:SetText(title)
  deathsText:SetFont(NUMBER_FONT, fontSize, "")

  local spellIDs = {}
  if record and record.entrance and record.entrance.activeSpellIDs then
    spellIDs = record.entrance.activeSpellIDs
  elseif preview and preview.activeSpellIDs then
    spellIDs = preview.activeSpellIDs
  end
  local spellCount = 0
  for index = 1, #spellIDs do
    local spellID = spellIDs[index]
    if spellID and not issecretvalue(spellID) then
      local texture = C_Spell.GetSpellTexture(spellID)
      if texture and not issecretvalue(texture) then
        spellCount = spellCount + 1
        local spell = spellButtons[spellCount]
        if not spell then
          local button = CreateFrame("Button", nil, spells)
          button:SetSize(ICON_SIZE, ICON_SIZE)
          local icon = button:CreateTexture(nil, "ARTWORK")
          icon:SetAllPoints()
          ---@type LDT_TimerSpell
          spell = { button = button, icon = icon }
          do
            local bound = spell
            button:SetScript("OnEnter", function()
              if not bound.spellID or issecretvalue(bound.spellID) then
                return
              end
              GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
              GameTooltip:SetSpellByID(bound.spellID)
              GameTooltip:Show()
            end)
          end
          button:SetScript("OnLeave", GameTooltip_Hide)
          spellButtons[spellCount] = spell
        end
        spell.spellID = spellID
        spell.icon:SetTexture(texture)
        spell.button:ClearAllPoints()
        spell.button:SetPoint("LEFT", spells, "LEFT", (spellCount - 1) * (ICON_SIZE + 4), 0)
        spell.button:Show()
      end
    end
  end
  for index = spellCount + 1, #spellButtons do
    spellButtons[index].button:Hide()
  end
  local spellHeight = 0
  if spellCount > 0 then
    spellHeight = ICON_SIZE + 6
  end
  spells:SetHeight(math.max(spellHeight, 1))

  local clockSize = fontSize + 8
  clock:SetFont(NUMBER_FONT, clockSize, "")
  phrase:SetFont(NUMBER_FONT, fontSize, "")
  timeHeader:SetFont(NUMBER_FONT, fontSize, "")
  bestHeader:SetFont(NUMBER_FONT, fontSize, "")
  timeHeader:SetTextColor(0.7, 0.7, 0.7)
  bestHeader:SetTextColor(0.7, 0.7, 0.7)

  local clockValue
  local phraseText
  local phraseColor = options.aheadColor
  if not phraseColor then
    phraseColor = { r = 0.2, g = 1, b = 0.2, a = 1 }
  end
  if record and Capture.clockReady then
    local frozen = record.finishedElapsed or record.bossElapsed
    if frozen then
      clockValue = Helpers.CompletionTime(record) or frozen
    elseif record.result == Constants.runResult.Active then
      clockValue = Capture:Elapsed(record)
    else
      clockValue = record.endedElapsed
    end
    local compare
    if frozen then
      local bestRun = Helpers.BestRun(record)
      compare = bestRun and Helpers.CompletionTime(bestRun) or nil
    elseif record.watch and record.watch.routeStep then
      compare = Data:BestSplit(record, record.watch.routeStep)
    end
    if clockValue and compare then
      local gap = compare - clockValue
      if gap >= 0 then
        phraseText = format("%s faster", Helpers.FormatElapsed(gap))
        phraseColor = options.aheadColor
      else
        phraseText = format("%s slower", Helpers.FormatElapsed(-gap))
        phraseColor = options.behindColor
      end
    end
  elseif preview and preview.bestFinish then
    clockValue = preview.bestFinish
  end
  if clockValue then
    clock:SetText(Helpers.FormatElapsed(clockValue))
  elseif preview then
    clock:SetText("")
  else
    clock:SetText("0:00.0")
  end
  phrase:SetText(phraseText or "")
  phrase:SetTextColor(phraseColor.r, phraseColor.g, phraseColor.b, phraseColor.a)

  local rightPad = 8
  local bestRight = -rightPad
  local timeRight = -(rightPad + TIME_WIDTH + COLUMN_GAP)
  local nameRight = timeRight - TIME_WIDTH - 8
  local clockY = -(4 + HEADER_HEIGHT + spellHeight)
  clock:ClearAllPoints()
  clock:SetPoint("TOPLEFT", frame, "TOPLEFT", 8, clockY)
  phrase:ClearAllPoints()
  phrase:SetPoint("LEFT", clock, "RIGHT", 12, 0)
  local headerY = clockY - clockSize - 6
  timeHeader:ClearAllPoints()
  timeHeader:SetPoint("TOPRIGHT", frame, "TOPRIGHT", timeRight, headerY)
  timeHeader:SetWidth(TIME_WIDTH)
  bestHeader:ClearAllPoints()
  bestHeader:SetPoint("TOPRIGHT", frame, "TOPRIGHT", bestRight, headerY)
  bestHeader:SetWidth(TIME_WIDTH)

  local stepRows = {}
  if record then
    stepRows = self:StepRows(record)
  elseif preview then
    stepRows = self:PreviewRows(preview)
  end
  local y = headerY - fontSize - 2
  for index = 1, #stepRows do
    local model = stepRows[index]
    local row = rows[index]
    if not row then
      row = self:CreateRow(frame)
      rows[index] = row
    end
    row.name:SetFont(NUMBER_FONT, fontSize, "")
    row.time:SetFont(NUMBER_FONT, fontSize, "")
    row.best:SetFont(NUMBER_FONT, fontSize, "")
    row.name:SetText(model.name)
    if model.current then
      row.name:SetTextColor(1, 0.82, 0)
    else
      row.name:SetTextColor(0.9, 0.9, 0.9)
    end
    if model.elapsed then
      row.time:SetText(Helpers.FormatElapsed(model.elapsed))
      if model.best and model.elapsed < model.best - 0.05 then
        row.time:SetTextColor(options.aheadColor.r, options.aheadColor.g, options.aheadColor.b)
      elseif model.best and model.elapsed > model.best + 0.05 then
        row.time:SetTextColor(options.behindColor.r, options.behindColor.g, options.behindColor.b)
      else
        row.time:SetTextColor(0.95, 0.95, 0.95)
      end
    else
      row.time:SetText("")
    end
    if model.best then
      row.best:SetText(Helpers.FormatElapsed(model.best))
      row.best:SetTextColor(0.55, 0.55, 0.55)
    else
      row.best:SetText("")
    end
    row.highlight:ClearAllPoints()
    row.highlight:SetPoint("TOPLEFT", frame, "TOPLEFT", 4, y)
    row.highlight:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -4, y)
    row.highlight:SetHeight(ROW_HEIGHT)
    if model.current then
      row.highlight:Show()
    else
      row.highlight:Hide()
    end
    row.name:ClearAllPoints()
    row.name:SetPoint("TOPLEFT", frame, "TOPLEFT", 8, y)
    row.name:SetPoint("TOPRIGHT", frame, "TOPRIGHT", nameRight, y)
    row.name:SetHeight(ROW_HEIGHT)
    row.best:ClearAllPoints()
    row.best:SetPoint("TOPRIGHT", frame, "TOPRIGHT", bestRight, y)
    row.best:SetWidth(TIME_WIDTH)
    row.best:SetHeight(ROW_HEIGHT)
    row.time:ClearAllPoints()
    row.time:SetPoint("TOPRIGHT", frame, "TOPRIGHT", timeRight, y)
    row.time:SetWidth(TIME_WIDTH)
    row.time:SetHeight(ROW_HEIGHT)
    row.name:Show()
    row.time:Show()
    row.best:Show()
    y = y - ROW_HEIGHT
  end
  for index = #stepRows + 1, #rows do
    local row = rows[index]
    row.name:Hide()
    row.time:Hide()
    row.best:Hide()
    row.highlight:Hide()
  end
  frame:SetWidth(280)
  frame:SetHeight(math.max(80, -y + 8))
end

function Timer:ShowRun()
  self:Build()
  if not self.frame or self.frame:IsShown() then
    return
  end
  self.frame:Show()
  self.frame:Raise()
end

function Timer:HideRun()
  if self.frame then
    self.frame:Hide()
  end
end

function Timer:ToggleWindow()
  self:Build()
  if not self.frame then
    return
  end
  if self.frame:IsShown() then
    self.frame:Hide()
    return
  end
  self.frame:Show()
end

function Timer:OnEnable()
end

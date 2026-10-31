---@class LDT_Addon
local addon = select(2, ...)

---@class LDT_Module_Timer
local Timer = addon.Core:NewModule("Timer")
addon.Module_Timer = Timer

local Data = addon.Data
local Constants = addon.Constants
local Helpers = addon.Helpers
local FormatElapsed = Helpers.FormatElapsed
local RoundShownDelta = Helpers.RoundShownDelta
local GetDeltaColor = Helpers.GetDeltaColor
local FormatDelta = Helpers.FormatDelta
local GetTier = Helpers.GetTier
local RoundIcon = Helpers.RoundIcon
local GetDuration = Helpers.GetDuration
local Capture = addon.Capture

local trackerHooked = false

---@param icon Texture
---@param text FontString
---@param atlas string
---@param count number|nil
---@param anchor Region
---@param point string
---@param offsetX number
---@return Region
---@return string
---@return number
local function placeCount(icon, text, atlas, count, anchor, point, offsetX)
  text:SetFont(Constants.media.NumberFont, Constants.sizes.timer.metaFont, "")
  icon:ClearAllPoints()
  text:ClearAllPoints()
  if count == nil then
    icon:Hide()
    text:Hide()
    return anchor, point, offsetX
  end
  icon:SetAtlas(atlas)
  icon:Show()
  text:SetText(tostring(count))
  text:Show()
  icon:SetPoint("LEFT", anchor, point, offsetX, 0)
  text:SetPoint("LEFT", icon, "RIGHT", Constants.sizes.timer.iconGap, 0)
  return text, "RIGHT", Constants.sizes.timer.iconGap
end

---@param color ColorRGBAData
---@param repaint function
local function showColorPicker(color, repaint)
  local previous = { r = color.r, g = color.g, b = color.b, a = color.a }
  local function setPickedColor()
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
    repaint()
  end
  local function setPickedOpacity()
    local alpha = ColorPickerFrame:GetColorAlpha()
    if type(alpha) ~= "number" then
      return
    end
    color.a = alpha
    repaint()
  end
  local function restorePreviousColor()
    color.r = previous.r
    color.g = previous.g
    color.b = previous.b
    color.a = previous.a
    repaint()
  end
  ---@type LiqUI_ColorPickerInfo
  local colorInfo = {
    r = color.r,
    g = color.g,
    b = color.b,
    a = color.a,
    opacity = color.a,
    hasOpacity = 1,
    swatchFunc = setPickedColor,
    opacityFunc = setPickedOpacity,
    cancelFunc = restorePreviousColor,
  }
  ColorPickerFrame:SetupColorPickerAndShow(colorInfo)
end

local paintRemaining = 0
local placedOnTracker = false

---@return number|nil
---@return number|nil
local function trackerCorner()
  local tracker = _G.ObjectiveTrackerFrame
  if not tracker then
    return nil, nil
  end
  local right = tracker:GetRight()
  local top = tracker:GetTop()
  if not right or not top then
    return nil, nil
  end
  return right, top
end

---@param percent number
---@return boolean
local function timerScaleIsSelected(percent)
  return (Data.db.global.timer.scale or 100) == percent
end

---@param percent number
local function selectTimerScale(percent)
  Data.db.global.timer.scale = percent
  Timer:Place()
  Timer:Render()
end

---@param _frame Frame
---@param elapsed number
local function onPaintUpdate(_frame, elapsed)
  paintRemaining = paintRemaining - elapsed
  if paintRemaining > 0 then
    return
  end
  paintRemaining = Constants.timing.paint
  if not placedOnTracker and not Data.db.global.timer.point then
    Timer:Place()
  end
  Timer:Render()
end

---@param fontString FontString
---@param size number
local function setFontSize(fontString, size)
  local face, _, flags = fontString:GetFont()
  if not face then
    face = Constants.media.NumberFont
    flags = ""
  end
  fontString:SetFont(face, size, flags)
end

---@param fontSize number
---@return number
local function textLineHeight(fontSize)
  local height = fontSize + 6
  if height < Constants.sizes.timer.lineHeight then
    return Constants.sizes.timer.lineHeight
  end
  return height
end

---@param fontSize number
---@return number
local function splitBarHeight(fontSize)
  local height = fontSize + 14
  if height < Constants.sizes.timer.rowHeight then
    return Constants.sizes.timer.rowHeight
  end
  return height
end

local HEADER_FONT_SIZES = { 12, 14, 15, 16, 18, 20 }
local BODY_FONT_SIZES = { 10, 12, 13, 14, 15, 16, 18 }
local CLOCK_FONT_SIZES = { 16, 18, 20, 22, 24, 28, 32 }

---@param owner Frame
local function showHeaderTooltip(owner)
  GameTooltip:SetOwner(owner, "ANCHOR_TOP")
  GameTooltip:SetText("Timer", 1, 1, 1)
  GameTooltip:AddLine("|cff00ff00Left click|r to drag.", NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b)
  GameTooltip:AddLine("|cff00ff00Right click|r to open settings.", NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b)
  GameTooltip:AddLine("|cff00ff00Shift click|r to open the run details.", NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b)
  GameTooltip:Show()
end

---@param rootMenu RootMenuDescriptionProxy|ElementMenuDescriptionProxy
---@param text string
---@param color ColorRGBAData
local function addColorSwatch(rootMenu, text, color)
  rootMenu:CreateColorSwatch(text, function()
    showColorPicker(color, function()
      Timer:Render()
    end)
  end, color)
end

---@param color ColorRGBAData
---@param default ColorRGBAData
local function restoreColor(color, default)
  color.r = default.r
  color.g = default.g
  color.b = default.b
  color.a = default.a
end

local function resetTimerColors()
  local options = Data.db.global.timer
  restoreColor(options.aheadColor, Constants.colors.ahead)
  restoreColor(options.behindColor, Constants.colors.behind)
  restoreColor(options.windowBackgroundColor, Constants.colors.windowBackground)
  restoreColor(options.borderColor, Constants.colors.border)
  restoreColor(options.headerBackgroundColor, Constants.colors.headerBackground)
  restoreColor(options.clockBackgroundColor, Constants.colors.clockBackground)
  restoreColor(options.stripeColor, Constants.colors.stripe)
  restoreColor(options.activeRowColor, Constants.colors.activeRow)
  restoreColor(options.headerTextColor, Constants.colors.titleText)
  restoreColor(options.columnTextColor, Constants.colors.columnText)
  restoreColor(options.splitTextColor, Constants.colors.splitText)
  restoreColor(options.stepTextColor, Constants.colors.step)
  restoreColor(options.objectiveTextColor, Constants.colors.objective)
  restoreColor(options.objectiveDoneTextColor, Constants.colors.objectiveDone)
  restoreColor(options.clockTextColor, Constants.colors.clockText)
  options.headerFontSize = Constants.sizes.timer.titleFont
  options.splitFontSize = Constants.sizes.timer.splitFont
  options.stepFontSize = Constants.sizes.timer.stepFont
  options.objectiveFontSize = Constants.sizes.timer.objectiveFont
  options.clockFontSize = Constants.sizes.timer.clockFont
  Timer:Render()
end

local resetColorsDialog = addon.name:upper() .. "_RESET_COLORS"

do
  ---@type LDT_ResetColorsStaticPopupDialog
  local dialog = {
    text = "Reset colors and text sizes?",
    button1 = YES,
    button2 = CANCEL,
    OnAccept = resetTimerColors,
    timeout = 0,
    whileDead = 1,
    hideOnEscape = 1,
  }
  StaticPopupDialogs[resetColorsDialog] = dialog
end

local function confirmResetTimerColors()
  StaticPopup_Show(resetColorsDialog)
end

---@param parent RootMenuDescriptionProxy|ElementMenuDescriptionProxy
---@param label string
---@param key "headerFontSize"|"splitFontSize"|"stepFontSize"|"objectiveFontSize"|"clockFontSize"
---@param sizes number[]
---@param fallback number
local function addFontSizes(parent, label, key, sizes, fallback)
  local sizeMenu = parent:CreateButton(label)
  for index = 1, #sizes do
    local size = sizes[index]
    sizeMenu:CreateRadio(tostring(size), function()
      local stored = Data.db.global.timer[key]
      if type(stored) ~= "number" then
        stored = fallback
      end
      return stored == size
    end, function()
      Data.db.global.timer[key] = size
      Timer:Render()
    end)
  end
end

---@param parent RootMenuDescriptionProxy|ElementMenuDescriptionProxy
---@param label string
---@param color ColorRGBAData
---@param sizeKey "headerFontSize"|"splitFontSize"|"stepFontSize"|"objectiveFontSize"|"clockFontSize"
---@param sizes number[]
---@param fallback number
local function addTextStyle(parent, label, color, sizeKey, sizes, fallback)
  local styleMenu = parent:CreateButton(label)
  addColorSwatch(styleMenu, "Color", color)
  addFontSizes(styleMenu, "Size", sizeKey, sizes, fallback)
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
      Timer:Render()
    end)
    rootMenu:CreateCheckbox("Show objective count", function()
      return options.showObjectiveCounts == true
    end, function()
      options.showObjectiveCounts = options.showObjectiveCounts ~= true
      Timer:Render()
    end)
    rootMenu:CreateCheckbox("Show objective steps", function()
      return options.showObjectives ~= false
    end, function()
      options.showObjectives = options.showObjectives == false
      Timer:Render()
    end)
    rootMenu:CreateCheckbox("Automatically open chambers", function()
      return options.autoOpenChambers ~= false
    end, function()
      options.autoOpenChambers = options.autoOpenChambers == false
    end)
    local textMenu = rootMenu:CreateButton("Text")
    addTextStyle(textMenu, "Header", options.headerTextColor, "headerFontSize", HEADER_FONT_SIZES, Constants.sizes.timer.titleFont)
    addColorSwatch(textMenu, "Columns", options.columnTextColor)
    addTextStyle(textMenu, "Splits", options.splitTextColor, "splitFontSize", BODY_FONT_SIZES, Constants.sizes.timer.splitFont)
    addTextStyle(textMenu, "Steps", options.stepTextColor, "stepFontSize", BODY_FONT_SIZES, Constants.sizes.timer.stepFont)
    local objectiveMenu = textMenu:CreateButton("Objectives")
    addColorSwatch(objectiveMenu, "Color", options.objectiveTextColor)
    addColorSwatch(objectiveMenu, "Finished", options.objectiveDoneTextColor)
    addFontSizes(objectiveMenu, "Size", "objectiveFontSize", BODY_FONT_SIZES, Constants.sizes.timer.objectiveFont)
    addTextStyle(textMenu, "Clock", options.clockTextColor, "clockFontSize", CLOCK_FONT_SIZES, Constants.sizes.timer.clockFont)
    addColorSwatch(rootMenu, "Faster than best", options.aheadColor)
    addColorSwatch(rootMenu, "Slower than best", options.behindColor)
    addColorSwatch(rootMenu, "Background", options.windowBackgroundColor)
    addColorSwatch(rootMenu, "Border", options.borderColor)
    addColorSwatch(rootMenu, "Header background", options.headerBackgroundColor)
    addColorSwatch(rootMenu, "Clock background", options.clockBackgroundColor)
    addColorSwatch(rootMenu, "Stripe", options.stripeColor)
    addColorSwatch(rootMenu, "Active step", options.activeRowColor)
    local timerScale = rootMenu:CreateButton("Scaling")
    for scalePercent = Constants.timerScale.min, Constants.timerScale.max, Constants.timerScale.step do
      timerScale:CreateRadio(scalePercent .. "%", timerScaleIsSelected, selectTimerScale, scalePercent)
    end
    rootMenu:CreateButton("Reset colors and text sizes", confirmResetTimerColors)
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
  local scale = frame:GetScale()
  if not scale or scale == 0 then
    scale = 1
  end
  local storedX = right * scale - UIParent:GetWidth()
  local storedY = top * scale - UIParent:GetHeight()
  local options = Data.db.global.timer
  ---@type LiqUI_WindowPointPersisted
  local savedPoint = { "TOPRIGHT", "TOPRIGHT", storedX, storedY }
  options.point = savedPoint
  options.scale = math.floor(scale * 100 + 0.5)
  frame:ClearAllPoints()
  frame:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", storedX / scale, storedY / scale)
end

---@param frame Frame
local function updateTimerClampInsets(frame)
  local width = frame:GetWidth()
  local height = frame:GetHeight()
  frame:SetClampRectInsets(width / 2, -width / 2, 0, height / 2)
end

function Timer:Place()
  local frame = self.frame
  if not frame then
    return
  end
  local options = Data.db.global.timer
  local scale = (options.scale or 100) / 100
  if scale <= 0 then
    scale = 1
  end
  local savedPoint = options.point
  local offsetX
  local offsetY
  if savedPoint and type(savedPoint[3]) == "number" and type(savedPoint[4]) == "number" then
    offsetX = savedPoint[3] / scale
    offsetY = savedPoint[4] / scale
  else
    if frame:IsDragging() then
      return
    end
    local trackerRight, trackerTop = trackerCorner()
    if not trackerRight or not trackerTop then
      return
    end
    offsetX = trackerRight - UIParent:GetWidth() / scale
    offsetY = trackerTop - UIParent:GetHeight() / scale
    placedOnTracker = true
  end
  frame:SetScale(scale)
  frame:ClearAllPoints()
  frame:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", offsetX, offsetY)
end

---Show or hide the timer. fromGame true means Capture owns auto-hide on leave.
---@param shown boolean
---@param fromGame boolean|nil
function Timer:SetFrameShown(shown, fromGame)
  if not self.frame then
    self:Render()
  end
  local frame = self.frame
  if not frame then
    return
  end
  if shown then
    if fromGame then
      if not frame:IsShown() then
        Capture.timerFromGame = true
      end
    else
      Capture.timerFromGame = false
    end
    frame:Show()
    frame:Raise()
    return
  end
  if not fromGame then
    Capture.timerFromGame = false
  end
  frame:Hide()
end

local SAMPLE_NAME = "The Shadow Enclave"
local SAMPLE_TIER = 11
local SAMPLE_DEATHS = 1
local SAMPLE_LIVES = 4
local SAMPLE_SPELLS = { 1279443, 1307638, 462940 }
local SAMPLE_CLOCK = 154000

---@param nodes LDT_TimerNode[]
---@return number|nil
local function findCurrentBest(nodes)
  for index = 1, #nodes do
    local node = nodes[index]
    if node.current then
      return node.best
    end
  end
  return nil
end

---@return LDT_TimerNode[]
local function buildSampleRows()
  ---@type LDT_TimerNode[]
  local rows = {}
  ---@type LDT_TimerNode
  local rowOne = { name = "Stage 1", elapsed = 84200, best = 90000, current = false, done = 1, total = 1 }
  ---@type LDT_TimerLine
  local openGate = { text = "(1/1) Open the gate", completed = true }
  ---@type LDT_TimerLine
  local cultists = { text = "(1/3) Kill the cultists", completed = false }
  ---@type LDT_TimerLine
  local ritual = { text = "(40%) Disrupt the ritual", completed = false }
  ---@type LDT_TimerLine[]
  local sampleLines = { openGate, cultists, ritual }
  ---@type LDT_TimerNode
  local rowTwo = {
    name = "Stage 2",
    elapsed = nil,
    best = 160000,
    current = true,
    lines = sampleLines,
    done = 0,
    total = 3,
  }
  ---@type LDT_TimerNode
  local rowThree = { name = "Stage 3", elapsed = nil, best = 230000, current = false, done = 0, total = 2 }
  ---@type LDT_TimerNode
  local rowFour = { name = "Stage 4", elapsed = nil, best = 310000, current = false, done = 0, total = 1 }
  ---@type LDT_TimerNode
  local rowFive = { name = "Stage 5", elapsed = nil, best = 390000, current = false, done = 0, total = 4 }
  rows[1] = rowOne
  rows[2] = rowTwo
  rows[3] = rowThree
  rows[4] = rowFour
  rows[5] = rowFive
  return rows
end

---@param name string
---@param done number|nil
---@param total number|nil
---@param showCounts boolean
---@return string
local function formatSplitLabel(name, done, total, showCounts)
  if not showCounts or total == nil or total < 1 then
    return name
  end
  return format("%s (%d/%d)", name, done or 0, total)
end

---@param fontString FontString
---@param parent Frame
---@param column integer
---@param align "LEFT"|"RIGHT"
---@param rowHeight number
local function placeColumn(fontString, parent, column, align, rowHeight)
  local x = Constants.sizes.timer.columnX[column] or 0
  local width = Constants.sizes.timer.columnWidth[column] or 0
  fontString:ClearAllPoints()
  fontString:SetWidth(width - Constants.sizes.timer.padding * 2)
  fontString:SetJustifyH(align)
  fontString:SetWordWrap(false)
  if align == "RIGHT" then
    fontString:SetPoint("RIGHT", parent, "TOPLEFT", x + width - Constants.sizes.timer.padding, -rowHeight / 2)
  else
    fontString:SetPoint("LEFT", parent, "TOPLEFT", x + Constants.sizes.timer.padding, -rowHeight / 2)
  end
end

---@param rows LDT_TimerSplitRow[]
---@param index integer
---@param parent Frame
---@return LDT_TimerSplitRow
local function createSplitRow(rows, index, parent)
  local existing = rows[index]
  if existing then
    return existing
  end
  local frame = CreateFrame("Frame", nil, parent)
  local bar = CreateFrame("Frame", nil, frame)
  bar:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
  bar:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
  bar:SetHeight(Constants.sizes.timer.rowHeight)
  local background = bar:CreateTexture(nil, "BACKGROUND")
  background:SetAllPoints()
  local highlight = bar:CreateTexture(nil, "ARTWORK")
  highlight:SetAllPoints()
  highlight:Hide()
  local name = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  local delta = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  local time = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  local best = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  placeColumn(name, bar, 1, "LEFT", Constants.sizes.timer.rowHeight)
  placeColumn(delta, bar, 2, "RIGHT", Constants.sizes.timer.rowHeight)
  placeColumn(time, bar, 3, "RIGHT", Constants.sizes.timer.rowHeight)
  placeColumn(best, bar, 4, "RIGHT", Constants.sizes.timer.rowHeight)
  local detail = CreateFrame("Frame", nil, frame)
  detail:SetPoint("TOPLEFT", bar, "BOTTOMLEFT", 0, 0)
  detail:SetPoint("TOPRIGHT", bar, "BOTTOMRIGHT", 0, 0)
  ---@type LDT_TimerDetailLine[]
  local lines = {}
  ---@type LDT_TimerSplitRow
  local row = {
    frame = frame,
    bar = bar,
    background = background,
    highlight = highlight,
    name = name,
    delta = delta,
    time = time,
    best = best,
    detail = detail,
    lines = lines,
  }
  rows[index] = row
  return row
end

---@param row LDT_TimerSplitRow
---@param index integer
---@return LDT_TimerDetailLine
local function createDetailLine(row, index)
  local existing = row.lines[index]
  if existing then
    return existing
  end
  local frame = CreateFrame("Frame", nil, row.detail)
  local icon = frame:CreateTexture(nil, "OVERLAY")
  icon:SetSize(Constants.sizes.timer.markSize, Constants.sizes.timer.markSize)
  local text = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  local time = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  ---@type LDT_TimerDetailLine
  local line = {
    frame = frame,
    icon = icon,
    text = text,
    time = time,
  }
  row.lines[index] = line
  return line
end

---@param line LDT_TimerDetailLine
---@param detail Frame
---@param label string
---@param title string|nil
---@param offsetY number
local function paintNode(line, detail, label, title, offsetY)
  local frame = line.frame
  frame:SetScript("OnEnter", nil)
  frame:SetScript("OnLeave", nil)
  frame:EnableMouse(false)
  frame:ClearAllPoints()
  frame:SetPoint("TOPLEFT", detail, "TOPLEFT", 0, -offsetY)
  frame:SetPoint("TOPRIGHT", detail, "TOPRIGHT", 0, -offsetY)
  frame:SetHeight(textLineHeight(Data.db.global.timer.stepFontSize))
  local icon = line.icon
  icon:ClearAllPoints()
  icon:SetSize(Constants.sizes.timer.markSize, Constants.sizes.timer.markSize)
  icon:SetPoint("LEFT", frame, "LEFT", Constants.sizes.timer.nodeIndent, 0)
  icon:SetAtlas(Constants.media.MarkNub)
  local stepColor = Data.db.global.timer.stepTextColor
  icon:SetVertexColor(stepColor.r, stepColor.g, stepColor.b)
  icon:Show()
  local textLeft = Constants.sizes.timer.nodeIndent + Constants.sizes.timer.markSize + Constants.sizes.timer.markGap
  local shown = label
  if title and title ~= "" then
    shown = format("%s: %s", label, WHITE_FONT_COLOR:WrapTextInColorCode(title))
  end
  local text = line.text
  setFontSize(text, Data.db.global.timer.stepFontSize)
  text:SetTextColor(stepColor.r, stepColor.g, stepColor.b)
  text:SetWordWrap(false)
  text:SetJustifyH("LEFT")
  text:SetJustifyV("MIDDLE")
  text:ClearAllPoints()
  text:SetPoint("LEFT", frame, "LEFT", textLeft, 0)
  text:SetWidth(Constants.sizes.timer.width - textLeft - Constants.sizes.timer.padding)
  text:SetText(shown)
  line.time:Hide()
  frame:Show()
end

---@param line LDT_TimerDetailLine
---@param detail Frame
---@param entry LDT_TimerLine
---@param offsetY number
---@param indent number
---@return number
local function paintLine(line, detail, entry, offsetY, indent)
  local frame = line.frame
  frame:ClearAllPoints()
  frame:SetPoint("TOPLEFT", detail, "TOPLEFT", 0, -offsetY)
  frame:SetPoint("TOPRIGHT", detail, "TOPRIGHT", 0, -offsetY)
  local textLeft = indent + Constants.sizes.timer.markSize + Constants.sizes.timer.markGap
  local textWidth = Constants.sizes.timer.width - textLeft - Constants.sizes.timer.padding
  local objectiveSize = Data.db.global.timer.objectiveFontSize
  local lineHeight = textLineHeight(objectiveSize)
  local color = Data.db.global.timer.objectiveTextColor
  local atlas = Constants.media.MarkNub
  if entry.completed then
    color = Data.db.global.timer.objectiveDoneTextColor
    atlas = Constants.media.MarkCheck
  end
  local text = line.text
  setFontSize(text, objectiveSize)
  text:SetTextColor(color.r, color.g, color.b)
  text:SetJustifyH("LEFT")
  text:SetWordWrap(false)
  text:ClearAllPoints()
  text:SetWidth(textWidth)
  text:SetText(entry.text)
  local oneLine = text:GetStringHeight()
  text:SetWordWrap(true)
  local textHeight = text:GetStringHeight()
  if oneLine < 1 then
    oneLine = lineHeight
  end
  if textHeight < oneLine then
    textHeight = oneLine
  end
  local wrapped = textHeight > oneLine + 1
  local rowHeight = lineHeight
  if wrapped and textHeight > rowHeight then
    rowHeight = textHeight
  end
  frame:SetHeight(rowHeight)
  local icon = line.icon
  icon:ClearAllPoints()
  icon:SetSize(Constants.sizes.timer.markSize, Constants.sizes.timer.markSize)
  icon:SetAtlas(atlas)
  icon:SetVertexColor(color.r, color.g, color.b)
  icon:Show()
  if wrapped then
    icon:SetPoint("LEFT", frame, "TOPLEFT", indent, -lineHeight / 2)
    text:SetJustifyV("TOP")
    text:SetPoint("TOPLEFT", frame, "TOPLEFT", textLeft, 0)
    text:SetHeight(textHeight)
  else
    icon:SetPoint("LEFT", frame, "LEFT", indent, 0)
    text:SetJustifyV("MIDDLE")
    text:SetPoint("LEFT", frame, "LEFT", textLeft, 0)
    text:SetHeight(lineHeight)
  end
  line.time:Hide()
  local plain = entry.text
  frame:EnableMouse(true)
  frame:SetScript("OnEnter", function(owner)
    if not wrapped then
      return
    end
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    GameTooltip:SetText(plain, 1, 1, 1, 1, true)
    GameTooltip:Show()
  end)
  frame:SetScript("OnLeave", GameTooltip_Hide)
  frame:Show()
  return rowHeight
end

---@param row LDT_TimerSplitRow
---@param detail Frame
---@param lines LDT_TimerLine[]|nil
---@param indent number
---@param used number
---@param offsetY number
---@return number
---@return number
local function paintLines(row, detail, lines, indent, used, offsetY)
  if not lines then
    return used, offsetY
  end
  for index = 1, #lines do
    used = used + 1
    local line = createDetailLine(row, used)
    local height = paintLine(line, detail, lines[index], offsetY, indent)
    offsetY = offsetY + height
  end
  return used, offsetY
end

---@param row LDT_TimerSplitRow
---@param model LDT_TimerNode
---@param showSteps boolean
---@return number
local function paintDetail(row, model, showSteps)
  local detail = row.detail
  local used = 0
  local offsetY = Constants.sizes.timer.detailPad
  local nodes = model.nodes
  if showSteps and model.current and nodes and #nodes > 0 then
    for index = 1, #nodes do
      local node = nodes[index]
      used = used + 1
      local line = createDetailLine(row, used)
      paintNode(line, detail, node.name, node.title, offsetY)
      offsetY = offsetY + textLineHeight(Data.db.global.timer.stepFontSize)
      if node.current then
        used, offsetY = paintLines(row, detail, node.lines, Constants.sizes.timer.lineIndent, used, offsetY)
      end
    end
  elseif showSteps and model.current then
    used, offsetY = paintLines(row, detail, model.lines, Constants.sizes.timer.nodeIndent, used, offsetY)
  end
  for index = used + 1, #row.lines do
    row.lines[index].frame:Hide()
  end
  if used == 0 then
    detail:Hide()
    return 0
  end
  offsetY = offsetY + Constants.sizes.timer.detailPad
  detail:SetHeight(offsetY)
  detail:Show()
  return offsetY
end

---@param splits Frame
---@param splitRows LDT_TimerSplitRow[]
---@param nodes LDT_TimerNode[]
---@param ahead ColorRGBAData
---@param behind ColorRGBAData
---@param showSteps boolean
---@param showCounts boolean
---@param stripe ColorRGBAData
---@param activeRow ColorRGBAData
---@return number
local function paintSplits(splits, splitRows, nodes, ahead, behind, showSteps, showCounts, stripe, activeRow)
  local offsetY = 0
  local stripeIndex = 0
  for index = 1, #nodes do
    local model = nodes[index]
    stripeIndex = stripeIndex + 1
    local row = createSplitRow(splitRows, index, splits)
    local timeText = ""
    local deltaText = ""
    if model.elapsed then
      timeText = FormatElapsed(model.elapsed) or ""
      local delta = 0
      if model.best then
        delta = RoundShownDelta(model.elapsed, model.best)
      end
      local deltaColor = GetDeltaColor(delta, ahead, behind)
      deltaText = CreateColor(deltaColor.r, deltaColor.g, deltaColor.b):WrapTextInColorCode(FormatDelta(delta))
    end
    local bestText = GRAY_FONT_COLOR:WrapTextInColorCode("-")
    if model.best then
      bestText = FormatElapsed(model.best) or ""
    end
    row.name:SetText(formatSplitLabel(model.name, model.done, model.total, showCounts))
    row.delta:SetText(deltaText)
    row.time:SetText(timeText)
    row.best:SetText(bestText)
    local splitColor = Data.db.global.timer.splitTextColor
    local splitSize = Data.db.global.timer.splitFontSize
    local barHeight = splitBarHeight(splitSize)
    setFontSize(row.name, splitSize)
    setFontSize(row.delta, splitSize)
    setFontSize(row.time, splitSize)
    setFontSize(row.best, splitSize)
    row.name:SetTextColor(splitColor.r, splitColor.g, splitColor.b)
    row.time:SetTextColor(splitColor.r, splitColor.g, splitColor.b)
    row.best:SetTextColor(splitColor.r, splitColor.g, splitColor.b)
    placeColumn(row.name, row.bar, 1, "LEFT", barHeight)
    placeColumn(row.delta, row.bar, 2, "RIGHT", barHeight)
    placeColumn(row.time, row.bar, 3, "RIGHT", barHeight)
    placeColumn(row.best, row.bar, 4, "RIGHT", barHeight)
    row.bar:SetHeight(barHeight)
    if stripeIndex % 2 == 1 then
      row.background:SetColorTexture(stripe.r, stripe.g, stripe.b, stripe.a)
    else
      row.background:SetColorTexture(Constants.colors.clear.r, Constants.colors.clear.g, Constants.colors.clear.b, Constants.colors.clear.a)
    end
    if model.current then
      row.highlight:SetColorTexture(activeRow.r, activeRow.g, activeRow.b, activeRow.a)
      row.highlight:Show()
    else
      row.highlight:Hide()
    end
    local detailHeight = paintDetail(row, model, showSteps)
    local height = barHeight + detailHeight
    row.frame:ClearAllPoints()
    row.frame:SetPoint("TOPLEFT", splits, "TOPLEFT", 0, -offsetY)
    row.frame:SetPoint("TOPRIGHT", splits, "TOPRIGHT", 0, -offsetY)
    row.frame:SetHeight(height)
    row.frame:Show()
    offsetY = offsetY + height
  end
  for index = #nodes + 1, #splitRows do
    splitRows[index].frame:Hide()
  end
  return offsetY
end

---@param run LDT_Run
---@return string
local function formatName(run)
  local instance = run.instance
  local name = instance and instance.name
  if not name or name == "" then
    local placeName = instance and (instance.subzone or instance.zone)
    if placeName and placeName ~= "" then
      name = placeName
    else
      name = "Delve"
    end
  end
  local variant = run.variant
  if not variant or variant == "" then
    local header = run.entrance and run.entrance.header
    if header and header ~= "" and header ~= name then
      variant = header
    end
  end
  local title = name
  if variant and variant ~= name then
    local withVariant = format("%s - %s", name, variant)
    if withVariant then
      title = withVariant
    end
  end
  if type(title) ~= "string" or title == "" then
    return "Delve"
  end
  return title
end

local function setObjectiveTracker()
  local tracker = _G.ObjectiveTrackerFrame
  if not tracker or not Data.db then
    return
  end
  if not trackerHooked then
    trackerHooked = true
    tracker:HookScript("OnShow", function()
      setObjectiveTracker()
    end)
  end
  local run = Data:FindActiveRun()
  if run and Data.db.global.timer.replaceTracker then
    if tracker:IsShown() then
      tracker:Hide()
    end
    Capture.trackerHidden = true
    return
  end
  if Capture.trackerHidden then
    Capture.trackerHidden = false
    tracker:Show()
  end
end

function Timer:Render()
  if not self.frame then
    local options = Data.db.global.timer
    ---@type LDT_TimerFrame
    local frame = CreateFrame("Frame", addon.name .. "Timer", UIParent, "BackdropTemplate")
    frame:SetSize(Constants.sizes.timer.width, Constants.sizes.timer.headerHeight)
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    frame:SetScript("OnSizeChanged", function(sizedFrame)
      updateTimerClampInsets(sizedFrame)
    end)
    updateTimerClampInsets(frame)
    frame:SetFrameStrata("MEDIUM")
    self.frame = frame

    ---@type LDT_TimerHeader
    local header = CreateFrame("Frame", nil, frame)
    header:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    header:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
    header:SetHeight(Constants.sizes.timer.headerHeight)
    local headerBackground = header:CreateTexture(nil, "BACKGROUND")
    headerBackground:SetPoint("TOPLEFT", header, "TOPLEFT", Constants.sizes.timer.borderSize, -Constants.sizes.timer.borderSize)
    headerBackground:SetPoint("BOTTOMRIGHT", header, "BOTTOMRIGHT", -Constants.sizes.timer.borderSize, 0)
    headerBackground:SetColorTexture(options.headerBackgroundColor.r, options.headerBackgroundColor.g, options.headerBackgroundColor.b, options.headerBackgroundColor.a)
    header.background = headerBackground
    header:EnableMouse(true)
    header:RegisterForDrag("LeftButton")
    header:SetScript("OnEnter", showHeaderTooltip)
    header:SetScript("OnLeave", GameTooltip_Hide)
    header:SetScript("OnDragStart", function()
      if IsShiftKeyDown() then
        return
      end
      GameTooltip:Hide()
      frame:StartMoving()
    end)
    header:SetScript("OnDragStop", function()
      frame:StopMovingOrSizing()
      Timer:SaveScreenPoint()
    end)
    header:SetScript("OnMouseUp", function(_, button)
      if button == "LeftButton" and IsShiftKeyDown() then
        GameTooltip:Hide()
        addon.Module_Run:ShowRun(Data:FindActiveRun())
        return
      end
      if button == "RightButton" then
        GameTooltip:Hide()
        Timer:OpenMenu(header)
      end
    end)
    self.header = header

    local title = header:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    title:SetJustifyH("LEFT")
    title:SetWordWrap(false)
    self.title = title

    local tier = header:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    tier:SetJustifyH("RIGHT")
    tier:SetWordWrap(false)
    self.tier = tier

    ---@type LDT_TimerColumns
    local columns = CreateFrame("Frame", nil, frame)
    columns:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, 0)
    columns:SetPoint("TOPRIGHT", header, "BOTTOMRIGHT", 0, 0)
    columns:SetHeight(Constants.sizes.timer.rowHeight)
    local headerSplits = columns:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    headerSplits:SetText("Splits")
    placeColumn(headerSplits, columns, 1, "LEFT", Constants.sizes.timer.rowHeight)
    local headerDelta = columns:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    headerDelta:SetText("Delta")
    placeColumn(headerDelta, columns, 2, "RIGHT", Constants.sizes.timer.rowHeight)
    local headerTime = columns:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    headerTime:SetText("Time")
    placeColumn(headerTime, columns, 3, "RIGHT", Constants.sizes.timer.rowHeight)
    local headerBest = columns:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    headerBest:SetText("Best")
    placeColumn(headerBest, columns, 4, "RIGHT", Constants.sizes.timer.rowHeight)
    columns.splits = headerSplits
    columns.delta = headerDelta
    columns.time = headerTime
    columns.best = headerBest
    self.columns = columns

    local splits = CreateFrame("Frame", nil, frame)
    splits:SetPoint("TOPLEFT", columns, "BOTTOMLEFT", 0, 0)
    splits:SetPoint("TOPRIGHT", columns, "BOTTOMRIGHT", 0, 0)
    splits:SetHeight(1)
    self.splits = splits
    ---@type LDT_TimerSplitRow[]
    self.splitRows = {}

    ---@type LDT_TimerClock
    local clockFrame = CreateFrame("Frame", nil, frame)
    clockFrame:SetPoint("TOPLEFT", splits, "BOTTOMLEFT", 0, 0)
    clockFrame:SetPoint("TOPRIGHT", splits, "BOTTOMRIGHT", 0, 0)
    clockFrame:SetHeight(Constants.sizes.timer.clockHeight)
    local clockBackground = clockFrame:CreateTexture(nil, "BACKGROUND")
    clockBackground:SetPoint("TOPLEFT", clockFrame, "TOPLEFT", Constants.sizes.timer.borderSize, 0)
    clockBackground:SetPoint("BOTTOMRIGHT", clockFrame, "BOTTOMRIGHT", -Constants.sizes.timer.borderSize, Constants.sizes.timer.borderSize)
    clockBackground:SetColorTexture(options.clockBackgroundColor.r, options.clockBackgroundColor.g, options.clockBackgroundColor.b, options.clockBackgroundColor.a)
    clockFrame.background = clockBackground
    self.clockFrame = clockFrame

    local livesIcon = clockFrame:CreateTexture(nil, "ARTWORK")
    livesIcon:SetSize(Constants.sizes.timer.iconSize, Constants.sizes.timer.iconSize)
    self.livesIcon = livesIcon

    local lives = clockFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    lives:SetJustifyH("LEFT")
    lives:SetWordWrap(false)
    self.lives = lives

    local deathsIcon = clockFrame:CreateTexture(nil, "ARTWORK")
    deathsIcon:SetSize(Constants.sizes.timer.iconSize, Constants.sizes.timer.iconSize)
    self.deathsIcon = deathsIcon

    local deaths = clockFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    deaths:SetJustifyH("LEFT")
    deaths:SetWordWrap(false)
    self.deaths = deaths

    local spells = CreateFrame("Frame", nil, clockFrame)
    spells:SetHeight(Constants.sizes.timer.iconSize)
    self.spells = spells
    ---@type LDT_TimerSpell[]
    self.spellButtons = {}

    local clockText = clockFrame:CreateFontString(nil, "OVERLAY")
    clockText:SetPoint("RIGHT", clockFrame, "RIGHT", -Constants.sizes.timer.padding, 0)
    clockText:SetJustifyH("RIGHT")
    clockText:SetWordWrap(false)
    self.clockText = clockText

    local phrase = clockFrame:CreateFontString(nil, "OVERLAY")
    phrase:SetPoint("RIGHT", clockText, "LEFT", -Constants.sizes.timer.phraseGap, 0)
    phrase:SetJustifyH("RIGHT")
    phrase:SetWordWrap(false)
    self.phrase = phrase

    frame:Hide()
    frame:SetScript("OnShow", function(shownFrame)
      paintRemaining = 0
      shownFrame:SetScript("OnUpdate", onPaintUpdate)
      Timer:Place()
      Timer:Render()
    end)
    frame:SetScript("OnHide", function(hiddenFrame)
      hiddenFrame:SetScript("OnUpdate", nil)
    end)
    Timer:Place()
  end

  local frame = self.frame
  if not frame then
    return
  end
  setObjectiveTracker()
  local run = Data:FindActiveRun()
  if run then
    if not frame:IsShown() then
      self:SetFrameShown(true, true)
      return
    end
  elseif Capture.timerFromGame and frame:IsShown() then
    self:SetFrameShown(false, true)
    return
  end
  if not frame:IsShown() then
    return
  end

  local header = self.header
  local titleText = self.title
  local tierText = self.tier
  local deathsText = self.deaths
  local deathsIcon = self.deathsIcon
  local livesText = self.lives
  local livesIcon = self.livesIcon
  local spells = self.spells
  local spellButtons = self.spellButtons
  local splits = self.splits
  local splitRows = self.splitRows
  local columns = self.columns
  local clockFrame = self.clockFrame
  local clockText = self.clockText
  local phrase = self.phrase
  if
    not header
    or not titleText
    or not tierText
    or not deathsText
    or not deathsIcon
    or not livesText
    or not livesIcon
    or not spells
    or not spellButtons
    or not splits
    or not splitRows
    or not columns
    or not clockFrame
    or not clockText
    or not phrase
  then
    return
  end

  local options = Data.db.global.timer
  local insideDelveOrLabyrinth = Capture:IsInsideDelveOrLabyrinth()
  local activeRun = insideDelveOrLabyrinth and Data:FindActiveRun() or nil
  local windowBackground = options.windowBackgroundColor or Constants.colors.windowBackground
  local border = options.borderColor or Constants.colors.border
  local ahead = options.aheadColor or Constants.colors.ahead
  local behind = options.behindColor or Constants.colors.behind
  local headerBackground = options.headerBackgroundColor or Constants.colors.headerBackground
  local clockBackground = options.clockBackgroundColor or Constants.colors.clockBackground
  local stripe = options.stripeColor or Constants.colors.stripe
  local activeRow = options.activeRowColor or Constants.colors.activeRow
  header.background:SetColorTexture(headerBackground.r, headerBackground.g, headerBackground.b, headerBackground.a)
  clockFrame.background:SetColorTexture(clockBackground.r, clockBackground.g, clockBackground.b, clockBackground.a)

  frame:SetBackdrop({
    bgFile = Constants.media.WhiteSquare,
    edgeFile = Constants.media.WhiteSquare,
    edgeSize = Constants.sizes.timer.borderSize,
  })
  frame:SetBackdropColor(windowBackground.r, windowBackground.g, windowBackground.b, windowBackground.a)
  frame:SetBackdropBorderColor(border.r, border.g, border.b, border.a)

  local headerInfo
  local title = "Delve"
  local tier
  if activeRun then
    if not Capture:IsEnded(activeRun) then
      headerInfo = Capture:SetDelveHeader(activeRun)
    end
    title = formatName(activeRun)
    tier = GetTier(activeRun)
  else
    title = SAMPLE_NAME
    tier = SAMPLE_TIER
  end
  titleText:SetFont(Constants.media.NumberFont, options.headerFontSize, "")
  titleText:SetTextColor(options.headerTextColor.r, options.headerTextColor.g, options.headerTextColor.b, options.headerTextColor.a)
  titleText:SetText(title)
  tierText:SetFont(Constants.media.NumberFont, options.headerFontSize, "")
  tierText:SetTextColor(options.headerTextColor.r, options.headerTextColor.g, options.headerTextColor.b, options.headerTextColor.a)
  titleText:ClearAllPoints()
  tierText:ClearAllPoints()
  if tier then
    tierText:SetText(format("Tier %d", tier))
    tierText:Show()
    tierText:SetPoint("RIGHT", header, "RIGHT", -Constants.sizes.timer.padding, 0)
    titleText:SetPoint("LEFT", header, "LEFT", Constants.sizes.timer.padding, 0)
    titleText:SetPoint("RIGHT", tierText, "LEFT", -Constants.sizes.timer.padding, 0)
  else
    tierText:Hide()
    titleText:SetPoint("LEFT", header, "LEFT", Constants.sizes.timer.padding, 0)
    titleText:SetPoint("RIGHT", header, "RIGHT", -Constants.sizes.timer.padding, 0)
  end
  local deathsCount
  local livesCount
  if activeRun then
    deathsCount = activeRun.deaths
    if deathsCount == nil then
      deathsCount = 0
    end
    livesCount = activeRun.lives
  else
    deathsCount = SAMPLE_DEATHS
    livesCount = SAMPLE_LIVES
  end
  local countAnchor, countPoint, countOffset =
    placeCount(livesIcon, livesText, Constants.media.Heart, livesCount, clockFrame, "LEFT", Constants.sizes.timer.padding)
  countAnchor, countPoint, countOffset = placeCount(deathsIcon, deathsText, Constants.media.Skull, deathsCount, countAnchor, countPoint, countOffset)

  local spellIDs = {}
  if headerInfo and #headerInfo.spellIDs > 0 then
    spellIDs = headerInfo.spellIDs
  elseif activeRun and activeRun.entrance and activeRun.entrance.activeSpellIDs then
    spellIDs = activeRun.entrance.activeSpellIDs
  elseif not activeRun then
    spellIDs = SAMPLE_SPELLS
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
          button:SetSize(Constants.sizes.timer.iconSize, Constants.sizes.timer.iconSize)
          local icon = button:CreateTexture(nil, "ARTWORK")
          RoundIcon(icon)
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
        spell.button:SetPoint("LEFT", spells, "LEFT", (spellCount - 1) * (Constants.sizes.timer.iconSize + Constants.sizes.timer.iconGap), 0)
        spell.button:Show()
      end
    end
  end
  for index = spellCount + 1, #spellButtons do
    spellButtons[index].button:Hide()
  end
  local spellWidth = 0
  if spellCount > 0 then
    spellWidth = spellCount * Constants.sizes.timer.iconSize + (spellCount - 1) * Constants.sizes.timer.iconGap
  end
  local spellOffset = countOffset
  if spellWidth > 0 and (deathsCount ~= nil or livesCount ~= nil) then
    spellOffset = Constants.sizes.timer.spellGap
  end
  spells:SetWidth(spellWidth)
  spells:ClearAllPoints()
  spells:SetPoint("LEFT", countAnchor, countPoint, spellOffset, 0)

  ---@type LDT_TimerNode[]
  local nodes = {}
  if activeRun then
    nodes = Data:BuildSplits(activeRun)
  else
    nodes = buildSampleRows()
  end

  local clockValue
  local phraseText
  local phraseColor = ahead
  if activeRun and Capture.clockReady then
    local frozen = GetDuration(activeRun)
    if frozen then
      clockValue = frozen
    else
      clockValue = Capture:GetElapsed(activeRun)
    end
    local compare
    if frozen then
      compare = GetDuration(activeRun.best)
    else
      compare = findCurrentBest(nodes)
    end
    if clockValue and compare then
      local delta = RoundShownDelta(clockValue, compare)
      phraseText = FormatDelta(delta)
      phraseColor = GetDeltaColor(delta, ahead, behind)
    end
  elseif not activeRun then
    clockValue = SAMPLE_CLOCK
    local compare = findCurrentBest(nodes)
    if compare then
      phraseText = FormatDelta(RoundShownDelta(SAMPLE_CLOCK, compare))
    end
  end
  clockText:SetFont(Constants.media.NumberFont, options.clockFontSize, "")
  clockText:SetTextColor(options.clockTextColor.r, options.clockTextColor.g, options.clockTextColor.b, options.clockTextColor.a)
  phrase:SetFont(Constants.media.NumberFont, Constants.sizes.timer.phraseFont, "")
  if clockValue then
    clockText:SetText(FormatElapsed(clockValue))
  else
    clockText:SetText("0:00.00")
  end
  phrase:SetText(phraseText or "")
  phrase:SetTextColor(phraseColor.r, phraseColor.g, phraseColor.b, phraseColor.a)

  local splitsHeight = paintSplits(
    splits,
    splitRows,
    nodes,
    ahead,
    behind,
    options.showObjectives ~= false,
    options.showObjectiveCounts == true,
    stripe,
    activeRow
  )
  splits:SetHeight(splitsHeight)
  local columnHeight = splitBarHeight(options.splitFontSize)
  local columnColor = options.columnTextColor
  columns:SetHeight(columnHeight)
  setFontSize(columns.splits, options.splitFontSize)
  setFontSize(columns.delta, options.splitFontSize)
  setFontSize(columns.time, options.splitFontSize)
  setFontSize(columns.best, options.splitFontSize)
  columns.splits:SetTextColor(columnColor.r, columnColor.g, columnColor.b)
  columns.delta:SetTextColor(columnColor.r, columnColor.g, columnColor.b)
  columns.time:SetTextColor(columnColor.r, columnColor.g, columnColor.b)
  columns.best:SetTextColor(columnColor.r, columnColor.g, columnColor.b)
  placeColumn(columns.splits, columns, 1, "LEFT", columnHeight)
  placeColumn(columns.delta, columns, 2, "RIGHT", columnHeight)
  placeColumn(columns.time, columns, 3, "RIGHT", columnHeight)
  placeColumn(columns.best, columns, 4, "RIGHT", columnHeight)
  local clockHeight = options.clockFontSize + 8
  if clockHeight < Constants.sizes.timer.clockHeight then
    clockHeight = Constants.sizes.timer.clockHeight
  end
  clockFrame:SetHeight(clockHeight)
  frame:SetSize(Constants.sizes.timer.width, Constants.sizes.timer.headerHeight + columnHeight + splitsHeight + clockHeight)
end

function Timer:ToggleWindow()
  if not self.frame then
    self:Render()
  end
  if not self.frame then
    return
  end
  self:SetFrameShown(not self.frame:IsShown(), false)
end

function Timer:OnEnable()
end

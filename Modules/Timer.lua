---@class LDT_Addon
local addon = select(2, ...)

---@class LDT_Module_Timer
local Timer = addon.Core:NewModule("Timer")
addon.Module_Timer = Timer

local Data = addon.Data
local Constants = addon.Constants
local Helpers = addon.Helpers
local Capture = addon.Capture

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
  icon:SetPoint("RIGHT", anchor, point, offsetX, 0)
  text:SetPoint("RIGHT", icon, "LEFT", -Constants.sizes.timer.iconGap, 0)
  return text, "LEFT", -Constants.sizes.timer.iconGap
end

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

local paintRemaining = 0

---@param _frame Frame
---@param elapsed number
local function onPaintUpdate(_frame, elapsed)
  paintRemaining = paintRemaining - elapsed
  if paintRemaining > 0 then
    return
  end
  paintRemaining = Constants.timing.paint
  Timer:Render()
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
    addColorSwatch(rootMenu, "Faster than best", options.aheadColor)
    addColorSwatch(rootMenu, "Slower than best", options.behindColor)
    addColorSwatch(rootMenu, "Background", options.backgroundColor)
    addColorSwatch(rootMenu, "Border", options.borderColor)
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

---Show or hide the timer. fromGame true means Capture owns auto-hide on leave.
---@param shown boolean
---@param fromGame boolean|nil
function Timer:ApplyFrameShown(shown, fromGame)
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
local function placeColumn(fontString, parent, column, align)
  local x = Constants.sizes.timer.columnX[column] or 0
  local width = Constants.sizes.timer.columnWidth[column] or 0
  fontString:ClearAllPoints()
  fontString:SetWidth(width - Constants.sizes.timer.padding * 2)
  fontString:SetJustifyH(align)
  fontString:SetWordWrap(false)
  if align == "RIGHT" then
    fontString:SetPoint("RIGHT", parent, "TOPLEFT", x + width - Constants.sizes.timer.padding, -Constants.sizes.timer.row / 2)
  else
    fontString:SetPoint("LEFT", parent, "TOPLEFT", x + Constants.sizes.timer.padding, -Constants.sizes.timer.row / 2)
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
  bar:SetHeight(Constants.sizes.timer.row)
  local background = bar:CreateTexture(nil, "BACKGROUND")
  background:SetAllPoints()
  local name = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  local delta = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  local time = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  local best = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  placeColumn(name, bar, 1, "LEFT")
  placeColumn(delta, bar, 2, "RIGHT")
  placeColumn(time, bar, 3, "RIGHT")
  placeColumn(best, bar, 4, "RIGHT")
  local detail = CreateFrame("Frame", nil, frame)
  detail:SetPoint("TOPLEFT", bar, "BOTTOMLEFT", 0, 0)
  detail:SetPoint("TOPRIGHT", bar, "BOTTOMRIGHT", 0, 0)
  local detailBackground = detail:CreateTexture(nil, "BACKGROUND")
  detailBackground:SetAllPoints()
  detailBackground:SetColorTexture(Constants.colors.wash.r, Constants.colors.wash.g, Constants.colors.wash.b, Constants.colors.wash.a)
  ---@type LDT_TimerDetailLine[]
  local lines = {}
  ---@type LDT_TimerSplitRow
  local row = {
    frame = frame,
    bar = bar,
    background = background,
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
  icon:SetSize(Constants.sizes.timer.mark, Constants.sizes.timer.mark)
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
  frame:SetHeight(Constants.sizes.timer.line)
  local icon = line.icon
  icon:ClearAllPoints()
  icon:SetSize(Constants.sizes.timer.mark, Constants.sizes.timer.mark)
  icon:SetPoint("LEFT", frame, "LEFT", Constants.sizes.timer.nodeIndent, 0)
  icon:SetAtlas(Constants.media.MarkNub)
  icon:SetVertexColor(Constants.colors.step.r, Constants.colors.step.g, Constants.colors.step.b)
  icon:Show()
  local textLeft = Constants.sizes.timer.nodeIndent + Constants.sizes.timer.mark + Constants.sizes.timer.markGap
  local shown = label
  if title and title ~= "" then
    shown = format("%s: %s", label, WHITE_FONT_COLOR:WrapTextInColorCode(title))
  end
  local text = line.text
  text:SetFontObject("GameFontNormal")
  text:SetTextColor(Constants.colors.step.r, Constants.colors.step.g, Constants.colors.step.b)
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
  local textLeft = indent + Constants.sizes.timer.mark + Constants.sizes.timer.markGap
  local textWidth = Constants.sizes.timer.width - textLeft - Constants.sizes.timer.padding
  local color = Constants.colors.objective
  local atlas = Constants.media.MarkNub
  if entry.completed then
    color = Constants.colors.objectiveDone
    atlas = Constants.media.MarkCheck
  end
  local text = line.text
  text:SetFontObject("GameFontHighlightSmall")
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
    oneLine = Constants.sizes.timer.line
  end
  if textHeight < oneLine then
    textHeight = oneLine
  end
  local wrapped = textHeight > oneLine + 1
  local rowHeight = Constants.sizes.timer.line
  if wrapped and textHeight > rowHeight then
    rowHeight = textHeight
  end
  frame:SetHeight(rowHeight)
  local icon = line.icon
  icon:ClearAllPoints()
  icon:SetSize(Constants.sizes.timer.mark, Constants.sizes.timer.mark)
  icon:SetAtlas(atlas)
  icon:SetVertexColor(color.r, color.g, color.b)
  icon:Show()
  if wrapped then
    icon:SetPoint("LEFT", frame, "TOPLEFT", indent, -Constants.sizes.timer.line / 2)
    text:SetJustifyV("TOP")
    text:SetPoint("TOPLEFT", frame, "TOPLEFT", textLeft, 0)
    text:SetHeight(textHeight)
  else
    icon:SetPoint("LEFT", frame, "LEFT", indent, 0)
    text:SetJustifyV("MIDDLE")
    text:SetPoint("LEFT", frame, "LEFT", textLeft, 0)
    text:SetHeight(Constants.sizes.timer.line)
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
      offsetY = offsetY + Constants.sizes.timer.line
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
---@return number
local function paintSplits(splits, splitRows, nodes, ahead, behind, showSteps, showCounts)
  local offsetY = 0
  local stripeIndex = 0
  for index = 1, #nodes do
    local model = nodes[index]
    stripeIndex = stripeIndex + 1
    local row = createSplitRow(splitRows, index, splits)
    local timeText = ""
    local deltaText = ""
    if model.elapsed then
      timeText = Helpers.FormatElapsed(model.elapsed) or ""
      local delta = 0
      if model.best then
        delta = Helpers.RoundShownDelta(model.elapsed, model.best)
      end
      local deltaColor = ahead
      if delta > 0 then
        deltaColor = behind
      end
      deltaText = CreateColor(deltaColor.r, deltaColor.g, deltaColor.b):WrapTextInColorCode(Helpers.FormatDelta(delta))
    end
    local bestText = GRAY_FONT_COLOR:WrapTextInColorCode("-")
    if model.best then
      bestText = Helpers.FormatElapsed(model.best) or ""
    end
    row.name:SetText(formatSplitLabel(model.name, model.done, model.total, showCounts))
    row.delta:SetText(deltaText)
    row.time:SetText(timeText)
    row.best:SetText(bestText)
    if model.current then
      row.background:SetColorTexture(Constants.colors.activeRow.r, Constants.colors.activeRow.g, Constants.colors.activeRow.b, Constants.colors.activeRow.a)
    elseif stripeIndex % 2 == 1 then
      row.background:SetColorTexture(Constants.colors.stripe.r, Constants.colors.stripe.g, Constants.colors.stripe.b, Constants.colors.stripe.a)
    else
      row.background:SetColorTexture(Constants.colors.clear.r, Constants.colors.clear.g, Constants.colors.clear.b, Constants.colors.clear.a)
    end
    local detailHeight = paintDetail(row, model, showSteps)
    local height = Constants.sizes.timer.row + detailHeight
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
---@param tier number|nil
---@return string
local function formatRunTitle(run, tier)
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
  if tier then
    local withTier = format("%s (Tier %d)", title, tier)
    if withTier then
      title = withTier
    end
  end
  if type(title) ~= "string" or title == "" then
    return "Delve"
  end
  return title
end

function Timer:Render()
  if not self.frame then
    local options = Data.db.global.timer
    ---@type LDT_TimerFrame
    local frame = CreateFrame("Frame", addon.name .. "Timer", UIParent, "BackdropTemplate")
    frame:SetSize(Constants.sizes.timer.width, Constants.sizes.timer.header)
    frame:SetPoint(options.point, UIParent, options.relativePoint, options.x, options.y)
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    frame:SetFrameStrata("HIGH")
    self.frame = frame

    local header = CreateFrame("Frame", nil, frame)
    header:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    header:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
    header:SetHeight(Constants.sizes.timer.header)
    local headerBackground = header:CreateTexture(nil, "BACKGROUND")
    headerBackground:SetPoint("TOPLEFT", header, "TOPLEFT", Constants.sizes.timer.border, -Constants.sizes.timer.border)
    headerBackground:SetPoint("BOTTOMRIGHT", header, "BOTTOMRIGHT", -Constants.sizes.timer.border, 0)
    headerBackground:SetColorTexture(Constants.colors.header.r, Constants.colors.header.g, Constants.colors.header.b, Constants.colors.header.a)
    header:EnableMouse(true)
    header:RegisterForDrag("LeftButton")
    header:SetScript("OnDragStart", function()
      frame:StartMoving()
    end)
    header:SetScript("OnDragStop", function()
      frame:StopMovingOrSizing()
      Timer:SaveScreenPoint()
    end)
    header:SetScript("OnMouseUp", function(_, button)
      if button == "RightButton" then
        Timer:OpenMenu(header)
      end
    end)
    self.header = header

    local livesIcon = header:CreateTexture(nil, "ARTWORK")
    livesIcon:SetSize(Constants.sizes.timer.icon, Constants.sizes.timer.icon)
    self.livesIcon = livesIcon

    local lives = header:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    lives:SetJustifyH("RIGHT")
    lives:SetWordWrap(false)
    self.lives = lives

    local deathsIcon = header:CreateTexture(nil, "ARTWORK")
    deathsIcon:SetSize(Constants.sizes.timer.icon, Constants.sizes.timer.icon)
    self.deathsIcon = deathsIcon

    local deaths = header:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    deaths:SetJustifyH("RIGHT")
    deaths:SetWordWrap(false)
    self.deaths = deaths

    local spells = CreateFrame("Frame", nil, header)
    spells:SetHeight(Constants.sizes.timer.icon)
    self.spells = spells
    ---@type LDT_TimerSpell[]
    self.spellButtons = {}

    local title = header:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    title:SetPoint("LEFT", header, "LEFT", Constants.sizes.timer.headerPad, 0)
    title:SetPoint("RIGHT", spells, "LEFT", -Constants.sizes.timer.headerPad, 0)
    title:SetJustifyH("LEFT")
    title:SetWordWrap(false)
    self.title = title

    local columns = CreateFrame("Frame", nil, frame)
    columns:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, 0)
    columns:SetPoint("TOPRIGHT", header, "BOTTOMRIGHT", 0, 0)
    columns:SetHeight(Constants.sizes.timer.row)
    local headerSplits = columns:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    headerSplits:SetText("Splits")
    placeColumn(headerSplits, columns, 1, "LEFT")
    local headerDelta = columns:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    headerDelta:SetText("Delta")
    placeColumn(headerDelta, columns, 2, "RIGHT")
    local headerTime = columns:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    headerTime:SetText("Time")
    placeColumn(headerTime, columns, 3, "RIGHT")
    local headerBest = columns:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    headerBest:SetText("Best")
    placeColumn(headerBest, columns, 4, "RIGHT")

    local splits = CreateFrame("Frame", nil, frame)
    splits:SetPoint("TOPLEFT", columns, "BOTTOMLEFT", 0, 0)
    splits:SetPoint("TOPRIGHT", columns, "BOTTOMRIGHT", 0, 0)
    splits:SetHeight(1)
    self.splits = splits
    ---@type LDT_TimerSplitRow[]
    self.splitRows = {}

    local clockFrame = CreateFrame("Frame", nil, frame)
    clockFrame:SetPoint("TOPLEFT", splits, "BOTTOMLEFT", 0, 0)
    clockFrame:SetPoint("TOPRIGHT", splits, "BOTTOMRIGHT", 0, 0)
    clockFrame:SetHeight(Constants.sizes.timer.clock)
    self.clockFrame = clockFrame

    local clock = clockFrame:CreateFontString(nil, "OVERLAY")
    clock:SetPoint("RIGHT", clockFrame, "RIGHT", -Constants.sizes.timer.headerPad, 0)
    clock:SetJustifyH("RIGHT")
    clock:SetWordWrap(false)
    self.clock = clock

    local phrase = clockFrame:CreateFontString(nil, "OVERLAY")
    phrase:SetPoint("RIGHT", clock, "LEFT", -Constants.sizes.timer.phraseGap, 0)
    phrase:SetJustifyH("RIGHT")
    phrase:SetWordWrap(false)
    self.phrase = phrase

    local cue = clockFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    cue:SetPoint("LEFT", clockFrame, "LEFT", Constants.sizes.timer.headerPad, 0)
    cue:SetPoint("RIGHT", phrase, "LEFT", -Constants.sizes.timer.cueGap, 0)
    cue:SetJustifyH("LEFT")
    cue:SetWordWrap(false)
    self.cue = cue

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
  end

  local frame = self.frame
  if not frame or not frame:IsShown() then
    return
  end

  local header = self.header
  local titleText = self.title
  local deathsText = self.deaths
  local deathsIcon = self.deathsIcon
  local livesText = self.lives
  local livesIcon = self.livesIcon
  local spells = self.spells
  local spellButtons = self.spellButtons
  local splits = self.splits
  local splitRows = self.splitRows
  local clockFrame = self.clockFrame
  local clockString = self.clock
  local cue = self.cue
  local phrase = self.phrase
  if
    not header
    or not titleText
    or not deathsText
    or not deathsIcon
    or not livesText
    or not livesIcon
    or not spells
    or not spellButtons
    or not splits
    or not splitRows
    or not clockFrame
    or not clockString
    or not cue
    or not phrase
  then
    return
  end

  local options = Data.db.global.timer
  local inside = Capture:IsInside() or Capture:IsInInstance()
  local activeRun = inside and Data:FindActiveRun() or nil
  local background = options.backgroundColor or Constants.colors.background
  local border = options.borderColor or Constants.colors.border
  local ahead = options.aheadColor or Constants.colors.ahead
  local behind = options.behindColor or Constants.colors.behind

  frame:SetBackdrop({
    bgFile = Constants.media.WhiteSquare,
    edgeFile = Constants.media.WhiteSquare,
    edgeSize = Constants.sizes.timer.border,
  })
  frame:SetBackdropColor(background.r, background.g, background.b, background.a)
  frame:SetBackdropBorderColor(border.r, border.g, border.b, border.a)

  local headerInfo
  local title = "Delve"
  if activeRun then
    if not Capture:IsEnded(activeRun) then
      headerInfo = Capture:SetDelveHeader(activeRun)
    end
    title = formatRunTitle(activeRun, Helpers.FindTier(activeRun))
  else
    title = "The Shadow Enclave (Tier 11)"
  end
  titleText:SetFont(Constants.media.NumberFont, Constants.sizes.timer.titleFont, "")
  titleText:SetTextColor(Constants.colors.title.r, Constants.colors.title.g, Constants.colors.title.b, Constants.colors.title.a)
  titleText:SetText(title)
  local deathsCount
  local livesCount
  if activeRun then
    deathsCount = activeRun.deaths
    if deathsCount == nil then
      deathsCount = 0
    end
    livesCount = activeRun.lives
  else
    deathsCount = 1
    livesCount = 4
  end
  local countAnchor, countPoint, countOffset = placeCount(livesIcon, livesText, Constants.media.Heart, livesCount, header, "RIGHT", -Constants.sizes.timer.headerPad)
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
          button:SetSize(Constants.sizes.timer.icon, Constants.sizes.timer.icon)
          local icon = button:CreateTexture(nil, "ARTWORK")
          icon:SetPoint("TOPLEFT", button, "TOPLEFT", Constants.sizes.iconInset, -Constants.sizes.iconInset)
          icon:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -Constants.sizes.iconInset, Constants.sizes.iconInset)
          local mask = button:CreateMaskTexture()
          mask:SetTexture(Constants.media.CircleMask, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
          mask:SetAllPoints(icon)
          icon:AddMaskTexture(mask)
          local ring = button:CreateTexture(nil, "OVERLAY")
          ring:SetAllPoints(button)
          ring:SetAtlas(Constants.media.AffixRing)
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
        spell.button:SetPoint("LEFT", spells, "LEFT", (spellCount - 1) * (Constants.sizes.timer.icon + Constants.sizes.timer.iconGap), 0)
        spell.button:Show()
      end
    end
  end
  for index = spellCount + 1, #spellButtons do
    spellButtons[index].button:Hide()
  end
  local spellWidth = 0
  if spellCount > 0 then
    spellWidth = spellCount * Constants.sizes.timer.icon + (spellCount - 1) * Constants.sizes.timer.iconGap
  end
  local spellOffset = countOffset
  if spellWidth > 0 and (deathsCount ~= nil or livesCount ~= nil) then
    spellOffset = -Constants.sizes.timer.spellGap
  end
  spells:SetWidth(spellWidth)
  spells:ClearAllPoints()
  spells:SetPoint("RIGHT", countAnchor, countPoint, spellOffset, 0)

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
    local frozen = Helpers.FindDuration(activeRun)
    if frozen then
      clockValue = frozen
    else
      clockValue = Capture:ReadElapsed(activeRun)
    end
    local compare
    if frozen then
      compare = Helpers.FindBestDuration(activeRun)
    else
      compare = findCurrentBest(nodes)
    end
    if clockValue and compare then
      local delta = Helpers.RoundShownDelta(clockValue, compare)
      phraseText = Helpers.FormatDelta(delta)
      if delta > 0 then
        phraseColor = behind
      end
    end
  elseif not activeRun then
    clockValue = SAMPLE_CLOCK
    local compare = findCurrentBest(nodes)
    if compare then
      phraseText = Helpers.FormatDelta(Helpers.RoundShownDelta(SAMPLE_CLOCK, compare))
    end
  end
  clockString:SetFont(Constants.media.NumberFont, Constants.sizes.timer.clockFont, "")
  phrase:SetFont(Constants.media.NumberFont, Constants.sizes.timer.phraseFont, "")
  if clockValue then
    clockString:SetText(Helpers.FormatElapsed(clockValue))
  else
    clockString:SetText("0:00.00")
  end
  phrase:SetText(phraseText or "")
  phrase:SetTextColor(phraseColor.r, phraseColor.g, phraseColor.b, phraseColor.a)
  local cueText = ""
  if activeRun then
    cueText = Data:FormatClockPrompt(activeRun) or ""
  end
  cue:SetFontObject("GameFontNormal")
  cue:SetTextColor(Constants.colors.step.r, Constants.colors.step.g, Constants.colors.step.b, Constants.colors.step.a)
  cue:SetText(cueText)

  local splitsHeight = paintSplits(
    splits,
    splitRows,
    nodes,
    ahead,
    behind,
    options.showObjectives ~= false,
    options.showObjectiveCounts == true
  )
  splits:SetHeight(splitsHeight)
  clockFrame:SetHeight(Constants.sizes.timer.clock)
  frame:SetSize(Constants.sizes.timer.width, Constants.sizes.timer.header + Constants.sizes.timer.row + splitsHeight + Constants.sizes.timer.clock)
end

function Timer:ShowRun()
  self:ApplyFrameShown(true, true)
end

function Timer:HideRun()
  self:ApplyFrameShown(false, true)
end

function Timer:ToggleWindow()
  if not self.frame then
    self:Render()
  end
  if not self.frame then
    return
  end
  self:ApplyFrameShown(not self.frame:IsShown(), false)
end

function Timer:OnEnable()
end

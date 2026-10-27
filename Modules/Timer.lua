---@class LDT_Addon
local addon = select(2, ...)

---@class LDT_Module_Timer
local Timer = addon.Core:NewModule("Timer")
addon.Module_Timer = Timer

local Data = addon.Data
local Helpers = addon.Helpers
local Capture = addon.Capture

local HEADER_HEIGHT = 40
local HEADER_PAD = 10
local ICON_SIZE = 20
local ICON_GAP = 4
local SPELL_GAP = 12
local STAGES_WIDTH = 180
local DELTA_WIDTH = 75
local TIME_WIDTH = 75
local BEST_WIDTH = 75
local TABLE_WIDTH = STAGES_WIDTH + DELTA_WIDTH + TIME_WIDTH + BEST_WIDTH
local COLUMN_X = {
  0,
  STAGES_WIDTH,
  STAGES_WIDTH + DELTA_WIDTH,
  STAGES_WIDTH + DELTA_WIDTH + TIME_WIDTH,
}
local COLUMN_WIDTH = {
  STAGES_WIDTH,
  DELTA_WIDTH,
  TIME_WIDTH,
  BEST_WIDTH,
}
local CELL_PADDING = 8
local ROW_HEIGHT = 28
local LINE_HEIGHT = 16
local DETAIL_PAD = 4
local NODE_INDENT = 8
local LINE_INDENT = 26
local MARK_ICON = 14
local MARK_NUB = "ui-questtracker-objective-nub"
local MARK_CHECK = "ui-questtracker-tracker-check"
---@type ColorRGBAData
local NODE_COLOR = { r = 1, g = 0.82, b = 0, a = 1 }
---@type ColorRGBAData
local LINE_COLOR = { r = 0.75, g = 0.85, b = 1, a = 1 }
---@type ColorRGBAData
local LINE_DONE_COLOR = { r = 0.65, g = 0.85, b = 0.65, a = 1 }
local CLOCK_HEIGHT = 36
local TITLE_SIZE = 16
local META_SIZE = 14
local CLOCK_SIZE = 22
local PHRASE_SIZE = 14
local NUMBER_FONT = "Fonts\\ARIALN.TTF"
local SKULL_ATLAS = "DungeonSkull"
local HEART_ATLAS = "delves-scenario-heart-icon"
---@type ColorRGBAData
local ACTIVE_ROW_COLOR = { r = 0.12, g = 0.32, b = 0.72, a = 0.7 }

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
  text:SetFont(NUMBER_FONT, META_SIZE, "")
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
  text:SetPoint("RIGHT", icon, "LEFT", -ICON_GAP, 0)
  return text, "LEFT", -ICON_GAP
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

local SAMPLE_SPELLS = { 1279443, 1307638, 462940 }
local SAMPLE_CLOCK = 154000

---@param nodes LDT_TimerNode[]
---@return number|nil
local function currentBest(nodes)
  for index = 1, #nodes do
    local node = nodes[index]
    if node.current then
      return node.best
    end
  end
  return nil
end

---@return LDT_TimerNode[]
local function sampleRows()
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
local function splitLabel(name, done, total, showCounts)
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
  local x = COLUMN_X[column] or 0
  local width = COLUMN_WIDTH[column] or 0
  fontString:ClearAllPoints()
  fontString:SetWidth(width - CELL_PADDING * 2)
  fontString:SetJustifyH(align)
  fontString:SetWordWrap(false)
  if align == "RIGHT" then
    fontString:SetPoint("RIGHT", parent, "TOPLEFT", x + width - CELL_PADDING, -ROW_HEIGHT / 2)
  else
    fontString:SetPoint("LEFT", parent, "TOPLEFT", x + CELL_PADDING, -ROW_HEIGHT / 2)
  end
end

---@param rows LDT_TimerSplitRow[]
---@param index integer
---@param parent Frame
---@return LDT_TimerSplitRow
local function ensureSplitRow(rows, index, parent)
  local existing = rows[index]
  if existing then
    return existing
  end
  local frame = CreateFrame("Frame", nil, parent)
  local bar = CreateFrame("Frame", nil, frame)
  bar:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
  bar:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
  bar:SetHeight(ROW_HEIGHT)
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
  detailBackground:SetColorTexture(0, 0, 0, 0.35)
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
local function ensureDetailLine(row, index)
  local existing = row.lines[index]
  if existing then
    return existing
  end
  local frame = CreateFrame("Frame", nil, row.detail)
  local icon = frame:CreateTexture(nil, "OVERLAY")
  icon:SetSize(MARK_ICON, MARK_ICON)
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
  frame:SetHeight(LINE_HEIGHT)
  local icon = line.icon
  icon:ClearAllPoints()
  icon:SetSize(MARK_ICON, MARK_ICON)
  icon:SetPoint("LEFT", frame, "LEFT", NODE_INDENT, 0)
  icon:SetAtlas(MARK_NUB)
  icon:SetVertexColor(NODE_COLOR.r, NODE_COLOR.g, NODE_COLOR.b)
  icon:Show()
  local textLeft = NODE_INDENT + MARK_ICON + 4
  local shown = label
  if title and title ~= "" then
    shown = format("%s: %s", label, WHITE_FONT_COLOR:WrapTextInColorCode(title))
  end
  local text = line.text
  text:SetFontObject("GameFontNormal")
  text:SetTextColor(NODE_COLOR.r, NODE_COLOR.g, NODE_COLOR.b)
  text:SetWordWrap(false)
  text:SetJustifyH("LEFT")
  text:SetJustifyV("MIDDLE")
  text:ClearAllPoints()
  text:SetPoint("LEFT", frame, "LEFT", textLeft, 0)
  text:SetWidth(TABLE_WIDTH - textLeft - CELL_PADDING)
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
  local textLeft = indent + MARK_ICON + 4
  local textWidth = TABLE_WIDTH - textLeft - CELL_PADDING
  local color = LINE_COLOR
  local atlas = MARK_NUB
  if entry.completed then
    color = LINE_DONE_COLOR
    atlas = MARK_CHECK
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
    oneLine = LINE_HEIGHT
  end
  if textHeight < oneLine then
    textHeight = oneLine
  end
  local wrapped = textHeight > oneLine + 1
  local rowHeight = LINE_HEIGHT
  if wrapped and textHeight > rowHeight then
    rowHeight = textHeight
  end
  frame:SetHeight(rowHeight)
  local icon = line.icon
  icon:ClearAllPoints()
  icon:SetSize(MARK_ICON, MARK_ICON)
  icon:SetAtlas(atlas)
  icon:SetVertexColor(color.r, color.g, color.b)
  icon:Show()
  if wrapped then
    icon:SetPoint("LEFT", frame, "TOPLEFT", indent, -LINE_HEIGHT / 2)
    text:SetJustifyV("TOP")
    text:SetPoint("TOPLEFT", frame, "TOPLEFT", textLeft, 0)
    text:SetHeight(textHeight)
  else
    icon:SetPoint("LEFT", frame, "LEFT", indent, 0)
    text:SetJustifyV("MIDDLE")
    text:SetPoint("LEFT", frame, "LEFT", textLeft, 0)
    text:SetHeight(LINE_HEIGHT)
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
    local line = ensureDetailLine(row, used)
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
  local offsetY = DETAIL_PAD
  local nodes = model.nodes
  if showSteps and model.current and nodes and #nodes > 0 then
    for index = 1, #nodes do
      local node = nodes[index]
      used = used + 1
      local line = ensureDetailLine(row, used)
      paintNode(line, detail, node.name, node.title, offsetY)
      offsetY = offsetY + LINE_HEIGHT
      if node.current then
        used, offsetY = paintLines(row, detail, node.lines, LINE_INDENT, used, offsetY)
      end
    end
  elseif showSteps and model.current then
    used, offsetY = paintLines(row, detail, model.lines, NODE_INDENT, used, offsetY)
  end
  for index = used + 1, #row.lines do
    row.lines[index].frame:Hide()
  end
  if used == 0 then
    detail:Hide()
    return 0
  end
  offsetY = offsetY + DETAIL_PAD
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
    local row = ensureSplitRow(splitRows, index, splits)
    local timeText = ""
    local deltaText = ""
    if model.elapsed then
      timeText = Helpers.FormatElapsed(model.elapsed) or ""
      local delta = 0
      if model.best then
        delta = Helpers.ShownDelta(model.elapsed, model.best)
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
    row.name:SetText(splitLabel(model.name, model.done, model.total, showCounts))
    row.delta:SetText(deltaText)
    row.time:SetText(timeText)
    row.best:SetText(bestText)
    if model.current then
      row.background:SetColorTexture(ACTIVE_ROW_COLOR.r, ACTIVE_ROW_COLOR.g, ACTIVE_ROW_COLOR.b, ACTIVE_ROW_COLOR.a)
    elseif stripeIndex % 2 == 1 then
      row.background:SetColorTexture(1, 1, 1, 0.08)
    else
      row.background:SetColorTexture(0, 0, 0, 0)
    end
    local detailHeight = paintDetail(row, model, showSteps)
    local height = ROW_HEIGHT + detailHeight
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
local function runTitle(run, tier)
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
    frame:SetSize(TABLE_WIDTH, HEADER_HEIGHT)
    frame:SetPoint(options.point, UIParent, options.relativePoint, options.x, options.y)
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    frame:SetFrameStrata("HIGH")
    self.frame = frame

    local header = CreateFrame("Frame", nil, frame)
    header:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    header:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
    header:SetHeight(HEADER_HEIGHT)
    local headerBackground = header:CreateTexture(nil, "BACKGROUND")
    headerBackground:SetPoint("TOPLEFT", header, "TOPLEFT", 1, -1)
    headerBackground:SetPoint("BOTTOMRIGHT", header, "BOTTOMRIGHT", -1, 0)
    headerBackground:SetColorTexture(0, 0, 0, 1)
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
    livesIcon:SetSize(ICON_SIZE, ICON_SIZE)
    self.livesIcon = livesIcon

    local lives = header:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    lives:SetJustifyH("RIGHT")
    lives:SetWordWrap(false)
    self.lives = lives

    local deathsIcon = header:CreateTexture(nil, "ARTWORK")
    deathsIcon:SetSize(ICON_SIZE, ICON_SIZE)
    self.deathsIcon = deathsIcon

    local deaths = header:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    deaths:SetJustifyH("RIGHT")
    deaths:SetWordWrap(false)
    self.deaths = deaths

    local spells = CreateFrame("Frame", nil, header)
    spells:SetHeight(ICON_SIZE)
    self.spells = spells
    ---@type LDT_TimerSpell[]
    self.spellButtons = {}

    local title = header:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    title:SetPoint("LEFT", header, "LEFT", HEADER_PAD, 0)
    title:SetPoint("RIGHT", spells, "LEFT", -HEADER_PAD, 0)
    title:SetJustifyH("LEFT")
    title:SetWordWrap(false)
    self.title = title

    local columns = CreateFrame("Frame", nil, frame)
    columns:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, 0)
    columns:SetPoint("TOPRIGHT", header, "BOTTOMRIGHT", 0, 0)
    columns:SetHeight(ROW_HEIGHT)
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
    clockFrame:SetHeight(CLOCK_HEIGHT)
    self.clockFrame = clockFrame

    local clock = clockFrame:CreateFontString(nil, "OVERLAY")
    clock:SetPoint("RIGHT", clockFrame, "RIGHT", -HEADER_PAD, 0)
    clock:SetJustifyH("RIGHT")
    clock:SetWordWrap(false)
    self.clock = clock

    local phrase = clockFrame:CreateFontString(nil, "OVERLAY")
    phrase:SetPoint("RIGHT", clock, "LEFT", -12, 0)
    phrase:SetJustifyH("RIGHT")
    phrase:SetWordWrap(false)
    self.phrase = phrase

    local cue = clockFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    cue:SetPoint("LEFT", clockFrame, "LEFT", HEADER_PAD, 0)
    cue:SetPoint("RIGHT", phrase, "LEFT", -8, 0)
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
  local inside = Capture:IsInside() or Capture:InInstance()
  local activeRun = inside and Data:GetActiveRun() or nil
  local background = options.backgroundColor or { r = 0, g = 0, b = 0, a = 0.9 }
  local border = options.borderColor or { r = 0, g = 0, b = 0, a = 0 }
  local ahead = options.aheadColor or { r = 0.2, g = 1, b = 0.2, a = 1 }
  local behind = options.behindColor or { r = 1, g = 0.2, b = 0.2, a = 1 }

  frame:SetBackdrop({
    bgFile = "Interface/Buttons/WHITE8X8",
    edgeFile = "Interface/Buttons/WHITE8X8",
    edgeSize = 1,
  })
  frame:SetBackdropColor(background.r, background.g, background.b, background.a)
  frame:SetBackdropBorderColor(border.r, border.g, border.b, border.a)

  local headerInfo
  local title = "Delve"
  if activeRun then
    if not Capture:Ended(activeRun) then
      headerInfo = Capture:ApplyDelveHeader(activeRun)
    end
    title = runTitle(activeRun, Helpers.RunTier(activeRun))
  else
    title = "The Shadow Enclave (Tier 11)"
  end
  titleText:SetFont(NUMBER_FONT, TITLE_SIZE, "")
  titleText:SetTextColor(1, 1, 1)
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
  local countAnchor, countPoint, countOffset = placeCount(livesIcon, livesText, HEART_ATLAS, livesCount, header, "RIGHT", -HEADER_PAD)
  countAnchor, countPoint, countOffset = placeCount(deathsIcon, deathsText, SKULL_ATLAS, deathsCount, countAnchor, countPoint, countOffset)

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
        spell.button:SetPoint("LEFT", spells, "LEFT", (spellCount - 1) * (ICON_SIZE + ICON_GAP), 0)
        spell.button:Show()
      end
    end
  end
  for index = spellCount + 1, #spellButtons do
    spellButtons[index].button:Hide()
  end
  local spellWidth = 0
  if spellCount > 0 then
    spellWidth = spellCount * ICON_SIZE + (spellCount - 1) * ICON_GAP
  end
  local spellOffset = countOffset
  if spellWidth > 0 and (deathsCount ~= nil or livesCount ~= nil) then
    spellOffset = -SPELL_GAP
  end
  spells:SetWidth(spellWidth)
  spells:ClearAllPoints()
  spells:SetPoint("RIGHT", countAnchor, countPoint, spellOffset, 0)

  ---@type LDT_TimerNode[]
  local nodes = {}
  if activeRun then
    nodes = Data:StepRows(activeRun)
  else
    nodes = sampleRows()
  end

  local clockValue
  local phraseText
  local phraseColor = ahead
  if activeRun and Capture.clockReady then
    local frozen = Helpers.Duration(activeRun)
    if frozen then
      clockValue = frozen
    else
      clockValue = Capture:Elapsed(activeRun)
    end
    local compare
    if frozen then
      compare = Helpers.BestDuration(activeRun)
    else
      compare = currentBest(nodes)
    end
    if clockValue and compare then
      local delta = Helpers.ShownDelta(clockValue, compare)
      phraseText = Helpers.FormatDelta(delta)
      if delta > 0 then
        phraseColor = behind
      end
    end
  elseif not activeRun then
    clockValue = SAMPLE_CLOCK
    local compare = currentBest(nodes)
    if compare then
      phraseText = Helpers.FormatDelta(Helpers.ShownDelta(SAMPLE_CLOCK, compare))
    end
  end
  clockString:SetFont(NUMBER_FONT, CLOCK_SIZE, "")
  phrase:SetFont(NUMBER_FONT, PHRASE_SIZE, "")
  if clockValue then
    clockString:SetText(Helpers.FormatElapsed(clockValue))
  else
    clockString:SetText("0:00.00")
  end
  phrase:SetText(phraseText or "")
  phrase:SetTextColor(phraseColor.r, phraseColor.g, phraseColor.b, phraseColor.a)
  local cueText = ""
  if activeRun then
    cueText = Data:ClockPrompt(activeRun) or ""
  end
  cue:SetFontObject("GameFontNormal")
  cue:SetTextColor(NODE_COLOR.r, NODE_COLOR.g, NODE_COLOR.b, NODE_COLOR.a)
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
  clockFrame:SetHeight(CLOCK_HEIGHT)
  frame:SetSize(TABLE_WIDTH, HEADER_HEIGHT + ROW_HEIGHT + splitsHeight + CLOCK_HEIGHT)
end

function Timer:ShowRun()
  self:SetFrameShown(true, true)
end

function Timer:HideRun()
  self:SetFrameShown(false, true)
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

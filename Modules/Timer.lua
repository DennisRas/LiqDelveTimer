---@class LDT_Addon
local addon = select(2, ...)

---@class LDT_Module_Timer
local Timer = addon.Core:NewModule("Timer")
addon.Module_Timer = Timer

local Data = addon.Data
local Helpers = addon.Helpers
local Capture = addon.Capture
local LiqUI = addon.libs.LiqUI
local TableGet = LiqUI.Utils.TableGet

local HEADER_HEIGHT = 40
local HEADER_PAD = 10
local ICON_SIZE = 20
local ICON_GAP = 4
local SPELL_GAP = 12
local STAGES_WIDTH = 150
local DELTA_WIDTH = 75
local TIME_WIDTH = 75
local BEST_WIDTH = 75
local CELL_PADDING = 8
local ROW_HEIGHT = 28
local OBJECTIVE_ROW_HEIGHT = 20
local OBJECTIVE_INDENT = 8
local OBJECTIVE_ICON = 14
local OBJECTIVE_GAP_AFTER = 4
local OBJECTIVE_NUB = "ui-questtracker-objective-nub"
local OBJECTIVE_CHECK = "ui-questtracker-tracker-check"
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
    rootMenu:CreateCheckbox("Show objectives", function()
      return options.showObjectives ~= false
    end, function()
      options.showObjectives = options.showObjectives == false
      Timer:Render()
    end)
    rootMenu:CreateCheckbox("Show objective counts", function()
      return options.showObjectiveCounts ~= false
    end, function()
      options.showObjectiveCounts = options.showObjectiveCounts == false
      Timer:Render()
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

---@param stepRows LDT_StepRow[]
---@return number|nil
local function currentBest(stepRows)
  for index = 1, #stepRows do
    local row = stepRows[index]
    if row.current then
      return row.best
    end
  end
  return nil
end

---@param name string
---@param done number
---@param total number
---@param showCounts boolean
---@return string
local function sampleStageName(name, done, total, showCounts)
  if not showCounts then
    return name
  end
  return format("%s (%d/%d)", name, done, total)
end

---@param showCounts boolean
---@return LDT_StepRow[]
local function sampleRows(showCounts)
  ---@type LDT_StepRow[]
  local rows = {}
  ---@type LDT_StepRow
  local stageOne = { name = sampleStageName("Stage 1", 1, 1, showCounts), elapsed = 84200, best = 90000, current = false }
  ---@type LDT_ObjectiveLine
  local openGate = { text = "(1/1) Open the gate", completed = true }
  ---@type LDT_ObjectiveLine
  local cultists = { text = "(1/3) Kill the cultists", completed = false }
  ---@type LDT_ObjectiveLine
  local ritual = { text = "(40%) Disrupt the ritual", completed = false }
  ---@type LDT_ObjectiveLine[]
  local sampleObjectives = { openGate, cultists, ritual }
  ---@type LDT_StepRow
  local stageTwo = {
    name = sampleStageName("Stage 2", 0, 3, showCounts),
    elapsed = nil,
    best = 160000,
    current = true,
    objectives = sampleObjectives,
  }
  ---@type LDT_StepRow
  local stageThree = { name = sampleStageName("Stage 3", 0, 2, showCounts), elapsed = nil, best = 230000, current = false }
  ---@type LDT_StepRow
  local stageFour = { name = sampleStageName("Stage 4", 0, 1, showCounts), elapsed = nil, best = 310000, current = false }
  ---@type LDT_StepRow
  local stageFive = { name = sampleStageName("Stage 5", 0, 4, showCounts), elapsed = nil, best = 390000, current = false }
  rows[1] = stageOne
  rows[2] = stageTwo
  rows[3] = stageThree
  rows[4] = stageFour
  rows[5] = stageFive
  return rows
end

---@param list LDT_Criteria[]
---@param criteriaID number
---@param slot number
---@return LDT_Criteria|nil
local function criterionMatch(list, criteriaID, slot)
  if criteriaID ~= 0 then
    for index = 1, #list do
      local row = list[index]
      if row.criteriaID == criteriaID then
        return row
      end
    end
    return nil
  end
  local row = list[slot]
  if row and row.criteriaID == 0 then
    return row
  end
  return nil
end

---@param description string|nil
---@param totalQuantity number|nil
---@param weighted boolean
---@param match LDT_Criteria|nil
---@return string|nil, number|nil, boolean
local function applyCriterion(description, totalQuantity, weighted, match)
  if not match then
    return description, totalQuantity, weighted
  end
  if not description then
    description = match.description
  end
  if totalQuantity == nil then
    totalQuantity = match.totalQuantity
  end
  if match.isWeightedProgress ~= nil then
    weighted = match.isWeightedProgress
  end
  return description, totalQuantity, weighted
end

---@param stepID number
---@param criteriaID number
---@param slot number
---@return string|nil, number|nil, boolean
local function criterionFacts(stepID, criteriaID, slot)
  local description
  local totalQuantity
  local weighted = false
  local known = TableGet(Data.steps, "stepID", stepID)
  local knownCriteria = known and known.criteria
  if knownCriteria then
    description, totalQuantity, weighted = applyCriterion(description, totalQuantity, weighted, criterionMatch(knownCriteria, criteriaID, slot))
  end
  if Data.db then
    local learned = Data.db.global.steps[stepID]
    local learnedCriteria = learned and learned.criteria
    if learnedCriteria then
      description, totalQuantity, weighted = applyCriterion(description, totalQuantity, weighted, criterionMatch(learnedCriteria, criteriaID, slot))
    end
  end
  return description, totalQuantity, weighted
end

---@param stepID number
---@param criteria LDT_RunCriteria
---@param slot number
---@return string|nil
local function objectiveLabel(stepID, criteria, slot)
  local description, totalQuantity, weighted = criterionFacts(stepID, criteria.criteriaID, slot)
  description = description or ""
  local progress
  if weighted then
    if criteria.quantity ~= nil then
      progress = format("%d%%", criteria.quantity)
    end
  elseif criteria.quantity ~= nil and totalQuantity ~= nil and totalQuantity > 0 then
    progress = format("%d/%d", criteria.quantity, totalQuantity)
  end
  if progress and progress ~= "" then
    if description ~= "" then
      return format("(%s) %s", progress, description)
    end
    return format("(%s)", progress)
  end
  if description == "" then
    return nil
  end
  return description
end

---@param rows LDT_StepRow[]
---@param run LDT_Run
local function fillObjectives(rows, run)
  local scenario = run.scenarios[#run.scenarios]
  if not scenario then
    return
  end
  local step = scenario.steps[#scenario.steps]
  if not step then
    return
  end
  local criteria = step.criteria
  if not criteria or #criteria == 0 then
    return
  end
  ---@type LDT_ObjectiveLine[]
  local lines = {}
  for index = 1, #criteria do
    local criteriaRow = criteria[index]
    local label = objectiveLabel(step.stepID, criteriaRow, index)
    if label then
      ---@type LDT_ObjectiveLine
      local line = { text = label, completed = criteriaRow.completed == true }
      lines[#lines + 1] = line
    end
  end
  if #lines == 0 then
    return
  end
  for index = 1, #rows do
    if rows[index].current then
      rows[index].objectives = lines
    end
  end
end

---@param line LDT_ObjectiveLine
---@return string
local function objectiveLineText(line)
  local atlas = OBJECTIVE_NUB
  if line.completed then
    atlas = OBJECTIVE_CHECK
  end
  local icon = CreateAtlasMarkup(atlas, OBJECTIVE_ICON, OBJECTIVE_ICON) or ""
  local textColor = CreateColor(0.85, 0.9, 1)
  if line.completed then
    textColor = CreateColor(0.65, 0.85, 0.65)
  end
  return format("%s %s", icon, textColor:WrapTextInColorCode(line.text))
end

---@param stepRows LDT_StepRow[]
---@param ahead ColorRGBAData
---@param behind ColorRGBAData
---@param showObjectives boolean
---@return LiqUI_TableData
local function timetableRows(stepRows, ahead, behind, showObjectives)
  ---@type LiqUI_TableData
  local data = {}
  for index = 1, #stepRows do
    local model = stepRows[index]
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
    ---@type ColorRGBAData|nil
    local backgroundColor
    if model.current then
      backgroundColor = ACTIVE_ROW_COLOR
    end
    local objectives = model.objectives
    local showLines = model.current and showObjectives and objectives and #objectives > 0
    ---@type LiqUI_TableDataRowExtended
    local row = {
      backgroundColor = backgroundColor,
      -- paddingBottom = showLines and 2 or nil,
      data = {
        model.name,
        deltaText,
        timeText,
        bestText,
      },
    }
    data[#data + 1] = row
    if showLines and objectives then
      for objectiveIndex = 1, #objectives do
        ---@type LiqUI_TableDataRowExtended
        local objectiveRow = {
          height = OBJECTIVE_ROW_HEIGHT,
          indent = OBJECTIVE_INDENT,
          padding = 0,
          span = true,
          skipStripe = true,
          gapBefore = objectiveIndex == 1 and OBJECTIVE_GAP_AFTER or nil,
          gapAfter = objectiveIndex == #objectives and OBJECTIVE_GAP_AFTER or nil,
          data = { objectiveLineText(objectives[objectiveIndex]), "", "", "" },
        }
        data[#data + 1] = objectiveRow
      end
    end
  end
  return data
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
    frame:SetSize(STAGES_WIDTH + DELTA_WIDTH + TIME_WIDTH + BEST_WIDTH, HEADER_HEIGHT)
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

    ---@type LiqUI_TableOptions
    local tableOptions = {
      name = addon.name .. "Timer",
      header = {
        enabled = true,
        sticky = false,
        height = ROW_HEIGHT,
        fontObject = "GameFontNormal",
        backgroundAlpha = 0,
      },
      rowStyle = {
        height = ROW_HEIGHT,
        highlight = false,
        striped = true,
        stripeColor = { r = 1, g = 1, b = 1, a = 0.08 },
      },
      cellStyle = {
        padding = CELL_PADDING,
        highlight = false,
        fontObject = "GameFontHighlight",
      },
      columns = {
        { id = "stage", headerText = "Stages", width = STAGES_WIDTH, align = "LEFT" },
        { id = "delta", headerText = "Delta", width = DELTA_WIDTH, align = "RIGHT" },
        { id = "time", headerText = "Time", width = TIME_WIDTH, align = "RIGHT" },
        { id = "best", headerText = "Best", width = BEST_WIDTH, align = "RIGHT" },
      },
    }
    local timetable = LiqUI:NewElement("Table", tableOptions)
    timetable:SetParent(frame)
    timetable:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, 0)
    self.table = timetable

    local clockFrame = CreateFrame("Frame", nil, frame)
    clockFrame:SetPoint("TOPLEFT", timetable, "BOTTOMLEFT", 0, 0)
    clockFrame:SetPoint("TOPRIGHT", timetable, "BOTTOMRIGHT", 0, 0)
    clockFrame:SetHeight(CLOCK_HEIGHT)
    self.clockFrame = clockFrame

    local clock = clockFrame:CreateFontString(nil, "OVERLAY")
    clock:SetPoint("RIGHT", clockFrame, "RIGHT", -HEADER_PAD, 0)
    clock:SetJustifyH("RIGHT")
    clock:SetWordWrap(false)
    self.clock = clock

    local phrase = clockFrame:CreateFontString(nil, "OVERLAY")
    phrase:SetPoint("LEFT", clockFrame, "LEFT", HEADER_PAD, 0)
    phrase:SetPoint("RIGHT", clock, "LEFT", -12, 0)
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
  local timetable = self.table
  local clockFrame = self.clockFrame
  local clockString = self.clock
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
    or not timetable
    or not clockFrame
    or not clockString
    or not phrase
  then
    return
  end

  local options = Data.db.global.timer
  local inside = Capture:IsInside() or Capture:InInstance()
  local activeRun = inside and Data:GetActiveRun() or nil
  local background = options.backgroundColor or { r = 0, g = 0, b = 0, a = 0.5 }
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

  local stepRows = {}
  if activeRun then
    stepRows = Data:StepRows(activeRun)
    if options.showObjectives ~= false then
      fillObjectives(stepRows, activeRun)
    end
  else
    stepRows = sampleRows(options.showObjectiveCounts ~= false)
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
      compare = currentBest(stepRows)
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
    local compare = currentBest(stepRows)
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

  timetable:SetData(timetableRows(stepRows, ahead, behind, options.showObjectives ~= false))

  local tableWidth, tableHeight = timetable:GetSize()
  if tableWidth < 1 then
    tableWidth = STAGES_WIDTH + DELTA_WIDTH + TIME_WIDTH + BEST_WIDTH
  end
  if tableHeight < 1 then
    tableHeight = ROW_HEIGHT
  end
  timetable:SetSize(tableWidth, tableHeight)
  clockFrame:SetHeight(CLOCK_HEIGHT)
  frame:SetSize(tableWidth, HEADER_HEIGHT + tableHeight + CLOCK_HEIGHT)
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

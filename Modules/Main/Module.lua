---@class LDT_Addon
local addon = select(2, ...)

---@class LDT_Module_Main
local Module = addon.Core:NewModule("Main")
addon.Module_Main = Module

local Data = addon.Data
local Constants = addon.Constants
local Helpers = addon.Helpers
local Capture = addon.Capture
local LiqUI = addon.libs.LiqUI

local PANEL_WIDTH = 360
local HEADER_HEIGHT = 30
local PANEL_HEADER = 24
local ICON_SIZE = 16
local ICON_GAP = 6
local BORDER_INSET = 2
local TIME_WIDTH = 72
local CLOCK_TIME_WIDTH = 88
local VALUE_WIDTH = 72

local FONT_CLOCK = "GameFontNormalLarge"
local FONT_HEADER = "GameFontNormalLarge"
local FONT_PANEL = "GameFontNormal"
local FONT_ROW = "GameFontHighlightSmall"

---@class LDT_RowColumn
---@field text string
---@field font string|nil
---@field r number|nil
---@field g number|nil
---@field b number|nil
---@field align "LEFT"|"CENTER"|"RIGHT"|nil
---@field width number|nil
---@field icon number|string|nil
---@field spellID number|nil
---@field barMin number|nil
---@field barMax number|nil
---@field barValue number|nil
---@field textOnBar "center"|"left"|"right"|"above"|nil

---@class LDT_RowModel
---@field columns LDT_RowColumn[]
---@field height number|nil
---@field itemLink string|nil
---@field currencyID number|nil
---@field goldCopper number|nil

---@class LDT_WidgetColumnFrame : Frame
---@field text FontString
---@field icon Texture
---@field bar StatusBar
---@field textFrame Frame

---@class LDT_WidgetRowFrame : Frame
---@field columns LDT_WidgetColumnFrame[]

---@class LDT_WidgetPanel : Frame
---@field id LDT_SectionId
---@field header Button
---@field title FontString
---@field chevron Texture
---@field headerBackground Texture
---@field bodyBackground Texture
---@field rule Texture
---@field rowFrames LDT_WidgetRowFrame[]
---@field rows LDT_RowModel[]

---@param text string
---@param width number|nil
---@param align "LEFT"|"CENTER"|"RIGHT"|nil
---@param font string|nil
---@param r number|nil
---@param g number|nil
---@param b number|nil
---@return LDT_RowColumn
local function TextColumn(text, width, align, font, r, g, b)
  ---@type LDT_RowColumn
  local column = {
    text = text,
    width = width,
    align = align,
    font = font,
    r = r,
    g = g,
    b = b,
  }
  return column
end

---@param text string
---@param minValue number
---@param maxValue number
---@param value number
---@param textOnBar "center"|"left"|"right"|"above"|nil
---@return LDT_RowModel
local function BarRow(text, minValue, maxValue, value, textOnBar)
  local place = textOnBar or "center"
  ---@type LDT_RowColumn
  local column = {
    text = text,
    barMin = minValue,
    barMax = maxValue,
    barValue = value,
    textOnBar = place,
    align = "CENTER",
    r = 1,
    g = 1,
    b = 1,
  }
  if place == "left" or place == "above" then
    column.align = "LEFT"
  elseif place == "right" then
    column.align = "RIGHT"
  end
  ---@type LDT_RowModel
  local row = {
    columns = { column },
    height = place == "above" and 30 or 16,
  }
  return row
end

---@param label string
---@param elapsed number|nil
---@param bestElapsed number|nil
---@param large boolean|nil
---@return LDT_RowModel
local function SplitRow(label, elapsed, bestElapsed, large)
  local font = FONT_ROW
  local timeWidth = TIME_WIDTH
  local height = 16
  if large then
    font = FONT_CLOCK
    timeWidth = CLOCK_TIME_WIDTH
    height = 24
  end
  ---@type LDT_RowColumn[]
  local columns = {
    TextColumn(label, nil, "LEFT", font, 0.95, 0.95, 0.95),
  }
  if elapsed then
    columns[#columns + 1] = TextColumn(Helpers.FormatElapsed(elapsed), timeWidth, "RIGHT", font, 1, 0.82, 0.2)
  end
  if bestElapsed and elapsed then
    local delta = elapsed - bestElapsed
    local red, green, blue = 0.75, 0.75, 0.75
    if delta > 0.05 then
      red, green, blue = 1, 0.4, 0.4
    elseif delta < -0.05 then
      red, green, blue = 0.35, 0.9, 0.5
    end
    columns[#columns + 1] = TextColumn(Helpers.FormatDelta(delta), timeWidth, "RIGHT", font, red, green, blue)
  end
  ---@type LDT_RowModel
  local row = { columns = columns, height = height }
  return row
end

---@param record LDT_Record
---@return number
local function LiveElapsed(record)
  if record.result == Constants.runResult.Active then
    if Capture.clockReady then
      return Capture:Elapsed(record)
    end
    local last = record.log[#record.log]
    if last then
      return last.elapsed
    end
    return 0
  end
  if record.endedElapsed then
    return record.endedElapsed
  end
  return 0
end

---@param record LDT_Record
---@return number
local function HeadlineElapsed(record)
  if record.finishedElapsed or record.bossElapsed then
    return Helpers.CompletionTime(record) or LiveElapsed(record)
  end
  return LiveElapsed(record)
end

---@param record LDT_Record
---@param kind LDT_LogKindId
---@return LDT_LogEntry|nil
local function LastLog(record, kind)
  for index = #record.log, 1, -1 do
    local entry = record.log[index]
    if entry.kind == kind then
      return entry
    end
  end
  return nil
end

---@param best LDT_Record|nil
---@param encounterName string
---@return number|nil
local function BestEncounterTime(best, encounterName)
  if not best or not best.encounters then
    return nil
  end
  local match = LiqUI.Utils.TableFind(best.encounters, function(encounter)
    return encounter.encounterName == encounterName and encounter.success == 1
  end)
  if not match then
    return nil
  end
  return match.elapsed
end

---@param best LDT_Record|nil
---@param chamberName string
---@return number|nil
local function BestChamberTime(best, chamberName)
  if not best or not best.chambers then
    return nil
  end
  local match = LiqUI.Utils.TableFind(best.chambers, function(chamber)
    return chamber.name == chamberName and chamber.completedElapsed ~= nil
  end)
  if not match then
    return nil
  end
  return match.completedElapsed
end

---@param record LDT_Record
---@return string
local function RunTitle(record)
  local instance = record.instance
  local name = instance and instance.name
  if not name or name == "" then
    return "Delve"
  end
  return name
end

---@param record LDT_Record
---@param best LDT_Record|nil
---@return LDT_RowModel[]
local function RunRows(record, best)
  ---@type LDT_RowModel[]
  local rows = {}
  local tier = Helpers.RunTier(record)
  local difficulty = record.instance and record.instance.difficultyName
  local summary = "Delve"
  if tier then
    summary = format("Tier %d", tier)
  end
  if difficulty and difficulty ~= "" then
    summary = format("%s, %s", summary, difficulty)
  end
  if best then
    summary = format("%s, vs tier %d best", summary, tier)
  end
  rows[#rows + 1] = { columns = { TextColumn(summary, nil, "LEFT", FONT_ROW, 0.8, 0.8, 0.8) }, height = 16 }
  local place = record.place
  local placeName = place and place.subzone
  if not placeName or placeName == "" then
    placeName = place and place.zone
  end
  if placeName and placeName ~= "" then
    rows[#rows + 1] = { columns = { TextColumn(placeName, nil, "LEFT", FONT_ROW, 0.9, 0.9, 0.9) }, height = 16 }
  end
  local player = record.player
  if player then
    ---@type LDT_RowColumn[]
    local columns = {}
    if player.level then
      columns[#columns + 1] = TextColumn(format("Level %d", player.level), nil, "LEFT", FONT_ROW, 0.85, 0.85, 0.85)
    end
    if player.itemLevel then
      columns[#columns + 1] = TextColumn(format("ilvl %d", math.floor(player.itemLevel)), nil, "LEFT", FONT_ROW, 0.85, 0.85, 0.85)
    end
    if player.specName and player.specName ~= "" then
      columns[#columns + 1] = TextColumn(player.specName, nil, "LEFT", FONT_ROW, 0.85, 0.85, 0.85)
    end
    if #columns > 0 then
      rows[#rows + 1] = { columns = columns, height = 16 }
    end
  end
  ---@type LDT_RowColumn[]
  local status = {
    TextColumn(format("Deaths %d", record.deaths or 0), nil, "LEFT", FONT_ROW, 0.95, 0.55, 0.45),
  }
  if record.lives ~= nil then
    status[#status + 1] = TextColumn(format("Lives %d", record.lives), nil, "LEFT", FONT_ROW, 0.55, 0.9, 0.55)
  end
  local entered = #record.chambers
  if record.labyrinth or entered > 0 then
    local completed = 0
    LiqUI.Utils.TableForEach(record.chambers, function(chamber)
      if chamber.completedElapsed then
        completed = completed + 1
      end
    end)
    status[#status + 1] = TextColumn(format("Chambers %d/%d", completed, entered), nil, "RIGHT", FONT_ROW, 0.9, 0.9, 0.9)
  end
  rows[#rows + 1] = { columns = status, height = 16 }
  return rows
end

---@param record LDT_Record
---@param now number
---@return { description: string, appeared: number, completed: number|nil, failed: boolean|nil }[]
local function ObjectiveRows(record, now)
  ---@type { description: string, appeared: number, completed: number|nil, failed: boolean|nil }[]
  local order = {}
  ---@type table<number|string, { description: string, appeared: number, completed: number|nil, failed: boolean|nil }>
  local byKey = {}
  local completion = record.finishedElapsed
  local sealed = {}
  local log = record.log or {}
  for index = 1, #log do
    local entry = log[index]
    local kind = entry.kind
    if kind == Constants.logKind.Objective or kind == Constants.logKind.ObjectiveDone or kind == Constants.logKind.ObjectiveFailed then
      local detail = entry.detail
      local criteriaID = detail and detail.criteriaID
      local key = criteriaID or entry.text
      if completion and not byKey[key] and entry.elapsed > completion then
        sealed[key] = true
      end
      local row = byKey[key]
      if sealed[key] then
        row = nil
      end
      if not sealed[key] then
        if not row then
          local description = detail and detail.description
          if not description or description == "" then
            description = entry.text
          end
          row = { description = description, appeared = entry.elapsed }
          byKey[key] = row
          order[#order + 1] = row
        elseif detail and detail.description and detail.description ~= "" then
          row.description = detail.description
        end
        if kind == Constants.logKind.ObjectiveDone then
          row.completed = entry.elapsed
        elseif kind == Constants.logKind.ObjectiveFailed then
          row.failed = true
          row.completed = entry.elapsed
        end
      end
    end
  end
  local runFinished = record.sawDelveComplete or record.finishedElapsed
  local scenario = record.scenario
  local criteria = scenario and scenario.criteria
  if criteria and not runFinished then
    for index = 1, #criteria do
      local info = criteria[index]
      local criteriaID = info.criteriaID
      local description = info.description
      if criteriaID and not issecretvalue(criteriaID) and description and not issecretvalue(description) and description ~= "" then
        local row = byKey[criteriaID]
        if not row then
          row = { description = description, appeared = now }
          byKey[criteriaID] = row
          order[#order + 1] = row
        end
        local completed = info.completed
        if completed and not issecretvalue(completed) and completed and not row.completed then
          row.completed = now
        end
      end
    end
  end
  return order
end

---@param record LDT_Record
---@param best LDT_Record|nil
---@return LDT_RowModel[]
local function TimerRows(record, best)
  ---@type LDT_RowModel[]
  local rows = {}
  local now = HeadlineElapsed(record)
  local live = LiveElapsed(record)
  local bestFinish = best and Helpers.CompletionTime(best) or nil
  rows[#rows + 1] = SplitRow("Time", now, bestFinish, true)
  local spells = record.entrance and record.entrance.activeSpellIDs
  if spells and #spells > 0 then
    ---@type LDT_RowColumn[]
    local spellColumns = {}
    for index = 1, #spells do
      local spellID = spells[index]
      if spellID and not issecretvalue(spellID) then
        local texture = C_Spell.GetSpellTexture(spellID)
        if texture and not issecretvalue(texture) then
          local column = TextColumn("", 22, "CENTER")
          column.icon = texture
          column.spellID = spellID
          spellColumns[#spellColumns + 1] = column
        end
      end
    end
    if #spellColumns > 0 then
      rows[#rows + 1] = { columns = spellColumns, height = 22 }
    end
  end
  local frozen = record.finishedElapsed or record.bossElapsed
  local clock = live
  if frozen then
    clock = now
  end
  local objectives = ObjectiveRows(record, clock)
  for index = 1, #objectives do
    local objective = objectives[index]
    local label = objective.description
    if objective.failed then
      label = format("%s failed", label)
    end
    local elapsed = objective.completed
    if not elapsed and not (frozen and objective.appeared > clock) then
      elapsed = math.max(0, clock - objective.appeared)
    end
    rows[#rows + 1] = SplitRow(label, elapsed, nil, false)
  end
  for index = 1, #record.chambers do
    local chamber = record.chambers[index]
    local elapsed = chamber.completedElapsed
    if not elapsed and not (frozen and chamber.enteredElapsed > clock) then
      elapsed = math.max(0, clock - chamber.enteredElapsed)
    end
    local bestElapsed = nil
    if chamber.completedElapsed then
      bestElapsed = BestChamberTime(best, chamber.name)
    end
    rows[#rows + 1] = SplitRow(chamber.name, elapsed, bestElapsed, false)
  end
  for index = 1, #record.encounters do
    local encounter = record.encounters[index]
    local label = encounter.encounterName
    if encounter.success ~= 1 then
      label = format("%s failed", label)
    end
    local bestElapsed = nil
    if encounter.success == 1 then
      bestElapsed = BestEncounterTime(best, encounter.encounterName)
    end
    rows[#rows + 1] = SplitRow(label, encounter.elapsed, bestElapsed, false)
  end
  if record.finishedElapsed then
    rows[#rows + 1] = SplitRow("Complete", record.finishedElapsed, bestFinish, false)
  end
  if #rows == 1 and #objectives == 0 then
    rows[#rows + 1] = { columns = { TextColumn("No step or boss yet", nil, "LEFT", FONT_ROW, 0.6, 0.6, 0.6) }, height = 16 }
  end
  return rows
end

---@param record LDT_Record
---@return LDT_RowModel[]
local function CompanionRows(record)
  ---@type LDT_RowModel[]
  local rows = {}
  local companion = record.companion
  if not companion or not companion.name or companion.name == "" then
    rows[1] = { columns = { TextColumn("No companion", nil, "LEFT", FONT_ROW, 0.6, 0.6, 0.6) }, height = 16 }
    return rows
  end
  local header = companion.name
  if companion.level then
    header = format("%s  %d", header, companion.level)
    if companion.maxLevel then
      header = format("%s/%d", header, companion.maxLevel)
    end
  end
  rows[#rows + 1] = { columns = { TextColumn(header, nil, "LEFT", FONT_ROW, 0.95, 0.95, 0.95) }, height = 16 }
  local minValue = companion.reactionThreshold
  local maxValue = companion.nextThreshold
  local standing = companion.standing
  if minValue and maxValue and standing and maxValue > minValue then
    local span = maxValue - minValue
    local into = standing - minValue
    rows[#rows + 1] = BarRow(format("%d / %d", into, span), minValue, maxValue, standing, "center")
  end
  if companion.startStanding and companion.standing then
    local gained = companion.standing - companion.startStanding
    local gainedText = format("%d", gained)
    if gained > 0 then
      gainedText = format("+%d", gained)
    end
    rows[#rows + 1] = {
      columns = { TextColumn(format("This run %s", gainedText), nil, "LEFT", FONT_ROW, 0.4, 0.8, 1) },
      height = 16,
    }
  end
  ---@type LDT_RowColumn[]
  local sockets = {}
  local socketSpells = {
    companion.roleSpellID,
    companion.flavorSpellID,
    companion.combatCurioSpellID,
    companion.utilityCurioSpellID,
  }
  for index = 1, #socketSpells do
    local spellID = socketSpells[index]
    if spellID and not issecretvalue(spellID) then
      local texture = C_Spell.GetSpellTexture(spellID)
      if texture and not issecretvalue(texture) then
        local column = TextColumn("", 22, "CENTER")
        column.icon = texture
        column.spellID = spellID
        sockets[#sockets + 1] = column
      end
    end
  end
  if #sockets > 0 then
    rows[#rows + 1] = { columns = sockets, height = 22 }
  else
    if companion.flavorName and companion.flavorName ~= "" then
      rows[#rows + 1] = { columns = { TextColumn(companion.flavorName, nil, "LEFT", FONT_ROW, 0.75, 0.75, 0.75) }, height = 16 }
    end
    if companion.roleName and companion.roleName ~= "" then
      rows[#rows + 1] = { columns = { TextColumn(format("Role %s", companion.roleName), nil, "LEFT") }, height = 16 }
    end
    if companion.combatCurioName and companion.combatCurioName ~= "" then
      rows[#rows + 1] = { columns = { TextColumn(format("Combat %s", companion.combatCurioName), nil, "LEFT") }, height = 16 }
    end
    if companion.utilityCurioName and companion.utilityCurioName ~= "" then
      rows[#rows + 1] = { columns = { TextColumn(format("Utility %s", companion.utilityCurioName), nil, "LEFT") }, height = 16 }
    end
  end
  return rows
end

local boonColorNeedles

---@param label string
---@return number|nil, number|nil, number|nil
local function BoonStatColor(label)
  if not boonColorNeedles then
    boonColorNeedles = {}
    local colors = Constants.boonStatColors
    for index = 1, #colors do
      local entry = colors[index]
      local text = _G[entry.key]
      if type(text) == "string" and text ~= "" then
        boonColorNeedles[#boonColorNeedles + 1] = {
          text = text:lower(),
          r = entry.r,
          g = entry.g,
          b = entry.b,
        }
      end
    end
    table.sort(boonColorNeedles, function(left, right)
      return #left.text > #right.text
    end)
  end
  local lower = label:lower()
  for index = 1, #boonColorNeedles do
    local needle = boonColorNeedles[index]
    if #needle.text >= 4 and (lower == needle.text or lower:find(needle.text, 1, true)) then
      return needle.r, needle.g, needle.b
    end
  end
  return nil
end

---@param text string
---@param stats { label: string, value: string }[]
local function AppendBoonStats(text, stats)
  for line in text:gmatch("[^\r\n]+") do
    local label, value = line:match("^%s*(.-)%s*:%s*(.-)%s*$")
    if label and label ~= "" and value and value ~= "" then
      local amount = Helpers.BoonAmount(value)
      if amount then
        value = Helpers.FormatBoonAmount(amount)
      else
        value = value:gsub("%s+$", ""):gsub("%.$", "")
      end
      stats[#stats + 1] = { label = label, value = value }
    end
  end
end

---@param record LDT_Record
---@return LDT_RowModel[]
local function BoonRows(record)
  ---@type LDT_RowModel[]
  local rows = {}
  local boons = record.boons or {}
  ---@type { label: string, value: string }[]
  local stats = {}
  for index = 1, #boons do
    local boon = boons[index]
    if boon.label and boon.amount then
      stats[#stats + 1] = { label = boon.label, value = Helpers.FormatBoonAmount(boon.amount) }
    elseif boon.text and boon.text ~= "" then
      AppendBoonStats(boon.text, stats)
    end
  end
  if #stats == 0 then
    rows[1] = { columns = { TextColumn("No boons", nil, "LEFT", FONT_ROW, 0.6, 0.6, 0.6) }, height = 16 }
    return rows
  end
  local index = 1
  while index <= #stats do
    local stat = stats[index]
    local nextStat = stats[index + 1]
    local nextLabel = ""
    local nextValue = ""
    local statR, statG, statB = BoonStatColor(stat.label)
    local nextR, nextG, nextB
    if nextStat then
      nextLabel = nextStat.label
      nextValue = nextStat.value
      nextR, nextG, nextB = BoonStatColor(nextLabel)
    end
    rows[#rows + 1] = {
      columns = {
        TextColumn(stat.label, nil, "LEFT", FONT_ROW, statR or 0.85, statG or 0.85, statB or 0.85),
        TextColumn(stat.value, 56, "RIGHT", FONT_ROW, statR or 0.75, statG or 0.9, statB or 0.7),
        TextColumn(nextLabel, nil, "LEFT", FONT_ROW, nextR or 0.85, nextG or 0.85, nextB or 0.85),
        TextColumn(nextValue, 56, "RIGHT", FONT_ROW, nextR or 0.75, nextG or 0.9, nextB or 0.7),
      },
      height = 16,
    }
    index = index + 2
  end
  return rows
end

---@param amount number
---@return string
local function SignedCount(amount)
  if amount > 0 then
    return format("+%d", amount)
  end
  return tostring(amount)
end

---@param record LDT_Record
---@return LDT_RowModel[]
local function GainsRows(record)
  ---@type LDT_RowModel[]
  local rows = {}
  local gold = record.gold
  if gold and gold.gained and gold.gained > 0 then
    rows[#rows + 1] = {
      columns = {
        TextColumn("Gold", nil, "LEFT"),
        TextColumn(Helpers.FormatMoney(gold.gained), nil, "RIGHT", FONT_ROW, 1, 1, 1),
      },
      height = 16,
      goldCopper = gold.gained,
    }
  end
  local changes = record.currencies or {}
  ---@type table<number, number>
  local seen = {}
  ---@type number[]
  local order = {}
  for index = 1, #changes do
    local change = changes[index]
    local total = seen[change.currencyID]
    if not total then
      order[#order + 1] = change.currencyID
      seen[change.currencyID] = change.change
    else
      seen[change.currencyID] = total + change.change
    end
  end
  for index = 1, #order do
    local currencyID = order[index]
    local total = seen[currencyID]
    if total ~= 0 and Helpers.CurrencyListed(currencyID) then
      local name = tostring(currencyID)
      for changeIndex = #changes, 1, -1 do
        local change = changes[changeIndex]
        if change.currencyID == currencyID and change.name and change.name ~= "" then
          name = change.name
          break
        end
      end
      local nameColumn = TextColumn(name, nil, "LEFT")
      local info = C_CurrencyInfo.GetCurrencyInfo(currencyID)
      if info and info.iconFileID and not issecretvalue(info.iconFileID) and info.iconFileID > 0 then
        nameColumn.icon = info.iconFileID
      end
      rows[#rows + 1] = {
        columns = {
          nameColumn,
          TextColumn(SignedCount(total), VALUE_WIDTH, "RIGHT", FONT_ROW, 0.5, 0.85, 1),
        },
        height = 18,
        currencyID = currencyID,
      }
    end
  end
  local loot = record.loot or {}
  ---@type { itemID: number|nil, itemLink: string|nil, quantity: number, elapsed: number, quality: number, qualityKnown: boolean, name: string }[]
  local items = {}
  for index = 1, #loot do
    local item = loot[index]
    if not Helpers.ItemHidden(item.itemID) then
      local quantity = item.quantity or 1
      local elapsed = item.elapsed or 0
      local match
      for itemIndex = 1, #items do
        local existing = items[itemIndex]
        local sameItem = (item.itemID and existing.itemID == item.itemID) or (not item.itemID and existing.itemLink == item.itemLink)
        if sameItem then
          match = existing
          break
        end
      end
      if not match then
        items[#items + 1] = {
          itemID = item.itemID,
          itemLink = item.itemLink,
          quantity = quantity,
          elapsed = elapsed,
          quality = 0,
          qualityKnown = false,
          name = "",
        }
      elseif math.abs(elapsed - match.elapsed) < 2 then
        if quantity > match.quantity then
          match.quantity = quantity
        end
        if item.itemLink then
          match.itemLink = item.itemLink
        end
      else
        match.quantity = match.quantity + quantity
        match.elapsed = elapsed
        if item.itemLink then
          match.itemLink = item.itemLink
        end
      end
    end
  end
  for index = 1, #items do
    local item = items[index]
    item.quality = 0
    item.qualityKnown = false
    local quality
    if item.itemLink then
      local _, _, linkQuality = C_Item.GetItemInfo(item.itemLink)
      if linkQuality and not issecretvalue(linkQuality) then
        quality = linkQuality
      end
    elseif item.itemID then
      local baseQuality = C_Item.GetItemQualityByID(item.itemID)
      if baseQuality and not issecretvalue(baseQuality) then
        quality = baseQuality
      else
        C_Item.RequestLoadItemDataByID(item.itemID)
      end
    end
    if quality then
      item.quality = quality
      item.qualityKnown = true
    end
    item.name = ""
    if item.itemLink then
      item.name = item.itemLink:match("%[(.-)%]") or item.itemLink
    end
  end
  table.sort(items, function(left, right)
    if left.quantity ~= right.quantity then
      return left.quantity > right.quantity
    end
    if left.quality ~= right.quality then
      return left.quality > right.quality
    end
    return left.name < right.name
  end)
  for index = 1, #items do
    local item = items[index]
    local label = item.name
    if label == "" then
      label = "Item"
    end
    local red, green, blue
    if item.qualityKnown then
      local colorR, colorG, colorB = C_Item.GetItemQualityColor(item.quality)
      if colorR and not issecretvalue(colorR) then
        red, green, blue = colorR, colorG, colorB
      end
    end
    ---@type LDT_RowColumn
    local nameColumn = TextColumn(label, nil, "LEFT", nil, red, green, blue)
    if item.itemID then
      local texture = C_Item.GetItemIconByID(item.itemID)
      if texture then
        nameColumn.icon = texture
      end
    end
    ---@type LDT_RowModel
    local row = {
      columns = {
        nameColumn,
        TextColumn(tostring(item.quantity), VALUE_WIDTH, "RIGHT"),
      },
      height = 18,
    }
    if item.itemLink and item.itemLink:find("|H", 1, true) then
      row.itemLink = item.itemLink
    end
    rows[#rows + 1] = row
  end
  if #rows == 0 then
    rows[1] = { columns = { TextColumn("No gains yet", nil, "LEFT", FONT_ROW, 0.6, 0.6, 0.6) }, height = 16 }
  end
  return rows
end

---@param record LDT_Record
---@return LDT_RowModel[]
local function RenownRows(record)
  ---@type LDT_RowModel[]
  local rows = {}
  local renowns = record.renowns or {}
  if #renowns == 0 then
    rows[1] = { columns = { TextColumn("No renown change", nil, "LEFT", FONT_ROW, 0.6, 0.6, 0.6) }, height = 16 }
    return rows
  end
  for index = 1, #renowns do
    local row = renowns[index]
    local threshold = row.threshold
    if not threshold or threshold <= 0 then
      threshold = 1
    end
    local name = row.name or "Renown"
    rows[#rows + 1] = BarRow(format("%s  %d  %d/%d", name, row.level, row.earned, threshold), 0, threshold, math.min(row.earned, threshold), "center")
  end
  return rows
end

---@param parent Frame
---@return LDT_WidgetColumnFrame
local function CreateColumn(parent)
  ---@type LDT_WidgetColumnFrame
  local column = CreateFrame("Frame", nil, parent)
  local bar = CreateFrame("StatusBar", nil, column)
  bar:SetStatusBarTexture("Interface/Buttons/WHITE8X8")
  bar:SetStatusBarColor(0.25, 0.55, 0.9, 0.95)
  bar:SetAllPoints()
  bar:Hide()
  local background = bar:CreateTexture(nil, "BACKGROUND")
  background:SetAllPoints()
  background:SetColorTexture(1, 1, 1, 0.08)
  column.bar = bar
  local textFrame = CreateFrame("Frame", nil, column)
  textFrame:SetAllPoints()
  textFrame:SetFrameLevel(bar:GetFrameLevel() + 2)
  column.textFrame = textFrame
  local icon = textFrame:CreateTexture(nil, "OVERLAY")
  icon:SetSize(18, 18)
  icon:SetPoint("LEFT", textFrame, "LEFT", 0, 0)
  icon:Hide()
  column.icon = icon
  local text = textFrame:CreateFontString(nil, "OVERLAY", FONT_ROW)
  text:SetPoint("LEFT", textFrame, "LEFT", 0, 0)
  text:SetPoint("RIGHT", textFrame, "RIGHT", 0, 0)
  text:SetJustifyH("LEFT")
  text:SetJustifyV("MIDDLE")
  text:SetWordWrap(true)
  column.text = text
  return column
end

---@param column LDT_WidgetColumnFrame
---@param model LDT_RowColumn
---@param rowHeight number
local function ApplyColumn(column, model, rowHeight)
  local text = column.text
  local bar = column.bar
  local icon = column.icon
  text:SetFontObject(model.font or FONT_ROW)
  local bodyColor = Data.db.global.widget.bodyFontColor
  local red, green, blue = 0.9, 0.9, 0.9
  if bodyColor then
    red, green, blue = bodyColor.r, bodyColor.g, bodyColor.b
  end
  text:SetTextColor(model.r or red, model.g or green, model.b or blue)
  text:SetJustifyH(model.align or "LEFT")
  text:SetText(model.text or "")
  if model.icon then
    icon:SetTexture(model.icon)
    icon:Show()
  else
    icon:Hide()
  end
  text:ClearAllPoints()
  bar:ClearAllPoints()
  if model.barValue ~= nil then
    bar:Show()
    bar:SetMinMaxValues(model.barMin or 0, model.barMax or 1)
    local maxValue = model.barMax or 1
    local value = model.barValue
    if value > maxValue then
      value = maxValue
    end
    bar:SetValue(value)
    if model.textOnBar == "above" then
      bar:SetPoint("BOTTOMLEFT", column, "BOTTOMLEFT", 0, 0)
      bar:SetPoint("BOTTOMRIGHT", column, "BOTTOMRIGHT", 0, 0)
      bar:SetHeight(12)
      text:SetPoint("TOPLEFT", column.textFrame, "TOPLEFT", 0, 0)
      text:SetPoint("TOPRIGHT", column.textFrame, "TOPRIGHT", 0, 0)
    else
      bar:SetAllPoints()
      local left = 4
      if icon:IsShown() then
        left = 20
      end
      text:SetPoint("LEFT", column.textFrame, "LEFT", left, 0)
      text:SetPoint("RIGHT", column.textFrame, "RIGHT", -4, 0)
    end
  else
    bar:Hide()
    if icon:IsShown() then
      text:SetPoint("LEFT", icon, "RIGHT", 4, 0)
    else
      text:SetPoint("LEFT", column.textFrame, "LEFT", 0, 0)
    end
    text:SetPoint("RIGHT", column.textFrame, "RIGHT", 0, 0)
    text:SetHeight(rowHeight)
  end
  column:SetHeight(rowHeight)
end

---@return LDT_Spacing
local function SpacingMetrics()
  local id = Data.db.global.widget.spacing
  local fallback = Constants.spacings[1]
  for index = 1, #Constants.spacings do
    local choice = Constants.spacings[index]
    if choice.id == Constants.spacingId.Default then
      fallback = choice
    end
    if choice.id == id then
      return choice
    end
  end
  return fallback
end

---@param panel LDT_WidgetPanel
---@param spacing LDT_Spacing
local function LayoutPanel(panel, spacing)
  local rows = panel.rows or {}
  local y = -PANEL_HEADER
  for index = 1, #rows do
    local model = rows[index]
    local row = panel.rowFrames[index]
    if not row then
      ---@type LDT_WidgetRowFrame
      local created = CreateFrame("Frame", nil, panel)
      created.columns = {}
      panel.rowFrames[index] = created
      row = created
    end
    row:Show()
    local rowHeight = model.height or 16
    if model.itemLink or model.currencyID or model.goldCopper then
      row:EnableMouse(true)
      row:SetScript("OnEnter", function()
        GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
        if model.itemLink then
          GameTooltip:SetHyperlink(model.itemLink)
        elseif model.currencyID then
          GameTooltip:SetHyperlink(format("currency:%d", model.currencyID))
        else
          GameTooltip:SetText("Gold", 1, 0.82, 0)
          GameTooltip:AddLine(Helpers.FormatMoney(model.goldCopper), 1, 1, 1)
        end
        GameTooltip:Show()
      end)
      row:SetScript("OnLeave", function()
        GameTooltip:Hide()
      end)
    else
      row:EnableMouse(false)
      row:SetScript("OnEnter", nil)
      row:SetScript("OnLeave", nil)
    end
    row:ClearAllPoints()
    row:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, y)
    row:SetPoint("TOPRIGHT", panel, "TOPRIGHT", 0, 0)
    row:SetHeight(rowHeight)
    local columns = model.columns
    local gap = spacing.column
    local panelWidth = panel:GetWidth()
    if panelWidth <= 0 then
      panelWidth = PANEL_WIDTH
    end
    local inner = panelWidth - (spacing.horizontal * 2) - (math.max(#columns - 1, 0) * gap)
    local used = 0
    local flex = 0
    for columnIndex = 1, #columns do
      local width = columns[columnIndex].width
      if width then
        used = used + width
      else
        flex = flex + 1
      end
    end
    local flexWidth = 0
    if flex > 0 then
      flexWidth = (inner - used) / flex
    end
    local x = spacing.horizontal
    for columnIndex = 1, #columns do
      local column = row.columns[columnIndex]
      if not column then
        column = CreateColumn(row)
        row.columns[columnIndex] = column
      end
      column:Show()
      local width = columns[columnIndex].width or flexWidth
      column:ClearAllPoints()
      column:SetPoint("TOPLEFT", row, "TOPLEFT", x, 0)
      column:SetWidth(math.max(width, 1))
      ApplyColumn(column, columns[columnIndex], rowHeight)
      local spellID = columns[columnIndex].spellID
      local textFrame = column.textFrame
      if spellID then
        textFrame:EnableMouse(true)
        textFrame:SetScript("OnEnter", function()
          GameTooltip:SetOwner(textFrame, "ANCHOR_RIGHT")
          GameTooltip:SetSpellByID(spellID)
          GameTooltip:Show()
        end)
        textFrame:SetScript("OnLeave", function()
          GameTooltip:Hide()
        end)
      else
        textFrame:EnableMouse(false)
        textFrame:SetScript("OnEnter", nil)
        textFrame:SetScript("OnLeave", nil)
      end
      x = x + width + gap
    end
    for columnIndex = #columns + 1, #row.columns do
      row.columns[columnIndex]:Hide()
    end
    y = y - rowHeight
    if index < #rows then
      y = y - spacing.row
    end
  end
  for index = #rows + 1, #panel.rowFrames do
    panel.rowFrames[index]:Hide()
  end
  if #rows == 0 then
    panel:SetHeight(PANEL_HEADER)
    return
  end
  panel:SetHeight(-y)
end

---@param color ColorTable
---@param apply function
local function ShowColorPicker(color, apply)
  local previous = { r = color.r, g = color.g, b = color.b, a = color.a }
  ColorPickerFrame:SetupColorPickerAndShow({
    r = color.r,
    g = color.g,
    b = color.b,
    opacity = color.a,
    hasOpacity = 1,
    swatchFunc = function()
      local red, green, blue = ColorPickerFrame:GetColorRGB()
      local alpha = ColorPickerFrame:GetColorAlpha()
      if red then
        color.r = red
        color.g = green
        color.b = blue
        color.a = alpha or color.a
        apply()
      end
    end,
    opacityFunc = function()
      local alpha = ColorPickerFrame:GetColorAlpha()
      if alpha then
        color.a = alpha
        apply()
      end
    end,
    cancelFunc = function()
      color.r = previous.r
      color.g = previous.g
      color.b = previous.b
      color.a = previous.a
      apply()
    end,
  })
end

function Module:BuildSettingsMenu(rootMenu)
  local widget = Data.db.global.widget
  rootMenu:CreateTitle("Tracker")
  rootMenu:CreateCheckbox("Show tracker", function()
    return self.frame and self.frame:IsShown()
  end, function()
    self:ToggleWindow()
  end)
  rootMenu:CreateButton("Records", function()
    if addon.Module_Records then
      addon.Module_Records:ToggleWindow()
    end
  end)
  rootMenu:CreateTitle("Appearance")
  local sectionsMenu = rootMenu:CreateButton("Sections")
  for index = 1, #Constants.sections do
    local section = Constants.sections[index]
    sectionsMenu:CreateCheckbox(section.label, function()
      return widget.sections[section.id].enabled
    end, function()
      local settings = widget.sections[section.id]
      settings.enabled = not settings.enabled
      self:Render()
    end)
  end
  local themeMenu = rootMenu:CreateButton("Theme")
  for index = 1, #Constants.themes do
    local theme = Constants.themes[index]
    themeMenu:CreateRadio(theme.label, function()
      return widget.theme == theme.id
    end, function()
      widget.theme = theme.id
      self:Render()
    end, theme.id)
  end
  local colorsMenu = rootMenu:CreateButton("Colors")
  local widgetColors = colorsMenu:CreateButton("Widget")
  widgetColors:CreateColorSwatch("Background", function()
    ShowColorPicker(widget.backgroundColor, function()
      self:Render()
    end)
  end, widget.backgroundColor)
  widgetColors:CreateColorSwatch("Header background", function()
    ShowColorPicker(widget.headerBackgroundColor, function()
      self:Render()
    end)
  end, widget.headerBackgroundColor)
  widgetColors:CreateColorSwatch("Header text", function()
    ShowColorPicker(widget.headerFontColor, function()
      self:Render()
    end)
  end, widget.headerFontColor)
  widgetColors:CreateColorSwatch("Text", function()
    ShowColorPicker(widget.bodyFontColor, function()
      self:Render()
    end)
  end, widget.bodyFontColor)
  local sectionColors = colorsMenu:CreateButton("Sections")
  sectionColors:CreateColorSwatch("Header background", function()
    ShowColorPicker(widget.panelHeaderBackgroundColor, function()
      self:Render()
    end)
  end, widget.panelHeaderBackgroundColor)
  sectionColors:CreateColorSwatch("Header text", function()
    ShowColorPicker(widget.panelHeaderFontColor, function()
      self:Render()
    end)
  end, widget.panelHeaderFontColor)
  sectionColors:CreateColorSwatch("Header line", function()
    ShowColorPicker(widget.sectionRuleColor, function()
      self:Render()
    end)
  end, widget.sectionRuleColor)
  sectionColors:CreateColorSwatch("Background", function()
    ShowColorPicker(widget.sectionBackgroundColor, function()
      self:Render()
    end)
  end, widget.sectionBackgroundColor)
  local borderMenu = rootMenu:CreateButton("Border")
  borderMenu:CreateCheckbox("Enabled", function()
    return widget.border.enabled
  end, function()
    widget.border.enabled = not widget.border.enabled
    self:Render()
  end)
  borderMenu:CreateColorSwatch("Color", function()
    ShowColorPicker(widget.border.color, function()
      widget.border.enabled = true
      self:Render()
    end)
  end, widget.border.color)
  local spacingMenu = rootMenu:CreateButton("Spacing")
  for index = 1, #Constants.spacings do
    local choice = Constants.spacings[index]
    spacingMenu:CreateRadio(choice.label, function()
      return widget.spacing == choice.id
    end, function()
      widget.spacing = choice.id
      self:Render()
    end, choice.id)
  end
  local sectionGapMenu = spacingMenu:CreateButton("Between sections")
  for index = 1, #Constants.sectionGaps do
    local choice = Constants.sectionGaps[index]
    sectionGapMenu:CreateRadio(choice.label, function()
      return widget.sectionGap == choice.value
    end, function()
      widget.sectionGap = choice.value
      self:Render()
    end, choice.value)
  end
end

function Module:OpenMenu(owner)
  self:Render()
  MenuUtil.CreateContextMenu(owner, function(_, rootMenu)
    self:BuildSettingsMenu(rootMenu)
  end)
end

function Module:Build()
  if self.frame then
    return
  end
  local widget = Data.db.global.widget
  local frame = CreateFrame("Frame", addon.name .. "Tracker", UIParent, "BackdropTemplate")
  frame:SetSize(PANEL_WIDTH, HEADER_HEIGHT)
  frame:SetPoint(widget.point, UIParent, widget.relativePoint, widget.x, widget.y)
  frame:SetMovable(true)
  frame:SetClampedToScreen(true)
  frame:SetFrameStrata("MEDIUM")

  local header = CreateFrame("Button", nil, frame)
  header:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
  header:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
  header:SetHeight(HEADER_HEIGHT)
  header:RegisterForDrag("LeftButton")
  local headerBackground = header:CreateTexture(nil, "BACKGROUND")
  headerBackground:SetAllPoints()
  headerBackground:SetColorTexture(0, 0, 0, 0.35)
  local headerRule = header:CreateTexture(nil, "BORDER")
  headerRule:SetHeight(1)
  headerRule:SetPoint("BOTTOMLEFT", header, "BOTTOMLEFT", 8, 0)
  headerRule:SetPoint("BOTTOMRIGHT", header, "BOTTOMRIGHT", -8, 0)
  headerRule:SetColorTexture(1, 0.82, 0, 0.45)

  local function BindTooltip(owner, text)
    owner:SetScript("OnEnter", function()
      GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
      GameTooltip:SetText(text, 1, 1, 1)
      GameTooltip:Show()
    end)
    owner:SetScript("OnLeave", function()
      GameTooltip:Hide()
    end)
  end

  local function PinTopRight()
    if self.dragging then
      return
    end
    local right = frame:GetRight()
    local top = frame:GetTop()
    local parentRight = UIParent:GetRight()
    local parentTop = UIParent:GetTop()
    if not right or not top or not parentRight or not parentTop or parentRight <= 0 then
      return
    end
    local x = right - parentRight
    local y = top - parentTop
    frame:ClearAllPoints()
    frame:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", x, y)
    widget.point = "TOPRIGHT"
    widget.relativePoint = "TOPRIGHT"
    widget.x = x
    widget.y = y
  end

  header:SetScript("OnDragStart", function()
    self.dragging = true
    frame:StartMoving()
  end)
  header:SetScript("OnDragStop", function()
    frame:StopMovingOrSizing()
    self.dragging = false
    PinTopRight()
  end)

  local closeButton = CreateFrame("Button", nil, header)
  closeButton:SetSize(ICON_SIZE, ICON_SIZE)
  closeButton:SetPoint("RIGHT", header, "RIGHT", -8, 0)
  local closeIcon = closeButton:CreateTexture(nil, "ARTWORK")
  closeIcon:SetAllPoints()
  closeIcon:SetAtlas("common-search-clearbutton")
  closeButton:SetScript("OnClick", function()
    frame:Hide()
  end)
  BindTooltip(closeButton, "Close")

  local minimizeButton = CreateFrame("Button", nil, header)
  minimizeButton:SetSize(18, 18)
  minimizeButton:SetPoint("RIGHT", closeButton, "LEFT", -ICON_GAP, 0)
  local minimizeIcon = minimizeButton:CreateTexture(nil, "ARTWORK")
  minimizeIcon:SetAllPoints()
  minimizeIcon:SetAtlas("ui-questtrackerbutton-collapse-all")
  local minimizeHighlight = minimizeButton:CreateTexture(nil, "HIGHLIGHT")
  minimizeHighlight:SetAllPoints()
  minimizeHighlight:SetAtlas("ui-questtrackerbutton-red-highlight")
  minimizeHighlight:SetBlendMode("ADD")
  minimizeButton:SetHighlightTexture(minimizeHighlight)
  minimizeButton:SetScript("OnClick", function()
    widget.minimized = not widget.minimized
    self:Render()
  end)
  BindTooltip(minimizeButton, "Collapse")

  local recordsButton = CreateFrame("Button", nil, header)
  recordsButton:SetSize(ICON_SIZE, ICON_SIZE)
  recordsButton:SetPoint("RIGHT", minimizeButton, "LEFT", -ICON_GAP, 0)
  local recordsIcon = recordsButton:CreateTexture(nil, "ARTWORK")
  recordsIcon:SetAllPoints()
  recordsIcon:SetTexture(Constants.media.Icon)
  recordsButton:SetScript("OnClick", function()
    if addon.Module_Records then
      addon.Module_Records:ToggleWindow()
    end
  end)
  BindTooltip(recordsButton, "Records")

  local cog = CreateFrame("DropdownButton", nil, header)
  cog:SetSize(ICON_SIZE, ICON_SIZE)
  cog:SetPoint("RIGHT", recordsButton, "LEFT", -ICON_GAP, 0)
  local cogIcon = cog:CreateTexture(nil, "ARTWORK")
  cogIcon:SetAllPoints()
  cogIcon:SetTexture(LiqUI.Constants.layout.media.iconSettings)
  cog.menuGenerator = function(_, rootMenu)
    self:BuildSettingsMenu(rootMenu)
  end
  BindTooltip(cog, "Settings")

  local title = header:CreateFontString(nil, "OVERLAY", FONT_HEADER)
  title:SetPoint("LEFT", header, "LEFT", 8, 0)
  title:SetPoint("RIGHT", header, "RIGHT", -((ICON_SIZE * 4) + (ICON_GAP * 3) + 16), 0)
  title:SetJustifyH("LEFT")
  title:SetJustifyV("MIDDLE")
  title:SetWordWrap(false)
  title:SetText("Delve")

  ---@type table<LDT_SectionId, LDT_WidgetPanel>
  local panels = {}
  for index = 1, #Constants.sections do
    local info = Constants.sections[index]
    ---@type LDT_WidgetPanel
    local panel = CreateFrame("Frame", nil, frame)
    panel.id = info.id
    panel.rowFrames = {}
    panel.rows = {}
    local panelHeader = CreateFrame("Button", nil, panel)
    panelHeader:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, 0)
    panelHeader:SetPoint("TOPRIGHT", panel, "TOPRIGHT", 0, 0)
    panelHeader:SetHeight(PANEL_HEADER)
    local panelBackground = panelHeader:CreateTexture(nil, "BACKGROUND")
    panelBackground:SetAllPoints()
    panelBackground:SetColorTexture(1, 1, 1, 0.06)
    local highlight = panelHeader:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints()
    highlight:SetColorTexture(1, 1, 1, 0.14)
    panelHeader:SetHighlightTexture(highlight)
    local bodyBackground = panel:CreateTexture(nil, "BACKGROUND")
    bodyBackground:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -PANEL_HEADER)
    bodyBackground:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", 0, 0)
    bodyBackground:SetColorTexture(0, 0, 0, 0)
    bodyBackground:Hide()
    local rule = panelHeader:CreateTexture(nil, "BORDER")
    rule:SetHeight(1)
    rule:SetPoint("BOTTOMLEFT", panelHeader, "BOTTOMLEFT", 8, 0)
    rule:SetPoint("BOTTOMRIGHT", panelHeader, "BOTTOMRIGHT", -8, 0)
    rule:SetColorTexture(1, 0.82, 0, 0.35)
    local chevron = panelHeader:CreateTexture(nil, "ARTWORK")
    chevron:SetSize(16, 16)
    chevron:SetPoint("RIGHT", panelHeader, "RIGHT", -8, 0)
    chevron:SetAtlas("ui-questtrackerbutton-secondary-collapse")
    local panelTitle = panelHeader:CreateFontString(nil, "OVERLAY", FONT_PANEL)
    panelTitle:SetPoint("LEFT", panelHeader, "LEFT", 8, 0)
    panelTitle:SetPoint("RIGHT", panelHeader, "RIGHT", -28, 0)
    panelTitle:SetJustifyH("LEFT")
    panelTitle:SetJustifyV("MIDDLE")
    panelTitle:SetWordWrap(false)
    panelTitle:SetText(info.label)
    panelHeader:SetScript("OnClick", function()
      local settings = widget.sections[info.id]
      settings.collapsed = not settings.collapsed
      self:Render()
    end)
    panel.header = panelHeader
    panel.title = panelTitle
    panel.chevron = chevron
    panel.headerBackground = panelBackground
    panel.bodyBackground = bodyBackground
    panel.rule = rule
    panels[info.id] = panel
  end

  self.frame = frame
  self.title = title
  self.header = header
  self.headerBackground = headerBackground
  self.headerRule = headerRule
  self.closeButton = closeButton
  self.minimizeIcon = minimizeIcon
  self.panels = panels
  self.pinTopRight = PinTopRight
  frame:Hide()
  frame:SetScript("OnShow", function()
    widget.shown = true
  end)
  frame:SetScript("OnHide", function()
    widget.shown = false
  end)
end

function Module:ApplyChrome()
  local frame = self.frame
  local widget = Data.db.global.widget
  if not frame then
    return
  end
  local background = widget.backgroundColor
  ---@type Backdrop
  local backdrop = { bgFile = "Interface/Buttons/WHITE8X8" }
  if widget.border.enabled then
    backdrop.edgeFile = "Interface/Buttons/WHITE8X8"
    backdrop.edgeSize = 1
  end
  frame:SetBackdrop(backdrop)
  frame:SetBackdropColor(background.r, background.g, background.b, background.a)
  if widget.border.enabled then
    local border = widget.border.color
    frame:SetBackdropBorderColor(border.r, border.g, border.b, border.a)
  end
  local headerColor = widget.headerBackgroundColor
  if self.headerBackground and headerColor then
    self.headerBackground:SetColorTexture(headerColor.r, headerColor.g, headerColor.b, headerColor.a)
  end
  local headerFont = widget.headerFontColor
  if self.title and headerFont then
    self.title:SetTextColor(headerFont.r, headerFont.g, headerFont.b)
  end
  local flat = widget.theme == Constants.themeId.Flat
  if self.headerRule then
    self.headerRule:SetShown(not flat)
    if not flat and headerFont then
      self.headerRule:SetColorTexture(headerFont.r, headerFont.g, headerFont.b, 0.45)
    end
  end
  local panelColor = widget.panelHeaderBackgroundColor
  local panelFont = widget.panelHeaderFontColor
  local ruleColor = widget.sectionRuleColor
  local sectionColor = widget.sectionBackgroundColor
  if self.panels and panelColor and panelFont then
    for index = 1, #Constants.sections do
      local panel = self.panels[Constants.sections[index].id]
      panel.headerBackground:Show()
      panel.headerBackground:SetColorTexture(panelColor.r, panelColor.g, panelColor.b, panelColor.a)
      panel.title:SetTextColor(panelFont.r, panelFont.g, panelFont.b)
      if ruleColor and ruleColor.a > 0 then
        panel.rule:Show()
        panel.rule:SetColorTexture(ruleColor.r, ruleColor.g, ruleColor.b, ruleColor.a)
      else
        panel.rule:Hide()
      end
      if sectionColor and sectionColor.a > 0 then
        panel.bodyBackground:Show()
        panel.bodyBackground:SetColorTexture(sectionColor.r, sectionColor.g, sectionColor.b, sectionColor.a)
      else
        panel.bodyBackground:Hide()
      end
    end
  end
end

function Module:Layout()
  local frame = self.frame
  local panels = self.panels
  if not frame or not panels then
    return
  end
  local widget = Data.db.global.widget
  local spacing = SpacingMetrics()
  local inset = 0
  if widget.border.enabled then
    inset = BORDER_INSET
  end
  local header = self.header
  if header then
    header:SetPoint("TOPLEFT", frame, "TOPLEFT", inset, -inset)
    header:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -inset, -inset)
  end
  if header and self.closeButton then
    self.closeButton:SetPoint("RIGHT", header, "RIGHT", -spacing.horizontal, 0)
  end
  if header and self.title and self.headerRule then
    local buttonRow = (ICON_SIZE * 4) + (ICON_GAP * 3) + 8
    self.title:SetPoint("LEFT", header, "LEFT", spacing.horizontal, 0)
    self.title:SetPoint("RIGHT", header, "RIGHT", -(spacing.horizontal + buttonRow), 0)
    self.headerRule:SetPoint("BOTTOMLEFT", header, "BOTTOMLEFT", spacing.horizontal, 0)
    self.headerRule:SetPoint("BOTTOMRIGHT", header, "BOTTOMRIGHT", -spacing.horizontal, 0)
  end
  local point = frame:GetPoint(1)
  if point ~= "TOPRIGHT" and self.pinTopRight then
    self.pinTopRight()
  end
  if self.minimizeIcon then
    if widget.minimized then
      self.minimizeIcon:SetAtlas("ui-questtrackerbutton-expand-all")
    else
      self.minimizeIcon:SetAtlas("ui-questtrackerbutton-collapse-all")
    end
  end
  if widget.minimized then
    for index = 1, #Constants.sections do
      panels[Constants.sections[index].id]:Hide()
    end
    frame:SetHeight(HEADER_HEIGHT + (inset * 2))
    return
  end
  local gap = widget.sectionGap or 0
  local y = -(HEADER_HEIGHT + inset)
  if gap > 0 then
    y = y - gap
  end
  local placed = false
  for index = 1, #Constants.sections do
    local info = Constants.sections[index]
    local panel = panels[info.id]
    local settings = widget.sections[info.id]
    if not settings.enabled then
      panel:Hide()
    else
      panel:Show()
      panel.title:SetPoint("LEFT", panel.header, "LEFT", spacing.horizontal, 0)
      panel.title:SetPoint("RIGHT", panel.header, "RIGHT", -(spacing.horizontal + 20), 0)
      panel.chevron:SetPoint("RIGHT", panel.header, "RIGHT", -spacing.horizontal, 0)
      panel.rule:SetPoint("BOTTOMLEFT", panel.header, "BOTTOMLEFT", spacing.horizontal, 0)
      panel.rule:SetPoint("BOTTOMRIGHT", panel.header, "BOTTOMRIGHT", -spacing.horizontal, 0)
      if placed and gap > 0 then
        y = y - gap
      end
      placed = true
      panel:ClearAllPoints()
      panel:SetWidth(PANEL_WIDTH - (inset * 2))
      panel:SetPoint("TOPLEFT", frame, "TOPLEFT", inset, y)
      if settings.collapsed then
        panel.chevron:SetAtlas("ui-questtrackerbutton-secondary-expand")
        panel.rows = {}
        LayoutPanel(panel, spacing)
        panel:SetHeight(PANEL_HEADER)
      else
        panel.chevron:SetAtlas("ui-questtrackerbutton-secondary-collapse")
        LayoutPanel(panel, spacing)
      end
      y = y - panel:GetHeight()
    end
  end
  frame:SetHeight(math.max(HEADER_HEIGHT + (inset * 2), -y + inset))
end

---@return LDT_Record, LDT_Record
local function DemoRecord()
  ---@type LDT_Record
  local best = {
    id = "demo-best",
    result = Constants.runResult.Complete,
    labyrinth = true,
    startedAt = 0,
    sessionStart = 0,
    sessionOffset = 0,
    finishedElapsed = 612,
    endedElapsed = 640,
    bossElapsed = 600,
    sawDelveComplete = true,
    deaths = 0,
    lives = 3,
    vault = { credits = 0, activities = {} },
    gold = { start = 0, last = 0, gained = 0, gains = {} },
    currencies = {},
    renownStart = {},
    renowns = {},
    boons = {},
    loot = {},
    chambers = {
      { name = "First chamber", enteredElapsed = 40, completedElapsed = 150 },
      { name = "Second chamber", enteredElapsed = 150, completedElapsed = 310 },
    },
    encounters = {
      { encounterID = 1, encounterName = "Chamber boss", difficultyID = 0, groupSize = 1, success = 1, elapsed = 600 },
    },
    log = {},
    watch = { criteria = {} },
  }
  ---@type LDT_Record
  local record = {
    id = "demo",
    result = Constants.runResult.Complete,
    labyrinth = true,
    startedAt = 0,
    sessionStart = 0,
    sessionOffset = 0,
    finishedElapsed = 754,
    endedElapsed = 754,
    bossName = "Chamber boss",
    bossElapsed = 720,
    sawDelveComplete = true,
    deaths = 1,
    lives = 2,
    player = { level = 80, itemLevel = 645, specName = "Restoration" },
    entrance = { tierInfo = { tier = 8, suggestedILvl = 0, overrideTooltipSpellID = 0, unlocked = true, tierDescription = "", rewards = {}, modifierUIWidgetSetID = 0, queueAsLFG = false, difficultyID = 0 } },
    companion = {
      name = "Brann Bronzebeard",
      level = 42,
      maxLevel = 80,
      flavorName = "Explorer",
      roleName = "Healer",
      combatCurioName = "Relic of Sentinels",
      utilityCurioName = "Idol of the Earthmother",
      standing = 2400,
      reactionThreshold = 2000,
      nextThreshold = 3000,
      startStanding = 2100,
    },
    instance = { name = "The Spiral Weave", difficultyName = "Delve" },
    place = { zone = "Azj-Kahet", subzone = "The Spiral Weave" },
    vault = { credits = 0, activities = {} },
    gold = {
      start = 0,
      last = 0,
      gained = 184250,
      gains = {
        { elapsed = 210, copper = 62500, afterComplete = false },
        { elapsed = 480, copper = 81750, afterComplete = false },
        { elapsed = 760, copper = 40000, afterComplete = true },
      },
    },
    currencies = {
      { currencyID = 3028, name = "Restored Coffer Key", change = 1, quantity = 4, elapsed = 300, afterComplete = false },
      { currencyID = 2815, name = "Resonance Crystals", change = 25, quantity = 400, elapsed = 770, afterComplete = true },
    },
    renownStart = {},
    renowns = {
      { factionID = 2590, name = "The Assembly of the Deeps", startLevel = 12, startEarned = 0, level = 12, earned = 1800, threshold = 2500, maxLevel = 25 },
    },
    boons = {
      { label = "Haste", amount = 8, percent = true },
      { label = "Speed", amount = 5, percent = true },
      { label = "Stamina", amount = 120, percent = false },
      { label = "Leech", amount = 3, percent = true },
      { label = "Versatility", amount = 10, percent = true },
    },
    loot = {
      { elapsed = 330, itemLink = "Adventurer's Helm", quantity = 1, afterComplete = false },
      { elapsed = 780, itemLink = "Delver's Bounty", quantity = 1, afterComplete = true },
    },
    chambers = {
      { name = "First chamber", enteredElapsed = 45, completedElapsed = 188 },
      { name = "Second chamber", enteredElapsed = 188, completedElapsed = 360 },
    },
    encounters = {
      { encounterID = 1, encounterName = "Chamber boss", difficultyID = 0, groupSize = 1, success = 1, elapsed = 720 },
    },
    log = {
      {
        at = 0,
        elapsed = 40,
        kind = Constants.logKind.Objective,
        text = "Objective: Clear the webs",
        detail = { criteriaID = 1, description = "Clear the webs" },
      },
      {
        at = 0,
        elapsed = 180,
        kind = Constants.logKind.ObjectiveDone,
        text = "Objective done: Clear the webs",
        detail = { criteriaID = 1, description = "Clear the webs" },
      },
      {
        at = 0,
        elapsed = 180,
        kind = Constants.logKind.Objective,
        text = "Objective: Defeat the chamber boss",
        detail = { criteriaID = 2, description = "Defeat the chamber boss" },
      },
      {
        at = 0,
        elapsed = 720,
        kind = Constants.logKind.ObjectiveDone,
        text = "Objective done: Defeat the chamber boss",
        detail = { criteriaID = 2, description = "Defeat the chamber boss" },
      },
    },
    watch = { criteria = {} },
  }
  return record, best
end

---@param record LDT_Record|nil
function Module:Fill(record)
  local panels = self.panels
  if not panels then
    return
  end
  if not record then
    self.title:SetText("Demo")
    local demo, best = DemoRecord()
    panels[Constants.sectionId.Run].rows = RunRows(demo, best)
    panels[Constants.sectionId.Timers].rows = TimerRows(demo, best)
    panels[Constants.sectionId.Companion].rows = CompanionRows(demo)
    panels[Constants.sectionId.Boons].rows = BoonRows(demo)
    panels[Constants.sectionId.Gains].rows = GainsRows(demo)
    panels[Constants.sectionId.Renown].rows = RenownRows(demo)
    return
  end
  local best = Helpers.BestRun(record)
  self.title:SetText(RunTitle(record))
  panels[Constants.sectionId.Run].rows = RunRows(record, best)
  panels[Constants.sectionId.Timers].rows = TimerRows(record, best)
  panels[Constants.sectionId.Companion].rows = CompanionRows(record)
  panels[Constants.sectionId.Boons].rows = BoonRows(record)
  panels[Constants.sectionId.Gains].rows = GainsRows(record)
  panels[Constants.sectionId.Renown].rows = RenownRows(record)
end

function Module:Render()
  self:Build()
  if not self.frame or not self.frame:IsShown() then
    return
  end
  self:ApplyChrome()
  self:Fill(Data:GetActiveRecord())
  self:Layout()
end

function Module:ShowRun()
  self:Build()
  if self.frame and not self.frame:IsShown() then
    self.frame:Show()
  end
  self:Render()
end

function Module:ToggleWindow()
  self:Build()
  if not self.frame then
    return
  end
  if self.frame:IsShown() then
    self.frame:Hide()
    return
  end
  self.frame:Show()
  self:Render()
end

function Module:OnEnable()
  if Data.db.global.widget.shown then
    self:ShowRun()
  end
  C_Timer.NewTicker(0.1, function()
    Module:Render()
  end)
end

---@class LDT_Addon
local addon = select(2, ...)

---@class LDT_Module_Run
local Module = addon.Core:NewModule("Run")
addon.Module_Run = Module

local Data = addon.Data
local Constants = addon.Constants
local Helpers = addon.Helpers
local FindTier = Helpers.FindTier
local RoundShownDelta = Helpers.RoundShownDelta
local FindDeltaColor = Helpers.FindDeltaColor
local FormatDelta = Helpers.FormatDelta
local FormatElapsed = Helpers.FormatElapsed
local FormatDate = Helpers.FormatDate
local FindResultColor = Helpers.FindResultColor
local FormatResult = Helpers.FormatResult
local FindBestDuration = Helpers.FindBestDuration
local FindDuration = Helpers.FindDuration
local ParseBoonAmount = Helpers.ParseBoonAmount
local FormatBoonAmount = Helpers.FormatBoonAmount
local FormatMoney = Helpers.FormatMoney
local IsCurrencyListed = Helpers.IsCurrencyListed
local IsItemHidden = Helpers.IsItemHidden
local RoundIcon = Helpers.RoundIcon
local LiqUI = addon.libs.LiqUI
local layoutSizes = LiqUI.Constants.layout.sizes
local BindScrollBoxMouseWheel = LiqUI.Utils.BindScrollBoxMouseWheel
local CreateScrollArea = LiqUI.Utils.CreateScrollArea
local SetBackgroundColor = LiqUI.Utils.SetBackgroundColor

local measureText = UIParent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
measureText:Hide()
measureText:SetWordWrap(false)

local paintRemaining = 0

---@param _frame Frame
---@param elapsed number
local function onPaintUpdate(_frame, elapsed)
  paintRemaining = paintRemaining - elapsed
  if paintRemaining > 0 then
    return
  end
  paintRemaining = Constants.timing.paint
  Module:Render()
end

---@param text string
---@param width number
---@return string, boolean
local function fitText(text, width)
  measureText:SetText(text)
  if measureText:GetStringWidth() <= width then
    return text, false
  end
  local trimmed = text
  while #trimmed > 0 do
    trimmed = trimmed:sub(1, #trimmed - 1)
    measureText:SetText(trimmed .. "...")
    if measureText:GetStringWidth() <= width then
      return trimmed .. "...", true
    end
  end
  return "...", true
end

---@param label string
---@param value string
---@return LiqUI_TableDataRowExtended
local function buildValueRow(label, value)
  ---@type LiqUI_TableDataRowExtended
  local row = {
    data = { label, value },
  }
  return row
end

---@param text string
---@param columns number
---@return LiqUI_TableDataRowExtended
local function buildNoteRow(text, columns)
  ---@type LiqUI_TableDataCellValue[]
  local cells = {}
  cells[1] = text
  for index = 2, columns do
    cells[index] = ""
  end
  ---@type LiqUI_TableDataRowExtended
  local row = {
    span = true,
    data = cells,
  }
  return row
end

---@param run LDT_Run
---@return string
local function formatWindowTitle(run)
  local instance = run.instance
  local rawName = instance and instance.name
  local name = "Delve"
  if type(rawName) == "string" and rawName ~= "" then
    name = rawName
  end
  local title = name
  local variant = run.variant
  if type(variant) == "string" and variant ~= "" and variant ~= name then
    title = format("%s - %s", name, variant) or name
  end
  local tier = FindTier(run)
  if tier then
    title = format("%s (Tier %d)", title, tier) or title
  end
  return title
end

---@param elapsed number|nil
---@param bestElapsed number|nil
---@param ahead ColorRGBAData
---@param behind ColorRGBAData
---@return string
local function formatDeltaText(elapsed, bestElapsed, ahead, behind)
  if not elapsed then
    return ""
  end
  local delta = 0
  if bestElapsed then
    delta = RoundShownDelta(elapsed, bestElapsed)
  end
  local color = FindDeltaColor(delta, ahead, behind)
  return CreateColor(color.r, color.g, color.b):WrapTextInColorCode(FormatDelta(delta))
end

---@param name string
---@return LiqUI_TableDataCellValue
local function buildStageCell(name)
  local shown, trimmed = fitText(name, Constants.sizes.run.stageTextWidth)
  if not trimmed then
    return shown
  end
  ---@param cellFrame LiqUI_TableCellFrame
  local function showStageName(cellFrame)
    GameTooltip:SetOwner(cellFrame, "ANCHOR_RIGHT")
    GameTooltip:SetText(name, 1, 1, 1)
    GameTooltip:Show()
  end
  ---@type LiqUI_TableDataCellExtended
  local cell = {
    data = shown,
    onEnter = showStageName,
    onLeave = GameTooltip_Hide,
  }
  return cell
end

---@param name string
---@param elapsed number|nil
---@param bestElapsed number|nil
---@param ahead ColorRGBAData
---@param behind ColorRGBAData
---@return LiqUI_TableDataRowExtended
local function buildStageRow(name, elapsed, bestElapsed, ahead, behind)
  local timeText = ""
  if elapsed then
    timeText = FormatElapsed(elapsed) or ""
  end
  local bestText = "-"
  if bestElapsed then
    bestText = FormatElapsed(bestElapsed) or ""
  end
  ---@type LiqUI_TableDataRowExtended
  local row = {
    data = {
      buildStageCell(name),
      formatDeltaText(elapsed, bestElapsed, ahead, behind),
      timeText,
      bestText,
    },
  }
  return row
end

---@param run LDT_Run
---@param ahead ColorRGBAData
---@param behind ColorRGBAData
---@return LiqUI_TableData
local function buildStageData(run, ahead, behind)
  ---@type LiqUI_TableData
  local data = {}
  local rows = Data:BuildSplits(run)
  for index = 1, #rows do
    local row = rows[index]
    data[#data + 1] = buildStageRow(row.name, row.elapsed, row.best, ahead, behind)
  end
  if #data == 0 then
    data[1] = buildNoteRow("No splits yet", 4)
  end
  return data
end

---@param spellIDs number[]
---@param cellFrame LiqUI_TableCellFrame
local function showAffixes(spellIDs, cellFrame)
  GameTooltip:SetOwner(cellFrame, "ANCHOR_RIGHT")
  local shown = false
  for index = 1, #spellIDs do
    local spellID = spellIDs[index]
    if spellID and not issecretvalue(spellID) then
      if not shown then
        GameTooltip:SetSpellByID(spellID)
        shown = true
      else
        local spellName = C_Spell.GetSpellName(spellID)
        if spellName and not issecretvalue(spellName) and spellName ~= "" then
          GameTooltip:AddLine(spellName, 1, 1, 1)
        end
      end
    end
  end
  if shown then
    GameTooltip:Show()
  end
end

---@param elapsed number
---@param bestElapsed number|nil
---@param ahead ColorRGBAData
---@param behind ColorRGBAData
---@return string
local function formatComparedTime(elapsed, bestElapsed, ahead, behind)
  local text = FormatElapsed(elapsed) or "-"
  if not bestElapsed then
    return text
  end
  local color = FindDeltaColor(RoundShownDelta(elapsed, bestElapsed), ahead, behind)
  return CreateColor(color.r, color.g, color.b):WrapTextInColorCode(text)
end

---@param atlas string
---@param value string
---@return string
local function formatWithAtlas(atlas, value)
  local icon = CreateAtlasMarkup(atlas, Constants.sizes.run.atlasSize, Constants.sizes.run.atlasSize) or ""
  return format("%s %s", icon, value)
end

---@param run LDT_Run
---@param ahead ColorRGBAData
---@param behind ColorRGBAData
---@return LiqUI_TableData, number[]
local function buildSummary(run, ahead, behind)
  ---@type LiqUI_TableData
  local data = {}
  local character = run.character
  local characterText = "-"
  if character and character.name and character.name ~= "" then
    characterText = character.name
    local classFile = character.classFile
    if classFile then
      local classColor = C_ClassColor.GetClassColor(classFile)
      if classColor and classColor.r and classColor.g and classColor.b then
        characterText = CreateColor(classColor.r, classColor.g, classColor.b):WrapTextInColorCode(character.name)
      end
    end
  end
  local specMarkup = ""
  if character and character.specID then
    local _, _, _, specTexture = GetSpecializationInfoByID(character.specID)
    if (type(specTexture) == "number" or type(specTexture) == "string") and not issecretvalue(specTexture) then
      specMarkup = format("|T%s:14|t", specTexture)
    end
  end
  if specMarkup ~= "" then
    characterText = format("%s %s", characterText, specMarkup)
  end
  local characterRow = buildValueRow("Character", characterText)
  if character then
    ---@param cellFrame LiqUI_TableCellFrame
    local function showCharacter(cellFrame)
      GameTooltip:SetOwner(cellFrame, "ANCHOR_RIGHT")
      local title = character.name or ""
      if title == "" then
        title = "Character"
      end
      local titleRed, titleGreen, titleBlue = 1, 1, 1
      if character.classFile then
        local classColor = C_ClassColor.GetClassColor(character.classFile)
        if classColor and classColor.r and classColor.g and classColor.b then
          titleRed, titleGreen, titleBlue = classColor.r, classColor.g, classColor.b
        end
      end
      GameTooltip:SetText(title, titleRed, titleGreen, titleBlue)
      ---@param label string
      ---@param value string
      local function addFact(label, value)
        GameTooltip:AddDoubleLine(label, value, NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b, 1, 1, 1)
      end
      if character.level then
        addFact("Level", format("%d", character.level))
      end
      if character.itemLevel then
        addFact("Item level", format("%d", character.itemLevel))
      end
      local realm = character.realm
      if not realm or realm == "" then
        realm = character.homeRealm
      end
      if realm and realm ~= "" then
        addFact("Realm", realm)
      end
      local specValue = character.specName
      if specMarkup ~= "" then
        if specValue and specValue ~= "" then
          specValue = format("%s %s", specMarkup, specValue)
        else
          specValue = specMarkup
        end
      end
      if specValue and specValue ~= "" then
        addFact("Spec", specValue)
      end
      if run.specChanged then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Specialization changed", NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b)
      end
      GameTooltip:Show()
    end
    characterRow.onEnter = showCharacter
    characterRow.onLeave = GameTooltip_Hide
  end
  data[#data + 1] = characterRow
  data[#data + 1] = buildValueRow("Started", FormatDate(run.startedAt, Constants.dateLength.Full))
  local endedText = "-"
  if run.endedAt then
    endedText = FormatDate(run.endedAt, Constants.dateLength.Full)
  end
  data[#data + 1] = buildValueRow("Ended", endedText)
  local red, green, blue = FindResultColor(run.result)
  data[#data + 1] = buildValueRow("Result", CreateColor(red, green, blue):WrapTextInColorCode(FormatResult(run.result)))
  local bestTime = FindBestDuration(run)
  local timeText = "-"
  if run.endedAt then
    local duration = FindDuration(run)
    if duration then
      timeText = formatComparedTime(duration, bestTime, ahead, behind)
    end
  end
  data[#data + 1] = buildValueRow("Time", timeText)
  local bestText = "-"
  if bestTime then
    bestText = FormatElapsed(bestTime) or "-"
  end
  data[#data + 1] = buildValueRow("Best", bestText)
  local deathsMarkup = formatWithAtlas("DungeonSkull", tostring(run.deaths or 0))
  local countLabel = "Deaths"
  local countValue = deathsMarkup
  if run.lives ~= nil then
    countLabel = "Deaths / Lives"
    countValue = format("%s / %s", deathsMarkup, formatWithAtlas("delves-scenario-heart-icon", tostring(run.lives)))
  end
  data[#data + 1] = buildValueRow(countLabel, countValue)
  ---@type number[]
  local affixSpells = {}
  local entrance = run.entrance
  local spellIDs = entrance and entrance.activeSpellIDs
  if spellIDs and #spellIDs > 0 then
    for index = 1, #spellIDs do
      local spellID = spellIDs[index]
      if spellID and not issecretvalue(spellID) then
        local texture = C_Spell.GetSpellTexture(spellID)
        if texture and not issecretvalue(texture) then
          affixSpells[#affixSpells + 1] = spellID
        end
      end
    end
    if #affixSpells > 0 then
      ---@param cellFrame LiqUI_TableCellFrame
      local function showAffixRow(cellFrame)
        showAffixes(affixSpells, cellFrame)
      end
      ---@type LiqUI_TableDataRowExtended
      local affixRow = buildValueRow("Affixes", "")
      affixRow.onEnter = showAffixRow
      affixRow.onLeave = GameTooltip_Hide
      data[#data + 1] = affixRow
    end
  end
  return data, affixSpells
end

local boonColorNeedles

---@param label string
---@return number|nil, number|nil, number|nil
local function findBoonColor(label)
  if not boonColorNeedles then
    boonColorNeedles = {}
    local colors = Constants.boonStatColors
    for index = 1, #colors do
      local entry = colors[index]
      ---@type string?
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
local function appendBoonStats(text, stats)
  for line in text:gmatch("[^\r\n]+") do
    local label, value = line:match("^%s*(.-)%s*:%s*(.-)%s*$")
    if label and label ~= "" and value and value ~= "" then
      local amount = ParseBoonAmount(value)
      if amount then
        value = FormatBoonAmount(amount)
      else
        value = value:gsub("%s+$", ""):gsub("%.$", "")
      end
      stats[#stats + 1] = { label = label, value = value }
    end
  end
end

---@param label string
---@return string
local function formatBoonLabel(label)
  local red, green, blue = findBoonColor(label)
  if red and green and blue then
    return CreateColor(red, green, blue):WrapTextInColorCode(label)
  end
  return label
end

---@param run LDT_Run
---@return LiqUI_TableData
local function buildBoons(run)
  ---@type LiqUI_TableData
  local data = {}
  local boons = run.boons or {}
  ---@type { label: string, value: string }[]
  local stats = {}
  for index = 1, #boons do
    local boon = boons[index]
    if boon.label and boon.amount then
      stats[#stats + 1] = { label = boon.label, value = FormatBoonAmount(boon.amount) }
    elseif boon.text and boon.text ~= "" then
      appendBoonStats(boon.text, stats)
    end
  end
  if #stats == 0 then
    data[1] = buildNoteRow("No boons", 4)
    return data
  end
  for index = 1, #stats, 2 do
    local left = stats[index]
    local right = stats[index + 1]
    ---@type LiqUI_TableDataRowExtended
    local row = {
      data = {
        formatBoonLabel(left.label),
        left.value,
        right and formatBoonLabel(right.label) or "",
        right and right.value or "",
      },
    }
    data[#data + 1] = row
  end
  return data
end

---@param amount number
---@return string
local function formatSignedCount(amount)
  if amount > 0 then
    return format("+%d", amount)
  end
  return tostring(amount)
end

---@param copper number
---@param cellFrame LiqUI_TableCellFrame
local function showGold(copper, cellFrame)
  GameTooltip:SetOwner(cellFrame, "ANCHOR_RIGHT")
  GameTooltip:SetText("Gold", 1, 0.82, 0)
  GameTooltip:AddLine(FormatMoney(copper), 1, 1, 1)
  GameTooltip:Show()
end

---@param currencyID number
---@param cellFrame LiqUI_TableCellFrame
local function showCurrency(currencyID, cellFrame)
  GameTooltip:SetOwner(cellFrame, "ANCHOR_RIGHT")
  GameTooltip:SetHyperlink(format("currency:%d", currencyID))
  GameTooltip:Show()
end

---@param itemLink string
---@param cellFrame LiqUI_TableCellFrame
local function showItem(itemLink, cellFrame)
  GameTooltip:SetOwner(cellFrame, "ANCHOR_RIGHT")
  GameTooltip:SetHyperlink(itemLink)
  GameTooltip:Show()
end

---@param factionID number
---@return string
local function formatFaction(factionID)
  local data = C_MajorFactions.GetMajorFactionData(factionID)
  if data and data.name and data.name ~= "" then
    return data.name
  end
  local faction = C_Reputation.GetFactionDataByID(factionID)
  if faction and faction.name and faction.name ~= "" then
    return faction.name
  end
  return tostring(factionID)
end

---@param data LiqUI_TableData
---@param name string
---@param amount number
local function appendAmount(data, name, amount)
  if amount == 0 then
    return
  end
  ---@type LiqUI_TableDataRowExtended
  local row = {
    data = {
      name,
      CreateColor(0.5, 0.85, 1):WrapTextInColorCode(formatSignedCount(amount)),
    },
  }
  data[#data + 1] = row
end

---@param rewards LDT_Reward[]
---@param rewardType LDT_RewardTypeId
---@return number
local function findAmount(rewards, rewardType)
  for index = 1, #rewards do
    local reward = rewards[index]
    if reward.type == rewardType then
      return reward.amount
    end
  end
  return 0
end

---@param run LDT_Run
---@return LiqUI_TableData
local function buildRewards(run)
  ---@type LiqUI_TableData
  local data = {}
  local rewards = run.rewards
  if not rewards then
    data[1] = buildNoteRow("No rewards yet", 2)
    return data
  end
  local companionName = "Companion"
  if run.companion and run.companion.name and run.companion.name ~= "" then
    companionName = run.companion.name
  end
  appendAmount(data, "Level", findAmount(rewards, Constants.rewardType.Level))
  appendAmount(data, "Experience", findAmount(rewards, Constants.rewardType.Experience))
  appendAmount(data, companionName .. " level", findAmount(rewards, Constants.rewardType.CompanionLevel))
  appendAmount(data, companionName .. " XP", findAmount(rewards, Constants.rewardType.CompanionExperience))
  local gold = findAmount(rewards, Constants.rewardType.Gold)
  if gold > 0 then
    local copper = gold
    ---@param cellFrame LiqUI_TableCellFrame
    local function showGoldRow(cellFrame)
      showGold(copper, cellFrame)
    end
    ---@type LiqUI_TableDataRowExtended
    local row = {
      data = {
        "Gold",
        FormatMoney(copper),
      },
      onEnter = showGoldRow,
      onLeave = GameTooltip_Hide,
    }
    data[#data + 1] = row
  end
  for index = 1, #rewards do
    local change = rewards[index]
    local currencyID = change.id
    local total = change.amount
    if change.type == Constants.rewardType.Currency and currencyID and total ~= 0 and IsCurrencyListed(currencyID) then
      local name = tostring(currencyID)
      local info = C_CurrencyInfo.GetCurrencyInfo(currencyID)
      if info and info.name and info.name ~= "" then
        name = info.name
      end
      if info and info.iconFileID and not issecretvalue(info.iconFileID) and info.iconFileID > 0 then
        name = format("|T%s:16|t %s", info.iconFileID, name)
      end
      ---@param cellFrame LiqUI_TableCellFrame
      local function showCurrencyRow(cellFrame)
        showCurrency(currencyID, cellFrame)
      end
      ---@type LiqUI_TableDataRowExtended
      local row = {
        data = {
          name,
          CreateColor(0.5, 0.85, 1):WrapTextInColorCode(formatSignedCount(total)),
        },
        onEnter = showCurrencyRow,
        onLeave = GameTooltip_Hide,
      }
      data[#data + 1] = row
    end
  end
  for index = 1, #rewards do
    local change = rewards[index]
    if change.type == Constants.rewardType.Renown and change.id and change.amount ~= 0 then
      appendAmount(data, formatFaction(change.id), change.amount)
    end
  end
  ---@type { itemID: number|nil, itemLink: string|nil, quantity: number, quality: number, qualityKnown: boolean, name: string }[]
  local items = {}
  for index = 1, #rewards do
    local item = rewards[index]
    if item.type == Constants.rewardType.Loot and not IsItemHidden(item.id) then
      items[#items + 1] = {
        itemID = item.id,
        itemLink = item.itemLink,
        quantity = item.amount,
        quality = 0,
        qualityKnown = false,
        name = "",
      }
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
    else
      label = format("[%s]", label)
    end
    if item.qualityKnown then
      local colorR, colorG, colorB = C_Item.GetItemQualityColor(item.quality)
      if colorR and not issecretvalue(colorR) and colorG and colorB then
        label = CreateColor(colorR, colorG, colorB):WrapTextInColorCode(label)
      end
    end
    if item.itemID then
      local texture = C_Item.GetItemIconByID(item.itemID)
      if texture and not issecretvalue(texture) then
        label = format("|T%s:16|t %s", texture, label)
      end
    end
    ---@type LiqUI_TableDataRowExtended
    local row = {
      data = { label, tostring(item.quantity) },
    }
    local itemLink = item.itemLink
    if itemLink and itemLink:find("|H", 1, true) then
      ---@param cellFrame LiqUI_TableCellFrame
      local function showItemRow(cellFrame)
        showItem(itemLink, cellFrame)
      end
      row.onEnter = showItemRow
      row.onLeave = GameTooltip_Hide
    end
    data[#data + 1] = row
  end
  if #data == 0 then
    data[1] = buildNoteRow("No rewards yet", 2)
  end
  return data
end

---@param companion LDT_Companion
---@return string|nil
local function findRoleAtlas(companion)
  local name = ""
  if companion.roleName then
    name = companion.roleName:lower()
  end
  local stored = ""
  if companion.roleAtlas then
    stored = companion.roleAtlas:lower()
  end
  local haystack = name .. " " .. stored
  if haystack:find("tank", 1, true) then
    return "ui-lfg-roleicon-tank"
  end
  if haystack:find("heal", 1, true) then
    return "ui-lfg-roleicon-healer"
  end
  if haystack:find("dps", 1, true) or haystack:find("damage", 1, true) then
    return "ui-lfg-roleicon-dps"
  end
  return companion.roleAtlas
end

---@param parent Frame
---@param anchor Frame|Texture
---@param relativePoint string
---@param x number
---@param round boolean|nil
---@return LDT_RunIconButton
local function createIconButton(parent, anchor, relativePoint, x, round)
  ---@type LDT_RunIconButton
  local button = CreateFrame("Button", nil, parent)
  button:SetSize(Constants.sizes.run.iconSize, Constants.sizes.run.iconSize)
  button:SetPoint("RIGHT", anchor, relativePoint, x, 0)
  local icon = button:CreateTexture(nil, "ARTWORK")
  icon:SetAllPoints()
  if round then
    RoundIcon(icon)
  end
  button.icon = icon
  button:SetScript("OnLeave", GameTooltip_Hide)
  return button
end

---@param parent Frame
---@return LDT_RunCompanion
local function createCompanion(parent)
  ---@type LDT_RunCompanion
  local frame = CreateFrame("Frame", nil, parent)
  local name = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  name:SetPoint("TOPLEFT", frame, "TOPLEFT", Constants.sizes.run.companionPad, -Constants.sizes.run.companionPad)
  name:SetJustifyH("LEFT")
  name:SetWordWrap(false)
  frame.name = name
  local level = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  level:SetPoint("TOP", frame, "TOP", 0, -Constants.sizes.run.companionPad)
  level:SetJustifyH("CENTER")
  frame.level = level
  local gain = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  gain:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -Constants.sizes.run.companionPad, -Constants.sizes.run.companionPad)
  gain:SetJustifyH("RIGHT")
  gain:SetTextColor(Constants.colors.gain.r, Constants.colors.gain.g, Constants.colors.gain.b)
  frame.gain = gain
  local empty = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  empty:SetPoint("TOPLEFT", frame, "TOPLEFT", Constants.sizes.run.companionPad, -Constants.sizes.run.companionPad)
  empty:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -Constants.sizes.run.companionPad, -Constants.sizes.run.companionPad)
  empty:SetJustifyH("LEFT")
  empty:SetText("No companion")
  frame.empty = empty
  local row = CreateFrame("Frame", nil, frame)
  row:SetPoint("TOPLEFT", name, "BOTTOMLEFT", 0, -Constants.sizes.run.companionGap)
  row:SetPoint("RIGHT", frame, "RIGHT", -Constants.sizes.run.companionPad, 0)
  row:SetHeight(Constants.sizes.run.barHeight)
  frame.row = row
  local icons = CreateFrame("Frame", nil, row)
  icons:SetPoint("TOPRIGHT", row, "TOPRIGHT", 0, 0)
  icons:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 0, 0)
  icons:SetWidth(1)
  frame.icons = icons
  local bar = CreateFrame("StatusBar", nil, row)
  bar:SetStatusBarTexture(Constants.media.WhiteSquare)
  bar:SetStatusBarColor(Constants.colors.bar.r, Constants.colors.bar.g, Constants.colors.bar.b, Constants.colors.bar.a)
  bar:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
  bar:SetPoint("BOTTOMRIGHT", icons, "BOTTOMLEFT", -Constants.sizes.run.companionGap, 0)
  local track = bar:CreateTexture(nil, "BACKGROUND")
  track:SetAllPoints()
  track:SetColorTexture(Constants.colors.stripe.r, Constants.colors.stripe.g, Constants.colors.stripe.b, Constants.colors.stripe.a)
  frame.bar = bar
  local barText = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  barText:SetPoint("LEFT", bar, "LEFT", Constants.sizes.run.barTextPad, 0)
  barText:SetPoint("RIGHT", bar, "RIGHT", -Constants.sizes.run.barTextPad, 0)
  barText:SetJustifyH("LEFT")
  barText:SetWordWrap(false)
  frame.barText = barText
  local role = createIconButton(icons, icons, "RIGHT", 0)
  ---@param button LDT_RunIconButton
  local function showRole(button)
    local tip = button.tip
    if not tip or tip == "" then
      return
    end
    GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
    GameTooltip:SetText(tip, Constants.colors.blockText.r, Constants.colors.blockText.g, Constants.colors.blockText.b)
    GameTooltip:Show()
  end
  role:SetScript("OnEnter", showRole)
  frame.role = role
  ---@type LDT_RunIconButton[]
  local spells = {}
  local previous = role
  for index = 1, 3 do
    local button = createIconButton(icons, previous, "LEFT", -Constants.sizes.run.iconGap, true)
    ---@param spellButton LDT_RunIconButton
    local function showSpell(spellButton)
      local spellID = spellButton.spellID
      if not spellID then
        return
      end
      GameTooltip:SetOwner(spellButton, "ANCHOR_RIGHT")
      GameTooltip:SetSpellByID(spellID)
      GameTooltip:Show()
    end
    button:SetScript("OnEnter", showSpell)
    spells[index] = button
    previous = button
  end
  frame.spells = spells
  return frame
end

---@param frame LDT_RunCompanion
---@param run LDT_Run|nil
local function paintCompanion(frame, run)
  local companion = run and run.companion
  if not companion or not companion.name or companion.name == "" then
    frame.name:Hide()
    frame.level:Hide()
    frame.gain:Hide()
    frame.row:Hide()
    frame.role:Hide()
    for index = 1, #frame.spells do
      frame.spells[index]:Hide()
    end
    if run then
      frame.empty:Show()
      frame:SetHeight((Constants.sizes.run.companionPad * 2) + Constants.sizes.run.companionLineHeight)
    else
      frame.empty:Hide()
      frame:SetHeight(0)
    end
    return
  end
  frame.empty:Hide()
  frame.name:Show()
  frame.name:SetText(companion.name)
  local level = ""
  if companion.level then
    level = format("Level %d", companion.level)
  end
  frame.level:SetText(level)
  frame.level:Show()
  local gain = ""
  if companion.startStanding and companion.standing then
    local gained = companion.standing - companion.startStanding
    if gained > 0 then
      gain = format("XP +%d", gained)
    elseif gained < 0 then
      gain = format("XP %d", gained)
    else
      gain = "XP +0"
    end
  end
  frame.gain:SetText(gain)
  frame.gain:Show()
  frame.row:Show()
  local minValue = companion.reactionThreshold
  local maxValue = companion.nextThreshold
  local standing = companion.standing
  frame.bar:Show()
  if minValue and maxValue and standing and maxValue > minValue then
    frame.bar:SetMinMaxValues(minValue, maxValue)
    local value = standing
    if value > maxValue then
      value = maxValue
    end
    frame.bar:SetValue(value)
    frame.barText:SetText(format("%d / %d", standing, maxValue))
  elseif standing then
    frame.bar:SetMinMaxValues(0, 1)
    frame.bar:SetValue(0)
    frame.barText:SetText(tostring(standing))
  else
    frame.bar:SetMinMaxValues(0, 1)
    frame.bar:SetValue(0)
    frame.barText:SetText("")
  end
  local atlas = findRoleAtlas(companion)
  if atlas and atlas ~= "" then
    frame.role:Show()
    frame.role.icon:SetAtlas(atlas)
    frame.role.tip = companion.roleName
  else
    frame.role:Hide()
  end
  local socketSpells = {
    companion.flavorSpellID,
    companion.combatCurioSpellID,
    companion.utilityCurioSpellID,
  }
  for index = 1, #frame.spells do
    local button = frame.spells[index]
    local spellID = socketSpells[index]
    local texture
    if spellID and not issecretvalue(spellID) then
      texture = C_Spell.GetSpellTexture(spellID)
    end
    if texture and not issecretvalue(texture) then
      button:Show()
      button.icon:SetTexture(texture)
      button.spellID = spellID
    else
      button:Hide()
      button.spellID = nil
    end
  end
  local iconCount = 0
  if frame.role:IsShown() then
    iconCount = iconCount + 1
  end
  for index = 1, #frame.spells do
    if frame.spells[index]:IsShown() then
      iconCount = iconCount + 1
    end
  end
  frame.bar:ClearAllPoints()
  frame.bar:SetPoint("TOPLEFT", frame.row, "TOPLEFT", 0, 0)
  if iconCount > 0 then
    frame.icons:Show()
    frame.icons:SetWidth(iconCount * Constants.sizes.run.iconSize + (iconCount - 1) * Constants.sizes.run.iconGap)
    frame.bar:SetPoint("BOTTOMRIGHT", frame.icons, "BOTTOMLEFT", -Constants.sizes.run.companionGap, 0)
  else
    frame.icons:Hide()
    frame.bar:SetPoint("BOTTOMRIGHT", frame.row, "BOTTOMRIGHT", 0, 0)
  end
  frame:SetHeight((Constants.sizes.run.companionPad * 2) + Constants.sizes.run.companionLineHeight + Constants.sizes.run.companionGap + Constants.sizes.run.barHeight)
end

---@param parent Frame
---@param text string
---@return LDT_RunBlockHeader
local function createBlockHeader(parent, text)
  ---@type LDT_RunBlockHeader
  local header = CreateFrame("Frame", nil, parent)
  header:SetHeight(Constants.sizes.run.blockHeaderHeight)
  local background = header:CreateTexture(nil, "BACKGROUND")
  background:SetAllPoints()
  background:SetColorTexture(Constants.colors.wash.r, Constants.colors.wash.g, Constants.colors.wash.b, Constants.colors.wash.a)
  local title = header:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  title:SetPoint("LEFT", header, "LEFT", Constants.sizes.run.padding, 0)
  title:SetPoint("RIGHT", header, "RIGHT", -Constants.sizes.run.padding, 0)
  title:SetJustifyH("LEFT")
  title:SetJustifyV("MIDDLE")
  title:SetWordWrap(false)
  title:SetText(text)
  header.title = title
  return header
end

---@param header LDT_RunBlockHeader
---@param y number
---@param shown boolean
---@return number
local function placeHeader(header, y, shown)
  if not shown then
    header:Hide()
    return y
  end
  header:Show()
  header:ClearAllPoints()
  header:SetPoint("TOPLEFT", header:GetParent(), "TOPLEFT", 0, y)
  header:SetWidth(Constants.sizes.run.bodyWidth)
  return y - Constants.sizes.run.blockHeaderHeight
end

---@param name string
---@param columns LiqUI_TableOptionsColumn[]
---@param showHeader boolean
---@param headerAlpha number|nil
---@param sticky boolean|nil
---@param highlight boolean|nil
---@return LiqUI_TableOptions
local function buildTableOptions(name, columns, showHeader, headerAlpha, sticky, highlight)
  ---@type LiqUI_TableOptions
  local options = {
    name = name,
    header = {
      enabled = showHeader,
      sticky = sticky == true,
      height = Constants.sizes.run.blockHeaderHeight,
      backgroundAlpha = headerAlpha or 0,
    },
    rowStyle = {
      highlight = highlight == true,
      striped = true,
    },
    cellStyle = {
      highlight = false,
    },
    columns = columns,
  }
  return options
end

---@param summary LiqUI_TableInstance
---@param spellIDs number[]
---@param buttons LDT_RunIconButton[]
---@return LDT_RunIconButton[]
local function paintSummaryAffixes(summary, spellIDs, buttons)
  for index = 1, #buttons do
    buttons[index]:Hide()
  end
  if #spellIDs == 0 then
    return buttons
  end
  local valueCell
  local rowFrames = summary.rowFrames
  for index = 1, #rowFrames do
    local rowFrame = rowFrames[index]
    local labelCell = rowFrame.cells[1]
    local label = labelCell and labelCell.label
    if rowFrame:IsShown() and label and label:GetText() == "Affixes" then
      valueCell = rowFrame.cells[2]
      break
    end
  end
  if not valueCell then
    return buttons
  end
  valueCell.label:SetText("")
  local anchor = valueCell
  ---@type FramePoint
  local relativePoint = "RIGHT"
  local offsetX = -layoutSizes.padding
  for index = #spellIDs, 1, -1 do
    local spellID = spellIDs[index]
    local texture = C_Spell.GetSpellTexture(spellID)
    if texture and not issecretvalue(texture) then
      local button = buttons[index]
      if not button then
        ---@type LDT_RunIconButton
        button = CreateFrame("Button", nil, valueCell)
        button:SetSize(Constants.sizes.run.iconSize, Constants.sizes.run.iconSize)
        local icon = button:CreateTexture(nil, "ARTWORK")
        icon:SetAllPoints()
        RoundIcon(icon)
        button.icon = icon
        button:SetScript("OnLeave", GameTooltip_Hide)
        ---@param affixButton LDT_RunIconButton
        local function showAffix(affixButton)
          local shownSpellID = affixButton.spellID
          if not shownSpellID or issecretvalue(shownSpellID) then
            return
          end
          GameTooltip:SetOwner(affixButton, "ANCHOR_RIGHT")
          GameTooltip:SetSpellByID(shownSpellID)
          GameTooltip:Show()
        end
        button:SetScript("OnEnter", showAffix)
        buttons[index] = button
      end
      button:SetParent(valueCell)
      button.spellID = spellID
      button.icon:SetTexture(texture)
      button:ClearAllPoints()
      button:SetPoint("RIGHT", anchor, relativePoint, offsetX, 0)
      button:Show()
      anchor = button
      relativePoint = "LEFT"
      offsetX = -Constants.sizes.run.iconGap
    end
  end
  return buttons
end

---@param frame LiqUI_TableInstance
---@param data LiqUI_TableData
---@param y number
---@return number
local function placeTable(frame, data, y)
  frame:SetData(data)
  local width, height = frame:GetSize()
  frame:ClearAllPoints()
  frame:SetPoint("TOPLEFT", frame:GetParent(), "TOPLEFT", 0, y)
  frame:SetSize(width, height)
  return y - height
end

---@param frame Frame
---@param scrollBox WowScrollBox
local function bindBodyWheel(frame, scrollBox)
  BindScrollBoxMouseWheel(frame, scrollBox)
  local children = { frame:GetChildren() }
  for index = 1, #children do
    bindBodyWheel(children[index], scrollBox)
  end
end

---@param line LDT_TimelineRow
---@return ColorRGBAData
local function findTimelineColor(line)
  if line.depth == 0 then
    return Constants.colors.blockText
  end
  if line.done ~= nil then
    if line.done then
      return Constants.colors.objectiveDone
    end
    return Constants.colors.objective
  end
  return Constants.colors.step
end

---@param text string
---@param color ColorRGBAData
---@return string
local function colorText(text, color)
  return CreateColor(color.r, color.g, color.b):WrapTextInColorCode(text)
end

---@param cellFrame LiqUI_TableCellFrame
---@param _rowFrame LiqUI_TableRowFrame
---@param _rowIndex integer
---@param columnIndex integer
---@param _columnId string|nil
---@param rowData LiqUI_TableDataRowExtended
local function showTimelineLine(cellFrame, _rowFrame, _rowIndex, columnIndex, _columnId, rowData)
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

---@param run LDT_Run|nil
---@return LiqUI_TableData
local function buildTimelineData(run)
  ---@type LiqUI_TableData
  local data = {}
  if not run then
    return data
  end
  local lines = Data:BuildTimeline(run)
  for lineIndex = 1, #lines do
    local line = lines[lineIndex]
    local labelColor = findTimelineColor(line)
    local timeColor = Constants.colors.nestedTime
    if line.depth == 0 then
      timeColor = Constants.colors.blockText
    end
    local timeText = ""
    if line.elapsed ~= nil then
      timeText = colorText(FormatElapsed(line.elapsed), timeColor)
    end
    ---@type LiqUI_TableDataRowExtended
    local row = {
      data = { colorText(line.name, labelColor), timeText },
      indent = line.depth * Constants.sizes.run.indent,
      onEnter = showTimelineLine,
      onLeave = GameTooltip_Hide,
    }
    data[#data + 1] = row
  end
  return data
end

---@param parent Frame
---@param name string
---@return LDT_RunColumn
local function createColumn(parent, name)
  ---@type LDT_RunColumn
  local column = CreateFrame("Frame", addon.name .. name, parent)
  local divider = CreateFrame("Frame", nil, column)
  divider:SetWidth(Constants.sizes.run.dividerWidth)
  SetBackgroundColor(divider, Constants.colors.divider)
  divider:Hide()
  column.divider = divider
  column:Hide()
  return column
end

---@param tableFrame LiqUI_TableInstance
---@param parent Frame
---@param data LiqUI_TableData
---@param viewHeight number
---@return number
local function layoutScrollingTable(tableFrame, parent, data, viewHeight)
  tableFrame:SetParent(parent)
  tableFrame:ClearAllPoints()
  tableFrame:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
  tableFrame:SetSize(Constants.sizes.run.bodyWidth, viewHeight)
  tableFrame:SetData(data)
  local _, contentHeight = tableFrame:GetSize()
  if contentHeight > viewHeight + layoutSizes.scrollbar.overflowTolerance then
    tableFrame:SetSize(Constants.sizes.run.bodyWidth + layoutSizes.scrollbar.thickness, viewHeight)
    return Constants.sizes.run.bodyWidth + layoutSizes.scrollbar.thickness
  end
  return Constants.sizes.run.bodyWidth
end

function Module:Layout()
  local window = self.window
  if not window or not self.summary or not self.stages or not self.companion or not self.boons or not self.rewards or not self.timeline then
    return
  end
  if not self.companionHeader or not self.boonsHeader then
    return
  end
  if not self.detailsColumn or not self.rewardsColumn or not self.timelineColumn or not self.detailsScroll then
    return
  end
  local shown = self.showingRun == true
  local y = 0
  y = placeTable(self.summary, self.summaryData or {}, y)
  self.affixButtons = paintSummaryAffixes(self.summary, self.affixSpells or {}, self.affixButtons or {})
  y = placeTable(self.stages, self.stagesData or {}, y)
  y = placeHeader(self.companionHeader, y, shown)
  self.companion:ClearAllPoints()
  self.companion:SetPoint("TOPLEFT", self.companion:GetParent(), "TOPLEFT", 0, y)
  self.companion:SetWidth(Constants.sizes.run.bodyWidth)
  y = y - self.companion:GetHeight()
  y = placeHeader(self.boonsHeader, y, shown)
  y = placeTable(self.boons, self.boonsData or {}, y)
  local detailsHeight = math.max(Constants.sizes.run.blockHeaderHeight, -y)
  local scale = window:GetWindowScale() / 100
  if scale <= 0 then
    scale = 1
  end
  local maxBody = (UIParent:GetHeight() - Constants.sizes.run.screenMargin) / scale - layoutSizes.titlebar.height
  if maxBody < Constants.sizes.run.blockHeaderHeight then
    maxBody = Constants.sizes.run.blockHeaderHeight
  end
  local bodyHeight = detailsHeight
  if bodyHeight > maxBody then
    bodyHeight = maxBody
  end
  local detailsWidth = Constants.sizes.run.bodyWidth
  if detailsHeight > bodyHeight + layoutSizes.scrollbar.overflowTolerance then
    detailsWidth = Constants.sizes.run.bodyWidth + layoutSizes.scrollbar.thickness
  end
  local rewardsWidth = layoutScrollingTable(self.rewards, self.rewardsColumn, self.rewardsData or {}, bodyHeight)
  local timelineWidth = layoutScrollingTable(self.timeline, self.timelineColumn, self.timelineData or {}, bodyHeight)
  ---@type LDT_RunColumn[]
  local openColumns = {}
  ---@type number[]
  local openWidths = {}
  ---@param column LDT_RunColumn
  ---@param width number
  ---@param open boolean
  local function queueColumn(column, width, open)
    if not open then
      column:Hide()
      return
    end
    openColumns[#openColumns + 1] = column
    openWidths[#openWidths + 1] = width
  end
  queueColumn(self.detailsColumn, detailsWidth, true)
  queueColumn(self.rewardsColumn, rewardsWidth, self.showRewards ~= false)
  queueColumn(self.timelineColumn, timelineWidth, self.showTimeline == true)
  local x = 0
  for index = 1, #openColumns do
    local column = openColumns[index]
    local width = openWidths[index]
    local hasNeighbor = index < #openColumns
    column:Show()
    column:ClearAllPoints()
    column:SetPoint("TOPLEFT", window.body, "TOPLEFT", x, 0)
    column:SetSize(width, bodyHeight)
    local divider = column.divider
    if hasNeighbor then
      divider:ClearAllPoints()
      divider:SetPoint("TOPLEFT", column, "TOPRIGHT", 0, 0)
      divider:SetPoint("BOTTOMLEFT", column, "BOTTOMRIGHT", 0, 0)
      divider:SetWidth(Constants.sizes.run.dividerWidth)
      divider:Show()
      x = x + width + Constants.sizes.run.dividerWidth
    else
      divider:Hide()
      x = x + width
    end
  end
  local detailsScroll = self.detailsScroll
  local container = detailsScroll.container
  container:ClearAllPoints()
  container:SetPoint("TOPLEFT", self.detailsColumn, "TOPLEFT", 0, 0)
  container:SetSize(detailsWidth, bodyHeight)
  detailsScroll:UpdateLayout(Constants.sizes.run.bodyWidth, detailsHeight)
  local scrollBox = detailsScroll:GetWheelScrollBox()
  if scrollBox then
    bindBodyWheel(detailsScroll.content, scrollBox)
  end
  window:SetBodySize(x, bodyHeight)
end

---@param run LDT_Run|nil
function Module:Fill(run)
  local window = self.window
  if not window or not self.companion then
    return
  end
  local options = Data.db.global.timer
  local ahead = options.aheadColor or Constants.colors.ahead
  local behind = options.behindColor or Constants.colors.behind
  self.showingRun = run ~= nil
  if not run then
    window:SetTitle("Run details")
    self.summaryData = {}
    self.affixSpells = {}
    self.stagesData = {}
    self.boonsData = {}
    self.rewardsData = {}
    self.timelineData = {}
    paintCompanion(self.companion, nil)
    return
  end
  Data:SetBest(run)
  window:SetTitle(formatWindowTitle(run))
  local summaryRows, affixSpells = buildSummary(run, ahead, behind)
  self.summaryData = summaryRows
  self.affixSpells = affixSpells
  self.stagesData = buildStageData(run, ahead, behind)
  self.boonsData = buildBoons(run)
  self.rewardsData = buildRewards(run)
  self.timelineData = buildTimelineData(run)
  paintCompanion(self.companion, run)
end

function Module:Render()
  if not self.window then
    local windows = Data.db.global.liqui.windows
    ---@type LiqUI_WindowOptions
    local windowOptions = {
      name = addon.name .. "Run",
      storage = windows.Run,
      title = "Run details",
      width = (Constants.sizes.run.bodyWidth * 2) + Constants.sizes.run.dividerWidth,
      height = Constants.sizes.run.windowHeight,
      onShow = function()
        Module:Render()
      end,
    }
    self.window = LiqUI:NewElement("Window", windowOptions)
    self.showRewards = true
    self.showTimeline = false
    ---@type LiqUI_WindowTitlebarButton
    local timelineButton = {
      name = "Timeline",
      icon = Constants.media.Timeline,
      iconSize = 16,
      tooltipTitle = "Timeline",
      tooltipDescription = "The path of this run.",
      onClick = function()
        Module.showTimeline = not Module.showTimeline
        Module:Layout()
      end,
    }
    ---@type LiqUI_WindowTitlebarButton
    local rewardsButton = {
      name = "Rewards",
      icon = Constants.media.Rewards,
      iconSize = 13,
      tooltipTitle = "Rewards",
      tooltipDescription = "Rewards from this run.",
      onClick = function()
        Module.showRewards = not Module.showRewards
        Module:Layout()
      end,
    }
    self.window:AddTitlebarButton(timelineButton)
    self.window:AddTitlebarButton(rewardsButton)
    self.window:HookScript("OnHide", function(hiddenFrame)
      hiddenFrame:SetScript("OnUpdate", nil)
    end)
    local body = self.window.body
    local detailsColumn = createColumn(body, "RunDetailsColumn")
    self.detailsColumn = detailsColumn
    local detailsScroll = CreateScrollArea(detailsColumn, {
      name = addon.name .. "RunDetailsColumnScroll",
      vertical = true,
      horizontal = false,
      wheelPanExtent = layoutSizes.row,
    })
    self.detailsScroll = detailsScroll
    local rewardsColumn = createColumn(body, "RunRewardsColumn")
    self.rewardsColumn = rewardsColumn
    local timelineColumn = createColumn(body, "RunTimelineColumn")
    self.timelineColumn = timelineColumn
    local content = detailsScroll.content
    local summaryColumns = {
      { id = "label", headerText = "Summary", width = Constants.sizes.run.labelWidth, align = "LEFT" },
      { id = "value", headerText = "", width = Constants.sizes.run.valueWidth, align = "RIGHT" },
    }
    local stageColumns = {
      { id = "stage", headerText = "Splits", width = Constants.sizes.run.stageWidth, align = "LEFT" },
      { id = "delta", headerText = "Delta", width = Constants.sizes.run.numberWidth, align = "RIGHT" },
      { id = "time", headerText = "Time", width = Constants.sizes.run.numberWidth, align = "RIGHT" },
      { id = "best", headerText = "Best", width = Constants.sizes.run.numberWidth, align = "RIGHT" },
    }
    local boonColumns = {
      { id = "stat", headerText = "", width = Constants.sizes.run.boonLabelWidth, align = "LEFT" },
      { id = "value", headerText = "", width = Constants.sizes.run.boonValueWidth, align = "RIGHT" },
      { id = "statRight", headerText = "", width = Constants.sizes.run.boonLabelWidth, align = "LEFT" },
      { id = "valueRight", headerText = "", width = Constants.sizes.run.boonValueWidth, align = "RIGHT" },
    }
    local rewardColumns = {
      { id = "name", headerText = "Rewards", width = Constants.sizes.run.rewardNameWidth, align = "LEFT" },
      { id = "amount", headerText = "", width = Constants.sizes.run.rewardAmountWidth, align = "RIGHT" },
    }
    local summary = LiqUI:NewElement("Table", buildTableOptions(addon.name .. "RunSummary", summaryColumns, true, 0.35, false))
    summary:SetParent(content)
    self.summary = summary
    local stages = LiqUI:NewElement("Table", buildTableOptions(addon.name .. "RunStages", stageColumns, true, 0.35))
    stages:SetParent(content)
    self.stages = stages
    self.companionHeader = createBlockHeader(content, "Companion")
    self.companion = createCompanion(content)
    self.boonsHeader = createBlockHeader(content, "Boons")
    local boons = LiqUI:NewElement("Table", buildTableOptions(addon.name .. "RunBoons", boonColumns, false))
    boons:SetParent(content)
    self.boons = boons
    local rewards = LiqUI:NewElement("Table", buildTableOptions(addon.name .. "RunRewards", rewardColumns, true, 0.35, true, true))
    rewards:SetParent(rewardsColumn)
    self.rewards = rewards
    local timelineColumns = {
      { id = "name", headerText = "Timeline", width = Constants.sizes.run.timelineNameWidth, align = "LEFT" },
      { id = "time", headerText = "Time", width = Constants.sizes.run.timelineTimeWidth, align = "RIGHT" },
    }
    local timeline = LiqUI:NewElement("Table", buildTableOptions(addon.name .. "RunTimeline", timelineColumns, true, 0.35, true, true))
    timeline:SetParent(timelineColumn)
    self.timeline = timeline
  end
  if not self.window or not self.window:IsShown() then
    return
  end
  local run = self.pinnedRun or Data:FindActiveRun()
  self:Fill(run)
  self:Layout()
  local active = Data:FindActiveRun()
  if run and active and run == active then
    if self.window:GetScript("OnUpdate") ~= onPaintUpdate then
      paintRemaining = 0
      self.window:SetScript("OnUpdate", onPaintUpdate)
    end
    return
  end
  self.window:SetScript("OnUpdate", nil)
end

---@param run LDT_Run|nil
function Module:ShowRun(run)
  if not self.window then
    self:Render()
  end
  if not self.window then
    return
  end
  if self.window:IsShown() and self.pinnedRun == run then
    self.window:Hide()
    return
  end
  self.pinnedRun = run
  if self.window:IsShown() then
    self:Render()
    self.window:Raise()
  else
    self.window:Show()
    self.window:Raise()
  end
end

function Module:ToggleWindow()
  if not self.window then
    self:Render()
  end
  if not self.window then
    return
  end
  if self.window:IsShown() then
    self.window:Hide()
    return
  end
  self:ShowRun(Data:FindActiveRun())
end

function Module:OnEnable()
end

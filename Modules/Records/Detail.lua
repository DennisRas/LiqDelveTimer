---@class LDT_Addon
local addon = select(2, ...)

---@class LDT_Module_Records
local Module = addon.Module_Records
if not Module then
  return
end

local Data = addon.Data
local Constants = addon.Constants
local Helpers = addon.Helpers
local LiqUI = addon.libs.LiqUI

---@param record LDT_Record
---@return string
local function DetailText(record)
  local lines = {}
  local instance = record.instance
  local name = instance and instance.name
  if not name or name == "" then
    name = "Delve"
  end
  lines[#lines + 1] = name
  lines[#lines + 1] = format("Result %s", record.result)
  if record.endedElapsed then
    lines[#lines + 1] = format("Time %s", Helpers.FormatElapsed(record.endedElapsed))
  end
  if record.bossName and record.bossElapsed then
    lines[#lines + 1] = format("Boss %s %s", record.bossName, Helpers.FormatElapsed(record.bossElapsed))
  end
  if record.finishedElapsed then
    lines[#lines + 1] = format("Complete %s", Helpers.FormatElapsed(record.finishedElapsed))
  end
  local best = Helpers.BestRun(record)
  local bestTime = best and Helpers.CompletionTime(best)
  local currentTime = Helpers.CompletionTime(record) or record.endedElapsed
  if bestTime and currentTime then
    lines[#lines + 1] = format("Vs tier %d best %s", Helpers.RunTier(record), Helpers.FormatDelta(currentTime - bestTime))
  end
  local player = record.player
  if player then
    local character = player.name or ""
    if player.specName and player.specName ~= "" then
      character = format("%s, %s", character, player.specName)
    end
    if player.level then
      character = format("%s, level %d", character, player.level)
    end
    if player.itemLevel then
      character = format("%s, ilvl %d", character, math.floor(player.itemLevel))
    end
    lines[#lines + 1] = character
  end
  lines[#lines + 1] = format("Deaths %d", record.deaths or 0)
  local companion = record.companion
  if companion and companion.name and companion.name ~= "" then
    local companionLine = companion.name
    if companion.roleName and companion.roleName ~= "" then
      companionLine = format("%s, %s", companionLine, companion.roleName)
    end
    lines[#lines + 1] = format("Companion %s", companionLine)
  end
  if record.boons and #record.boons > 0 then
    local parts = {}
    for index = 1, #record.boons do
      parts[index] = record.boons[index].text
    end
    lines[#lines + 1] = format("Boons %s", table.concat(parts, " | "))
  end
  if record.gold and record.gold.gained and record.gold.gained > 0 then
    lines[#lines + 1] = format("Gold %s", Helpers.FormatMoney(record.gold.gained))
  end
  if record.currencies then
    for index = 1, #record.currencies do
      local row = record.currencies[index]
      if Helpers.CurrencyListed(row.currencyID) then
        local amount = tostring(row.change)
        if row.change > 0 then
          amount = format("+%d", row.change)
        end
        lines[#lines + 1] = format("Currency %s %s", amount, row.name or row.currencyID)
      end
    end
  end
  if record.renowns then
    for index = 1, #record.renowns do
      local row = record.renowns[index]
      lines[#lines + 1] = format("Renown %s %d", row.name or "Faction", row.level)
    end
  end
  if record.loot then
    for index = 1, #record.loot do
      local row = record.loot[index]
      if not Helpers.ItemHidden(row.itemID) then
        local link = row.itemLink or "Item"
        lines[#lines + 1] = format("Loot %s", link)
      end
    end
  end
  if record.encounters and #record.encounters > 0 then
    lines[#lines + 1] = "Encounters"
    for index = 1, #record.encounters do
      local encounter = record.encounters[index]
      local result = "failed"
      if encounter.success == 1 then
        result = "killed"
      end
      lines[#lines + 1] = format("%s %s %s", encounter.encounterName, result, Helpers.FormatElapsed(encounter.elapsed))
    end
  end
  return table.concat(lines, "\n")
end

---@param record LDT_Record
function Module:ShowDetail(record)
  if not self.detail then
    self.detail = LiqUI:NewElement("Window", {
      name = addon.name .. "RecordDetail",
      storage = Data.db.global.liqui.windows.RecordDetail,
      title = "Record",
      icon = Constants.media.Icon,
      width = 420,
      height = 480,
    })
    local scrollArea = LiqUI.Utils.CreateScrollArea(self.detail.body, { vertical = true })
    scrollArea:SetPoint("TOPLEFT", self.detail.body, "TOPLEFT", 8, -8)
    scrollArea:SetPoint("BOTTOMRIGHT", self.detail.body, "BOTTOMRIGHT", -8, 8)
    local text = scrollArea.content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    text:SetPoint("TOPLEFT", scrollArea.content, "TOPLEFT", 4, -4)
    text:SetJustifyH("LEFT")
    text:SetJustifyV("TOP")
    text:SetSpacing(2)
    text:SetWordWrap(true)
    self.detailScroll = scrollArea
    self.detailText = text
    scrollArea.container:SetScript("OnSizeChanged", function()
      Module:LayoutDetail()
    end)
    self.detail:Hide()
  end
  local title = record.instance and record.instance.name
  if not title or title == "" then
    title = "Record"
  end
  self.detail:SetTitle(title)
  self.detailText:SetText(DetailText(record))
  self.detail:Show()
  self:LayoutDetail()
end

function Module:LayoutDetail()
  local scrollArea = self.detailScroll
  local text = self.detailText
  if not scrollArea or not text then
    return
  end
  local width = scrollArea.container:GetWidth()
  if width < 20 then
    return
  end
  text:SetWidth(width - 20)
  scrollArea:UpdateLayout(width, text:GetStringHeight() + 8)
end

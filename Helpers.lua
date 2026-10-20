---@class LDT_Addon
local addon = select(2, ...)

---@class LDT_Helpers
local Helpers = {}
addon.Helpers = Helpers

---@param elapsed number|nil
---@return string
function Helpers.FormatElapsed(elapsed)
  if not elapsed or elapsed < 0 then
    elapsed = 0
  end
  local tenths = math.floor((elapsed * 10) % 10)
  local whole = math.floor(elapsed)
  local seconds = whole % 60
  local minutes = math.floor(whole / 60)
  local hours = math.floor(minutes / 60)
  minutes = minutes % 60
  if hours > 0 then
    return format("%d:%02d:%02d.%d", hours, minutes, seconds, tenths)
  end
  return format("%d:%02d.%d", minutes, seconds, tenths)
end

---@param copper number|nil
---@return string
function Helpers.FormatMoney(copper)
  if not copper or copper < 0 then
    copper = 0
  end
  local gold = math.floor(copper / 10000)
  local silver = math.floor((copper % 10000) / 100)
  if gold > 0 then
    return format("%dg %ds", gold, silver)
  end
  if silver > 0 then
    return format("%ds", silver)
  end
  return format("%dc", copper)
end

---@param delta number|nil
---@return string
function Helpers.FormatDelta(delta)
  if not delta then
    return ""
  end
  local sign = "+"
  if delta < -0.05 then
    sign = "-"
    delta = -delta
  elseif delta <= 0.05 then
    return Helpers.FormatElapsed(0)
  end
  return sign .. Helpers.FormatElapsed(delta)
end

---@param record LDT_Record
---@return number|nil
function Helpers.RunTier(record)
  local tier = record.entrance and record.entrance.tierInfo and record.entrance.tierInfo.tier
  if tier and tier > 0 then
    return tier
  end
  return nil
end

---@param record LDT_Record
---@return number|nil
function Helpers.CompletionTime(record)
  if record.finishedElapsed then
    return record.finishedElapsed
  end
  if record.bossElapsed then
    return record.bossElapsed
  end
  if record.result ~= addon.Constants.runResult.Active and record.endedElapsed then
    return record.endedElapsed
  end
  return nil
end

---@param record LDT_Record
---@return LDT_Record|nil
function Helpers.BestRun(record)
  local character = addon.Data:GetCharacter()
  local instance = record.instance
  if not character or not instance then
    return nil
  end
  local tier = Helpers.RunTier(record)
  if not tier then
    return nil
  end
  local mapID = instance.mapID
  local name = instance.name
  local best
  local bestTime
  addon.libs.LiqUI.Utils.TableForEach(character.records, function(candidate)
    if candidate == record or candidate.result ~= addon.Constants.runResult.Complete then
      return
    end
    if Helpers.RunTier(candidate) ~= tier then
      return
    end
    local candidateInstance = candidate.instance
    local samePlace = false
    if mapID and candidateInstance and candidateInstance.mapID == mapID then
      samePlace = true
    elseif name and name ~= "" and candidateInstance and candidateInstance.name == name then
      samePlace = true
    end
    if not samePlace then
      return
    end
    local time = Helpers.CompletionTime(candidate)
    if not time then
      return
    end
    if not bestTime or time < bestTime then
      best = candidate
      bestTime = time
    end
  end)
  return best
end

local listedCurrencyIDs
local listedCurrencyCount = 0
local listedCurrencyAt

---@param currencyID number|nil
---@return boolean
function Helpers.CurrencyListed(currencyID)
  if not currencyID or currencyID <= 0 then
    return false
  end
  local now = GetTime()
  if not listedCurrencyIDs or not listedCurrencyAt or now - listedCurrencyAt > 1 then
    listedCurrencyIDs = {}
    listedCurrencyCount = 0
    local size = C_CurrencyInfo.GetCurrencyListSize() or 0
    for index = 1, size do
      local row = C_CurrencyInfo.GetCurrencyListInfo(index)
      if row and not row.isHeader and row.currencyID and row.currencyID > 0 then
        listedCurrencyIDs[row.currencyID] = true
        listedCurrencyCount = listedCurrencyCount + 1
      end
    end
    listedCurrencyAt = now
  end
  if listedCurrencyCount == 0 then
    local info = C_CurrencyInfo.GetCurrencyInfo(currencyID)
    return info ~= nil and not info.isHeader and info.name ~= nil and info.name ~= ""
  end
  return listedCurrencyIDs[currencyID] == true
end

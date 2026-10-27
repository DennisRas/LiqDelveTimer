---@class LDT_Addon
local addon = select(2, ...)

---@class LDT_Helpers
local Helpers = {}
addon.Helpers = Helpers

---@param value string
---@return number|nil, boolean
function Helpers.BoonAmount(value)
  local cleaned = value:gsub("%s+$", ""):gsub("%.$", "")
  local percent = cleaned:find("%%", 1, true) ~= nil
  local numberText = cleaned:match("([%+%-]?%d+%.?%d*)")
  if not numberText then
    return nil, percent
  end
  return tonumber(numberText), percent
end

---@param amount number
---@return string
function Helpers.FormatBoonAmount(amount)
  local text
  if amount % 1 == 0 then
    text = format("%d", amount)
  else
    text = format("%.1f", amount)
  end
  return text .. "%"
end

---@param milliseconds number|nil
---@return number
function Helpers.Shown(milliseconds)
  local ms = milliseconds or 0
  local sign = 1
  if ms < 0 then
    sign = -1
    ms = -ms
  end
  return sign * math.floor(ms / 10 + 0.5) * 10
end

---@param left number
---@param right number
---@return number
function Helpers.ShownDelta(left, right)
  return Helpers.Shown(left) - Helpers.Shown(right)
end

---@param milliseconds number|nil
---@return string
function Helpers.FormatElapsed(milliseconds)
  local shown = Helpers.Shown(milliseconds)
  if shown < 0 then
    shown = -shown
  end
  local hundredths = math.floor(shown / 10) % 100
  local whole = math.floor(shown / 1000)
  local seconds = whole % 60
  local minutes = math.floor(whole / 60)
  local hours = math.floor(minutes / 60)
  minutes = minutes % 60
  if hours > 0 then
    return format("%d:%02d:%02d.%02d", hours, minutes, seconds, hundredths)
  end
  return format("%d:%02d.%02d", minutes, seconds, hundredths)
end

---@param copper number|nil
---@return string
function Helpers.FormatMoney(copper)
  local copperAmount = 0
  if copper then
    if copper >= 0 then
      copperAmount = copper
    end
  end
  return C_CurrencyInfo.GetCoinTextureString(copperAmount, 12)
end

---@param itemID number|nil
---@return boolean
function Helpers.ItemHidden(itemID)
  return itemID ~= nil and addon.Data.hiddenItemIDs[itemID] == true
end

---@param delta number|nil
---@return string
function Helpers.FormatDelta(delta)
  if not delta then
    return ""
  end
  local shown = Helpers.Shown(delta)
  local sign = "+"
  if shown < 0 then
    sign = "-"
    shown = -shown
  end
  local text = format("%s%s", sign, Helpers.FormatElapsed(shown))
  if text then
    return text
  end
  return ""
end

---@param result string|nil
---@return boolean
function Helpers.IsCleared(result)
  return result == addon.Constants.runResult.Completed or result == addon.Constants.runResult.PersonalBest or result == "complete"
end

---@param result string|nil
---@return boolean
function Helpers.IsAbandoned(result)
  return result == addon.Constants.runResult.Abandoned or result == "left"
end

---@param result string|nil
---@return string
function Helpers.ResultLabel(result)
  if result == addon.Constants.runResult.PersonalBest then
    return "Personal Best"
  end
  if Helpers.IsCleared(result) then
    return "Completed"
  end
  if Helpers.IsAbandoned(result) then
    return "Abandoned"
  end
  if result == addon.Constants.runResult.Active then
    return "In progress"
  end
  return ""
end

---@param result string|nil
---@return number, number, number
function Helpers.ResultColor(result)
  if result == addon.Constants.runResult.PersonalBest then
    local timer = addon.Data.db and addon.Data.db.global.timer
    local color = timer and timer.aheadColor
    if color then
      return color.r, color.g, color.b
    end
    return 0.35, 0.9, 0.5
  end
  if Helpers.IsAbandoned(result) then
    return 1, 0.35, 0.35
  end
  return 0.95, 0.95, 0.95
end

---@param run LDT_Run
---@return number|nil
function Helpers.RunTier(run)
  local tier = run.entrance and run.entrance.tierInfo and run.entrance.tierInfo.tier
  if tier and tier > 0 then
    return tier
  end
  return nil
end

---@param run LDT_Run
---@return number|nil
function Helpers.Duration(run)
  if not run.endedAt then
    return nil
  end
  return run.endedAt - run.startedAt
end

---@param milliseconds number
---@param length LDT_DateLengthId
---@return string
function Helpers.FormatDate(milliseconds, length)
  local pattern = "%Y-%m-%d %H:%M"
  if length == addon.Constants.dateLength.Full then
    pattern = "%Y-%m-%d %H:%M:%S"
  end
  local text = date(pattern, math.floor(milliseconds / 1000))
  if type(text) ~= "string" then
    return ""
  end
  return text
end

---@param run LDT_Run
---@return LDT_RunModeId|nil
function Helpers.RunMode(run)
  return run.mode
end

---@param run LDT_Run
---@return LDT_Run|nil
function Helpers.BestRun(run)
  local tier = Helpers.RunTier(run)
  if not tier then
    return nil
  end
  local mode = Helpers.RunMode(run)
  local scenarioID
  if mode ~= addon.Constants.runMode.Lab then
    local first = run.scenarios[1]
    scenarioID = first and first.scenarioID
    if not scenarioID then
      return nil
    end
  end
  local best
  local bestTime
  addon.Data:ForEachRun(function(saved)
    if saved == run or not Helpers.IsCleared(saved.result) or not saved.endedAt or saved.endedAt > run.startedAt then
      return
    end
    if Helpers.RunTier(saved) ~= tier or Helpers.RunMode(saved) ~= mode then
      return
    end
    if scenarioID then
      local savedFirst = saved.scenarios[1]
      if not savedFirst or savedFirst.scenarioID ~= scenarioID then
        return
      end
    end
    local time = Helpers.Duration(saved)
    if not time then
      return
    end
    if not bestTime or time < bestTime then
      best = saved
      bestTime = time
    end
  end)
  return best
end

---@param run LDT_Run
---@return number|nil
function Helpers.BestDuration(run)
  local best = run.best
  if not best or not best.endedAt or not best.startedAt then
    return nil
  end
  return best.endedAt - best.startedAt
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

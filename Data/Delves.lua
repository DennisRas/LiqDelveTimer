---@class LDT_Addon
local addon = select(2, ...)

---@class LDT_Data
local Data = addon.Data

---@type LDT_Delve[]
Data.delves = {
  {delveID = 2933, name = "Collegiate Calamity", mode = "delve"},
  {delveID = 2952, name = "The Shadow Enclave", mode = "delve"},
  {delveID = 2953, name = "Parhelion Plaza", mode = "delve"},
  {delveID = 2961, name = "Twilight Crypts", mode = "delve"},
  {delveID = 2962, name = "Atal'Aman", mode = "delve"},
  {delveID = 2963, name = "The Grudge Pit", mode = "delve"},
  {delveID = 2964, name = "The Gulf of Memory", mode = "delve"},
  {delveID = 2965, name = "Sunkiller Sanctum", mode = "delve"},
  {delveID = 2966, name = "Torment's Rise", mode = "delve"},
  {delveID = 2979, name = "Shadowguard Point", mode = "delve"},
  {delveID = 3003, name = "The Darkway", mode = "delve"},
  {delveID = 3038, name = "Gnarldor Isle", mode = "delve"},
  {delveID = 3043, name = "The Labyrinth of Kindo'jan", mode = "lab", kinduruCriteriaID = 117017, pathCriteriaID = 112888},
  {delveID = 3077, name = "The Ring of Glory", mode = "delve"},
  {delveID = 3079, name = "Venomfall Deeps", mode = "delve"},
}

---@type LDT_UiMap[]
Data.uiMaps = {
  {uiMapID = 2502, delveID = 2952},
  {uiMapID = 2503, delveID = 2961},
  {uiMapID = 2504, delveID = 2961},
  {uiMapID = 2505, delveID = 2964},
  {uiMapID = 2506, delveID = 2979},
  {uiMapID = 2507, delveID = 2966},
  {uiMapID = 2510, delveID = 2963},
  {uiMapID = 2525, delveID = 3003},
  {uiMapID = 2528, delveID = 2965},
  {uiMapID = 2535, delveID = 2962},
  {uiMapID = 2536, delveID = 2962},
  {uiMapID = 2545, delveID = 2953},
  {uiMapID = 2547, delveID = 2933},
  {uiMapID = 2571, delveID = 2965},
  {uiMapID = 2575, delveID = 2964},
  {uiMapID = 2577, delveID = 2933},
  {uiMapID = 2578, delveID = 2933},
  {uiMapID = 2633, delveID = 3077},
  {uiMapID = 2634, delveID = 3079},
  {uiMapID = 2635, delveID = 3038},
  {uiMapID = 2647, delveID = 3043},
  {uiMapID = 2648, delveID = 3043},
}

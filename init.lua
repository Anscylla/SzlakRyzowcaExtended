---@diagnostic disable-next-line: undefined-global
local yaml = yaml or {dump = function(...) error("missing function") end}

local memory = require("customskirmishtrails.memory")
local interface = require("customskirmishtrails.interface")
local cst_io = require("customskirmishtrails.io")
local description = require("customskirmishtrails.description")
local tradeability = require("customskirmishtrails.tradeability")
local producibility = require("customskirmishtrails.producibility")
local recruitability = require("customskirmishtrails.recruitability")
local startgold = require("customskirmishtrails.startgold")
local start_goods = require("customskirmishtrails.start_goods")

local TRAIL_TYPES = memory.TRAIL_TYPES
local TRAIL_PROGRESS_ADDRESSES = memory.TRAIL_PROGRESS_ADDRESSES
local REGISTRY = memory.REGISTRY
local fetchCurrentTrail = memory.fetchCurrentTrail

local function insertPostSkirmishSetupDetour()
  log(2, "insertPostSkirmishSetupDetour: setting up detour")
  -- local detourLocation, detourSize = core.AOBScan("A1 ? ? ? ? 8D 0C 80 03 C9 89 ? ? ? ? ?"), 5
  local detourLocation, detourSize = core.AOBScan("8B 8C 24 ? ? 00 00 5f 5e 89 ? ? ? ? ? 89 ? ? ? ? ? 89 ? ? ? ? ? 89 ? ? ? ? ? 5B 33 CC"), 7
  core.detourCode(function(registers)
    if core.readInteger(memory.IS_SKIRMISH_TRAIL) ~= 1 then
      log(2, "not in skirmish trail")
      return registers
    end

    local trail =  core.readInteger(memory.CURRENT_TRAIL_TYPE) 
    local trailName = TRAIL_TYPES[trail]

    if trailName == nil then error(string.format("invalid trail: %s", trail)) end

    log(2, string.format("trail: %s", trailName))

    local progressAddr = TRAIL_PROGRESS_ADDRESSES[trailName]

    local mission = core.readInteger(progressAddr) + 1

    local missions = REGISTRY[trailName]
    if missions == nil then
      log(2, string.format("No custom missions registered for trail name: %s", trailName))
      return registers
    end

    log(2, string.format("Committing extra parameters for %s mission: %s", trailName, mission))
    
    local entry = missions[mission]
    if entry == nil then log(-1, string.format("skirmish trail (%s) entry is unexpectedly nil: %s", trailName, mission)) end
    interface.commitEntryExtra(entry)

    return registers

  end, detourLocation, detourSize)

  core.detourCode(function(registers)
    if core.readInteger(memory.IS_SKIRMISH_TRAIL) ~= 1 then return registers end

    local trail, trailName, mission = memory.fetchCurrentTrail()
    local missions = REGISTRY[trailName]
    if missions == nil then
      log(2, string.format("No custom missions registered for trail name: %s", trailName))
      return registers
    end

    log(2, string.format("Committing start goods parameters for %s mission: %s", trailName, mission))
    
    local entry = missions[mission]
    if entry == nil then log(-1, string.format("skirmish trail (%s) entry is unexpectedly nil: %s", trailName, mission)) end
    interface.setStartGoods(entry)
  end, core.AOBScan("A3 ? ? ? ? A3 ? ? ? ? A3 ? ? ? ? A3 ? ? ? ? A3 ? ? ? ? A3 ? ? ? ? A3 ? ? ? ? A3 ? ? ? ? A3 ? ? ? ? A3 ? ? ? ? A3 ? ? ? ? A3 ? ? ? ? A3 ? ? ? ? A3 ? ? ? ? 89 44 24 10 "), 5)
end

local function applyTrail(trailName, path, missions, limit)
  local result, err = cst_io.readCSV(path, limit + 1) -- one for the header
  if result == nil then error(err) end
  
  local f = io.open(string.format("ucp/.cache/custom-skirmish-trails-config-%s.yml", trailName), 'w')
  f:write(yaml.dump(result))
  f:close()

  REGISTRY[trailName] = result
  
  for index, entry in pairs(REGISTRY[trailName]) do
    interface.commitEntry(missions, index, entry, trailName)
  end
end

local function detourSwitchToMenu()
  core.detourCode(function(registers)
    local isTrail = core.readInteger(memory.IS_SKIRMISH_TRAIL) == 1

    if not isTrail then
      startgold.reset() -- tutaj resetujemy złoto przy powrocie do menu
    end

    local trail, trailName, mission = fetchCurrentTrail()
    if trail ~= nil then
      local missions = REGISTRY[trailName]
      if missions == nil then
        log(VERBOSE, string.format(
          "No custom missions registered for trail name: %s",
          trailName
        ))
        return registers
      end

      local entry = missions[mission]
      if entry == nil then
        log(-1, string.format(
          "skirmish trail (%s) entry is unexpectedly nil: %s",
          trailName, mission
        ))
        return registers
      end
      
      interface.commitTextDescription(entry)
      interface.commitStartGoldDisplay(entry)
    else
      log(2, "detourSwitchMenu: no trail active")
    end

    return registers
  end, core.AOBScan("C7 ? ? ? ? ? ? ? ? ? ? E8 ? ? ? ? 5D C3"), 11)
end



return {
  enable = function(self, config)
    if config.csv.strict_format == true then
      cst_io.setStrictness("error")
    else
      cst_io.setStrictness("warning")
    end

    local _, skirmishTrailMissions, extremeTrailMissions, warchestTrailMissions = utils.AOBExtract("8D ? I(? ? ? ?) 75 08 8D ? I(? ? ? ?) EB 0B 83 F9 01 75 06 8D ? I(? ? ? ?) 53")

    hooks.registerHookCallback("afterInit", function()
      local extremePath = config.extremetrail.csv.path
      if extremePath and extremePath ~= "" then
        applyTrail("extremeTrail", extremePath, extremeTrailMissions, 20)
      end

      local firsteditionPath = config.firstedition.csv.path
      if firsteditionPath and firsteditionPath ~= "" then
        applyTrail("firstEditionTrail", firsteditionPath, skirmishTrailMissions, 50)
      end

      local warchestPath = config.warchest.csv.path
      if warchestPath and warchestPath ~= "" then
        applyTrail("warchestTrail", warchestPath, warchestTrailMissions, 30) -- todo: check
      end

      self.REGISTRY = REGISTRY -- debug line
    end)

    insertPostSkirmishSetupDetour()


    -- -- detour to get the map text displayed right...
    -- core.detourCode(function(registers)
    --   if core.readInteger(memory.IS_SKIRMISH_TRAIL) ~= 1 then
    --     return registers
    --   end

    --   if core.readInteger(memory.CURRENT_TRAIL_TYPE) ~= 2 then
    --     return registers
    --   end

    --   local mission = core.readInteger(memory.EXTREME_TRAIL_PROGRESS) + 1
    --   local entry = REGISTRY.extremeTrail[mission]
    --   -- todo
    -- end, core.AOBScan("83 C2 51 52", 9))
    
    log(2, "enable description hijack")
    description.enable()
    tradeability.enable()
    producibility.enable()
    startgold.enable()
    
    detourSwitchToMenu()
  end,
  disable = function(self, config) end,
  getTrailProgress = function(self, trail)
    local progressAddr = TRAIL_PROGRESS_ADDRESSES[trail]

    if progressAddr == nil then
      error(string.format("no such trail: %s", trail))
    end
    
    return core.readInteger(progressAddr)
  end,
  setTrailProgress = function(self, trail, progress)
    local progressAddr = TRAIL_PROGRESS_ADDRESSES[trail]

    if progressAddr == nil then
      error(string.format("no such trail: %s", trail))
    end
    
    core.writeInteger(progressAddr, progress)
  end,
  setText = function(self, line, text)
    description.setText(line, text)
  end,
  getStartGood = function(self, good)
    return start_goods.getStartGood(good)
  end,
  setStartGood = function(self, good, value)
    start_goods.setStartGood(good, value)
  end,
  getTradeable = function(self, resource)
    return tradeability.getTradeable(resource)
  end,
  setTradeable = function(self, resource, tradeable)
    tradeability.setTradeable(resource, tradeable)
  end,
  setProducible = function(self, weapon, producible)
    producibility.setWeaponProducible(weapon, producible)
  end,
  getRecruitable = function(self, unit)
    return recruitability.getUnitRecruitable(unit)
  end,
  setRecruitable = function(self, unit, value)
    recruitability.setUnitRecruitable(unit, value)
  end,
  getTextDescription = function(self, index)
    return description.getText(index)
  end,
  setTextDescription = function(self, index, value)
    return description.setText(index, value)
  end,
},
{
  public = {
    "setTrailProgress",
    "setText",
    "setTradeable",
    "setProducible",
  }
}

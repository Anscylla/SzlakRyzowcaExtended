local memory = require("szlakryzowcaextended.memory")


local EURO_RECRUITABLE_OFFSETS = {
  ["archers"] = 0*4,
  ["crossbowmen"] = 1*4,
  ["spearmen"] = 2*4,
  ["pikemen"] = 3*4,
  ["macemen"] = 4*4,
  ["swordsmen"] = 5*4,
  ["knights"] = 6*4,
}

local MERC_RECRUITABLE_OFFSETS = {
  ["arabian_bows"] = 0*4,
  ["slaves"] = 1*4,
  ["slingers"] = 2*4,
  ["assassins"] = 3*4,
  ["horse_archers"] = 4*4,
  ["arabian_swordsmen"] = 5*4,
  ["fire_throwers"] = 6*4,
}

local function getUnitRecruitable(unit)
  local euroOffset = EURO_RECRUITABLE_OFFSETS[unit]
  if euroOffset ~= nil then
    local addr = memory.EURO_RECRUITABLE + euroOffset
    log(WARNING, string.format("getUnitRecruitable: getting %s at %X", unit,  addr))
    return core.readInteger(addr) == 1
  end

  local mercOffset = MERC_RECRUITABLE_OFFSETS[unit]
  if mercOffset ~= nil then
    local addr = memory.MERC_RECRUITABLE + mercOffset
    log(WARNING, string.format("getUnitRecruitable: getting %s at %X ", unit,  addr))
    return core.readInteger(addr) == 1
  end

  error( string.format("unknown unit: %s", unit))
end

local function setUnitRecruitable(unit, value)
  if value == nil then return end

  if type(value) == "boolean" then
    if value == true then value = 1 end
    if value == false then value = 0 end
  end

  local euroOffset = EURO_RECRUITABLE_OFFSETS[unit]
  if euroOffset ~= nil then
    local addr = memory.EURO_RECRUITABLE + euroOffset
    log(WARNING, string.format("setUnitRecruitable: setting %s at %X to %s", unit,  addr, value))
    core.writeInteger(addr, value)
    return
  end

  local mercOffset = MERC_RECRUITABLE_OFFSETS[unit]
  if mercOffset ~= nil then
    local addr = memory.MERC_RECRUITABLE + mercOffset
    log(WARNING, string.format("setUnitRecruitable: setting %s at %X to %s", unit,  addr, value))
    core.writeInteger(addr, value)
    return
  end

  error( string.format("unknown unit: %s", unit))
end

local function setUnitsRecruitable(entry)
  for name, offset in pairs(EURO_RECRUITABLE_OFFSETS) do
    local value = entry["recruitable_" .. name]
    if value ~= nil then
      setUnitRecruitable(name, value)
    end
  end

  for name, offset in pairs(MERC_RECRUITABLE_OFFSETS) do
    local value = entry["recruitable_" .. name]
    if value ~= nil then
      setUnitRecruitable(name, value)
    end
  end
end

return {
  setUnitRecruitable = setUnitRecruitable,
  getUnitRecruitable = getUnitRecruitable,
  setUnitsRecruitable = setUnitsRecruitable,
  EURO_RECRUITABLE_OFFSETS = EURO_RECRUITABLE_OFFSETS,
  MERC_RECRUITABLE_OFFSETS = MERC_RECRUITABLE_OFFSETS,
}
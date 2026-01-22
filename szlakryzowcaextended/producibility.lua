local pFletcherDetour, fletcherDetourSize = core.AOBScan("B8 11 00 00 00 EB E4"), 5
local pPoleTurnerDetour, poleturnerDetourSize = core.AOBScan("B8 13 00 00 00 66 89 84 37 A2 02 00 00"), 5

local memory = require("szlakryzowcaextended.memory")
local common = require("szlakryzowcaextended.common")

local WEAPON_PRODUCIBLE_OFFSETS = {
  address = memory.WEAPON_PRODUCIBLE,
  offsets = {
    ["crossbows"] = 0,
    ["pikes"] = 4,
    ["swords"] = 8,
    ["bows"] = 12,
    ["spears"] = 16,
    ["maces"] = 20,
  },
  writeFunction = core.writeInteger,
  readFunction = core.readInteger,
}

local function setWeaponProducible(weapon, value)
  local f = WEAPON_PRODUCIBLE_OFFSETS.writeFunction
  local address = WEAPON_PRODUCIBLE_OFFSETS.address
  local offsets = WEAPON_PRODUCIBLE_OFFSETS.offsets
  local addr = address + offsets[weapon]
  log(WARNING, string.format("setWeaponProducible: %s @ %X: %s", weapon,addr, value))
  f(addr, value)
end

local function setWeaponsProducible(entry)
  for name, offset in pairs(WEAPON_PRODUCIBLE_OFFSETS.offsets) do
    local entry_name = string.format("producible_%s", name)
    if entry[entry_name] ~= nil then
      setWeaponProducible(name, entry[entry_name])
    end
  end
end

local function getWeaponProducible(weapon, value)
  local f = WEAPON_PRODUCIBLE_OFFSETS.readFunction
  local address = WEAPON_PRODUCIBLE_OFFSETS.address
  local offsets = WEAPON_PRODUCIBLE_OFFSETS.offsets
  local addr = address + offsets[weapon]
  local value = f(addr)
  log(WARNING, string.format("getWeaponProducible: %s @ %X: %s", weapon,addr, value))
  return value
end


return {
  enable = function()
    core.writeCode(pFletcherDetour, {0x90, 0x90, 0x90, 0x90, 0x90, })
    core.detourCode(function(registers)
      local canBow = getWeaponProducible("bows") == 1
      local canCrossBow = getWeaponProducible("crossbows") == 1

      if not canBow then
        if canCrossBow then
          registers.EAX = common.resources.crossbow  
        else
          registers.EAX = common.resources.bow
        end
      else
        registers.EAX = common.resources.bow
      end

      log(WARNING, string.format("producibility: fletcher: %s (%s, %s)", registers.EAX, canBow, canCrossBow))

      return registers
    end, pFletcherDetour, fletcherDetourSize)
  
    core.writeCode(pPoleTurnerDetour, {0x90, 0x90, 0x90, 0x90, 0x90, })
    core.detourCode(function(registers)
      local canSpear = getWeaponProducible("spears") == 1
      local canPike = getWeaponProducible("pikes") == 1

      if not canSpear then
        if canPike then
          registers.EAX = common.resources.pike
        else
          registers.EAX = common.resources.spear
        end
      else
        registers.EAX = common.resources.spear
      end

      log(WARNING, string.format("producibility: poleturner: %s (%s, %s)", registers.EAX, canSpear, canPike))
      
      return registers
    end, pPoleTurnerDetour, poleturnerDetourSize)
  end,
  setWeaponProducible = setWeaponProducible,
  setWeaponsProducible = setWeaponsProducible,
  WEAPON_PRODUCIBLE_OFFSETS = WEAPON_PRODUCIBLE_OFFSETS,
}
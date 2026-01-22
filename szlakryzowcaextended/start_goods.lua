local memory = require("szlakryzowcaextended.memory")

local common = require("szlakryzowcaextended.common")

local function getStartGood(good)
  local g = common.resources[good]
  if g == nil then error(string.format("unknown good type: %s", good)) end

  local addr = memory.START_GOODS + (4*g)
  log(WARNING, string.format("getStartGood: %s @ %X", good,addr))
  return core.readInteger(addr)
end

local function setStartGood(good, value)
  local g = common.resources[good]
  if g == nil then error(string.format("unknown good type: %s", good)) end

  local addr = memory.START_GOODS + (4*g)
  log(WARNING, string.format("setStartGood: %s @ %X: %s", good,addr, value))
  core.writeInteger(addr, value)
end

local function hasPrefix(s, prefix)
  return s:sub(1, prefix:len()) == prefix
end

local function setStartGoods(entry)
  for name, offset in pairs(common.resources) do
    local names = {
      "resource_" .. name,
      "resources_" .. name,
    }
    for _, n in ipairs(names) do
      if entry[n] ~= nil then
        setStartGood(name, entry[n])
      end
    end
    
  end
end

return {
  getStartGood = getStartGood,
  setStartGood = setStartGood,
  setStartGoods = setStartGoods,
}
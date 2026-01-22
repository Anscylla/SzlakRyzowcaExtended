local common = require("szlakryzowcaextended.common")
local resources = common.resources
local _, pTradeAbilityArray

local tradeability = {}



function tradeability.enable()
  _, pTradeAbilityArray = utils.AOBExtract("89 ? I(? ? ? ?) 83 C0 08 83 C1 04 83 C6 04")
end

---@param goodsType string
---@param bool binary
function tradeability.setTradeable(goodsType, binary)
  if type(binary) ~= "number" then error(string.format("binary of wrong type: %s", binary)) end

  if resources[goodsType] == nil then
    error(debug.traceback(string.format("No such goods type: %s", goodsType)))
  end
  
  local addr = pTradeAbilityArray + (4 * resources[goodsType])
  log(WARNING, string.format("setTradeable: %s => %s (%s) @ 0x%X", goodsType, binary, binary, addr))
  core.writeInteger(addr, binary)
end

function tradeability.setTradeables(entry)
  for _, resource in ipairs(common.resources_array) do
    local v = entry[string.format("tradeable_%s", resource)]
    if v ~= nil then
      log(WARNING, string.format("tradeability: setting resource %s to %s", resource, v))
      tradeability.setTradeable(resource, v)  
    end
  end
end

function tradeability.getTradeable(goodsType)
  if resources[goodsType] == nil then
    error(debug.traceback(string.format("No such goods type: %s", goodsType)))
  end
  
  local addr = pTradeAbilityArray + (4 * resources[goodsType])
  log(WARNING, string.format("getTradeable: %s @ 0x%X", goodsType, addr))
  return core.readInteger(addr)
end

return tradeability
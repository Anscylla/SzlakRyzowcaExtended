-- =========================================================
-- interface.lua (NAPRAWIONA WERSJA)
-- =========================================================

local memory = require("szlakryzowcaextended.memory")
local tradeability = require("szlakryzowcaextended.tradeability")
local producibility = require("szlakryzowcaextended.producibility")
local recruitability = require("szlakryzowcaextended.recruitability")
local descriptiveTexts = require("szlakryzowcaextended.descriptive_texts")
local start_goods = require("szlakryzowcaextended.start_goods")
local startgold = require("szlakryzowcaextended.startgold")

local PLAYER_MAPPING = {
    ["SK_RAT"] = 1,
    ["SK_SNAKE"] = 2,
    ["SK_PIG"] = 3,
    ["SK_WOLF"] = 4,
    ["SK_SALADIN"] = 5,
    ["SK_CALIPH"] = 6,
    ["SK_SULTAN"] = 7,
    ["SK_RICHARD"] = 8,
    ["SK_FREDERICK"] = 9,
    ["SK_PHILLIP"] = 10,
    ["SK_WAZIR"] = 11,
    ["SK_EMIR"] = 12,
    ["SK_NIZAR"] = 13,
    ["SK_SHERIFF"] = 14,
    ["SK_MARSHAL"] = 15,
    ["SK_ABBOT"] = 16,
}

local STRING_ADDRESSES = {}

local ENTRY_OFFSETS = {
    ["map_name"] = 0*4,
    ["fairness"] = 1*4,
    ["start_levels"] = 2*4,
    ["num_players"] = 3*4,
    ["player1"] = 4*4,
    ["player2"] = 5*4,
    ["player3"] = 6*4,
    ["player4"] = 7*4,
    ["player5"] = 8*4,
    ["player6"] = 9*4,
    ["player7"] = 10*4,
    ["player8"] = 11*4,
    ["start_position1"] = 12*4,
    ["start_position2"] = 13*4,
    ["start_position3"] = 14*4,
    ["start_position4"] = 15*4,
    ["start_position5"] = 16*4,
    ["start_position6"] = 17*4,
    ["start_position7"] = 18*4,
    ["start_position8"] = 19*4,
    ["team1"] = 20*4,
    ["team2"] = 21*4,
    ["team3"] = 22*4,
    ["team4"] = 23*4,
    ["team5"] = 24*4,
    ["team6"] = 25*4,
    ["team7"] = 26*4,
    ["team8"] = 27*4,
    ["aiv_type1"] = 28*4,
    ["aiv_type2"] = 29*4,
    ["aiv_type3"] = 30*4,
    ["aiv_type4"] = 31*4,
    ["aiv_type5"] = 32*4,
    ["aiv_type6"] = 33*4,
    ["aiv_type7"] = 34*4,
    ["aiv_type8"] = 35*4,
}

local function commitEntry(addr, index, entry, trail)
    local offset = addr + 144 * (index - 1)
    log(WARNING, string.format("commitEntry: %s %X %s %X", entry, addr, index - 1, offset))

    local missionName = entry.mission_name
    if missionName ~= nil then
        if trail == "firstEditionTrail" then
            modules.textResourceModifier:SetText(0xF5, 0x01 + (index - 1), missionName)      
        elseif trail == "warchestTrail" then
            modules.textResourceModifier:SetText(0xF5, 0x33 + (index - 1), missionName)
        elseif trail == "extremeTrail" then
            modules.textResourceModifier:SetText(0xF5, 0x51 + (index - 1), missionName)  
        else 
            error(string.format("unknown trail: %s", trail))
        end  
    end

    local mapName = entry.map_name
    if mapName ~= nil and STRING_ADDRESSES[mapName] == nil then
        local mapNameAddress = core.allocate(mapName:len() + 1, true)
        core.writeString(mapNameAddress, mapName)
        STRING_ADDRESSES[mapName] = mapNameAddress
        log(WARNING, string.format("commitEntry: map name: %s", mapName))
    end

    local mapNameAddress = STRING_ADDRESSES[mapName]
    for name, value in pairs(entry) do
        if name == "map_name" then
            value = mapNameAddress
        end

        if value ~= nil then
            local fieldOffset = ENTRY_OFFSETS[name]
            if fieldOffset ~= nil then
                if name:sub(1, ("player"):len()) == "player" then
                    value = PLAYER_MAPPING[value]
                end
                log(WARNING, string.format("commitEntry: %s @ %X: %s", name, offset + fieldOffset, value))
                core.writeInteger(offset + fieldOffset, value)
            end
        end
    end
end

local function commitEntryExtra(entry)
    log(WARNING, string.format("commitEntryExtra: processing entry"))
    producibility.setWeaponsProducible(entry)
    recruitability.setUnitsRecruitable(entry)
    tradeability.setTradeables(entry)
end

local function commitTextDescription(entry)
    log(WARNING, string.format("commitTextDescription: %s => %s", entry, entry.text_description_line_01))
    descriptiveTexts.setTextDescriptions(entry)
end

-- KLUCZOWA ZMIANA: Używamy setStartGoldDisplay dla menu
local function commitStartGoldDisplay(entry)
    log(WARNING, string.format("commitStartGoldDisplay: gold_player_1=%s, gold_player_2=%s", 
        tostring(entry.gold_player_1), tostring(entry.gold_player_2)))
    startgold.setStartGoldDisplay(entry)
end

return {
    commitEntry = commitEntry,
    commitEntryExtra = commitEntryExtra,
    commitTextDescription = commitTextDescription,
    commitStartGoldDisplay = commitStartGoldDisplay,
    setStartGoods = start_goods.setStartGoods,
    STRING_ADDRESSES = STRING_ADDRESSES,
}
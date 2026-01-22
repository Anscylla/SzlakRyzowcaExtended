-- =========================================================
-- init.lua (NAPRAWIONA WERSJA)
-- =========================================================

---@diagnostic disable-next-line: undefined-global
local yaml = yaml or {dump = function(...) error("missing function") end}

-- =========================================================
-- SAFE MODULE LOADING
-- =========================================================
local function safeRequire(moduleName)
    local success, module = pcall(require, moduleName)
    if not success then
        log(WARNING, string.format("FATAL: Failed to load module '%s': %s", moduleName, module))
        error(string.format("Module loading failed: %s", moduleName))
    end
    return module
end

-- =========================================================
-- MODULES
-- =========================================================
local memory = safeRequire("szlakryzowcaextended.memory")
local interface = safeRequire("szlakryzowcaextended.interface")
local cst_io = safeRequire("szlakryzowcaextended.io")
local description = safeRequire("szlakryzowcaextended.description")
local tradeability = safeRequire("szlakryzowcaextended.tradeability")
local producibility = safeRequire("szlakryzowcaextended.producibility")
local recruitability = safeRequire("szlakryzowcaextended.recruitability")
local startgold = safeRequire("szlakryzowcaextended.startgold")
local start_goods = safeRequire("szlakryzowcaextended.start_goods")

log(WARNING, "DEBUG: All modules loaded successfully")

local TRAIL_TYPES = memory.TRAIL_TYPES
local TRAIL_PROGRESS_ADDRESSES = memory.TRAIL_PROGRESS_ADDRESSES
local REGISTRY = memory.REGISTRY
local fetchCurrentTrail = memory.fetchCurrentTrail

-- =========================================================
-- POST-SKIRMISH SETUP DETOUR (KOMPLETNA WERSJA)
-- =========================================================
local function insertPostSkirmishSetupDetour()
    log(WARNING, "")
    log(WARNING, "========================================")
    log(WARNING, "insertPostSkirmishSetupDetour: STARTING")
    log(WARNING, "========================================")

    -- =========================================================
    -- DETOUR #1: Po zakończeniu setupu skirmish - ustawia extra parametry
    -- Wywoływany gdy gra ładuje misję
    -- =========================================================
    local detour1Location = core.AOBScan(
        "8B 8C 24 ? ? 00 00 5F 5E 89 ? ? ? ? ? 89 ? ? ? ? ? 89 ? ? ? ? ? 89 ? ? ? ? ? 5B 33 CC"
    )
    local detour1Size = 7

    if detour1Location then
        log(WARNING, string.format("[OK] Detour #1 (post-setup) @ 0x%X, size=%d", detour1Location, detour1Size))
        
        core.detourCode(function(registers)
            log(WARNING, "=== DETOUR #1 TRIGGERED ===")

            local isTrail = core.readInteger(memory.IS_SKIRMISH_TRAIL)
            log(WARNING, string.format("  IS_SKIRMISH_TRAIL = %d", isTrail or -1))

            if isTrail ~= 1 then 
                log(WARNING, "  Not in trail, skipping")
                return registers 
            end

            local trail, trailName, mission = memory.fetchCurrentTrail()
            log(WARNING, string.format("  Trail = %s, Mission = %d", tostring(trailName), mission or -1))

            if not trailName then 
                log(WARNING, "  ERROR: Invalid trail")
                return registers
            end

            local missions = REGISTRY[trailName]
            if not missions then 
                log(WARNING, string.format("  WARNING: No missions data for trail %s", trailName))
                return registers 
            end

            local entry = missions[mission]
            if entry then
                log(WARNING, "  Calling interface.commitEntryExtra")
                interface.commitEntryExtra(entry)

                log(WARNING, "  Setting start gold for game")
                startgold.setStartGold(entry)
                
                log(WARNING, "  Detour #1 complete - gold values:")
                startgold.debugGetCurrentGold()
            else
                log(WARNING, string.format("  WARNING: No entry for mission %d", mission))
            end

            log(WARNING, "=== DETOUR #1 COMPLETED ===")
            return registers
        end, detour1Location, detour1Size)
    else
        log(WARNING, "[ERROR] Could not find Detour #1 location!")
    end

    -- =========================================================
    -- DETOUR #2: Ustawia startowe surowce
    -- =========================================================
    local detour2Location = core.AOBScan(
        "A3 ? ? ? ? A3 ? ? ? ? A3 ? ? ? ? A3 ? ? ? ? A3 ? ? ? ? A3 ? ? ? ? A3 ? ? ? ? A3 ? ? ? ? A3 ? ? ? ? 89 44 24 10"
    )
    local detour2Size = 5

    if detour2Location then
        log(WARNING, string.format("[OK] Detour #2 (start goods) @ 0x%X, size=%d", detour2Location, detour2Size))
        
        core.detourCode(function(registers)
            log(WARNING, "=== DETOUR #2 TRIGGERED ===")

            local isTrail = core.readInteger(memory.IS_SKIRMISH_TRAIL)
            if isTrail ~= 1 then 
                log(WARNING, "  Not in trail, skipping")
                return registers 
            end

            local trail, trailName, mission = memory.fetchCurrentTrail()
            if not trailName then 
                log(WARNING, "  Invalid trail, skipping")
                return registers 
            end

            local missions = REGISTRY[trailName]
            if not missions then 
                log(WARNING, string.format("  No missions for %s", trailName))
                return registers 
            end

            local entry = missions[mission]
            if entry then
                log(WARNING, string.format("  Setting start goods for %s mission %d", trailName, mission))
                interface.setStartGoods(entry)
            end

            log(WARNING, "=== DETOUR #2 COMPLETED ===")
            return registers
        end, detour2Location, detour2Size)
    else
        log(WARNING, "[ERROR] Could not find Detour #2 location!")
    end

    -- =========================================================
    -- DETOUR #3: Backup - późne ustawienie złota
    -- =========================================================
    local detour3Location = core.AOBScan("83 C4 04 5F 5E 5B C3")
    local detour3Size = 3

    if detour3Location then
        log(WARNING, string.format("[OK] Detour #3 (backup gold) @ 0x%X, size=%d", detour3Location, detour3Size))
        
        core.detourCode(function(registers)
            local isTrail = core.readInteger(memory.IS_SKIRMISH_TRAIL)
            if isTrail == 1 then
                local flags = startgold.debugGetFlags()
                -- Wykonaj forceApply jeśli trail jest aktywny i złoto nie zostało jeszcze zapisane
                if flags.trailGoldActive == 1 and flags.goldWritten ~= 1 then
                    log(WARNING, "=== DETOUR #3 TRIGGERED: FORCING GOLD WRITE ===")
                    startgold.forceApply()
                end
            end
            return registers
        end, detour3Location, detour3Size)
    else
        log(WARNING, "[INFO] Detour #3 pattern not found (optional)")
    end

    -- =========================================================
    -- DETOUR #4: Późny zapis złota (po załadowaniu mapy)
    -- =========================================================
    local lateGoldPatterns = {
        { pattern = "C7 05 ? ? ? ? 01 00 00 00 5F 5E 5B", size = 13, name = "flag_set" },
        { pattern = "83 C4 ? 5F 5E 5D 5B C3", size = 8, name = "func_epilog" },
        { pattern = "5F 5E 5D 5B 83 C4 ? C3", size = 8, name = "func_epilog2" },
        { pattern = "C3 CC CC CC CC CC CC CC 55 8B EC", size = 1, name = "ret_padding" },
    }

    local lateGoldInstalled = false
    for _, p in ipairs(lateGoldPatterns) do
        local location = core.AOBScan(p.pattern)
        if location and not lateGoldInstalled then
            log(WARNING, string.format("[OK] Late gold detour (%s) @ 0x%X, size=%d", p.name, location, p.size))
            
            core.detourCode(function(registers)
                local isTrail = core.readInteger(memory.IS_SKIRMISH_TRAIL)
                if isTrail == 1 then
                    local flags = startgold.debugGetFlags()
                    if flags.initialized and flags.trailGoldActive == 1 and flags.goldWritten ~= 1 then
                        log(WARNING, "=== LATE GOLD WRITE TRIGGERED ===")
                        local result = startgold.forceApply()
                        log(WARNING, string.format("  forceApply result: %s", tostring(result)))
                    end
                end
                return registers
            end, location, p.size)
            
            lateGoldInstalled = true
            break
        end
    end

    if not lateGoldInstalled then
        log(WARNING, "[WARNING] Late gold detour not installed - no matching pattern found")
    end

    -- =========================================================
    -- HOOK #5: Wejście do menu wyboru misji trail
    -- Ten hook ustawia wyświetlanie złota PRZED startem gry
    -- =========================================================
    
    local trailMenuPatterns = {
        { pattern = "83 F8 02 0F 84", size = 5, name = "trail_type_check" },
        { pattern = "83 F9 02 0F 84", size = 5, name = "trail_type_check_alt" },
        { pattern = "A3 ? ? ? ? E8 ? ? ? ? 83 C4 04 85 C0", size = 5, name = "trail_init" },
    }

    local trailMenuHookInstalled = false
    for _, p in ipairs(trailMenuPatterns) do
        local location = core.AOBScan(p.pattern)
        if location and not trailMenuHookInstalled then
            log(WARNING, string.format("[OK] Trail menu hook (%s) @ 0x%X", p.name, location))
            
            core.detourCode(function(registers)
                local currentTrailType = core.readInteger(memory.CURRENT_TRAIL_TYPE)
                local trailName = memory.TRAIL_TYPES[currentTrailType]
                
                if trailName and REGISTRY[trailName] then
                    local mission = 1
                    
                    if trailName == "firstEditionTrail" then
                        mission = core.readInteger(memory.FIRST_EDITION_TRAIL_PROGRESS) + 1
                    elseif trailName == "warchestTrail" then
                        mission = core.readInteger(memory.WARCHEST_TRAIL_PROGRESS) + 1
                    elseif trailName == "extremeTrail" then
                        mission = core.readInteger(memory.EXTREME_TRAIL_PROGRESS) + 1
                    end
                    
                    local entry = REGISTRY[trailName][mission]
                    if entry then
                        log(WARNING, string.format("=== TRAIL MENU HOOK: Pre-loading %s mission %d ===", trailName, mission))
                        startgold.setStartGoldDisplay(entry)
                    end
                end
                
                return registers
            end, location, p.size)
            
            trailMenuHookInstalled = true
            break
        end
    end
    
    if not trailMenuHookInstalled then
        log(WARNING, "[INFO] Trail menu hook patterns not found (will rely on other hooks)")
    end

    log(WARNING, "========================================")
    log(WARNING, "insertPostSkirmishSetupDetour: COMPLETED")
    log(WARNING, "========================================")
    log(WARNING, "")
end

-- =========================================================
-- APPLY TRAIL DATA
-- =========================================================
local function applyTrail(trailName, path, missions, limit)
    log(WARNING, string.format("=== applyTrail: %s ===", trailName))

    local result, err = cst_io.readCSV(path, limit + 1)
    if not result then 
        log(WARNING, string.format("ERROR: Failed to read CSV: %s", tostring(err)))
        error(err) 
    end

    log(WARNING, string.format("DEBUG: Loaded %d entries from CSV", #result))

    -- Debug: pokaż pierwsze entry
    if result[1] then
        log(WARNING, "DEBUG: First entry gold values:")
        log(WARNING, string.format("  gold_player_1 = %s (type: %s)", 
            tostring(result[1].gold_player_1), type(result[1].gold_player_1)))
        log(WARNING, string.format("  gold_player_2 = %s (type: %s)", 
            tostring(result[1].gold_player_2), type(result[1].gold_player_2)))
    end

    local f = io.open(string.format("ucp/.cache/custom-skirmish-trails-config-%s.yml", trailName), "w")
    if f then
        f:write(yaml.dump(result))
        f:close()
    end

    REGISTRY[trailName] = result
    log(WARNING, string.format("DEBUG: REGISTRY[%s] set with %d entries", trailName, #result))

    for index, entry in pairs(result) do
        interface.commitEntry(missions, index, entry, trailName)
    end

    log(WARNING, string.format("=== applyTrail: %s COMPLETED ===", trailName))
end

-- =========================================================
-- DETOUR FOR MENU SWITCH - Obsługa powrotu do menu
-- =========================================================
local function detourSwitchToMenu()
    local menuDetourLocation = core.AOBScan("C7 ? ? ? ? ? ? ? ? ? ? E8 ? ? ? ? 5D C3")
    
    if not menuDetourLocation then
        log(WARNING, "[ERROR] Could not find Menu detour location!")
        return
    end
    
    log(WARNING, string.format("[OK] Menu detour @ 0x%X", menuDetourLocation))

    core.detourCode(function(registers)
        log(WARNING, "=== MENU DETOUR TRIGGERED ===")

        -- Pobierz aktualny trail BEZPOŚREDNIO z pamięci
        local currentTrailType = core.readInteger(memory.CURRENT_TRAIL_TYPE)
        local trailName = memory.TRAIL_TYPES[currentTrailType]
        
        log(WARNING, string.format("  CURRENT_TRAIL_TYPE = %d (%s)", 
            currentTrailType or -1, tostring(trailName)))

        -- Dezaktywuj tryb gry (wracamy do menu)
        startgold.deactivateGameMode()

        -- Sprawdź czy mamy zarejestrowane misje dla tego trail
        if trailName and REGISTRY[trailName] then
            local mission = 1
            
            -- Pobierz numer misji
            if trailName == "firstEditionTrail" then
                mission = core.readInteger(memory.FIRST_EDITION_TRAIL_PROGRESS) + 1
            elseif trailName == "warchestTrail" then
                mission = core.readInteger(memory.WARCHEST_TRAIL_PROGRESS) + 1
            elseif trailName == "extremeTrail" then
                mission = core.readInteger(memory.EXTREME_TRAIL_PROGRESS) + 1
            end
            
            log(WARNING, string.format("  Trail context: %s, mission: %d", trailName, mission))
            
            local missions = REGISTRY[trailName]
            local entry = missions[mission]
            
            if entry then
                log(WARNING, string.format("  Entry found - gold_player_1=%s, gold_player_2=%s", 
                    tostring(entry.gold_player_1), tostring(entry.gold_player_2)))

                -- Ustaw opis tekstowy
                interface.commitTextDescription(entry)

                -- Ustaw wyświetlanie złota w menu
                interface.commitStartGoldDisplay(entry)

                -- Debug
                log(WARNING, "  Current gold state:")
                startgold.debugGetCurrentGold()
            else
                log(WARNING, string.format("  WARNING: No entry for mission %d", mission))
                startgold.reset()
            end
        else
            -- Nie jesteśmy w trail lub nie mamy danych - reset
            log(WARNING, "  Not in trail context or no data, resetting gold")
            startgold.reset()
        end

        log(WARNING, "=== MENU DETOUR COMPLETED ===")
        return registers
    end, menuDetourLocation, 11)
end

-- =========================================================
-- DETOUR FOR GAME END - Reset po zakończeniu misji
-- =========================================================
local function detourGameEnd()
    -- Szukamy miejsca wywoływanego przy końcu gry
    local gameEndPatterns = {
        "83 C4 04 5F 5E 5B C3",  -- Typowy epilog funkcji
    }

    for i, pattern in ipairs(gameEndPatterns) do
        local location = core.AOBScan(pattern)
        if location then
            log(WARNING, string.format("DEBUG: Game end detour (pattern %d) @ 0x%X", i, location))

            core.detourCode(function(registers)
                -- Dezaktywuj tryb gry
                startgold.deactivateGameMode()
                return registers
            end, location, 3)

            break
        end
    end
end

-- =========================================================
-- ENABLE EXTENSION
-- =========================================================
return {
  enable = function(self, config)
      log(WARNING, "")
      log(WARNING, "================================================")
      log(WARNING, "=== ENABLING SzlakRyzowcaExtended ===")
      log(WARNING, "================================================")

      if config.csv and config.csv.strict_format then
          cst_io.setStrictness("error")
      else
          cst_io.setStrictness("warning")
      end

      local _, skirmishTrailMissions, extremeTrailMissions, warchestTrailMissions = utils.AOBExtract(
          "8D ? I(? ? ? ?) 75 08 8D ? I(? ? ? ?) EB 0B 83 F9 01 75 06 8D ? I(? ? ? ?) 53"
      )

      log(WARNING, string.format("Mission addresses:"))
      log(WARNING, string.format("  skirmish: 0x%X", skirmishTrailMissions or 0))
      log(WARNING, string.format("  extreme: 0x%X", extremeTrailMissions or 0))
      log(WARNING, string.format("  warchest: 0x%X", warchestTrailMissions or 0))

      -- Ładowanie danych z CSV
      hooks.registerHookCallback("afterInit", function()
          log(WARNING, "=== afterInit HOOK TRIGGERED ===")

          if config.firstedition and config.firstedition.csv and config.firstedition.csv.path and config.firstedition.csv.path ~= "" then
              log(WARNING, string.format("Loading first edition trail from: %s", config.firstedition.csv.path))
              applyTrail("firstEditionTrail", config.firstedition.csv.path, skirmishTrailMissions, 50)
          end

          if config.extremetrail and config.extremetrail.csv and config.extremetrail.csv.path and config.extremetrail.csv.path ~= "" then
              log(WARNING, string.format("Loading extreme trail from: %s", config.extremetrail.csv.path))
              applyTrail("extremeTrail", config.extremetrail.csv.path, extremeTrailMissions, 20)
          end

          if config.warchest and config.warchest.csv and config.warchest.csv.path and config.warchest.csv.path ~= "" then
              log(WARNING, string.format("Loading warchest trail from: %s", config.warchest.csv.path))
              applyTrail("warchestTrail", config.warchest.csv.path, warchestTrailMissions, 30)
          end

          log(WARNING, "=== afterInit HOOK COMPLETED ===")
      end)

      -- Włącz moduły
      log(WARNING, "Enabling sub-modules...")
      
      log(WARNING, "  - description")
      description.enable()
      
      log(WARNING, "  - tradeability")
      tradeability.enable()
      
      log(WARNING, "  - producibility")
      producibility.enable()
      
      log(WARNING, "  - startgold (CRITICAL)")
      startgold.enable()

      -- Ustaw detoury
      log(WARNING, "Setting up detours...")
      insertPostSkirmishSetupDetour()
      detourSwitchToMenu()

      log(WARNING, "================================================")
      log(WARNING, "=== SzlakRyzowcaExtended ENABLED ===")
      log(WARNING, "================================================")
      log(WARNING, "")
  end,

    disable = function(self, config) 
        log(WARNING, "=== DISABLING SzlakRyzowcaExtended ===")
        startgold.reset()
    end,

    -- =========================================================
    -- PUBLIC API
    -- =========================================================
    
    getTrailProgress = function(self, trail)
        local addr = TRAIL_PROGRESS_ADDRESSES[trail]
        if not addr then error(string.format("no such trail: %s", trail)) end
        return core.readInteger(addr)
    end,

    setTrailProgress = function(self, trail, progress)
        local addr = TRAIL_PROGRESS_ADDRESSES[trail]
        if not addr then error(string.format("no such trail: %s", trail)) end
        core.writeInteger(addr, progress)
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

    -- =========================================================
    -- DEBUG FUNCTIONS
    -- =========================================================
    
    debugGetCurrentGold = function(self)
        return startgold.debugGetCurrentGold()
    end,

    debugGetGoldFlags = function(self)
        return startgold.debugGetFlags()
    end,

    debugGetCurrentTrail = function(self)
        local trail, trailName, mission = fetchCurrentTrail()
        log(WARNING, string.format("DEBUG: Current trail info - trail=%s, name=%s, mission=%d", 
            tostring(trail), tostring(trailName), mission or -1))
        return trail, trailName, mission
    end,

    debugGetRegistry = function(self)
        for trailName, missions in pairs(REGISTRY) do
            if missions then
                log(WARNING, string.format("DEBUG: REGISTRY[%s] has %d missions", trailName, #missions))
                if missions[1] then
                    log(WARNING, string.format("DEBUG: First mission gold_player_1 = %s", 
                        tostring(missions[1].gold_player_1)))
                    log(WARNING, string.format("DEBUG: First mission gold_player_2 = %s", 
                        tostring(missions[1].gold_player_2)))
                end
            else
                log(WARNING, string.format("DEBUG: REGISTRY[%s] is nil", trailName))
            end
        end
        return REGISTRY
    end,
},
-- =========================================================
-- PUBLIC API DEFINITION
-- =========================================================
{
    public = {
        "setTrailProgress",
        "setText", 
        "setTradeable",
        "setProducible",
        "debugGetCurrentGold",
        "debugGetGoldFlags",
        "debugGetCurrentTrail", 
        "debugGetRegistry",
    }
}
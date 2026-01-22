-- =========================================================
-- startgold.lua (WERSJA v14 - poprawiona)
-- =========================================================

local memory = require('szlakryzowcaextended.memory')

local startgold = {}

-- =========================================================
-- STAŁE
-- =========================================================

local EXE_BASE = 0x00400000
local EXE_END = 0x00700000

-- Bufory pamięci
local pCurrentTrail = nil
local pCurrentMission = nil
local pStartGoldValues = nil
local pTrailGoldActive = nil

local isInitialized = false

-- =========================================================
-- HELPERS
-- =========================================================

local function isValidExeAddress(addr)
    return addr and addr >= EXE_BASE and addr < EXE_END
end

-- =========================================================
-- INICJALIZACJA
-- =========================================================

local function initializeBuffers()
    if isInitialized then return end
    
    log(WARNING, "=== startgold: Initializing memory buffers ===")
    
    pCurrentTrail = core.allocate(4, true)
    pCurrentMission = core.allocate(4, true)
    pStartGoldValues = core.allocate(4 * 2, true)
    pTrailGoldActive = core.allocate(4, true)
    
    core.writeInteger(pCurrentTrail, 0)
    core.writeInteger(pCurrentMission, 0)
    core.writeInteger(pTrailGoldActive, 0)
    core.writeInteger(pStartGoldValues + 0, 0)
    core.writeInteger(pStartGoldValues + 4, 0)
    
    log(WARNING, string.format("  pCurrentTrail: 0x%X", pCurrentTrail))
    log(WARNING, string.format("  pCurrentMission: 0x%X", pCurrentMission))
    log(WARNING, string.format("  pStartGoldValues: 0x%X", pStartGoldValues))
    log(WARNING, string.format("  pTrailGoldActive: 0x%X", pTrailGoldActive))
    
    isInitialized = true
end

-- =========================================================
-- ASM LAMBDA
-- =========================================================

local function createRenderLambda()
    return [[
        push ecx

        ; =====================================================
        ; CHECK IF TRAIL GOLD IS ACTIVE
        ; =====================================================
        mov eax, dword [pTrailGoldActive]
        cmp eax, 1
        jne original

        ; =====================================================
        ; CHECK TRAIL TYPE
        ; =====================================================
        mov eax, dword [pType]
        mov ecx, dword [pCurrentTrail]
        cmp eax, ecx
        jne original

      firstTrail:
        cmp eax, 0
        jne warchestTrail
        mov eax, dword [pFirstProgress]
        mov ecx, dword [pCurrentMission]
        cmp eax, ecx
        jne original
        jmp modification

      warchestTrail:
        cmp eax, 1
        jne extremeTrail
        mov eax, dword [pWarchestProgress]
        mov ecx, dword [pCurrentMission]
        cmp eax, ecx
        jne original
        jmp modification

      extremeTrail:
        cmp eax, 2
        jne original
        mov eax, dword [pExtremeProgress]
        mov ecx, dword [pCurrentMission]
        cmp eax, ecx
        jne original

      modification:
        mov eax, dword [pStartGoldValues]
        jmp skip_original

      original:
        mov eax, dword [edx*8 + pData]

      skip_original:
        pop ecx
    ]]
end

-- =========================================================
-- ENABLE
-- =========================================================

function startgold.enable()
    log(WARNING, "")
    log(WARNING, "========================================")
    log(WARNING, "=== startgold.enable ===")
    log(WARNING, "========================================")
    
    initializeBuffers()
    
    -- =========================================================
    -- MAIN GOLD DETOUR
    -- =========================================================
    
    local detourPattern = "89 86 00 E4 FF FF"
    local detourSize = 6
    
    local success, detourAddress = pcall(core.AOBScan, detourPattern)
    
    if success and detourAddress and isValidExeAddress(detourAddress) then
        log(WARNING, string.format("[OK] Main gold detour @ 0x%X", detourAddress))
        
        core.detourCode(function(registers)
            -- Sprawdź czy jesteśmy w skirmish trail
            if core.readInteger(memory.IS_SKIRMISH_TRAIL) ~= 1 then
                return registers
            end
            
            -- Sprawdź czy trail gold jest aktywne
            if core.readInteger(pTrailGoldActive) ~= 1 then
                return registers
            end
            
            local playerID = registers.EBX
            
            local humanGold = core.readInteger(pStartGoldValues + 0)
            local aiGold = core.readInteger(pStartGoldValues + 4)
            
            local value = nil
            
            if playerID == nil or playerID <= 0 then
                return registers
            elseif playerID == 1 then
                value = humanGold
            else
                value = aiGold
            end
            
            if value ~= nil and value > 0 then
                log(WARNING, string.format(
                    "startgold: player %d gold = %d (was %d)",
                    playerID, value, registers.EAX
                ))
                registers.EAX = value
            end
            
            return registers
        end, detourAddress, detourSize)
        
        log(WARNING, "[OK] Main gold detour installed")
    else
        log(WARNING, "[ERROR] Main gold pattern not found or outside exe!")
    end
    
    -- =========================================================
    -- RENDER HOOKS
    -- =========================================================
    
    local success1, pRenderHook1, pData1 = pcall(utils.AOBExtract,
        "8B ? ? I(? ? ? ?) 0F AF C6 50 B9 ? ? ? ? E8 ? ? ? ? 8B ? ? ? ? ? 8B ? ? ? ? ? A1 ? ? ? ?"
    )
    
    if success1 and pRenderHook1 and pData1 and isValidExeAddress(pRenderHook1) then
        log(WARNING, string.format("[OK] Human render hook @ 0x%X", pRenderHook1))
        
        core.insertCode(pRenderHook1, 7, {
            core.AssemblyLambda(createRenderLambda(), {
                pData = pData1,
                pType = memory.CURRENT_TRAIL_TYPE,
                pFirstProgress = memory.FIRST_EDITION_TRAIL_PROGRESS,
                pWarchestProgress = memory.WARCHEST_TRAIL_PROGRESS,
                pExtremeProgress = memory.EXTREME_TRAIL_PROGRESS,
                pCurrentTrail = pCurrentTrail,
                pCurrentMission = pCurrentMission,
                pStartGoldValues = pStartGoldValues,
                pTrailGoldActive = pTrailGoldActive,
            })
        }, nil, 'before')
        
        log(WARNING, "[OK] Human render hook installed")
    end
    
    local success2, pRenderHook2, pData2 = pcall(utils.AOBExtract,
        "8B ? ? I(? ? ? ?) 0F AF C6 50 B9 ? ? ? ? E8 ? ? ? ? 8B ? ? ? ? ? 8B ? ? ? ? ? 83 C1 5C"
    )
    
    if success2 and pRenderHook2 and pData2 and isValidExeAddress(pRenderHook2) then
        log(WARNING, string.format("[OK] AI render hook @ 0x%X", pRenderHook2))
        
        core.insertCode(pRenderHook2, 7, {
            core.AssemblyLambda(createRenderLambda(), {
                pData = pData2,
                pType = memory.CURRENT_TRAIL_TYPE,
                pFirstProgress = memory.FIRST_EDITION_TRAIL_PROGRESS,
                pWarchestProgress = memory.WARCHEST_TRAIL_PROGRESS,
                pExtremeProgress = memory.EXTREME_TRAIL_PROGRESS,
                pCurrentTrail = pCurrentTrail,
                pCurrentMission = pCurrentMission,
                pStartGoldValues = pStartGoldValues + 4,
                pTrailGoldActive = pTrailGoldActive,
            })
        }, nil, 'before')
        
        log(WARNING, "[OK] AI render hook installed")
    end
    
    -- =========================================================
    -- Disable vanilla increment
    -- =========================================================
    
    local vanillaIncrementAddr = core.AOBScan("8D 77 01 8B ? ? ? ? ? A1 ? ? ? ?")
    if vanillaIncrementAddr and isValidExeAddress(vanillaIncrementAddr) then
        log(WARNING, string.format("[OK] Disabling vanilla increment @ 0x%X", vanillaIncrementAddr))
        core.writeCode(vanillaIncrementAddr, { 0x90, 0x90, 0x90 })
    end
    
    log(WARNING, "========================================")
    log(WARNING, "=== startgold.enable COMPLETED ===")
    log(WARNING, "========================================")
end

-- =========================================================
-- SET START GOLD DISPLAY (POPRAWIONE - bez sprawdzenia IS_SKIRMISH_TRAIL)
-- =========================================================

function startgold.setStartGoldDisplay(entry)
    if not isInitialized then initializeBuffers() end
    if not entry then return end
    
    -- Pobierz aktualny trail z pamięci
    local trail = core.readInteger(memory.CURRENT_TRAIL_TYPE)
    local trailName = memory.TRAIL_TYPES[trail]
    
    if not trailName then
        log(WARNING, "setStartGoldDisplay: invalid trail type")
        return
    end
    
    -- Pobierz aktualną misję
    local mission = 1
    if trailName == "firstEditionTrail" then
        mission = core.readInteger(memory.FIRST_EDITION_TRAIL_PROGRESS) + 1
    elseif trailName == "warchestTrail" then
        mission = core.readInteger(memory.WARCHEST_TRAIL_PROGRESS) + 1
    elseif trailName == "extremeTrail" then
        mission = core.readInteger(memory.EXTREME_TRAIL_PROGRESS) + 1
    end
    
    -- Ustaw flagi
    core.writeInteger(pTrailGoldActive, 1)
    core.writeInteger(pCurrentTrail, trail)
    core.writeInteger(pCurrentMission, mission - 1)
    
    -- Znajdź max AI gold
    local maxAI = nil
    for playerID = 2, 8 do
        local value = tonumber(entry[string.format("gold_player_%d", playerID)])
        if value ~= nil then
            if maxAI == nil or value > maxAI then
                maxAI = value
            end
        end
    end
    
    local humanGold = tonumber(entry["gold_player_1"]) or 0
    
    core.writeInteger(pStartGoldValues + 0, humanGold)
    core.writeInteger(pStartGoldValues + 4, maxAI or 0)
    
    log(WARNING, string.format(
        "setStartGoldDisplay: trail=%s mission=%d human=%d ai=%s",
        trailName, mission, humanGold, tostring(maxAI)
    ))
end

-- =========================================================
-- SET START GOLD
-- =========================================================

function startgold.setStartGold(entry)
    log(WARNING, "=== startgold.setStartGold ===")
    startgold.setStartGoldDisplay(entry)
end

-- =========================================================
-- RESET
-- =========================================================

function startgold.reset()
    log(WARNING, "=== startgold.reset ===")
    
    if not isInitialized then return end
    
    core.writeInteger(pTrailGoldActive, 0)
    core.writeInteger(pStartGoldValues + 0, 0)
    core.writeInteger(pStartGoldValues + 4, 0)
end

-- =========================================================
-- DEACTIVATE GAME MODE
-- =========================================================

function startgold.deactivateGameMode()
    log(WARNING, "=== startgold.deactivateGameMode ===")
end

-- =========================================================
-- FORCE APPLY
-- =========================================================

function startgold.forceApply()
    return true
end

-- =========================================================
-- DEBUG
-- =========================================================

function startgold.debugGetCurrentGold()
    log(WARNING, "=== startgold.debugGetCurrentGold ===")
    
    if not isInitialized then
        log(WARNING, "  Not initialized!")
        return {}
    end
    
    log(WARNING, string.format("  pTrailGoldActive: %d", core.readInteger(pTrailGoldActive)))
    log(WARNING, string.format("  pCurrentTrail: %d", core.readInteger(pCurrentTrail)))
    log(WARNING, string.format("  pCurrentMission: %d", core.readInteger(pCurrentMission)))
    log(WARNING, string.format("  IS_SKIRMISH_TRAIL: %d", core.readInteger(memory.IS_SKIRMISH_TRAIL)))
    
    local humanGold = core.readInteger(pStartGoldValues + 0)
    local aiGold = core.readInteger(pStartGoldValues + 4)
    
    log(WARNING, string.format("  Human gold: %d", humanGold))
    log(WARNING, string.format("  AI gold: %d", aiGold))
    
    return { humanGold, aiGold }
end

function startgold.debugGetFlags()
    if not isInitialized then
        return { initialized = false }
    end
    
    return {
        initialized = true,
        trailGoldActive = core.readInteger(pTrailGoldActive),
        currentTrail = core.readInteger(pCurrentTrail),
        currentMission = core.readInteger(pCurrentMission),
        isSkirmishTrail = core.readInteger(memory.IS_SKIRMISH_TRAIL),
        humanGold = core.readInteger(pStartGoldValues + 0),
        aiGold = core.readInteger(pStartGoldValues + 4),
    }
end

return startgold
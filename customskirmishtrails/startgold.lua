local memory = require('customskirmishtrails.memory')

local startgold = {}

-- =========================================================
-- MEMORY
-- =========================================================

local pCurrentTrail      = core.allocate(4, true)
local pCurrentMission    = core.allocate(4, true)
local pStartGoldValues   = core.allocate(4 * 2, true) -- [0]=human [1]=ai
local pTrailGoldActive   = core.allocate(4, true)

-- =========================================================
-- ASM LAMBDA
-- =========================================================

local t = function()
  return [[
    push ecx

    ; =====================================================
    ; CHECK IF SKIRMISH TRAIL IS ACTIVE
    ; =====================================================
    mov eax, dword [pIsSkirmishTrail]
    cmp eax, 1
    jne original

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

  -- -----------------------------------------------------
  -- MAIN GOLD DETOUR
  -- -----------------------------------------------------

  local detourAddress = core.AOBScan("89 86 00 E4 FF FF")
  local detourSize = 6

  log(VERBOSE, string.format(
    'startgold: enabling hook @ 0x%X',
    detourAddress
  ))

  core.detourCode(function(registers)

    -- HARD BLOCK: not a skirmish trail
    if core.readInteger(memory.IS_SKIRMISH_TRAIL) ~= 1 then
      return registers
    end

    if core.readInteger(pTrailGoldActive) ~= 1 then
      return registers
    end

    local trail, trailName, mission = memory.fetchCurrentTrail()
    if trail == nil then
      return registers
    end

    local missions = memory.REGISTRY[trailName]
    if missions == nil then
      return registers
    end

    local entry = missions[mission]
    if entry == nil then
      log(-1, string.format(
        "startgold: missing entry for trail '%s' mission %s",
        trailName,
        tostring(mission)
      ))
      return registers
    end

    local playerID = registers.EBX

    local humanGold = core.readInteger(pStartGoldValues + 0)
    local aiGold    = core.readInteger(pStartGoldValues + 4)

    local value = nil

    -- NOTE: player indexing safety
    if playerID <= 0 then
      return registers
    elseif playerID == 1 then
      value = humanGold
    else
      value = aiGold
    end

    if value ~= nil then
      log(VERBOSE, string.format(
        "startgold: player %i start gold = %i",
        playerID,
        value
      ))
      registers.EAX = value
    end

    return registers

  end, detourAddress, detourSize)

  -- -----------------------------------------------------
  -- RENDER / CALC HOOKS
  -- -----------------------------------------------------

  -- humans
  local pRenderHook1, pData1 = utils.AOBExtract(
    "8B ? ? I(? ? ? ?) 0F AF C6 50 B9 ? ? ? ? E8 ? ? ? ? 8B ? ? ? ? ? 8B ? ? ? ? ? A1 ? ? ? ?"
  )

  core.insertCode(pRenderHook1, 7, {
    core.AssemblyLambda(t(), {
      pData               = pData1,
      pType               = memory.CURRENT_TRAIL_TYPE,
      pFirstProgress      = memory.FIRST_EDITION_TRAIL_PROGRESS,
      pWarchestProgress   = memory.WARCHEST_TRAIL_PROGRESS,
      pExtremeProgress    = memory.EXTREME_TRAIL_PROGRESS,
      pCurrentTrail       = pCurrentTrail,
      pCurrentMission     = pCurrentMission,
      pStartGoldValues    = pStartGoldValues,
      pTrailGoldActive    = pTrailGoldActive,
      pIsSkirmishTrail    = memory.IS_SKIRMISH_TRAIL,
    })
  }, nil, 'before')

  -- ai
  local pRenderHook2, pData2 = utils.AOBExtract(
    "8B ? ? I(? ? ? ?) 0F AF C6 50 B9 ? ? ? ? E8 ? ? ? ? 8B ? ? ? ? ? 8B ? ? ? ? ? 83 C1 5C"
  )

  core.insertCode(pRenderHook2, 7, {
    core.AssemblyLambda(t(), {
      pData               = pData2,
      pType               = memory.CURRENT_TRAIL_TYPE,
      pFirstProgress      = memory.FIRST_EDITION_TRAIL_PROGRESS,
      pWarchestProgress   = memory.WARCHEST_TRAIL_PROGRESS,
      pExtremeProgress    = memory.EXTREME_TRAIL_PROGRESS,
      pCurrentTrail       = pCurrentTrail,
      pCurrentMission     = pCurrentMission,
      pStartGoldValues    = pStartGoldValues + 4,
      pTrailGoldActive    = pTrailGoldActive,
      pIsSkirmishTrail    = memory.IS_SKIRMISH_TRAIL,
    })
  }, nil, 'before')

  -- disable vanilla increment
  core.writeCode(
    core.AOBScan("8D 77 01 8B ? ? ? ? ? A1 ? ? ? ?"),
    { 0x90, 0x90, 0x90 }
  )

  log(VERBOSE, 'startgold: enabling done!')
end

-- =========================================================
-- SET START GOLD (TRAIL ONLY)
-- =========================================================

function startgold.setStartGoldDisplay(entry)

  if core.readInteger(memory.IS_SKIRMISH_TRAIL) ~= 1 then
    return
  end

  local trail, trailName, mission = memory.fetchCurrentTrail()
  if trail == nil then
    return
  end

  core.writeInteger(pTrailGoldActive, 1)
  core.writeInteger(pCurrentTrail, trail)
  core.writeInteger(pCurrentMission, mission - 1)

  local maxAI = nil

  for playerID = 2, 8 do
    local value = tonumber(entry[string.format("gold_player_%i", playerID)])
    if value ~= nil then
      if maxAI == nil or value > maxAI then
        maxAI = value
      end
    end
  end

  local humanGold = tonumber(entry["gold_player_1"]) or 0

  core.writeInteger(pStartGoldValues + 0, humanGold)

  if maxAI ~= nil then
    core.writeInteger(pStartGoldValues + 4, maxAI)
  end

  log(VERBOSE, string.format(
    "startgold: trail=%s mission=%i human=%i ai=%s",
    trailName,
    mission,
    humanGold,
    tostring(maxAI)
  ))
end

-- =========================================================
-- RESET (CALL ON EXIT FROM TRAIL)
-- =========================================================

function startgold.reset()
  core.writeInteger(pTrailGoldActive, 0)
  core.writeInteger(pStartGoldValues + 0, 0) -- human gold
  core.writeInteger(pStartGoldValues + 4, 0) -- AI gold
end

return startgold

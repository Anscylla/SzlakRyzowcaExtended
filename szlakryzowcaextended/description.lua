
local _, pColorArray = utils.AOBExtract("8B ? ? I(? ? ? ?) 6A 13 6A 00 51")
local _, pTextManagerObj = utils.AOBExtract("8B ? I(? ? ? ?) A1 ? ? ? ? 52 8D 54 01 0A")

local renderFunc = core.AOBScan("8B 44 24 20 8B 54 24 18 53")

local placeholderAddress = core.allocate(100)
core.writeString(placeholderAddress, "[placeholder]")

local textLines = {
  core.allocate(1000, true),
  core.allocate(1000, true),
  core.allocate(1000, true),
  core.allocate(1000, true),
  core.allocate(1000, true),
  core.allocate(1000, true),
  core.allocate(1000, true),
  core.allocate(1000, true),
}

local function genRenderText(address, xOffset, yOffset)
  return core.AssemblyLambda([[
    pushad
    
    push 0
    push 0
    push 0x12
    push 0
    mov edx, dword [pColorArray]
    push edx
    push 0
    add eax, yOffset
    push eax
    add ecx, xOffset
    push ecx
    
    mov ecx, stringAddress
    push ecx
    mov ecx, pTextManagerObj
    call func
    
    popad
  ]], {
    func = renderFunc,
    stringAddress = address or placeholderAddress,
    pColorArray = pColorArray,
    pTextManagerObj = pTextManagerObj,
    yOffset = 0x04 + (yOffset or 0),
    xOffset = 0x100 + (xOffset or 0),
  })
end



-- --[[
  -- Render map description in the skirmish mission intro
-- --]]
 
 -- -- MenuView_CrusadeMissionIntro_DoEveryFrame
 -- -- 

    -- -- _mode = 1;
    -- -- _blendStrength = 0;
    -- -- _color = 0;
    -- -- _width = 345;
    -- -- _y = 0;
    -- -- _x = 0;
    -- -- _mapDescription = DAT_GameCore.mapDescription;
-- -- LAB_004411d1:
    -- -- Text::FontSizeClass::renderMultilineText?
              -- -- (TextManagerObj.fontSizeClassArray + 0x13,_mapDescription,_x,_y,_width,_color,
               -- -- _blendStrength,_mode);

-- testStringAddress = core.allocate(100)
-- core.writeString(testStringAddress, "Hello world!")

-- detourAddress = core.allocateCode({0x90, 0x90, 0x90, 0x90, 0x90, 0xC3})
-- core.detourCode(function(registers)
  -- log(WARNING, string.format("renderMultilineText: %s, %s", registers.ECX, registers.EAX))

-- end, detourAddress, 5)

-- -- For some reason doesn't appear...
-- al = core.AssemblyLambda([[
  -- pushad
  
  -- push 0; mode, 0, 1, 2
  -- push 0
  -- mov edx, dword [0x00615104]
  -- push edx ; color. Original: push 0
  -- push 345
  -- add eax, 0x10
  -- push eax
  -- add ecx, 0x100
  -- push ecx
  -- mov ecx, stringAddress
  -- push ecx
  -- mov ecx, 0x0215786c
  -- call func

  
  -- popad
-- ]], {
  -- func = 0x00472ef0,
  -- stringAddress = testStringAddress,
  -- x = 0x4c,
  -- y = 100,
  -- detour = detourAddress,
-- })

-- local _, pColorArray = utils.AOBExtract("8B ? ? I(? ? ? ?) 6A 13 6A 00 51")
-- local _, pTextManagerObj = utils.AOBExtract("8B ? I(? ? ? ?) A1 ? ? ? ? 52 8D 54 01 0A")

-- al2 = core.AssemblyLambda([[
  -- pushad
  
  -- push 0
  -- push 0
  -- push 0x12
  -- push 0
  -- mov edx, dword [pColorArray]
  -- push edx
  -- push 0
  -- add eax, 0x04
  -- push eax
  -- add ecx, 0x100
  -- push ecx
  
  -- mov ecx, stringAddress
  -- push ecx
  -- mov ecx, pTextManagerObj
  -- call func
  
  -- popad
-- ]], {
  -- func = core.AOBScan("8B 44 24 20 8B 54 24 18 53"),
  -- stringAddress = testStringAddress,
  -- pColorArray = pColorArray,
  -- pTextManagerObj = pTextManagerObj,
-- })

-- core.insertCode(core.AOBScan("8D A4 24 00 00 00 00 83 FD 01"), 7, {al2}, nil, 'after')


return {
  enable = function()
    local codes = {}
    for line, addr in pairs(textLines) do
      table.insert(codes, genRenderText(addr, 0, 0x16 * (line - 1)))
    end
    core.insertCode(core.AOBScan("8D A4 24 00 00 00 00 83 FD 01"), 7, codes, nil, 'after')
  end,
  setText = function(line, text)
    local ttext = modules.textResourceModifier:TransformText(text)
    core.writeString(textLines[line], ttext)
    core.writeByte(textLines[line] + string.len(ttext), 0)
  end,
  getText = function(line)
    return core.readString(textLines[line])
  end,
}



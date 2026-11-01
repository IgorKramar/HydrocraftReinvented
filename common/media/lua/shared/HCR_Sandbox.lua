require "HCR_SandboxCatalog"
HCRSandbox={}
local S=HCRSandbox

function S.value(option)
    -- SP admin UI меняет native option без toLua. На сервере и клиенте
    -- значения этого объекта обновляются штатным пакетом SandboxOptions.
    if getSandboxOptions then
        local native=getSandboxOptions():getOptionByName("Hydrocraft."..option)
        if native then return native:getValue() end
    end
    local settings=SandboxVars and SandboxVars.Hydrocraft
    return settings and settings[option]
end

function S.enabled(option)
    return S.value(option)~=false
end

function S.multiplier(option,minimum,maximum)
    local value=S.value(option)
    if type(value)~="number" or value~=value or value==math.huge or value==-math.huge then return 1 end
    return math.max(minimum,math.min(maximum,value))
end

function S.recipeEnabled(recipe)
    local option=recipe and HCRSandboxCatalog.recipes[recipe:getName()]
    return not option or S.enabled(option)
end

function S.itemEnabled(kind)
    local option=HCRSandboxCatalog.items[kind]
    return not option or S.enabled(option)
end

for token,definition in pairs(HCRSandboxCatalog.callbacks) do
    local rule=definition
    S["Test_"..token]=function(item,character)
        if not S.enabled(rule.option) then return false end
        if rule.previous=="" then return true end
        local fn=_G
        for part in rule.previous:gmatch("[^.]+") do fn=fn and fn[part] end
        assert(type(fn)=="function","Missing original sandbox recipe predicate: "..rule.previous)
        return fn(item,character)
    end
end

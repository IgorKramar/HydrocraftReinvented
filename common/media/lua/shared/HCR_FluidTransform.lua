-- Перестройка проверяется на отдельном native компоненте. Исходный сосуд
-- сохраняет идентичность и настройки; копирование также сохраняет цвет примесей.
require 'HCR_FluidLedger'
HCRFluidTransform={}
local X=HCRFluidTransform

function X.contents(fluid)
    local sample=fluid:createFluidSample()
    local parts={}
    for i=0,sample:size()-1 do
        local kind=sample:getFluid(i)
        parts[#parts+1]={name=kind:getFluidTypeString(),litres=fluid:getSpecificFluidAmount(kind)}
    end
    sample:release()
    return parts
end

local function matches(fluid,parts)
    local actual=X.contents(fluid)
    if #actual~=#parts then return false end
    for i,part in ipairs(parts) do
        if actual[i].name~=part.name or math.abs(actual[i].litres-part.litres)>.000001 then return false end
    end
    return true
end

local function total(parts)
    local amount=0
    for _,part in ipairs(parts) do amount=amount+part.litres end
    return amount
end

function X.rewrite(fluid,before,after)
    local L=HCRFluidLedger
    L.validate(before);L.validate(after)
    local initial=X.contents(fluid)
    local expected,desired={},{}
    for _,lot in ipairs(before.lots) do expected[lot.fluid]=(expected[lot.fluid] or 0)+lot.litres end
    for _,lot in ipairs(after.lots) do desired[lot.fluid]=(desired[lot.fluid] or 0)+lot.litres end
    local found={}
    for _,part in ipairs(initial) do
        found[part.name]=part.litres
        if expected[part.name] then
            assert(math.abs(part.litres-expected[part.name])<.000001,'Fermentation source changed')
        end
    end
    for name,amount in pairs(expected) do
        assert(math.abs(amount-(found[name] or 0))<.000001,'Missing fermentation source')
    end
    assert(math.abs(L.volume(before)-L.volume(after))<.000001,'Fermentation changed volume')
    -- Сохраняем порядок уже существующих компонентов; новые идут в порядке
    -- партий. Это делает primary fluid при равных объёмах воспроизводимым.
    local planned,seen={},{}
    for _,part in ipairs(initial) do
        local amount=desired[part.name]
        if amount==nil then amount=expected[part.name] and 0 or part.litres end
        if amount>0 then planned[#planned+1]={name=part.name,litres=amount};seen[part.name]=true end
    end
    for _,lot in ipairs(after.lots) do
        if not seen[lot.fluid] and desired[lot.fluid]>0 then
            planned[#planned+1]={name=lot.fluid,litres=desired[lot.fluid]};seen[lot.fluid]=true
        end
    end
    if #planned>8 then return false,'components' end
    local whitelist,blacklist=fluid:getWhitelist(),fluid:getBlacklist()
    for _,part in ipairs(planned) do
        local kind=assert(Fluid.Get(part.name),'Missing fermentation fluid: '..part.name)
        if (whitelist and not whitelist:allows(kind)) or (blacklist and not blacklist:allows(kind)) then
            return false,'filter'
        end
        for _,other in ipairs(planned) do
            local second=assert(Fluid.Get(other.name),'Missing fermentation mixture')
            if not kind:canBlendWith(second) then return false,'blend' end
        end
    end
    local capacity=fluid:getCapacity()
    assert(total(planned)<=capacity+.000001,'Fermentation exceeds vessel capacity')
    local backup=FluidContainer.CreateContainer()
    local candidate=FluidContainer.CreateContainer()
    local committed=false
    local locked,empty=fluid:isInputLocked(),fluid:canPlayerEmpty()
    local ok,reason=pcall(function()
        -- Запас устраняет округление isFull до capacity в последнем миллилитре.
        backup:setCapacity(capacity+1);backup:copyFluidsFrom(fluid)
        assert(matches(backup,initial),'Native backup lost liquid')
        candidate:setCapacity(capacity+1);candidate:copyFluidsFrom(backup)
        -- Сначала освободить все убывающие компоненты и только потом добавлять.
        for _,part in ipairs(initial) do
            local amount=desired[part.name]
            if amount==nil then amount=expected[part.name] and 0 or part.litres end
            if amount<part.litres then candidate:adjustSpecificFluidAmount(Fluid.Get(part.name),amount) end
        end
        -- Native adjustSpecificFluidAmount удаляет остатки менее 0,1 мл.
        -- Вернуть их через addFluid, который сохраняет такой положительный
        -- объём; удалённый компонент по правилам движка встанет в конец.
        local reordered,remaining={},{}
        for _,part in ipairs(X.contents(candidate)) do
            local amount=desired[part.name] or part.litres
            reordered[#reordered+1]={name=part.name,litres=amount};remaining[part.name]=true
        end
        for _,part in ipairs(planned) do
            if not remaining[part.name] then reordered[#reordered+1]=part end
        end
        planned=reordered
        for _,part in ipairs(planned) do
            local kind=Fluid.Get(part.name)
            local amount=candidate:getSpecificFluidAmount(kind)
            if part.litres>amount then candidate:addFluid(kind,part.litres-amount) end
        end
        assert(matches(candidate,planned),'Native fermentation plan lost liquid')
        fluid:setCapacity(capacity+1);fluid:setInputLocked(false);fluid:setCanPlayerEmpty(true)
        committed=true
        fluid:copyFluidsFrom(candidate);fluid:setCapacity(capacity)
        assert(matches(fluid,planned),'Native fermentation result lost liquid')
    end)
    if not ok and committed then
        -- Настройки возвращаются и после ошибки; копия хранит исходные примеси.
        fluid:setCapacity(capacity+1);fluid:copyFluidsFrom(backup);fluid:setCapacity(capacity)
    end
    fluid:setInputLocked(locked);fluid:setCanPlayerEmpty(empty)
    FluidContainer.DisposeContainer(candidate);FluidContainer.DisposeContainer(backup)
    if not ok then error(reason) end
    return true
end

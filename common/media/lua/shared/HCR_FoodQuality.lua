-- Native Food хранит питание. Sidecar сохраняет точный яд и нижнюю границу
-- свежести; native integer poisonPower остаётся видимым маркером дозы.
require "HCR_FluidEffects"
require "HCR_Medicine"
-- Native copyConditionStatesFrom переносит condition:* и при приготовлении,
-- и при гниении. Новая таблица при каждой записи исключает общую изменяемую дозу.
HCRFoodQuality={key="condition:HCRFoodPoison160",qualityKey="condition:HCRFoodFreshness160",
    taintKey="condition:HCRFoodTaint160",maxDose=1000000}
local F=HCRFoodQuality
local contexts={}

local function valid(dose)
    return type(dose)=="number" and dose>=0 and dose<=F.maxDose
end

function F.active(item)
    return item and item:IsFood() and (item:getModData()[F.key]~=nil or item:getModData()[F.qualityKey]~=nil
        or item:getModData()[F.taintKey]~=nil or item:isTainted())
end

-- B42 Food.save не пишет isTainted: полный replacement может затереть флаг,
-- ранее полученный через ItemStats. Запись переживает сеть/сейв, а очистка
-- следует реальному native cookingTime.
function F.tainted(item)
    if not item or not item:IsFood() then return false end
    local saved=item:getModData()[F.taintKey]
    if not saved then return item:isTainted() end
    assert(saved.version==1 and type(saved.cleared)=='boolean','Invalid Food taint state')
    if saved.cleared then return false end
    assert(type(saved.cookingTime)=='number' and saved.cookingTime>=0 and type(saved.threshold)=='number'
        and saved.threshold>=0 and type(saved.cookedTargets)=='table','Invalid Food taint cooking state')
    if saved.cookedTargets[item:getFullType()] then return false end
    local elapsed=item:getCookingTime()
    -- Уже приготовленное блюдо после загрязнения должно снова нагреться.
    -- Просто загрузить старое высокое cookingTime недостаточно для очистки.
    return not (elapsed>saved.cookingTime and elapsed>saved.threshold)
end

function F.setTainted(item)
    assert(not isClient() and item:IsFood(),'Invalid Food taint destination')
    local targets={};local cooked=item:getReplaceOnCooked()
    if cooked then for i=0,cooked:size()-1 do
        local kind=cooked:get(i)
        if not kind:find('%.') then kind=item:getFullType():match('^([^%.]+)')..'.'..kind end
        targets[kind]=true
    end end
    item:getModData()[F.taintKey]={version=1,cleared=false,cookingTime=item:getCookingTime(),
        threshold=item:isCookable() and math.min(item:getMinutesToCook(),10) or 10,cookedTargets=targets}
    item:setTainted(true)
end

local ranks={fresh=0,stale=1,rotten=2}
local function qualityState(saved)
    assert(type(saved)=="table" and saved.version==1 and (saved.state=="stale" or saved.state=="rotten"),
        "Invalid Food freshness state")
    for _,key in ipairs({"offAge","offAgeMax"}) do
        local value=saved[key]
        assert(value==nil or (type(value)=="number" and value>=0 and value<=1000000000),
            "Invalid Food freshness override")
    end
    return saved
end
function F.worst(a,b)
    assert(ranks[a] and ranks[b],"Invalid Food freshness")
    return ranks[a]>=ranks[b] and a or b
end

function F.quality(item)
    local state="fresh"
    if item:getAge()>=item:getOffAgeMax() then state="rotten"
    elseif item:getAge()>=item:getOffAge() then state="stale" end
    local saved=item:getModData()[F.qualityKey]
    if saved then
        qualityState(saved)
        state=F.worst(state,saved.state)
    end
    return state
end

function F.setQuality(item,state)
    assert(not isClient() and item:IsFood() and ranks[state],"Invalid Food quality destination")
    local data=item:getModData()
    if state=="fresh" then data[F.qualityKey]=nil;return end
    local old=data[F.qualityKey]
    if old and old.state==state then F.reconcile(item);return end
    local saved={version=1,state=state}
    if state=="rotten" and item:getOffAgeMax()>=1000000000 then
        -- У консервов нет native срока. Нельзя ставить age миллиард дней:
        -- это сразу удалит блюдо при DaysForRottenFoodRemoval. Задаём короткую
        -- native шкалу уже испорченного продукта; overrides переживают сейв.
        saved.offAge,saved.offAgeMax=0,1
        item:setAge(1.001)
    elseif state=="stale" and item:getOffAge()>=item:getOffAgeMax() then
        -- У некоторых продуктов вообще нет интервала «несвежий».
        saved.offAge=0
    end
    data[F.qualityKey]=saved
    F.reconcile(item)
end

function F.dose(item)
    local saved=item:getModData()[F.key]
    if not saved then
        local dose=item:getPoisonPower()
        assert(valid(dose),"Invalid native food poison")
        return dose
    end
    assert(saved.version==1 and valid(saved.dose),"Invalid food poison state")
    return saved.dose
end

function F.store(item,dose)
    assert(not isClient() and item:IsFood() and valid(dose),"Invalid food poison destination")
    item:getModData()[F.key]=dose>0 and {version=1,dose=dose,detection=item:getPoisonDetectionLevel()} or nil
    -- Native save пишет poisonPower как signed byte. Полная доза остаётся
    -- в modData, положительный маркер сохраняет обычное обнаружение яда.
    item:setPoisonPower(math.min(127,math.ceil(dose)))
end

function F.reconcile(item)
    if not F.active(item) then return end
    local taint=item:getModData()[F.taintKey]
    if not taint and item:isTainted() and not isClient() then
        F.setTainted(item);taint=item:getModData()[F.taintKey]
    end
    if taint then
        local contaminated=F.tainted(item)
        item:setTainted(contaminated)
        if not contaminated and not taint.cleared and not isClient() then
            -- Tombstone очищает также прежний true у уже открытого клиента.
            item:getModData()[F.taintKey]={version=1,cleared=true}
            F.sync(item)
        end
    end
    local saved=item:getModData()[F.key]
    -- Cooked/rotten replacement переносит condition:* без integer marker.
    -- Это производные поля; их можно восстановить и в клиентском tooltip.
    item:setPoisonPower(math.min(127,math.ceil(F.dose(item))))
    if saved and saved.detection~=nil then item:setPoisonDetectionLevel(saved.detection) end
    local quality=item:getModData()[F.qualityKey]
    if quality then
        qualityState(quality)
        -- Native cooked/rotten replacement может иметь другую шкалу сроков.
        -- Не переносить возраст исходного Food в миллиардолетнюю «консерву».
        if quality.state=="rotten" and not quality.offAgeMax and item:getOffAgeMax()>=1000000000 then
            quality={version=1,state="rotten",offAge=0,offAgeMax=1}
            if not isClient() then item:getModData()[F.qualityKey]=quality end
            item:setAge(1.001)
        elseif quality.state=="stale" and not quality.offAge and item:getOffAge()>=item:getOffAgeMax() then
            quality={version=1,state="stale",offAge=0}
            if not isClient() then item:getModData()[F.qualityKey]=quality end
        end
        if quality.offAge then item:setOffAge(quality.offAge) end
        if quality.offAgeMax then item:setOffAgeMax(quality.offAgeMax) end
        local floor=quality.state=="rotten" and item:getOffAgeMax()+.001 or item:getOffAge()+.0001
        item:setAge(math.max(item:getAge(),floor))
    end
end

function F.sync(item,character)
    if not isServer() then return end
    if item:getWorldItem() then
        HCRQualitySync.bump(item)
        item:getWorldItem():sendObjectChange(IsoObjectChange.SWAP_ITEM)
    elseif item:getContainer() then
        -- В syncItemFields отсутствуют baseHunger и пищевые значения Food.
        -- ItemStats обновляет существующий предмет, не меняя ссылки в руках.
        sendItemStats(item)
        HCRFluidQuality.sync(item,character)
    end
end

function F.fullSnapshot(item,character)
    if not isServer() then return end
    local container=item:getContainer()
    local owner=container and container:getCharacter()
    if owner and instanceof(owner,"IsoPlayer") then
        HCRQualitySync.bump(item)
        -- Новые outputs уже отправлены native handcraft ДО OnCreate.
        -- Полный упорядоченный пакет нужен также для age/offAge/offAgeMax.
        -- Не применять к существующему предмету в руках: native replacement
        -- обновляет очередь действий, но не ссылки primary/secondary hand.
        sendReplaceItemInContainer(container,item,item)
    else
        -- World и вложенные наземные сумки уже получают полный снимок.
        F.sync(item,character)
    end
end

local function resolve(name)
    if not name then return nil end
    local fn=_G
    for part in name:gmatch("[^.]+") do fn=fn and fn[part] end
    assert(type(fn)=="function","Missing previous Food.OnEat: "..name)
    return fn
end

function F.OnEat(item,character,fraction)
    if isClient() then return end
    local context=assert(contexts[item],"Food poison callback outside scoped Eat")
    assert(not context.called,"Repeated food poison callback")
    context.called=true
    -- Fraction уже учитывает native BaseHunger rebasing и последний кусок.
    context.remaining=context.dose*(1-fraction)
    -- UseAndSync вызывается сразу после OnEat и копирует condition:* в пустую
    -- посуду. Остаток нужно записать ДО него, иначе яд перейдёт в пустой сосуд.
    F.store(item,context.remaining)
    if fraction>=1 then
        item:getModData()[F.qualityKey]=nil
        item:getModData()[F.taintKey]=nil
    end
    HCRFluidEffects.poison(character,context.dose*fraction,context.carrier)
    if context.previous then context.previous(item,character,fraction) end
end

function F.eat(item,character,operation)
    if HCRMedicine then
        local native=operation
        operation=function() return HCRMedicine.eat(item,character,native) end
    end
    if isClient() or not F.active(item) then return operation() end
    F.reconcile(item)
    assert(not contexts[item],"Recursive Food Eat")
    local original=item:getOnEat()
    local context={dose=F.dose(item),previous=resolve(original),carrier=HCRFluidEffects.poisonCarrier()}
    context.remaining=context.dose
    contexts[item]=context
    item:setPoisonPower(0)
    item:setOnEat("HCRFoodQuality.OnEat")
    local ok,result=pcall(operation)
    contexts[item]=nil
    item:setOnEat(original)
    F.store(item,context.remaining)
    F.sync(item,character)
    if not ok then error(result) end
    return result
end

require "TimedActions/ISEatFoodAction"
for _,name in ipairs({"complete","eat"}) do
    local original=ISEatFoodAction[name]
    ISEatFoodAction[name]=function(self,...)
        local args={...}
        return F.eat(self.item,self.character,function() return original(self,unpack(args)) end)
    end
end

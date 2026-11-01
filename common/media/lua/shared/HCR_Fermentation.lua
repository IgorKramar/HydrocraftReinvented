-- План созревания не меняет исходную партию. Питание готового напитка
-- соответствует исходному HC, а качество и точная доза следуют за сырьём.
require 'HCR_FluidLedger'
require 'HCR_FermentationClock'
require 'HCR_FluidTransform'
HCRFermentation={}
local B,L,F=HCRFermentation,HCRFluidLedger,HCRFermentationClock
B.stages={
    ['Hydrocraft.HCBarrelgrape']={marker='HCRMustRed'},
    ['Hydrocraft.HCBarrelgrapegreen']={marker='HCRMustWhite'},
    ['Hydrocraft.HCBarrelhoney']={marker='HCRHoneyBrew'},
    ['Hydrocraft.HCBarrelrice']={marker='HCRRiceMash'},
    ['Hydrocraft.HCBarrelwine']={marker='HCRWineRed',target='Base.Wine2'},
    ['Hydrocraft.HCBarrelwinewhite']={marker='HCRWineWhite',target='Base.Wine'},
    ['Hydrocraft.HCBarrelmead']={marker='HCRMead',sourceFood='Hydrocraft.HCMead'},
    ['Hydrocraft.HCBarrelsake']={marker='HCRSake',sourceFood='Hydrocraft.HCSake'},
    ['Hydrocraft.HCBarrelvinegar']={marker='HCRVinegar'},
}
B.casks={['Hydrocraft.HCWoodenbarrelFluid']=true}
for kind,stage in pairs(HCRMashCatalog.stages) do B.stages[kind]=stage end
for kind,stage in pairs(HCRBreweryCatalog and HCRBreweryCatalog.stages or {}) do B.stages[kind]=stage end

function B.active(ledger)
    for _,lot in ipairs(ledger.lots) do if lot.fermentation then return true end end
    return false
end

-- При запуске сусла обычный срок порчи сока сменяется исходной выдержкой HC.
-- Уже достигнутая несвежесть остаётся; питание и дозы сырья не пересчитываются.
function B.start(ledger,kind,now,snapshot)
    L.validate(ledger)
    local stage=assert(B.stages[kind],'Missing fermentation start stage')
    local result=L.copy(ledger)
    for _,lot in ipairs(result.lots) do
        assert(not lot.fermentation,'Cannot restart an existing fermentation clock')
        local quality=L.quality({version=L.VERSION,lots={lot}})
        local stable=(snapshot or B.snapshot)(kind,quality)
        lot.age=stable.age or 0
        lot.food.age=lot.age;lot.food.offAge=stable.offAge;lot.food.offAgeMax=stable.offAgeMax
        lot.food.canBeFrozen=false;lot.food.frozen=false;lot.food.freezingTime=0
        -- units у свежего сока — реально израсходованная доля Food, а не литры.
        -- Новое основание даёт исходное питание вина на фактический литр.
        if lot.litres>0 then lot.basisLitres=lot.litres/lot.units end
        lot.fluid=stage.marker;lot.lastHour=now
        lot.fermentation=F.new(kind,now,now,true)
    end
    L.validate(result)
    return result
end

function B.plan(ledger,now,inBarrel,snapshot)
    L.validate(ledger)
    local result=L.copy(ledger)
    local changed=false
    for _,lot in ipairs(result.lots) do
        if lot.fermentation then
            local before=lot.fermentation
            assert(B.stages[before.kind].marker==lot.fluid,'Fermentation stage does not match its liquid')
            local clock,transition=F.advance(before,now,inBarrel)
            lot.fermentation=clock
            if transition then
                local stage=assert(B.stages[clock.kind],'Missing fermentation stage')
                if not stage.preserveNutrition then
                local quality=L.quality({version=L.VERSION,lots={lot}})
                local food=L.copy(snapshot(clock.kind,quality))
                -- basisLitres описывает исходную порцию, даже после многих
                -- переливаний. Нулевой native след также сохраняет свою дозу.
                food.poisonPower=(lot.food.poisonPower or 0)/lot.basisLitres
                food.poisonDetectionLevel=lot.food.poisonDetectionLevel or -1
                food.tainted=lot.food.tainted or false
                if stage.preserveBurnt then food.burnt=lot.food.burnt or false end
                lot.units=lot.units*lot.basisLitres
                lot.basisLitres=1
                lot.food=food;lot.age=food.age or 0;lot.lastHour=now
                end
                -- Созревшая брага ещё не является дистиллятом: сохраняем
                -- питание сырья до фактической перегонки, вместе с дозой.
                lot.fluid=stage.marker
                changed=true
            end
        end
    end
    L.validate(result)
    return result,changed
end

-- При смешивании резервируем место для всех стадий партий разного возраста.
-- Иначе восемь компонентов могут превратиться в девять без нового переливания.
function B.futureComponents(ledger,nativeNames)
    L.validate(ledger)
    local names={}
    for name in pairs(nativeNames or {}) do names[name]=true end
    for _,lot in ipairs(ledger.lots) do
        if lot.litres>0 then
            names[lot.fluid]=true
            local kind=lot.fermentation and lot.fermentation.kind
            while kind do
                names[assert(B.stages[kind],'Missing fermentation stage').marker]=true
                local rule=F.transition(kind)
                kind=rule and rule.target
            end
        end
    end
    local count=0
    for _ in pairs(names) do count=count+1 end
    return count,names
end

function B.waterComponents(source,depth)
    local names={}
    if not source then return {Water=true,TaintedWater=true} end
    assert((depth or 0)<8,'Unsupported external water chain')
    local fluid=source:getFluidContainer()
    if fluid then
        for _,part in ipairs(HCRFluidTransform.contents(fluid)) do names[part.name]=true end
    end
    local primary=source:getPrimaryFluid()
    if primary then names[primary:getFluidTypeString()]=true end
    if source:getUsesExternalWaterSource() then
        -- Водопровод может работать без собственного FC. При внешнем баке
        -- движок также превращает TaintedWater в Water, сохраняя прочие примеси.
        names.Water=true
        local external=source:FindExternalWaterSource()
        if external then
            for name in pairs(B.waterComponents(external,(depth or 0)+1)) do
                names[name=='TaintedWater' and 'Water' or name]=true
            end
        end
    end
    return names
end

function B.checkMixture(ledger,target,extra,incomingNames)
    if not B.active(ledger) then return true end
    local names={}
    for name in pairs(incomingNames or {}) do names[name]=true end
    for _,fluid in ipairs({target,extra}) do
        for _,part in ipairs(HCRFluidTransform.contents(fluid)) do names[part.name]=true end
    end
    local count,future=B.futureComponents(ledger,names)
    if count>8 then return false end
    local whitelist,blacklist=target:getWhitelist(),target:getBlacklist()
    for name in pairs(future) do
        local kind=assert(Fluid.Get(name),'Missing fermentation fluid: '..name)
        if (whitelist and not whitelist:allows(kind)) or (blacklist and not blacklist:allows(kind)) then return false end
        for other in pairs(future) do
            if not kind:canBlendWith(Fluid.Get(other)) then return false end
        end
    end
    return true
end

function B.refresh(item,fluid,ledger,now)
    if not B.active(ledger) then return ledger,false end
    local planned,changed=B.plan(ledger,now,B.casks[item:getFullType()] or false,B.snapshot)
    if changed then
        -- Сторонний мод может добавить несовместимую примесь мимо preflight.
        -- Не терять содержимое и оставить возможность опустошить такой сосуд.
        local ok=HCRFluidTransform.rewrite(fluid,ledger,planned)
        if not ok then return ledger,false end
        planned=L.alignVolumes(planned,HCRFluidQuality.amounts(fluid))
    end
    return planned,changed
end

function B.snapshot(kind,quality)
    require 'HCR_WineQuality'
    local stage=assert(B.stages[kind],'Missing fermentation stage')
    local W,E=HCRWineQuality,HCRFluidEffects
    if stage.nativeFluid then
        -- Новое пиво получает профиль B42 на один литр. B.plan масштабирует
        -- его по реальному объёму каждой партии, сохраняя дозы и худшую свежесть.
        local item=assert(instanceItem('Base.Pot'),'Missing beer sample vessel')
        local fluid=assert(HCRFluidQuality.fluid(item),'Missing beer sample fluid')
        fluid:Empty();fluid:addFluid(stage.nativeFluid,1)
        local food=W.snapshot(fluid,{quality='fresh',dose=0},1)
        food.offAge=stage.freshDays;food.offAgeMax=stage.rottenDays
        food.age=quality=='rotten' and stage.rottenDays or quality=='stale' and stage.freshDays or 0
        return food
    end
    if stage.target or stage.sourceFood then
        local fluid=stage.target and HCRFluidQuality.fluid(instanceItem(stage.target)) or nil
        return W.bottledSnapshot({sourceFood=stage.sourceFood,count=1},fluid,{quality=quality,dose=0})
    end
    local item=assert(instanceItem('Hydrocraft.HCRFluidSample'),'Missing fermentation sample')
    HCRFoodQuality.setQuality(item,quality)
    local food=E.snapshot(item)
    food.canBeFrozen=false
    return food
end

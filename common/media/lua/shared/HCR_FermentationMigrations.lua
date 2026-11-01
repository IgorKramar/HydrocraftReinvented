-- Старые Normal должны сначала загрузиться своим прежним Java-классом.
require 'HCR_Fermentation'
require 'HCR_ItemNames'
require 'HCR_ProcessQuality'
HCRFermentationMigrations={}
local M,B,Q,L,E=HCRFermentationMigrations,HCRFermentation,HCRFluidQuality,HCRFluidLedger,HCRFluidEffects
local buckets={['Hydrocraft.HCWoodenbucketgrape']='HCRJuiceGrape',
    ['Hydrocraft.HCWoodenbucketgrapegreen']='HCRJuiceGrapeWhite'}
local warned={}
function M.newReplacement(source,copyState)
    if not source or isClient() or (isServer() and source:isEquipped()) then return nil end
    local kind=source:getFullType()
    local stage=B.stages[kind];local bucket=buckets[kind]
    if not stage and not bucket and kind~='Hydrocraft.HCWoodenbarrel' then return nil end
    local ok,result=pcall(function()
        assert(not source:IsFood() and not source:IsDrainable() and not Q.fluid(source),'Changed legacy cask class')
        local target=assert(instanceItem(bucket and 'Hydrocraft.HCWoodenbucketFluid' or 'Hydrocraft.HCWoodenbarrelFluid'))
        local fluid=assert(Q.fluid(target),'Missing fermentation vessel')
        assert(fluid:isEmpty(),'Fermentation migration destination is not empty')
        local ledger=L.empty();local now=getGameTime():getWorldAgeHours()
        if stage or bucket then
            local state=HCRProcessQuality.read(source)
            local amount=bucket and 4 or 20
            local food=B.snapshot(stage and kind or 'Hydrocraft.HCBarrelvinegar',state.quality)
            -- Normal никогда не хранил калории сырья. Для готового вина
            -- сохраняем исходный выход20 бутылок, а не выдуманный снимок фруктов.
            local ready=stage and (stage.target or stage.sourceFood)
            food.poisonPower=state.dose/(ready and amount or 1)
            food.poisonDetectionLevel=state.detection or -1
            food.tainted=state.tainted or false
            local marker=bucket or stage.marker
            ledger=L.batch(marker,ready and 1 or amount,food,now)
            if ready then ledger.lots[1].litres=amount;ledger.lots[1].units=amount end
            if stage then
                local md=source:getModData()
                local start=md.HCRTimedStart or md.StartTime or now
                ledger.lots[1].fermentation=HCRFermentationClock.new(kind,start,start,true)
                ledger=B.plan(ledger,now,true,B.snapshot)
                marker=ledger.lots[1].fluid
            end
            E.prepare(ledger)
            assert(fluid:getCapacity()>=amount,'Fermentation migration capacity')
            fluid:addFluid(marker,amount)
            assert(math.abs(Q.rawAmount(fluid)-amount)<.00001,'Fermentation migration volume')
        end
        copyState(source,target)
        local md=target:getModData()
        md[HCRProcessQuality.key]=nil
        md[HCRFoodQuality.key]=nil;md[HCRFoodQuality.qualityKey]=nil
        md.HCRMigrationFrom=kind;md.HCRMigrationVersion='1.6.0'
        md.HCRDrinkMigration=true
        if source:isCustomName() then md.HCRLegacyCustomName=HCRItemNames.custom(source) end
        Q.store(target,fluid,L.alignVolumes(ledger,Q.amounts(fluid)))
        return target
    end)
    if ok then return result end
    local reason=kind..':'..tostring(result)
    if not warned[reason] then warned[reason]=true;print('[HydrocraftReinvented] Fermentation migration deferred: '..reason) end
    return nil
end

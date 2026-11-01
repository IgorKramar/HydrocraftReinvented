-- Снимок ДО native consumeInputsInternal: OnStart вызывается уже после расхода.
require "HCR_FluidQuality"
require "HCR_FluidRecipeRules"
require "HCR_NativeMilk"
require "HCR_MilkChainRules"
require "HCR_WineQuality"
require "HCR_AlcoholPortions"
require "HCR_BrewedDrinks"
require "HCR_BarDrinks"
require "HCR_SoftDrinks"
require "HCR_FermentationRecipes"
require "HCR_MethanolRules"
HCRFluidRecipeQuality={rules=HCRFluidRecipeRules or {}}
local R,Q,L=HCRFluidRecipeQuality,HCRFluidQuality,HCRFluidLedger
for name,rule in pairs(HCRMilkChainRules or {}) do R.rules[name]=rule end
for name,rule in pairs(HCRWineQuality and HCRWineQuality.rules or {}) do R.rules[name]=rule end
for name,rule in pairs(HCRAlcoholPortions and HCRAlcoholPortions.rules or {}) do R.rules[name]=rule end
for name,rule in pairs(HCRBrewedDrinkRules or {}) do
    if rule.inputs then R.rules[name]=rule end
end
if HCRNativeWhiskey then HCRNativeWhiskey.install(R.rules) end
for name,rule in pairs(HCRSpiritCatalog and HCRSpiritCatalog.consumers or {}) do R.rules[name]=rule end
local function mergeRules(rules)
for name,rule in pairs(rules) do
    local previous=R.rules[name] or {inputs={}}
    if not previous.inputs then
        local slots={}
        for slot in pairs(previous.slots) do slots[slot]=previous end
        previous={inputs=slots}
    end
    for slot,definition in pairs(rule.inputs) do previous.inputs[slot]=definition end
    R.rules[name]=previous
end
end
mergeRules(HCRBarCatalog and HCRBarCatalog.consumers or {})
mergeRules(HCRSoftDrinkCatalog and HCRSoftDrinkCatalog.consumers or {})
mergeRules(HCRCocktailCatalog and HCRCocktailCatalog.consumers or {})
mergeRules(HCRMilkCocktailCatalog and HCRMilkCocktailCatalog.consumers or {})
mergeRules(HCRFermentationRecipes and HCRFermentationRecipes.rules or {})
mergeRules(HCRMethanolRules or {})

-- Состав разрешён для конкретного входа. Milk/whisky в одном рецепте
-- нельзя объединять в общий whitelist или обрабатывать одним snapshot.
function R.slotRule(recipe,slot)
    local rule=R.rules[recipe:getName()]
    if not rule then return nil end
    if rule.inputs then return rule.inputs[slot] end
    return (slot==nil or rule.slots[slot]) and rule or nil
end

function R.allowed(recipe,slot,script)
    local rule=R.slotRule(recipe,slot)
    return rule and (script:isKeep() or rule.nativeSink) and script:hasConsumeFromItem()
        and not script:hasCreateToItem() and not script:isReplace()
        and not script:hasFlag(InputFlag.Unseal) and not script:hasFlag(InputFlag.InheritUsesAndEmpty)
end

function R.compatible(recipe,item,slot)
    local rule=R.slotRule(recipe,slot)
    local fluid=Q.fluid(item)
    if not rule or not fluid then return false end
    if rule.exact and math.abs(Q.rawAmount(fluid)-rule.exact)>.00001 then return false end
    -- Рецепт требует указанный сок; clean water допускает разбавление.
    -- Иначе mode:primary незаметно расходовал также алкоголь/химикаты,
    -- для которых fixed-output Food не имеет эквивалентных эффектов.
    local sample=fluid:createFluidSample()
    local compatible=true
    for index=0,sample:size()-1 do
        local kind=sample:getFluid(index)
        local allowed=kind==Fluid.Water and not rule.pure
        for _,name in ipairs(rule.fluids) do allowed=allowed or kind==Fluid.Get(name) end
        if not allowed then compatible=false;break end
    end
    sample:release()
    if compatible then
        -- Native мог округлить крошечную примесь до нулевого marker, но её
        -- сохранённая доза/алкоголь остаются в окружающей жидкости.
        for _,lot in ipairs(Q.capture(item,fluid).ledger.lots) do
            local allowed=false
            for _,name in ipairs(rule.fluids) do allowed=allowed or lot.fluid==name end
            if not allowed then return false end
            if rule.sourceTypes and not rule.sourceTypes[lot.food.sourceType] then return false end
            if rule.unfermented and lot.fermentation then return false end
        end
    end
    return compatible
end

function R.capture(data)
    local sources,seen={},{}
    local bar=HCRBarCatalog and HCRBarCatalog.products[data:getRecipe():getName()]
    local scripts=data:getRecipe():getInputs()
    for slot=0,scripts:size()-1 do
        local script=scripts:get(slot)
        if R.allowed(data:getRecipe(),slot,script) then
            -- canConsumeInputs уже заполнил applied; исходные selected lists
            -- нужны также при native queued-reservation prefix reset.
            local items=data:getInputItems(slot)
            if items then
                for i=0,items:size()-1 do
                    local item=items:get(i)
                    local fluid=Q.fluid(item)
                    local rule=R.slotRule(data:getRecipe(),slot)
                    -- Auto lists содержат также посторонние сосуды. Проверяем
                    -- native тип/состав без canUseItem, зависящего от reservation.
                    local candidate=fluid and (not (bar or rule.nativeWater) or
                        (script:isAcceptsAnyItem() or script:containsItem(item:getScriptItem()))
                        and script:getConsumeFromItemScript():isFluidMatch(fluid))
                    if not seen[item] and candidate and (Q.active(item,fluid) or rule.nativeMilk or rule.nativeWine or rule.nativeWater or bar) then
                        seen[item]=true
                        local before=Q.capture(item,fluid)
                        if (bar or rule.nativeWater) and not rule.nativeMilk and not rule.nativeWine then
                            local water=fluid:getSpecificFluidAmount(Fluid.Water)
                            if water>.000001 then
                                before.nativeWater=L.batch("Water",water,HCRBarDrinks.waterSnapshot(fluid),getGameTime():getWorldAgeHours())
                            end
                        end
                        if rule.nativeMilk then
                            local amount=before.amount-L.volume(before.ledger)
                            if amount>.000001 then
                                before.nativeMilk=L.batch("HCRMilk",amount,HCRNativeMilk.snapshot(fluid),getGameTime():getWorldAgeHours())
                            end
                        end
                        if rule.nativeWine then
                            local amount=before.amount-L.volume(before.ledger)
                            if amount>.000001 then
                                local food=HCRWineQuality.snapshot(fluid,{quality="fresh",dose=0},1)
                                before.nativeWine=L.batch(rule.nativeWine,amount,food,getGameTime():getWorldAgeHours())
                            end
                        end
                        sources[#sources+1]=before
                    end
                end
            end
        end
    end
    return sources
end

function R.finish(sources,character)
    local removed={}
    for _,before in ipairs(sources) do
        local after=Q.rawAmount(before.fluid)
        local amounts=Q.amounts(before.fluid)
        local fraction=before.amount>0 and math.max(0,math.min(1,(before.amount-after)/before.amount)) or 0
        local kept,used=L.withdrawNative(before.ledger,before.amounts,amounts,fraction)
        if #used.lots>0 then
            Q.store(before.item,before.fluid,kept)
            Q.sync(before.item,character)
            removed[#removed+1]=used
        end
        if before.nativeMilk and fraction>0 then
            local volume=L.volume(before.nativeMilk)
            local _,native=L.split(before.nativeMilk,volume*fraction,volume)
            if #native.lots>0 then removed[#removed+1]=native end
        end
        if before.nativeWine and fraction>0 then
            local volume=L.volume(before.nativeWine)
            local _,native=L.split(before.nativeWine,volume*fraction,volume)
            if #native.lots>0 then removed[#removed+1]=native end
        end
        if before.nativeWater and fraction>0 then
            local volume=L.volume(before.nativeWater)
            local _,native=L.split(before.nativeWater,volume*fraction,volume)
            if #native.lots>0 then removed[#removed+1]=native end
        end
    end
    return removed
end

function R.check(sources)
    local dose=0
    for _,before in ipairs(sources) do
        dose=dose+L.budget(before.ledger,"poisonPower")
    end
    return true,dose
end

function R.perform(data,character,operation,before)
    before=before or R.capture(data)
    local ok,result=pcall(operation)
    -- Даже частично исполненный native input расход не должен оставить
    -- прежний полный ledger в уже опустевшем сосуде при исключении.
    local removed=R.finish(before,character)
    if not ok then error(result) end
    return result,removed
end

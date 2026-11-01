require "HCR_DrinkFamilies"
require "HCR_ItemNames"
require "HCR_RetailDrinkFamilies"
require "HCR_DrinkProductFamilies"
require "HCR_MilkFamilies"
require "HCR_MashCatalog"
require "HCR_MashCooking"
require "HCR_WineFamilies"
require "HCR_BeerQuality"
require "HCR_SpiritCatalog"
require "HCR_BarCatalog"
require "HCR_CocktailCatalog"
require "HCR_MilkCocktailCatalog"
require "HCR_DrinkFluids"
HCRDrinkMigrations = {}
-- Только готовые ReplaceOnCooked ID; сырой Food остаётся на источнике тепла.
for kind,spec in pairs(HCRMashCatalog.families) do HCRDrinkFamilies[kind]=spec end
local M, Q, L, E = HCRDrinkMigrations, HCRFluidQuality, HCRFluidLedger, HCRFluidEffects
local warned = {}

-- Native Eat сохраняет собственный BaseHunger при уменьшении Food.
-- Сравнение с pristine-прототипом ломает блюда с изменённым исходным питанием.
function M.remaining(source,spec)
    local base, current = source:getBaseHunger(), source:getHungChange()
    if base==0 and current==0 and spec and spec.remaining=='native-zero-hunger-thirst' then
        -- У Agua Hunger=0. Food.getActualWeight использует именно этот
        -- знаменатель; native Eat уменьшает unmodified thirst при питье.
        base=source:getScriptItem():getThirstChange()/100
        current=source:getThirstChangeUnmodified()
        if type(base)~='number' or base>=0 then return nil end
    end
    if type(base) ~= "number" or type(current) ~= "number" or base == 0 then return nil end
    local fraction = current / base
    if fraction ~= fraction or fraction <= 0 or fraction > 1.000001 then return nil end
    return math.min(1, fraction)
end

function M.newReplacement(source, copyState)
    if not source or isClient() or (isServer() and source:isEquipped()) then return nil end
    local kind = source:getFullType()
    local spec = HCRDrinkFamilies[kind] or HCRMashCatalog.raw[kind]
    if not spec or not spec.enabled then return nil end
    if spec.cookedMash and not (source:isCooked() or source:isBurnt()) then return nil end
    local ok, result = pcall(function()
        assert(not Q.fluid(source), "Legacy drink has unexpected native contents")
        local amount,snapshot
        if spec.empty then
            assert(not source:IsFood() and not source:IsDrainable(),"Legacy empty vessel has unexpected type")
            amount=0
        elseif spec.normalStage then
            assert(not source:IsFood() and not source:IsDrainable(),"Legacy milk stage has unexpected type")
            amount=spec.litres
            -- Старые Normal stages не хранили Food поля: не выдумывать
            -- историческое питание, возраст или яд при переносе сохранения.
            snapshot=E.snapshot(instanceItem("Hydrocraft.HCRFluidSample"))
            snapshot.canBeFrozen=false
        elseif spec.unitLitres then
            assert(source:IsDrainable(),"Legacy concentrate has unexpected type")
            local uses=source:getCurrentUses()
            assert(uses>=0 and uses<=spec.legacyUses,"Invalid legacy concentrate uses")
            amount=uses*spec.unitLitres
            -- У старых концентратов не было Food-полей. Не придумывать питание,
            -- возраст или яд, которых загруженный Drainable никогда не хранил.
            snapshot=E.snapshot(instanceItem("Hydrocraft.HCRFluidSample"))
            snapshot.canBeFrozen=false
        else
            assert(source:IsFood(), "Legacy drink has unexpected type")
            local fraction=M.remaining(source,spec)
            if not fraction then
                -- Ожидаемая отсрочка не должна бросать Lua exception при
                -- каждом inventory tick: B42 пишет даже пойманный assert.
                local reason=kind..":unknown-remaining-portion"
                if not warned[reason] then
                    warned[reason]=true
                    print("[HydrocraftReinvented] Drink migration deferred: "..kind.." has an unknown remaining portion")
                end
                return nil
            end
            amount=spec.litres*fraction
            source:updateAge(false) -- Включая время выгруженного chunk.
            snapshot=spec.cookedMash and HCRMashCooking.snapshot(source,spec) or E.snapshot(source)
        end
        local target = assert(instanceItem(spec.target), "Missing drink vessel")
        local fluid = assert(Q.fluid(target), "Missing drink fluid component")
        assert(fluid:getCapacity() >= amount - .000001, "Drink exceeds vessel capacity")
        -- Многие vanilla factory IDs создаются уже наполненными/запечатанными.
        fluid:Empty()
        if amount>0 then fluid:addFluid(spec.fluid, amount) end
        local actual = Q.rawAmount(fluid)
        assert(math.abs(actual-amount) < math.max(.000001, amount*.000001), "Drink volume was rejected")
        copyState(source, target)
        local data = target:getModData()
        if HCRFoodQuality then
            data[HCRFoodQuality.key],data[HCRFoodQuality.qualityKey]=nil,nil
        end
        if source:isCustomName() then data.HCRLegacyCustomName = HCRItemNames.custom(source) end
        data.HCRMigrationFrom, data.HCRMigrationVersion = kind, "1.6.0"
        data.HCRDrinkMigration = true
        -- Snapshot описывает весь текущий остаток; units=1 не удваивает уже
        -- съеденную долю. Старые сроки/возраст/модификации сохраняются точно.
        Q.store(target, fluid, actual>0 and L.batch(spec.fluid, actual, snapshot, getGameTime():getWorldAgeHours()) or L.empty())
        if (spec.beer or spec.factoryDrink) and actual>0 then HCRBeerQuality.mark(target,source) end
        return target
    end)
    if ok then return result end
    local reason = kind .. ":" .. tostring(result)
    if not warned[reason] then
        warned[reason] = true
        print("[HydrocraftReinvented] Drink migration deferred: " .. reason)
    end
    return nil -- Исходный Food не расходуется и остаётся доступен.
end

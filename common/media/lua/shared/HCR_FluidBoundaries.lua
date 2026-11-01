require "HCR_FluidActions"
require "Farming/TimedActions/ISWaterPlantAction"
require "FeedingTrough/TimedActions/ISAddWaterToTrough"
require "TimedActions/Animals/ISGiveWaterToAnimal"
require "TimedActions/Animals/ISHutchCleanFloor"
require "TimedActions/Animals/ISMilkAnimal"
require "TimedActions/Animals/ISGatherBloodFromAnimal"
require "TimedActions/ISAddTakeDispenserBottle"
require "TimedActions/ISOpenCloseLid"
require "TimedActions/ISDrinkFromBottle"
require "Vehicles/TimedActions/ISWashVehicle"
require "TimedActions/ISWashClothing"
require "TimedActions/ISWashYourself"
require "TimedActions/ISCleanBandage"
require "TimedActions/ISDisinfect"
require "TimedActions/ISCleanBlood"
require "TimedActions/ISCleanGraffiti"
require "TimedActions/ISPutOutFire"
require "TimedActions/ISEmptyRainBarrelAction"
require "HCR_NativeWhiskey"

local A, Q = HCRFluidActions, HCRFluidQuality

-- These native actions store a scalar water value or replace an entity without
-- metadata. They cannot silently turn poisoned juice into safe animal water.
local function ordinary(item)
    return not Q.active(item, Q.fluid(item))
end

local function ordinaryObject(object)
    if object then
        return not Q.active(Q.item(object), object:getFluidContainer())
    end
    return true
end

A.guard(ISWaterPlantAction, {"update", "complete", "useItemOneUnit"}, function(self) return ordinary(self.item) end)
A.guard(ISGiveWaterToAnimal, {"update", "animEvent"}, function(self) return ordinary(self.item) end)
A.guard(ISAddWaterToTrough, {"updateAddingWater"}, function(self) return ordinary(self.itemFrom) end)
A.guard(ISGatherBloodFromAnimal, {"updateBucket"}, function(self) return ordinary(self.bucket) end)

A.guard(ISHutchCleanFloor, {"clean"}, function(self)
    local inv = self.character:getInventory()
    local water, bleach = self.water, self.bleach
    if not water or Q.fluid(water):isEmpty() then water = inv:getFirstWaterFluidSources(true, true) end
    if not bleach or Q.fluid(bleach):isEmpty() then bleach = inv:getFirstCleaningFluidSources() end
    return ordinary(water) and ordinary(bleach)
end)

A.guard(ISMilkAnimal, {"milk", "stress"}, function(self)
    if not ordinary(self.bucket) then return false end -- stress spills before automatic selection
    local bucket = self.bucket
    if not bucket or Q.fluid(bucket):isFull() or self.character:hasFullInventory() then
        local inv = self.character:getInventory()
        if self.all then bucket = inv:getFirstAvailableFluidContainer(self.animal:getData():getBreed():getMilkType()) end
        if bucket then
            local list = inv:getItemsFromFullType(bucket:getFullType())
            for index = 0, list:size()-1 do
                local candidate = list:get(index)
                if not Q.fluid(candidate):isFull() then bucket = candidate; break end
            end
        end
        return ordinary(bucket)
    end
    return true
end)

A.guard(ISAddTakeDispenserBottle, {"complete"}, function(self)
    return ordinary(self.bottle) and ordinaryObject(self.waterdispenser)
end)
A.guard(ISOpenCloseLid, {"complete"}, function(self) return ordinaryObject(self.barrel) end)

-- Legacy drink() hardcodes thirst relief, ignoring the fluid's properties.
-- HCR drinks use the modern ISDrinkFluidAction, already integrated with quality.
A.guard(ISDrinkFromBottle, {"drink"}, function(self) return ordinary(self.item) end)

A.guard(ISWashClothing, {"complete", "useSoap"}, function(self)
    if not ordinaryObject(self.sink) then return false end
    if self.soaps then
        for index=0,self.soaps:size()-1 do
            if not ordinary(self.soaps:get(index)) then return false end
        end
    end
    return true
end)
A.guard(ISWashYourself, {"complete"}, function(self) return ordinaryObject(self.sink) end)
A.guard(ISCleanBandage, {"complete"}, function(self) return ordinaryObject(self.waterObject) end)
A.guard(ISDisinfect,{"complete"},function(self)
    return ordinary(self.alcohol) or (HCRNativeWhiskey and HCRNativeWhiskey.medical(self.alcohol)) or false
end)
A.wrap(ISDisinfect,"complete",function(self,operation)
    if ordinary(self.alcohol) then return operation() end
    if not HCRNativeWhiskey or not HCRNativeWhiskey.medical(self.alcohol) then
        return A.refuse(self,"Unsupported disinfectant quality")
    end
    if isClient() then return A.refuse(self,"Disinfection quality requires server authority") end
    return Q.remove(self.alcohol,self.character,operation,false)
end)
A.guard(ISCleanBlood, {"complete"}, function(self) return ordinary(self.cleaner) end)
A.guard(ISCleanGraffiti, {"complete"}, function(self) return ordinary(self.cleaner) end)
A.guard(ISPutOutFire, {"useItem", "complete"}, function(self) return ordinary(self.item) end)
A.guard(ISWashVehicle, {"removeBlood", "useWater"}, function(self)
    local function check(container)
        local items=container:getItems()
        for index=0,items:size()-1 do
            local item=items:get(index)
            local fluid=Q.fluid(item)
            if fluid and fluid:getAmount()>=.1 and (fluid:contains(Fluid.Water) or fluid:contains(Fluid.TaintedWater))
                and not ordinary(item) then return false end
            if instanceof(item,"InventoryContainer") and not check(item:getItemContainer()) then return false end
        end
        return true
    end
    return check(self.character:getInventory())
end)

for _,method in ipairs({"serverStop","complete"}) do
    A.wrap(ISEmptyRainBarrelAction, method, function(self, operation)
        local item=Q.item(self.object)
        if item then return Q.remove(item,self.character,operation,false) end
        if not ordinaryObject(self.object) then return A.refuse(self, "Unsupported fixed liquid vessel") end
        return operation()
    end)
end

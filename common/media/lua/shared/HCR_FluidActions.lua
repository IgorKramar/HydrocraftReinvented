require "HCR_FluidQuality"
require "Fluids/ISFluidContainer"
require "Fluids/ISFluidTransferAction"
require "Fluids/ISFluidEmptyAction"
require "TimedActions/ISDrinkFluidAction"
require "TimedActions/ISTakeWaterAction"
require "TimedActions/ISAddFluidFromItemAction"
require "TimedActions/ISDumpWaterAction"

HCRFluidActions = {}
local A, Q = HCRFluidActions, HCRFluidQuality
local warned = {}

local function refuse(action, reason)
    if action.hcrFluidRefused then return false end
    action.hcrFluidRefused = true
    if not warned[tostring(reason)] then
        print("[HydrocraftReinvented] Liquid action refused: " .. tostring(reason))
        warned[tostring(reason)] = true
    end
    if action.action and action.forceStop then
        action:forceStop()
    elseif action.netAction then
        action.netAction:forceComplete()
    end
    if action.character then
        if isServer() then
            sendServerCommand(action.character, "HCRLiquids", "Refused", {})
        elseif HaloTextHelper then
            HaloTextHelper.addBadText(action.character, getText("IGUI_HCR_LiquidActionRefused"))
        end
    end
    return false
end

-- Guard the actual mutation, not only the UI's isValid or action completion.
-- Re-entrancy avoids accounting twice when complete calls a wrapped helper.
local function wrap(class, method, handler)
    local original = assert(class[method], "Missing native liquid action: " .. method)
    class[method] = function(self, ...)
        if self.hcrFluidRefused then return false end
        if isClient() or self.hcrFluidOperation then return original(self, ...) end
        local args = {...}
        self.hcrFluidOperation = true
        local ok, result = pcall(handler, self, function() return original(self, unpack(args)) end)
        self.hcrFluidOperation = nil
        if not ok then return refuse(self, result) end
        return result
    end
end

local function wrapValidation(class, check, serverProgress)
    local original = class.isValid
    class.isValid = function(self, ...)
        if self.hcrFluidRefused then return false end
        if not original(self, ...) then return false end
        -- B42 отправляет объём FC и modData разными пакетами. В ходе действия
        -- клиент временно видит новый объём со старой партией; это не повод
        -- прерывать питьё/переливание. Каждый реальный расход проверяет сервер.
        -- До старта сохраняем клиентский preflight; native isValid нужен всегда.
        if serverProgress and isClient() and self.isStarted and self:isStarted() then return true end
        local ok, result = pcall(check, self)
        return ok and result ~= false
    end
end

local function checkDrink(self)
    local fluid = Q.fluid(self.item)
    if Q.active(self.item, fluid) then
        local before = Q.capture(self.item, fluid)
        HCRFluidEffects.prepare(before.ledger)
    end
    return true
end

wrapValidation(ISDrinkFluidAction, checkDrink, true)
wrap(ISDrinkFluidAction, "updateEat", function(self, operation)
    return Q.remove(self.item, self.character, operation, true, self.useUtensil)
end)

wrapValidation(ISFluidTransferAction, function(self) return Q.checkTransfer(self.source, self.target) end, true)
for _, method in ipairs({"update", "complete"}) do
    wrap(ISFluidTransferAction, method, function(self, operation)
        return Q.transfer(self.source, self.target, self.character, operation)
    end)
end

for _, method in ipairs({"updateEmpty", "complete"}) do
    wrap(ISFluidEmptyAction, method, function(self, operation)
        local item = Q.item(self.container:getOwner())
        if not item then
            assert(not Q.active(nil, self.container:getFluidContainer()), "Untracked machine quality")
            return operation()
        end
        return Q.remove(item, self.character, operation, false)
    end)
end
for _, method in ipairs({"updateDumpingWater", "complete"}) do
    wrap(ISDumpWaterAction, method, function(self, operation)
        return Q.remove(self.item, self.character, operation, false)
    end)
end

wrap(ISTakeWaterAction, "transferFluid", function(self, operation)
    local source = Q.item(self.waterObject)
    local sourceFluid = self.waterObject:getFluidContainer()
    if Q.active(source, sourceFluid) then
        assert(source, "Tracked fluid has no portable source")
        if self.item then
            return Q.transfer(ISFluidContainer:new(sourceFluid), ISFluidContainer:new(Q.fluid(self.item)),
                self.character, operation)
        end
        return Q.remove(source, self.character, operation, true, false)
    end
    if self.item then return Q.addNative(self.item, self.character, operation, sourceFluid, self.waterObject) end
    return operation()
end)

local function addFromItem(self, operation)
    local sourceFluid, targetFluid = Q.fluid(self.itemFrom), self.objectTo:getFluidContainer()
    if not Q.active(self.itemFrom, sourceFluid) and not Q.active(Q.item(self.objectTo), targetFluid) then
        return Q.nativeOnly(self.character,operation,self.itemFrom,Q.item(self.objectTo))
    end
    assert(targetFluid and Q.item(self.objectTo), "Tracked drinks require a portable destination")
    return Q.transfer(ISFluidContainer:new(sourceFluid), ISFluidContainer:new(targetFluid),
        self.character, operation)
end
wrap(ISAddFluidFromItemAction, "updateAdd", addFromItem)
wrap(ISAddFluidFromItemAction, "complete", addFromItem)
wrapValidation(ISAddFluidFromItemAction, function(self)
    local sourceFluid, targetFluid = Q.fluid(self.itemFrom), self.objectTo:getFluidContainer()
    if not Q.active(self.itemFrom, sourceFluid) and not Q.active(Q.item(self.objectTo), targetFluid) then return true end
    assert(targetFluid and Q.item(self.objectTo), "Tracked drinks require a portable destination")
    return Q.checkTransfer(ISFluidContainer:new(sourceFluid), ISFluidContainer:new(targetFluid))
end)

-- Java autoDrink bypasses timed actions. HCR transport types are not in the
-- Water category; this additional guard also rejects malformed quality on water.
Hook.AutoDrink.Add(function(character)
    local source = character:getWaterSource(character:getInventory():getItems())
    if source and Q.active(source, Q.fluid(source)) then return true end
    return false
end)

if Events.OnServerCommand then
    Events.OnServerCommand.Add(function(module, command)
        if module == "HCRLiquids" and command == "Refused" and HaloTextHelper then
            local player = getSpecificPlayer(0)
            if player then HaloTextHelper.addBadText(player, getText("IGUI_HCR_LiquidActionRefused")) end
        end
    end)
end

A.wrap = wrap -- shared registration for additional reviewed native sinks
A.refuse = refuse

-- Some legacy actions also mutate on the client. A preflight guard runs on
-- both sides and before every entry point, including nested calls from stop().
function A.guard(class, methods, check)
    wrapValidation(class, check)
    for _, method in ipairs(methods) do
        local original = assert(class[method], "Missing guarded action: "..method)
        class[method] = function(self, ...)
            if self.hcrFluidRefused then return false end
            local ok, result = pcall(check, self)
            if not ok or result == false then return refuse(self, result) end
            return original(self, ...)
        end
    end
end

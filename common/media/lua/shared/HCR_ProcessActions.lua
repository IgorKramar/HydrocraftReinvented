-- Native объединение Drainable округляет обе стороны независимо. Для
-- пищевых партий переносим целые uses и их точную дозу одновременно.
require "HCR_ProcessQuality"
require "HCR_FluidActions"
require "TimedActions/ISConsolidateDrainable"
HCRProcessActions={}
local A,P,F=HCRProcessActions,HCRProcessQuality,HCRFoodQuality

local function tracked(item)
    return item and P.carrier(item) and item:getModData()[P.key]~=nil
end
function A.active(action)
    return action.hcrProcessMix or tracked(action.drainable) or tracked(action.intoItem)
end

function A.advance(action,progress)
    assert(not isClient(),"Process consolidation belongs to server")
    local source,target=action.drainable,action.intoItem
    assert(source and target and source~=target and source:getFullType()==target:getFullType()
        and source:IsDrainable() and target:IsDrainable(),"Incompatible process consolidation")
    local mix=action.hcrProcessMix
    if not mix then
        local delta=source:getUseDelta()
        assert(delta>0 and math.abs(delta-target:getUseDelta())<.000001,"Different process portion sizes")
        local a,b=source:getCurrentUses(),target:getCurrentUses()
        assert(a>0 and math.abs(a*delta-action.fromStart)<.00001
            and math.abs(b*delta-action.intoStart)<.00001,"Process contents changed while queued")
        local left,right=P.read(source),P.read(target)
        assert(left.dose+right.dose<=F.maxDose,"Process mixture poison limit")
        local capacity=math.floor(1/delta+.5)
        assert(b>=0 and b<=capacity and a<=capacity,"Invalid process uses")
        mix={source=source,target=target,from=a,into=b,moved=0,
            amount=math.min(a,capacity-b),left=left,right=right}
        action.hcrProcessMix=mix
    end
    assert(source==mix.source and target==mix.target
        and source:getCurrentUses()==mix.from-mix.moved
        and target:getCurrentUses()==mix.into+mix.moved,"Process contents changed during transfer")
    assert(type(progress)=="number" and progress==progress,"Invalid process transfer progress")
    local moved=math.max(mix.moved,math.floor(mix.amount*math.max(0,math.min(1,progress))+.000001))
    if moved==mix.moved then return end
    local fraction=moved/mix.from
    local state={dose=mix.right.dose+mix.left.dose*fraction,
        quality=F.worst(mix.left.quality,mix.right.quality),
        detection=math.max(mix.left.detection or -1,mix.right.detection or -1),
        poisoner=mix.right.poisoner or mix.left.poisoner,clocks={}}
    state.tainted=mix.left.tainted or (mix.into>0 and mix.right.tainted) or false
    if mix.left.clock then state.clocks[#state.clocks+1]=mix.left.clock end
    if mix.right.clock then state.clocks[#state.clocks+1]=mix.right.clock end
    -- Все проверки выполнены до первой записи. Один transferred use даёт
    -- ровно один use приёмнику, независимо от округления анимации B42.
    source:setCurrentUses(mix.from-moved);target:setCurrentUses(mix.into+moved)
    P.keep(source,mix.left,1-fraction,action.character)
    P.write(target,state,1,action.character)
    mix.moved=moved
end

HCRFluidActions.wrap(ISConsolidateDrainable,"update",function(self,operation)
    if not A.active(self) then return operation() end
    local progress=isServer() and self.netAction:getProgress() or self:getJobDelta()
    A.advance(self,progress)
    if not isServer() then
        self.drainable:setJobDelta(progress);self.intoItem:setJobDelta(progress)
    end
end)
HCRFluidActions.wrap(ISConsolidateDrainable,"complete",function(self,operation)
    if A.active(self) then A.advance(self,1) end
    return operation()
end)

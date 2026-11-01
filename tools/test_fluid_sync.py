"""Свежее состояние сервера сохраняет ссылки и не затирает новый native refill."""
import unittest
import test_quality_sync
from lupa.lua51 import LuaRuntime


class FluidSync(unittest.TestCase):
    def setUp(self):
        test_quality_sync.QualitySync.setUp(self)
        self.lua.execute('''
            local L=HCRFluidLedger
            FluidCategory={Beverage='Beverage',Colors='Colors'}
            Fluid={};local kinds={}
            function Fluid.Get(name)
                if not kinds[name] then kinds[name]={getFluidTypeString=function() return name end,
                    isCategory=function(_,category) return category==(name=='Dye' and 'Colors' or 'Beverage') end} end
                return kinds[name]
            end
            function fluid(parts,capacity)
                local f={parts=L.copy(parts or {}),capacity=capacity or 2,locked=false,empty=true,rain=.1,name='Bucket'}
                function f:raw() local n=0;for _,v in pairs(self.parts) do n=n+v end;return n end
                function f:getAmount() local n=self:raw();return math.abs(n-self.capacity)<.001 and self.capacity or n end
                function f:createFluidSample()
                    local rows,seen={},{}
                    for _,name in ipairs(self.order or {}) do
                        if self.parts[name] then rows[#rows+1]=name;seen[name]=true end
                    end
                    local tail={};for name in pairs(self.parts) do if not seen[name] then tail[#tail+1]=name end end
                    table.sort(tail);for _,name in ipairs(tail) do rows[#rows+1]=name end
                    return {getAmount=function() return self:raw() end,size=function() return #rows end,
                        getFluid=function(_,i) return Fluid.Get(rows[i+1]) end,release=function() end}
                end
                function f:getSpecificFluidAmount(kind) return self.parts[kind:getFluidTypeString()] or 0 end
                function f:getCapacity() return self.capacity end
                function f:setCapacity(n) self.capacity=n end
                function f:isInputLocked() return self.locked end
                function f:setInputLocked(v) self.locked=v end
                function f:canPlayerEmpty() return self.empty end
                function f:setCanPlayerEmpty(v) self.empty=v end
                function f:getRainCatcher() return self.rain end
                function f:setRainCatcher(v) self.rain=v end
                function f:getContainerName() return self.name end
                function f:setContainerName(v) self.name=v end
                function f:Empty() self.parts={};self.order={} end
                function f:addFluid(name,litres)
                    if self.reject==name or self.locked or not self.empty or self:getAmount()>=self.capacity-.0001 then return end
                    if not self.parts[name] then self.order=self.order or {};self.order[#self.order+1]=name end
                    self.parts[name]=(self.parts[name] or 0)+math.min(litres,self.capacity-self:getAmount())
                end
                return f
            end
            HCRFluidQuality.transport={HCRMilk=true}
            HCRFluidQuality.rawAmount=function(f) return f and f:raw() or 0 end
            HCRFluidQuality.amounts=function(f)
                local out={};if f and (f.parts.HCRMilk or 0)>0 then out.HCRMilk=f.parts.HCRMilk end;return out
            end
            function target:IsFood() return false end
            target.fluid=fluid({HCRMilk=1})
            serverTarget=item(12);serverTarget.container=inner.inside
            function serverTarget:IsFood() return false end
            serverTarget.fluid=fluid({HCRMilk=1});serverTarget.data=L.copy(target.data)
            local resolve=HCRQualitySync.resolve
            HCRQualitySync.resolve=function(a) if not client and a.id==12 then return serverTarget end;return resolve(a) end
            function getPlayer() return owner end
            requests={}
            function sendClientCommand(p,m,c,args) requests[#requests+1]=L.copy(args) end
            function hint()
                client=false;assert(HCRFluidSync.notify(serverTarget));local a=sent[#sent].args
                client=true;HCRFluidSync.changed(a);return a
            end
            function response()
                local req=requests[#requests];assert(req,'Missing snapshot request')
                client=false;HCRFluidSync.serve(owner,req);local a=sent[#sent].args
                assert(a.nonce==req.nonce,'Server did not return the requested snapshot');client=true;return a
            end
            function deliver() local a=response();HCRFluidSync.receive(a);return a end
        ''')
        self.lua.execute((test_quality_sync.SHARED/'HCR_FluidSync.lua').read_text(encoding='utf-8'))

    def test_notification_requests_fresh_state_and_preserves_all_references(self):
        self.lua.execute('''
            local L=HCRFluidLedger
            serverTarget.fluid.parts={HCRMilk=.75,Water=.25}
            local _,portion=L.split(batch(.8),.75,1);serverTarget.data.HCRFluidQuality=portion
            serverTarget.fluid.locked=true;serverTarget.fluid.empty=false;serverTarget.fluid.rain=0
            target.data.otherMod='keep'
            local refs={outer,outer.inside,inner,inner.inside,target,target.fluid}
            hint();assert(target.fluid.parts.HCRMilk==1,'Hint must not apply cached contents')
            deliver()
            assert(target.fluid.parts.HCRMilk==.75 and target.fluid.parts.Water==.25)
            assert(target.data.HCRFluidQuality.lots[1].food.poisonPower==.8)
            assert(math.abs(L.budget(target.data.HCRFluidQuality,'poisonPower')-.6)<1e-9)
            assert(target.fluid.locked and not target.fluid.empty and target.fluid.rain==0)
            assert(target.data.otherMod=='keep')
            assert(outer==refs[1] and outer.inside==refs[2] and inner==refs[3] and inner.inside==refs[4]
                and target==refs[5] and target.fluid==refs[6])
        ''')

    def test_late_native_packet_requests_current_server_state_never_replays_milk(self):
        self.lua.execute('''
            hint();deliver()
            -- После tracked молока сервер уже принял штатный refill водой.
            serverTarget.fluid.parts={Water=1.7};serverTarget.data.HCRFluidQuality=nil
            serverTarget.fluid.rain=.3
            -- Старый native пакет на клиенте: прежние .4 л, та же revision.
            target.fluid.parts={HCRMilk=.4}
            now=500;HCRFluidSync.reconcile()
            assert(target.fluid.parts.HCRMilk==.4 and #requests==2)
            deliver()
            assert(target.fluid.parts.Water==1.7 and not target.fluid.parts.HCRMilk)
            assert(not target.data.HCRFluidQuality and target.fluid.rain==.3)
        ''')

    def test_native_change_during_request_rejects_stale_response_and_old_nonce(self):
        self.lua.execute('''
            hint();local stale=response()
            target.fluid.parts={Water=.6};serverTarget.fluid.parts={Water=.6};serverTarget.data.HCRFluidQuality=nil
            now=500;HCRFluidSync.receive(stale)
            assert(target.fluid.parts.Water==.6 and #requests==2)
            HCRFluidSync.receive(stale);assert(target.fluid.parts.Water==.6)
            deliver();assert(target.fluid.parts.Water==.6 and not target.data.HCRFluidQuality)
        ''')

    def test_new_hint_and_replaced_identity_invalidate_pending_response(self):
        self.lua.execute('''
            hint();local first=response();now=500;hint();local newer=response()
            HCRFluidSync.receive(first);assert(not target.data.HCRQualityRevision160)
            local old=target
            target=item(12);target.container=inner.inside;target.fluid=fluid({Water=.5});inner.rows[1]=target
            function target:IsFood() return false end
            now=1000;HCRFluidSync.receive(newer)
            assert(target.fluid.parts.Water==.5 and not target.data.HCRQualityRevision160)
            deliver();assert(target.fluid.parts.HCRMilk==1 and old.fluid.parts.HCRMilk==1)
        ''')

    def test_empty_snapshot_clears_owned_metadata_without_touching_other_mod(self):
        self.lua.execute('''
            target.data.HCRProcessQuality160={quality='rotten'}
            target.data.HCRBeerFactory160=true;target.data.HCRFluidRainCatcher=.2;target.data.other=4
            serverTarget.fluid.parts={};serverTarget.data={};serverTarget.fluid.rain=.2
            hint();deliver()
            assert(target.fluid:raw()==0 and target.fluid.rain==.2)
            assert(not target.data.HCRFluidQuality and not target.data.HCRProcessQuality160)
            assert(not target.data.HCRBeerFactory160 and not target.data.HCRFluidRainCatcher and target.data.other==4)
        ''')

    def test_near_full_trace_components_survive_native_full_rounding(self):
        self.lua.execute('''
            serverTarget.fluid=fluid({HCRMilk=.9997,Water=.0003},1)
            local _,portion=HCRFluidLedger.split(batch(.5),.9997,1);serverTarget.data.HCRFluidQuality=portion
            hint();deliver()
            assert(math.abs(target.fluid.parts.HCRMilk-.9997)<1e-9)
            assert(math.abs(target.fluid.parts.Water-.0003)<1e-9 and target.fluid.capacity==1)
        ''')

    def test_unsupported_private_or_distant_requests_use_no_numeric_transport(self):
        self.lua.execute('''
            serverTarget.fluid=fluid({Dye=1})
            assert(not HCRFluidSync.notify(serverTarget) and #sent==0)
            serverTarget.fluid=fluid({Water=1});hint()
            local request=requests[1];local count=#sent
            client=false;HCRFluidSync.serve(far,request);assert(#sent==count)
            request.address.location='player';HCRFluidSync.serve(owner,request);assert(#sent==count)
            outer.world=nil;local c=container({outer});c.owner=owner;outer.container=c
            assert(not HCRFluidSync.notify(serverTarget))
        ''')

    def test_rejected_component_rolls_back_contents_and_metadata(self):
        self.lua.execute('''
            target.fluid=fluid({Water=.4});target.data={other=1}
            target.fluid.reject='HCRMilk'
            hint();local a=response()
            local ok=pcall(HCRFluidSync.apply,target,a);assert(not ok)
            assert(target.fluid.parts.Water==.4 and not target.fluid.parts.HCRMilk)
            assert(target.data.other==1 and not target.data.HCRQualityRevision160)
        ''')

    def test_equal_volume_preserves_native_primary_fluid_insertion_order(self):
        self.lua.execute('''
            serverTarget.fluid=fluid({Water=.5,HCRMilk=.5},1)
            serverTarget.fluid.order={'Water','HCRMilk'}
            local _,portion=HCRFluidLedger.split(batch(.5),.5,1);serverTarget.data.HCRFluidQuality=portion
            hint();deliver()
            local packed=HCRFluidSync.pack(target.fluid)
            assert(packed.parts[1].name=='Water' and packed.parts[2].name=='HCRMilk')
        ''')

    def test_slow_response_keeps_nonce_valid_on_retry(self):
        self.lua.execute('''
            hint();local first=requests[1].nonce;local delayed=response()
            now=2000;HCRFluidSync.reconcile()
            assert(#requests==2 and requests[2].nonce==first)
            HCRFluidSync.receive(delayed)
            assert(target.data.HCRQualityRevision160==delayed.revision)
        ''')

    def test_vehicle_request_uses_actual_position_not_claimed_nearby_square(self):
        self.lua.execute('''
            hint();local req=requests[1];local count=#sent
            req.address.location='vehicle';req.address.vehicle=7;req.address.part='TruckBed'
            local actual=HCRFluidLedger.copy(req.address);actual.x=1000
            HCRQualitySync.address=function() return actual end
            client=false;HCRFluidSync.serve(owner,req);assert(#sent==count)
            actual.x=11;now=500;HCRFluidSync.serve(owner,req)
            assert(#sent==count+1 and sent[#sent].args.nonce==req.nonce)
        ''')


class NativeOnlySync(unittest.TestCase):
    def setUp(self):
        self.lua=LuaRuntime(unpack_returned_tuples=True)
        self.lua.execute('''
            function require() end
            HCRQualitySync={key='revision'}
            HCRFluidLedger={}
        ''')
        self.lua.execute((test_quality_sync.SHARED/'HCR_FluidQuality.lua').read_text(encoding='utf-8'))
        self.lua.execute('''
            Q=HCRFluidQuality
            Q.active=function() return false end;Q.fluid=function() return {} end
            calls={};Q.sync=function(item) calls[#calls+1]=item end
            known={getModData=function() return {revision=4} end}
            ordinary={getModData=function() return {} end}
        ''')

    def test_empty_vessel_native_refill_is_replicated_without_food_restrictions(self):
        self.lua.execute('''
            assert(Q.addNative(known,nil,function() return 'filled' end)=='filled')
            assert(#calls==1 and calls[1]==known)
            Q.nativeOnly(nil,function() end,nil,known,ordinary)
            assert(#calls==2 and calls[2]==known)
        ''')

    def test_native_partial_error_still_publishes_changed_known_vessel(self):
        self.lua.execute('''
            local ok=pcall(Q.remove,known,nil,function() error('after native partial change') end,false)
            assert(not ok and #calls==1 and calls[1]==known)
            Q.addNative(ordinary,nil,function() end);assert(#calls==1)
        ''')


if __name__=='__main__':
    unittest.main()

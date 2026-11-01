"""Задержки сети не заменяют сумку и не откатывают уже увиденную новую партию."""
import unittest
from pathlib import Path
from lupa.lua51 import LuaRuntime

SHARED=Path(__file__).resolve().parents[1]/'common/media/lua/shared'


class QualitySync(unittest.TestCase):
    def setUp(self):
        self.lua=LuaRuntime(unpack_returned_tuples=True)
        self.lua.globals().package.path = str(SHARED.as_posix()) + '/?.lua;' + self.lua.globals().package.path
        self.lua.execute((SHARED/'HCR_FluidLedger.lua').read_text(encoding='utf-8'))
        self.lua.execute('''
            function require() end
            function isClient() return client end
            function isServer() return not client end
            function instanceof(item,kind) return item and item.class==kind end
            now=100;function getTimestampMs() return now end
            Events={OnTick={Add=function() end},OnContainerUpdate={Add=function() end},OnServerCommand={Add=function() end}}
            function list(rows) return {size=function() return #rows end,get=function(_,n) return rows[n+1] end} end
            function container(rows,bag)
                return {getItems=function() return list(rows) end,getContainingItem=function() return bag end,
                    getCharacter=function(self) return self.owner end,getVehiclePart=function(self) return self.part end,
                    getParent=function(self) return self.parent end,getSourceGrid=function() return square end}
            end
            function item(id,kind,bag)
                local i={id=id,kind=kind or 'Base.Pot',data={},class=bag and 'InventoryContainer' or 'InventoryItem'}
                function i:getID() return self.id end
                function i:getFullType() return self.kind end
                function i:getContainer() return self.container end
                function i:getWorldItem() return self.world end
                function i:getModData() return self.data end
                if bag then i.rows={};i.inside=container(i.rows,i);function i:getItemContainer() return self.inside end end
                return i
            end
            function add(c,i,rows) rows[#rows+1]=i;i.container=c end
            worldRows={};objects={}
            square={getX=function() return 10 end,getY=function() return 20 end,getZ=function() return 0 end,
                getWorldObjects=function() return list(worldRows) end,getObjects=function() return list(objects) end}
            function getCell() return {getGridSquare=function(_,x,y,z)
                if loaded~=false and x==10 and y==20 and z==0 then return square end end} end
            outer=item(10,'Base.Bag_Schoolbag',true)
            outer.world={getSquare=function() return square end,getItem=function() return outer end}
            worldRows[1]=outer.world
            inner=item(11,'Base.Bag_Schoolbag',true);add(outer.inside,inner,outer.rows)
            target=item(12);target.fluid={amount=1,amounts={HCRMilk=1}};add(inner.inside,target,inner.rows)
            function batch(dose) return HCRFluidLedger.batch('HCRMilk',1,{calories=100,poisonPower=dose,offAge=2,offAgeMax=4},0) end
            target.data.HCRFluidQuality=batch(.25)
            HCRFluidQuality={key='HCRFluidQuality',fluid=function(i) return i.fluid end,
                rawAmount=function(f) return f and f.amount or 0 end,amounts=function(f) return f and f.amounts or {} end}
            HCRProcessQuality={key='HCRProcessQuality160'}
            function player(id,x)
                return {class='IsoPlayer',getOnlineID=function() return id end,getX=function() return x end,
                    getY=function() return 20 end,getInventory=function(self) return self.inv end}
            end
            owner=player(1,10);observer=player(2,11);far=player(3,1000)
            function getOnlinePlayers() return list({owner,observer,far}) end
            function getNumActivePlayers() return 1 end
            function getSpecificPlayer() return owner end
            sent={};function sendServerCommand(p,module,command,args) sent[#sent+1]={player=p,args=HCRFluidLedger.copy(args)} end
        ''')
        self.lua.execute((SHARED/'HCR_QualitySync.lua').read_text(encoding='utf-8'))

    def test_storage_patch_preserves_nested_bag_item_and_fluid_references(self):
        self.lua.execute('''
            local references={outer,outer.inside,inner,inner.inside,target,target.fluid}
            target.data.HCRFluidQuality=batch(.5)
            assert(HCRQualitySync.send(target));assert(#sent==2)
            args=sent[1].args;assert(args.revision==1)
            assert(args.address.root==10 and args.address.path[1]==11 and args.address.path[2]==12)
            client=true;target.data={otherMod='kept',HCRFluidQuality=batch(.25)}
            HCRQualitySync.receive(args)
            assert(target.data.HCRFluidQuality.lots[1].food.poisonPower==.5)
            assert(target.data.otherMod=='kept')
            assert(outer==references[1] and outer.inside==references[2] and inner==references[3]
                and inner.inside==references[4] and target==references[5] and target.fluid==references[6])
        ''')

    def test_add_ordering_and_late_old_snapshot_reapply_without_creating_items(self):
        self.lua.execute('''
            HCRQualitySync.send(target);args=sent[1].args
            client=true;inner.rows[1]=nil;target.data={}
            HCRQualitySync.receive(args);assert(#inner.rows==0)
            inner.rows[1]=target;HCRQualitySync.reconcile()
            assert(target.data.HCRQualityRevision160==1)
            target.data={};HCRQualitySync.reconcile()
            assert(target.data.HCRQualityRevision160==1 and #inner.rows==1)
        ''')

    def test_observed_newer_mutation_permanently_retires_older_patch(self):
        self.lua.execute('''
            target.data.HCRQualityRevision160=4;HCRQualitySync.send(target);args=sent[1].args
            client=true;target.data={};HCRQualitySync.receive(args)
            target.data={HCRQualityRevision160=6,HCRFluidQuality=batch(.9)}
            HCRQualitySync.reconcile()
            target.data={HCRQualityRevision160=4,HCRFluidQuality=batch(.1)}
            HCRQualitySync.reconcile();HCRQualitySync.receive(args)
            assert(target.data.HCRQualityRevision160==4)
            assert(target.data.HCRFluidQuality.lots[1].food.poisonPower==.1)
        ''')

    def test_mismatched_volume_defers_and_exact_path_does_not_search_other_bags(self):
        self.lua.execute('''
            HCRQualitySync.send(target);args=sent[1].args
            client=true;target.data={};target.fluid.amount=.5
            HCRQualitySync.receive(args);assert(not target.data.HCRFluidQuality)
            assert(target.fluid.amount==.5)
            target.fluid.amount=1;inner.rows[1]=nil;outer.rows[2]=target
            HCRQualitySync.reconcile();assert(not target.data.HCRFluidQuality)
            outer.rows[2]=nil;inner.rows[1]=target;HCRQualitySync.reconcile()
            assert(target.data.HCRFluidQuality)
        ''')

    def test_absent_keys_are_removed_and_expired_or_unloaded_patches_do_not_apply(self):
        self.lua.execute('''
            target.fluid=nil;target.data={};HCRQualitySync.send(target);args=sent[1].args
            client=true;target.data={HCRProcessQuality160={old=true},HCRFluidRainCatcher=.1}
            HCRQualitySync.receive(args)
            assert(not target.data.HCRProcessQuality160 and not target.data.HCRFluidRainCatcher)
            now=30101;target.data={};HCRQualitySync.reconcile();assert(not target.data.HCRQualityRevision160)
            loaded=false;HCRQualitySync.receive(args);loaded=true;HCRQualitySync.reconcile()
            assert(not target.data.HCRQualityRevision160)
        ''')

    def test_player_furniture_vehicle_and_direct_world_routes_are_exact(self):
        self.lua.execute('''
            local S=HCRQualitySync
            assert(S.resolve(S.address(outer))==outer)
            outer.world=nil;local rows={outer};local root=container(rows,nil);outer.container=root
            root.owner=owner;owner.inv=root;local a=S.address(target)
            assert(a.location=='player' and S.resolve(a)==target)
            S.send(target);assert(#sent==1 and sent[1].player==owner)
            root.owner=nil
            local object={getObjectIndex=function() return 0 end,getContainerCount=function() return 1 end,
                getContainerByIndex=function() return root end}
            objects[1]=object;root.parent=object;a=S.address(target)
            assert(a.location=='container' and S.resolve(a)==target)
            local vehicle={getId=function() return 7 end,getPartById=function() return root.part end}
            root.part={getVehicle=function() return vehicle end,getId=function() return 'TruckBed' end,getItemContainer=function() return root end}
            function getVehicleById(id) if id==7 then return vehicle end end
            a=S.address(target);assert(a.location=='vehicle' and S.resolve(a)==target)
            target.kind='Base.Other';assert(not S.resolve(a))
        ''')


if __name__=='__main__':
    unittest.main()

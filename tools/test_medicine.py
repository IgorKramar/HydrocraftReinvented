"""Лекарство из старого сохранения: остаток дозы, одно исправление и native класс."""
import unittest
from lupa.lua51 import LuaRuntime
from hcr_paths import LUA,SCRIPTS,read_text
from apply_playability_fixes import blocks
from build_water_catalog import props


class Medicine(unittest.TestCase):
    def setUp(self):
        self.lua=LuaRuntime(unpack_returned_tuples=True)
        self.lua.execute('''
            function isClient() return client or false end
            function item(effect,fraction)
                local obj={effect=effect,hunger=.001*fraction,base=.001,data={}}
                function obj:getFullType() return 'Hydrocraft.HCLemongrassExtract' end
                function obj:IsFood() return true end
                function obj:getModData() return self.data end
                function obj:getFoodSicknessChange() return self.effect end
                function obj:setFoodSicknessChange(n) self.effect=n end
                function obj:getBaseHunger() return self.base end
                function obj:getHungChange() return self.hunger end
                function obj:isCooked() return self.cooked or false end
                function obj:isBurnt() return self.burnt or false end
                function obj:getAge() return self.age or 0 end
                function obj:getOffAge() return 100 end
                return obj
            end
        ''')
        self.lua.execute(read_text(LUA/'shared/HCR_Medicine.lua'))

    def test_legacy_partial_dose_and_integer_tail_are_not_recreated(self):
        self.lua.execute('''
            local old=item(0,.5)
            assert(HCRMedicine.prepare(old) and old.effect==-25 and old.hunger==.0005)
            old.effect=0;old.hunger=.000001
            assert(not HCRMedicine.prepare(old) and old.effect==0)
            local new=item(-50,1);assert(HCRMedicine.prepare(new) and new.effect==-50)
            new.effect=0;assert(not HCRMedicine.prepare(new) and new.effect==0)
            local changed=item(-17,.5);assert(HCRMedicine.prepare(changed) and changed.effect==-17)
        ''')

    def test_unknown_portion_and_client_are_untouched(self):
        self.lua.execute('''
            for _,fraction in ipairs({0,-1,2,0/0,math.huge}) do
                local old=item(0,fraction);assert(not HCRMedicine.prepare(old) and old.effect==0 and next(old.data)==nil)
            end
            local old=item(0,1);old.base=-.01;assert(not HCRMedicine.prepare(old))
            old=item(0,1);client=true;assert(not HCRMedicine.prepare(old) and next(old.data)==nil)
            client=false
            for _,field in ipairs({'cooked','burnt','age'}) do
                old=item(0,1);old[field]=field=='age' and 101 or true
                assert(not HCRMedicine.prepare(old) and next(old.data)==nil)
            end
        ''')

    def test_lemongrass_uses_native_healing_field_and_medicines_keep_food_class(self):
        items={name:props(body) for path in SCRIPTS.rglob('*.txt') for _,_,name,body in blocks(read_text(path),'item')}
        self.assertEqual(items['HCLemongrassExtract']['foodsicknesschange'],'-50')
        self.assertNotIn('reducefoodsickness',items['HCLemongrassExtract'])
        for name in ('HCGinsengExtract','HCLemongrassExtract','HCAdrenalin','HCSyringeadrenalin','HCMouthwash','HCMouthwash2'):
            self.assertEqual(items[name]['itemtype'],'base:food')

    def test_server_repairs_before_native_eat_and_syncs_only_changed_health(self):
        self.lua.execute('''
            function isServer() return true end
            CharacterStat={FOOD_SICKNESS='sick',POISON='poison'}
            SyncPlayerStatsPacket={getBitMaskForStat=function(stat) return stat=='sick' and 2 or 4 end}
            HCRFoodQuality={sync=function() itemSyncs=(itemSyncs or 0)+1 end}
            function syncPlayerStats(_,mask) assert(mask==6);healthSyncs=(healthSyncs or 0)+1 end
            local stats={sick=80,poison=80,get=function(self,key) return self[key] end}
            local player={getStats=function() return stats end};local old=item(0,.5)
            assert(HCRMedicine.eat(old,player,function()
                assert(old.effect==-25);stats.sick=55;stats.poison=55;return true
            end))
            assert(itemSyncs==1 and healthSyncs==1)
            HCRMedicine.eat(old,player,function() return true end)
            assert(itemSyncs==2 and healthSyncs==1)
        ''')

if __name__=='__main__': unittest.main()

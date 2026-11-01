"""Настройки не удваивают веса и не расходуют отключённые inputs."""
import json
import unittest
from lupa.lua51 import LuaRuntime
from hcr_paths import LUA, HERE, read_text
from sandbox_test_support import load_sandbox


class Sandbox(unittest.TestCase):
    def setUp(self):
        self.lua=LuaRuntime(unpack_returned_tuples=True)
        load_sandbox(self.lua,loot=True)

    def test_loot_preserves_vanilla_and_uses_baseline_on_each_application(self):
        self.lua.execute('''
            pool={'Base.Apple',7}
            HCRSandboxLoot.append(pool,{'Hydrocraft.HCJar',4,'Base.Worm',2},.5)
            SandboxVars={Hydrocraft={LootMultiplier=2}}
            initSandboxLoot();initSandboxLoot()
        ''')
        self.assertEqual(list(self.lua.globals().pool.values()),['Base.Apple',7,'Hydrocraft.HCJar',4,'Base.Worm',2])
        self.lua.execute('SandboxVars.Hydrocraft.LootMultiplier=0;initSandboxLoot()')
        self.assertEqual(self.lua.globals().pool[2],7)
        self.assertEqual(len(self.lua.globals().pool),2)
        self.lua.execute('SandboxVars.Hydrocraft.LootMultiplier=1;initSandboxLoot()')
        self.assertEqual(self.lua.globals().pool[4],2)

    def test_disabled_subsystem_and_guns_weights_recover_without_duplicate_entries(self):
        self.lua.execute('''
            pool={}
            HCRSandboxLoot.append(pool,{'Hydrocraft.HCHempbudfresh',1})
            HCRSandboxLoot.append(pool,{'Hydrocraft.HCUzi',2},nil,'SpawnHydrocraftGuns')
            SandboxVars={Hydrocraft={EnableCannabis=false,SpawnHydrocraftGuns=false}}
            initSandboxLoot()
        ''')
        self.assertEqual(len(self.lua.globals().pool),0)
        self.lua.execute('SandboxVars.Hydrocraft={};initSandboxLoot()')
        self.assertEqual(self.lua.globals().pool[2],1)
        self.assertEqual(self.lua.globals().pool[4],2)
        self.assertEqual(len(self.lua.globals().pool),4)

    def test_removed_pairs_restore_order_among_foreign_items_and_late_additions(self):
        self.lua.execute('''
            pool={'Base.Apple',1};HCRSandboxLoot.append(pool,{'Hydrocraft.HCHempbudfresh',2})
            pool[#pool+1]='Other.Mod';pool[#pool+1]=3
            HCRSandboxLoot.append(pool,{'Hydrocraft.HCJar',4})
            SandboxVars={Hydrocraft={EnableCannabis=false,LootMultiplier=0}};initSandboxLoot()
            HCRSandboxLoot.append(pool,{'Hydrocraft.HCCarrot',5})
            initSandboxLoot();SandboxVars.Hydrocraft={};initSandboxLoot();initSandboxLoot()
        ''')
        self.assertEqual(list(self.lua.globals().pool.values()),
                         ['Base.Apple',1,'Hydrocraft.HCHempbudfresh',2,'Other.Mod',3,'Hydrocraft.HCJar',4,'Hydrocraft.HCCarrot',5])

    def test_external_weight_change_is_left_untouched(self):
        self.lua.execute('''
            pool={};HCRSandboxLoot.append(pool,{'Hydrocraft.HCJar',4})
            pool[2]=9;SandboxVars={Hydrocraft={LootMultiplier=2}}
            _,conflicts=HCRSandboxLoot.apply()
        ''')
        self.assertEqual(self.lua.globals().pool[2],9)
        self.assertEqual(self.lua.globals().conflicts,1)

    def test_late_registration_uses_current_setting_once(self):
        self.lua.execute('''
            SandboxVars={Hydrocraft={LootMultiplier=.5}};initSandboxLoot()
            pool={};HCRSandboxLoot.append(pool,{'Hydrocraft.HCJar',4})
            HCRSandboxLoot.register(pool,1);initSandboxLoot()
        ''')
        self.assertEqual(self.lua.globals().pool[2],2)

    def test_native_admin_change_without_to_lua_updates_once(self):
        self.lua.execute('''
            current=1
            function getSandboxOptions() return {
                getOptionByName=function(_,name)
                    if name=='Hydrocraft.LootMultiplier' then
                        return {getValue=function() return current end}
                    end
                end} end
            SandboxVars={Hydrocraft={LootMultiplier=1}}
            pool={};HCRSandboxLoot.append(pool,{'Hydrocraft.HCJar',4})
            initSandboxLoot();current=2
            for i=1,180 do HCRSandboxLoot.poll() end
        ''')
        self.assertEqual(self.lua.globals().pool[2],8)
        self.assertEqual(self.lua.globals().parses,2)
        self.assertEqual(self.lua.globals().SandboxVars.Hydrocraft.LootMultiplier,1)

    def crafting(self):
        self.lua.execute('''
            ISHandcraftAction={isValid=function() return true end,
                performRecipe=function() calls=(calls or 0)+1;return true end,
                getDuration=function(self) return self.duration end}
            function isServer() return server or false end
            Events.OnServerCommand={Add=function() end}
            recipe={getName=function() return name end}
            data={getRecipe=function() return recipe end}
            action={craftRecipe=recipe,logic={getRecipeData=function() return data end},duration=1250}
        ''')
        self.lua.execute(read_text(LUA/'shared/HCR_SandboxCrafting.lua'))

    def test_production_refused_before_mutation_and_cleanup_remains_enabled(self):
        self.crafting()
        for server in (True,False):
            self.lua.globals().server=server
            self.lua.execute("SandboxVars={Hydrocraft={EnableCannabis=false}};name='Cure Hemp Bud';calls=0")
            self.assertFalse(self.lua.eval('ISHandcraftAction.isValid(action)'))
            self.assertFalse(self.lua.eval('ISHandcraftAction.performRecipe(action)'))
            self.assertEqual(self.lua.globals().calls,0)
            self.lua.execute("name='Clean Glass Bong'")
            self.assertTrue(self.lua.eval('ISHandcraftAction.performRecipe(action)'))

    def test_mining_speed_leaves_building_instant_and_invalid_actions_unchanged(self):
        self.crafting()
        self.lua.execute("SandboxVars={Hydrocraft={MiningSpeedMultiplier=2}};name='Mine Iron'")
        self.assertEqual(self.lua.eval('ISHandcraftAction.getDuration(action)'),625)
        self.lua.execute("name='Build Mine'")
        self.assertEqual(self.lua.eval('ISHandcraftAction.getDuration(action)'),1250)
        for duration in (1,-1):
            self.lua.execute("name='Mine Iron'")
            self.lua.globals().action.duration=duration
            self.assertEqual(self.lua.eval('ISHandcraftAction.getDuration(action)'),duration)

    def test_disabled_hemp_harvest_preserves_fibres_and_seeds(self):
        self.lua.execute(read_text(LUA/'shared/PlantsGrowing.lua'))
        self.lua.execute('''
            SandboxVars={Hydrocraft={EnableCannabis=false}}
            output={}
            local plant={getType=function() return 'HCPottedhempready' end}
            local items={size=function() return 1 end,get=function() return plant end}
            local inv={AddItem=function(_,name) output[name]=(output[name] or 0)+1 end}
            recipe_NDPlantsHarvest(items,nil,{getInventory=function() return inv end})
        ''')
        output=self.lua.globals().output
        self.assertIsNone(output['Hydrocraft.HCHempbudfresh'])
        self.assertEqual(output['Hydrocraft.HCPlantfibers'],4)
        self.assertGreater(output['Hydrocraft.HCHempseeds'],0)

    def test_mining_callbacks_use_the_passed_server_player(self):
        self.lua.execute('''
            function getPlayer() error('No local player on a dedicated server') end
            Perks={Strength='Strength',Fitness='Fitness',PlantScavenging='PlantScavenging'}
            CharacterStat={ENDURANCE='ENDURANCE'}
            function ZombRand() return 0 end
            xp={};outputs={}
            player={getXp=function() return {AddXP=function(_,perk,amount) xp[perk]=(xp[perk] or 0)+amount end} end,
                getStats=function() return {add=function() end} end,getPerkLevel=function() return 1 end,
                getInventory=function() return {AddItem=function(_,name) outputs[#outputs+1]=name end,AddItems=function() end} end}
        ''')
        self.lua.execute(read_text(LUA/'server/RockHCExtra.lua'))
        for name in ('HCMine','HCShovelClay','HCMineStone','HCDarkmine'):
            self.lua.execute(name+'(nil,nil,player)')
        self.assertEqual(self.lua.globals().xp.Strength,11)
        self.assertEqual(self.lua.globals().xp.Fitness,11)
        self.assertGreater(len(self.lua.globals().outputs),0)

    def test_catalogue_keeps_production_distinct_from_unpacking_and_building(self):
        data=json.loads(read_text(HERE/'sandbox_catalog.json'))
        self.assertEqual(len(data['recipes']),29)
        self.assertEqual(len(data['mining']),16)
        self.assertNotIn('Pack Cigarettes',data['recipes'])
        self.assertNotIn('Clean Glass Bong',data['recipes'])
        self.assertNotIn('Dig Mine',data['mining'])


if __name__=='__main__':
    unittest.main()

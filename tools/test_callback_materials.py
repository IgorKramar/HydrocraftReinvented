"""Execute reachable material rewards and every dung-foraging random branch."""
import json
import re
import unittest

from lupa.lua51 import LuaRuntime

from audit_lua_item_ids import declared
from hcr_paths import LUA, REPO, SCRIPTS, find_game, read_text


def runtime():
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.globals().known = lua.table_from({name: True for name in declared(SCRIPTS) | declared(find_game() / "media/scripts")})
    lua.execute('''
        function require() end
        outputs = {}; xp = 0; fatigue = 0; spoken = 0
        inventory = {}
        function inventory:AddItem(name)
            assert(type(name) == "string" and known[name], "Unavailable reward: " .. tostring(name))
            outputs[name] = (outputs[name] or 0) + 1
        end
        function inventory:AddItems(name, amount)
            assert(amount >= 1 and amount == math.floor(amount))
            for i = 1, amount do self:AddItem(name) end
        end
        player = {outside=true, skill=0}
        function player:getInventory() return inventory end
        function player:isOutside() return self.outside end
        function player:Say() spoken = spoken + 1 end
        function player:getPerkLevel() return self.skill end
        function player:getStats() return {add=function(_,_,value) fatigue=fatigue+value end} end
        function player:getXp() return {AddXP=function(_,_,value) xp=xp+value end} end
        CharacterStat={FATIGUE="Fatigue"}; Perks={PlantScavenging="Foraging"}
        month=5
        function getGameTime() return {getMonth=function() return month end} end
        function ZombRand(upper)
            if upper == 4096 then return chanceChoice end
            assert(upper == 2, "Secondary choice includes unhandled outcomes")
            return secondaryChoice
        end
    ''')
    return lua


class CallbackMaterials(unittest.TestCase):
    def test_reachable_callbacks_create_real_resources_with_original_quantities(self):
        source = read_text(LUA / "server/HCExtra.lua")
        headers = list(re.finditer(r"(?m)^function ([\w.]+)\([^\n]*", source))
        functions = {match[1]: source[match.start():headers[i + 1].start() if i + 1 < len(headers) else len(source)]
                     for i, match in enumerate(headers)}
        cases = {
            "recipe_hcdismantlecopymachine": ("Hydrocraft.HCPlasticscrap", 30),
            "recipe_hcdismantlepallettruck": ("Hydrocraft.HCRubberscrap", 6),
            "recipe_hcdismantletoywagon": ("Hydrocraft.HCRubberscrap", 8),
            "recipe_hcdismantlehanddolly": ("Hydrocraft.HCRubberscrap", 4),
            "recipe_hcdismantlepushcart": ("Hydrocraft.HCRubberscrap", 8),
            "recipe_hcdismantleglovebox": ("Hydrocraft.HCPlasticscrap", 8),
            "recipe_hcdismantlelawnmower": ("Hydrocraft.HCPlasticscrap", 6),
            "recipe_hcelectrolyzerobsidian": ("Hydrocraft.HCSiliconpowder", 2),
            "recipe_hcgivemusselshell": ("Hydrocraft.HCMusselshell", 1),
        }
        scripts = "\n".join(read_text(path) for path in SCRIPTS.rglob("*.txt"))
        for name, (reward, count) in cases.items():
            with self.subTest(callback=name):
                self.assertIn("OnCreate = HCR42." + name, scripts, "Callback is not reached by a current recipe")
                lua = runtime()
                lua.execute(functions[name])
                lua.globals()[name](None, None, lua.globals().player)
                self.assertEqual(lua.globals().outputs[reward], count)
                if name == "recipe_hcdismantlelawnmower":
                    self.assertEqual(lua.globals().outputs["Hydrocraft.HCCablecopper"], 1)

    def test_every_foraging_roll_at_every_skill_in_summer_and_winter(self):
        lua = runtime()
        lua.execute(read_text(LUA / "server/DungHCExtra.lua"))
        lua.execute('''
            observed = {}
            for _, season in ipairs({0, 5}) do
                month = season
                for skill = 0, 10 do
                    player.skill = skill
                    local maximumRewardRoll = 2047 + 204.6 * skill
                    if season == 0 then maximumRewardRoll = maximumRewardRoll / 2 end
                    for roll = 0, 4095 do
                        for secondary = 0, 1 do
                            chanceChoice, secondaryChoice = roll, secondary
                            outputs, xp, fatigue = {}, 0, 0
                            HCDungGather(nil, nil, player)
                            local count = 0
                            for name, amount in pairs(outputs) do
                                count = count + amount; observed[name] = true
                            end
                            if roll <= maximumRewardRoll then
                                assert(count == 1 and xp == 10, "Reward branch gave XP without valid dung")
                            else
                                assert(count == 0 and xp == 0, "No-find branch created a reward")
                            end
                            assert(fatigue == 0.05)
                        end
                    end
                end
            end
            local count = 0
            for _ in pairs(observed) do count=count+1 end
            assert(count == 12, "Not all dung species branches executed")
            player.outside=false; outputs={}; xp=0; fatigue=0; spoken=0
            HCDungGather(nil,nil,player)
            assert(next(outputs)==nil and xp==0 and fatigue==0 and spoken==1)
        ''')

    def test_material_names_icons_and_mussel_replacement_resolve(self):
        source = read_text(SCRIPTS / "HydrocraftReinvented/HCR_CallbackMaterials.txt")
        russian = json.loads(read_text(LUA / "shared/Translate/RU/ItemName.json"))
        names = declared(SCRIPTS)
        blocks = re.findall(r"\bitem (\w+)\s*\{([^}]+)\}", source)
        self.assertEqual(len(blocks), 9)
        for name, body in blocks:
            self.assertIn("ItemType = base:normal", body)
            icon = re.search(r"\bIcon\s*=\s*(\w+)", body)[1]
            self.assertTrue((REPO / "common/media/textures" / ("Item_" + icon + ".png")).is_file())
            self.assertTrue(russian["Hydrocraft." + name])
        seafood = read_text(SCRIPTS / "HydrocraftReinvented/HCR_Food Seafood.txt")
        replacement = re.search(r"item HCMussel\s*\{[^}]*ReplaceOnUse\s*=\s*(\w+)", seafood)[1]
        self.assertIn("Hydrocraft." + replacement, names)


if __name__ == "__main__":
    unittest.main(verbosity=2)

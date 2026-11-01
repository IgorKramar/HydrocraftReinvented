"""Метанол: исходный whitelist действует на жидкость, а не на этикетку тары."""
import unittest
from apply_playability_fixes import blocks
from hcr_paths import LUA, SCRIPTS, read_text
from build_methanol_restore import MARKERS
import test_fluid_recipe_quality as quality


class MethanolEligibility(unittest.TestCase):
    setUp = quality.FluidRecipeQuality.setUp

    def test_all_sources_and_ineligible_trace_after_pouring(self):
        self.lua.execute(read_text(LUA/'shared/HCR_MethanolRules.lua'))
        self.lua.execute('''
            local R,L=HCRFluidRecipeQuality,HCRFluidLedger
            R.rules.Test=HCRMethanolRules['Make Methanol']
            Fluid={Water='Water',Get=function(k) return k end}
            local marker='HCRVodka'
            function source:createFluidSample()
                return {size=function() return 1 end,getFluid=function() return marker end,release=function() end}
            end
            local count=0
            for kind in pairs(R.rules.Test.inputs[0].sourceTypes) do
                count=count+1
                marker=kind:find('Sake') and 'HCRSake' or kind:find('Gin') and 'HCRGin'
                    or kind:find('Rum') and 'HCRRum' or kind:find('Vodka') and 'HCRVodka' or 'HCRWhiskey'
                source.data=L.batch(marker,1.5,{sourceType=kind,calories=137,poisonPower=.75},0)
                assert(R.compatible(recipe,source,0),kind)
                local trace=L.batch(marker,.00001,{sourceType='Hydrocraft.HCDrinkglasstallvodka'},0)
                trace.lots[1].litres=0
                source.data=L.mix(source.data,trace)
                assert(not R.compatible(recipe,source,0),'Disallowed source trace accepted')
            end
            assert(count==15)
            marker='Water';source.data=L.empty()
            assert(not R.compatible(recipe,source,0),'Water accepted')
            marker='Whiskey';source.data=L.empty()
            assert(not R.compatible(recipe,source,0),'Native Whiskey outside original list')
        ''')


class MethanolRecipes(unittest.TestCase):
    def test_original_amounts_and_single_native_output_path(self):
        recipes={n:b for p in SCRIPTS.rglob('*.txt') for _,_,n,b in blocks(read_text(p),'craftRecipe')}
        original=recipes['Make Methanol']
        self.assertIn('SkillRequired = Cooking:7,',original)
        self.assertIn('time = 100,',original)
        self.assertIn('-fluid 1 ['+';'.join(MARKERS)+'] mode:primary,',original)
        self.assertIn('[Hydrocraft.HCDistillery;Hydrocraft.HCDistillery2] mode:keep,',original)
        self.assertIn('item 1 [Base.Charcoal],',original)
        self.assertIn('item 1 tags[base:startfire],',original)
        self.assertIn('item 1 Hydrocraft.HCMethanol,',original)
        found=recipes['Distill Methanol']
        self.assertNotIn('OnCreate',found)
        self.assertIn('item 5 Hydrocraft.HCMethanol,',found)
        self.assertIn('item 1 Hydrocraft.HCWoodenbarrelFluid,',found)
        self.assertNotIn('Fill Barrel with Lemon Mash',recipes)
        items={n:b for p in SCRIPTS.rglob('*.txt') for _,_,n,b in blocks(read_text(p),'item')}
        for name in ('HCBarrelLemon','HCBarrelLemonFermented'):
            self.assertRegex(items[name],r'ItemType\s*=\s*base:normal')
        self.assertRegex(items['HCMethanol'],r'UseDelta\s*=\s*0\.25')


if __name__ == '__main__':
    unittest.main()

"""Conservation tests for per-batch liquids; independent of native UI mocks."""
import random
import struct
import unittest
from pathlib import Path
from lupa.lua51 import LuaRuntime

SOURCE = Path(__file__).resolve().parents[1] / 'common/media/lua/shared/HCR_FluidLedger.lua'


class FluidLedger(unittest.TestCase):
    def setUp(self):
        self.lua = LuaRuntime(unpack_returned_tuples=True)
        self.lua.globals().package.path = str(SOURCE.parent.as_posix()) + '/?.lua;' + self.lua.globals().package.path
        self.lua.execute(SOURCE.read_text(encoding='utf-8'))
        self.core = self.lua.globals().HCRFluidLedger

    def batch(self, litres=1, age=0, poison=13, calories=240, fluid='HCRJuice'):
        return self.core.batch(fluid, litres, self.lua.table_from(dict(
            age=age, offAge=3, offAgeMax=7, poisonPower=poison,
            calories=calories, hungChange=-.2, thirstChange=-.3)), 100)

    def test_actual_withdrawal_from_water_diluted_batch(self):
        source = self.batch()
        kept, moved = self.core.transfer(source, self.core.empty(), .25, 2)
        self.assertAlmostEqual(self.core.volume(kept), .875)
        self.assertAlmostEqual(self.core.volume(moved), .125)
        self.assertAlmostEqual(self.core.budget(moved, 'poisonPower'), 1.625)
        self.assertEqual(self.core.volume(source), 1)  # inputs immutable

    def test_repeated_interruptions_and_round_trips_conserve_every_budget(self):
        rng = random.Random(160)
        first = self.core.mix(self.batch(age=9), self.batch(.7, age=1, poison=0, calories=81))
        second = self.core.empty()
        volumes = [2.7, 1.0]  # each also contains native water
        totals = {key: self.core.budget(first, key) for key in ('poisonPower', 'calories', 'hungChange', 'thirstChange')}
        for _ in range(2000):
            direction = rng.randrange(2)
            amount = volumes[direction] * rng.random() * .2
            if direction == 0:
                first, second = self.core.transfer(first, second, amount, volumes[0])
            else:
                second, first = self.core.transfer(second, first, amount, volumes[1])
            volumes[direction] -= amount
            volumes[1-direction] += amount
        for field, expected in totals.items():
            self.assertAlmostEqual(self.core.budget(first, field) + self.core.budget(second, field), expected, places=9)
        self.assertAlmostEqual(self.core.volume(first) + self.core.volume(second), 1.7, places=10)
        self.assertLessEqual(len(first.lots), 2)
        self.assertLessEqual(len(second.lots), 2)
        self.assertEqual(self.core.quality(first), 'rotten')

    def test_age_is_not_reset_or_averaged_when_mixing(self):
        mixed = self.core.mix(self.batch(age=8), self.batch(age=0, poison=0))
        self.assertEqual(self.core.quality(mixed), 'rotten')
        self.assertEqual([mixed.lots[n].age for n in (1, 2)], [8, 0])
        aged = self.core.advance(mixed, 124, self.lua.eval('function(a,b) return (b-a)*0.2 end'))
        self.assertAlmostEqual(aged.lots[1].age, 8.2)
        repeated = self.core.advance(aged, 124, self.lua.eval('function() error("duplicate ageing") end'))
        self.assertAlmostEqual(repeated.lots[1].age, 8.2)

    def test_individual_transport_id_must_match_native_amount(self):
        source = self.batch()
        self.assertTrue(self.core.matches(source, self.lua.table_from({'HCRJuice': 1})))
        for amounts in ({'HCRJuice': 2}, {'HCRJuice': 1, 'HCRMilk': .1}, {'HCRMilk': 1}, {}):
            self.assertFalse(self.core.matches(source, self.lua.table_from(amounts)))

    def test_small_sips_preserve_fractional_poison_and_last_drop(self):
        remainder = self.batch(poison=1)
        dose = 0
        volume = 1
        for _ in range(999):
            remainder, sip = self.core.split(remainder, .001, volume)
            volume -= .001
            dose += self.core.budget(sip, 'poisonPower')
        remainder, sip = self.core.split(remainder, volume, volume)
        dose += self.core.budget(sip, 'poisonPower')
        self.assertEqual(self.core.volume(remainder), 0)
        self.assertAlmostEqual(dose, 1, places=12)

    def test_native_float32_volume_rounding_preserves_nutrition_and_poison(self):
        def float32(n):
            return struct.unpack('f', struct.pack('f', n))[0]
        first, second = self.batch(64), self.core.empty()
        before = 64
        after = float32(64 - float32(.1))
        gained = float32(.1)
        kept, moved = self.core.transfer(first, second, before-after, before)
        kept = self.core.alignVolumes(kept, self.lua.table_from({'HCRJuice': after}))
        moved = self.core.alignVolumes(moved, self.lua.table_from({'HCRJuice': gained}))
        self.assertTrue(self.core.matches(kept, self.lua.table_from({'HCRJuice': after})))
        self.assertTrue(self.core.matches(moved, self.lua.table_from({'HCRJuice': gained})))
        self.assertAlmostEqual(self.core.budget(kept, 'poisonPower') + self.core.budget(moved, 'poisonPower'), 13)
        self.assertAlmostEqual(self.core.budget(kept, 'calories') + self.core.budget(moved, 'calories'), 240)

    def test_native_component_accounting_sees_a_sip_hidden_by_full_volume_snap(self):
        first=self.batch(poison=100,calories=5000)
        before=self.lua.table_from({'HCRJuice':1})
        after=self.lua.table_from({'HCRJuice':.9996})
        kept,sip=self.core.withdrawNative(first,before,after,.0004)
        self.assertAlmostEqual(self.core.budget(sip,'poisonPower'),.04)
        self.assertAlmostEqual(self.core.budget(sip,'calories'),2)
        self.assertTrue(self.core.matches(kept,after))

    def test_native_final_trace_is_counted_without_erasing_poison(self):
        first=self.batch(.00011,poison=100)
        kept,sip=self.core.withdrawNative(first,self.lua.table_from({'HCRJuice':.00011}),self.lua.table(),.00011)
        self.assertEqual(len(kept.lots),0)
        self.assertEqual(self.core.budget(sip,'poisonPower'),100)
        # A nearly full receiver can lose the native marker during blending.
        trace=self.core.alignVolumes(sip,self.lua.table(),.00101)
        self.assertEqual(self.core.volume(trace),0)
        self.assertEqual(self.core.budget(trace,'poisonPower'),100)
        self.assertTrue(self.core.matches(trace,self.lua.table()))
        left,half=self.core.withdrawNative(trace,self.lua.table(),self.lua.table(),.5)
        self.assertEqual(self.core.budget(half,'poisonPower'),50)
        empty,last=self.core.withdrawNative(left,self.lua.table(),self.lua.table(),1)
        self.assertEqual(len(empty.lots),0)
        self.assertEqual(self.core.budget(last,'poisonPower'),50)

    def test_invalid_and_excessive_mixes_fail_without_mutating_inputs(self):
        original = self.batch()
        for amount in (-1, 2, float('nan'), float('inf')):
            with self.assertRaises(Exception):
                self.core.transfer(original, self.core.empty(), amount, 1)
            self.assertEqual(self.core.volume(original), 1)
        target = self.core.empty()
        for n in range(128):
            target = self.core.mix(target, self.batch(age=n))
        with self.assertRaises(Exception):
            self.core.mix(target, self.batch(age=129))
        self.assertEqual(len(target.lots), 128)

    def test_schema_is_plain_saveable_scalars_and_round_trips(self):
        source = self.batch(age=5)
        # A fresh Lua VM with plain tables models the save/load boundary.
        def plain(value):
            return {key: plain(entry) for key, entry in value.items()} if hasattr(value, 'items') else value
        restored = self.lua.table_from(plain(source), recursive=True)
        self.assertTrue(self.core.validate(restored))
        self.assertEqual(self.core.quality(restored), 'stale')
        self.assertEqual(self.core.budget(restored, 'poisonPower'), 13)

    def test_sparse_saved_lots_are_rejected_instead_of_discarded(self):
        source = self.batch()
        source.lots[2] = source.lots[1]
        source.lots[1] = None
        with self.assertRaises(Exception):
            self.core.validate(source)

    def test_invalid_working_field_types_are_rejected_at_ingress(self):
        for key, value in [('poisonPower', 'oops'), ('offAgeMax', '7'), ('poisonPower', -1),
                           ('poisonPower', float('inf')), ('cooked', 1), ('unknown', 1)]:
            source = self.batch()
            source.lots[1].food[key] = value
            with self.assertRaises(Exception):
                self.core.validate(source)

    def test_fractional_food_poison_survives_a_drink_round_trip(self):
        source=self.batch(poison=.0125)
        kept,moved=self.core.split(source,.3,1)
        self.assertAlmostEqual(self.core.budget(moved,'poisonPower'),.00375)
        joined=self.core.mix(kept,moved)
        self.assertAlmostEqual(self.core.budget(joined,'poisonPower'),.0125)

    def test_unbounded_application_count_is_rejected_before_consumption(self):
        source=self.batch()
        source.lots[1].units=1e20
        with self.assertRaises(Exception):
            self.core.validate(source)

    def test_mix_preflight_rejects_combined_application_limit(self):
        first,second=self.batch(),self.batch()
        first.lots[1].units=3000
        second.lots[1].units=3000
        with self.assertRaises(Exception):
            self.core.mix(first,second)
        self.assertEqual(first.lots[1].units,3000)
        self.assertEqual(second.lots[1].units,3000)

    def test_clock_rollback_does_not_age_the_same_interval_twice(self):
        source = self.batch()
        clock = self.lua.eval('function(a,b) return b-a end')
        restored = self.core.advance(source, 90, clock)
        advanced = self.core.advance(restored, 110, clock)
        self.assertAlmostEqual(advanced.lots[1].age, 10/24)

    def test_corrupt_storage_is_rejected_before_ageing(self):
        valid = dict(cold=True, freezer=False, powered=True, temperature=.2, x=1, y=2, z=0)
        for key, value in [('temperature', float('nan')), ('powered', 1), ('x', .5), ('y', None)]:
            source = self.batch()
            changed = dict(valid)
            changed[key] = value
            source.storage = self.lua.table_from(changed)
            with self.assertRaises(Exception):
                self.core.validate(source)

    def test_component_prune_applies_dose_when_float_total_does_not_change(self):
        self.lua.execute('''
            function require() end
            function isClient() return false end
            HCRFluidEffects={prepare=function(l) return l end,
                consume=function(_,l) dose=HCRFluidLedger.budget(l,"poisonPower") end}
        ''')
        self.lua.execute(SOURCE.with_name('HCR_FluidQuality.lua').read_text(encoding='utf-8'))
        self.lua.globals().batch = self.batch(.0000001)
        self.lua.execute('''
            local Q=HCRFluidQuality
            local fluid={}
            local item={}
            Q.fluid=function() return fluid end
            Q.active=function() return true end
            Q.capture=function() return {ledger=batch,amounts={HCRJuice=.0000001},amount=64} end
            Q.rawAmount=function() return 64 end
            Q.amounts=function() return {} end
            Q.store=function(_,_,l) remaining=l end
            Q.sync=function() end
            Q.remove(item,{},function() end,true,false)
        ''')
        self.assertEqual(self.lua.globals().dose, 13)
        self.assertEqual(len(self.lua.globals().remaining.lots), 0)

    def test_cold_storage_does_not_refrigerate_previous_warm_days(self):
        self.lua.execute('function require() end')
        self.lua.execute(SOURCE.with_name('HCR_FluidCooling.lua').read_text(encoding='utf-8'))
        warm = self.lua.table_from(dict(cold=False, freezer=False, powered=False, temperature=1))
        cold = self.lua.table_from(dict(cold=True, freezer=False, powered=True, temperature=.2))
        source = self.batch()
        source.storage = warm
        cooled = self.lua.globals().HCRFluidCooling.advance(source, 268, cold, .2, 1, -1, False)
        self.assertAlmostEqual(cooled.lots[1].age, 7)
        aged = self.lua.globals().HCRFluidCooling.advance(cooled, 292, cold, .2, 1, -1, True)
        self.assertAlmostEqual(aged.lots[1].age, 7.2)

    def test_freeze_and_thaw_integrate_only_unfrozen_intervals(self):
        self.lua.execute('function require() end')
        self.lua.execute(SOURCE.with_name('HCR_FluidCooling.lua').read_text(encoding='utf-8'))
        cooling = self.lua.globals().HCRFluidCooling
        freezer = self.lua.table_from(dict(cold=True, freezer=True, powered=True, temperature=.2))
        warm = self.lua.table_from(dict(cold=False, freezer=False, powered=False, temperature=1))
        source = self.batch()
        source.storage = freezer
        frozen = cooling.advance(source, 124, freezer, .2, 1, -1, True)
        self.assertAlmostEqual(frozen.lots[1].age, 4*.2/24)
        self.assertTrue(frozen.lots[1].food.frozen)
        frozen.storage = warm  # transfer closes the old storage interval
        thawed = cooling.advance(frozen, 148, warm, .2, 1, -1, False)
        self.assertAlmostEqual(thawed.lots[1].age, 4*.2/24 + 22.5/24)
        self.assertFalse(thawed.lots[1].food.frozen)


if __name__ == '__main__':
    unittest.main()

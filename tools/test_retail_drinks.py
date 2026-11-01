"""Магазинная миграция не обрывает рецепты и сохраняет загрузочные классы."""
import re
import unittest
from apply_playability_fixes import blocks
from build_retail_drinks import catalogue
from build_water_catalog import props
from hcr_paths import SCRIPTS,read_text


class RetailDrinks(unittest.TestCase):
    def test_retail_migrations_are_closed_and_do_not_change_old_serialized_classes(self):
        catalog=catalogue()
        self.assertEqual(len(catalog),14)
        items={name:props(body) for path in SCRIPTS.rglob('*.txt')
               for _,_,name,body in blocks(read_text(path),'item')}
        for kind,spec in catalog.items():
            expected='base:normal' if spec.get('empty') else 'base:food'
            self.assertEqual(items[kind.split('.')[1]]['itemtype'],expected)
        for path in SCRIPTS.rglob('*.txt'):
            for _,_,name,body in blocks(read_text(path),'craftRecipe'):
                referenced=set(re.findall(r'Hydrocraft\.\w+',body))
                self.assertFalse(referenced & catalog.keys(),(path.name,name,referenced & catalog.keys()))

    def test_new_cartons_are_empty_and_keep_existing_icons(self):
        text=read_text(SCRIPTS/'HydrocraftReinvented/HCR_DrinkContainers.txt')
        entries=list(blocks(text,'item'))
        self.assertEqual(len(entries),3)
        for _,_,name,body in entries:
            p=props(body)
            self.assertEqual(float(p['capacity']),.2)
            self.assertNotRegex(body,r'\bFluids\s*\{')
            self.assertEqual(p['icon'],name.removesuffix('Fluid'))


if __name__=='__main__': unittest.main()

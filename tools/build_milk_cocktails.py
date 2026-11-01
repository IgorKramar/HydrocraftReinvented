"""Молочные коктейли: фактический выход кастрюли и разлив без размножения."""
import json
import re
from apply_playability_fixes import blocks
from build_juice_catalog import lua
from build_water_catalog import props
from convert_water_recipes import callback
from hcr_paths import LUA, REPO, SCRIPTS, read_text
from repair_food_counts import whole_input

FAMILIES = {
    'HCEggnogpot': ('Base.Pot', 'Eggnog', 1.5),
    'HCEggnogmug': ('Base.Mugl', 'Eggnog', .2),
    'HCWhiskeyeggnogbottle': ('Hydrocraft.HCEggnogbottleFluid', 'Eggnog', 1),
    'HCColademonopot': ('Base.Pot', 'MonkeyTail', 1.5),
    'HCColademonomug': ('Base.Mugl', 'MonkeyTail', .2),
    'HCWhiskeycolademonobottle': ('Hydrocraft.HCMonkeyTailbottleFluid', 'MonkeyTail', 1),
}
PRODUCTS = {
    'Make Eggnog Pot': ('Base.Pot', 'Eggnog', .35, 1),
    'Make Monkey Tail Pot': ('Base.Pot', 'MonkeyTail', 1.1, 1),
    'Make Eggnog Cuppa': ('Base.Mugl', 'Eggnog', .8, 4),
    'Make Monkey Tail Mug': ('Base.Mugl', 'MonkeyTail', .8, 4),
    'Make Eggnog Bottle': ('Hydrocraft.HCEggnogbottleFluid', 'Eggnog', 2, 2),
    'Make Monkey Tail Bottle': ('Hydrocraft.HCMonkeyTailbottleFluid', 'MonkeyTail', 2, 2),
}


def main():
    items = {name: props(body) for p in SCRIPTS.rglob('*.txt') for _, _, name, body in blocks(read_text(p), 'item')}
    families = {'Hydrocraft.'+name: dict(target=target, fluid='HCR'+marker, litres=litres, enabled=True)
                for name, (target, marker, litres) in FAMILIES.items()}
    products, consumers, empty_recipes = {}, {}, set()
    aliases = ['Hydrocraft.HCEggnogbottleFluid', 'Hydrocraft.HCMonkeyTailbottleFluid']
    for path in SCRIPTS.rglob('*.txt'):
        text = previous = read_text(path)
        for start, end, name, body in reversed(list(blocks(text, 'craftRecipe'))):
            def alias(match):
                kinds = match[2].split(';')
                for kind in aliases:
                    if kind not in kinds: kinds.append(kind)
                empty_recipes.add(name)
                return match[1]+';'.join(kinds)+match[3]
            body = re.sub(r'(item \d+ \[)(Base\.Whiskey(?:;[^\]]+)?)(\](?: mode:destroy)? flags\[ItemCount;ItemIsFluid;IsEmpty\],)', alias, body)
            if name in PRODUCTS:
                target, marker, litres, count = PRODUCTS[name]
                batch=name in ('Make Eggnog Pot','Make Monkey Tail Pot')
                if not batch:
                    body = re.sub(r'item 1 \[Hydrocraft\.(?:HCEggnogpot|HCColademonopot)\] flags\[ItemCount\],',
                        f'item 1 [*] mode:keep flags[ItemIsFluid;HandcraftOnly],\n            -fluid {litres:g} [HCR{marker}] mode:primary,', body)
                # Отдельные пустые сосуды расходуются по одному, донор остаётся.
                body = re.sub(r'(item \d+ \[Base\.(?:Pot|Mugl)[^\]]*\])(?: mode:destroy)? flags\[ItemCount(?:;ItemIsFluid;IsEmpty)?\],',
                    r'\1 mode:destroy flags[ItemCount;ItemIsFluid;IsEmpty],', body)
                body = re.sub(r'(item 2 \[Base\.Whiskey[^\]]*\])(?: mode:destroy)?( flags\[ItemCount;ItemIsFluid;IsEmpty\],)', r'\1 mode:destroy\2', body)
                body = re.sub(r'outputs\s*\{[^}]*\}', f'outputs\n        {{\n            item {count} {target},\n        }}', body)
                body, _ = callback(body, 'OnCreate', 'HCRBarDrinks.create')
                body, _ = callback(body, 'Tooltip', 'Tooltip_HCR_MilkCocktailBatch')
                lines = re.findall(r'item [^\n]+\n(?:\s*-fluid [^\n]+\n)?', body.split('inputs', 1)[1].split('outputs', 1)[0])
                slots, foods = {}, {}
                for index, line in enumerate(lines):
                    match = re.search(r'-fluid [\d.]+ \[([^\]]+)\]', line)
                    if match:
                        slots[index] = dict(fluids=match[1].split(';'))
                        if batch and index == 0: slots[index]['nativeMilk'] = True
                        else: slots[index]['nativeWine'] = 'HCR'+marker
                    elif 'mode:keep' not in line and 'IsEmpty' not in line:
                        foods[index] = ({'nativeTags': True} if 'tags[' in line else
                            {kind: True for kind in re.search(r'\[([^\]]+)\]', line)[1].split(';')})
                products[name] = dict(target=target, marker='HCR'+marker, litres=litres, count=count, foodSlots=foods)
                if name=='Make Eggnog Pot': products[name]['safeEggSlot'] = 1
                consumers[name] = dict(inputs=slots)
            text = text[:start]+body+text[end:]
        if text != previous: path.write_text(text, encoding='utf-8')
    assert len(products)==6
    catalog = dict(families=families, products=products, consumers=consumers, emptyRecipes=sorted(empty_recipes),
        pending=[])
    (REPO/'tools/milk_cocktail_catalog.json').write_text(json.dumps(catalog, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
    path = REPO/'tools/milk_fluid_migrations.json'; record = json.loads(path.read_text(encoding='utf-8'))
    for row in record['migrations']:
        if row.get('native_recipe') in products and row.get('superseded_by')!='unified_milk_1_6': row['superseded_by'] = 'milk_cocktails'
    path.write_text(json.dumps(record, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
    (LUA/'shared/HCR_MilkCocktailCatalog.lua').write_text('-- Генерируется tools/build_milk_cocktails.py.\nrequire "HCR_BarCatalog"\nHCRMilkCocktailCatalog='+lua(catalog)+'\n'
        'for kind,spec in pairs(HCRMilkCocktailCatalog.families) do HCRDrinkFamilies[kind]=spec end\n'
        'for name,rule in pairs(HCRMilkCocktailCatalog.products) do HCRBarCatalog.products[name]=rule end\n', encoding='utf-8')
    script = ['module Hydrocraft', '{']
    for name in ('HCWhiskeyeggnogbottle', 'HCWhiskeycolademonobottle'):
        p = items[name]; target = FAMILIES[name][0].split('.')[1]
        script += [f'    item {target}', '    {', '        ItemType = base:normal,', '        DisplayCategory = WaterContainer,',
            f'        DisplayName = {p["displayname"]},', f'        Icon = {p["icon"]},', '        Weight = 0.2,',
            '        EatType = Bourbon,', '        Tags = base:glass;base:glassbottle,', '        component FluidContainer', '        {',
            '            ContainerName = Bottle,', '            Capacity = 1,', '            CustomDrinkSound = DrinkingFromBottleGlass,', '        }', '    }']
    (SCRIPTS/'HydrocraftReinvented/HCR_MilkCocktailContainers.txt').write_text('\n'.join(script+['}'])+'\n', encoding='utf-8')
    for lang in ('RU', 'EN'):
        path = LUA/f'shared/Translate/{lang}/ItemName.json'; names = json.loads(path.read_text(encoding='utf-8'))
        for old in ('HCWhiskeyeggnogbottle', 'HCWhiskeycolademonobottle'):
            names[FAMILIES[old][0]] = names.get('Hydrocraft.'+old, items[old]['displayname'])
        path.write_text(json.dumps(names, ensure_ascii=False, indent=4)+'\n', encoding='utf-8')
        path = LUA/f'shared/Translate/{lang}/Tooltip.json'; names = json.loads(path.read_text(encoding='utf-8'))
        names['Tooltip_HCR_MilkCocktailBatch'] = ('Эггног: 0,35 л; «Обезьяний хвост»: 1,1 л. Для четырёх кружек нужно 0,8 л, для двух бутылок — 2 л. Жидкость можно собрать из нескольких сосудов; остаток и исходная тара сохраняются.' if lang=='RU' else 'Eggnog yields 0.35 L; Monkey Tail yields 1.1 L. Four mugs require 0.8 L; two bottles require 2 L. Liquid may come from several containers; unused liquid and source vessels are retained.')
        path.write_text(json.dumps(names, ensure_ascii=False, indent=4)+'\n', encoding='utf-8')
    recipes = {name: body for p in SCRIPTS.rglob('*.txt') for _, _, name, body in blocks(read_text(p), 'craftRecipe')}
    for filename in ('food_count_migrations.json', 'liquid_input_migrations.json', 'physical_container_migrations.json', 'petrol_container_migrations.json'):
        path = REPO/'tools'/filename; record = json.loads(path.read_text(encoding='utf-8'))
        for field in ('migrations', 'protected_partial_inputs'):
            if field not in record: continue
            active = []
            for row in record[field]:
                expected = row.get('after', whole_input(row['input']) if field=='migrations' and 'input' in row else row.get('input', ''))
                if row['recipe'] in set(products)|empty_recipes and expected and expected not in recipes[row['recipe']]:
                    row['supersededBy'] = 'milk-cocktail-1.6'; record.setdefault('superseded_'+field, []).append(row)
                else: active.append(row)
            record[field] = active
        path.write_text(json.dumps(record, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
    print('Milk cocktails: 6 legacy families, 6 native recipes; no pending milk producers')


if __name__ == '__main__': main()

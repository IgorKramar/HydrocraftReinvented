"""Барные смеси: реальный выход, новые сосуды и сохранённые старые запасы."""
import json
import re
from apply_playability_fixes import blocks
from build_juice_catalog import lua
from build_water_catalog import props
from convert_water_recipes import callback
from hcr_paths import LUA, REPO, SCRIPTS, read_text
from repair_food_counts import whole_input

MIXERS = {'HCLemonmixer': ('LemonMixer', 'Lemon'), 'HCLimemixer': ('LimeMixer', 'Lime'),
          'HCBloodymarymixer': ('BloodyMaryMixer', 'Tomato')}
MODIFIERS = {'HCBitters': 'Bitters', 'HCVermouth': 'Vermouth', 'HCTriplesec': 'TripleSec'}
PRODUCERS = {'Make Lemon Mixer': 'HCLemonmixer', 'Make Lime Mixer': 'HCLimemixer',
             'Make Bloody Mary Mixer': 'HCBloodymarymixer'}


def main():
    items = {name: props(body) for path in SCRIPTS.rglob('*.txt')
             for _, _, name, body in blocks(read_text(path), 'item')}
    markers = {name: value[0] for name, value in MIXERS.items()} | MODIFIERS
    families = {}
    for name, marker in markers.items():
        spec = dict(target='Hydrocraft.'+name+'Fluid', fluid='HCR'+marker, litres=1, enabled=True)
        if name in MODIFIERS:
            spec.update(unitLitres=.025, legacyUses=40, policy='explicit-one-litre-bottle; 40 legacy uses; no invented Food effects')
        families['Hydrocraft.'+name] = spec
    products, consumers, changed, empty_recipes = {}, {}, set(), set()
    returns = {'WhiskeyEmpty': 'Base.Whiskey', 'WineEmpty': 'Base.Wine', 'WineEmpty2': 'Base.Wine2'}
    empty_aliases = {}
    for old in markers:
        p=items[old]; original=p.get('replaceonuse',p.get('replaceondeplete'))
        empty_aliases.setdefault(returns[original],[]).append('Hydrocraft.'+old+'Fluid')
    for path in SCRIPTS.rglob('*.txt'):
        text = previous = read_text(path)
        for start, end, name, body in reversed(list(blocks(text, 'craftRecipe'))):
            for old, marker in markers.items():
                def replace(match):
                    uses = int(match[1]); litres = uses*(.025 if old in MODIFIERS else .05)
                    return ('item 1 [*] mode:keep flags[ItemIsFluid;HandcraftOnly],\n'
                            f'            -fluid {litres:g} [HCR{marker}] mode:primary,')
                body = re.sub(r'item (\d+) \[Hydrocraft\.'+old+r'\],', replace, body)
            def alias(match):
                kinds=match[2].split(';')
                for base,new in empty_aliases.items():
                    if base in kinds:
                        for target in new:
                            if target not in kinds: kinds.append(target)
                        empty_recipes.add(name)
                return match[1]+';'.join(kinds)+match[3]
            body=re.sub(r'(item \d+ \[)([^\]]+)(\](?: mode:(?:destroy|keep))? flags\[ItemCount;ItemIsFluid;IsEmpty\],)',alias,body)
            if name in PRODUCERS:
                old = PRODUCERS[name]; target = 'Hydrocraft.'+old+'Fluid'
                products[name] = dict(target=target, marker='HCR'+markers[old], litres=.1)
                body = re.sub(r'(item 1 \[Base\.Whiskey[^\]]*\])(?: mode:destroy)?( flags\[ItemCount;ItemIsFluid;IsEmpty\],)', r'\1 mode:destroy\2', body)
                body = re.sub(r'outputs\s*\{[^}]*\}', 'outputs\n        {\n            item 1 '+target+',\n        }', body)
                body, _ = callback(body, 'OnCreate', 'HCRBarDrinks.create')
                body, _ = callback(body, 'Tooltip', 'Tooltip_HCR_MixerYield')
            inputs = body.split('inputs', 1)[-1].split('outputs', 1)[0]
            slots = {}
            lines = re.findall(r'item [^\n]+\n(?:\s*-fluid [^\n]+\n)?', inputs)
            if name in products:
                products[name]['foodSlots']={}
                for index,line in enumerate(lines):
                    if '-fluid' not in line and 'IsEmpty' not in line and 'mode:keep' not in line:
                        kinds=re.search(r'\[([^\]]+)\]',line)[1].split(';')
                        assert '*' not in kinds,name
                        products[name]['foodSlots'][index]={kind:True for kind in kinds}
            for index, line in enumerate(lines):
                match = re.search(r'-fluid [\d.]+ \[([^\]]+)\]', line)
                if match and any('HCR'+marker in match[1].split(';') for marker in markers.values()):
                    slots[index] = dict(fluids=match[1].split(';'))
            if slots: consumers[name] = dict(inputs=slots)
            if body != text[start:end]: changed.add(name)
            text = text[:start]+body+text[end:]
        if text != previous: path.write_text(text, encoding='utf-8')
    catalog = dict(families=families, products=products, consumers=consumers, emptyRecipes=sorted(empty_recipes))
    (REPO/'tools/bar_fluid_catalog.json').write_text(json.dumps(catalog, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
    (LUA/'shared/HCR_BarCatalog.lua').write_text('-- Генерируется tools/build_bar_fluids.py.\nrequire "HCR_DrinkFamilies"\nHCRBarCatalog='+lua(catalog)+'\n'
        'for kind,spec in pairs(HCRBarCatalog.families) do HCRDrinkFamilies[kind]=spec end\n', encoding='utf-8')
    script = ['module Hydrocraft', '{']
    for name in markers:
        p = items[name]
        script += [f'    item {name}Fluid', '    {', '        ItemType = base:normal,',
            '        DisplayCategory = WaterContainer,', f'        DisplayName = {p["displayname"]},',
            f'        Icon = {p["icon"]},', '        Weight = 0.2,', '        EatType = Bourbon,',
            '        Tags = base:glass;base:glassbottle,', '        component FluidContainer', '        {',
            '            ContainerName = Bottle,', '            Capacity = 1,',
            '            CustomDrinkSound = DrinkingFromBottleGlass,', '        }', '    }']
    script.append('}')
    (SCRIPTS/'HydrocraftReinvented/HCR_BarContainers.txt').write_text('\n'.join(script)+'\n', encoding='utf-8')
    for lang in ('RU', 'EN'):
        path = LUA/f'shared/Translate/{lang}/ItemName.json'
        names = json.loads(path.read_text(encoding='utf-8'))
        for name in markers: names['Hydrocraft.'+name+'Fluid'] = names.get('Hydrocraft.'+name, items[name]['displayname'])
        path.write_text(json.dumps(names, ensure_ascii=False, indent=4)+'\n', encoding='utf-8')
        path = LUA/f'shared/Translate/{lang}/Tooltip.json'
        names = json.loads(path.read_text(encoding='utf-8'))
        names['Tooltip_HCR_MixerYield'] = ('Выход: 0,1 л смеси из 0,1 л сока. Питание, свежесть и примеси переносятся из ингредиентов. Бутылка остаётся частично наполненной.' if lang=='RU' else 'Yield: 0.1 L of mixer from 0.1 L of juice. Nutrition, freshness and contaminants follow the ingredients. The bottle remains partly full.')
        path.write_text(json.dumps(names, ensure_ascii=False, indent=4)+'\n', encoding='utf-8')
    recipes = {name: body for path in SCRIPTS.rglob('*.txt') for _, _, name, body in blocks(read_text(path), 'craftRecipe')}
    for filename in ('food_count_migrations.json', 'liquid_input_migrations.json', 'physical_container_migrations.json'):
        path = REPO/'tools'/filename; record = json.loads(path.read_text(encoding='utf-8'))
        for field in ('migrations', 'protected_partial_inputs'):
            if field not in record: continue
            active = []
            for row in record[field]:
                expected = row.get('after', whole_input(row['input']) if field=='migrations' and 'input' in row else row.get('input', ''))
                if row['recipe'] in set(products)|set(consumers)|empty_recipes and expected and expected not in recipes[row['recipe']]:
                    row['supersededBy'] = 'bar-fluid-1.6'; record.setdefault('superseded_'+field, []).append(row)
                else: active.append(row)
            record[field] = active
        path.write_text(json.dumps(record, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
    print(f'Bar: {len(families)} migrations, {len(products)} mixers, {len(consumers)} consumers')


if __name__ == '__main__': main()

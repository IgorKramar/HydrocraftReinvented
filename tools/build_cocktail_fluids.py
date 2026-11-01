"""Готовые коктейли: реальный состав и отдельная тара без смены legacy-класса."""
import json
import re
from apply_playability_fixes import blocks
from build_juice_catalog import lua
from build_water_catalog import props
from convert_water_recipes import callback
from hcr_paths import LUA, REPO, SCRIPTS, read_text
from repair_food_counts import whole_input

# Названия, написание и рецепты опубликованной версии сохранены.
DRINKS = {
    'oldfashioned': ('OldFashioned', 'Short'), 'martini': ('Martini', 'Cocktail'),
    'manhattan': ('Manhattan', 'Cocktail'), 'daquiri': ('Daiquiri', 'Cocktail'),
    'bloodymary': ('BloodyMary', 'Tall'), 'whiskeysour': ('WhiskeySour', 'Short'),
    'maitai': ('MaiTai', 'Short'), 'cosmo': ('Cosmopolitan', 'Cocktail'),
    'tomcollins': ('TomCollins', 'Tall'), 'longisland': ('LongIsland', 'Tall'),
    'gimlet': ('Gimlet', 'Cocktail'), 'planterspunch': ('PlantersPunch', 'Short'),
    'whiskeyandcoke': ('WhiskeyCola', 'Tall'), 'margarita': ('Margarita', 'Margarita'),
}
SHAPES = {'Short': ('HCGlassshortempty', 'HCGlassshortFluid'),
          'Tall': ('HCGlasstallempty', 'HCGlasstallFluid'),
          'Cocktail': ('HCCocktailglassempty', 'HCCocktailglassFluid'),
          'Margarita': ('HCMargaritaglassempty',)}


def main():
    items = {name: props(body) for path in SCRIPTS.rglob('*.txt')
             for _, _, name, body in blocks(read_text(path), 'item')}
    products, consumers, families, empty_recipes = {}, {}, {}, set()
    aliases = {shape: ['Hydrocraft.HCDrink'+name+'Fluid' for name, (_, group) in DRINKS.items() if group == shape]
               for shape in SHAPES}
    for path in SCRIPTS.rglob('*.txt'):
        text = previous = read_text(path)
        for start, end, name, body in reversed(list(blocks(text, 'craftRecipe'))):
            # Прежние пустые бокалы и опустевшие новые — одна физическая тара.
            def alias(match):
                kinds = match[2].split(';')
                matched = False
                for shape, sources in SHAPES.items():
                    if 'Hydrocraft.'+sources[0] in kinds:
                        matched = True
                        for kind in aliases[shape]:
                            if kind not in kinds: kinds.append(kind)
                        empty_recipes.add(name)
                if not matched: return match[0]
                return match[1]+';'.join(kinds)+'] mode:destroy flags[ItemCount;IsEmpty],'
            body = re.sub(r'(item \d+ \[)([^\]]+)(\](?: mode:destroy)?(?: flags\[ItemCount;IsEmpty\])?,)', alias, body)
            output = re.search(r'outputs\s*\{\s*item 1 Hydrocraft\.(HCDrink(?:'+ '|'.join(DRINKS)+r')|HCCoffeeirish2?)(?:Fluid)?,', body)
            if output or name.startswith('Brew Irish Coffee'):
                old = ('HCCoffeeirish2' if name.endswith(('(Cup of Irish Coffee)', '(Cup of Irish Coffee 3)')) else 'HCCoffeeirish') if name.startswith('Brew Irish Coffee') else output[1]
                irish = old.startswith('HCCoffeeirish')
                marker = 'HCRIrishCoffee' if irish else 'HCR'+DRINKS[old[7:]][0]
                target = ('Hydrocraft.HCClaymugFluid' if old.endswith('2') else 'Base.Mugl') if irish else 'Hydrocraft.'+old+'Fluid'
                if irish:
                    body = re.sub(r'(item 1 \[[^\]]+\])(?: mode:destroy)?( flags\[ItemCount;ItemIsFluid;IsEmpty\],)', r'\1 mode:destroy\2', body)
                lines = re.findall(r'item [^\n]+\n(?:\s*-fluid [^\n]+\n)?', body.split('inputs', 1)[1].split('outputs', 1)[0])
                slots, foods, litres = {}, {}, 0
                for index, line in enumerate(lines):
                    fluid = re.search(r'-fluid ([\d.]+) \[([^\]]+)\]', line)
                    if fluid:
                        amount = float(fluid[1]); litres += amount
                        slots[index] = dict(fluids=fluid[2].split(';'), nativeWine=marker)
                        if 'mode:destroy' in line:
                            slots[index].update(nativeSink=True, exact=amount)
                        elif irish and index == 3:
                            slots[index]['exact'] = amount
                    elif 'mode:keep' not in line and 'IsEmpty' not in line:
                        kinds = re.search(r'\[([^\]]+)\]', line)[1].split(';')
                        foods[index] = {kind: True for kind in kinds}
                litres = round(litres, 12)
                products[name] = dict(target=target, marker=marker, litres=litres, foodSlots=foods)
                consumers[name] = dict(inputs=slots)
                spec = families.setdefault('Hydrocraft.'+old, dict(target=target, fluid=marker, litres=litres, enabled=True))
                spec['litres'] = max(spec['litres'], litres)
                body = re.sub(r'outputs\s*\{[^}]*\}', 'outputs\n        {\n            item 1 '+target+',\n        }', body)
                body, _ = callback(body, 'OnCreate', 'HCRBarDrinks.create')
                body, _ = callback(body, 'Tooltip', 'Tooltip_HCR_CocktailYield')
            text = text[:start]+body+text[end:]
        if text != previous: path.write_text(text, encoding='utf-8')
    assert (len(families), len(products)) == (16, 19), (len(families), len(products))
    families['Hydrocraft.HCDrinkwhiskeyandcoke']['policy'] = 'legacy-unknown-recipe-origin: 0.4 L; original Food budgets retained'
    catalog = dict(families=families, products=products, consumers=consumers, emptyRecipes=sorted(empty_recipes))
    (REPO/'tools/cocktail_fluid_catalog.json').write_text(json.dumps(catalog, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
    (LUA/'shared/HCR_CocktailCatalog.lua').write_text('-- Генерируется tools/build_cocktail_fluids.py.\nrequire "HCR_BarCatalog"\nHCRCocktailCatalog='+lua(catalog)+'\n'
        'for kind,spec in pairs(HCRCocktailCatalog.families) do HCRDrinkFamilies[kind]=spec end\n'
        'for name,rule in pairs(HCRCocktailCatalog.products) do HCRBarCatalog.products[name]=rule end\n', encoding='utf-8')
    script = ['module Hydrocraft', '{']
    for suffix, (_, shape) in DRINKS.items():
        old = 'HCDrink'+suffix; p = items[old]; empty = items[SHAPES[shape][0]]
        script += [f'    item {old}Fluid', '    {', '        ItemType = base:normal,',
            '        DisplayCategory = WaterContainer,', f'        DisplayName = {p["displayname"]},',
            f'        Icon = {p["icon"]},', f'        Weight = {empty["weight"]},',
            '        EatType = Mug,', '        Tags = base:glass,', '        component FluidContainer', '        {',
            '            ContainerName = Glass,', '            Capacity = 0.5,',
            '            CustomDrinkSound = DrinkingFromGlass,', '        }', '    }']
    (SCRIPTS/'HydrocraftReinvented/HCR_CocktailContainers.txt').write_text('\n'.join(script+['}'])+'\n', encoding='utf-8')
    for lang in ('RU', 'EN'):
        path = LUA/f'shared/Translate/{lang}/ItemName.json'; names = json.loads(path.read_text(encoding='utf-8'))
        for suffix in DRINKS:
            kind = 'Hydrocraft.HCDrink'+suffix; names[kind+'Fluid'] = names.get(kind, items['HCDrink'+suffix]['displayname'])
        path.write_text(json.dumps(names, ensure_ascii=False, indent=4)+'\n', encoding='utf-8')
        path = LUA/f'shared/Translate/{lang}/Tooltip.json'; names = json.loads(path.read_text(encoding='utf-8'))
        names['Tooltip_HCR_CocktailYield'] = ('Объём и свойства складываются из использованных ингредиентов. Остатки в исходных сосудах сохраняются; свежесть и примеси переходят в напиток.' if lang=='RU' else 'Volume and properties follow the ingredients used. Liquids left in the source containers are retained; freshness and contaminants carry into the drink.')
        path.write_text(json.dumps(names, ensure_ascii=False, indent=4)+'\n', encoding='utf-8')
    recipes = {name: body for path in SCRIPTS.rglob('*.txt') for _, _, name, body in blocks(read_text(path), 'craftRecipe')}
    for filename in ('food_count_migrations.json', 'liquid_input_migrations.json', 'physical_container_migrations.json', 'petrol_container_migrations.json'):
        path = REPO/'tools'/filename; record = json.loads(path.read_text(encoding='utf-8'))
        for field in ('migrations', 'protected_partial_inputs'):
            if field not in record: continue
            active = []
            for row in record[field]:
                expected = row.get('after', whole_input(row['input']) if field=='migrations' and 'input' in row else row.get('input', ''))
                if row['recipe'] in set(products)|empty_recipes and expected and expected not in recipes[row['recipe']]:
                    row['supersededBy'] = 'cocktail-fluid-1.6'; record.setdefault('superseded_'+field, []).append(row)
                else: active.append(row)
            record[field] = active
        path.write_text(json.dumps(record, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
    print(f'Cocktails: {len(families)} migrations, {len(products)} recipes, {len(empty_recipes)} empty aliases')


if __name__ == '__main__': main()

"""Замкнутые спиртные напитки: бутылки, разлив, бокалы и их потребители."""
import json
import re
from apply_playability_fixes import blocks
from build_juice_catalog import lua
from build_water_catalog import props
from hcr_paths import LUA, REPO, SCRIPTS, read_text
from repair_food_counts import whole_input

BOTTLES = {
    'HCVodka': 'Vodka', 'HCVodka1': 'Vodka', 'HCVodka2': 'Vodka',
    'HCGin1': 'Gin', 'HCGin2': 'Gin', 'HCGin3': 'Gin',
    **{'HCWhiskey'+str(n): 'Whiskey' for n in range(1, 5)},
    'HCWhiskeycorn': 'WhiskeyCorn', 'HCTequila': 'Tequila', 'HCMezcal': 'Mezcal',
    'HCApplejack': 'Applejack', 'HCPeachschnapps': 'PeachSchnapps', 'HCFlip': 'Flip',
    'HCBourbon1': 'Whiskey', 'HCBourbon2': 'Whiskey', 'HCScotch1': 'Whiskey', 'HCRum1': 'Rum',
    'HCAbsinth': 'Absinthe', 'HCHerballiqueur': 'HerbalLiqueur', 'HCMead2': 'Mead', 'HCAguaardiente': 'Aguardiente',
}
GLASSES = {
    'Short': ('HCGlassshortempty', 'HCGlassshortFluid', 'glassshort', .2),
    'Tall': ('HCGlasstallempty', 'HCGlasstallFluid', 'glasstall', .3),
    'Cocktail': ('HCCocktailglassempty', 'HCCocktailglassFluid', 'cocktailglass', .2),
}


def main():
    items = {name: props(body) for path in SCRIPTS.rglob('*.txt')
             for _, _, name, body in blocks(read_text(path), 'item')}
    families = {'Hydrocraft.'+name: dict(target='Hydrocraft.'+name+'Fluid',
                fluid='HCR'+marker, litres=1, enabled=True) for name, marker in BOTTLES.items()}
    families['Hydrocraft.HCAguaardiente']['remaining'] = 'native-zero-hunger-thirst'
    for _, target, suffix, _ in GLASSES.values():
        for drink in ('gin', 'whiskey', 'vodka', 'rum'):
            families['Hydrocraft.HCDrink'+suffix+drink] = dict(target='Hydrocraft.'+target,
                fluid='HCR'+drink.title(), litres=.1, enabled=True)
    pours, consumers, outputs, empty_recipes = {}, {}, {}, []
    reusable = ['Hydrocraft.'+name+'Fluid' for name in BOTTLES if name != 'HCMezcal']
    for path in SCRIPTS.rglob('*.txt'):
        text = read_text(path)
        previous = text
        for start, end, name, body in reversed(list(blocks(text, 'craftRecipe'))):
            if name.startswith('Distill '):
                for source, marker in BOTTLES.items():
                    pattern = r'item 20 Hydrocraft\.'+source+r'(?:Fluid)?,'
                    if re.search(pattern, body):
                        target = 'Hydrocraft.'+source+'Fluid'
                        body = re.sub(pattern, 'item 20 '+target+',', body)
                        outputs[name] = dict(target=target, marker='HCR'+marker, count=20,
                                             sourceFood='Hydrocraft.'+source, empty=True)
            match = re.fullmatch(r'Pour (Short|Tall|Cocktail) Glass of (Gin|Whiskey|Vodka|Rum)( \(Bottled Whiskey\))?', name)
            if match:
                shape, drink, native = match.groups()
                empty, target, suffix, _ = GLASSES[shape]
                markers = ['Whiskey'] if native else (['HCRWhiskey', 'HCRWhiskeyCorn', 'Whiskey'] if drink == 'Whiskey' else ['HCR'+drink])
                body = re.sub(r'item (?:1|2) \[[^\]\n]+\](?: mode:keep flags\[ItemIsFluid;HandcraftOnly\])?,\n(?:\s*-fluid 0.1 \[[^\]]+\](?: mode:primary)?,\n)?(?=\s*}\s*outputs)',
                    'item 1 [*] mode:keep flags[ItemIsFluid;HandcraftOnly],\n            -fluid 0.1 ['+';'.join(markers)+'] mode:primary,\n', body)
                body = re.sub(r'item 1 Hydrocraft\.(?:HCDrink'+suffix+drink.lower()+'|'+target+'),', 'item 1 Hydrocraft.'+target+',', body)
                pours[name] = dict(slots={1: True}, fluids=markers, target='Hydrocraft.'+target, count=1, litres=.1)
                if drink=='Whiskey': pours[name]['nativeWine'] = 'HCRWhiskey'
            # Полный бокал был тарой готового коктейля. Расходуем именно его,
            # сохраняя отдельную тару виски в рецептах ирландского кофе.
            # Один напиток уже находится в своём бокале: второй пустой бокал
            # в старом Planter's Punch исчезал без результата и не требуется.
            if name == "Mix Planter's Punch":
                body = re.sub(r'            item 1 \[Hydrocraft\.HCGlassshortempty;Hydrocraft\.HCGlassshortFluid\] flags\[ItemCount;IsEmpty\],\n', '', body)
            full = re.search(r'item 1 \[(Hydrocraft\.HCDrink(?:glassshort|glasstall|cocktailglass)(?:gin|whiskey|vodka|rum)[^\]]*)\] flags\[ItemCount\],', body)
            if full:
                source = full[1].split(';')[0]
                spec = families[source]
                slot = len(re.findall(r'\bitem \d+ \[', body[:full.start()]))
                irish = name.startswith('Brew Irish Coffee')
                targets = list(dict.fromkeys(families[s]['target'] for s in full[1].split(';')))
                markers = [spec['fluid']]+(['HCRWhiskeyCorn','Whiskey'] if spec['fluid']=='HCRWhiskey' else [])
                body = body[:full.start()]+'item 1 ['+';'.join(targets)+']'+(' mode:keep' if irish else ' mode:destroy')+' flags[ItemCount;ItemIsFluid;HandcraftOnly],\n            -fluid 0.1 ['+';'.join(markers)+'] mode:primary,'+body[full.end():]
                consumers[name] = dict(inputs={slot: dict(fluids=markers,
                    nativeSink=not irish, exact=.1)})
            elif name.startswith('Brew Irish Coffee') or name in ('Mix Old Fashioned', 'Mix Martini', 'Mix Manhattan',
                    'Mix Bloody Mary', 'Mix Whiskey Sour', 'Mix Cosmopolitan', 'Mix Tom Collins',
                    'Mix Long Island Iced Tea', 'Mix Gimlet', 'Whiskey and Coke', 'Whiskey and Coke (Canned Cola)',
                    'Mix Daquiri', 'Mix Mai Tai', "Mix Planter's Punch"):
                # Повторный запуск читает уже перенесённый вход.
                lines = re.findall(r'item \d+ \[[^\]]+\][^\n]*\n(?:\s*-fluid [^\n]+\n)?', body)
                for slot, line in enumerate(lines):
                    if any(target in line for _, target, _, _ in GLASSES.values()) and '-fluid' in line:
                        markers = re.search(r'-fluid 0.1 \[([^\]]+)\]', line)[1].split(';')
                        irish = name.startswith('Brew Irish Coffee')
                        if 'HCRWhiskey' in markers and 'Whiskey' not in markers: markers.append('Whiskey')
                        updated=re.sub(r'-fluid 0.1 \[[^\]]+\](?: mode:primary)?', '-fluid 0.1 ['+';'.join(markers)+'] mode:primary',line)
                        if not irish: updated=updated.replace('] flags[ItemCount;', '] mode:destroy flags[ItemCount;')
                        body=body.replace(line,updated)
                        consumers[name] = dict(inputs={slot: dict(fluids=markers, nativeSink=not irish, exact=.1)})
            if name == 'Mix Long Island Iced Tea':
                body = body.replace('item 2 [Hydrocraft.HCRum1],',
                    'item 1 [*] mode:keep flags[ItemIsFluid;HandcraftOnly],\n            -fluid 0.1 [HCRRum] mode:primary,')
                consumers[name]['inputs'][2] = dict(fluids=['HCRRum'])
            if name.startswith('Make Monkey Tail Pot'):
                body = body.replace('item 1 [Hydrocraft.HCAguaardiente] flags[ItemCount],',
                    'item 1 [*] mode:keep flags[ItemIsFluid;HandcraftOnly],\n            -fluid 1 [HCRAguardiente] mode:primary,')
                consumers[name] = dict(inputs={2: dict(fluids=['HCRAguardiente'])})
                milk=re.search(r'-fluid 0.1 \[(HCRMilk;[^\]]+)\]',body)
                if milk:
                    consumers[name]['inputs'][0] = dict(fluids=milk[1].split(';'),nativeMilk=True)
            if name == 'Mix Margarita':
                body = body.replace('item 2 [Hydrocraft.HCTequila],',
                    'item 1 [*] mode:keep flags[ItemIsFluid;HandcraftOnly],\n            -fluid 0.1 [HCRTequila],')
                consumers[name] = dict(inputs={2: dict(fluids=['HCRTequila'])})
                body=body.replace('-fluid 0.1 [HCRTequila],','-fluid 0.1 [HCRTequila] mode:primary,')
            # Старые пустые Normal ID остаются читаемыми; оба вида тары пригодны.
            for empty, target, _, _ in GLASSES.values():
                body = re.sub(r'item 1 \[Hydrocraft\.'+empty+r'(?:;Hydrocraft\.'+target+r')?\](?: flags\[ItemCount;IsEmpty\])?,',
                    f'item 1 [Hydrocraft.{empty};Hydrocraft.{target}] flags[ItemCount;IsEmpty],', body)
            # Израсходованная новая бутылка заменяет прежнюю пустую Whiskey.
            # Бутылка с червём намеренно исключена: прежде её не использовали.
            def bottle_alias(match):
                kinds = match[2].split(';')
                for kind in reusable:
                    if kind not in kinds: kinds.append(kind)
                empty_recipes.append(name)
                return match[1]+';'.join(kinds)+match[3]
            body = re.sub(r'(item \d+ \[)(Base\.Whiskey(?:;[^\]]+)?)(\](?: mode:(?:destroy|keep))? flags\[ItemCount;ItemIsFluid;IsEmpty\],)', bottle_alias, body)
            if name.startswith('Brew Irish Coffee'):
                body = body.replace('item 1 [Base.Mugl] flags[ItemCount],', 'item 1 [Base.Mugl] flags[ItemCount;ItemIsFluid;IsEmpty],')
            text = text[:start]+body+text[end:]
        if text != previous: path.write_text(text, encoding='utf-8')
    assert (len(families), len(pours), len(consumers), len(outputs)) == (36, 15, 20, 8)
    config = dict(families=families, pours=pours, consumers=consumers, outputs=outputs, emptyRecipes=sorted(empty_recipes))
    (REPO/'tools/spirit_fluid_catalog.json').write_text(json.dumps(config, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
    (LUA/'shared/HCR_SpiritCatalog.lua').write_text('-- Генерируется tools/build_spirit_fluids.py.\nrequire "HCR_DrinkFamilies"\nHCRSpiritCatalog='+lua(config)+'\n'
        'for kind,spec in pairs(HCRSpiritCatalog.families) do HCRDrinkFamilies[kind]=spec end\n', encoding='utf-8')
    script = ['module Hydrocraft', '{']
    vessels = [(name+'Fluid', name, 1, .2) for name in BOTTLES]
    vessels += [(target, empty, .1, weight) for empty, target, _, weight in GLASSES.values()]
    for target, source, capacity, weight in vessels:
        p = items[source]
        glass = capacity == .1
        icon = 'HCMezcalemptyworm' if source == 'HCMezcal' else p['icon']
        script += [f'    item {target}', '    {', '        ItemType = base:normal,', '        DisplayCategory = WaterContainer,',
            f'        DisplayName = {p["displayname"]},', f'        Weight = {weight},', f'        Icon = {icon},',
            '        EatType = '+('Mug' if glass else 'Bourbon')+',', '        Tags = base:glass'+('' if glass else ';base:glassbottle')+',',
            '        component FluidContainer', '        {', '            ContainerName = '+('Glass' if glass else 'Bottle')+',',
            f'            Capacity = {capacity},', '            CustomDrinkSound = '+('DrinkingFromGlass' if glass else 'DrinkingFromBottleGlass')+',',
            '        }', '    }']
    script += ['}']
    (SCRIPTS/'HydrocraftReinvented/HCR_SpiritContainers.txt').write_text('\n'.join(script)+'\n', encoding='utf-8')
    for lang in ('RU', 'EN'):
        path = LUA/f'shared/Translate/{lang}/ItemName.json'
        names = json.loads(path.read_text(encoding='utf-8'))
        for target, source, _, _ in vessels: names['Hydrocraft.'+target] = names.get('Hydrocraft.'+source, items[source]['displayname'])
        names['Hydrocraft.HCRCookingHerbalSpirit'] = 'Порция травяного спиртного для готовки' if lang=='RU' else 'Herbal Spirit for Cooking'
        path.write_text(json.dumps(names, ensure_ascii=False, indent=4)+'\n', encoding='utf-8')
        path = LUA/f'shared/Translate/{lang}/Recipes.json'
        names = json.loads(path.read_text(encoding='utf-8'))
        names['Prepare Herbal Spirit for Cooking'] = 'Отмерить травяное спиртное для готовки' if lang=='RU' else 'Prepare Herbal Spirit for Cooking'
        path.write_text(json.dumps(names, ensure_ascii=False, indent=4)+'\n', encoding='utf-8')
        path = LUA/f'shared/Translate/{lang}/Tooltip.json'
        names = json.loads(path.read_text(encoding='utf-8'))
        names['Tooltip_HCR_CookingHerbalSpirit'] = ('Отмерить 0,8 л абсента или травяного ликёра в пустую бутылку для готовки. Остаток, питание, свежесть и яд сохраняются.' if lang=='RU' else 'Measure 0.8 L of absinthe or herbal liqueur into an empty bottle for cooking. The remainder, nutrition, freshness and poison are retained.')
        names['Tooltip_HCR_LegacyAguardiente'] = ('Можно пить или использовать в коктейле «Обезьяний хвост». Старый напиток без насыщения нельзя добавлять в супы, рагу и горячие напитки.' if lang=='RU' else 'Drink as it is or use in Monkey Tail. Legacy stock with no hunger value cannot be added to soups, stews or hot drinks.')
        path.write_text(json.dumps(names, ensure_ascii=False, indent=4)+'\n', encoding='utf-8')
    path = SCRIPTS/'HydrocraftReinvented/HCR_AlcoholPortions.txt'
    text = read_text(path).replace('[HCRGin;HCRWhiskeyCorn;', '[HCRGin;HCRWhiskey;HCRVodka;HCRWhiskeyCorn;')
    text = text.replace('HCRWhiskeyCorn;HCRTequila;', 'HCRWhiskeyCorn;HCRRum;HCRTequila;')
    path.write_text(text, encoding='utf-8')
    # Исторические доказательства сохраняются, но новый fluid-вход заменяет
    # прежнее точное написание Food/empty alias. Новая проверка — весь каталог.
    changed = set(pours)|set(consumers)|set(outputs)|set(empty_recipes)
    recipes = {name: body for path in SCRIPTS.rglob('*.txt')
               for _, _, name, body in blocks(read_text(path), 'craftRecipe')}
    for filename in ('food_count_migrations.json', 'liquid_input_migrations.json', 'physical_container_migrations.json'):
        path = REPO/'tools'/filename
        record = json.loads(path.read_text(encoding='utf-8'))
        for field in ('migrations', 'protected_partial_inputs'):
            if field not in record: continue
            active = []
            for row in record[field]:
                expected = row.get('after', whole_input(row['input']) if field=='migrations' and 'input' in row else row.get('input', ''))
                if row['recipe'] in changed and expected and expected not in recipes[row['recipe']]:
                    row['supersededBy'] = 'spirit-fluid-1.6'
                    record.setdefault('superseded_'+field, []).append(row)
                else: active.append(row)
            record[field] = active
        path.write_text(json.dumps(record, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
    print(f'Spirits: {len(families)} migrations, 27 vessels, {len(outputs)} distillations, {len(pours)} pours, {len(consumers)} consumers; empty bottle recipes={len(empty_recipes)}')


if __name__ == '__main__': main()

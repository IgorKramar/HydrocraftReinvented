"""Соки и старые цитрусовые добавки после переноса потребляющих рецептов.

Старые Food-объявления остаются загрузочными прототипами. Литраж определяется
native вместимостью возвращаемой посуды; старый Food литры не хранил.
"""
import hashlib
import json
import math
import re
from apply_playability_fixes import blocks
from build_water_catalog import props
from convert_water_recipes import callback, flags
from hcr_paths import LUA, REPO, SCRIPTS, read_text

SERIES = {
    'HCPopbottle': ('Base.PopBottle', 2),
    'HCWaterbottle': ('Base.WaterBottle', 1),
    'HCRemoulade': ('Base.RemouladeEmpty', 2),
    'HCMayonnaise': ('Base.MayonnaiseEmpty', .2),
    'HCWhiskey': ('Base.Whiskey', 1),
    'HCClingmug': ('Base.Mugl', .2),
}
FLAVOURS = ('Apple', 'Carrot', 'Grape', 'Lemon', 'Orange', 'Lime', 'Strawberry',
            'Tomato', 'Watermelon', 'Pineapple', 'Blueberry', 'Blackberry', 'Wildberry', 'Cherry')
PATH = SCRIPTS / 'HydrocraftReinvented/HCR_Food Juice.txt'
DRIED = SCRIPTS / 'HydrocraftReinvented/HCR_Food Dried.txt'
MANIFEST = REPO / 'tools/juice_recipe_rules.json'


def catalogue():
    items = {name: props(body) for _, _, name, body in blocks(read_text(PATH), 'item')}
    result = {}
    for prefix, (target, litres) in SERIES.items():
        for flavour in FLAVOURS:
            name = prefix + flavour.lower() + 'juice'
            assert items[name]['itemtype'] == 'base:food', name
            result['Hydrocraft.' + name] = dict(target=target, litres=litres,
                fluid='HCRJuice' + flavour, enabled=True,
                policy='native-vessel-capacity; remaining=rawHunger/ownBaseHunger')
    for flavour in ('Lemon', 'Lime'):
        result[f'Hydrocraft.HC{flavour}juicebowl'] = dict(target='Base.Bowl', litres=.3,
            fluid='HCRJuice'+flavour, enabled=True,
            policy='native-vessel-capacity; remaining=rawHunger/ownBaseHunger')
        # Старый Drainable не содержит питание/свежесть и имеет четыре use.
        # Один use теперь равен единой порции 0.1 L; бутылка заполнена на 0.4 L.
        result[f'Hydrocraft.HC{flavour}juicebottle'] = dict(target='Base.WaterBottle', litres=.4,
            fluid='HCRJuice'+flavour, enabled=True, unitLitres=.1, legacyUses=4,
            policy='native-integer-uses; zero-authored-food-effects', lootOnly=True)
    return result


def lua(value):
    if value is None:
        return 'nil'
    if isinstance(value, str):
        return json.dumps(value, ensure_ascii=False)
    if isinstance(value, bool):
        return 'true' if value else 'false'
    if isinstance(value, (list, tuple)):
        return '{' + ','.join(lua(entry) for entry in value) + '}'
    if isinstance(value, dict):
        return '{' + ','.join('[' + lua(k) + ']=' + lua(v) for k, v in value.items()) + '}'
    return str(value)


def convert(path, catalog, rules):
    text = read_text(path)
    changed = 0
    for start, end, name, body in reversed(list(blocks(text, 'craftRecipe'))):
        if 'HCRDrinkRecipes.Create_' in body:
            continue
        outputs = re.search(r'outputs\s*\{\s*item (\d+) (Hydrocraft\.\w+),\s*\}', body)
        if not outputs or outputs[2] not in catalog or not catalog[outputs[2]]['enabled']:
            continue
        count = int(outputs[1])
        spec = catalog[outputs[2]]
        inputs = re.search(r'inputs\s*\{([^}]*)\}', body)[1]
        lines = re.findall(r'(?m)^\s*item [^\r\n]+', inputs)
        vessel = [(i, line) for i, line in enumerate(lines)
                  if f'[{spec["target"]}]' in line and 'mode:destroy' in line]
        assert len(vessel) == 1, name
        slot, line = vessel[0]
        assert int(re.search(r'item (\d+)', line)[1]) == count, name
        converted = flags(line.replace('mode:destroy', 'mode:keep'), 'IsEmpty')
        body = body.replace(line, converted, 1)
        # Пустой outputs разрешён: OnCreate наполняет сохранённый сосуд.
        body = body.replace(outputs[0], 'outputs\n        {\n        }')
        token = hashlib.sha256(name.encode()).hexdigest()[:12]
        body, previous_test = callback(body, 'OnTest', 'HCRDrinkRecipes.Test_' + token)
        body, previous_create = callback(body, 'OnCreate', 'HCRDrinkRecipes.Create_' + token)
        assert not previous_test and not previous_create, (name, previous_test, previous_create)
        rules[token] = dict(name=name, sourceFood=outputs[2], target=spec['target'], count=count,
                            fluid=spec['fluid'], litres=spec['litres'], vesselSlot=slot,
                            freshDays=3, rottenDays=7, nutrition='consumed-fruit')
        text = text[:start] + body + text[end:]
        changed += 1
    for rule in rules.values():
        rule.setdefault('count', 1)
        rule.setdefault('legacyCount', rule['count'])
        # В старых рецептах кружка требует половину фруктов от бутылки.
        # Выход зависит от исходной партии, а не от вместимости новой посуды.
        rule['batchLitres'] = rule['legacyCount'] * (.5 if rule['target'] == 'Base.Mugl' else 1)
        capacity = catalog[rule['sourceFood']]['litres']
        rule['litres'] = min(capacity, rule['batchLitres'])
        rule['count'] = math.ceil(rule['batchLitres']/capacity - 1e-8)
    names = {r['name']: (token, r) for token, r in rules.items()}
    source_items = {name: props(body) for _, _, name, body in blocks(text, 'item')}
    for start, end, name, body in reversed(list(blocks(text, 'craftRecipe'))):
        if name not in names:
            continue
        token, rule = names[name]
        vessel = re.compile(r'(item )\d+( \[' + re.escape(rule['target']) + r'\] mode:keep)')
        body, replacements = vessel.subn(lambda m: m[1]+str(rule['count'])+m[2], body)
        assert replacements == 1, name
        if rule['target'] == 'Base.Mugl':
            body = re.sub(r'item \d+ \[Hydrocraft.HCSaranwrap\]',
                          f'item {rule["count"]} [Hydrocraft.HCSaranwrap]', body)
        body, _ = callback(body, 'Tooltip', 'Tooltip_HCR_Juice_' + token)
        body, _ = callback(body, 'Icon', source_items[rule['sourceFood'].split('.')[1]]['icon'])
        text = text[:start] + body + text[end:]
    path.write_text(text, encoding='utf-8')
    return changed


def main():
    catalog = catalogue()
    rules = json.loads(MANIFEST.read_text(encoding='utf-8')) if MANIFEST.exists() else {}
    changed = sum(convert(path, catalog, rules) for path in (PATH, DRIED))
    for lang in ('EN', 'RU'):
        path = LUA / f'shared/Translate/{lang}/Tooltip.json'
        translations = json.loads(path.read_text(encoding='utf-8'))
        for token, rule in rules.items():
            amount = f'{rule["batchLitres"]:g}'
            translations['Tooltip_HCR_Juice_' + token] = (
                f'Yield: {amount} L. Empty vessels: {rule["count"]}; the last may be partly filled. Freshness depends on the fruit.' if lang == 'EN' else
                f'Выход: {amount} л. Пустая тара: {rule["count"]} шт.; последний сосуд может быть наполнен частично. Свежесть зависит от фруктов.')
        path.write_text(json.dumps(translations, ensure_ascii=False, indent=4)+'\n', encoding='utf-8')
    MANIFEST.write_text(json.dumps(rules, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
    physical_path = REPO / 'tools/physical_container_migrations.json'
    physical = json.loads(physical_path.read_text(encoding='utf-8'))
    converted_names = {r['name'] for r in rules.values()}
    remaining = []
    for row in physical['migrations']:
        if row['file'] in (PATH.name, DRIED.name) and row['recipe'] in converted_names:
            row['supersededBy'] = 'juice-1.6: fill the same empty vessel'
            physical['superseded_migrations'].append(row)
        else:
            remaining.append(row)
    physical['migrations'] = remaining
    physical_path.write_text(json.dumps(physical, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
    (REPO / 'tools/drink_families.json').write_text(json.dumps(catalog, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
    for name, data in [('HCR_DrinkFamilies', catalog), ('HCR_JuiceRecipeRules', rules)]:
        global_name = {'HCR_DrinkFamilies':'HCRDrinkFamilies', 'HCR_JuiceRecipeRules':'HCRJuiceRecipeRules'}[name]
        lines = ['-- Генерируется tools/build_juice_catalog.py.', global_name + ' = {']
        lines += ['    ['+lua(k)+'] = '+lua(v)+',' for k, v in sorted(data.items())]
        lines += ['}']
        (LUA / 'shared' / (name + '.lua')).write_text('\n'.join(lines)+'\n', encoding='utf-8')
    print(f'Juice catalogue {len(catalog)}; enabled {sum(x["enabled"] for x in catalog.values())}; recipes {len(rules)}; changed {changed}')


if __name__ == '__main__':
    main()

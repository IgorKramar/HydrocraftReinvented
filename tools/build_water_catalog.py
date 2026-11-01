"""Каталог нативной водяной тары из неизменяемых legacy-объявлений.

Не меняет Java-классы старых ID. Литраж воды сохраняет игровую шкалу
0,1 л/use; новые недостающие ёмкости имеют явно записанные решения баланса.
"""
import json
import math
import re
from pathlib import Path

from apply_playability_fixes import blocks
from hcr_paths import REPO, SCRIPTS, LUA, read_text

OUT = SCRIPTS / 'HydrocraftReinvented/HCR_FluidContainers.txt'


def props(body):
    return {m[1].lower(): m[2].strip() for m in re.finditer(
        r'(?im)^\s*(\w+)\s*=\s*([^,\r\n]+)', body)}


def collect():
    records = {}
    for path in sorted(SCRIPTS.rglob('*.txt')):
        if path == OUT:
            continue
        for _, _, name, body in blocks(read_text(path), 'item'):
            records[name] = {'file': path.name, 'body': body, 'properties': props(body)}
    water = {n: r for n, r in records.items()
             if r['properties'].get('canstorewater', '').lower() == 'true'
             and not re.search(r'\bcomponent\s+FluidContainer\b', r['body'])}
    full = {n: r for n, r in water.items()
            if r['properties'].get('iswatersource', '').lower() == 'true'}
    empty = {n: r for n, r in water.items() if n not in full}
    targets = {}
    migration = {}
    corrections = {'HCAlestienfull': 'HCAlestien', 'HCFishbowlfull': 'HCFishbowl'}
    for name, record in full.items():
        p = record['properties']
        base = corrections.get(name, p['replaceondeplete'])
        delta = float(p.get('usedelta', '0.03125'))
        # B42 setCurrentUsesFloat(1) uses Math.round, not floor. At .08 this
        # produces 13 uses; a 1.2 L target would strand a valid full old vessel.
        uses = int(math.floor(1 / delta + .5))
        capacity = round(uses * .1, 6)
        targets[base] = {'capacity': capacity, 'source': base if base in records else name,
                         'basis': f'legacy water {uses} uses × 0.1 L'}
        migration[name] = {'target': base + 'Fluid', 'unitLitres': .1,
                           'fluid': 'TaintedWater', 'legacyClass': p['itemtype']}
    # Рецепты виноделия используют то же ведро: 5 вёдер → 20 литровых бутылок.
    # Большая новая вместимость не увеличивает старый остаток воды при переносе.
    targets['HCWoodenbucket']['capacity'] = 4
    targets['HCWoodenbucket']['basis'] += '; new vessel 4 L for shared wine/milk chains'
    targets['HCMilkjugempty']['capacity'] = 2
    targets['HCMilkjugempty']['basis'] += '; milk recipes establish a 2 L jug'
    targets['HCMilkjugchocolateempty']['capacity'] = 2
    targets['HCMilkjugchocolateempty']['basis'] += '; chocolate milk shares the 2 L milk jug'
    # Отсутствовавшие full ID не задавали объём. Это новые решения, не upstream-цифры.
    for name, capacity, basis in [
        ('HCClaycauldron', 8, 'new: capacity matches the HC iron cauldron'),
        ('HCWell', 32, 'new: capacity matches the HC vat'),
        ('HCDutchoven', 6, 'new: six-litre rain-catching cast-iron cooking vessel'),
    ]:
        targets[name] = {'capacity': capacity, 'source': name, 'basis': basis}
        empty[name] = records[name]
    for name, record in empty.items():
        if name not in targets:
            filled = record['properties'].get('replaceonuseon', '').removeprefix('WaterSource-')
            # Пустая пластиковая канистра ошибочно ссылалась на detergentwater.
            full_record = full.get(filled)
            if not full_record:
                raise ValueError(f'No reviewed capacity for {name}: {filled}')
            delta = float(full_record['properties'].get('usedelta', '.03125'))
            targets[name] = {'capacity': round(math.floor(1 / delta + .5) * .1, 6),
                             'source': name, 'basis': f'water fill alias of {filled}'}
        migration[name] = {'target': name + 'Fluid', 'unitLitres': 0,
                           'legacyClass': record['properties']['itemtype']}
    # У чайника отсутствовал empty ID; нативный чайник получается из full.
    targets['HCClayteapot']['emptyWeight'] = 1
    targets['HCClayteapot']['displayName'] = 'Clay Teapot'
    # This old drainable lacks CanStoreWater and even refills itself on depletion.
    # Preserve its remaining uses at the same 0.1 L scale as every water source.
    migration['HCBeakerwaterhalf'] = {'target': 'HCGlassbeakerFluid', 'unitLitres': .1,
        'fluid': 'TaintedWater', 'legacyClass': records['HCBeakerwaterhalf']['properties']['itemtype']}
    return records, targets, migration


def main():
    records, targets, migration = collect()
    ru_path = LUA / 'shared/Translate/RU/ItemName.json'
    ru_items = json.loads(ru_path.read_text(encoding='utf-8'))
    # Не сохраняем ошибочные ключи раннего локального черновика генератора.
    for base in targets:
        ru_items.pop('ItemName_Hydrocraft.' + base + 'Fluid', None)
    translations = {lang: json.loads((LUA / f'shared/Translate/{lang}/Fluids.json').read_text(encoding='utf-8'))
                    for lang in ('EN', 'RU')}
    declarations = ['module Hydrocraft', '{',
        '    /* Generated by tools/build_water_catalog.py. Legacy IDs retain their save classes. */']
    allow = {'weight', 'displayname', 'icon', 'iconsfortexture', 'displaycategory',
             'staticmodel', 'worldstaticmodel', 'worldscale', 'tags', 'canbeequipped',
             'attachmentsprovided', 'attachmentreplacement', 'replaceinprimaryhand',
             'replaceinsecondhand', 'runSpeedModifier'.lower(), 'canhaveholes',
             'equippednosprint', 'requiresequippedbothhands', 'twohandweapon'}
    for base, spec in sorted(targets.items()):
        p = records[spec['source']]['properties']
        target = base + 'Fluid'
        label = spec.get('displayName', p.get('displayname', base))
        ru = ru_items.get('Hydrocraft.' + base,
             ru_items.get('Hydrocraft.' + spec['source'], label))
        if base == 'HCWaterflask':
            label, ru = 'Leather Waterflask', 'Кожаная фляга'
        if base == 'HCClayteapot':
            ru = 'Глиняный чайник'
        ru_items['Hydrocraft.' + target] = ru
        key = 'Waterflask' if base == 'HCWaterflask' else 'HCR_' + base
        translations['EN']['Fluid_Container_' + key] = label
        translations['RU']['Fluid_Container_' + key] = ru
        lines = [f'    item {target}', '    {', '        ItemType = base:normal,']
        for m in re.finditer(r'(?im)^\s*(\w+)\s*=\s*([^,\r\n]+)', records[spec['source']]['body']):
            k, value = m[1], m[2].strip()
            if k.lower() not in allow:
                continue
            if k.lower() == 'weight': value = str(spec.get('emptyWeight', value))
            if k.lower() == 'displayname': value = label
            lines.append(f'        {k} = {value},')
        lines.extend(['        CanStoreWater = true,',
                      '        FillFromDispenserSound = GetWaterFromDispenser,',
                      '        FillFromLakeSound = GetWaterFromLakeSmall,',
                      '        FillFromTapSound = GetWaterFromTap,',
                      '        FillFromToiletSound = GetWaterFromToilet,',
                      '        component FluidContainer', '        {',
                      f'            ContainerName = {key},',
                      f'            Capacity = {spec["capacity"]:g},',
                      '            RainFactor = 1,',
                      '            CustomDrinkSound = DrinkingFromBottlePlastic,'])
        if base == 'HCWaterflask':
            lines.extend(['            whitelist', '            {',
                          '                fluid = Water/TaintedWater,', '            }'])
        lines.extend(['        }', '    }'])
        declarations.extend(lines)
    declarations.append('}')
    OUT.write_text('\n'.join(declarations) + '\n', encoding='utf-8')
    manifest = {'policy': 'Legacy water uses × 0.1 L; unknown purity is TaintedWater.',
                'targets': targets, 'migrations': migration}
    (REPO / 'tools/water_families.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    lua = ['-- Generated by tools/build_water_catalog.py; keep legacy save classes.',
           'HCRWaterFamilies = {', '    migrations = {']
    for source, row in sorted(migration.items()):
        lua.append(f'        ["Hydrocraft.{source}"] = {{target="Hydrocraft.{row["target"]}", unitLitres={row["unitLitres"]}}},')
    lua.extend(['    },', '    targets = {'])
    for base in sorted(targets):
        lua.append(f'        ["Hydrocraft.{base}Fluid"] = true,')
    lua.extend(['    },', '}'])
    (LUA / 'shared/HCR_WaterFamilies.lua').write_text('\n'.join(lua) + '\n', encoding='utf-8')
    ru_path.write_text(json.dumps(ru_items, ensure_ascii=False, indent=4) + '\n', encoding='utf-8')
    for lang, data in translations.items():
        (LUA / f'shared/Translate/{lang}/Fluids.json').write_text(json.dumps(data, ensure_ascii=False, indent=4) + '\n', encoding='utf-8')
    print(f'Native water vessels: {len(targets)}; legacy IDs covered: {len(migration)}')


if __name__ == '__main__':
    main()

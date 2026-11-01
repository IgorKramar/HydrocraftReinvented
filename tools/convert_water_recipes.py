"""One-time, idempotent conversion of physical water-vessel recipe references.

Legacy item descriptors remain unchanged for loading old saves. The rule manifest
also preserves pre-existing callbacks instead of replacing their behaviour.
"""
import hashlib
import json
import math
import re
from apply_playability_fixes import blocks
from build_water_catalog import collect
from hcr_paths import LUA, REPO, SCRIPTS, read_text

MANIFEST = REPO/'tools/water_recipe_rules.json'


def water_guard(body):
    """Находим прежний предикат и под обёрткой настроек производства."""
    match = re.search(r'OnTest\s*=\s*([^,\s]+)', body)
    if not match:
        return None
    name = match[1]
    if name.startswith('HCRSandbox.Test_'):
        catalog = json.loads((REPO/'tools/sandbox_catalog.json').read_text(encoding='utf-8'))
        name = catalog['callbacks'][name.split('Test_', 1)[1]]['previous']
    prefix = 'HCRFluidRecipes.Test_'
    return name[len(prefix):] if name.startswith(prefix) else None


def flags(line, *added):
    match = re.search(r'flags\[([^]]*)\]', line)
    values = match[1].split(';') if match else []
    values = list(dict.fromkeys([x for x in values + list(added) if x]))
    result = 'flags[' + ';'.join(values) + ']'
    return line[:match.start()]+result+line[match.end():] if match else line.rstrip(',')+' '+result+','


def callback(body, name, value):
    pattern = r'(?m)^\s*'+name+r'\s*=\s*([^,]+),'
    match = re.search(pattern, body)
    if match:
        body = body[:match.start()]+'\n        '+name+' = '+value+','+body[match.end():]
    else:
        body = body.replace('{', '{\n        '+name+' = '+value+',', 1)
    return body, match[1].strip() if match else None


def eyedropper_routes(rules):
    """Reviewed water-only cycle: one dropper = one old water use (0.1 L).

    Keep all four recipe IDs so existing learned recipes remain usable. Do not
    reproduce the legacy full/half beaker transformations, which duplicated glass.
    """
    path = SCRIPTS/'HydrocraftReinvented/HCR_Eyedroppers.txt'
    text = read_text(path)
    for start, end, name, body in reversed(list(blocks(text, 'craftRecipe'))):
        if not name.startswith(('Put Water In Beaker', 'Remove Water From Beaker')): continue
        token = hashlib.sha256(name.encode()).hexdigest()[:12]
        put = name.startswith('Put ')
        target = 'Hydrocraft.HCGlassbeakerFluid'
        rule = {'name': name, 'file': path.name, 'empty': [], 'water': {}}
        first = put and name == 'Put Water In Beaker'
        if put:
            rule['addWater'] = {'target': target, 'litres': .1}
            rule['previousCreate'] = 'HCR42.recipe_hcgeteyedropper'
            create = 'HCRFluidRecipes.Create_'+token
        else:
            rule['water'][target] = {'minimum': .1}
            create = 'HCR42.recipe_hcgeteyedropperwater'
        empty_flag = ' flags[ItemCount;IsEmpty]' if first else ''
        dropper = 'HCEyedropperwater' if put else 'HCEyedropper'
        fluid = '' if put else '\n                -fluid 0.1 [Water],'
        replacement = f'''craftRecipe {name}
    {{
        OnTest = HCRFluidRecipes.Test_{token},
        time = 50,
        Tags = AnySurfaceCraft;CanBeDoneFromFloor,
        category = Health,
        timedAction = Making,
        OnCreate = {create},
        inputs
        {{
            item 1 [Hydrocraft.{dropper}] flags[ItemCount],
            item 1 [{target}] mode:keep{empty_flag},{fluid}
            item 1 [Hydrocraft.HCLab2] mode:keep,
        }}
        outputs
        {{
        }}
    }}'''
        text = text[:start]+replacement+text[end:]
        rules[token] = rule
    if text != read_text(path): path.write_text(text, encoding='utf-8')


def main():
    records, targets, migrations = collect()
    empty = {key: row for key, row in migrations.items() if row['unitLitres'] == 0}
    full = {key: row for key, row in migrations.items() if row['unitLitres'] > 0}
    rules = json.loads(MANIFEST.read_text(encoding='utf-8')) if MANIFEST.exists() else {}
    eyedropper_routes(rules)
    changed = 0
    for path in sorted(SCRIPTS.rglob('*.txt')):
        old = read_text(path)
        text = old
        for start, end, name, body in reversed(list(blocks(text, 'craftRecipe'))):
            # Stateless boxing deliberately excludes all fluid containers.
            if path.name == 'HCR_Box.txt' and name.startswith('Store '):
                continue
            if water_guard(body):
                continue
            original = body
            parts = re.split(r'(\boutputs\s*\{)', body, maxsplit=1)
            if len(parts) != 3:
                continue
            inputs, output_marker, outputs = parts
            rule = {'name': name, 'file': path.name, 'empty': [], 'water': {}}
            purify = name.startswith('Purify Water')
            pump = name in ('Fill Bucket', 'Fill IBC Tower')

            def convert_input(match):
                line = match[0]
                amount, selection = int(match[1]), match[2].split(';')
                old_full = [value.split('.')[-1] for value in selection if value.split('.')[-1] in full]
                if purify:
                    if any(value == 'Hydrocraft.HCPurifyingtablets' for value in selection): return line
                    converted = ['Hydrocraft.'+full[value.split('.')[-1]]['target']
                                 if value.split('.')[-1] in full else value for value in selection]
                    for value in converted: rule['water'][value] = {'minimum': .000001}
                    return '            item 1 ['+';'.join(converted)+'] mode:keep flags[ItemCount],'
                if old_full:
                    assert len(selection) == 1, (name, selection)
                    legacy = old_full[0]
                    target = 'Hydrocraft.'+full[legacy]['target']
                    if 'mode:destroy' in line:
                        delta = float(records[legacy]['properties'].get('usedelta', '.03125'))
                        litres = round(math.floor(1/delta+1e-7)*.1, 6)
                        rule['water'][target] = {'exact': litres}
                        return f'            item 1 [{target}] mode:destroy flags[ItemCount],\n                -fluid {litres:g} [Water],'
                    if 'mode:keep' in line:
                        rule['water'][target] = {'minimum': .000001}
                        return f'            item 1 [{target}] mode:keep flags[ItemCount],'
                    return f'            item 1 [{target}] mode:keep,\n                -fluid {amount*.1:g} [Water],'
                converted = list(selection)
                touched = False
                for value in selection:
                    legacy = value.split('.')[-1]
                    if legacy in empty:
                        target = 'Hydrocraft.'+empty[legacy]['target']
                        if target not in converted: converted.append(target)
                        rule['empty'].append(target)
                        touched = True
                if not touched: return line
                if pump:
                    # The callback fills the SAME native vessel; the legacy ID
                    # is converted by the save migrator before it is eligible.
                    converted = [x for x in converted if x in rule['empty']]
                    rule['fill'] = converted[0]
                    return '            item 1 ['+';'.join(converted)+'] mode:keep flags[ItemCount;IsEmpty],'
                line = line.replace('['+match[2]+']', '['+';'.join(converted)+']')
                return flags(line, 'ItemCount', 'IsEmpty')

            inputs = re.sub(r'(?m)^\s*item (\d+) \[([^]]+)\][^\r\n]*', convert_input, inputs)
            if purify or pump:
                outputs = re.sub(r'(?m)^\s*item [^\r\n]*\r?\n', '\n', outputs)
            else:
                def convert_output(match):
                    legacy = match[2]
                    if legacy in empty:
                        return match[1]+'Hydrocraft.'+empty[legacy]['target']+match[3]
                    return match[0]
                outputs = re.sub(r'(\bitem \d+ )Hydrocraft\.(\w+)([^\r\n]*)', convert_output, outputs)
            body = inputs+output_marker+outputs
            if body == original: continue
            token = hashlib.sha256(name.encode()).hexdigest()[:12]
            body, prior = callback(body, 'OnTest', 'HCRFluidRecipes.Test_'+token)
            if prior: rule['previousTest'] = prior
            if purify or pump:
                rule['purify'] = purify
                body, prior = callback(body, 'OnCreate', 'HCRFluidRecipes.Create_'+token)
                if prior: rule['previousCreate'] = prior
            rule['empty'] = sorted(set(rule['empty']))
            rules[token] = rule
            text = text[:start]+body+text[end:]
            changed += 1
        if text != old: path.write_text(text, encoding='utf-8')
    # Refresh guards from the final inputs, including vanilla alternatives.
    # B42's IsEmpty does not see a component moved to a ground world object.
    for path in sorted(SCRIPTS.rglob('*.txt')):
        for _, _, name, body in blocks(read_text(path), 'craftRecipe'):
            token = water_guard(body)
            if not token: continue
            rule = rules[token]
            rule['empty'] = sorted({kind for line in body.splitlines()
                if 'IsEmpty' in line
                for selection in re.findall(r'\bitem \d+ \[([^]]+)\]', line)
                for kind in selection.split(';')})
    MANIFEST.write_text(json.dumps(rules, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
    lua = ['-- Generated by tools/convert_water_recipes.py.', 'HCRWaterRecipeRules = {']
    def encode(value):
        if isinstance(value, dict):
            return '{'+','.join('['+json.dumps(k)+']='+encode(v) for k,v in value.items())+'}'
        if isinstance(value, list): return '{'+','.join(encode(x) for x in value)+'}'
        if isinstance(value, bool): return 'true' if value else 'false'
        return json.dumps(value, ensure_ascii=False)
    for token, rule in sorted(rules.items()): lua.append(f'    ["{token}"] = '+encode(rule)+',')
    lua.append('}')
    (LUA/'shared/HCR_WaterRecipeRules.lua').write_text('\n'.join(lua)+'\n', encoding='utf-8')
    print(f'Water vessel recipes converted: {changed}; guarded recipes: {len(rules)}')


if __name__ == '__main__':
    main()

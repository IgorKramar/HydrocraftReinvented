"""Перевод исходных wine recipes на native объёмы без смены legacy классов."""
import re
from hcr_paths import SCRIPTS, LUA, read_text
from apply_playability_fixes import blocks


def main():
    path = SCRIPTS / 'HydrocraftReinvented/HCR_Winemaking.txt'
    text = read_text(path)
    juice = {
        'Juice Grapes Into Wooden Bucket': 'Red',
        'Juice Grapes Into Wooden Bucket (Wooden Bucket with White Grape Juice)': 'White',
    }
    prepare = {
        'Prepare Wine Barrels': 'HCRJuiceGrape',
        'Prepare Wine Barrels (Barrel of White Grape Juice)': 'HCRJuiceGrapeWhite',
    }
    bottles = {
        'Fill Bottles with Wine': 'HCRWineRed',
        'Fill Bottles with Wine (Variant)': 'HCRWineWhite',
        'Make Bottle of Mead': 'HCRMead', 'Make Bottle of Sake': 'HCRSake',
        'Fill Vinegar Bottles with Vinegar': 'HCRVinegar',
        'Fill Whiskey Bottles with Vinegar': 'HCRVinegar',
    }
    for start, end, name, body in reversed(list(blocks(text, 'craftRecipe'))):
        if name not in juice and name not in prepare and name not in bottles:
            continue
        body = re.sub(r'^\s*On(?:Test|Create)\s*=.*\n', '', body, flags=re.M)
        if name in juice:
            token = juice[name]
            body = body.replace('{', '{\n        OnTest = HCRFermentationRecipes.Test'+token+
                                ',\n        OnCreate = HCRFermentationRecipes.Juice'+token+',', 1)
            body = re.sub(r'item 1 \[Hydrocraft.HCWoodenbucket[^\n]+',
                          'item 1 [Hydrocraft.HCWoodenbucketFluid] mode:keep flags[ItemCount;IsEmpty],', body, count=1)
            body = re.sub(r'\n\s*item 1 Hydrocraft.HCWoodenbucketgrape(?:green)?,', '', body)
        elif name in prepare:
            body = re.sub(r'item 1 \[Hydrocraft.HCWoodenbarrel[^\n]+',
                          'item 1 [Hydrocraft.HCWoodenbarrelFluid] mode:keep flags[ItemCount;IsEmpty],', body, count=1)
            body = re.sub(r'item 5 \[Hydrocraft.HCWoodenbucketgrape(?:green)?\],',
                          'item 1 [*] mode:keep flags[ItemIsFluid;HandcraftOnly],\n'
                          '            -fluid 20 ['+prepare[name]+'] mode:primary,', body)
            body = re.sub(r'\n\s*item 1 Hydrocraft.HCBarrelgrape(?:green)?,', '', body)
        else:
            body = re.sub(r'item 1 \[Hydrocraft.HCBarrel[^\n]+',
                          'item 1 [*] mode:keep flags[ItemIsFluid;HandcraftOnly],\n'
                          '            -fluid 20 ['+bottles[name]+'] mode:primary,', body, count=1)
        text = text[:start] + body + text[end:]
    path.write_text(text, encoding='utf-8')
    # Остальные исходные применения пустой бочки принимают новый ID, но не
    # расходуют налитый напиток как древесину или корпус для дистилляции.
    for path in SCRIPTS.rglob('*.txt'):
        text = read_text(path)
        changed = re.sub(r'(item \d+ \[[^\n\]]*\bHydrocraft\.HCWoodenbarrel)(\])',
                         r'\1;Hydrocraft.HCWoodenbarrelFluid\2', text)
        lines = []
        for line in changed.splitlines(keepends=True):
            if re.search(r'item \d+ \[.*Hydrocraft\.HCWoodenbarrel;', line) and 'IsEmpty' not in line:
                if 'flags[' in line:
                    line = line.replace('flags[', 'flags[IsEmpty;', 1)
                else:
                    line = re.sub(r',\s*$', ' flags[ItemCount;IsEmpty],\n', line)
            line = re.sub(r'(item \d+ Hydrocraft\.HCWoodenbarrel),', r'\1Fluid,', line)
            lines.append(line)
        changed = ''.join(lines)
        if changed != text:
            path.write_text(changed, encoding='utf-8')
    path = LUA / 'server/HCExtra.lua'
    text = read_text(path)
    changed = text.replace('AddItem("Hydrocraft.HCWoodenbarrel")', 'AddItem("Hydrocraft.HCWoodenbarrelFluid")')
    if changed != text:
        path.write_text(changed, encoding='utf-8')


if __name__ == '__main__':
    main()

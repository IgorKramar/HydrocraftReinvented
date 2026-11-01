"""Восстановить исходный способ метанола, сохранив найденные готовые бочки."""
import json
import re
from apply_playability_fixes import blocks
from build_juice_catalog import lua
from hcr_paths import LUA, REPO, SCRIPTS, read_text

SOURCES = ['HCVodka', 'HCWhiskey1', 'HCWhiskey2', 'HCWhiskey3', 'HCWhiskey4',
           'HCBourbon1', 'HCBourbon2', 'HCScotch1', 'HCRum1', 'HCGin1', 'HCGin2',
           'HCGin3', 'HCVodka1', 'HCVodka2', 'HCSake']
MARKERS = ['HCRVodka', 'HCRWhiskey', 'HCRRum', 'HCRGin', 'HCRSake']


def main():
    rule = {'inputs': {0: {'fluids': MARKERS, 'pure': True,
                         'sourceTypes': {'Hydrocraft.' + n: True for n in SOURCES}}}}
    (LUA/'shared/HCR_MethanolRules.lua').write_text(
        '-- Исходные 15 видов спиртного проверяются даже после переливания.\n'
        '-- Генерируется tools/build_methanol_restore.py.\n'
        'HCRMethanolRules = '+lua({'Make Methanol': rule})+'\n', encoding='utf-8')
    path = SCRIPTS/'HydrocraftReinvented/HCR_Distillery.txt'
    text = read_text(path)
    for start, end, name, body in reversed(list(blocks(text, 'craftRecipe'))):
        if name == 'Fill Barrel with Lemon Mash':
            # Ни исходник, ни текущие часы не имеют перехода этой браги.
            # Старые предметы остаются читаемыми, новый тупик не предлагается.
            text = text[:start]+text[end:]
        elif name == 'Distill Methanol':
            body = re.sub(r'(?m)^\s*OnCreate\s*=\s*HCR42.recipe_getMethanol,\r?\n', '\n', body)
            if 'item 5 Hydrocraft.HCMethanol,' not in body:
                body = body.replace('item 1 Hydrocraft.HCWoodenbarrelFluid,',
                                    'item 1 Hydrocraft.HCWoodenbarrelFluid,\n            item 5 Hydrocraft.HCMethanol,')
            text = text[:start]+body+text[end:]
    path.write_text(text, encoding='utf-8')
    recipe = '''module Hydrocraft
{
    craftRecipe Make Methanol
    {
        time = 100,
        Tags = AnySurfaceCraft;CanBeDoneFromFloor,
        category = Chemistry,
        timedAction = Making,
        SkillRequired = Cooking:7,
        xpAward = Cooking:4,
        Tooltip = Tooltip_HCR_MethanolSpirits,
        inputs
        {
            item 1 [*] mode:keep flags[ItemIsFluid;HandcraftOnly],
            -fluid 1 [HCRVodka;HCRWhiskey;HCRRum;HCRGin;HCRSake] mode:primary,
            item 1 [Base.Charcoal],
            item 1 tags[base:startfire],
            item 1 [Hydrocraft.HCDistillery;Hydrocraft.HCDistillery2] mode:keep,
        }
        outputs
        {
            item 1 Hydrocraft.HCMethanol,
        }
    }
}
'''
    (SCRIPTS/'HydrocraftReinvented/HCR_Methanol.txt').write_text(recipe, encoding='utf-8')
    for lang in ('RU', 'EN'):
        path = LUA/f'shared/Translate/{lang}/Recipes.json'
        names = json.loads(read_text(path))
        names['Make Methanol'] = 'Получить метанол из спиртного' if lang == 'RU' else 'Make Methanol from Spirits'
        names.pop('Fill Barrel with Lemon Mash', None)
        path.write_text(json.dumps(names, ensure_ascii=False, indent=4)+'\n', encoding='utf-8')
        path = LUA/f'shared/Translate/{lang}/Tooltip.json'
        names = json.loads(read_text(path))
        names['Tooltip_HCR_MethanolSpirits'] = (
            'Исходный рецепт Hydrocraft: 1 л водки, покупного виски, бурбона, скотча, рома, джина или саке. Сосуд и остаток сохраняются. Подходит переносимый или закреплённый перегонный аппарат.'
            if lang == 'RU' else
            'Original Hydrocraft recipe: 1 L of vodka, retail whiskey, bourbon, Scotch, rum, gin or sake. The vessel and any remainder are retained. Works with a portable or anchored still.')
        path.write_text(json.dumps(names, ensure_ascii=False, indent=4)+'\n', encoding='utf-8')
    for filename in ('food_count_migrations.json', 'liquid_input_migrations.json', 'physical_container_migrations.json'):
        path = REPO/'tools'/filename
        record = json.loads(read_text(path))
        for field in ('migrations', 'protected_partial_inputs'):
            if field not in record:
                continue
            active = []
            for row in record[field]:
                if row['recipe'] == 'Fill Barrel with Lemon Mash':
                    row['supersededBy'] = 'methanol-original-recipe-1.6'
                    record.setdefault('superseded_'+field, []).append(row)
                else:
                    active.append(row)
            record[field] = active
        path.write_text(json.dumps(record, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
    print('Methanol: original 15 source types, 1 L input; found ready cask: exactly five outputs')


if __name__ == '__main__':
    main()

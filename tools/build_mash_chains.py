"""Нативная брага: реальные объёмы, сохранённые рецептуры и новые согласованные часы."""
import json
import re
from apply_playability_fixes import blocks
from build_juice_catalog import lua
from hcr_paths import LUA, REPO, SCRIPTS, read_text
from repair_food_counts import whole_input

# token, исходное имя рецепта, суффикс pot, суффикс готовой legacy бочки,
# русское имя жидкости, конечные рецепты перегонки.
MASHES = [
    ('Potato', 'Potato Mash', 'potatomash', 'potato', 'Картофельная брага', ['Vodka']),
    ('BlueAgave', 'Blue Agave Mash', 'blueagavemash', 'blueagave', 'Брага из голубой агавы', ['Tequila', 'Mezcal']),
    ('Apple', 'Apple Mash', 'applemash', 'apple', 'Яблочная брага', ['Applejack']),
    ('Peach', 'Peach Mash', 'peachmash', 'peach', 'Персиковая брага', ['Peach Schnapps']),
    ('Pumpkin', 'Pumpkin Mash', 'pumpkinmash', 'pumpkin', 'Тыквенная брага', ['Flip']),
    ('Juniper', 'Juniper Berry Mash', 'junipermash', 'juniper', 'Можжевеловая брага', ['Gin']),
    ('Flour', 'Flour Mash', 'flourmash', 'flour', 'Мучная брага', ['Whiskey']),
    ('Corn', 'Corn Mash', 'cornmash', 'corn', 'Кукурузная брага', ['Corn Whiskey']),
    ('Honey', 'Honey Brew', 'honeybrew', 'honey', 'Медовое сусло', []),
    ('Rice', 'Rice Mash', 'ricemash', 'rice', 'Рисовое сусло', []),
]


def fluid_input(litres, marker):
    return ('            item 1 [*] mode:keep flags[ItemIsFluid;HandcraftOnly],\n'
            f'            -fluid {litres:g} [{marker}] mode:primary,')


def main():
    families, products, stages, transitions, consumers, prepare, raw = {}, {}, {}, {}, {}, {}, {}
    for token, title, pot, barrel, ru, distills in MASHES:
        marker = 'HCRHoneyBrew' if token == 'Honey' else 'HCRRiceMash' if token == 'Rice' else 'HCRMash' + token
        active = 'Hydrocraft.HCBarrel' + barrel if not distills else 'Hydrocraft.HCRFerment' + token
        ready = 'Hydrocraft.HCBarrel' + barrel
        families['Hydrocraft.HCPotof' + pot + 'cooked'] = dict(
            target='Base.Pot', litres=.5, fluid=marker, enabled=True)
        raw['Hydrocraft.HCPotof'+pot]=dict(target='Base.Pot',litres=.5,fluid=marker,enabled=True,
                                         cookedMash=True,readyFood='Hydrocraft.HCPotof'+pot+'cooked')
        name = 'Fill Barrel with ' + title
        products[name] = dict(slot=1, marker=marker, stage=active, water=18.5)
        prepare['Prepare Pot of ' + title] = dict(waterSlot=2 if not distills else 3)
        if distills:
            stages[active] = dict(marker=marker)
            stages[ready] = dict(marker=marker+'Ready', preserveNutrition=True)
            transitions[active] = dict(target=ready, hours=336)
        for drink in distills:
            consumers['Distill Bottle of '+drink] = dict(inputs={0: dict(fluids=[marker+'Ready'], pure=True)})
    catalog = dict(families=families, products=products, stages=stages,
                   transitions=transitions, consumers=consumers, prepare=prepare,raw=raw)
    (REPO/'tools/mash_chains.json').write_text(json.dumps(catalog, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
    (LUA/'shared/HCR_MashCatalog.lua').write_text(
        '-- Генерируется tools/build_mash_chains.py.\nHCRMashCatalog = '+lua(catalog)+'\n', encoding='utf-8')
    for filename in ('HCR_Distillery.txt', 'HCR_Winemaking.txt'):
        path=SCRIPTS/'HydrocraftReinvented'/filename
        text=read_text(path)
        for start,end,name,body in reversed(list(blocks(text,'item'))):
            if 'Hydrocraft.'+name in raw:
                body=re.sub(r'(?m)^\s*(?:ReplaceOnCooked|OnCooked)\s*=.*?,\r?\n','\n',body)
                body=re.sub(r'\{\s*', '{\n        OnCooked = HCRMashCooking.OnCooked,\n\t',body,count=1)
                text=text[:start]+body+text[end:]
        for start,end,name,body in reversed(list(blocks(text,'craftRecipe'))):
            if name in prepare:
                body=body.replace('[Base.Pot] mode:destroy flags[ItemCount]',
                                  '[Base.Pot] mode:destroy flags[ItemCount;ItemIsFluid;IsEmpty]')
            elif name in products:
                rule=products[name]
                body=re.sub(r'(?m)^\s*OnCreate\s*=.*?,\r?\n','\n',body)
                body=re.sub(r'inputs\s*\{[^}]*\}',lambda _: 'inputs\n        {\n'
                            '            item 1 [Hydrocraft.HCWoodenbarrelFluid] mode:keep flags[ItemCount;ItemIsFluid;IsEmpty],\n'
                            +fluid_input(1.5,rule['marker'])+'\n'+fluid_input(18.5,'Water')+'\n        }',body)
                body=re.sub(r'outputs\s*\{[^}]*\}','outputs\n        {\n        }',body)
                body=re.sub(r'(?m)^\s*Tooltip\s*=.*?,\r?\n','\n',body)
                body=re.sub(r'\{\s*', '{\n        Tooltip = Tooltip_HCR_MashFerment,\n        ',body,count=1)
            elif name in consumers:
                body=re.sub(r'(?m)^\s*OnCreate\s*=\s*HCR42.recipe_hcwoodenbarrel,\r?\n','\n',body)
                marker=consumers[name]['inputs'][0]['fluids'][0]
                body=re.sub(r'            item 1 \[Hydrocraft.HCBarrel\w+\],',fluid_input(20,marker),body,count=1)
            else:
                continue
            text=text[:start]+body+text[end:]
        path.write_text(text,encoding='utf-8')
    recipes={name:body for p in SCRIPTS.rglob('*.txt') for _,_,name,body in blocks(read_text(p),'craftRecipe')}
    changed=set(products)|set(prepare)|set(consumers)
    for filename in ('food_count_migrations.json','liquid_input_migrations.json','physical_container_migrations.json'):
        path=REPO/'tools'/filename;record=json.loads(read_text(path))
        for field in ('migrations','protected_partial_inputs'):
            if field not in record:continue
            active=[]
            for row in record[field]:
                expected=row.get('after',whole_input(row['input']) if field=='migrations' and 'input' in row else row.get('input',''))
                if row['recipe'] in changed and expected and expected not in recipes[row['recipe']]:
                    row['supersededBy']='mash-chains-1.6'
                    record.setdefault('superseded_'+field,[]).append(row)
                else:active.append(row)
            record[field]=active
        path.write_text(json.dumps(record,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    for lang in ('RU','EN'):
        path=LUA/f'shared/Translate/{lang}/Tooltip.json'
        data=json.loads(read_text(path))
        data['Tooltip_HCR_MashFerment']=(
            '1,5 л приготовленного сусла и 18,5 л чистой воды в пустую бочку на 20 л. Брожение занимает 14 дней. Кастрюли и бочка сохраняются; свежесть и примеси переходят из ингредиентов.'
            if lang=='RU' else
            'Combine 1.5 L of cooked mash and 18.5 L of clean water in an empty 20 L cask. Fermentation takes 14 days. Pots and cask are retained; freshness and contaminants follow the ingredients.')
        path.write_text(json.dumps(data,ensure_ascii=False,indent=4)+'\n',encoding='utf-8')
    print('Mash chains: 10 cooked migrations, 10 measured cask fills, 8 new clocks, 9 distillations')


if __name__=='__main__':
    main()

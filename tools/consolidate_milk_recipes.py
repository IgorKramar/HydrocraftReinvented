"""Согласованная унификация девяти Milk/Soy рецептов без дублей меню.

Исходные Food-OR и native bodies сохраняются в manifest. Повторный запуск
проверяет supersession; прежний repair больше не создаёт удалённые варианты.
"""
import json
import re
from apply_playability_fixes import blocks
from hcr_paths import LUA, REPO, SCRIPTS, read_text


def main():
    path=REPO/'tools/milk_fluid_migrations.json'
    manifest=json.loads(read_text(path))
    rows=[r for r in manifest['migrations'] if r['kind']=='split_food_or']
    assert len(rows)==9
    aliases={r.get('previous_native_recipe',r['native_recipe']):r['recipe'] for r in rows}
    chains_path=REPO/'tools/milk_chains.json'
    chains=json.loads(read_text(chains_path))
    for script_path in SCRIPTS.rglob('*.txt'):
        text=read_text(script_path);before=text
        recipes={name:body for _,_,name,body in blocks(text,'craftRecipe')}
        for start,end,name,body in reversed(list(blocks(text,'craftRecipe'))):
            if name in aliases:
                text=text[:start]+text[end:]
            else:
                row=next((r for r in rows if r['recipe']==name),None)
                if not row: continue
                alias=row.get('previous_native_recipe',row['native_recipe'])
                if alias in recipes:
                    row['legacy_food_body']=body
                    row['legacy_native_body']=recipes[alias]
                    body=recipes[alias].replace('craftRecipe '+alias,'craftRecipe '+name,1)
                else:
                    assert row.get('superseded_by')=='unified_milk_1_6',name
                assert 'Hydrocraft.HCSoymilk]' not in body and '-fluid ' in body,name
                text=text[:start]+body+text[end:]
        def teach(match):
            names=[]
            for name in match[2].split(';'):
                name=aliases.get(name.strip(),name.strip())
                if name not in names:names.append(name)
            return match[1]+';'.join(names)
        text=re.sub(r'(LearnedRecipes\s*=\s*)([^,]+)',teach,text)
        if text!=before:script_path.write_text(text,encoding='utf-8')
    for row in rows:
        alias=row.get('previous_native_recipe',row['native_recipe'])
        name=row['recipe']
        if alias in chains:
            spec=chains.pop(alias)
            spec['original']=spec['original'].replace('craftRecipe '+alias,'craftRecipe '+name,1)
            chains[name]=spec
        assert name in chains,name
        row['previous_native_recipe']=alias
        row['native_recipe']=name
        row['superseded_by']='unified_milk_1_6'
    manifest['policy']='Historical source volumes remain in source records. Nine Food-OR/native pairs are superseded by canonical fluid recipes with equal Milk/Soy volumes. Concentrate enters through dilution; raw Soy requires cooking and finishing.'
    path.write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    chains_path.write_text(json.dumps(chains,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    for lang in ('RU','EN'):
        path=LUA/f'shared/Translate/{lang}/Recipes.json'
        names=json.loads(read_text(path))
        for alias in aliases:names.pop(alias,None)
        path.write_text(json.dumps(names,ensure_ascii=False,indent=4)+'\n',encoding='utf-8')
    # Старые гранулярные исправления больше не владеют заменёнными bodies.
    recipes={name:body for p in SCRIPTS.rglob('*.txt') for _,_,name,body in blocks(read_text(p),'craftRecipe')}
    for filename in ('food_count_migrations.json','liquid_input_migrations.json',
                     'physical_container_migrations.json','petrol_container_migrations.json'):
        path=REPO/'tools'/filename;record=json.loads(read_text(path))
        for field in ('migrations','protected_partial_inputs'):
            if field not in record:continue
            active=[]
            for row in record[field]:
                name=row.get('recipe')
                if name in aliases or name in aliases.values():
                    row['supersededBy']='unified-milk-1.6'
                    record.setdefault('superseded_'+field,[]).append(row)
                else:active.append(row)
            record[field]=active
        path.write_text(json.dumps(record,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print('Consolidated 9 Milk/Soy pairs; preserved source records and teaching links')


if __name__=='__main__':main()

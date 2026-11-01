"""Apply reviewed B41 Milk-to-B42 CowMilk volumes without changing HC Food portions."""
import argparse
import json
import re
from collections import defaultdict
from pathlib import Path

from apply_playability_fixes import blocks
from hcr_paths import SCRIPTS, LUA, read_text

MANIFEST = Path(__file__).with_name('milk_fluid_migrations.json')


def align_water_callback(expected, actual):
    """Different recipe names have different hashes, but identical guards."""
    pattern = r'OnTest\s*=\s*HCRFluidRecipes\.Test_(\w+)'
    a, b = re.search(pattern, expected), re.search(pattern, actual)
    if not a or not b or a[1] == b[1]: return expected
    rules = json.loads(Path(__file__).with_name('water_recipe_rules.json').read_text(encoding='utf-8'))
    semantic = lambda row: {k:v for k,v in row.items() if k not in ('name','file')}
    if semantic(rules[a[1]]) != semantic(rules[b[1]]):
        raise RuntimeError('Milk variants have different water guards')
    return expected.replace(a[0], b[0], 1)


def native_lines(row):
    return ('item 1 [Base.Milk] mode:keep flags[ItemIsFluid;HandcraftOnly],\n'
            '            -fluid ' + str(row['litres']) + ' [CowMilk],')


def apply(check=False):
    data=json.loads(MANIFEST.read_text(encoding='utf-8'))
    newer_path=MANIFEST.with_name('milk_chains.json')
    newer=json.loads(newer_path.read_text(encoding='utf-8')) if newer_path.exists() else {}
    brewed=json.loads(MANIFEST.with_name('brewed_drink_rules.json').read_text(encoding='utf-8'))
    by_file=defaultdict(dict)
    for row in data['migrations']:by_file[row['file']][row['recipe']]=row
    changes=[]
    for filename,rows in by_file.items():
        path=SCRIPTS/'HydrocraftReinvented'/filename
        old=read_text(path);new=old
        names={name for _,_,name,_ in blocks(old,'craftRecipe')}
        found=set()
        for a,z,name,body in reversed(list(blocks(old,'craftRecipe'))):
            if name not in rows:continue
            row=rows[name];found.add(name);before=row['input']
            if row.get('superseded_by')=='unified_milk_1_6':
                assert row['native_recipe']==name and row['previous_native_recipe'] not in names,name
                assert '-fluid ' in body and 'HCRMilkSoy' in body,name
                continue
            if row.get('superseded_by')=='brewed_drinks':
                assert name in brewed and 'OnCreate = HCRBrewedDrinks.create,' in body,name
                continue
            if row.get('native_recipe') in newer:
                # Объёмы/guard теперь принадлежат явному каталогу 1.6.
                if row['kind']=='split_food_or' and before.replace('[Base.Milk;','[') not in body:
                    raise RuntimeError('Legacy milk alternative changed: '+name)
                continue
            if row['kind']=='split_food_or':
                food=before.replace('[Base.Milk;','[')
                if before not in body:
                    if food not in body or row['native_recipe'] not in names:
                        raise RuntimeError('Reviewed milk OR changed: '+name)
                    continue
                if check:raise RuntimeError('Mixed Food/fluid milk still present: '+name)
                if row['native_recipe'] in names:raise RuntimeError('Duplicate milk variant: '+name)
                native=body.replace('craftRecipe '+name,'craftRecipe '+row['native_recipe'],1)
                native=native.replace(before,native_lines(row),1)
                body=body.replace(before,food,1)+ '\n'+native
            else:
                after=row['after'] if row['kind']=='whole_carton_conversion' else native_lines(row)
                if before not in body:
                    if after not in body:raise RuntimeError('Reviewed milk input changed: '+name)
                    continue
                if check:raise RuntimeError('Milk input still ignores fluid: '+name)
                body=body.replace(before,after,1)
            new=new[:a]+body+new[z:]
        if set(rows)-found:raise RuntimeError('Missing reviewed milk recipes: '+filename)
        # A concurrent physical-container correction may have changed only the
        # original recipe after splitting. Derive each variant from that current
        # original, so all non-milk fields/flags stay identical.
        originals={name:body for _,_,name,body in blocks(new,'craftRecipe')}
        split_rows={row['native_recipe']:row for row in rows.values() if row['kind']=='split_food_or' and row.get('superseded_by')!='unified_milk_1_6'}
        for a,z,name,body in reversed(list(blocks(new,'craftRecipe'))):
            if name not in split_rows:continue
            if name in newer:continue
            row=split_rows[name]
            food=row['input'].replace('[Base.Milk;','[')
            expected=originals[row['recipe']].replace('craftRecipe '+row['recipe'],'craftRecipe '+name,1)
            expected=expected.replace(food,native_lines(row),1)
            expected=align_water_callback(expected, body)
            if expected!=body:
                if check:raise RuntimeError('Milk variant differs from current original: '+name)
                new=new[:a]+expected+new[z:]
        if old!=new:changes.append((path,old,new))

    # Keep newly split learned recipes beside the same existing teaching links.
    split={row['recipe']:row['native_recipe'] for row in data['migrations'] if row['kind']=='split_food_or' and row.get('superseded_by')!='unified_milk_1_6'}
    def teach(match):
        names=[name.strip() for name in match[2].split(';')]
        extra=[target for source,target in split.items() if source in names and target not in names]
        if check and extra:raise RuntimeError('Milk variants missing from teaching book')
        return match[1]+match[2].rstrip()+(';'+';'.join(extra) if extra else '')
    for path in SCRIPTS.rglob('*.txt'):
        old=read_text(path)
        if 'LearnedRecipes' not in old:continue
        new=re.sub(r'(LearnedRecipes\s*=\s*)([^,]+)',teach,old)
        if old!=new:changes.append((path,old,new))
    path=LUA/'shared/Translate/RU/Recipes.json';old=read_text(path);translations=json.loads(old)
    for source,target in split.items():
        if target not in translations:
            if check:raise RuntimeError('Milk variant missing Russian name: '+target)
            translations[target]=translations.get(source,source)+' (молоко из пакета)'
    new=json.dumps(translations,ensure_ascii=False,indent=4)+'\n'
    if old!=new:changes.append((path,old,new))
    if not check:
        for path,old,new in changes:
            if read_text(path)!=old:raise RuntimeError('Concurrent edit: '+str(path))
            path.write_text(new,encoding='utf-8',newline='')
    print('milk fluid routes reviewed='+str(len(data['migrations']))+'; files changed='+str(len(changes)))


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check',action='store_true')
    apply(parser.parse_args().check)

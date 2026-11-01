"""Газировка, энергетики, фитнес-напиток и безалкогольный яблочный сидр."""
import json
import re
from apply_playability_fixes import blocks
from build_juice_catalog import lua
from build_water_catalog import props
from convert_water_recipes import callback
from hcr_paths import LUA, REPO, SCRIPTS, read_text
from repair_food_counts import whole_input

FLAVOURS = {'cherry':'Cherry','cola':'Cola','cream':'Cream','drpepper':'DrPepper',
            'gingerale':'GingerAle','grape':'Grape','grapefruit':'Grapefruit',
            'lemonlime':'LemonLime','pineapple':'Pineapple','rootbeer':'RootBeer'}


def catalogue():
    rows = {f'HCPop{n}':('HCRSodaPop',.3) for n in (4,5,6)}
    rows |= {'HCSoda'+flavour:('HCRSoda'+marker,2) for flavour,marker in FLAVOURS.items()}
    rows |= {'HCEnergydrink':('HCREnergy',.3),'HCEnergydrink2':('HCREnergy',.3),
             'HCFitnessdrink':('HCRFitness',1.4),'HCApplecider':('HCRAppleCider',1.4)}
    result = {}
    for old,(marker,litres) in rows.items():
        target={'HCFitnessdrink':'HCCanteenFluid','HCApplecider':'HCGlassjugFluid'}.get(old,old+'Fluid')
        result['Hydrocraft.'+old] = dict(target='Hydrocraft.'+target,fluid=marker,litres=litres,enabled=True,
            factoryDrink=old.startswith('HCPop'),policy='preserve current Food properties; non-alcoholic')
    result['Hydrocraft.HCApplecider']['policy']='pinned917 Glassworking jug: 14 water uses x 0.1 L; non-alcoholic'
    return result


def main():
    families=catalogue()
    items={name:props(body) for path in SCRIPTS.rglob('*.txt') for _,_,name,body in blocks(read_text(path),'item')}
    packing,unpacking,consumers,empty_recipes={},{},{},set()
    soda_vessels=[v['target'] for k,v in families.items() if k.startswith('Hydrocraft.HCSoda')]
    for path in SCRIPTS.rglob('*.txt'):
        text=previous=read_text(path)
        for start,end,name,body in reversed(list(blocks(text,'craftRecipe'))):
            if name=='Pack Pop (Pack of Pop 3)':
                body=body.replace('[Hydrocraft.HCPop6]','[Hydrocraft.HCPop6Fluid]')
                body,_=callback(body,'Tooltip','Tooltip_HCR_PackPop')
                packing[name]='Hydrocraft.HCPop6Fluid'
            elif name=='Unpack Pop (Pop)':
                body=re.sub(r'item 6 Hydrocraft.HCPop6(?:Fluid)?,','item 6 Hydrocraft.HCPop6Fluid,',body)
                unpacking[name]=dict(target='Hydrocraft.HCPop6Fluid',source='Hydrocraft.HCPop6',count=6)
            if name=='Whiskey and Coke':
                body=body.replace('item 1 [Hydrocraft.HCSodacola],',
                    'item 1 [*] mode:keep flags[ItemIsFluid;HandcraftOnly],\n            -fluid 0.133333333333 [HCRSodaCola] mode:primary,')
                consumers[name]=dict(inputs={1:dict(fluids=['HCRSodaCola'])})
            if name=='Mix Fitness Drink':
                body=re.sub(r'item 1 \[Hydrocraft.HCCanteen(?:;Hydrocraft.HCCanteenFluid)?\] mode:destroy flags\[ItemCount;IsEmpty\],',
                    'item 1 [Hydrocraft.HCCanteenFluid] mode:keep flags[ItemCount;IsEmpty],',body)
                body=re.sub(r'outputs\s*\{[^}]*\}','outputs\n        {\n        }',body)
                body,_=callback(body,'OnCreate','HCRSoftDrinks.createFitness')
                body,_=callback(body,'Tooltip','Tooltip_HCR_FitnessMix')
                consumers[name]=dict(inputs={})
            elif 'item 1 [Hydrocraft.HCFitnessdrink],' in body or '-fluid 0.14 [HCRFitness]' in body:
                body=body.replace('item 1 [Hydrocraft.HCFitnessdrink],',
                    'item 1 [*] mode:keep flags[ItemIsFluid;HandcraftOnly],\n            -fluid 0.14 [HCRFitness] mode:primary,')
                if path.name=='HCR_Gym.txt':
                    body=re.sub(r'outputs\s*\{\s*item 1 Hydrocraft.HCCanteenFluid,\s*\}','outputs\n        {\n        }',body)
                lines=re.findall(r'item [^\n]+\n(?:\s*-fluid [^\n]+\n)?',body.split('inputs',1)[1].split('outputs',1)[0])
                slot=next(i for i,line in enumerate(lines) if '-fluid 0.14 [HCRFitness]' in line)
                consumers[name]=dict(inputs={slot:dict(fluids=['HCRFitness'])})
            def aliases(match):
                kinds=match[2].split(';')
                if 'Base.PopBottle' in kinds:
                    for target in soda_vessels:
                        if target not in kinds: kinds.append(target)
                    empty_recipes.add(name)
                return match[1]+';'.join(kinds)+match[3]
            body=re.sub(r'(item \d+ \[)([^\]]+)(\](?: mode:(?:destroy|keep))? flags\[[^\]]*IsEmpty[^\]]*\],)',aliases,body)
            text=text[:start]+body+text[end:]
        if text!=previous: path.write_text(text,encoding='utf-8')
    config=dict(families=families,vessels={v['target']:k for k,v in families.items() if v['factoryDrink']},
                packing=packing,unpacking=unpacking,consumers=consumers,emptyRecipes=sorted(empty_recipes),
                emptyAliases={'Base.PopBottle':soda_vessels})
    (REPO/'tools/soft_drink_catalog.json').write_text(json.dumps(config,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    (LUA/'shared/HCR_SoftDrinkCatalog.lua').write_text('-- Генерируется tools/build_soft_drinks.py.\nrequire "HCR_DrinkFamilies"\nHCRSoftDrinkCatalog='+lua(config)+'\n'
        'for kind,spec in pairs(HCRSoftDrinkCatalog.families) do HCRDrinkFamilies[kind]=spec end\n',encoding='utf-8')
    script=['module Hydrocraft','{']
    for old,spec in families.items():
        if old=='Hydrocraft.HCFitnessdrink': continue
        p=items[old.split('.')[1]];can=spec['litres']==.3;jug=old=='Hydrocraft.HCApplecider'
        script += [f'    item {spec["target"].split(".")[1]}','    {','        ItemType = base:normal,',
            '        DisplayCategory = WaterContainer,',f'        DisplayName = {p["displayname"]},',
            f'        Icon = {"HCGlassjug" if jug else p["icon"]},',f'        Weight = {0.1 if can or not jug else .3},',
            '        EatType = '+('Popcan' if can else 'Bourbon')+',',
            '        Tags = '+('base:hasmetal;base:emptycan' if can else 'base:glass' if jug else 'base:plasticbottle')+',',
            '        component FluidContainer','        {','            ContainerName = '+('Can' if can else 'Bottle')+',',
            f'            Capacity = {spec["litres"]},','            CustomDrinkSound = '+('DrinkingFromCan' if can else 'DrinkingFromBottle')+',',
            '        }','    }']
    script.append('}')
    (SCRIPTS/'HydrocraftReinvented/HCR_SoftDrinkContainers.txt').write_text('\n'.join(script)+'\n',encoding='utf-8')
    for lang in ('RU','EN'):
        path=LUA/f'shared/Translate/{lang}/ItemName.json';names=json.loads(path.read_text(encoding='utf-8'))
        for old,spec in families.items():
            if old!='Hydrocraft.HCFitnessdrink': names[spec['target']]=names.get(old,items[old.split('.')[1]]['displayname'])
        names['Hydrocraft.HCGlassjugFluid']='Стеклянный кувшин' if lang=='RU' else 'Glass Jug'
        path.write_text(json.dumps(names,ensure_ascii=False,indent=4)+'\n',encoding='utf-8')
        path=LUA/f'shared/Translate/{lang}/Tooltip.json';names=json.loads(path.read_text(encoding='utf-8'))
        names['Tooltip_HCR_PackPop']=('Шесть полных исходных банок. Начатые, повторно наполненные или изменённые напитки упаковать нельзя.' if lang=='RU' else 'Six full original cans. Partly used, refilled or altered drinks cannot be packed.')
        names['Tooltip_HCR_FitnessMix']=('Выход: 1,4 л в той же пустой фляге. Сохраняется питание исходного рецепта; свежесть и примеси переносятся из ингредиентов. Одно использование батареи блендера.' if lang=='RU' else 'Yield: 1.4 L in the same empty canteen. Keeps the original recipe nutrition; freshness and contaminants follow the ingredients. Uses one blender battery charge.')
        path.write_text(json.dumps(names,ensure_ascii=False,indent=4)+'\n',encoding='utf-8')
    changed=set(packing)|set(unpacking)|set(consumers)|empty_recipes
    recipes={name:body for path in SCRIPTS.rglob('*.txt') for _,_,name,body in blocks(read_text(path),'craftRecipe')}
    for filename in ('food_count_migrations.json','physical_container_migrations.json','packaging_migrations.json','liquid_input_migrations.json','petrol_container_migrations.json'):
        path=REPO/'tools'/filename;record=json.loads(path.read_text(encoding='utf-8'))
        for field in ('migrations','protected_partial_inputs'):
            if field not in record: continue
            active=[]
            for row in record[field]:
                expected=row.get('after',whole_input(row['input']) if field=='migrations' and 'input' in row else row.get('input',''))
                if row['recipe'] in changed and ((expected and expected not in recipes[row['recipe']]) or row['recipe'] in packing):
                    row['supersededBy']='soft-drinks-1.6';record.setdefault('superseded_'+field,[]).append(row)
                else: active.append(row)
            record[field]=active
        path.write_text(json.dumps(record,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print(f'Soft drinks: {len(families)} families; {len(consumers)} consumers/producers; {len(empty_recipes)} empty-bottle routes')


if __name__=='__main__': main()

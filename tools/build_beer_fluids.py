"""Магазинное пиво: прежние марки, 0,3 л, замкнутая упаковка шести банок."""
import json
import re
from apply_playability_fixes import blocks
from build_juice_catalog import lua
from build_water_catalog import props
from hcr_paths import LUA, REPO, SCRIPTS, read_text


def catalogue():
    return {'Hydrocraft.'+kind:dict(target='Hydrocraft.'+kind+'Fluid',litres=.3,
            fluid='HCRBeer',enabled=True,beer=True)
            for prefix,count in [('HCBeer',8),('HCBeercan',10)]
            for n in range(1,count+1) for kind in [prefix+str(n)]}


def main():
    families=catalogue();vessels={v['target']:k for k,v in families.items()}
    path=SCRIPTS/'HydrocraftReinvented/HCR_Food Bar.txt';text=read_text(path)
    labels={'Hydrocraft.'+name:props(body)['displayname'] for _,_,name,body in blocks(text,'item')}
    packing={};unpacking={}
    for start,end,name,body in reversed(list(blocks(text,'craftRecipe'))):
        if name.startswith('Open Pack of Beer'):
            old=re.search(r'item 6 Hydrocraft\.(HCBeercan\d+)(?:Fluid)?,',body)
            assert old,name
            source='Hydrocraft.'+old[1];target=families[source]['target']
            body=re.sub(r'item 6 Hydrocraft\.HCBeercan\d+(?:Fluid)?,','item 6 '+target+',',body)
            unpacking[name]=dict(target=target,source=source,count=6)
        elif name.startswith('Pack Beer'):
            old=re.search(r'item 6 \[Hydrocraft\.(HCBeercan\d+)(?:Fluid)?\]',body)
            assert old,name
            target='Hydrocraft.'+old[1]+'Fluid'
            body=re.sub(r'item 6 \[Hydrocraft\.HCBeercan\d+(?:Fluid)?\]',f'item 6 [{target}]',body)
            if 'Tooltip = Tooltip_HCR_PackBeer,' not in body:
                body=body.replace('OnTest = HCRPackaging.IsFullFactoryState,',
                                  'OnTest = HCRPackaging.IsFullFactoryState,\n        Tooltip = Tooltip_HCR_PackBeer,')
            packing[name]=target
        else: continue
        text=text[:start]+body+text[end:]
    assert len(packing)==len(unpacking)==10
    path.write_text(text,encoding='utf-8')
    config=dict(families=families,vessels=vessels,packing=packing,unpacking=unpacking)
    (REPO/'tools/beer_fluid_catalog.json').write_text(json.dumps(config,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    (LUA/'shared/HCR_BeerFamilies.lua').write_text('-- Генерируется tools/build_beer_fluids.py.\n'
        'require "HCR_DrinkFamilies"\nHCRBeerCatalog='+lua(config)+'\n'
        'for kind,spec in pairs(HCRBeerCatalog.families) do HCRDrinkFamilies[kind]=spec end\n',encoding='utf-8')
    script=['module Hydrocraft','{']
    for source,spec in families.items():
        old=source.split('.')[1];target=spec['target'].split('.')[1];can='Beercan' in old
        script += [f'    item {target}','    {','        ItemType = base:normal,',
            '        DisplayCategory = WaterContainer,','        Weight = 0.1,',
            '        DisplayName = '+('Beer Can' if can else 'Beer Bottle')+',',f'        Icon = {old},',
            '        EatType = '+('Popcan' if can else 'Bourbon')+',',
            '        StaticModel = '+('BeerCan' if can else 'BeerBottle')+',',
            '        WorldStaticModel = '+('BeerCan_Ground' if can else 'BeerBottleGround')+',',
            '        Tags = '+('base:hasmetal;base:emptycan' if can else 'base:glass;base:glassbottlesmall')+',',
            '        component FluidContainer','        {','            ContainerName = '+('CanBeer' if can else 'BottleBeer')+',',
            '            Capacity = 0.3,','            CustomDrinkSound = '+('DrinkingFromCan' if can else 'DrinkingFromBottleGlass')+',',
            '        }','    }']
    script += ['}']
    (SCRIPTS/'HydrocraftReinvented/HCR_BeerContainers.txt').write_text('\n'.join(script)+'\n',encoding='utf-8')
    for lang in ('RU','EN'):
        p=LUA/f'shared/Translate/{lang}/ItemName.json';names=json.loads(p.read_text(encoding='utf-8'))
        for source,spec in families.items(): names[spec['target']]=names.get(source,labels[source])
        names['Hydrocraft.HCRCookingBeer']='Порция пива для готовки' if lang=='RU' else 'Beer for Cooking'
        p.write_text(json.dumps(names,ensure_ascii=False,indent=4)+'\n',encoding='utf-8')
        p=LUA/f'shared/Translate/{lang}/Recipes.json';names=json.loads(p.read_text(encoding='utf-8'))
        names['Prepare Beer for Cooking']='Отмерить пиво для готовки' if lang=='RU' else 'Prepare Beer for Cooking'
        p.write_text(json.dumps(names,ensure_ascii=False,indent=4)+'\n',encoding='utf-8')
        p=LUA/f'shared/Translate/{lang}/Tooltip.json';names=json.loads(p.read_text(encoding='utf-8'))
        names['Tooltip_HCR_PackBeer']=('Шесть полных исходных банок одной марки. Начатые, повторно наполненные или изменённые напитки упаковать нельзя.' if lang=='RU' else
            'Six full original cans of the same brand. Partly used, refilled or altered drinks cannot be packed.')
        names['Tooltip_HCR_CookingBeer']=('Отмерить 0,3 л пива Hydrocraft в пустую кружку для супа или рагу. Питание, свежесть, яд и действие алкоголя сохраняются.' if lang=='RU' else
            'Measure 0.3 L of Hydrocraft beer into an empty stein for soup or stew. Nutrition, freshness, poison and alcohol effects are retained.')
        p.write_text(json.dumps(names,ensure_ascii=False,indent=4)+'\n',encoding='utf-8')
    path=REPO/'tools/packaging_migrations.json';record=json.loads(path.read_text(encoding='utf-8'))
    active=[]
    for entry in record['migrations']:
        if entry['recipe'] in packing:
            entry['supersededBy']='beer-fluid-1.6'
            record.setdefault('superseded_migrations',[]).append(entry)
        else: active.append(entry)
    record['migrations']=active;path.write_text(json.dumps(record,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print('Beer: 18 migrations/vessels; 10 pack + 10 unpack recipes; 0.3 L per serving')


if __name__=='__main__': main()

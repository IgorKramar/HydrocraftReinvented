"""Замкнутый этап: native молоко → ведро → масло, сыр, йогурт, молочные блюда.

Сырое соевое молоко остаётся Food до нагрева и завершения. Legacy классы сохраняются;
миграции кувшинов/UHT/канистр переносят оставшиеся свойства в native тару.
"""
import hashlib
import json
import re
from apply_playability_fixes import blocks
from build_juice_catalog import lua
from convert_water_recipes import callback
from hcr_paths import LUA,REPO,SCRIPTS,read_text

MILK=['HCRMilk','CowMilk','SheepMilk','AnimalMilk']
CHOCOLATE_MILK=MILK+['HCRMilkChocolate']
CHOCOLATE_RECIPES=set((
    'Make Eggnog Pot','Make Monkey Tail Pot','Prepare Cornbread','Make Nacho Cheese',
    'Make Frosting','Make Fruit Cake Batter','Make Pot of Rice Pudding'))
SOY_RECIPES=CHOCOLATE_RECIPES|{'Make Cup of Hot Chocolate','Make Cup of Hot Chocolate (Cup of Hot Chocolate)'}
ROOT=SCRIPTS/'HydrocraftReinvented'

def fluid(litres,kinds=MILK,items='*'):
    return f'item 1 [{items}] mode:keep flags[ItemIsFluid;HandcraftOnly],\n            -fluid {litres:g} ['+';'.join(kinds)+'] mode:primary,'

def empty(kind,count=1):
    return f'item {count} [{kind}] mode:keep flags[ItemCount;IsEmpty],'

SPECIAL={
 'Fill Empty Soap Can With UHT Milk':dict(inputs=[fluid(1.4),empty('Hydrocraft.HCDetergentemptyFluid'),'item 1 [Hydrocraft.HCFunnel;Hydrocraft.HCGlassfunnel] mode:keep,'],output='',slots=[0],litres=1.4,vesselSlot=1,vesselType='Hydrocraft.HCDetergentemptyFluid',marker='HCRMilk'),
 'Pour Milk into Bowl':dict(replace={0:fluid(.3,CHOCOLATE_MILK)},slots=[0],fluids=CHOCOLATE_MILK,litres=.3,foodTarget='Hydrocraft.HCRMilkBowl'),
 'Fill Wooden Bucket with Milk':dict(inputs=[empty('Hydrocraft.HCWoodenbucketFluid'),fluid(4)],output='',slots=[1],litres=4,vesselSlot=0,marker='HCRMilk'),
 'Heat Milk':dict(replace={0:fluid(4,items='Hydrocraft.HCWoodenbucketFluid')},output='',slots=[0],litres=4,vesselSlot=0,marker='HCRMilkHeated'),
 'Ferment Milk':dict(replace={0:fluid(4,['HCRMilkHeated'],'Hydrocraft.HCWoodenbucketFluid')},output='',slots=[0],litres=4,vesselSlot=0,marker='HCRMilkFermented',fluids=['HCRMilkHeated']),
 'Jar Homemade Yogurt':dict(replace={0:fluid(4,['HCRMilkFermented'])},slots=[0],litres=4,fluids=['HCRMilkFermented']),
 'Make Butter':dict(replace={0:fluid(4)},slots=[0],litres=4),
 'Fill Cheese Vat':dict(replace={1:fluid(16)},slots=[1],litres=16),
 'Make Cream Cheese Culture':dict(replace={0:fluid(4)},slots=[0],litres=4),
 'Bottle Milk':dict(replace={0:fluid(4)},slots=[0],litres=4,outputTarget='Base.Milk',count=4),
 'Pour into Carton':dict(replace={0:fluid(1)},slots=[0],litres=1,outputTarget='Base.Milk',count=1),
 'Dilute Evaporated Milk':dict(replace={0:'item 1 [Hydrocraft.HCEvaporatedmilkopen] flags[ItemCount;AllowRottenItem],'},slots=[1],fluids=['Water'],litres=1,outputTarget='Base.Milk',count=1,foodSlot=0,foodLitres=.3,variableYield=True,byproduct='Hydrocraft.HCEvaporatedmilkopenempty'),
}

def main():
    saved_path=REPO/'tools/milk_chains.json'
    old=json.loads(saved_path.read_text(encoding='utf-8')) if saved_path.exists() else {}
    rows={}
    for path in sorted(ROOT.glob('*.txt')):
        text=read_text(path);original=text
        for start,end,name,body in reversed(list(blocks(text,'craftRecipe'))):
            # Два жидких ингредиента и отдельная посуда: отдельный coffee pipeline.
            if name.startswith('Add Milk From Carton'): continue
            # Историческая запись нужна аудиту, но состав/выход этих партий
            # теперь принадлежит build_milk_cocktails.py.
            cocktail=name in ('Make Eggnog Pot','Make Monkey Tail Pot') and 'OnCreate = HCRBarDrinks.create' in body
            spec=SPECIAL.get(name)
            native=bool(re.search(r'-fluid [\d.]+ \[CowMilk\]',body))
            if spec is None and not native and name not in old: continue
            source=old.get(name,{}).get('original',body)
            body=body if cocktail else source
            match=re.search(r'inputs\s*\{([^}]*)\}',body)
            lines=re.findall(r'item [^\r\n]+(?:\r?\n\s*-fluid [^\r\n]+)?',match[1])
            spec=dict(spec or {})
            if not spec:
                slot=next(i for i,line in enumerate(lines) if '[CowMilk]' in line or (cocktail and 'HCRMilk;' in line))
                litres=.2 if 'Thermos' in name or 'Hot Chocolate' in name else .1
                allowed=CHOCOLATE_MILK if name in CHOCOLATE_RECIPES else MILK
                if name in SOY_RECIPES:allowed=allowed+['HCRMilkSoy']
                spec=dict(replace={slot:fluid(litres,allowed)},slots=[slot],fluids=allowed,litres=litres)
            for slot,replacement in spec.get('replace',{}).items(): lines[slot]=replacement
            if 'inputs' in spec: lines=spec['inputs']
            body=body[:match.start()]+'inputs\n        {\n            '+'\n            '.join(lines)+'\n        }'+body[match.end():]
            if name in SOY_RECIPES:
                body=re.sub(r'(item 1 \[Base\.(?:Mugl|Pot)\](?: mode:destroy)?) flags\[ItemCount\],',
                    r'\1 flags[ItemCount;ItemIsFluid;IsEmpty],',body)
            if 'output' in spec:
                body=re.sub(r'outputs\s*\{[^}]*\}','outputs\n        {\n        }',body)
            if spec.get('byproduct'):
                body=re.sub(r'outputs\s*\{[^}]*\}',
                    'outputs\n        {\n            item 1 '+spec['outputTarget']+',\n            item 1 '+spec['byproduct']+',\n        }',body)
            # Старые callbacks безусловно создают пустое ведро. Теперь оно kept.
            body=re.sub(r'(?m)^\s*OnCreate = HCR42\.recipe_hcwoodenbucket\d*,\r?\n','\n',body)
            # Старый OnTest проверял пустую тару по ID, включая занятую source
            # бутылку. Новая проверка выполняется по конкретному applied slot.
            if name in ('Fill Wooden Bucket with Milk','Fill Empty Soap Can With UHT Milk'):
                body=re.sub(r'(?m)^\s*OnTest = HCRFluidRecipes\.Test_\w+,\r?\n','\n',body)
            token=hashlib.sha256(name.encode()).hexdigest()[:12]
            if 'marker' in spec or 'outputTarget' in spec or 'foodTarget' in spec:
                body,_=callback(body,'OnCreate','HCRMilkChains.Create_'+token)
            if not cocktail:body,_=callback(body,'Tooltip','Tooltip_HCR_MilkChain_'+token)
            body,_=callback(body,'Icon','HCMilkjug')
            rows[name]=dict(spec,original=source,file=path.name,token=token)
            text=text[:start]+body+text[end:]
        if text!=original: path.write_text(text,encoding='utf-8')
    assert len(rows)==21,len(rows)
    saved_path.write_text(json.dumps(rows,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    rules={name:dict(slots={i:True for i in spec['slots']},fluids=spec.get('fluids',MILK),
        nativeMilk=True,nutrition='fixed-output') for name,spec in rows.items()}
    products={s['token']:dict(name=name,**{k:v for k,v in s.items() if k not in ('original','replace','inputs','output','token','file')})
        for name,s in rows.items() if 'marker' in s or 'outputTarget' in s or 'foodTarget' in s}
    (LUA/'shared/HCR_MilkChainRules.lua').write_text('-- Генерируется tools/build_milk_chains.py.\nHCRMilkChainRules = '+lua(rules)+'\nHCRMilkChainProducts = '+lua(products)+'\n',encoding='utf-8')
    families={
        'Hydrocraft.HCWoodenbucketmilk':dict(target='Hydrocraft.HCWoodenbucketFluid',litres=4,fluid='HCRMilk',enabled=True,milk=True),
        'Hydrocraft.HCWoodenbucketheatedmilk':dict(target='Hydrocraft.HCWoodenbucketFluid',litres=4,fluid='HCRMilkHeated',enabled=True,milk=True,normalStage=True),
        'Hydrocraft.HCWoodenbucketfermentedmilk':dict(target='Hydrocraft.HCWoodenbucketFluid',litres=4,fluid='HCRMilkFermented',enabled=True,milk=True,normalStage=True),
        'Hydrocraft.HCUHTmilk':dict(target='Hydrocraft.HCUHTmilkFluid',litres=1,fluid='HCRMilk',enabled=True,milk=True),
        'Hydrocraft.HCPlasticcanmilk':dict(target='Hydrocraft.HCPlasticcanemptyFluid',litres=1.4,fluid='HCRMilk',enabled=True,milk=True),
        'Hydrocraft.HCDetergentmilk':dict(target='Hydrocraft.HCDetergentemptyFluid',litres=1.4,fluid='HCRMilk',enabled=True,milk=True),
        'Hydrocraft.HCMilkjug':dict(target='Hydrocraft.HCMilkjugemptyFluid',litres=2,fluid='HCRMilk',enabled=True,milk=True),
        'Hydrocraft.HCMilkjugchocolate':dict(target='Hydrocraft.HCMilkjugchocolateemptyFluid',litres=2,fluid='HCRMilkChocolate',enabled=True,milk=True),
    }
    (LUA/'shared/HCR_MilkFamilies.lua').write_text('-- Генерируется tools/build_milk_chains.py.\nrequire "HCR_DrinkFamilies"\nHCRMilkFamilies = '+lua(families)+'\nfor kind,spec in pairs(HCRMilkFamilies) do HCRDrinkFamilies[kind]=spec end\n',encoding='utf-8')
    for lang in ('EN','RU'):
        p=LUA/f'shared/Translate/{lang}/ItemName.json';names=json.loads(p.read_text(encoding='utf-8'))
        names['Hydrocraft.HCUHTmilkFluid']='UHT Milk Carton' if lang=='EN' else 'Пакет ультрапастеризованного молока'
        p.write_text(json.dumps(names,ensure_ascii=False,indent=4)+'\n',encoding='utf-8')
        p=LUA/f'shared/Translate/{lang}/Tooltip.json';translations=json.loads(p.read_text(encoding='utf-8'))
        for s in rows.values():
            translations['Tooltip_HCR_MilkChain_'+s['token']]=(
                f'Batch: {s["litres"]:g} L. Milk vessels are retained; legacy empty cartons are replaced when filled. Freshness and poison follow the ingredients. Other drink mixtures are unsuitable.' if lang=='EN' else
                f'Объём партии: {s["litres"]:g} л. Сосуды с молоком сохраняются; старые пустые пакеты заменяются при наполнении. Свежесть и яд переходят из ингредиентов. Другие смеси напитков не подходят.')
            if s.get('foodTarget'):
                translations['Tooltip_HCR_MilkChain_'+s['token']]=(
                    'Pour 0.3 L of thawed milk into an empty bowl for use in dishes. Nutrition, freshness and poison are retained. This portion cannot be frozen. Tainted milk and unsupported medicinal mixtures are unsuitable.' if lang=='EN' else
                    'Налить 0,3 л оттаявшего молока в пустую миску для добавления в блюда. Питание, свежесть и яд сохраняются. Порцию нельзя заморозить. Заражённое молоко и неподдерживаемые лечебные смеси не подходят.')
            if s.get('variableYield'):
                translations['Tooltip_HCR_MilkChain_'+s['token']]=(
                    'Mix 0.7 L of water with the remaining concentrate. A full can yields 1 L; a half-full can yields 0.85 L. Nutrition, freshness and contaminants are retained. Diluted milk can be used in milk recipes.' if lang=='EN' else
                    'Смешать 0,7 л воды с оставшимся концентратом. Полная банка даёт 1 л, половина банки — 0,85 л. Питание, свежесть и примеси сохраняются. Разбавленное молоко подходит для молочных рецептов.')
            if s['token'] in {hashlib.sha256(name.encode()).hexdigest()[:12] for name in SOY_RECIPES}:
                translations['Tooltip_HCR_MilkChain_'+s['token']]+=(
                    ' Cooked, finished soy milk uses the same volume. Dilute evaporated milk first.' if lang=='EN' else
                    ' Готовое соевое молоко расходуется в том же объёме. Концентрированное молоко сначала разбавьте.')
        p.write_text(json.dumps(translations,ensure_ascii=False,indent=4)+'\n',encoding='utf-8')
    # Правила водяной тары сохраняются для остальных рецептов; эти строки
    # теперь обслуживает явный milk pipeline.
    for filename in ('physical_container_migrations.json','water_recipe_migrations.json'):
        p=REPO/'tools'/filename
        if not p.exists(): continue
        record=json.loads(p.read_text(encoding='utf-8'))
        if not isinstance(record,dict) or 'migrations' not in record: continue
        active=[]
        for entry in record['migrations']:
            if entry.get('recipe') in SPECIAL:
                entry['supersededBy']='milk-chain-1.6'
                record.setdefault('superseded_migrations',[]).append(entry)
            else: active.append(entry)
        record['migrations']=active
        p.write_text(json.dumps(record,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print(f'Milk core: {len(rows)} recipes; {len(products)} callbacks; {len(families)} legacy migrations')

if __name__=='__main__': main()

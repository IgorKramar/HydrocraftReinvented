"""Домашний лимонад: .1 L сока + .2 L воды дают .3 L в прежнем сосуде."""
import hashlib
import json
import re
from apply_playability_fixes import blocks
from build_juice_catalog import lua
from convert_water_recipes import callback
from hcr_paths import LUA,REPO,SCRIPTS,read_text

PRODUCTS={
    'Make Bottle of Juice':('Hydrocraft.HCLemonade1','Base.PopBottle',2),
    'Make Bottle of Juice (Homemade Lemonade)':('Hydrocraft.HCLemonade2','Base.WaterBottle',1),
}


def main():
    path=SCRIPTS/'HydrocraftReinvented/HCR_Food Juice.txt'
    text=read_text(path)
    rules={}
    families={}
    for name,(source,target,capacity) in PRODUCTS.items():
        token=hashlib.sha256(name.encode()).hexdigest()[:12]
        rules[token]=dict(name=name,sourceFood=source,target=target,fluid='HCRLemonade',
            litres=.3,vesselSlot=3,nutrition='fixed-output')
        families[source]=dict(target=target,litres=capacity,fluid='HCRLemonade',
            enabled=True,product=True,policy='legacy-native-vessel-capacity; current Food snapshot')
    for start,end,name,body in reversed(list(blocks(text,'craftRecipe'))):
        if name not in PRODUCTS:
            continue
        token=hashlib.sha256(name.encode()).hexdigest()[:12]
        rule=rules[token]
        if 'HCRDrinkProducts.Create_' not in body:
            body=body.replace('[Base.WaterBottle;Base.WaterBottle]','[Base.WaterBottle]')
            old=f'item 1 [{rule["target"]}] mode:destroy flags[ItemCount],'
            assert old in body,name
            body=body.replace(old,f'item 1 [{rule["target"]}] mode:keep flags[ItemCount;IsEmpty],')
            body,count=re.subn(r'outputs\s*\{\s*item 1 '+re.escape(rule['sourceFood'])+r',\s*\}',
                              'outputs\n        {\n        }',body)
            assert count==1,name
        body,previous=callback(body,'OnCreate','HCRDrinkProducts.Create_'+token)
        assert not previous or previous=='HCRDrinkProducts.Create_'+token,name
        body,_=callback(body,'Tooltip','Tooltip_HCR_DrinkProduct_'+token)
        body,_=callback(body,'Icon',rule['sourceFood'].split('.')[1])
        text=text[:start]+body+text[end:]
    path.write_text(text,encoding='utf-8')
    physical_path=REPO/'tools/physical_container_migrations.json'
    physical=json.loads(physical_path.read_text(encoding='utf-8'))
    remaining=[]
    for row in physical['migrations']:
        if row['file']==path.name and row['recipe'] in PRODUCTS:
            row['supersededBy']='drink-product-1.6: fill the same empty vessel'
            physical['superseded_migrations'].append(row)
        else:
            remaining.append(row)
    physical['migrations']=remaining
    physical_path.write_text(json.dumps(physical,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    (REPO/'tools/drink_product_rules.json').write_text(json.dumps(rules,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    (LUA/'shared/HCR_DrinkProductRules.lua').write_text(
        '-- Генерируется tools/build_drink_products.py.\nHCRDrinkProductRules = '+lua(rules)+'\n',encoding='utf-8')
    (LUA/'shared/HCR_DrinkProductFamilies.lua').write_text(
        '-- Генерируется tools/build_drink_products.py.\nrequire "HCR_DrinkFamilies"\n'
        +'HCRDrinkProductFamilies = '+lua(families)+'\n'
        +'for kind,spec in pairs(HCRDrinkProductFamilies) do HCRDrinkFamilies[kind]=spec end\n',encoding='utf-8')
    for lang in ('EN','RU'):
        dest=LUA/f'shared/Translate/{lang}/Tooltip.json'
        translations=json.loads(dest.read_text(encoding='utf-8'))
        for token in rules:
            translations['Tooltip_HCR_DrinkProduct_'+token]=(
                'Yield: 0.3 L from 0.1 L lemon juice and 0.2 L clean water. The empty bottle is retained. Freshness follows the worst ingredient. Other drink mixtures are unsuitable.' if lang=='EN' else
                'Выход: 0,3 л из 0,1 л лимонного сока и 0,2 л чистой воды. Пустая бутылка сохраняется. Свежесть определяется худшим ингредиентом. Другие смеси напитков не подходят.')
        dest.write_text(json.dumps(translations,ensure_ascii=False,indent=4)+'\n',encoding='utf-8')
    print('Lemonade products=2; uniform native yield=0.3 L; legacy migrations=2')


if __name__=='__main__': main()

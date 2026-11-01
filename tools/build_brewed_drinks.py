"""Завершение заваривания и измеряемый молочный кофе; исходные Food ID остаются."""
import json
import re
from apply_playability_fixes import blocks
from build_juice_catalog import lua
from hcr_paths import LUA,REPO,SCRIPTS,read_text

FINISH={
 'Finish Brewing Black Coffee':('HCCoffeeblack','Base.Mugl',.2,'HCRCoffee',True,'Закончить заваривание чёрного кофе'),
 'Finish Brewing Clay Mug Coffee':('HCCoffeeblack2','Hydrocraft.HCClaymugFluid',.2,'HCRCoffee',True,'Закончить заваривание кофе в глиняной кружке'),
 'Finish Brewing Sweet Coffee':('HCCoffeeblacksugar','Base.Mugl',.2,'HCRCoffeeSweet',True,'Закончить заваривание кофе с сахаром'),
 'Finish Brewing Sweet Clay Mug Coffee':('HCCoffeeblack2sugar','Hydrocraft.HCClaymugFluid',.2,'HCRCoffeeSweet',True,'Закончить заваривание сладкого кофе в глиняной кружке'),
 'Finish Brewing Milk Coffee':('HCCoffeeblacksugarmilk','Base.Mugl',.2,'HCRCoffeeMilk',True,'Закончить заваривание кофе с молоком'),
 'Finish Brewing Clay Mug Milk Coffee':('HCCoffeeblack2sugarmilk','Hydrocraft.HCClaymugFluid',.2,'HCRCoffeeMilk',True,'Закончить заваривание молочного кофе в глиняной кружке'),
 'Finish Brewing Coffee Kettle':('HCKettlecoffee','Base.Kettle',1.5,'HCRCoffee',True,'Закончить заваривание чайника кофе'),
 'Prepare Thermos Coffee for Pouring':('HCThermoscoffee','Hydrocraft.HCThermosFluid',1.4,'HCRCoffee',False,'Подготовить кофе в термосе к переливанию'),
 'Prepare Sweet Thermos Coffee for Pouring':('HCThermoscoffeesugar','Hydrocraft.HCThermosFluid',1.4,'HCRCoffeeSweet',False,'Подготовить сладкий кофе в термосе к переливанию'),
 'Prepare Thermos Milk Coffee for Pouring':('HCThermoscoffeesugarmilk','Hydrocraft.HCThermosFluid',1.4,'HCRCoffeeMilk',False,'Подготовить молочный кофе в термосе к переливанию'),
 'Prepare Hot Chocolate for Pouring':('HCCococup','Base.Mugl',.2,'HCRCocoa',False,'Подготовить горячий шоколад к переливанию'),
 'Prepare Clay Mug Hot Chocolate for Pouring':('HCCococup2','Hydrocraft.HCClaymugFluid',.2,'HCRCocoa',False,'Подготовить горячий шоколад в глиняной кружке к переливанию'),
 'Finish Preparing Soy Milk':('HCSoymilk','Base.Whiskey',1,'HCRMilkSoy',True,'Завершить приготовление соевого молока'),
}
COFFEE=['Coffee','HCRCoffee','HCRCoffeeSweet']
MILK=['HCRMilk','CowMilk','SheepMilk','AnimalMilk']

def fluid_input(amount,kinds):
    return ('            item 1 [*] mode:keep flags[ItemIsFluid;HandcraftOnly],\n'
            f'            -fluid {amount:g} ['+';'.join(kinds)+'] mode:primary,')

def replace_body(body,inputs,create=True,tooltip='Tooltip_HCR_CoffeePour'):
    body=re.sub(r'(?m)^\s*(?:OnCreate|OnTest|Tooltip|Icon)\s*=.*?,\r?\n','\n',body)
    added=f'\n        Tooltip = {tooltip},'
    if create: added+='\n        OnCreate = HCRBrewedDrinks.create,'
    body=body.replace('    {','    {'+added,1)
    body=re.sub(r'inputs\s*\{[^}]*\}',lambda _:'inputs\n        {\n'+inputs+'\n        }',body)
    if create: body=re.sub(r'outputs\s*\{[^}]*\}','outputs\n        {\n        }',body)
    return re.sub(r'\n\s*\n','\n',body)


def main():
    rules={};script=['module Hydrocraft','{']
    recipes={lang:{} for lang in ('RU','EN')}
    for name,(source,target,litres,marker,cookable,ru) in FINISH.items():
        rules[name]=dict(finish=True,source='Hydrocraft.'+source,target=target,litres=litres,
                         marker=marker,cookable=cookable)
        script.extend([f'    craftRecipe {name}','    {','        time = 20,',
                       '        category = Cooking,','        Tags = AnySurfaceCraft,',
                       '        OnCreate = HCRBrewedDrinks.create,',
                       '        Tooltip = '+('Tooltip_HCR_FinishSoy' if source=='HCSoymilk' else 'Tooltip_HCR_FinishBrew')+','])
        if cookable: script.append('        OnTest = HCRBrewedDrinks.TestCooked,')
        script.extend(['        inputs','        {',
                       f'            item 1 [Hydrocraft.{source}] mode:destroy flags[ItemCount;AllowRottenItem;AllowFavorite;InheritFavorite],',
                       '        }','        outputs','        {',f'            item 1 {target},','        }','    }'])
        recipes['RU'][name]=ru;recipes['EN'][name]=name
    script.append('}')
    (SCRIPTS/'HydrocraftReinvented/HCR_BrewedDrinks.txt').write_text('\n'.join(script)+'\n',encoding='utf-8')
    path=SCRIPTS/'HydrocraftReinvented/HCR_Food Drinks.txt';text=read_text(path)
    for start,end,name,body in reversed(list(blocks(text,'craftRecipe'))):
        if name in ('Brew Black Coffee','Brew Black Coffee (Cup of Black Coffee)','Prepare Black Coffee Kettle'):
            clay=name=='Brew Black Coffee';kettle=name=='Prepare Black Coffee Kettle'
            targets=['Base.Kettle'] if kettle else (['Hydrocraft.HCClaymugFluid'] if clay else ['Base.MugWhite','Base.Mugl'])
            litres=1.5 if kettle else .2
            rules[name]=dict(brew=True,waterSlot=1,vesselSlot=0,litres=litres,
                             inputs={1:dict(fluids=['Water'])})
            lines='            item 1 ['+';'.join(targets)+'] mode:destroy flags[ItemCount;ItemIsFluid;IsEmpty],\n'
            lines+=fluid_input(litres,['Water'])+'\n'
            lines+=('            item 10 [Base.Coffee2;Hydrocraft.HCCoffeelarge],\n            item 1 [Hydrocraft.HCCoffeefilterdry],' if kettle else '            item 6 [Base.Coffee2],')
            body=replace_body(body,lines,False,'Tooltip_HCR_CoffeeBrew')
            text=text[:start]+body+text[end:];continue
        pour=name.startswith('Pour Black Coffee into ')
        sugar=name.startswith(('Add Sugar From Bag','Add Sugar Cubes'))
        milk=name.startswith(('Add Milk From Carton','Add Milk From Jug'))
        if not (pour or sugar or milk): continue
        thermos='Thermos' in name;clay='Cup of Coffee' in name
        clay=clay or (pour and '(Cup of Black Coffee)' in name)
        target='Hydrocraft.HCThermosFluid' if thermos else ('Hydrocraft.HCClaymugFluid' if clay else 'Base.Mugl')
        if pour or sugar:
            amount=1.4 if thermos else .2
            rules[name]=dict(inputs={0:dict(fluids=['Coffee','HCRCoffee'],nativeWine='HCRCoffee')},
                             target=target,vesselSlot=0 if sugar else 1,litres=amount,
                             marker='HCRCoffeeSweet' if sugar else 'HCRCoffee')
            lines=fluid_input(amount,['Coffee','HCRCoffee'])+'\n'
            if sugar:
                rules[name]['foodSlot']=1
                rules[name]['foodType']='Hydrocraft.HCSugarcubes' if name.startswith('Add Sugar Cubes') else 'Base.Sugar'
                rules[name]['inPlace']=True
                rules[name]['inputs'][0]['exact']=amount
                lines=lines.replace('[*]',f'[{target}]',1)
                count=2 if thermos and name.startswith('Add Sugar Cubes') else 1
                lines+=f'            item {count} ['+('Hydrocraft.HCSugarcubes' if name.startswith('Add Sugar Cubes') else 'Base.Sugar')+'] flags[AllowRottenItem],'
            else: lines+=f'            item 1 [{target}] mode:keep flags[ItemCount;ItemIsFluid;IsEmpty],'
            body=replace_body(body,lines,tooltip='Tooltip_HCR_CoffeeSugar' if sugar else 'Tooltip_HCR_CoffeePour')
            text=text[:start]+body+text[end:];continue
        amount=.7 if thermos else .1
        rules[name]=dict(inputs={0:dict(fluids=COFFEE,nativeWine='HCRCoffee'),
                                1:dict(fluids=MILK,nativeMilk=True)},
                         target=target,vesselSlot=2,litres=2*amount,marker='HCRCoffeeMilk')
        body=re.sub(r'(?m)^\s*(?:OnCreate|OnTest|Tooltip|Icon)\s*=.*?,\r?\n','\n',body)
        body=body.replace('    {','    {\n        OnCreate = HCRBrewedDrinks.create,\n        Tooltip = Tooltip_HCR_MilkCoffee,',1)
        inputs=('inputs\n        {\n'
                '            item 1 [*] mode:keep flags[ItemIsFluid;HandcraftOnly],\n'
                f'            -fluid {amount:g} ['+';'.join(COFFEE)+'] mode:primary,\n'
                '            item 1 [*] mode:keep flags[ItemIsFluid;HandcraftOnly],\n'
                f'            -fluid {amount:g} ['+';'.join(MILK)+'] mode:primary,\n'
                f'            item 1 [{target}] mode:keep flags[ItemCount;ItemIsFluid;IsEmpty],\n'
                '        }')
        body=re.sub(r'inputs\s*\{[^}]*\}',lambda _:inputs,body)
        body=re.sub(r'outputs\s*\{[^}]*\}','outputs\n        {\n        }',body)
        body=re.sub(r'\n\s*\n','\n',body)
        text=text[:start]+body+text[end:]
    path.write_text(text,encoding='utf-8')
    assert len(rules)==31,len(rules)
    (LUA/'shared/HCR_BrewedDrinkRules.lua').write_text(
        '-- Генерируется tools/build_brewed_drinks.py.\nHCRBrewedDrinkRules = '+lua(rules)+'\n',encoding='utf-8')
    (REPO/'tools/brewed_drink_rules.json').write_text(json.dumps(rules,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    tooltips={
      'RU':{'Tooltip_HCR_FinishBrew':'Завершить приготовление и подготовить напиток к переливанию. Кофе сначала нужно заварить на источнике тепла. Сохраняются остаток, питание, подгорание, свежесть и примеси; дополнительная пустая посуда не появляется.',
            'Tooltip_HCR_MilkCoffee':'Кружка: 0,1 л кофе + 0,1 л молока. Термос: по 0,7 л. Нужна отдельная пустая ёмкость; остатки в исходных сосудах сохраняются. Питание, свежесть и примеси переходят из обоих ингредиентов.'},
      'EN':{'Tooltip_HCR_FinishBrew':'Finish preparation and make the drink pourable. Coffee must first be brewed over heat. The remaining amount, nutrition, burning, freshness and contaminants are retained; no extra empty vessel is created.',
            'Tooltip_HCR_MilkCoffee':'Mug: 0.1 L coffee + 0.1 L milk. Thermos: 0.7 L of each. Requires a separate empty vessel; leftovers stay in their original containers. Nutrition, freshness and contaminants follow both ingredients.'}}
    for lang in ('RU','EN'):
        tooltips[lang].update({
            'Tooltip_HCR_FinishSoy': 'Сначала приготовьте соевое молоко на источнике тепла. Завершение делает его доступным для переливания, сохраняя остаток, питание, свежесть, примеси и подгорание. Дополнительная пустая бутылка не появляется.' if lang=='RU' else 'Cook the soy milk over heat first. Finishing makes it pourable, retaining the remainder, nutrition, freshness, contaminants and burning. No extra empty bottle is created.',
            'Tooltip_HCR_CoffeeBrew': 'Пустая кружка и 0,2 л чистой воды из отдельного сосуда; для чайника 1,5 л. Затем заварите кофе на источнике тепла и завершите приготовление.' if lang=='RU' else 'Requires an empty mug and 0.2 L of clean water from another vessel, or 1.5 L for a kettle. Brew over heat, then finish preparation.',
            'Tooltip_HCR_CoffeePour': 'Перелить 0,2 л заваренного кофе в пустую кружку или 1,4 л в термос. Остаток и свойства напитка сохраняются.' if lang=='RU' else 'Pour 0.2 L of brewed coffee into an empty mug, or 1.4 L into a thermos. The remainder and drink properties are retained.',
            'Tooltip_HCR_CoffeeSugar': 'Добавить сахар в 0,2 л кофе в кружке или 1,4 л в термосе. Сохраняются тот же сосуд, питание, свежесть и примеси обоих ингредиентов.' if lang=='RU' else 'Add sugar to 0.2 L of coffee in a mug or 1.4 L in a thermos. The vessel, nutrition, freshness and contaminants from both ingredients are retained.',
        })
        for filename,values in (('Recipes',recipes[lang]),('Tooltip',tooltips[lang])):
            dest=LUA/f'shared/Translate/{lang}/{filename}.json'
            data=json.loads(dest.read_text(encoding='utf-8'));data.update(values)
            dest.write_text(json.dumps(data,ensure_ascii=False,indent=4)+'\n',encoding='utf-8')
    print('Brewed drinks: 13 finishes, 3 brewers, 3 pours, 6 sugar and 6 milk recipes')


if __name__=='__main__': main()

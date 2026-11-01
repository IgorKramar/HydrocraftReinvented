"""Замкнутая группа магазинных соков: нет craft-потребителей/производителей."""
import json
from build_juice_catalog import lua
from hcr_paths import LUA,REPO,SCRIPTS


def catalogue():
    rows={
        'HCOJ':('Base.PopBottle',2,'HCRJuiceOrange'),
        'HCCranberryjug':('Base.PopBottle',2,'HCRJuiceCranberry'),
    }
    for flavour,fluid,target in (
        ('apple','JuiceApple','Base.JuiceBoxApple'),
        ('orange','JuiceOrange','Base.JuiceBoxOrange'),
        ('grape','JuiceGrape','Base.JuiceBox'),
        ('cherry','JuiceCherry','Hydrocraft.HCEmptyjuiceboxcherryFluid'),
        ('lemonaid','Lemonade','Hydrocraft.HCEmptyjuiceboxlemonaidFluid'),
        ('pinklemonaid','LemonadePink','Hydrocraft.HCEmptyjuiceboxpinklemonaidFluid'),
    ):
        rows['HCJuicebox'+flavour]=(target,.2,'HCR'+fluid)
    result={}
    for source,(target,litres,fluid) in rows.items():
        result['Hydrocraft.'+source]=dict(target=target,litres=litres,fluid=fluid,
            enabled=True,retail=True,lootOnly=True,
            policy='native-returned-vessel-capacity; preserve-current-Food-properties')
        if source.startswith('HCJuicebox'):
            empty=source.replace('HCJuicebox','HCEmptyjuicebox')
            result['Hydrocraft.'+empty]=dict(target=target,litres=0,enabled=True,
                empty=True,retail=True,lootOnly=True,policy='empty-stays-empty')
    return result


def main():
    catalog=catalogue()
    (REPO/'tools/retail_drink_families.json').write_text(json.dumps(catalog,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    (LUA/'shared/HCR_RetailDrinkFamilies.lua').write_text(
        '-- Генерируется tools/build_retail_drinks.py.\nrequire "HCR_DrinkFamilies"\n'
        +'HCRRetailDrinkFamilies = '+lua(catalog)+'\n'
        +'for kind,spec in pairs(HCRRetailDrinkFamilies) do HCRDrinkFamilies[kind]=spec end\n',encoding='utf-8')
    translations={lang:json.loads((LUA/f'shared/Translate/{lang}/ItemName.json').read_text(encoding='utf-8')) for lang in ('EN','RU')}
    script=['module Hydrocraft','{','    /* Старые Normal ID остаются загрузочными прототипами. */']
    for flavour in ('cherry','lemonaid','pinklemonaid'):
        source='HCEmptyjuicebox'+flavour
        target=source+'Fluid'
        script += [f'    item {target}','    {','        ItemType = base:normal,',
            '        DisplayName = Juice Carton,','        DisplayCategory = WaterContainer,',
            '        Weight = 0.1,',f'        Icon = {source},','        EatType = Popcan,',
            '        CustomContextMenu = Drink,','        Eattime = 160,',
            '        component FluidContainer','        {','            ContainerName = Carton,',
            '            Capacity = 0.2,','            CustomDrinkSound = DrinkingFromCarton,',
            '        }','    }']
        translations['EN']['Hydrocraft.'+target]='Juice Carton'
        translations['RU']['Hydrocraft.'+target]='Пакет сока'
    script.append('}')
    (SCRIPTS/'HydrocraftReinvented/HCR_DrinkContainers.txt').write_text('\n'.join(script)+'\n',encoding='utf-8')
    for lang,rows in translations.items():
        (LUA/f'shared/Translate/{lang}/ItemName.json').write_text(json.dumps(rows,ensure_ascii=False,indent=4)+'\n',encoding='utf-8')
    print(f'Retail drink migrations={len(catalog)}; drink targets=8; empty cartons=6; new vessels=3')


if __name__=='__main__': main()

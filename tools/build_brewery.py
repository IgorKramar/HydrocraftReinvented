"""Новая малая пивоварня: отдельная рецептура, не изменение старого пива HC."""
import json
from build_juice_catalog import lua
from hcr_paths import LUA, REPO, SCRIPTS, read_text

ACTIVE = 'Hydrocraft.HCRWheatWortBatch'
READY = 'Hydrocraft.HCRWheatBeerBatch'
RAW = 'Hydrocraft.HCRWheatWortPot'


def main():
    catalog = dict(
        transitions={ACTIVE: dict(target=READY, hours=168)},
        stages={ACTIVE: dict(marker='HCRBeerWort'), READY: dict(marker='HCRBeer', nativeFluid='Beer', freshDays=14, rottenDays=30, preserveBurnt=True)},
        rules={
            'Prepare Wheat Wort': dict(brew=True, waterSlot=1, vesselSlot=0, litres=1.5,
                                      inputs={1: dict(fluids=['Water'], pure=True)}),
            'Start Wheat Beer Fermentation': dict(finish=True, source=RAW, target='Base.Pot',
                                                  litres=1.5, marker='HCRBeerWort', cookable=True, ferment=ACTIVE),
        },
    )
    (REPO/'tools/brewery_catalog.json').write_text(json.dumps(catalog, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
    (LUA/'shared/HCR_BreweryCatalog.lua').write_text('-- Генерируется tools/build_brewery.py. Новая рецептура 1.6.0.\nHCRBreweryCatalog = '+lua(catalog)+'\n', encoding='utf-8')
    script = '''module Hydrocraft
{
    item HCRWheatWortPot
    {
        ItemType = base:food,
        DisplayCategory = Cooking,
        DisplayName = Pot of Wheat Wort,
        Icon = PotFull,
        Weight = 2.5,
        HungerChange = -15,
        ThirstChange = -30,
        Calories = 750,
        Carbohydrates = 54,
        Proteins = 6,
        Lipids = 0,
        IsCookable = true,
        MinutesToCook = 60,
        MinutesToBurn = 120,
        DaysFresh = 2,
        DaysTotallyRotten = 4,
        ReplaceOnUse = Base.Pot,
        Tooltip = Tooltip_HCR_WheatWort,
    }
    craftRecipe Prepare Wheat Wort
    {
        time = 100,
        category = Cooking,
        Tags = AnySurfaceCraft,
        timedAction = Making,
        SkillRequired = Cooking:3,
        xpAward = Cooking:4,
        Tooltip = Tooltip_HCR_WheatWort,
        inputs
        {
            item 1 [Base.Pot] mode:destroy flags[ItemCount;ItemIsFluid;IsEmpty],
            item 1 [*] mode:keep flags[ItemIsFluid;HandcraftOnly],
            -fluid 1.5 [Water] mode:primary,
            item 30 [Hydrocraft.HCWheat],
            item 1 [Hydrocraft.HCHops],
        }
        outputs
        {
            item 1 Hydrocraft.HCRWheatWortPot,
        }
    }
    craftRecipe Start Wheat Beer Fermentation
    {
        time = 20,
        category = Cooking,
        Tags = AnySurfaceCraft,
        SkillRequired = Cooking:3,
        xpAward = Cooking:4,
        OnTest = HCRBrewedDrinks.TestCookedOrNotFood,
        OnCreate = HCRBrewedDrinks.create,
        Tooltip = Tooltip_HCR_WheatBeer,
        inputs
        {
            item 1 [Hydrocraft.HCRWheatWortPot] mode:destroy flags[ItemCount;AllowRottenItem;AllowFavorite;InheritFavorite],
            item 1 [Base.Yeast],
        }
        outputs
        {
            item 1 Base.Pot,
        }
    }
}
'''
    (SCRIPTS/'HydrocraftReinvented/HCR_Brewery.txt').write_text(script, encoding='utf-8')
    forage = '''-- Хмель возобновляется через штатный поиск; старый loot сохранён.
require 'Foraging/forageDefinitions'
require 'Foraging/forageSystem'
local function addHops()
    forageSystem.addForageDef('HCRHops',{
        type='Hydrocraft.HCHops',skill=4,minCount=1,maxCount=2,xp=3,
        categories={'WildHerbs'},
        zones={Forest=1,DeepForest=1,BirchForest=1,OrganicForest=1,
            PHForest=1,PRForest=1,FarmLand=1,Vegitation=1},
        months={8,9,10},bonusMonths={9},spawnFuncs={},
        altWorldTexture=forageSystem.worldSprites.wildPlants,
    })
end
Events.preAddForageDefs.Add(addHops)
'''
    (LUA/'shared/HCR_BreweryForage.lua').write_text(forage, encoding='utf-8')
    for lang in ('RU', 'EN'):
        groups = {
            'ItemName': {RAW: 'Кастрюля пшеничного сусла' if lang == 'RU' else 'Pot of Wheat Wort'},
            'Recipes': {
                'Prepare Wheat Wort': 'Приготовить пшеничное сусло' if lang == 'RU' else 'Prepare Wheat Wort',
                'Start Wheat Beer Fermentation': 'Начать брожение пшеничного пива' if lang == 'RU' else 'Start Wheat Beer Fermentation',
            },
            'Tooltip': {
                'Tooltip_HCR_WheatWort': (
                    '1,5 л воды, 30 порций пшеницы и хмель. Нагрейте сусло до готовности, затем добавьте дрожжи рецептом брожения. Оставленное на огне сусло может подгореть. Хмель можно найти поиском в лесу и на полях в августе — октябре.'
                    if lang == 'RU' else
                    'Use 1.5 L of water, 30 portions of wheat and hops. Cook the wort, then add yeast using the fermentation recipe. Wort left on the heat can burn. Forage for hops in woods and farmland from August to October.'),
                'Tooltip_HCR_WheatBeer': (
                    'Добавить одну порцию дрожжей в приготовленное сусло. Через 7 дней получится до 1,5 л пива. Частично использованное сусло даёт соответствующий объём. После начала брожения жидкость можно переливать; сроки партий сохраняются.'
                    if lang == 'RU' else
                    'Add one measure of yeast to cooked wort. It becomes up to 1.5 L of beer after seven days. Partly used wort yields the remaining volume. Once fermentation starts, the liquid can be poured without resetting its age.'),
            },
            'Fluids': {'Fluid_Name_HCRBeerWort': 'Пшеничное сусло (бродит)' if lang == 'RU' else 'Wheat Wort (Fermenting)'},
        }
        for group, additions in groups.items():
            path=LUA/f'shared/Translate/{lang}/{group}.json'
            data=json.loads(read_text(path));data.update(additions)
            path.write_text(json.dumps(data,ensure_ascii=False,indent=4)+'\n',encoding='utf-8')
    print('Brewery: 1.5 L wheat wort, native cooking, one yeast use, seven days fermentation')


if __name__ == '__main__':
    main()

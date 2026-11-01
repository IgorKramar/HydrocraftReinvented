"""Register neutral transport fluids; all nutritional/quality effects live in batches."""
import json
from build_mash_chains import MASHES
from hcr_paths import LUA, SCRIPTS

# Native colour references; labels are deliberately separate from vessel names.
FLAVOURS = [
    ('JuiceApple', 'Khaki', 'Apple juice', 'Яблочный сок'),
    ('JuiceCarrot', 'Orange', 'Carrot juice', 'Морковный сок'),
    ('JuiceGrape', 'Purple', 'Grape juice', 'Виноградный сок'),
    ('JuiceGrapeWhite', 'Khaki', 'White grape juice', 'Сок белого винограда'),
    ('JuiceLemon', 'Yellow', 'Lemon juice', 'Лимонный сок'),
    ('JuiceOrange', 'Orange', 'Orange juice', 'Апельсиновый сок'),
    ('JuiceLime', 'LimeGreen', 'Lime juice', 'Сок лайма'),
    ('JuiceStrawberry', 'Red', 'Strawberry juice', 'Клубничный сок'),
    ('JuiceTomato', 'Red', 'Tomato juice', 'Томатный сок'),
    ('JuiceWatermelon', 'Salmon', 'Watermelon juice', 'Арбузный сок'),
    ('JuicePineapple', 'Khaki', 'Pineapple juice', 'Ананасовый сок'),
    ('JuiceBlueberry', 'Purple', 'Blueberry juice', 'Черничный сок'),
    ('JuiceBlackberry', 'Purple', 'Blackberry juice', 'Ежевичный сок'),
    ('JuiceWildberry', 'Purple', 'Wild berry juice', 'Сок лесных ягод'),
    ('JuiceCherry', 'Red', 'Cherry juice', 'Вишнёвый сок'),
    ('JuiceCranberry', 'Red', 'Cranberry juice', 'Клюквенный сок'),
    ('Lemonade', 'Yellow', 'Lemonade', 'Лимонад'),
    ('LemonadePink', 'LightPink', 'Pink lemonade', 'Розовый лимонад'),
    ('Milk', 'White', 'Milk', 'Молоко'),
    ('MilkChocolate', 'Sienna', 'Chocolate milk', 'Шоколадное молоко'),
    ('MilkSoy', 'White', 'Soy milk', 'Соевое молоко'),
    ('MilkHeated', 'White', 'Heated milk', 'Подогретое молоко'),
    ('MilkFermented', 'White', 'Cultured milk', 'Сквашенное молоко'),
    ('MustRed', 'Purple', 'Red grape must', 'Сусло красного винограда'),
    ('MustWhite', 'Khaki', 'White grape must', 'Сусло белого винограда'),
    ('HoneyBrew', 'Khaki', 'Fermenting honey brew', 'Бродящая медовая смесь'),
    ('RiceMash', 'White', 'Fermenting rice mash', 'Бродящее рисовое сусло'),
    ('WineRed', 'Red', 'Red wine', 'Красное вино'),
    ('WineWhite', 'Khaki', 'White wine', 'Белое вино'),
    ('Mead', 'Khaki', 'Mead', 'Медовуха'),
    ('Sake', 'White', 'Sake', 'Саке'),
    ('Vinegar', 'Khaki', 'Vinegar', 'Уксус'),
    ('Beer', 'Khaki', 'Beer', 'Пиво'),
    ('BeerWort', 'Khaki', 'Wheat Wort (Fermenting)', 'Пшеничное сусло (бродит)'),
    ('Coffee', 'Sienna', 'Coffee', 'Кофе'),
    ('CoffeeSweet', 'Sienna', 'Coffee with sugar', 'Кофе с сахаром'),
    ('CoffeeMilk', 'Sienna', 'Coffee with milk', 'Кофе с молоком'),
    ('Cocoa', 'Sienna', 'Hot chocolate', 'Горячий шоколад'),
    ('Vodka', 'White', 'Vodka', 'Водка'),
    ('Whiskey', 'Khaki', 'Whisky', 'Виски'),
    ('WhiskeyCorn', 'Khaki', 'Corn whisky', 'Кукурузный виски'),
    ('Rum', 'Khaki', 'Rum', 'Ром'),
    ('Gin', 'White', 'Gin', 'Джин'),
    ('Tequila', 'White', 'Tequila', 'Текила'),
    ('Mezcal', 'White', 'Mezcal', 'Мескаль'),
    ('Applejack', 'Khaki', 'Applejack', 'Яблочный бренди'),
    ('PeachSchnapps', 'Khaki', 'Peach schnapps', 'Персиковый шнапс'),
    ('Flip', 'Orange', 'Pumpkin spirit', 'Тыквенный дистиллят'),
    ('Absinthe', 'LimeGreen', 'Absinthe', 'Абсент'),
    ('HerbalLiqueur', 'Khaki', 'Herbal liqueur', 'Травяной ликёр'),
    ('Aguardiente', 'White', 'Aguardiente', 'Агуардиенте'),
    ('LemonMixer', 'Yellow', 'Lemon mixer', 'Лимонная смесь'),
    ('LimeMixer', 'LimeGreen', 'Lime mixer', 'Лаймовая смесь'),
    ('BloodyMaryMixer', 'Red', 'Bloody Mary mixer', 'Смесь для «Кровавой Мэри»'),
    ('Bitters', 'Sienna', 'Bitters', 'Биттер'),
    ('Vermouth', 'Khaki', 'Vermouth', 'Вермут'),
    ('TripleSec', 'White', 'Triple sec', 'Трипл-сек'),
    ('SodaPop', 'Sienna', 'Pop', 'Газировка'),
    ('SodaCherry', 'Red', 'Cherry soda', 'Вишнёвая газировка'),
    ('SodaCola', 'Sienna', 'Cola', 'Кола'),
    ('SodaCream', 'Khaki', 'Cream soda', 'Крем-сода'),
    ('SodaDrPepper', 'Sienna', 'Dr Pepper', 'Доктор Пеппер'),
    ('SodaGingerAle', 'Khaki', 'Ginger ale', 'Имбирная газировка'),
    ('SodaGrape', 'Purple', 'Grape soda', 'Виноградная газировка'),
    ('SodaGrapefruit', 'Salmon', 'Grapefruit soda', 'Грейпфрутовая газировка'),
    ('SodaLemonLime', 'LimeGreen', 'Lemon-lime soda', 'Лимонно-лаймовая газировка'),
    ('SodaPineapple', 'Yellow', 'Pineapple soda', 'Ананасовая газировка'),
    ('SodaRootBeer', 'Sienna', 'Root beer', 'Рутбир'),
    ('Energy', 'LimeGreen', 'Energy drink', 'Энергетик'),
    ('Fitness', 'Khaki', 'Fitness drink', 'Фитнес-напиток'),
    ('AppleCider', 'Khaki', 'Apple cider', 'Яблочный сидр'),
    ('OldFashioned', 'Khaki', 'Old fashioned', 'Олд фэшен'),
    ('Martini', 'White', 'Martini', 'Мартини'),
    ('Manhattan', 'Sienna', 'Manhattan', 'Манхэттен'),
    ('Daiquiri', 'White', 'Daiquiri', 'Дайкири'),
    ('BloodyMary', 'Red', 'Bloody Mary', 'Кровавая Мэри'),
    ('WhiskeySour', 'Khaki', 'Whisky sour', 'Виски сауэр'),
    ('MaiTai', 'Khaki', 'Mai tai', 'Май тай'),
    ('Cosmopolitan', 'Red', 'Cosmopolitan', 'Космополитен'),
    ('TomCollins', 'White', 'Tom Collins', 'Том Коллинз'),
    ('LongIsland', 'Sienna', 'Long Island iced tea', 'Лонг-Айленд айс ти'),
    ('Gimlet', 'LimeGreen', 'Gimlet', 'Гимлет'),
    ('PlantersPunch', 'Khaki', "Planter’s punch", 'Пунш плантатора'),
    ('WhiskeyCola', 'Sienna', 'Whisky and cola', 'Виски с колой'),
    ('Margarita', 'LimeGreen', 'Margarita', 'Маргарита'),
    ('IrishCoffee', 'Sienna', 'Irish coffee', 'Кофе по-ирландски'),
    ('Eggnog', 'Khaki', 'Eggnog', 'Эггног'),
    ('MonkeyTail', 'Sienna', 'Monkey tail', 'Обезьяний хвост'),
]
EFFECTS = ['HungerChange', 'ThirstChange', 'UnhappyChange', 'StressChange',
           'Calories', 'Carbohydrates', 'Lipids', 'Proteins', 'alcohol',
           'fluReduction', 'painReduction', 'enduranceChange', 'fatigueChange',
           'foodSicknessChange']


def main():
    texts = {lang: json.loads((LUA / f'shared/Translate/{lang}/Fluids.json').read_text(encoding='utf-8'))
             for lang in ('EN', 'RU')}
    script = ['module Hydrocraft', '{',
              '    /* Quality and all food effects are applied exactly once by HCR_FluidEffects. */']
    lua = ['-- Generated by tools/build_drink_fluids.py.', 'require "HCR_FluidQuality"',
           'HCRDrinkFluids = {']
    for name, colour, en, ru in FLAVOURS:
        key = 'HCR' + name
        script += [f'    fluid {key}', '    {', f'        ColorReference = {colour},',
                   f'        DisplayName = Fluid_Name_{key},', '        Categories',
                   '        {', '            Beverage,', '        }', '        Properties', '        {']
        script += [f'            {effect} = 0,' for effect in EFFECTS]
        script += ['        }', '        BlendWhiteList', '        {', '            whitelist = true,',
                   '            categories', '            {', '                Beverage,',
                   '            }', '        }', '    }']
        lua.append(f'    {name} = "{key}",')
        texts['EN']['Fluid_Name_' + key] = en
        texts['RU']['Fluid_Name_' + key] = ru
    script.append('}')
    lua += ['}', 'for _, name in pairs(HCRDrinkFluids) do HCRFluidQuality.transport[name] = true end']
    (SCRIPTS/'HydrocraftReinvented/HCR_HomemadeFluids.txt').write_text('\n'.join(script)+'\n', encoding='utf-8')
    (LUA/'shared/HCR_DrinkFluids.lua').write_text('\n'.join(lua)+'\n', encoding='utf-8')
    for lang, data in texts.items():
        (LUA/f'shared/Translate/{lang}/Fluids.json').write_text(json.dumps(data, ensure_ascii=False, indent=4)+'\n', encoding='utf-8')
    for lang, text in [('EN', 'This mixture or container is unsuitable for this action. Check the liquid requirements.'),
                       ('RU', 'Эта смесь или ёмкость не подходит для выбранного действия. Проверьте требования к жидкости.')]:
        path = LUA / f'shared/Translate/{lang}/IG_UI.json'
        data = json.loads(path.read_text(encoding='utf-8'))
        data['IGUI_HCR_LiquidActionRefused'] = text
        path.write_text(json.dumps(data, ensure_ascii=False, indent=4)+'\n', encoding='utf-8')
    path = LUA/'shared/Translate/RU/ItemName.json'
    data = json.loads(path.read_text(encoding='utf-8'))
    data['Hydrocraft.HCRFluidSample'] = 'Образец качества напитка'
    path.write_text(json.dumps(data, ensure_ascii=False, indent=4)+'\n', encoding='utf-8')
    print(f'Registered neutral liquid identities: {len(FLAVOURS)}')


for token,title,_,_,ru,distills in MASHES:
    if distills:
        FLAVOURS.extend([
            ('Mash'+token, 'Khaki', title, ru),
            ('Mash'+token+'Ready', 'Khaki', 'Fermented '+title.lower(), ru+' (готова к перегонке)'),
        ])

if __name__ == '__main__':
    main()

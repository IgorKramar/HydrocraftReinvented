# Оставшиеся напитки 1.6.0: карта переноса

Source audit for the remaining bar and soft drinks; implementation and real-game
verification are tracked separately in FLUIDS_1_6_STATUS.md.

Аудит 2026-11-01 выполнен по текущим scripts/Lua и установленному B42.21.
Это рабочая карта, а не отчёт о завершённых функциях. Исходные Food ID сохраняются
для загрузки старых запасов; новый напиток получает фактически сохранённые
питание, яд и свежесть. В новых рецептах выбранный принцип объёмов распространяется
на бар: использовать реальный входной объём, подходящую тару и сохранять остаток.

## Бутылки и бокалы

`HCR_Food Bar.txt`: Bourbon1/2, Scotch1, Rum1 имеют Hunger20, 2142 ккал,
Evolved4: порция готовки 0,2 л из литровой бутылки. Три полных ромовых бокала
имели 395 ккал каждый; миграция сохраняет эти свойства, новый разлив 0,1 л
из обычного рома даёт 214,2 ккал. Rum входит также в Long Island (2 uses =0,1 л),
а полные бокалы — в Daquiri, Mai Tai и Planter's Punch. Последний раньше
дополнительно поглощал пустой бокал, хотя результат был один.

Absinth/Herballiqueur: Hunger5, Evolved4, 82/103 ккал. Для прежней порции готовки
нужно 0,8 л и подходящая тара; общий 0,2-литровый bridge не эквивалентен.
Mead2: Hunger20, Soup/Stew8, 356 ккал, unhappy−20/boredom−15; порция 0,4 л.

Aguaardiente: Hunger0, thirst−10, 2150 ккал/537 carbs, AlcoholPower3,
unhappy−25/stress−15; нет ReplaceOnUse/CantBeFrozen. Native частичное Eat
уменьшает thirst и питание, но hunger остаётся нулевым. `Food.getActualWeight`
использует current unmodified thirst / script thirst: этот узкий fallback
может восстановить обычные частичные запасы; изменённый runtime thirst не
отличим от выпитой доли. Питьевой E.consume уже умеет исходную zero-hunger
формулу. Его Evolved4 опасен: native может получить 0/0; нужен отдельный oracle,
нельзя просто снять запрет A.properties. Monkey Tail использует whole Agua,
то есть полный литр при принятой литровой бутылке.

Уточнение native evidence: Food.java из установленного projectzomboid.jar,
CFR stdout сохранён только в private lab `agua-reference/Food.java`.
getActualWeight805–810 использует getThirstChange, который отличается от raw
при cooked/burnt; этот напиток исходно не cookable. Для migration используется
unmodified thirst, чтобы искусственное cooked/burnt состояние не уменьшило
объём повторно. getItemsCanBeUse/checkItemCanBeUse и обычный UI не отсекают
Hunger0 ingredient. Добавлен безопасный отказ legacy evolved-пути до изменения
предметов: isValidStart/isValid/complete и прямой HCR addIngredient. Spice-флаг
не обходит защиту — native spice calculation тоже делит на нулевой hunger.
Poison-only и изменённый ненулевой hunger остаются отдельными допустимыми путями.

## Смеси и коктейли

Lemon/Lime Mixer: пустая бутылка +0,1 л сока → прежний полный Food.
Bloody Mary Mixer: то же +2 Salt/2 Pepper/2 Hot Sauce uses. Все Hunger20;
fixed calories 550/550/400. Два Food uses =1/10 полного запаса; Bloody5 =1/4.
Прежнее создание «полной литровой бутылки» из 0,1 л не сохраняет объём.
Новый фактический выход и старые готовые запасы должны учитываться отдельно.
Реализовано: новый выход0,1 л, питание и срок берутся из реального сока/специй,
а не из старого fixed-output прототипа. Это явное изменение новых партий:
лимонная смесь больше не создаёт550 ккал из малой порции сока. Старые Food
запасы сохраняют исходные550/400 ккал и свой фактический остаток. Новая пустая
бутылка принимается прежними Whiskey-empty маршрутами с проверкой IsEmpty.

Bitters/Vermouth/TripleSec — Drainable40 uses, не Food. При явном соответствии
литровой бутылке одна порция составляет 0,025 л; нельзя выдумывать отсутствующие
Food-питание/яд. Потребители: Martini/Manhattan по Bitters+Vermouth; остальные
TripleSec/Bitters согласно исходному рецепту.
Реализованы native migrations всех трёх Drainable и13 cocktail consumers:
0,025 л/use, сохраняемый донор. Два Food uses mixer =0,1 л; Bloody5 =0,25 л.
Готовые cocktail outputs пока Food — это отдельный следующий этап.

Нынешние Short/Tall/Cocktail spirits vessels вмещают 0,1 л. Сумма жидкостей
коктейля больше: Martini/Manhattan 0,15; Bloody Mary 0,35; Long Island 0,425;
Whiskey&Coke с native банкой 0,4. Нужны более вместительные serving vessels,
сохранение остатков и отсутствие лишней физической тары. 14 конечных cocktails
не имеют EvolvedRecipe или приготовления на плите. Старые готовые запасы
мигрируют со своими значениями, а не пересчитываются по новым ингредиентам.

Irish Coffee четыре recipes: 0,1 л Water +6 Coffee uses +0,1 л Whiskey,
пустая кружка →0,2 л. Original не требует нагрева. Food261 ккал,
fatigue−15/unhappy−15/stress−10; AlcoholPower0,5. Clay serving тоже0,2 л.

Eggnog Pot:0,1 л Milk +0,25 л Whiskey +whole Egg +Pot. Monkey Tail Pot:
0,1 л Milk +whole Agua +1 Sugar/1 Coffee +Pot. Оба не cookable, fresh8/rotten10.
Прежний розлив whole pot →4 mugs (0,8 л) или2 bottles (2 л) противоречит
входному объёму и native Pot1,5 л. Retained pot не должен дополнительно
возвращаться callback. Eggnog cups ещё добавляют Chocolate; его питание
нужно учитывать при новых партиях. Старые fixed Food выходы имели собственные
непропорциональные значения: они сохраняются при миграции старых запасов.

## Безалкогольные напитки

17 Food: Pop4/5/6, десять Soda, Energy1/2, Fitness, Applecider. Ни один не имеет
Alcoholic, EvolvedRecipe или OnEat; Root Beer и Applecider также безалкогольные.
Нейтральные маркеры и E.snapshot сохраняют исходные питание/стимуляцию,
включая Energy, Cola, Dr Pepper; native Cola не должна добавлять их второй раз.

Native Pop соответствует0,3 л, PopBottle2 л; Energy-банки также можно явно
сопоставить0,3 л. Fitness использует существующую HCCanteenFluid1,4 л.
У Applecider возврат HCGlassjug не объявлен в текущем моде, но есть в pinned917
Glassworking.txt: empty Normal0,3; full Drainable UseDelta0,07 с возвратом empty.
При принятом переводе14water uses×0,1 л это1,4 л, а не произвольные2 л.
Иконки empty/full сохранены. Нужен отдельный HCGlassjugFluid и явная ссылка
на это основание объёма. Applecider336 ккал, thirst−85, carbs35,4.

Единственные прямые consumers: HC6 pack/unpack; HCSodacola в Whiskey&Coke
(1/15 бутылки =2/15 л); Fitness Research +3 hard exercise (1/10 =0,14 л).
Pack обязан проверять полную исходную factory state по образцу Beer. Три
тренировки сейчас создают новую пустую флягу после каждой Food use — убрать
этот лишний выход при сохранении исходного сосуда. Рецепт тренировки не был
питьём: автоматически применять спортсмену яд или стимуляцию нельзя.

Mix Fitness Drink использует батарейный HCBlenderpowered как Drainable:
UseDelta0,125, восемь использований; затем ровно один HCBlenderdead.
Это сохранённая модель pinned917 Kitchen.txt, а сам рецепт впервые виден
в initial repo3defd36 (не приписывать его917). Не ставить mode:keep и не
добавлять callback возврата powered blender. Снятие батареи с dead blender
возвращает обычный инструмент и одну разряженную среднюю батарею.

Energy-trash остаётся в distributions/Junkyard, HC-банки не входят в нынешний
Recycle Aluminum Cans (только три Base.Pop*Empty). Обычные определения и
старые мусорные предметы не удалять при создании новых FluidContainer ID.

Реализовано в Soft Drinks срезе: все 17 families, HCGlassjugFluid 1,4 л,
factory pack/unpack Pop6, точные жидкие consumers, Fitness в сохранённой
фляге и восемь зарядов блендера. 22 empty-PopBottle маршрута принимают
десять новых Soda vessels; generic juice/DrinkProducts callbacks проверяют
alias, пустоту и вместимость. Native 155:soft PASS; подробные доказательства
и оставшиеся cold/MP проверки — в FLUIDS_1_6_STATUS.md.

## Дозированные лекарства и бытовые средства

Ginseng/Lemongrass Extract и Adrenalin сохраняют Food-класс и исходную
дозировку. Это намеренное исключение из переливаемых пищевых напитков:
литраж в исходнике отсутствует; positive hunger у extracts даёт 0 native
craft uses, но настоящие лечебные/стимулирующие эффекты при Eat. Adrenalin
имеет один hunger use, native частичный приём округляет его до целой дозы.
Не менять это выдуманными миллилитрами или свободно делимым FluidContainer.

Extracts впервые есть в initial repo3defd36, в pinned917 их нет. Ginseng:
endurance +0,15; Lemongrass intended ReduceFoodSickness=50. В B42 требуется
FoodSicknessChange=-50: native Eat уменьшает sickness и poison, соблюдая
effectiveEdibleBuffTimer. Исправление поля реализовано; старые сохранённые
Food имели 0, поскольку Food.load сбрасывает поле независимо от script default.
Узкий repair перед Eat восстанавливает только fresh, uncooked/unburnt нулевой
препарат с исходным baseHunger +0,001 и известным остатком. Питание, яд, имя,
favorite и объект не заменяются; однократная метка исключает восстановление
округлённого нулевого хвоста. Ненулевое лекарственное значение сохраняется.
После Eat server отправляет остаток и изменившиеся sickness/poison явно.

Pinned917 Medical подтверждает Adrenalin: endurance +0,10 и **stress +0,20**,
возврат HCEyedropperbottle; коробка даёт4. Отдельный HCAdrenalinbottle Drainable
имеет5 uses для наполнения5 HCSyringeadrenalin — не смешивать эти ID.
Старые syringe тоже Food, native injection-механика этим срезом не добавляется.

Mouthwash1/2 — бытовые токсичные средства, сохраняются в исходном Food-виде:
poison10/detection3, алкоголь, thirst−0,2; без medicinal effects, evolved,
craft chains, срока порчи и определённого литража. Loot и вред не удаляются.
Это не пищевой напиток; оснований выдумывать вместимость бутылки нет.

## Готовые коктейли и ирландский кофе

16 legacy Food остаются загрузочными классами; миграция сохраняет их
индивидуальные текущие свойства и долю. 14 ready cocktail vessels имеют
вместимость0,5 л и прежние иконки. Irish Coffee использует существующие Mugl
0,2 л / HCClaymugFluid1,4 л, заполненные0,2 л. Отдельный объём для clay
не придуман. Legacy Whiskey&Coke получает0,4 л: происхождение из двух
старых рецептов в Food не записано; текущие калории/доза не пересчитываются.

Новые партии получают фактическое питание жидкостей и потраченных твёрдых
ингредиентов вместо старого фиксированного cocktail Food. Это явное
отклонение ради единой системы смешивания. Вода, native Cola/ColaDiet и
Whiskey учитываются собственными native properties ровно один раз;
quality-only Whiskey batch остаётся отдельным нулевым объёмом. Худшая
свежесть и точные примеси переходят в результат.

| Рецепт | Жидкости, л | Твёрдые ингредиенты |
|---|---|---|
| Old Fashioned | Whisky0,1 + Bitters0,025 | 1use Sugar OR, целый Slicedorange |
| Martini | Gin0,1 + Bitters0,025 + Vermouth0,025 | — |
| Manhattan | Whisky0,1 + Bitters0,025 + Vermouth0,025 | — |
| Daquiri | Rum0,1 + LimeMixer0,1 | 1use Sugar OR, целый Slicedlime |
| Bloody Mary | Vodka0,1 + BloodyMaryMixer0,25 | — |
| Whiskey Sour | Whisky0,1 + LemonMixer0,1 | 1use Sugar OR |
| Mai Tai | Rum0,1 + LimeMixer0,1 + TripleSec0,025 | 1use Sugar OR |
| Cosmopolitan | Vodka0,1 + TripleSec0,025 + LimeMixer0,1 | целый Slicedlime |
| Tom Collins | Gin0,1 + LemonMixer0,1 | 1use Sugar OR |
| Long Island | Vodka0,1 + Rum0,1 + LemonMixer0,1 + LimeMixer0,1 + TripleSec0,025 | 1use Sugar OR |
| Gimlet | Gin0,1 + LimeMixer0,1 | 1use Sugar OR |
| Planter's Punch | Rum0,1 + Bitters0,025 + LemonMixer0,1 | 1use Sugar OR |
| Whiskey and Coke | Whisky0,1 + HCCola2/15 | — |
| Whiskey and Coke (Canned Cola) | Whisky0,1 + Cola/ColaDiet0,3 | — |
| Margarita | Tequila0,1 + TripleSec0,025 + LemonMixer0,1 | 1use Salt, целый Slicedlime |
| Irish Coffee (4 recipes) | Water0,1 + Whisky0,1 | 6uses Coffee2/HC large coffee |

Sugar OR = Base.Sugar/SugarBrown/SugarPacket/HCSugarcubes. Сохраняется
опубликованный текущий1use, а не pinned917 cubes2. Алкогольный бокал
переходит в ready cocktail как одна физическая тара; Margarita использует
один отдельный пустой бокал и сохраняет донор Tequila. Irish сохраняет
опустевший whisky glass и использует ровно одну пустую кружку.

16 empty routes:15 spirit pours и Margarita принимают соответствующие
ready glasses только с IsEmpty. Старые Normal empty тоже принимаются.
Recipe pour возвращает прежнее plain-spirit состояние с вместимостью0,1 л;
это явная смена состояния тары. Обычное native переливание сохраняет ID
и0,5 л ready vessel. Native выпивание тоже сохраняет его целиком.
Не возвращаются ошибочные legacy HCShortglassempty (не объявлен) и
cocktail glass из Margarita. Отсутствующие recycling recipes pinned917
не восстановлены попутно.

## Эггног и «Обезьяний хвост»

Группа содержит8 recipes и6 legacy Food. Перенесены6 native recipes;
два исходных milk Food OR producers пока ждут решения по Soy и не являются
готовыми release routes. Это явный незавершённый участок.

Carton producers: эггног0,35 л =0,1 л молока +0,25 л Whiskey +целое яйцо;
Monkey Tail1,1 л =0,1 л молока +1 л Agua +1use Sugar +1use Coffee2.
Твёрдые добавки не создают жидкость. Пустой Base.Pot1,5 л проверяется до
расхода; все отдельные доноры сохраняются. Eggnog исходно не cookable и
не имел raw-egg штрафа. Этот штраф явно не добавляется новым переносом
свойств: только dangerousUncooked яйца снимается, а его свежесть/яд/питание
сохраняются. Это не приготовление яйца и не очистка испорченного сырья.

Разлив4 кружек требует0,8 л;2 бутылок —2 л. Native действительно собирает
нужный объём из нескольких kept-сосудов, в том числе1,5+0,75 л из двух
кастрюль. Неиспользованные0,25 л остаются. Eggnog Cuppa дополнительно
расходует одну целую Chocolate (850 kcal/110 carbs/10 protein/66 fat),
равномерно распределяя её свойства на4 выхода. Legacy recipe_hcpot callback
удалён из этих4 routes: он создавал бы лишнюю пустую кастрюлю.

Legacy stock mapping: pot1,5 л, mug0,2 л, bottle1 л. Все шесть исходных
Food-классов сохранены; перенос использует текущие индивидуальные свойства,
а не новую рецептуру. Две новые bottle FC замыкаются в прежние Whiskey-empty
маршруты с IsEmpty. Предустановленные свойства новых партий не прибавляются
поверх фактических ингредиентов. После native milk ingress сохраняется
принятый срок молока4/7 дней; свежесть остальных партий остаётся собственной.

Общий Bar callback теперь делит физический объём и каждый Food budget на
число выходов. Preflight проверяет пустой прототип и вместимость каждой
порции. Native tags учитывают все подходящие яйца без перечисления видов
вручную и не захватывают постороннюю еду. Исторические milk-chain records
сохранены, но их генератор больше не переписывает два Carton producers.

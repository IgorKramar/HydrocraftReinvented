# Hydrocraft Reinvented 1.6.0 — Живая вода / The Fluids Update

## Русский

Вода, соки, молочные напитки и алкоголь теперь хранятся в настоящих
FluidContainer B42. Переливание переносит реальный объём, питание, свежесть,
дозу яда и загрязнение. При смешивании партии сохраняют собственные часы
брожения; старые запасы переносятся при загрузке мира.

- Водяная тара, дождь и очистка воды; частично израсходованные старые предметы
  сохраняют остаток. Вода с неизвестной чистотой становится неочищенной.
- Соки, кофе/какао, молоко и соевые напитки используют литры. Свежесть и яд
  переходят в готовку, молочные продукты, сиропы и консервы. Обычное и соевое
  молоко расходуются в одинаковом объёме, но остаются разным сырьём.
- Виноград → сок → сусло → вино/уксус, медовуха, саке и перегонная брага.
  Новая перегонная брага: 1,5 л основы + 18,5 л воды, выдержка 336 часов.
  Старые готовые бочки не требуют повторного ожидания.
- Пшеничное пиво: 30 пшеницы, 1 хмель и 1,5 л воды, Cooking 3. Сусло готовится
  60 игровых минут, сгорает после 120; затем одна порция дрожжей запускает
  168 часов брожения. Половина сусла даёт 0,75 л, остаток 1% — 0,015 л.
  Хмель доступен в собирательстве в августе–октябре с уровня 4.
- Домашнее пиво получает пищевой профиль native Beer и сроки 14/30 дней.
  Его нельзя упаковать в заводской брендовый шестипак.
- Метанол снова производится из 1 л допустимого готового спиртного. Остаток
  источника сохраняется; найденные готовые лимонные бочки также используются.
- Действующие настройки Sandbox, сохранение личных надписей на сосудах,
  серверный расчёт качества и исправленная загрузка атласа `hcBuilding2x`.
  Пять точных копий моделей игры заменены ссылками на установленную ваниль.

### Обновление

Поддерживаемая и проверенная версия игры — **Project Zomboid 42.21.0**.
Сделайте резервную копию мира до обновления, включая серверную конфигурацию
и список модов. Завершите игру и сервер, обновите все клиенты, затем загрузите
копию мира для проверки. Используйте только одну копию ID `HydrocraftReinvented`.

Локальная установка сохраняет обе папки `common` и `42` из архива. Для Steam
Workshop дождитесь обновления перед входом на сервер. Экипированная старая
тара в MP переносится после снятия с рук. Воду с неизвестной чистотой очистите
перед питьём. Для возврата на 1.5.12 восстановите резервную копию старого мира:
сохранение, уже записанное с новыми ID, не предназначено для отката мода.

### Проверки и границы

374 автоматические регрессионные проверки. Парсер: **5 384 предмета,
3 647 рецептов**, русские имена предметов и рецептов покрыты на 100%.
Подробная история предыдущих этапов — в [журнале 1.6](FLUIDS_1_6_STATUS.md).

На втором ПК проверены настоящее приготовление и подгорание сусла, 18
комбинаций остатка и свежести, native сбор хмеля, смешивание партий и запрет
брендовой упаковки. 22 образца прошли полный перезапуск одиночной игры.
Сервер и два настоящих клиента независимо прошли девять этапов пивоварения,
восемь этапов браги/метанола, выгрузку участка и полный перезапуск всех трёх
процессов. Проверяется фактически полученное состояние, включая ID и дозы.
Отдельное сохранение создано на 1.5.12: 377 видов запасов во вложенных сумках
в инвентаре и на земле перенесены в новую версию с проверкой реальных остатков;
повторный холодный запуск сохранил новые ID без повторной миграции. Общий MP
сценарий также прошёл 11 этапов передачи, еды, молочной упаковки и Sandbox.

Эти проверки не подтверждают все сочетания сторонних модов, сетевые потери
и задержки или полный состав ZZZ. Сохраняются [общие ограничения](../README.md#limits-ru).
Граф достижимости является статической диагностикой, а не доказательством
доступности каждого ингредиента в игре.

## English

Water, juices, dairy drinks and alcohol now use native B42 FluidContainers.
Pouring preserves measured volume, nutrition, freshness, exact poison dose and
contamination. Mixed batches retain independent fermentation clocks; existing
stock is migrated when the world loads.

- Native water vessels, rain collection and purification; partial legacy stock
  keeps its real remainder. Water of unknown purity becomes tainted water.
- Juices, coffee/cocoa, dairy and soy drinks use measured litres. Quality follows
  ingredients through cooking, dairy processing, syrups and preserves. Cow and
  soy milk use equal volumes while remaining different ingredients.
- Grape juice → must → wine/vinegar, mead, sake and distilling mash. New mash uses
  1.5 L base plus 18.5 L water and matures for 336 hours; ready legacy casks stay ready.
- Wheat beer uses 30 wheat, one hops and 1.5 L water at Cooking 3. Cook for 60 game
  minutes (burns after 120), then add one yeast use and ferment for 168 hours.
  Half the wort yields 0.75 L; a 1% remainder yields 0.015 L. Hops are forageable
  during August–October at skill level 4. Beer uses native nutrition and a 14/30-day
  shelf life; homebrew cannot become a branded retail six-pack.
- Restored methanol production consumes one litre of supported finished spirits
  and preserves the remainder. Found ready lemon casks remain usable.
- Active Sandbox settings, preserved personal vessel labels, authoritative server
  quality updates, and corrected loading of the existing `hcBuilding2x` atlas.
  Five byte-identical game meshes now reference the installed vanilla resources.

### Updating

Supported and tested game version: **Project Zomboid 42.21.0**. Back up your world,
server configuration and mod list first. Stop the game/server, update all clients,
and test a copy of the world. Enable only one copy of `HydrocraftReinvented`.
Local installations must retain both `common` and `42`. Equipped legacy vessels
in multiplayer migrate after being unequipped. Purify legacy water of unknown
purity before drinking. To downgrade, restore the old world backup; saves written
with new item IDs are not designed for loading with 1.5.12.

### Verification

374 automated checks; 5,384 items, 3,647 recipes and complete Russian item/recipe
coverage. New native checks include cooking/burning, 18 portion/freshness cases,
foraging, mixing and retail-pack rejection; 22 SP samples survive a cold restart.
A real server and two clients independently pass nine brewing phases, eight
mash/methanol phases, chunk unload/reload and full three-process cold restart.
A world created on actual 1.5.12 supplies 377 legacy stock types in nested held
and ground bags for upgrade verification; a second cold load retains the new IDs
without repeating migration. The general MP integration scenario also passes
11 phases covering transfers, food, milk cartons and Sandbox settings.
See the [verification journal](FLUIDS_1_6_STATUS.md).

Other mod combinations, full ZZZ integration and simulated network loss/latency
remain outside these tests. Static reachability reports are diagnostic estimates.

Original Hydrocraft: Hydromancerx. B41 maintenance: Hydrocraft Continued team.
B42 port: hombrehumor. AI-assisted development and verification: OpenAI Codex
(GPT-6), using Universal Modder. This release adds no generated artwork or audio;
existing asset credits remain in [asset provenance](ASSET_PROVENANCE.json).

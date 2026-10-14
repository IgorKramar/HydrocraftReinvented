# Журнал доводки Hydrocraft Reinvented

## 2026-10-14 — исходное состояние

- Ветка: `codex/playability-polish`, исходный коммит `8200867`, мод 1.5.11.
- Цель пользователя: сначала полностью играбельный существующий контент, затем новые механики.
- Источники: 19 сообщений багрепортов, 5 предложений, 9 сообщений roadmap, 95 комментариев Workshop (прочитаны 2026-10-14).
- Базовый аудит: 5196 предметов / 5204 определения, 3591 рецепт, RU 100%, 0 необучаемых рецептов; variant B: 115 недостижимых предметов, 77 заблокированных рецептов. Variant B считает растения доступными и не доказывает работу таймеров.
- Установка игры: `C:/Program Files (x86)/Steam/steamapps/common/ProjectZomboid`; пользовательский version.txt отражает старый запуск 42.19.1, версию установленного движка нужно проверить отдельно.
- Лаборатория вне репозитория: `C:/Users/Igor/.codex/modding-lab`; приватный Java-референс хранится там. Ключ fal берётся только из среды, в файлы не записывается.
- Используются навыки Universal Modder: recon, research, port, reverse engineering, assets, pipeline, automation, showcase, publish, field notes. Cross-game mashup не является требованием мода.
- `um scan` падает при проверке нераспознаваемого D:/XboxGames; не менять диск, использовать Steam-манифест и обход сканера в памяти.
- Подтверждено: HCMREbox не имеет ItemType; свежие стеки FloraHCExtra:19 и JunkyardExtra:37/412 совпадают с getTraits():contains('Lucky'); рецепт душа ссылается на BucketEmpty; пищевые входы не имеют ItemCount.

## Критерий готовности

Статические проверки, Lua-регрессии, создание предметов и выполнение контрольных рецептов в изолированной игре; визуальный просмотр ассетов. Нулевой статический отчёт не заменяет игру. Существующие сейвы не использовать для испытаний. Публикация и внешние PR требуют отдельного разрешения.

## Проверено и изменено на 42.21.0

- Пользователь обновил игру. Версия подтверждена Core из установленного JAR и экраном игры. Лаборатория: `C:/Users/Igor/.codex/modding-lab/pz-profile`, отдельный cachedir, `-debug -nosteam -nosound`, окно 1280×720. Пользовательские миры не используются. Backup лаборатории: `hcr-pristine-lab/20261014-181352.zip`.
- 5196 уникальных предметов создаются в реальном движке без ошибок (удалены 8 дублирующих определений, исправлены ItemType и разделители). 12 Lua/рецептурных регрессий проходят.
- Исправлены nil trait API, BucketEmpty, расход целой еды/банок, 20 семян из одного початка вместо 120, возврат одной верёвки, работа упаковки без поверхности, namespace книг и старые vanilla IDs. CharacterStat boredom/unhappiness/panic использует 0..100, stress 0..1.
- Сохранены реальные модели 14 видов оружия; исправлены 52/54 WeaponSprite mappings и namespace 256 WorldStaticModel ссылок. Некоторым клинкам пока назначены временные vanilla модели; Chainsaw и Spiketrapclosed ещё требуют решения.
- Добавлены 265 переходов таймеров растений, сыра, ульев с catch-up после отсутствия. Источник legacy: brosseaualex/Hydrocraft, commit 917d37d4ed526f429e1525316c9fab487bbf7257. В игре подтверждены томат→урожай, сыр→выдержанный, закреплённый улей→полный. Последующие исправления world swap и MP контейнеров требуют повторной проверки.
- Добавлены путь получения стальной балки, редкий loot садовых ножниц/коробки булавок, vanilla apron для садового стола, кормление и сбор переносного улья.
- fal nano-banana-2/edit создал 8 отсутствовавших иконок растений; просмотрены вместе, импортированы с сохранением горшков. Оценка стоимости 8×$0.08=$0.64, не фактическая выписка. Raw outputs и manifest вне repo в modding-lab/hcr-assets. Первый request 01a13a52-8346-7723-9f3c-0a7a32c95246 восстановлен после TLS download failure без повторной генерации; его provenance нужно добавить в manifest.
- Найден важный дефект bridge: getAllConsumedItems не передаёт kept weapon. Используется getAllInputItems в native recipe order, GenericFood пока consumed-only. Исправлен SpearCrafted baseline охоты и удалены выдачи отсутствующих legacy livestock IDs. Найдены food mode:keep exploits, исправлены Hashbrowns/Bake Potato/Paper Bag.
- Найдена причина legguard tooltip NPE: отсутствует media/fileGuidTable.xml, поэтому clothing XML не привязан к script item. Следующий шаг — добавить GUID table, проверить getVisual и экипировку в игре. Аудит питания multioutputs и legacy getAllRecipes продолжается.
- Остаётся: полноценная chainmail, реальные визуальные проверки/крафт, полный callback/ID audit, MP, сохранение/загрузка и таймеры предметов в мире, provenance/документация/упаковка/видео. Пока не готово к публикации.

## Повторная проверка и защита сейвов

- Реальный локальный MP сервер 42.21.0 привязан только к 127.0.0.1, UPnP отключён. Клиент подтвердил замену вложенных растений/сыра и отдельного горшка без старых IDs/дубликатов, с сохранением позиции.
- Обнаружен риск смены Java-класса старого HCArmorchainmail: старый ID оставлен normal, новый wearable получает отдельный ID. Добавлена миграция состояния после загрузки; 8 регрессий проходят. Native save/reload ещё проверяется.
- Food bridge использует native consumed amounts, копирует свежесть/яд, делит питание между результатами; 633 source-backed whole-food entries и 178 physical fluid-container inputs исправлены. Возврат Food посуды производится вручную: native crafting подавляет ReplaceOnUse.
- 133 source-backed keep Tongs строки исправлены; расходуемые детали оборудования и 114 fire-charge inputs сохранены. Native smithing harness добавлен и ждёт повторного запуска.
- Полный текущий Python/Lua suite: 47 тестов PASS. Реальные crafting сценарии ранее 8/8; книги изучают 19 рецептов.
- Fal Trellis2 создал SpikeTrap GLB; импорт/визуальная проверка ещё выполняются. 9 raster assets имеют portable provenance.

## Расширение проверки после первых игровых прогонов

- Native save/reload контрольного normal экземпляра кольчуги PASS; выбран подготовленный персонаж, native BLOB не менялся. Старые экспериментальные Clothing-записи лаборатории были несовместимы и не использовались как reference пользовательских сейвов.
- Реальный MP: ground+carried nested bags, standalone pot и legacy chainmail migration PASS на клиенте, независимо подтверждено сервером. Женская модель кольчуги загружена и просмотрена.
- 9 reachable callback materials восстановлены (5 trace manure, scrap rubber/plastic, shell, silicon powder); inventory animals не восстановлены. Два inferred материала имеют честно описанное происхождение и отсутствие downstream consumers.
- Source-backed whole physical inputs теперь232; liquor/medical/cleaning51 миграция+27variants; milk13 миграций; petrol64charges+22emptycontainers. Latest full suite72 PASS до текущих boxing/tag/package additions.
- Native measured whiskey/disinfectant/eggnog consumption PASS. Native progression прошёл smelter, anchoring, copper sheet/pipe, lever; старый staged recycle recipe ещё не потребил PopEmpty, повтор нужен после свежего staging.
- Native mashed-potato scenario выявил настоящий tag issue: Base.Potato не имеет Potato tag. Более глубокий аудит обнаружил legacy unknown tags alias через null; namespaced registries + reviewed generic boxing сейчас реализуются. Ранний native boxing PASS не доказывал корректную whitelist eligibility.
- GLB loader умеет формат, но ModelScript.checkMesh его не признаёт. Попытка legacy TXT устранила mesh-warning, однако дала ModelLoader.applyToMesh skinningData NPE. Asset pipeline проходит повторный native repair; пока не считать модель завершённой. Demo с ранней геометрией будет переснят после проверки.
- Текущая цель следующего прогона: core10, progression chain, milk4, measured liquids, petrol pooled/partial, registry positive/negative groups, TXT model actual load/render. Packaging partial-fluid cycle также проверяется отдельно.
- UM publish --game нашёл один byte-identical vanilla файл: HCWardog.png == Drumstick.png. Копия удалена, model texture теперь ссылается на установленный vanilla texture, внешний вид сохраняется; повторный lint нужен на готовом package.

### Native recipe final pass
Fresh 42.21 process: core 10/10, milk 4/4, drink packaging 2/2, input selectors 14/14, boxing 12/12, fuel 3/3, linked progression 9 crafts PASS. Boxing predicate corrected against native category Item (script type Normal), and pairs replaces unavailable global next. Petrol harness corrected to real Fluid.Petrol/adjustAmount and treats native rejection as a negative result; production fuel values passed actual conservation checks. Proof: external sp-final-recipes-pass.log plus subsequent console log (will archive after cold mesh run).

### Final native availability and trap checks
88 regression tests PASS. Fresh client: 23 registered/placed rare loot seeds with exact singleton weights PASS; Trip Hammer native BenchAnvil consumption, kept tools and one result PASS. Native ISPlaceTrap.complete consumed spanishRider; sensor emitted OnThrowableExplode once and removed device. Isolated offline god mode restored after the fixture. New .x ground model verified; armed object retains native PlacedSprite, zombie damage and MP trap activation not measured. Proof external availability-proof.png and sp-final-availability-trap-pass.log. Final chainsaw cold display verified red housing and grey blade (uv-saw-clear.png); showcase rebuilt20.8s from current actual native captures.

### Planter geometry correction, preview.2
User identified squat boxes against original hcBuilding2x. Global warm-colour alignment included stems/fruit and resized the complete sprite; it did not actually preserve original box pixels. Eight icons now reuse exact owned atlas planter110x123 at(45,194), transparent200x424 canvas, ground317. Existing foliage RGB remains1:1 with reviewed layer masks/translation. Two exploratory fal edits changed foliage shape and four SAM calls did not provide useful separation; those outputs were rejected and remain private, no experimental art shipped. Read-only geometry checks8/8PASS. Native dropped-item renderer anchors at3/4 of texture height: initial320 canvas clipped the box below ground, corrected424 adds transparent padding only. Original-icons backup external planter-scale/before.

Fresh42.21 client loaded padded textures. Potato and red cabbage at native world z-offset0 render complete front walls (private planter-scale/native-final.png). Idempotence8/8PASS. Catalogue refreshed6002 records including8 superseded icons in history. Preview.2 package lint6343 files,0FAIL/0WARN. No publication.

### Tomato white fringe, preview.3
Removed415 neutral white matte pixels from isolated tomato foliage before compositing onto original atlas box. All changed source pixels meet the reviewed neutral matte threshold; coloured pixels and front walls unchanged. Private before/after tomato-dehalo-comparison.png. Processing is deterministic, no new fal generation or charge.
Cold42.21 client displayed cleaned tomato texture: planter-scale/tomato-native.png. Pixel audit415 matte pixels only; eight planter geometry checks and repeated processing PASS. Catalogue6003 records updated, intermediate halo version retained in history.

### Native-alpha foliage regeneration, preview.4
User still saw matte fringe in tomato and both cabbages. Three canopies fully regenerated using fal-ai/gpt-image-1.5/edit, background=transparent, medium quality. gpt-image-2/edit rejected transparent input with422 despite schema advertising it; failed requests were not accepted as assets. Original atlas planters retained exactly. Native RGBA outputs trimmed and fitted once with nearest-neighbour, placed behind original front walls. Three light/dark/grey background reviews and white-edge diagnostic0/0/0 passed. Source/requests documented in PLANT_REGENERATION.json; superseded versions retained privately and in catalogue history.
Fresh native42.21 client: all three regenerated plants displayed together at world z-offset0 with full original planters and no white matte fringe; proof private fal-clean-plants-v2/native-final.png. Geometry8/8PASS; catalogue6006 records with old three variants in history. No publication.

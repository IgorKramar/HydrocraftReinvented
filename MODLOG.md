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

### 1.6.0 development, 2026-10-15
Branch codex/fluids-1.6.0 from published485e704. Parallel read-only water/native/brewing audits found120 legacy water-marked IDs and285 directly linked recipes, not~1000 fluids. First closed unit: HCWaterflaskFluid Normal/FC1.4L; oldNormal/Drainable IDs retained; currentUses*.1L migration. User explicitly selected unknown legacy purity->TaintedWater. Empty/native quantities and actual existingFC mixtures preserved, unsupported contents keep old item. Private lab backup: C:/Users/Igor/.universal-modder/backups/hcr-before-fluids-160/20261015-183055.zip (13017 files188.6MB). No1.6 publication authorised by this development request.

Native42.21 registered5207items/failed0. A real1.5.12 saved Drainable fixture with7uses loaded as exactly one new1.4L flask containing.7L TaintedWater. SP held replacement, favourite/custom flag/modData, native bidirectional fluid transfer conservation, petrol rejection, empty retention, Make Waterflask and Brush Teeth(.1L) PASS. Native scripts silently omit item declarations after unsupported // comments: use block comments. Native FluidContainer labels use Translate/*/Fluids.json. Full native transfer refuses overfull inventories; lab harness clears only disposable unequipped test stock before measuring. Initial harness errors were corrected; logs preserve both failed setup and subsequent PASS, not a claim of a warning-free game.

Read-only review reproduced existing-empty-FC + stale7uses -> free.7L; fixed by treating any existing FC, including0L, as authoritative. Native FC UI ignores custom InventoryItem names: keep underlying name/flag and explicitly archive text in HCRLegacyCustomName, document visible-name limitation. MP review found world SWAP_ITEM omits transferred world-owned FC, and Equip/replacement cross-channel ordering can clear hands. Auto flask migration now explicitly deferred on servers; SP mocks do not claim MP validation. Old chainmail migration remains independent.100 regressions PASS with12 fluid cases; first test invocation lacked external PYTHONPATH and was rerun with the existing lab dependency environment.

Second cold1.6 load PASS: exactly one native flask retains.7L TaintedWater, favourite/custom flag and modData after save/restart. Updated native custom-name archive assertion PASS on a fresh held legacy fixture. Evidence outside repo: fluids160-sp-verified-before-reload.log, fluids160-second-reload.log and fluids160-regressions.log. Final review confirms empty-FC fix and server gate; server hand-setter branch also excluded so this SP addition does not alter chainmail MP packet ordering. Remaining milestones and explicit limits are in docs/FLUIDS_1_6_STATUS.md.

### 1.6.0 native rain and MP synchronisation follow-up
Session baseline100 tests PASS. Backed up private MP server/client before staging: C:/Users/Igor/.universal-modder/backups/hcr-fluids160-mp-server/20261015-190521.zip and hcr-fluids160-mp-client/20261015-190529.zip. Full current common/42 staged additively into isolated profiles; no user saves/game files changed. Server binds127.0.0.1, Open=false/Public=false/UPnP=false; existing HCRLabAdmin account reused. Native server launch needs -adminusername HCRLabAdmin; omitting it prompted for a nonexistent default admin, so that initial launch exited without starting a world.

Native SP rain PASS: real FluidContainerUpdateSystem filled outdoor flask to1.4L TaintedWater, RainFactor0 and indoor controls stayed0; original climate admin flags/values/final values restored and three test objects removed. Input was only climate precipitation/snow settings, never addFluid. Hot-reloading a new Lua filename cannot resolve the mod file and new event callbacks are not installed during reload; used a known loaded lab file plus explicit observer after actual native ticks. Raw proof fluids160-rain-pass.log retains the initial harness-loading failure and later PASS. Production rain code needed no change.

Native network review: object:sync is unordered channel3, so cannot safely follow SWAP_ITEM channel0. GameEntityNetwork has correct ordered channel0 but requires a registered entity absent after first legacy conversion. Ground migration now sends a second full SWAP_ITEM with FC temporarily on item during synchronous serialization, then restores FC to world in the exception path as well. Factory, enums and methods are explicitly Lua-exposed (bytecode checked). Held MP old flask is deferred until unequip; server hand-setter addition remains SP-only.14 fluid tests/102 total PASS, including snapshot contents and send-failure restoration; independent read-only review found no new P1/P2. Real client test is still being completed.

Private MP harness setup correction: global sendEquip(player) is server-only, so a client setter plus sendEquip does not publish hands. Replaced it with native player:updateHandEquips(), which sends the real C-to-S Equip packet. Initial setup failed before production migration; not counted as a migration result. Harness is confined to tools/ and the localhost test mods.

Real MP42.21 PASS: client nested bag.7L, ground.3L with same ID/xy and exactly one instance, legacy flask remained held with7uses, then unequipped migrated to one.7L native flask. Server independently verified final values and client acknowledgement; client kept observing120frames. Proof: external fluids160-mp-client-pass.log and fluids160-mp-server-pass.log. F8 opens native map editor, so removed the unused experimental lab shortcut; start via HCRLabFluidMP.begin(getPlayer()) in native Lua console. Console input at1280x720/DPI175% is logical110,389 (395 hits the bottom border); character/chat UI can overlap console title. No fake C-to-S hands or fake client fluid observations were used. Two-client/latency stress and MP-server cold reload still pending; SP cold reload was already verified in the preceding step.

MP cold-save fixture initially differed from.3L because its square was outdoors and native rain had legitimately raised it to.30719032883644104L. For deterministic persistence verification only that lab FC's RainCatcher was set0; the then-current server amount.39723849296569824L was recorded independently in item modData.HCRFluidSavedExpected and published via the production full snapshot. No water was added/removed. This preparation used native server `reloadlua zz_install.lua`; the temporary startup code was restored immediately. Then both processes exited normally and restarted with current helper/dev.2 metadata. CLIENT and SERVER independently PASS exact saved ground baseline, nested.7L, formerly held.7L, unique tags/IDs and original ground offset. Evidence: fluids160-mp-frozen-baseline.log, fluids160-mp-cold-client-pass.log, fluids160-mp-cold-server-pass.log. Full suite102 PASS; no repeat of unchanged production tests after documentation-only edits. Remaining: two-client/latency stress and the other fluid families; no1.6 publication performed.

### Основа качества жидкостей и все водяные семейства, 31 октября 2026

Решение пользователя: собственные партии со свежестью, индивидуальным ядом и пищевой ценностью, включая переливание и смешивание. Реализованы ledger, нейтральные fluid identities, применение Food-эффектов, progressive actions, наблюдение хранения и защита неподдерживаемых хозяйственных действий. Новые напитки пока не мигрируются автоматически: их рецептурная интеграция следующая.

122 старых ID воды →82 native сосуда;284 рецепта перепривязаны с guards. Старые Java-классы не менялись. Native42.21:5289 items/0 failed;488 миграций, очистка .37L в той же бутылке, пипетка .1L без дублирования PASS. У UseDelta=.08 native Math.round даёт13uses, поэтому Tupperware вмещает1.3L. Неизвестная чистота старой воды переносится как TaintedWater по решению пользователя.

Native SP: small sip50cal/1poison, rotten modifiers,64L→.1L, progressive transfer/stop/drink/empty PASS. FC.getAmount округляет near-full до capacity, а removeFluid удаляет traces<.0001L. Ledger хранит dose units отдельно от marker литров, учитывает фактическое исчезновение каждого компонента. Native raw volume доступен через FluidSample:getAmount/release, но FluidInstance НЕ exposed Lua. Clipped marker в воде сохраняет дозу при питье, следующем переливании и сбросе пустой тары. Proof: private quality160-native-precision-pass.log.

18 native boundary entry points отказали до расхода; ожидаемые assert-отказы вызывали debugger/log spam, поэтому последняя редакция возвращает boolean. Добавлены проверки soaps и тушения огня; последней редакции ещё нужен cold run. У HCR Beverage запрещён прямой blend с Petrol/CleaningLiquid, но zero-marker Water разрешает CleaningLiquid/Bleach, поэтому эти sinks действительно нужны. Pure regressions: invisible aggregate delta, invalid storage, client/server guards. Полный suite127; parse_hcr/variant_b/analyze_gaps выполнены, LuaLS не найден. Ночной автоматический повтор Purify Water отказал по native dark=true: это условие стенда, не потеря жидкости. Старый дневной proof остаётся действительным.

Следующее: capture до ISHandcraftAction.performRecipe (OnStart уже после native fluid consumption), точные applied slots в OnCreate, Food/drink recipes, холодильник и MP качества, Sandbox, итоговая упаковка. Полная1.6.0 не готова.

### Соковый блок 1.6.0-dev.3, 31 октября 2026

66legacyFood→native,102recipes сохранили тару и фактическое питание/яд/возраст фруктов. Пользователь 31 октября подтвердил одинаковый выход из одинакового сырья: 1L бутылочная партия, .5L кружечная; небольшая тара требует несколько сосудов, последний может быть неполным. Миграция старых Food не угадывает исторические литры: nativecapacity×remaining, точное прежнее питание/яд без масштабирования дважды. Lemon/Lime/Tomato18ID покаотложеныдоdownstream.

Native198миграций, unloadedage,apple1L110cal3poison,samevessel, pineapple1L5mugs(.6poison/22.2cal each),apple.5L→.2/.2/.1,autocraftcleanwater/retainedpoisontrace,trackedkeep-pot+plainwater→egg PASS. В процессе найден и исправлен реальный native bypass: updateFloorContainer перезаписывает allItems послеfilter. Второй testOnly-обход через queued reservations устранён отдельными inputItems списками для каждого слота и scopedlogicfacade,использующимdata.perform(...nil...). Native original OnCreate/processUsed остаются без переписывания. Safe keep допускается, Unseal/InheritUsesAndEmpty исключаются. Первый auto fixture также требовал отдельной реальной сумки: rootinventory содержал чистую воду старых стендов, которую native законно выбирал вместо тестовой.

20nativeboundaryentrypointsboolean/fire PASS. Storage watcher keyedbyobject исправляет repeatedworldsync послеfactoryIDchange. В tooltip виден worstfreshness,приrender прежнее поле предмета восстанавливается. Screenshot juice160-quality-tooltip.png просмотрен. Proof juice160-native-batch-pass.log и juice160-native-boundaries20.log внеrepo. 141testsPASS,required3staticchecksPASS/diagnostic;LuaLS unavailable. Никакой публикации1.6.0небыло. Продолжитьобщийqualitycrafting/остальныенапитки, Sandbox, coldstorage+MP2clients иreleaseQA.

### Sandbox 1.6.0, 31 октября 2026

10 native options, 29 gated production recipes, 46 gated loot IDs, 16 extraction
recipes. Loot provenance retains baseline/order and changes only authored pairs.
Native ItemPicker adds zombieDensity even to weight=0: disabled pairs must be
removed, with retained insertion positions for re-enable. OnInitGlobalModData
occurs after saved settings and initial Java Parse, so call public static
IsoWorld.parseDistributions() after applying authored weights. SP admin set()
does not toLua; consumers read native options, server/SP polling catches six
loot settings even while paused. Other three legacy consumers also use the
native-backed accessors. Mining callbacks use passed player instead of getPlayer.

152 pure tests PASS. Required three audits run: 5289 items/3636 recipes, 100% RU.
Read-only review additionally exercised 7200 randomized loot operations with no
ordering/weight discrepancy. Native SP options, actual authored pools x2/repeat/
zero/restore, four craft gates, mining duration PASS (sandbox160-native-pass.log).
Native Russian panel inspected (sandbox160-options.png). A second cold boot
confirmed native admin set() without toLua: polling applied x2 then restored x1
(sandbox160-native-live-pass.log). Next: Food quality bridge, remaining drinks,
cold-storage/two-client MP, packaging. No 1.6.0 release has been published.

### Точная доза Food и переходы при готовке, 31 октября 2026

HCR_FoodQuality хранит дробную дозу в condition:HCRFoodPoison160. Native signed
byte poisonPower — только ceil marker<=127; дозировка применяется отдельно
нейтральным Food через native JustAteFood(dose/127), с сохранением traits/pain
и без изменения nutrition/healthFromFoodTimer. Большие значения не вызывают
цикла subtract127. Ledger ограничивает суммарные ceil(units)<=4096 и проверяет
результат mix до native transfer; иначе валидные два входа могли дать зависание
при расходе огромного количества reference portions.

Scoped Food.OnEat получает фактическую native fraction после BaseHunger/last-bite
rebasing, вызывает прежний callback один раз, сохраняет остаток до UseAndSync.
condition:* переживает native cooked/rotten replacement, не попадает в пустую
посуду при полном расходе. Marker/detection восстанавливаются перед tooltip.
Native split копировал весь poison в каждую часть; теперь сумма сохраняется.

HCR_FoodTransfers переносит дозу через обычный handcraft (включая отсутствие
OnCreate) и evolved addItem, сохраняя нативное питание/кулинарные бонусы. В evolved
доля берётся из фактического расхода nutrition, fallback raw hunger с cooked1.3;
удалённый последний ингредиент отдаёт остаток целиком. Poison-only путь отдаёт
всю дозу без расхода питания, как native. Metadata временно убирается до native
UseAndSync, чтобы не заражать пустую посуду. Handcraft проверяет общий budget
ПОСЛЕ floor refresh, но ДО data.perform: проверка лишь в OnCreate давала бы
бесплатные outputs при исключении. Detection переносится отдельно.

171 автономный тест PASS; required parse_hcr/variant_b/analyze_gaps выполнены,
5289items/3636recipes/100%RU. LuaLS отсутствует. Native первый прогон PASS:
eating partial/full/cancelled, native cooking/rotting, empty bowl, cheese8/mashed2,
Grate Cheese without callback, evolved replacement/partial/final fragment,
dose254 с native cap100 и pain. Proof foodtransfers160-native-first-pass.log.
Два сбоя fixture исправлены: getOriginalname не является script ID Sandwich;
factory lastCookMinute=0 требует ненулевую минуту при ручном Food.update.
Последняя редакция preflight/detection после cold boot PASS: manual/auto
сумма1200000 отклонена до output/water/Food mutation. Proof
foodtransfers160-native-final-pass.log. Добавлен client inventory refresh/
double-click reconcile marker: native список использует isKnownPoison раньше
tooltip. Его визуальная проверка остаётся в следующем cold run.

Следующий блок: общий fluid→Food craft, затем оставшиеся напитки, cold-storage,
два клиента MP и упаковка. 1.6.0 ещё не релизная.

### В работе: fluid→Food и худшая свежесть

Пользователь явно выбрал перенос худшей свежести, включая сиропы/консервы.
FoodQuality теперь также хранит condition:HCRFoodFreshness160 (stale/rotten
floor). Native age/expiry производные восстанавливаются перед едой, snapshot,
inventory/tooltip и server storage scan. Непортящиеся rotten outputs получают
offAge0/offAgeMax1/age1.001, а не миллиард лет: иначе DaysForRottenFoodRemoval
сразу удалял бы результат. Stale output без stale interval получает offAge0.
Overrides в metadata переживают сохранение и native condition-copy replacement.
Пустая посуда очищается перед UseAndSync; handcraft/evolved передают worst state.

tools/convert_juice_consumers.py +juice_consumers.json перевели21 consumer на
0.1L native -fluid mode:primary в kept vessel. Это новая единая мера рецептуры,
не попытка восстановить несогласованные oldFood uses разных сосудов. Nutrition
у20Foodoutputs остаётся авторским fixed-output; ничего поверх не прибавляется.
Disinfectant Drainable удаляет устаревший callback, безусловно создававший Bowl.
Новые native producers/migrations для18Lemon/Lime/Tomato и4citrusaliases ещё
НЕ включены; текущие незакоммиченные consumers пока не замкнуты на производство.

HCR_FluidRecipeQuality captures до native perform, reconciles каждый реально
израсходованный компонент после него (даже при native exception). C допускает
tracked fluids только в явно перечисленных consume slots; source ledger
передаётся в T.finishCreate для дозы/худшей свежести. Native -fluid defaultExact
не принимает смеси; mode:primary допускает primary и расходует всю смесь
пропорционально. Public getFirstInputFluidWithFlag возвращает borrowed sample,
но не наш ledger, поэтому выбран capture/delta. Агент chains_audit проверил
native source, кода не менял.

179 автономных тестов PASS. Новый cold boot запущен с командой33:fluidrecipe
(pure/mixed ×fresh/stale/rotten→HCLemonmixer). Native результата ещё нет.
Текущий working tree не коммитить как готовый: закончить native мост,
производителей/миграции citrus, ещё QA свежести/coldsave, остальные напитки.

### Fluid→Food: native и замкнутые цитрусовые, 31 октября

Coldboot34:fluidrecipe PASS: pure/mixed ×fresh/stale/rotten, manual/auto,
точный расход/доза в Food/остатке, неизменная посуда. Review выявил два края:
native скрывает Stale у непортящихся продуктов — добавлена EN/RU tooltipстрока;
rotten replacement в непортящийся melted Food получал миллиардолетний age —
reconcile теперь адаптирует шкалу получателя. Native HCIcecreamsoft→melted PASS,
возраст1.001 и доза.625 сохраняются. Proof fluidrecipe160-native-final-pass.log.

88 drinkIDs включены:84series+2citrusbowls+2Drainableconcentrates. 122fruits→juice
recipes наполняют ту же посуду; четыре лимона/лайма дают1L в4bowls .3/.3/.3/.1.
Два старых Drainable имели4uses, не хранили Foodполя: политика .1L/use, target
Base.WaterBottle с.4L при полном остатке, питание/яд не выдумываются. Лут старых
ID проходит ту же миграцию. Native35:juices PASS:258Foodмиграций,10Drainable
остатков, яблоки/ананас/multi-mugs/lemonbowls иregressionавтоводы/keep-pot.
Proof juice160-citrus-native-pass.log. 180puretestsPASS, required3audits выполнены:
5289items/3636recipes/100%RU; diagnosticreach4885/3570. LuaLS отсутствует.

Ошибка lab orchestration: старый PID3172 остался в меню после выхода из мира,
поэтому был запущен второй PID26168 в том же private cachedir. Второй процесс
не входил в мир; остановлен точнымPID, старый закрыт штатно с подтверждением.
Последующие launches проверяют отсутствие PZпроцесса. Повторный coldboot прошёл.
Реальные пользовательские сейвы не затронуты.

Следующее:36:freshseed→normal save/exit→37:freshverify для cold persistence/tooltip,
затем retail/drink/milk/wine/distillation, cold-storage/дваMPклиента, releaseQA.

37:freshverify после normal save/полного restart PASS: nativefreshness, корректная
шкала и точнаядоза.875 у stale/rotten HCLemonmixer. Русскийtooltip просмотрен.
Proof fluidrecipe160-native-coldsave-pass.log +freshness-cold-tooltip.png.
Дополнительныйкрай evolved poison-only: отдача всей дозы без расхода Food теперь
сохраняет freshnessfloor остатка; pure regression проходит. 180tests PASS.

### Магазинные соки и состав ингредиента

Добавлены 8 retail Food миграций (HCOJ, cranberry, 6 juiceboxes) и 6 empty cartons.
Полный литраж по native возвращаемой таре: бутылки 2 L, пакетики .2 L. Current Food
nutrition/age/expiry/exact poison сохраняются; срок 3/7 магазинным не приписывается.
Три новых Normal+FC ID сохраняют старые иконки cherry/lemonade/pinklemonade;
прочие используют vanilla JuiceBox IDs. Добавлены нейтральные жидкости Cranberry,
Lemonade/PinkLemonade (всего 41). Native 40:retail PASS: 24 Food остатка + 6 пустых
сосудов, metadata/favorite/idempotence. Proof retail160-native-pass.log.
Native 39 выявил ошибку генератора: // перед первым item не воспринимается
script parser как комментарий и теряет первый item; исправлено на /* */.

Read-only аудит обнаружил потерю native alcohol при juice→Food для primary смеси
Brandy. Принято ограничение рецептуры: указанные в рецепте соки + чистая Water;
прочие смеси отклонять ДО расхода. Проверяются native компоненты и zero-marker
ledger lots. Это ограничение крафта; native переливание/питьё смесей работает.
Причина: fixed-output Food не имеет эквивалента всех эффектов добавленных жидкостей.
Native 42.21 PoisonInfo.getPoisonEffect возвращает maxEffect, но DrinkFluid
использует другое float poison поле; из enum нельзя придумывать дозу. Рецепт
не очищает эти смеси. Tooltip EN/RU объясняет состав, отказ больше не предлагает
сменить бутылку вместо состава. 183 pure tests PASS; parse→variant/gaps проведены
в правильном порядке (они читают model): 5292 items/3636 recipes/100% RU,
diagnostic 4888/3570. Native 41:fluidrecipe PASS: шесть отказов (manual/auto ×
Brandy/TaintedWater/HCRWhiskey) до расхода; все прежние качества/дозы по-прежнему
PASS. Proof retail160-native-guards-pass.log и retail-guards-pass.png.

### Домашний лимонад: замкнутый native продукт

HCR_DrinkProducts + generated rules/families наполняют kept empty bottle .3L
(.1L juice +.2L water). Legacy HCLemonade1/2 сохраняют исторический остаток
2/1L × Food fraction/current snapshot. OnCreate получает scoped реальный
FoodTransfers context; protected cleanup при ошибке. Juice consumer generator
сохраняет специальный ProductTooltip при повторном запуске.

Native coldboot42:products PASS:6 migration cases +2targets×3freshness×manual/auto,
тот же ID/favorite, no output duplicate, точный poison1.625, authored nutrition.
Proof products160-native-pass.log/png в private lab; screenshot просмотрен.
184puretestsPASS; parse→variant/gaps:5292/3636/RU100. Read-only review final_review
подтвердил scopedcontext/recipeclosure без новых P1/P2. LuaLS отсутствует.
Lab PID27680 остаётся в worldpaused; command42:products. Реальные сейвы не тронуты.
Следующее: полная молочная цепь, кофе/какао, вино/дистилляция, storage/2clientMP.

### Молочная цепочка: 22 рецепта и сохранение качества сырных стадий

Генератор build_milk_chains сохраняет исходные блоки в milk_chains.json.
Native milk -> kept bucket4L -> heat/culture -> yogurt/butter/cheese;
расфасовка4x1L, старые partial jugs ->1L, whole evaporated concentrate+.7L.
12 Carton вариантов принимают reviewed native/HCR milk, расход .1/.2L.
Три старых ведра мигрируют; у двух Normal стадий нет исторических Food-полей,
перенос нейтральный,4L. NativeMilk читает whole-container properties, дробь
применяется один раз после фактического расхода; native ingress начинает4/7clock.
Разведение концентрата допускает чистую Water; no alcohol/tainted mixtures.

ProcessQuality переносит dose/worst freshness через12Normalcheese-stages.
Curds сохраняют заявленный10dayclock; Food waxed14dayclock продолжается
на стойке (имя actualrecipe проверено). Timed successor уже копирует modData.
Storage watcher и Food tooltip учитывают Normalprocessclock. Холодный native
storage/reload и2clientMP всё ещё не доказаны этим этапом.

Native42.21 consumeInputFromItems читает itemFC до eligibility check и падает
на groundworldFC. C.borrowWorldFluids временно переносит реальный компонент,
восстанавливает все owners до отправки sync; защита вложенности/ошибок.
Q.sync откладывается; после actualcraft публикуются даже untracked vanilla
donors. Read-only native network audit: interim packet идёт на временныйitemID,
finalworldsnapshot на том же orderedchannel. Это обоснование, ещё неMPproof.

Ревью final_review: выявлены/fixed multi-partialjugs, наблюдениеprocessclock,
waxedrecipe-name, lot/unit overflow ДО native debit/output. Native applied-cache
не гарантирует полный prefix, поэтому preflight проверяет верхнюю границу
candidateledgers. L.canMix возвращаетобычныйотказбезLuaexception.
202puretestsPASS; parse→variant/gaps:5292items/3636recipes/RU100.
Native52:milkPASS, productioncoldboot; helperreload послеразделенияrunCases
из-за Kahlua200localslimit. Покрытие:5migrationcases,6heat/culture/yogurtcases,
6nativefill/bottlecases,2legacyFoodroutes,2partialmultijugcases,4groundcases,
2taintedrefusals,2lotlimitrefusals,16Lvat→16curds→4trays→rack→4wheels,
12butter/culturecases,waxednear-expiryclock. Groundmanual setupborrow scope;
timer successor вhelper созданвручнуючерезHCRTimed.resolve/modDatacopy.
Proof milkcore160-native-pass.log/png private lab. Olderfailedhelperruns есть
втомжелоге; итоговый52:milkPASS приf120, неожиданныхошибоквэтомпрогоненет.
Следующее: остатокmilk/coffee/cocoa/evolved, wines/distillation, storage/2clientMP.

### 2026-10-31 — история холодного хранения

Q.age не перечитывает current generator на старом square для прошлого периода.
Разделены сохранённые generator/operational/grid flags: native Food age fallback
до shutdown и фактическая работа freezer имеют разные правила. Наблюдатель
учитывает обе новые power flags. Каждый десятиминутный шаг и OnSave закрывают
известный период без лишнего sync при неизменных условиях; новые загруженные
предметы проходят resuming checkpoint. Неизвестный генераторный gap холодный
лишь при powered на обоих концах; остальные случаи консервативно тёплые,
с отдельным known grid cutoff. Точное время потери/возврата топлива неизвестно.

212 unit PASS. Native coldboot 57:storageprobe проверил пять сохранённых
образцов (fridge/freezer/nested fridge/nested ground/Normal curd clock).
58:storageprobe + final actual storage run PASS при f1694: реальный генератор,
сеть, морозилка, CantFreeze, nested cold-to-warm, точные dose/nutrition.
24/48h интервалы backdated в private helper, не natural wait. Проверка helper
разнесена по ticks: IsoObject.checkObjectPowered кеширует питание на один tick.
Proof storage160-native-pass.log/png; seed лог отдельно. 5292items/3636recipes,
RU100%, parse→variant/gaps завершены. Два клиента MP/unknown unloaded gap в игре
не проверены. Следующий блок — фактические Food portions, затем остаток напитков.

### 2026-10-31 — фактические порции в Food craft

HCR_FoodConsumption сохраняет applied items, Food values/quality/dose до OnCreate,
затем измеряет native debit. Retained Food: raw hunger delta; removed: whole
remainder включая fractional tail. Generic nutrients — actual field deltas;
BaseHunger переносится пропорционально. Native HashSet order не симулируется.
T.contexts живёт до конца performRecipe; свои nutrition/juice/milk/lemonade/
returnContainer callbacks deferred до processDestroyAndUsedItems. Split copy
остаётся перед расходом, итоговая dose переносится после. Native OnCreate один.
Clear/restore metadata защищает возвращаемую посуду. Upper-bound preflight
проверяет всех Food кандидатов. Milk volume weighting использует raw hunger use
delta, поскольку float32 truncation может снять лишний integer currentUse.

218 unit PASS, read-only review actual/deferred/Normal/split без новых P1/P2.
Native59milk/60juices/61products/62foodquality/63fluidrecipe PASS;
portions160-native-regression.log. Final C.used fix + expanded milkhelper
coldboot64milk PASS: 4 дробных retained/removed tails, 16 multi-inputmanual/auto,
secondsourcefirst9, проверены lot litres по actual hunger uses.
portions160-native-final-pass.log/png. Generic nutrition4cases manual/auto
в62foodquality такжеPASS. Parse→variant/gaps,5292/3636/RU100.
Остались milk variants/coffee/cocoa/evolved ingress, wines/distillation/vinegar,
beer packaging и2clientMP передфинальнойупаковкой. 1.6.0 не опубликована.
# 2026-11-01 — молочная порция для evolved recipes

Добавлен `HCRMilkBowl`: 0,3 л kept milk donor + пустая Base.Bowl → Food, без
дублирования FC. Собственное питание/точная доза, ближайшие сроки компонентов;
исходные девять evolved направлений jug. Generated milk core теперь 23 recipes.
226 тестов PASS; native 66/67 полный milk+bowl PASS, 68 после cold boot также
проверил три сохранённые миски с custom offAge/offAgeMax, age/calories/dose.
69:milk подтвердил отказы до расхода tainted/frozen/partial-thaw/alcoholEffects;
CantBeFrozen миски постоянен, native не сохраняет runtime canBeFrozen/tainted.
Proof `.codex/modding-lab/milkbowl160-native-pass.log/png`; все три аудита,
5293/3637/RU100. Иконка через fal и universal-modder, provenance записан.
Первый harness промахнулся мимо output: native evolved кладёт результат в
player inventory, а не ingredient bag; исправлен тест согласно native UI.
Контрольная точка: игра SP HCRLab запущена, command file пуст, save содержит
помеченную сумку `HCRLab: milk bowl save proof`. Следующая замкнутая группа —
UHT / plastic / detergent milk: только SoapFill требует нового fluid route;
raw soy/jug/coffee пока не мигрировать. Полный релиз 1.6.0 ещё не готов.

# 2026-11-01 — UHT / plastic / detergent milk

Добавлен собственный UHT carton1L (пустой вес0,1, исходная иконка, native model).
Три новые Food→fluid миграции; existingmilkFamilies теперь6, milkrecipes24.
SoapFill теперь kept destination1,4L, marker сохраняет реальные порции/качество,
нет outputвторойканистры. M.destination поддерживает явный vesselType.
229 tests PASS; coldboot70:milk PASS: весьнабор+18retailfills, миграциидолей
.25/.5/.68/1, nutrition/dose/age/freezing. Proof milkretail160-native-pass.log/png.
Триаудита5294items/3637recipes/RU100. Ниодногопуша/публикации1.6ещёнебыло.
Открытвопроспользователюпоmilkcoffee: .1Lcoffee+.1Lmilkвпустуюкружкулибо
добавлятьмолокотольковнаполовинувыпитую. Независимаяследующаяработа—wine/distill
или rawsoy; coffeeтепловойпуть изучает equipment_audit. Игра SP работает,
commandfileпуст, частныйsaveсодержит milkbowlcoldsaveproof. Неостанавливаться
насрезе: полныйрелизостаётсяцелью.

# 2026-11-01 — вино / уксус / неполные Drainable

Pinned upstream 917d37d4ed526f429e1525316c9fab487bbf7257, timetracker_definitions
L400: восемь переходов по336h (grape/grapegreen/honey/rice -> wine/white/mead/sake
-> vinegar). Восстановлены без новых invented distillation timers. ProcessQuality
для двух grape buckets, девяти barrels, Vinegar2 и Rennet; finite exact dose,
worst freshness. Cooked mash1day не переносится как lifetime готового алкоголя.
Три целых honey/rice/flour pots; callback возвращает одну emptyNormalbarrel.

Wine native FC получает HCR marker +481cal/.12nativeAlcohol на литр; snapshots
preserveactualnativeprops. E.consume агрегирует nativeAlcohol по всем партиям,
затем один JustDrankBoozeFluid после hunger. Food legacy alcohol остаётся прежним.
Four .25L FC wineglasses сохраняют1Lдозу/питание/алкоголь, учитывают воду.
Legacy3glassIDs мигрируют remainingFood,includingactualalcoholic; oldFoodclasskept.
Deviation: новыеglasses не создают oldfixed170cal/Foodbooze из native wine.
Обычные Wine2 factory FC sealed: Empty+addFluid отказывал доunseal. Теперь
unseal идётпервым, потому что розливиспользуетalreadyopenedemptybottles.

ProcessActions перехватывает nativeDrainableupdate/complete, переноситwholeuses
иdoseвместе; stop/resume сохраняетрезультат. Native используетindependentrounding,
metadataнепереносил. Q.sync syncItemFieldsвключаетuses+modData; MP ещёнепроверен.
Evolvedvinegaruses actualdelta; flooritem отсутствиеcontainer неозначаетremoved.
Craft preflightсуммируетвсехC.capture(data,true)processcandidates,неprefixapplied.
Vinegar27HCconsumers:23Food+Rennet+3industrial; nativejar+8evolvedroutescovered.

238testsPASS, parse5295/3637/RU100, variant/gapsвыполнены, LuaLSнедоступен.
Native74winePASS доновыхconsolidation/jarcases;76подтвердилconsolidation/rennet,
helperMakeJarвыбралfactoryrandomWaterBottleбез.5LWater — исправленfixture.
77wineALLPASS (manual/auto,24bottlingbatches,mixed/dilutedglasses,DrinkFluidparity,
Drainableupdate/stop/resume/complete,rennetpartials,nativeMakeJar/cook/OpenJar).
Proofwine160-native-pass.log/png просмотрен. 78wineseedсоздалчетыреобразца.
Сейчасвыполняетсяcold-loadverify; отдельнаязаписьнижефиксируетрезультат.
Read-onlyreviewfinal_review:подтверждённыхP1/P2нет. Никакогопуша/релиза1.6.
Следомjug/chocolate(migration+carton),coffee/cocoa,distill/brewery,2clientMP,
finalreleaseQA;полныйрезультатнеобъявлятьготовымпоэтомуэтапу.

79:wineverify после полного закрытия/запуска PASS: четыре сохранённых образца,
uses/объём/доза/свежесть/nativeAlcohol/питание/начало брожения. Proof
wine160-cold-pass.log. E aggregation staged before this boot. Последняя правка
T.checkCraft только убирает неиспользуемую переменную, сам validation вызов сохранён.

# 2026-11-01 — plain/chocolate jug

Восемь milk families: новые HCMilkjug/HCMilkjugchocolate 2L, target existing
water vessels. Chocolate capacity1.4->2 сохраняет historical water1.4, нового
объёма при migrationневыдаёт. Отдельный HCRMilkChocolate только7oldORcounterparts
+bowl, plainmilkproductionнерасширен. PourintoCarton теперь1LkeptFC,безfoodSlot;
двапакетаизодного2Ljug; .05Lnativeхвостнедублируетсяинепропадает.
ПроверкиactualFoodportionраньшетестировалиэтотрецепт: helperпереведённаmigration
того же дробногоFoodпередрозливом; genericFoodactualregressionsостаютсявсвоёмнаборе.
239testsPASS; coldboot80milkPASS включаявесьпредыдущийнабор,двакартона,шесть
chocolatebowl/frostingmanualautoqualitycases. Proofmilkjug160-native-pass.log/png.
Requiredparse5295/3637/RU100,variant78unreachable/40blocked,gapsbaseline. Read-only
final_reviewподтверждённыхP1/P2необнаружил. Сохранениевсегорелиза/MPещёвпереди.
Исправленаошибкаописанияwineэтапа: HCMead/HCSakeпокаFood,аНЕnative-migrated;
нужноevolvedbridge(Soup/Stew8дляMead,6groups4дляSake)вместесdistillfamilies.
Осталисьrawsoy/coffee/cocoa,alcoholconsumers/distillation/brewery,storageunload,
2clientMPиreleaseQA. Существующийcoffeequestionещёбезответа;неповторять.

# 2026-11-01 — отмеренные алкогольные Food-порции

Новые HCRCookingSpirit .2L / HCRCookingMead .4L, девять HC составов, старые
evolved группы. A.properties сохраняет алкоголь через 2*hung/base; base не
масштабируется при разливе. T.addIngredient восстанавливает его после native
evolved, включая fresh/dose0. Per-slot R.inputs разрешает разные жидкости
разным ingredient slots; existing rules совместимы. NativeAlcohol и изменённые
runtime эффекты отвергаются preflight до расхода. Бутылки ещё НЕ мигрированы.

Readonly review выявил/закрыт: retained Mead baseline amplification; MP final
Food state терял base/nutrition/expiry. F.sync existing теперь sendItemStats;
F.fullSnapshot новых outputs sendReplaceItemInContainer (root/carried nested)
либо прежний world snapshot. T.finishCreate/A.finish и evolved wrapper после
final native name/temp публикуют полно. Existing held Food не заменяется.
Game ItemStats не содержит age/offAge/offMax, полная PlayerItem.save содержит.
MP live ещё не запускался. Повторный review P1/P2 не нашёл.

246 pure tests PASS; parse5297/3639/RU100, variant/gaps выполнены. Native83:alcohol
PASS:54manualautoquality; diluted evolved; real FoodEat/DrinkFluid parity;
freshdose0 retainedMead Soup/Stew Cooking10→Drink, без усиления. Helper81 ошибочно
предполагал весь input consumed;82 ожидал freshMead retained наCooking8 (native
tail removal); исправлены сценарии. Productionbaselinefix подтверждён на10.
Proof alcoholportion160-native-pass.log/png.84:alcoholseed запускается, coldload
ещё pending. Нужен commit этого блока после saveproof, затем Mead/Sake migration
с producer20BaseWhiskey и W legacyFood snapshot; прочийalcohol/distill/coffee/soy,
storage unload/2clientMP/releaseQA остаются. Никакого пуша/публикации1.6.

Пользователь ответил на coffee question: .1L coffee + .1L milk в пустую кружку,
остаток кофе сохраняется. Решение обязательно для следующих coffee recipes;
не спрашивать повторно и не применять вариант «только недопитая кружка».

88:alcoholverify cold-load PASS после полного выхода/запуска: три новых образца,
включая retained evolvedMead, сохранилиbaseline/flags/dose/quality. Proof
alcoholportion160-cold-pass.log. Попытка85 потеряла2из3 testoutputs: seed работал
без unlimitedcarry на перегруженномlabперсонаже, helperдобавлялworlditemвbag
безnativegrab. Исправлено черезISGrabItemAction + scopedunlimitedcarry;86seed,
87immediateverify,88truecoldverifyPASS. Productionничегоизсохранениянеудаляла.
Native FC network audit: syncItemFields содержит полный FluidContainer.save/load,
поэтому Q.sync для новых бутылок уже публикует marker вместоfactoryWhiskey.
Empty/addFluid сами не реплицируют. Foodдополнение ItemStats/fullSnapshotнужно.

# 2026-11-01 — Mead/Sake native

Две WineFamilies HCMead/HCSake→Base.Whiskey1L, дваproduceroutputs20Base.Whiskey.
W.bottledSnapshot берётlegacyFoodprototype (356/39cal, FoodalcoholPower2),
factoryWhiskey свойства не применяет. Исходные Food классы/evolvedIDоставлены,
прямые Food consumers отсутствуют, порции из e9cceb4 закрывают evolved.
248testsPASS, parse5297/3639RU100, variant78/40/gapsbaseline. Native89:wineALLPASS:
24bottlingcases+8partialmodifiedstockMead/Sake migrations+entirewinevinegar suite.

Review нашёлnetworkrace: W.finish unseal отправляет factorycontents channel0,
finalsyncItemFields channel1 может прийти раньше. Заменено publicnative
setCanPlayerEmpty(true), затемEmpty/add/store/sync. Nativeunsealotherchangesтолько
копирование тех жеfluids;canPlayerEmptyсериализуетсявFC.9winetestsPASS incl
regression forbiddingearlyunseal. Native90:wineALLPASS. Proofmeadsake160-native-pass.
Реальный2clientMPнепроверен. Следомcoffee/cocoa/cookableSoy, distillconsumers,
storageunload/2clientMP/SandboxMP/releaseQA. Usercoffeeanswer .1+.1 emptycup.
Никакого push/publish1.6.0. PrivateSPработает,commandfileочиститьпослеproof.

# 2026-11-01 — Coffee closure

BrewedDrinks30 rules: 12manualfinish,3rawbrew,3measuredpour,6inPlaceSugar,
6milk mixtures. User .1coffee+.1milk в отдельнуюemptycup; термос .7+.7.
Raw Food классы сохраняются, finish лишь cooked/burnt: autoOnCooked отключал
бы nativeburn. Full/partial snapshotпитание не масштабируетсяповторно, объём
fraction=currentHung/baseHunger. Тара BaseMugl.2, ClayFluid1.4(кофе.2),
Kettle1.5,Thermos1.4; cocoa2manualfinish. Noextraempty;AllowFavorite/Inherit.
Rawbrewers separateempty+.2/1.5pureWater; originalCoffee2amounts/heat unchanged.
Sugarzero-volume lot сactualfraction; сохраняетсятажеFC, slot0exact prevents
native poolingpartialvessels. Milk/Carton generator ownership explicitlysplit.

Review2P2fixed: brew pure-water whitelist must filterALLactualcandidates through
R.inputs, а неtestOnlyapplied; sugarpreflightallfoodTypecandidates catcheslot
overflow beforedebit. Candidateemptydestinationamount0allowed. NootherP1/P2.
MilkaddFood похожийlimit не подвержен текущейошибке: лишь1wholeevaporateditem.

253purePASS. Parse5297/3651RU100,variant78/40,gaps4893/5297+3585/3651.
Native93:108casesPASS butburnfixturefailed same-minuteupdate; correctedseparate
Food.94/95coffeeALLPASS inclburn,contaminatedWatermanualrefusal/autoexclusion,
127lot+3sugarrefusal,nodebit,nativeCoffee+Water/CowMilknutrition. 95seed3samples.
Proofcoffee160-native-pass.log/png inspected. Privategame restartedWITHOUTdebug
(assertbreaknesteddebugger slowedlab; no productionchanges). Cold96pending.
CurrentUNCOMMITTEDcoffee; no pushpublish. NextSoycookablemanualfinish +9direct
consumer volume audit assignedread-onlychains_audit; distill/spirits,breweryremaining,
storageunload,2clientMP,SandboxMP,releasewidechecks/docs/package stillpending.

96:coffee truecoldPASS:3savedpartial/sugar/milk samples exactamount/calories/
dose/quality/lotcount, весьnativeнаборagainPASS. Proofcoffee160-cold-pass.log.
Generator idempotence выявил тольконарастающиепустыестроки6Milkrecipes;
normalizationвнутриrecipeисправлен. CoffeeMilklabelбезобязательногосахара.

Coffee сохранён в 9a1f763. Независимая часть Soy: HCRMilkSoy и явное завершение
приготовления в Base.Whiskey 1 л. Published485e704 остаётся источником для
20/40 минут нагрева/подгорания, 15/30 дней свежести и DangerousUncooked.
Native97:coffee PASS: 52 finishes +36 milk +18 pours/sugar +6 water brews,
raw refusal и native Soy heating/burn; proof soy160-native-pass.log/png.
253 tests PASS, затем дополнительный тест частичного Soy PASS (5 brewed tests).
Вопрос пользователя о расходе Soy в девяти блюдах ожидает ответа: единые
объёмы молока или сохранение 1/30 бутылки. До ответа consumers не менять.
Следом private 2-client MP: новые cachedir, native menu handlers, HWND для
снимков. um drive --proc неоднозначен при двух одинаковых именах процессов.

Soy finish committed b9434ce. Двухклиентский localhost lab создан в
`C:/Users/Igor/.codex/modding-lab/pz-two-{server,owner,observer}`. Только private
профили, Open=true при bind127.0.0.1, Steam/VAC/UPnP/Public=false, MaxPlayers2.
Initial admin password через два stdin lines (не CLI); adduser не использовать:
native console пишет всю команду. Отдельные credentials в private lab, не git.
prepare_two_mp.py/run_two_mp_server.py/mp_window.py остаются вне repo.
mods/reset-mods-42_00.txt обязателен: без него первый boot стирает default.txt.
Menu bootstrap использует native ServerConnectPopup и character creation UI.
Два клиента успешно вошли, exact HWND screenshot + physical loading click.

Новый tools/lab_two_client.lua пока НЕ полный PASS. Native10:start прошёл
initial legacy nested flask, migration .7TaintedWater, owner native milk bowl,
peer shared bowl, native quarter Eat with held reference, shared partial bowl.
300→225cal, .375→.28125dose, base-.12/current-.09, off0/max4/age≈1.
Carton phase требовала настоящей поверхности AnySurfaceCraft: исправляется lab
native table carpentry_01_60 и ISEntityUI.FindCraftSurface. Следом13:start.
Native auto FromLogic(false) падает convertToPZNetTable(Boolean); lab использует
manual selection. Ошибка lab ArrayList.add(assert(...)) передавала два аргумента;
исправлено отдельной local переменной. expected polling не должен спамить assert.
Новые Lua файлы после старта отсутствуют в virtual map: initial reload читает
fallback profile/mods/media/lua/shared/HCRLabTwoCases.lua. При следующем cold
boot stage также настоящий HCRLabMP/42/media/lua/shared, очистить commandfiles.
Owner hot reload временно выдавал Kahlua callFrame NPE после ошибочного Java
вызова;12reload уже PASS, но окончательное доказательство требует cold restart.
Пока никто не публиковал1.6.0. SandboxMP, coldMP, storageunload остаются.

## 2026-11-01 — Два клиента: завершённые live и cold прогоны

18:start прошёл все 11 фаз. После полного чистого старта 20:start повторил
PASS: owner native craft, held Food quarter Eat, native inventory transfers,
новый carton FC, world-to-world fluid transfer, Sandbox disable/restore через
штатную Admin UI. Оба клиента читают состояние самостоятельно; сервер сверяет
канонические предметы только после двух ACK. Proof twoclient160-clean-*.log.
Снимки mp2-owner/observer-current_small.png просмотрены.

Lab исправления: стол требует IsoObject.new(getCell(),square,sprite), а смена
sprite — getSprite(name), иначе нет GenericCraftingSurface props. Переливание
требует ISFluidContainer(FluidContainer), не IsoWorldInventoryObject. Это были
ошибки harness, production изменения не понадобились. Native replication
временно пишет expected assert до стабильного состояния; итоговая проверка
ждёт 120 кадров. Искусственные packet loss не проверены.

Аудит final_review нашёл два дефекта oracle: поздний ACK после timeout мог
дать PASS; saved fixture без рестарта назывался cold. Исправлены terminal guard
и boot IDs всех трёх процессов. 21:verify без рестарта ожидаемо отказал.
После native client exit + server quit, окончания всех старых PID и нового
запуска 23:verify PASS: обе клиентские копии и сервер подтвердили сохранённые
флягу, partial Food, carton, source/target coffee. Proof twoclient160-cold-*.log.

254 теста PASS, parse 5297/3652 RU100%, variant78/40, gaps4893/5297+3586/3652.
Текущие private процессы: server5420, owner25924, observer27316 (сверять PID
файлы перед действием). Commands server23:verify, clients empty. Следом реальная
выгрузка участка с холодильником; native teleportto обоих клиентов и три
независимых getGridSquare==nil, затем возврат. Новые файлы после boot загружать
из fallback profile/mods/media/lua/shared через reloadLuaFile.

Оставшиеся production блоки: Soy consumers ждут ответа; spirits/distillation,
retail beer, Methanol. Flour→native Whiskey требует consumer compatibility,
Mezcal должен сохранять червя в пустой бутылке. Нельзя просто включить migration
без этих выходов. Аудит цепочек в сообщении chains_audit; никаких новых таймеров
браги из головы. 1.6.0 по-прежнему не опубликована.

## 2026-11-01 — Настоящий storage unload PASS

Новый tools/lab_storage_unload.lua, loaded после Cases в private combined file.
Отдельный HCRLabStorageCommand: 1:probe нашёл fridge/freezer10656,9413,0.
Native console teleportto обоих рядом, 2:start три образца1L/615cal/.875dose.
Grid стабильна, ElecShutModifier14, FridgeFactor3, FoodRotSpeed3. Бутылка frozen
в тестовой fixture изначально заморожена; замораживание ранее проверено в SP.

Оба native teleportto10655,11000/11001,0; origin square реально nil на трёх
процессах. Server .25 world hours, каждый client >=.24, без изменения времени.
READY_RETURN после37,152,581ms; обратно10655,9413/9414. Server+дваclientPASS
на37,190,091ms. Читаются raw metadata, не Q.capture: lastHour обязан быть после
unload interval, age по formula, sameID/count, exactbudgets, fridge/freezer flags.
Java item references не держатся в state. Proof storage-unload160-*.log/png.
Снимки после возвращения просмотрены. Production не менялся.

Final review исправления: age tolerance1e-5 вместо1.5e-4; terminal client fail
при loaded square в absent, независимый observed absence interval в returnACK.
ReloadLuaFile новых Events не установил: module использует существующий
HCRLabTwo tick/client/server bridge с args.storage. Для cold staging назвать
модуль после Cases или объединить. В текущих profile Cases combined version27.
Live processes всё ещё server5420/owner25924/observer27316. Последняя server
console10:teleportto observer near fridge; StorageCommand2:start completed;
TwoCommand27:reload. Перед остановкой очистить commandfiles, clients native
28:exit, дождаться их завершения, server consolequit; затем ждать exactPID.

## 2026-11-01 — магазинное пиво и тара evolved

Предыдущие MP процессы штатно завершены. Добавлены 18 native beer migrations,
10 pack/unpack pairs, .3L cooking bridge. См. FLUIDS_1_6_STATUS для сохранённых
свойств и forced deviations. Read-only review нашёл общий tracked-FC guard и
auto empty candidate blocker; narrow pack-input allow исправлен, native passed.
265 tests PASS; parse5316/3653/RU100%; variant78/40; gaps4912/5316+3587/3653.

Native98 выявил ошибочную whole-portion assertion. Fresh decompile Food42.21
показал currentUses=int(abs(hungChange*100)); UseAndSync снимает1food-use,
но создаёт ReplaceOnUse и при остатке. A.evolved/T.addIngredient scoped fix
предотвращает лишние сосуды для всех3 cooking portions. Legacy nutrition/use
сохранены, exactdose распределяется по фактическому расходу.
99:beer baseline PASS; 101:beerverify после coldboot PASS3samples.
102 oracle имел неверную1L beerbasis, исправлена .3L. 103:beer PASS:
18pristine+54modified migrations,20packcycles,4refusals,12evolved comparisons,
Beer5/Mead4/Spirit2 повторных rotten additions → ровно1empty +totaldose preserved.
Proof beer160-native-pass/cold-pass.log/png. Возврат тары MP ещё не проверен.
SP сейчас PID5420 (это НОВЫЙ ProjectZomboid64, не прежний MPserver5420),
private pz-profile, command103:beer. Не трогать PID без проверки executable.
Следующие блоки: MP pack/empty returns; distillation/spirits consumers; Methanol;
Soy9consumers ожидают ранее заданное решение пользователя. Полный1.6неготов.

## 2026-11-01 — beer MP PASS

SP завершён командой 104:exit. tools/lab_beer_mp.lua добавлен к private Cases
после lab_two_client.lua; args.beer использует прежний bridge. Первый MP boot
имел checksum mismatch после правки harness между server/client стартами.
Все процессы остановлены, копии уравнены; native checksum не отключался.
В чистом boot 1:start отказал до fixture: Cooking недостаточен. Native console
addxp HCRLabOwner Cooking=1000000; 2:start PASS11phases на server+2clients.
Proof beer160-mp-{server,owner,observer}.log/png; оба снимка просмотрены.
Упаковка/распаковка, partial transfer, 5rotten soups totaldose.375, ровно1empty;
источник после передачи проверен на отсутствие новых outputs. Production
не менялся. Текущие PID server26524/owner3132/observer28620, только private
pz-two профили. Commands BeerMP2:start complete, console3:addxp; Two пуст.
Следом native выход клиентов и сервера, distillation/spirits. Этот MP набор
ещё не проходил cold reload; общий fluid/Food cold ранее прошёл.

## 2026-11-01 — native Whiskey и восемь бочек качества

Beer MP зафиксирован 6e3b48b, процессы26524/3132/28620 штатно завершены.
Новый HCR_NativeWhiskey: zero-volume Whiskey lot, не второй sidecar.
Физический native Whiskey/питание/алкоголь сохранены; spoilHunger нужен
JustAteFood для порчи без повторного Eat/hunger/timer. Все transport invariants
не менялись, Whiskey не внесён в Q.transport. 8 Normal браг добавлены в P.types.
Flour distillation20nativebottles поддерживает качество; medical/trap slots
и direct ISDisinfect списывают quality без ingestion. 270 unit PASS, parse
5316/3653 RU100%, variant78/40,gaps4912/5316+3587/3653.

Native105 ground-output oracle;106/107 rotten-Food rejection исходного input.
Исправлен тест, без AllowRotten изменения production. 108/109 whiskey PASS:
6manual/auto productions, drink parity, poison/spoil,10nonfood crafts,
direct disinfect,4mixed transfers. 110exit завершилPID19900. НовыйPID27328:
111whiskeyverify PASS3saved samples. Proof whiskey160-native-pass/cold-pass.log/png.
Снимки просмотрены. Последняя команда112exit, проверить GameThread/точныйPID.
Read-only review P1/P2 не нашёл. MP данного пути ещё не проверен.

Далее8HC spirits и10directconsumers +3nativeWhiskeypours. Все нужныеmarkers
уже есть HCR_DrinkFluids, включаяHCRWhiskey. Предпочтительно8новыхnativevessels
с исходными иконками, вMezcalworm физическиостаётсявсосуде. W.preflight/finish
сейчасожидаютfactory1L; новыеempty-prototypes требуютявногоrule.empty.
3legacyemptyglasses NormalможноприниматьORnewnativeFluid сflags[ItemCount;IsEmpty]:
InputScript.doesItemPassIsOrNotEmptyAndFullTests ignoresIsEmptyforplainNormal,
checksFCifpresent. Дляworld-ownedfilledglass вlegacycocktail безfluidinput
потребуетсяявный Q.fluid IsEmptyguard, иначе nativeнеувидитworldcomponent.
Новыеnativepour outputs должнысохранятьреальную.1Lnutrition; nativeWhiskey
можновноситьчерезR.nativeWine='HCRWhiskey' вместеzeroqualityWhiskeylot.
Native/legacy recipes нельзяподменятьбеззакрытиявсехORветок. Soy9всёещёждётответа.

## 2026-11-01 — spirits, бокалы и их потребители

Реализован build_spirit_fluids.py: 25 migrations (16 bottles + 9 glasses),
19 native vessels, 8 distill outputs, 12 pours, 16 downstream consumers.
Пустые 15 бутылок переиспользуются в 19 рецептах; Mezcal с червём исключён.
Коктейли ещё Food с исходными свойствами, без попытки выдавать это за весь
оставшийся бар. Домашняя Vodka исключена из cooking по sourceType каждого lot.
Generic world IsEmpty guard закрывает filled-world-vessel расход без -fluid.
Whiskey markers в script/catalog согласованы, обычный native transfer в бокал
принимается; native/HC mixtures сохраняют бюджет через nativeWine snapshot.

Native 113 обнаружил duplicate glass: OnPostWorldDictionaryInit делает keep
для -fluid без явного mode:destroy. Исправлено в 11 cocktail sinks.
115 прошёл все production/pour/consumers, но oracle дал пивную кружку вместо
Base.GlassTumbler в cooking. Исправлен oracle. 116:spirits ALL PASS:
100 migrations, 48 distills, 24 pours, 32 consumers, 15 cooking + 1 refusal,
mixed native/HC pour и native Whiskey cocktail. 117:exit PID19712 завершён;
новый PID26732: 118:spiritsverify PASS3. Снимки просмотрены.
Proof spirits160-native-pass.log/png + spirits160-cold-pass.log/png.
Последняя команда119:exit; проверить PID перед следующим запуском.

274 unit tests PASS. Parse5335/3653 RU100%, variant78/40,
gaps4931/5335+3587/3653. Генератор идемпотентен. LuaLS по-прежнему недоступен.
Read-only review подтвердил Whiskey whitelist mismatch (исправлен), других
подтверждённых проблем после правок не оставил. MP spirits/native Whiskey далее.

Новый pending вопрос пользователю: Methanol — вернуть исходный Make Methanol
из готового спиртного с сохранением current found-barrel route либо придумать
новый lemon cycle. Доказанного lemon timer нет ни в истории, ни pinned917,
ни проверенных upstream branches. Текущий callback даёт единственные5 HCMethanol,
не дублирует output (script output сейчас только woodenbarrel). Source-backed
Make Methanol: Cooking7, time100, whole OR bottle →1 four-use HCMethanol.
Soy9consumers всё ещё ожидают прежнего ответа. Ни push, ни release1.6 не было.

Scope audit: ROADMAP по-прежнему требует native fermentation внутри FC и
пивоварню. Нынешние8 wine/mead/sake→vinegar timers336h работают на Normal stages,
не заменяют это обещание. Brewing cycle в original отсутствует; HCHops имеется,
доступные grain/yeast/equipment и quantities продолжает read-only equipment_audit.
Оставшийся бар (Rum/mixers/cocktails/Irish/Eggnog/MonkeyTail), soda/energy/cider
ещё имеют Food IDs без полного native finish/migration. Не забыть полную closure.

### 2026-11-01 — MP спиртного и сохранение

25faad0 проверен в private pz-two-server/owner/observer. lab_spirits_mp.lua:
2:start PASS all ten phases на сервере и обоих клиентах; Whiskey/Gin20×1L,
shared transfer,0.1L pour,Old Fashioned,raw quality/dose,точный подсчёт предметов.
1:start упал из-за oracle assert multireturn в {get()}; исправлено скобками.
Read-only review нашёл count-hole общих бутылок, исправлено до успешного прогона.
После122:exit и123:quit новые PID28636/10964/23920;3:verify cold PASS всех3.
Proof spirits160-mp[-cold]-{server,owner,observer}.log;4clientPNG просмотрены.
Фактическое питьё/опьянение этот MP oracle не проверяет. Штатный124:exit
обоих клиентов;125:quit серверу. Следующий этап — оставшиеся барные напитки.
Ожидаются прежние ответы Soy/Methanol. Публикации1.6 не было.

### 2026-11-01 — Бурбон, скотч, ром

Каталог расширен25→32families,19→23vessels:4bottles+3legacyRumglasses.
3Rum pours .1L,3glass consumers,LongIsland separateRum slot .1L;PlanterPunch
не требует лишнийemptyshortglass.4new cooking bottle sources;19empty aliases
обновлены. Исторические food_count записи перенесены в superseded.
274tests PASS,parse5339/3653 RU100,variant78/40,gaps4935/5339+3587/3653;
generator idempotent. Native126:spirits PASS128migrations,48distills,30pours,
38consumers,19cooking+1refusal,mixednativeWhiskey;smoke5339failed0.
127:exit PID26184→new6068;128:spiritsverify COLD PASS9. Proof
spirits160-rum-{native,cold}-pass.log/png;снимки просмотрены.129:exit послан.
MPновыхRumslots ещё не проверен. СледомAbsinth/Herballiqueur/Mead2 иAgua,
ноAguazero-hunger требуетузкийthirst-basedmigrationfallback, неgenericguardremoval.
Полнаяread-onlyкартаоставшихсябарных/softdrinks записанаFLUIDS_BAR_AUDIT.md.

### 2026-11-01 — Травяное спиртное, Mead2, Agua

Каталог36migrations/27vessels,3newneutralmarkers,herbal .8L cooking bridge
сemptyHCHerballiqueurFluid return;Mead2 existing.4Lbridge. Aguaremaining
толькоexplicitzero-hunger spec:rawthirst/scriptthirst. MonkeyTail2recipes
тратят1LAgua, nativeMilk0slotсохранён,legacySoyвариантожидаетпрежнеерешение.
276unitPASS;parse5344/3654RU100,variant78/40,gaps4940/5344+3588/3654;genidem.
Native130failedoraclefixedwhole-doseexpectation:rottenherbсъедаетсячастями.
131ALLPASS144migrations,48distills,30pours,38consumers,22cooking+2refusals,
herb nativeevolvedparity/repeatedsinglevessel,Aguafull/partialdrinkparity,
4MonkeyTailmanualauto. Native smoke5344failed0. Read-onlyreviewnofindings.
132exit22620→23100;133coldPASS19. Proof spirits160-herbal-{native,cold}-pass.log/png;
обаPNGпросмотрены.134exitпослан. Никакихpush/release1.6.
ДалееобязателенlegacyAguaEvolvedguard: nativezero-hungerделит0/0,UIнефильтрует.
CurrentnewfluidнепопадаетвSpiritCooking,ноотложенныйoldFoodещёопасен.
SourceFoodCFRstoredprivately agua-reference/Food.java. Затем mixers/cocktails,
Eggnog/MonkeyTailnativefinish,softdrinks,nativefermentation/brewing,releaseQA.

### 2026-11-01 — Барные смеси и защита старого агуардиенте

Закрыт legacy Agua zero-hunger evolved guard, включая spice=true и серверный
complete. Unknown remaining portion теперь откладывает миграцию без assert:
B42 логировал даже пойманное исключение при каждом inventory tick.
135 guard использовал старый загруженный Lua и отказал до complete; после
перезапуска137/147 PASS на обычном/изменённом/deferred/spice legacy Food.

Шесть bar families/vessels, три mixer producers,13 cocktail consumers.
Новый выход0,1 л из0,1 л сока; реальные nutrition/poison/freshness от сока,
воды и специй вместо fixed-output550/400 ккал. Старые Food сохраняют snapshot.
Bitters/Vermouth/TripleSec:40uses×0,025 л без выдуманного Food-питания.
20 Whiskey-empty +2 Wine-empty маршрута принимают соответствующие новые
пустые сосуды. Wine2-empty маршрутов пока нет (учесть в native wine).
Read-only review поймал foodSlots filter, aliases и native pruning0,10005 л;
исправлены, unit/native regression добавлены. Lot volumes нормализуются,
Food units остаются целыми. Три генератора идемпотентны, Lua5.1 syntax PASS.

284 unit PASS; parse5350/3654 RU100%, variant78/40,
gaps4946/5350+3588/3654; native smoke5350 failed0.
141:bar PASS21 migrations +36 manual/auto fresh/stale/rotten pure/diluted
crafts +2 prune-edge fixtures.142:spirits ALL PASS прежнего полного набора
с актуальными mixer inputs. Proof bar160-native-pass.log/png, tooltip просмотрен.
144:exit PID13244 → новый10308;145:barverify COLD PASS6;
146:barchain сок→mix→Whiskey Sour PASS;147 guard PASS;148 spirits cold PASS29.
Proof bar160-cold-pass.log/png, снимок просмотрен.150:exit отправлен.
MP этой группы не проверен; lab_spirits_mp fixture обновлён, пока не запущен.

Следом soft drinks, затем готовые cocktail/IrishCoffee/Eggnog/MonkeyTail,
native fermentation/brewing и оставшиеся release QA. Soy/Methanol решения
всё ещё ожидают ответа. Публикации1.6 не было.
Уточнение read-only equipment audit: HCBlenderpowered Drainable8 uses,
восьмой даёт dead blender; не делать keep/дублирующий callback.
HCGlassjug действительно был в pinned917 Glassworking: UseDelta0,07 у full,
значит принятый water mapping даёт1,4 л. Иконки сохранены; текущий мод потерял
определения. Не выбирать2 л для cider без основания. Детали в BAR_AUDIT.

### 1.6.0: Soft Drinks, 2026-11-01

17 migrations, 16 новых сосудов, 14 нейтральных fluid identities; Pop pack
factory checks, Soda empty aliases, retained Fitness flask и точные consumers.
Native155 PASS: 17+51 migration, pack cycles, 8 Fitness crafts/8 blender charges,
rotten-solid refusal, 20 juice aliases, 2 lemonade, 2 Coke, 8 Fitness consumers.
Неудачные151/152 — штатный native запрет rotten solids;153 — ошибочный ID
только в fixture. Ни одно не исправлялось ослаблением production правил.
Proof soft160-native-pass.log/png просмотрен.156:exit PID25216 →4396;
157:softverify COLD PASS28,158:softshow; soft160-cold-pass.log/png просмотрен.
159:exit →26280 для финальной проверки исправленного bar auto capture.
289 unit PASS. Read-only review выявил лишний capture посторонних Water в bar
auto preflight; исправлено native composition/type проверкой, stress oracle
добавлен в lab_bar_fluids. MP Soft не выполнен. Публикации1.6 не было.

Следом готовые коктейли/Irish Coffee, medical fix (Lemongrass устаревшее
ReduceFoodSickness → FoodSicknessChange=-50), Eggnog/MonkeyTail, брожение,
варка пива и полный release QA. Soy/Methanol решения остаются ожидающими.

Финальный Soft regression:160:bar PASS с 127 juice lots +2 unrelated Waters
и 1 lot +129 Waters, прежними36 mixer crafts и2 prune edges.161:spirits ALL
PASS;162:softverify COLD PASS28. `soft160-final-regression.log`.
Parse5366/3654 RU100%, variant78/40, gaps4962/5366+3588/3654;289 unit PASS.

### 1.6.0: дозированные лекарства, 2026-11-01

Lemongrass FoodSicknessChange=-50 вместо непризнанного ReduceFoodSickness.
HCR_Medicine.prepare чинит старый нулевой fresh/raw baseline один раз по
оставшемуся hunger; новые ненулевые дозы также помечены против resurrection
int-tail. Hook F.eat до early return, native cooldown/poison сохранены,
server sync sickness+poison и item без replacement. Лекарства остаются Food;
Mouthwash остаётся вредным household средством, исходный литраж неизвестен.
293unit PASS; Lua syntax PASS; parse/variant/gaps без изменения количества.
164:medicine PASS full heal/cooldown, ginseng partial/full, adrenalin snap+
stress, 4extract+2box+10syringe manual/auto crafts, harmful mouthwash1/2.
Proof medicine160-native-pass.log.165:exit PID17600→23468;
166:medicineverify COLD PASS старой сериализованной половины дозы (heal25),
167:foodquality полный native regression PASS. medicine160-cold-pass.log/png
просмотрен. MP medicine ещё не выполнен. Готовые cocktails/IrishCoffee — далее.

### 1.6.0: готовые коктейли и Irish Coffee, 2026-11-01

Закрыты16 legacy families и19 recipes:14 ready-vessels0,5 л, Irish в
существующей Mugl/HCClaymugFluid,15 новых neutral markers. Реальный объём и
свойства ingredients, nativeCola/Water/Whiskey snapshots без удвоения;
16 empty alias routes, без потери partial и дубликатов. Подробные
изменения баланса/тарных состояний записаны FLUIDS_BAR_AUDIT.

295unit PASS;99Lua syntax PASS;5generators idempotent;parse5380/3654RU100;
variant78/40,gaps4976/5380+3588/3654;smoke5380failed0. Read-only reviewP1/P2нет.
172cocktails PASS64migrations+114crafts+8native cases+28empty reuse/refusals,
partial/fullDrink иnative refill.170/171labconstraints исправленыбезproduction
ослаблений.173barchain,175spiritsALL,177soft PASS;174/176labFoodassertions
адаптированы к новымFCoutputs.178tooltip просмотрен. Evidence
cocktails160-native-pass.log/png.179exit7500→16552;180coldPASS92;181tooltip
просмотрен;cocktails160-cold-pass.log/png.182exit отправлен. MP новыхготовых
cocktails/soft/medical/herbal пока не выполнен;oracleSpiritsMPподготовлен.

Следом Eggnog/MonkeyTail (8recipes/6Food, реальный выход.35/1.1L;4mugs=.8,
2bottles=2L; убратьrecipe_hcpot приkeptsource). Soy/Methanol ответыожидаются.
Потом native fermentation/brewing,полныйreleaseQA/публикация.1.6неопубликована.

### 1.6.0: native Eggnog/Monkey Tail, 2026-11-01

6legacyfamilies,2bottle FC,6native recipes. ДваoldmilkOR producers PENDING
Soy,невыдаватьзаrelease-ready. Nativebatch.35/1.1L,4mugs.8/2bottles2L;
pooledkeptdonors,точныеbudgets,нетдублирующегоrecipe_hcpot. Bar.create
multi-output;nativeeggTags preflight;safeEggSlot сохраняетoldнетrawpenalty,
неубираяпорчу/яд. Ownership2Carton вbuild_milk_chainsисправленпослеP2review.
7generatorsstable;298unitPASS;144LuaPASS;parse5382/3654RU100;variant78/40;
gaps4978/5382+3588/3654;smoke5382failed0.186milkbarPASS24migration+24produce+
24pour+4refusals,185cocktails/187bar/188spiritsALLPASS.

LabPlayerDBBufferOverflowпосле185:115completedcocktailcoldbagsduplicated
ledger snapshots. C.runretiredтолькопомеченныеHCRCocktailCold bags;другие
fixturesсохранены.189exit27524безновогоoverflow→27372;190milkbarverify
COLDPASS54. Proofmilkbar160-native-pass.log/pngиmilkbar160-cold-pass.log/png
просмотрены. MPmedicine/soft/herbal/cocktails/milkbarещёнепроверен.

Далее общийMPпроход (oracleSpiritsMP ужеFC-ready), Soy/Methanolpending,
nativefermentation/brewing,полныйreleaseQA. Не создавалrelease/push/Workshop.

### 1.6.0: MP и синхронизация хранения (2026-11-01)

Spirits4:start ALL10 и Generic31:start ALL11 на90df0f5:server+owner+observer
PASS. Далее lab_drinks_mp16phases и cold всех трёх suites завершены (ниже).
Production: client isValid прерывалDrinkмеждуFC/modDatapackets; только
ужеstartedDrink/Transfer ждётservervalidation. Серверныеchecksсохранены.
Run7nativeDrink .3→.225,+75cal PASS,END1из-заlabGodMode/UnlimitedEndurance.
Флагиoff;8–13inputcraftblocked, расследованиепоказалоnative tooDarkToRead.
Run14подготовленснастоящимHandTorch+ISEquipWeaponAction, пока незапущен.

Втораяошибка: Q.storage→Q.sync→SWAP_ITEM outerbag инвалидировал queued
transfers (4mugs→2). Добавлен HCR_QualitySync storage-onlymetadata exactpath,
общаяrevision,30s boundedreconcile/256entries,беззаменыпредметов. P2review
highestSeen retirement исправлен,6сетевыхрегрессий+2actionsрегрессии.
306unitPASS;parse5382/3654RU100;variant/gapsбезизменения. Кодещёнепроверен
нативновbulk/cold на этом промежуточном этапе; итог ниже. GeneralmutationworldbagsпрежнийSWAP,этоотдельныйриск.
См.FLUIDS_1_6_STATUS. Productionнепубликовался;используютсятолькоприватныепрофили.

DrinksMP24: все16фаз PASS server+owner+observer. Очереди4mugs/2bottles сохраняют
identity сумки и контейнера. Energy native trace: точные calories/endurance/
fatigue/poison для фактической четверти. Lemongrass oldhalf/cooldown,
ginseng partial/full, adrenaline native whole-dose и возврат3tubes+1bottle PASS.
17–23 исправляли oracle: floor50kg от failed fixtures, metabolism вне action,
native cooldown без immediate stats, смерть lab персонажа от предыдущего
яда, server SleepAllowed/SleepNeeded=false сбрасывали fatigue. Теперь
baseline health/poison чистые, God/UnlimitedEndurance=false, native sleep=true,
cooldown no-heal проверяется доACK и server trace=0/calls1. Мир20–21 сохранён
отдельно, восстановлен private pre20 checkpoint. Пользовательские сейвы не трогали.
Read-only P2: первый40/40 нельзя latch без проверки позднего лечения; исправлено.
146Lua syntax PASS, parse→variant/gaps5382/3654RU100,78/40,4978/5382+3588/3654.
Generic75 ALL11/Spirits5 ALL10 PASS на всех трёх процессах.
После штатного выхода и полного перезапуска: Drinks26/Generic82/Spirits6
COLD PASS server+owner+observer. Прежние run IDs и item IDs, raw ledger,
native состав/объёмы, питание/алкоголь/яд сохранены. Ошибка первого25verify
была в поиске сумки по floor координаты игрока; исправлен только lab lookup
в радиусе2, без создания новых fixtures. Proof drinksmp160-native-pass-* и
drinksmp160-cold-pass-* (logs всех3, screenshots обоих клиентов просмотрены).
306unit/146Lua PASS. Никаких release/push/Workshop.

### 1.6.0: электросеть и выгруженные холодильники (2026-11-01)

Native research уточнил две границы: Food.updateAge D×24 намеренно не
учитывает TimeSinceApo, operational grid учитывает месяцы до старта. Разделены
age/grid cutoff в Q.age/C.advance, сохранён age quirk. 3 новых unit случая,
два воспроизводили неверное оттаивание до исправления;309unitPASS.
147LuaPASS;parse→variant/gaps5382/3654RU100,78/40,4978/5382+3588/3654.

lab_storage_power: actual MP unload на server+2clients, forward ticks без
перестановки часов. 1:base PASS cutoff72, absent69.038→74.504;2:offset PASS
TimeSinceApo2 cutoff120/age840, absent117.046→122.515. Raw received ledger,
ID/1L/615cal/.875dose, fridge/freezer/nested ground age и thaw совпали.
Режимы Sandbox и90min/day восстановлены с3ACK. Review cleanup P2 исправлен:
ошибки также восстанавливают настройки, ABORT не выдаётся за PASS.
Proof powercut160-base/offset-{server,owner,observer}.log и оба pass PNG
просмотрены. Checkpoint private world/config сохранён до теста. User saves
не трогали; release/push/Workshop нет. Далее mutation sync сумок.

### 1.6.0: mutation sync вложенных сосудов — начатый срез

Native packet review: ServerCommand/SyncItemFields reliable unordered,
FC GameEntity reliable ordered channel0, inventory Add/Replace ordered1.
Повторять cached FC при equal revision нельзя: это может стереть новый
vanilla rain/refill. Выбран notification → fresh exact-address request,
nonce + неизменившаяся local signature → однократное применение текущего
server snapshot. Расхождение требует нового запроса, не replay старой смеси.
Сохраняем item/container/FC identity; unsupported Colors остаются native,
как и полные изменения состояния cooked beverage finish.

Реализован HCR_FluidSync: bounded fresh requests, nonce/identity/signature guards,
actual vehicle range, порядок native компонентов, rollback при отклонении
снимка. NativeOnly продолжает синхронизировать сосуд после удаления последней
tracked порции, не распространяя ограничения Food на обычную воду.
322 unit / 149 Lua syntax PASS; parse → variant/gaps:5382/3654 RU100%,
78/40,4978/5382 и3588/3654. Read-only review: подтверждённых P1/P2 нет.

Mutation3:start PASS server+owner+observer: четыре native переливания по0,25 л
между двумя вложенными сумками одновременно с очередью переноса четырёх кружек
в наружную сумку. Все ссылки item/container/FC сохранены. Проверены исходный
и целевой primary fluid при равных долях, 307,5cal/0,4375dose на сторону,
опустошение, refill0,7 л Water и обратное переливание0,2 л. Проверки читают raw
metadata, не восстанавливают ledger через capture. Generic96 all11 и Spirits7
all10 PASS на всех трёх процессах. Drinks regression и cold далее.

Первые два запуска исправляли oracle: InventoryItem.getName всегда возвращает
fluid UI-name; native ContainerID не умеет destination во вложенной наземной
сумке (parent=null). Очередь направлена в наружную сумку; жидкости остаются
во вложенных. Это проверяет прежний риск SWAP наружной сумки, не выдаётся за
поддержку native переносов предметов во вложенный destination. Production не
менялся между этими запусками. Пользовательские миры не затрагивались.

Drinks27 all16 PASS на всех трёх процессах. После сохранения и полного
перезапуска: Mutation4 / Generic100 / Spirits9 / Drinks28 cold PASS на сервере
и обоих клиентах, без создания новых fixtures. Сверены старые IDs, native
состав и объём, raw quality/nutrition/poison. Первый Spirits8 cold ожидал19
Whiskey, но считал также помеченный ингредиент следующего Drinks-прогона;
исключён только HCRDrinksMPTag, немеченые дубликаты по-прежнему ловятся.

Proof: fluidsync160-native-pass-* и fluidsync160-cold-pass-* logs всех трёх,
fluidsync160-{native,cold}-{owner,observer}.png; четыре снимка просмотрены.
После native QA production не менялся. Release/push/Workshop не выполнялись.

### 1.6.0: часы партий брожения — основа следующего среза

Добавлены HCR_FermentationClock и сериализуемое поле lot.fermentation.
Длительности берутся из восьми исходных HCR_TimedDefinitions. Начатое
брожение сохраняется при переливании; готовое вино накапливает дальнейший
срок до уксуса в бочке, вне неё часы приостанавливаются без сброса прогресса.
Разные clocks не сливаются в L.mix; L.split сохраняет каждую исходную партию.
Восемь новых проверок: четыре пары точных границ336/672, offline catch-up,
смена тары, отсутствие reset, прежние условия в прошедшем интервале,
rollback, split/mix с точным ядом, повреждённая metadata. Все330 unit PASS.
Read-only review: математических P1/P2 нет; замечание о test loader исправлено
реальным shared package.path в Ledger/QualitySync tests.

Это только расчёт времени и формат metadata: рецепты, миграции и native
изменение состава к новым часам ещё не подключены. Не считать живую
ферментацию реализованной. Следующий шаг — этот runtime и recipes; ответы
по Soy, Methanol и объёму Honey/Rice остаются необходимыми для финала1.6.0.
Проверенный private MP checkpoint: fluidsync160-verified-private.zip.

Clock foundation: 330 unit PASS, 150 Lua5.1 syntax PASS; parse FIRST → variant/gaps unchanged. Private server startup reached SERVER STARTED; dependency load clean apart from existing native map warnings, graceful104:quit and both Java13184/runner5884 gone. Evidence fermentation-clock160-startup-server.log. No gameplay fermentation claim; no push.

### 1.6.0: runtime брожения

B.plan + FluidTransform подключены к Q.capture/store; native состав меняется
без замены FC. Сохранены смесь, порядок, цвета, настройки, sub-pruning trace,
качество/точная доза. Новый20L cask и5 fluid IDs; recipes/migration ещё впереди.
Deviation: native8-component limit требует резерва будущих стадий до смешивания.
Review выявил virtual tap без FC; sourceObject и waterComponents учитывают
водопровод/внешнее очищение до native debit. Исправление подтверждено reviewer.
339 unit,153 Lua syntax PASS; parse FIRST5383/3654 RU100%,variant78/40,
gaps4979/5383,3588/3654. water catalog исключает нативную пустую бочку.

Native4:run PASS сервер-only OnServerStarted (PauseEmpty=true): четыре цепочки,
trace/full, девятый компонент, capture+pour clocks и виртуальный кран без FC.
Ожидаемый отказ крана логирует assert, операция не вызывалась, вода сохранена.
Предыдущие два отказа oracle были форматированием container name и заполнением
trace без headroom, исправлялись только fixtures. Proof в modding-lab:
fermentation160-native-server.log. Graceful110:quit; Java11224/runner24724 gone.
Три private профиля имеют одинаковые файлы; command очищен, клиенты не запускались.
Далее виноградные recipes и legacy migration; Soy/Methanol/Honey-Rice ждут ответов.

### 1.6.0: нативная винодельня

Два juice recipes:16 Food →4L в прежнем ведре; два prepare:20L pure grape
в прежней20L бочке. Один исходный Yeast use, вёдра остаются. B.start связывает
basis с actual litres/units, удерживает worst quality, не перезапускает clock.
Четыре wine/mead/sake bottling и два vinegar recipes используют actual native
20L, сохраняют cask и отдельные clocks. Миграция9 полных бочек,2 вёдер и пустой
бочки берёт timer/quality/dose без выдумывания фруктового питания.
Carpentry output/callback и прочие empty-cask inputs переведены/защищены IsEmpty.
build_fermentation_recipes идемпотентен; convert_water_recipes обновил guards.

Review нашёл taint-loss в Drainable vinegar. Сохранён P-sidecar tainted через
capture/write/keep/consolidate, handcraft/evolved Food и повторную migration.
Review затем поймал ошибочное старое имя setTaintedWater: заменено на реальное
Food.setTainted/isTainted (Food.java2167–2172), включая mock/oracle. Run2 был
отменён до теста, клиент штатно остановлен; production не hot-reloadился.

344 unit PASS, после замены API11 process/taint PASS;156 Lua syntax;
parse FIRST5383/3654 RU100%,78/40,gaps4979/5383,3588/3654. Native SP3 ALL PASS:
81 cask migrations,2 buckets+empty,red/white grape→wine→20 bottles manual/auto,
mead/sake+2 vinegar manual/auto,taint и точная доза в настоящем evolved Sandwich.
Oracle1 дошёл до81+juice/prepare, ошибся ожидая всю пачку Yeast вместо одного
use; исправлен fixture. Backup hcr-fermentation-recipes-before/20261101-092640.zip
(281 files,16.3MB). Proof modding-lab/fermentation-recipes160-native-pass.log+png,
снимок просмотрен. Native SP PID1844 штатно завершён после1002:exit.
MP профили пока остались на core5b86d42! Перед MP стадировать весь common
с одинаковыми hash. Новые recipes/cold MP ещё не проверены; release/push нет.

## 2026-11-01 — native MP винодельни и стойкий Food taint

Предыдущая запись о старом common в MP более не актуальна: все три профиля
сверены побайтово с рабочим common. Backups hcr-fermentation-mp-{server,
owner,observer}-before/20261101-09401*.zip сохранены до новых fixtures.
lab_fermentation_mp: crate capacity100, legacy migration, juice/preparation,
20 wine+20 vinegar bottles, native evolved spice, shared inventory и cold.
Run1: ошибочный assert-return в oracle; run2: реальный taint-loss после
Food full replacement. Run3 ALL10 PASS, run4 cold PASS во всех трёх процессах.

Food.save не сохраняет isTainted (ItemStats сохраняет — проверено review).
Добавлен condition:HCRFoodTaint160, native ingress без sidecar, partial
остатки, отсутствие копирования в пустую тару, передача через handcraft и
evolved. Heating смотрит native cookingTime с baseline, cooked replacements
и serializable cleared tombstone. Отдельный lab_food_taint использует
настоящий Food.update и heated container, не меняет часы/таймер после старта.
Все три горячих случая и cold control PASS, яд/свежесть сохранены.
Event.Add нового oracle при hot reload не исполнялся; заменён на цепочку
существующего lab tick. Production никогда не hot reloadился.

Review final_review без новых P1/P2; chains_audit выявил native-only ingress
и подтвердил безопасный preflight отказ tainted milk/alcohol cooking bowls.
Ingress исправлен и проверен regression. W.snapshot/W.bottledSnapshot/
N.ledger теперь сохраняют state.tainted. Расширенный SpiritsMP11 ALL10 PASS
на сервере и обоих клиентах; run10 остановился до fixture, поскольку игроки
были далеко, observer перенесён штатной private-server teleport командой.
351 unit PASS, 158 Lua5.1 PASS, parse FIRST/RU100%, variant/gaps без регресса.
Cold Spirits12 PASS на сервере и обоих клиентах после завершения прежних
процессов и нового запуска (server16080, owner27256, observer17260).
Прежние ID, объёмы, tainted ledger, дозы, питание и качество сохранены.
Proof food-taint160-spirits-cold-pass-{server,owner,observer}.log и два PNG;
снимки просмотрены. Новых production изменений после 351 unit/audits нет.
Следующий блок — подготовка браги, пивоварение и ожидающие ответы о Soy,
Honey/Rice и Methanol. Публикации 1.6.0 нет.

## 2026-11-01 — получены все открытые решения о рецептурах

Пользователь подтвердил: Soy — те же реальные объёмы, что Milk; Honey/Rice —
20 л с дополнительными 18,5 л воды; новая distillery mash — 20 л с 18,5 л
воды и 336 ч брожения, старые полные бочки уже готовы; Methanol — исходный
способ из готового спиртного плюс нынешнее использование найденных готовых
бочек. Повторные карточки получили одинаковые ответы. Ожидающих решений
по этим четырём вопросам больше нет. Реализация следующих цепочек впереди.

## 2026-11-01 — надписи на native сосудах

HCR_ItemNames.custom: modData.customName > getDisplayName > архив. Native
SyncItemFieldsPacket.setData использует getName (FC UI); processClient сначала
ставит это private name, затем processModData восстанавливает исходную надпись.
Primary CFR reference сохранён снаружи repo как
modding-lab/SyncItemFieldsPacket-review.java. copyState + Water/Drink/Fermentation
archives используют helper; FluidTooltip показывает надпись и у пустого FC.
357 unit PASS, шесть names regressions, 161 Lua5.1 files PASS.

Names1: metadata PASS, визуальный FAIL кириллицы. Причина в oracle literals:
LuaManager/IndieFileLoader UTF8 Reader → LuaCompiler → LexState.save(int)
byte cast → newstring UTF8. Не gsub! Исправлен источник fixture на native
getFileReader UTF8 HCRLabNamesLabels.txt. Names2 был слишком рано для второго
игрока, fixture не создан; Names3 PASS server+owner+observer, оба screenshot
просмотрены, русские надписи читаются. Найдены и устранены все3 non-ASCII
production literals (разделитель dot в FluidTooltip/FoodQualityTooltip).
Cold с окончательными ASCII-разделителями выполняется далее. Runner4380,
server19056, owner22796, observer23728; все9 lab oracle частей стадированы
одинаково на3profiles, common hashes сверены.

Names4 cold PASS на сервере и обоих клиентах, прежние5 ID/объёмы/надписи.
Окончательные подсказки просмотрены на2PNG: Unicode иразделители корректны.
Proof names160-cold-pass-{server,owner,observer}.log иowner/observer.png.
ParseFIRST5383/3654,RU100%,variant78/40,gaps4979/5383,3588/3654.
Декомпиляция иprofiles остаются снаружи repo; публикации нет.

Следующая согласованная работа: Soy9canonical вместо18дублирующихся рецептов,
сохранить2cocktailcompose .35/1.1L; concentrate через существующий Dilute.
Read-only audit обнаружил partial can: addFood всегда даёт.3L дажеhalfcan.
Исправить на actual output .7+.3*remaining (сегодня ещё НЕ реализовано).
Не расширять dairy/cheese на Soy автоматически. Затем Honey/Rice, distill,
Methanol, новая brewery, общий release. Полные audit-ответы агентов в чате.


## 2026-11-01 — единые молочные рецепты, проверка перед коммитом

Девять Food-OR/native пар объединены под прежними canonical именами. Обучение
книгами дедуплицировано, старые bodies сохранены в milk_fluid_migrations.json.
Готовое HCRMilkSoy принимает тот же объём: 0,2 л в какао, 0,1 л в остальных
семи рецептах. Eggnog/Monkey Tail продолжают HCRBarDrinks.create с выходом
0,35/1,1 л и реальным питанием ингредиентов. Dairy/cheese на Soy не расширены.
repair_milk_fluids учитывает supersession, generators повторяются без diff.

Dilute Evaporated Milk: выход .7 + .3 * rawHunger/baseHunger, свойства текущего
остатка без повторного масштабирования, один пустой tin возвращается native
script output. Обнаружен native крайний случай: 1% остатка Food имеет0 uses,
но ItemCount всё ещё расходует сам предмет. variableYield больше не требует
положительного целого uses. Новая unit regression моделирует именно0 uses.
В какао и rice pudding теперь нужна пустая посуда, полный сосуд не исчезает.

360 unit PASS, 162 Lua5.1 PASS. ParseFIRST5383/3645,RU100%,1370taught,
variant/gaps выполнены. Первый SP run выявил0-use край; исправлен после
остановки процесса, production hot reload не использовался. run2 прошёл
54+8+4 случая; run3 прошёл те же проверки на окончательном варианте,
включая ровно1 empty tin. Proof soy-unified160-native-pass.log; предыдущая
ошибка сохранена в soy-unified160-small-can-failure.log. Cold и MP ещё идут.

Отдельный read-only audit chains_audit: distillery readyMash должен сохранять
исходные budgets на336h transition, без преждевременного превращения
nutrition в Vodka. Новые clock kinds отделить от8 legacy ready barrel IDs;
terminal readyMash не превращается в уксус. Cooked pots переносятся как
.5L * actual remaining в Base.Pot, Fill расходует1.5L+18.5L Water и kept cask.
Original Methanol1L whitelist15 sourceFoods сохраняется после переливания;
found LemonFermented остаётся5outputs без нового lemon timer.

Milk slice завершён: SP cold run4 сохранил16 cartons; native tooltip screenshot
soy-unified160-cold-pass.png просмотрен. MP run21 остановился на floor-bag
transfer; приватное хранилище заменено штатным furniture crate100, production
не менялся. Run22 все18 phases PASS на сервере/владельце/наблюдателе. После
остановки всех трёх процессов и повторного запуска run23 cold PASS независимо
на всех трёх; dilute .85L/173cal/.625 poison/rotten/tainted, ID сохранён.
Логи soy-unified160-mp-{server,owner,observer}-pass.log и
soy-unified160-mp-{server,owner,observer}-cold.log. Финальные parse FIRST,
variant/gaps выполнены; 5383 items/3645 recipes, RU100%, 4979/3579 reachable.

### 2026-11-01 — нативная брага, согласованные 20 л и 336 часов

HCR_MashCatalog генерирует десять cooked/raw семейств, десять fills,
восемь active→ready часов и девять потребителей дистилляции. Legacy восемь
Normal бочек становятся немедленно готовыми, новые ready stages терминальны.
Fill сохраняет cask и донорские Pot, расходует1.5L mash+18.5L чистой Water.
FluidRecipeQuality снимает nativeWater только подходящего slot и учитывает
фактический расход; одна вода не захватывается повторно через другие inputs.
29 исходных bodies сохранены из f95da9a, unit проверяет инварианты рецептур.

Native Food.ReplaceOnCooked создавал pristine cooked Food и терял остаток,
nutrition/poison; raw OnCooked теперь сохраняет реальные поля и worst quality,
после чего inventory migration переносит .5L*remaining в Base.Pot. Старые
cooked Food не требуют isCooked=true. Native Food.update очищает water taint,
индивидуальный яд не обнуляется; сроки cooked prototypes сохранены.

368 unit PASS,166 Lua5.1 PASS. Native SP run3:30 legacy cooked full/half/1%,
8 immediate ready casks,20 manual/auto fills,18 distillations,4 Mead/Sake
bottlings PASS. Heat4:20 half-raw native cooks (fresh/rotten), actual6min
fixture cookTime, no world-clock/cookingTime injection, cold control PASS.
Cold5/270:99 mash samples+20 heated samples PASS. В bottled Mead/Sake часы
уксусной выдержки приостановлены: oracle теперь сравнивает elapsed, а не
подвижный startedAt. Native clock сам не исправлялся.

Два первых SP сбоя были в oracle: авто расходует общий запас cooling Water;
две Agave-перегонки должны получать по одному подходящему cask, иначе auto
законно выбирает другой. MP1: Lua assert возвратил также message в manual
input list; private get теперь скобками ограничен одним result. MP2: все
6 phases PASS server/owner/observer, включая native timed actions,6 halfpots,
18.5Lwater,336h transition,20Vodka outputs, transfer, no duplicates. MP cold
ещё выполняется. Production не hot-reload; менялся только private oracle.
Read-only final_review: actionable P1/P2 не найдено.

Proof: private lab/mash160-native-pass.log, mash160-cold-pass.log/png,
mash160-mp-{server,owner,observer}-pass.log/png; исходные failures сохранены.
ParseFIRST5383/3645,RU100%,1370taught; variant/gaps:4979/3579 reachable.
Генератор повторяется без diff после устранения накопления пустых строк.

MP3 cold: после полного выхода/перезапуска сервера и двух клиентов все три
независимо PASS.20 бутылок с прежними ID, остатки Water1.5/0L,6 пустых Pot,
тот же cask, точные calories/dose/taint/rotten. Proof mash160-mp-*-cold.log.


## Восстановленный метанол — 1 ноября

Make Methanol использует 1 л чистого разрешённого спиртного: 15 исходных
видов Vodka/Whiskey/Rum/Gin/Sake. Сохранены Cooking7, время100, уголь и
розжиг; допускаются переносная и установленная перегонные установки.
Из 1,5 л остаётся 0,5 л с пропорциональными питанием и дозой. Найденная
готовая лимонная бочка даёт прежние пять бутылок без повторной выдачи
callback. Неработающее Fill Barrel with Lemon Mash удалено, legacy ID
сохранены; выдуманного времени созревания лимонной браги нет.

370 unit PASS,168 Lua5.1 PASS; parse FIRST5383/3645,RU100%, reachable4978/3579.
Генератор повторяется без diff. Native SP:30 ручных/автоматических вариантов,
две установки, найденные бочки и четыре запрещённых вида PASS; cold SP PASS.
Native MP run6: все восемь фаз PASS на сервере и двух клиентах, включая
передачу результата и точный остаток. Холодный MP этого расширенного
сценария НЕ выполнен: тестовые процессы закрыты для передачи компьютера.
Предыдущие сбои MP были ошибкой fixture с уже израсходованным углём;
новая операция получает отдельный уголь и розжиг. Production не hot-reload.

Proof private lab: methanol160-native-pass.log, methanol160-cold-pass.log,
methanol160-mp-{server,owner,observer}-pass.log. Read-only review: P1/P2 нет.

**English:** The original alcohol-to-methanol recipe is restored with measured
native input and preserved remainder. Found legacy casks remain usable without
duplicate outputs. SP and the eight-phase two-client/server workflow pass;
the methanol multiplayer cold restart remains an explicit handoff task.

## Продолжение на втором ПК — 1 ноября 2026

Ветка `codex/release-1.6.0` от GitHub brewery snapshot `16196f9`.
Universal-modder подтвердил установленный Steam Project Zomboid 42.21.0;
частная лаборатория находится в `C:\HCRLab`, пользовательские сохранения
не изменяются. ASCII worktree нужен для Lua 5.1 require через Lupa на Windows.
Начальный прогон: 374 unit PASS; parse 5384 items / 3647 recipes / RU 100%.

Новый `tools/lab_brewery.lua`: настоящие Prepare Wheat Wort (manual/auto),
отказ для сырого, 18 комбинаций остатка и свежести, ровно одна native порция
дрожжей и одна кастрюля. Нагрев в игровом ItemContainer при штатных 60/120
минутах (без изменения cookingTime/world time): приготовление и подгорание
PASS, холодный контроль остался сырым. Разновозрастные партии, native
переливание, точная доза/объём, 168h и запрет брендовых шестипаков PASS.
Хмель: native createSpecificIcon и ISForageAction.complete с реальной выдачей
предметов, skill/season filters PASS (это не статистический тест распределения).
22 образца сохранены для холодной проверки; она пока не завершена.
Proof: private `C:\HCRLab\brewery-sp-pass.log`.

На первом старте нового профиля игра сбрасывает default.txt: после создания
version.txt моды включены повторно и выполнен новый запуск. Подготовлены
loopback server + HCRLabOwner + HCRLabObserver, отдельные credentials.
Один owner и один observer процесс завершились с native GLFW access violation
в Display.processMessages до испытаний. Исходные crash logs сохранены;
параметры GC приведены к bundled Windows launcher (ZGC), проверка продолжается.
Production Lua не hot-reload; лабораторный bridge и fixtures не входят в common.

## Завершение проверок 1.6.0 — 1 ноября 2026

На втором ПК закрыты все игровые пункты handoff: SP-пивоварение (22 cold
образца), MP-пивоварение (9 фаз), брага/метанол (8 фаз), выгрузка участка и
полный перезапуск сервера с обоими клиентами. Общая MP-интеграция: 11 фаз.
Настоящий мир 1.5.12: 377 legacy типов перенесены, затем 377 cold-проверок
подтвердили новые ID и отсутствие повторной миграции. 374 unit PASS.
Исправлен manifest pack=hcBuilding2x; cold native texture lookup PASS.
Версия и русско-английская документация приведены к 1.6.0. Подробности,
ограничения и имена локальных доказательств: docs/FLUIDS_1_6_STATUS.md.
Проверка пакета дополнительно выявила пять точных копий ванильных mesh:
заменены ссылками на установленную игру. 741 model reference без пропусков;
повторно 374 unit PASS, новый игровой процесс с native model requests и
экипированным Alice pack PASS. Оба mod.info синхронизированы.

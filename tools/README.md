# Инструменты аудита / Audit tools

- `import_clean_plants.py` — импорт новых RGBA растений fal на исходные ящики:
  сначала `--raw PRIVATE/fal-clean-plants-v2 --out PRIVATE/review`, после проверки
  `--apply`; не генерирует и не загружает файлы в сеть.
- `fit_planter_icons.py` — точные исходные ящики hcBuilding2x для восьми новых
  состояний растений; `--check` проверяет размер, пиксели и посадку, `--apply`
  обновляет проверенные файлы. См. docs/PLANTER_SCALE.md.

- `setup_dev.py` — подготовка машины: ссылка `pz-lua` на Lua игры, `.venv`
  с openpyxl и Pillow, проверка lua-language-server. `--check` — только
  диагностика, ненулевой код возврата, если чего-то не хватает.
- `hcr_paths.py` — общие пути и поиск установки игры (сам ничего не делает).
- `parse_hcr.py` — парсер скриптов мода в model.json (предметы, рецепты, книги).
- `variant_b.py` — анализ достижимости: недостижимые предметы и некрафтуемые рецепты
  (моделирует лут-lua, фермерство, ReplaceOn*-цепочки). Запускать перед каждым релизом.
- `analyze_gaps.py` — расширенный отчёт с битыми ссылками.
- `weapon_models.py` — разрешение `WeaponSprite` в реальные модели B42; отдельно
  проверяется отображение предметов в мире.
- `test_playability.py` и `test_food_callbacks.py` — Lua 5.1 регрессии репортов
  сообщества; требуют lupa в отдельном dev-окружении.
- `lab_smoke.lua` и `lab_crafting.lua` — реальные проверки 42.21, только для
  отдельного HCRLab и отдельного cachedir. В релизную папку не копировать.
- `clothing_guids.py` — регистрация XML одежды с их исходными GUID.
- `audit_lua_item_ids.py` — неподтверждённые literal IDs; отчёт требует проверки
  достижимости callback и намеренно удалённых legacy систем.
- `make_icon.py` — иконки для новых предметов: перекраска в другой материал,
  сборка «предмет в коробке», приведение сторонней картинки к палитре мода,
  аудит ссылок на иконки. Требует Pillow.
  Список недостающих иконок с промптами — в [docs/ICON_PROMPTS.md](../docs/ICON_PROMPTS.md).
- `build_xlsx.py` / `gen_flowcharts.py` — генерация docs/HCR_Database.xlsx и docs/FLOWCHARTS.md.
- `repair_food_counts.py`, `repair_physical_containers.py`, `repair_liquid_inputs.py`,
  `repair_milk_fluids.py`, `repair_petrol_containers.py` — воспроизводимые миграции
  потребления; проверенные строки и исходные количества записаны в JSON manifests.
  Поддерживаемый `--check` проверяет результат без повторной правки.
- `audit_world_models.py` — проверка native ссылок моделей, meshes и текстур.
- `export_asset_provenance.py`, `generate_silicon_icon.py`, `import_spike_trap.py` —
  переносимое происхождение ассетов и воспроизводимая обработка; сырые fal файлы
  хранятся вне мода. Генератор кремния повторно использует существующий raw.
- `lab_liquids.lua`, `lab_milk.lua`, `lab_petrol_containers.lua`, `lab_packaging.lua`,
  `lab_progression.lua`, `lab_input_tags.lua`, `lab_boxing.lua` — отдельные native сценарии только
  для частного HCRLab. Само наличие harness не означает успешный игровой прогон;
  подтверждённые результаты фиксируются в отчёте доводки.
- `package_preview.py --out <новый внешний каталог>` — неопубликованная сборка
  с раскладкой `common/42`, документами и проверкой относительных ссылок.
  Python/Lua лабораторные инструменты и сырые материалы в пакет не включаются.

Порядок: `parse_hcr.py` → остальное (модель кладётся рядом со скриптом).

## Диагностика парсера

`parse_hcr.py` печатает и число уникальных сущностей, и число определений:
`items=5196 (определений 5204)` означает 8 переопределений — один и тот же
предмет объявлен дважды, движок оставит последнее по алфавиту файлов, остальные
молча пропадут. Список пар (файл:строка) уходит в stderr и в модель
(`dup_items` / `dup_recipes`) — сверяйтесь при каждом релизе.

## Пути

Корень репозитория инструменты вычисляют сами. Каталог установки Project Zomboid —
нужен для списка ванильных предметов и их переводов — ищется так:

1. аргумент `--game <путь>` (или `--game=<путь>`);
2. переменная окружения `PZ_GAME_DIR`;
3. типовые места установки Steam (Windows / Linux / macOS).

```sh
python3 tools/parse_hcr.py --game "C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid"
PZ_GAME_DIR="~/.steam/steam/steamapps/common/ProjectZomboid" python3 tools/variant_b.py
```

На Windows `media/` лежит прямо в каталоге игры, на Linux и macOS — во вложенном
`projectzomboid/`. Обе раскладки есть в списке автопоиска, и обе принимаются
в `--game`/`PZ_GAME_DIR`: указать можно как внешний каталог, так и вложенный.

`variant_b.py` и `analyze_gaps.py` без игры не работают (не с чем сверять ванильные
предметы). `parse_hcr.py` отработает и без неё, но предупредит: в модели не будет
ванильных названий, и генераторы документации откажутся писать в `docs/`, чтобы
не подменить русские подписи идентификаторами (`Stone2` вместо «Камень»).
Осознанный обход — флаг `--allow-missing-vanilla`.

## Зависимости

Python 3.8+; `build_xlsx.py` требует `openpyxl`, `make_icon.py` — `Pillow`.
Остальные скрипты — только стандартная библиотека.

Ставит их `setup_dev.py`. Если в системном Python их нет (на Arch и других
дистрибутивах с externally-managed окружением их там и не будет), он заводит
`tools/.venv` — тогда эти два скрипта запускаются через `tools/.venv/bin/python`.

## Проверка Lua

`.luarc.json` в корне репозитория настраивает lua-language-server. Ванильный
API он берёт из `pz-lua` — ссылки на `media/lua` игры, которую заводит
`setup_dev.py`. Разовый прогон:

```sh
lua-language-server --check=. --configpath=.luarc.json --checklevel=Warning
```

Сейчас на моде 18 диагностик, все настоящие. Новые движковые глобали
дописываются в `diagnostics.globals` — функции самого мода туда не попадают,
их отсутствие означает битую ссылку.

Промежуточные файлы (`model.json`, `gaps_*.txt`, `no_source.json`,
`icon_audit.txt`), `.venv/` и ссылка `pz-lua` не версионируются.

# Инструменты аудита / Audit tools

- `hcr_paths.py` — общие пути и поиск установки игры (сам ничего не делает).
- `parse_hcr.py` — парсер скриптов мода в model.json (предметы, рецепты, книги).
- `variant_b.py` — анализ достижимости: недостижимые предметы и некрафтуемые рецепты
  (моделирует лут-lua, фермерство, ReplaceOn*-цепочки). Запускать перед каждым релизом.
- `analyze_gaps.py` — расширенный отчёт с битыми ссылками.
- `build_xlsx.py` / `gen_flowcharts.py` — генерация docs/HCR_Database.xlsx и docs/FLOWCHARTS.md.

Порядок: `parse_hcr.py` → остальное (модель кладётся рядом со скриптом).

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

`variant_b.py` и `analyze_gaps.py` без игры не работают (не с чем сверять ванильные
предметы). `parse_hcr.py` отработает и без неё, но предупредит: в модели не будет
ванильных названий, и генераторы документации откажутся писать в `docs/`, чтобы
не подменить русские подписи идентификаторами (`Stone2` вместо «Камень»).
Осознанный обход — флаг `--allow-missing-vanilla`.

## Зависимости

Python 3.8+; `build_xlsx.py` дополнительно требует `openpyxl`
(`pip install openpyxl`). Остальные скрипты — только стандартная библиотека.

Промежуточные файлы (`model.json`, `gaps_*.txt`, `no_source.json`) не версионируются.

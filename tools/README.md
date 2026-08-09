# Инструменты аудита / Audit tools

- `parse_hcr.py` — парсер скриптов мода в model.json (предметы, рецепты, книги).
- `variant_b.py` — анализ достижимости: недостижимые предметы и некрафтуемые рецепты
  (моделирует лут-lua, фермерство, ReplaceOn*-цепочки). Запускать перед каждым релизом.
- `analyze_gaps.py` — расширенный отчёт с битыми ссылками.
- `build_xlsx.py` / `gen_flowcharts.py` — генерация docs/HCR_Database.xlsx и docs/FLOWCHARTS.md.

Порядок: parse_hcr.py -> variant_b.py (модель кладётся рядом со скриптом).

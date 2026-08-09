# -*- coding: utf-8 -*-
"""model.json -> docs/FLOWCHARTS.md (Mermaid: обучение + межкатегорийные потоки + глубокие цепочки)."""
import json, re
from pathlib import Path
from collections import defaultdict, Counter

HERE = Path(__file__).parent
M = json.loads((HERE / "model.json").read_text(encoding="utf-8"))
items, recipes = M["items"], M["recipes"]
ru_items, ru_recipes = M["ru_items"], M["ru_recipes"]
van_ru = M["van_ru"]
book_teaches, producers, consumers = M["book_teaches"], M["producers"], M["consumers"]

def ru_item(fid):
    return ru_items.get(fid) or van_ru.get(fid) or fid.split(".", 1)[-1]

ITEM_LINE = re.compile(r'^item\s+(\d+)\s+(.*)$')
def ids_of(lines):
    ids = []
    for line in lines:
        m = ITEM_LINE.match(line)
        if not m: continue
        rest = m.group(2).strip()
        if rest.startswith("tags["): continue
        lm = re.match(r'^\[([^\]]*)\]', rest)
        ids += [x.strip() for x in lm.group(1).split(";")] if lm else [rest.split()[0]]
    return [i for i in ids if i]

# ---------- 1. Обучение: семейства книг -> категории рецептов ----------
FAMILY = {
    "Books.txt": "Учебники",
    "HCR_Cookbooks.txt": "Кулинарные книги",
    "HCR_Blueprints.txt": "Чертежи",
    "HCR_Tablets.txt": "Планшеты и исследования",
}
fam_edges = Counter()   # (family, recipe_cat) -> n
fam_books = Counter()
for rn, books in book_teaches.items():
    cat = recipes.get(rn, {}).get("cat") or "Прочее"
    for b in books:
        fam = FAMILY.get(items.get(b, {}).get("file", ""), "Прочие источники")
        fam_edges[(fam, cat)] += 1
for b in {b for bl in book_teaches.values() for b in bl}:
    fam_books[FAMILY.get(items.get(b, {}).get("file", ""), "Прочие источники")] += 1

_NID = {}
def nid(s):  # безопасный уникальный id узла
    if s not in _NID:
        _NID[s] = f"n{len(_NID)}"
    return _NID[s]

learn = ["flowchart LR"]
for fam, cnt in sorted(fam_books.items()):
    learn.append(f'    {nid(fam)}["📚 {fam}<br/>{cnt} шт."]')
cats = sorted({c for (_, c) in fam_edges})
for c in cats:
    total = sum(n for (f, cc), n in fam_edges.items() if cc == c)
    learn.append(f'    {nid("cat"+c)}("{c}<br/>{total} рец.")')
for (fam, cat), n in sorted(fam_edges.items(), key=lambda kv: -kv[1]):
    if n >= 2:
        learn.append(f'    {nid(fam)} -->|{n}| {nid("cat"+cat)}')
learn_mmd = "\n".join(learn)

# ---------- 2. Потоки крафта между категориями ----------
cat_edges = Counter()
for r in recipes.values():
    outs = ids_of(r["outputs"])
    dst_cats = {recipes[c]["cat"] or "Прочее" for o in outs for c in consumers.get(o, []) if c != r["name"]}
    for dc in dst_cats:
        sc = r["cat"] or "Прочее"
        if sc != dc:
            cat_edges[(sc, dc)] += 1

flow = ["flowchart LR"]
used = set()
for (a, b), n in sorted(cat_edges.items(), key=lambda kv: -kv[1]):
    if n < 8: continue
    for c in (a, b):
        if c not in used:
            used.add(c)
            flow.append(f'    {nid("f"+c)}("{c}")')
    flow.append(f'    {nid("f"+a)} -->|{n}| {nid("f"+b)}')
flow_mmd = "\n".join(flow)

# ---------- 3. Самые глубокие цепочки (предметы) ----------
# ребро: item -> item через рецепт; только РАСХОДУЕМЫЕ входы, OR-списки не длиннее 4
def chain_ids(lines):
    ids = []
    for line in lines:
        m = ITEM_LINE.match(line)
        if not m: continue
        rest = m.group(2).strip()
        if rest.startswith("tags[") or "mode:keep" in rest: continue
        lm = re.match(r'^\[([^\]]*)\]', rest)
        cur = [x.strip() for x in lm.group(1).split(";")] if lm else [rest.split()[0]]
        if len(cur) > 4: continue
        ids += cur
    return [i for i in ids if i]

edge_via = {}
succ = defaultdict(set)
for r in recipes.values():
    ins, outs = chain_ids(r["inputs"]), ids_of(r["outputs"])
    for i in ins:
        for o in outs:
            if i != o and o not in succ[i]:
                succ[i].add(o)
                edge_via[(i, o)] = r["name"]

import sys
sys.setrecursionlimit(100000)
memo = {}
onpath = set()
def longest(v, depth=0):
    if v in memo: return memo[v]
    if v in onpath or depth > 40: return (0, [v])
    onpath.add(v)
    best = (0, [v])
    for w in succ.get(v, ()):
        l, p = longest(w, depth + 1)
        if l + 1 > best[0]:
            best = (l + 1, [v] + p)
    onpath.discard(v)
    memo[v] = best
    return best

chains = sorted((longest(i) for i in list(succ)), key=lambda t: -t[0])[:600]
# отобрать непересекающиеся показательные цепочки; повторы подряд склеить, длину ограничить
def clean(path):
    out = [path[0]]
    for x in path[1:]:
        if x != out[-1]:
            out.append(x)
    return out[:14]

picked, seen_items = [], set()
for l, path in chains:
    if l < 5: break
    p = clean(path)
    if len(set(p) & seen_items) > len(p) // 4: continue
    picked.append(p); seen_items |= set(p)
    if len(picked) == 6: break

chain_blocks = []
for k, path in enumerate(picked, 1):
    g = ["flowchart LR"]
    for idx, it in enumerate(path):
        g.append(f'    c{k}_{idx}["{ru_item(it)}"]')
    for idx in range(len(path) - 1):
        rn = edge_via.get((path[idx], path[idx+1]), "")
        label = (ru_recipes.get(rn) or rn).split(" (")[0]
        g.append(f'    c{k}_{idx} -->|"{label}"| c{k}_{idx+1}')
    chain_blocks.append("\n".join(g))

md = f"""# Карта крафта и обучения / Craft & Learning Flowcharts

*Автогенерация из скриптов мода (v1.5.0): {len(items)} предметов, {len(recipes)} рецептов,
{len({b for bl in book_teaches.values() for b in bl})} книг и чертежей. Полные данные — в [HCR_Database.xlsx](HCR_Database.xlsx).*

*Auto-generated from the mod scripts (v1.5.0). Full data in [HCR_Database.xlsx](HCR_Database.xlsx).*

## 1. Обучение: откуда берутся рецепты / Learning map

Семейства обучающих предметов и категории рецептов, которым они учат
(на стрелках — число рецептов; связи реже 2 рецептов скрыты).

```mermaid
{learn_mmd}
```

## 2. Потоки крафта между категориями / Cross-category craft flows

Стрелка «A → B» означает: результаты рецептов категории A служат ингредиентами
рецептов категории B (на стрелке — число таких рецептов; связи реже 8 скрыты).

```mermaid
{flow_mmd}
```

## 3. Самые глубокие производственные цепочки / Deepest craft chains

Показательные цепочки предметов (подписи на стрелках — рецепты).

"""
for k, block in enumerate(chain_blocks, 1):
    md += f"### Цепочка {k} ({len(picked[k-1])} звеньев)\n\n```mermaid\n{block}\n```\n\n"

out = Path(r"C:\Users\Игорь\projects\HydrocraftReinvented\docs\FLOWCHARTS.md")
out.write_text(md, encoding="utf-8")
print("saved", out)
print("learn edges:", sum(1 for l in learn if '-->' in l), "| flow edges:", sum(1 for l in flow if '-->' in l))
print("chains:", [len(p) for p in picked])

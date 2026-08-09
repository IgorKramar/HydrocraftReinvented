# -*- coding: utf-8 -*-
"""Вариант B: урожай/семена (динамическая lua-склейка) считаем достижимыми."""
import json, re
from pathlib import Path
from collections import Counter

HERE = Path(__file__).parent
M = json.loads((HERE / "model.json").read_text(encoding="utf-8"))
items, recipes = M["items"], M["recipes"]
ru_items, van_ru = M["ru_items"], M["van_ru"]
book_teaches = M["book_teaches"]

REPO = Path(r"C:\Users\Игорь\projects\HydrocraftReinvented")
GAME = Path(r"C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid")

def read_text(p):
    for enc in ("utf-8-sig", "utf-8", "cp1252"):
        try: return p.read_text(encoding=enc)
        except UnicodeDecodeError: continue
    return p.read_text(encoding="utf-8", errors="replace")

def ru(fid): return ru_items.get(fid) or van_ru.get(fid) or fid

van_items = set()
for f in (GAME / "media/scripts").rglob("*.txt"):
    module = "Base"
    for line in read_text(f).splitlines():
        m = re.match(r'^\s*module\s+(\w+)', line)
        if m: module = m.group(1); continue
        m = re.match(r'^\s*item\s+(\S+)\s*$', line)
        if m: van_items.add(f"{module}.{m.group(1)}")

lua_strings = set()
for f in (REPO / "common/media/lua").rglob("*.lua"):
    for m in re.finditer(r'"([A-Za-z0-9._\- ]{2,64})"|\'([A-Za-z0-9._\- ]{2,64})\'', read_text(f)):
        lua_strings.add((m.group(1) or m.group(2)).strip())

def in_lua(fid):
    short = fid.split(".", 1)[-1]
    return fid in lua_strings or short in lua_strings

FARM_FILES = {"HCR_Gardening.txt", "HCR_Seeds.txt", "HCR_Seeds ND.txt", "HCR_Trees.txt"}
reachable = set(van_items)
for fid, it in items.items():
    if in_lua(fid) or it["file"] in FARM_FILES:
        reachable.add(fid)
# урожай фермерства: PlantsGrowing.lua строит имена как HC<X> из семян HC<X>seeds
for fid in list(items):
    m = re.match(r'^Hydrocraft\.HC(.+)seeds$', fid)
    if m:
        crop = "Hydrocraft.HC" + m.group(1)
        if crop in items:
            reachable.add(crop)
        # заглавная форма (plantName:upper() первой буквы)
        crop2 = "Hydrocraft.HC" + m.group(1)[:1].upper() + m.group(1)[1:]
        if crop2 in items:
            reachable.add(crop2)
# altName-продукты урожая из PlantsGrowing.lua (точные строки altName = "X")
pg = (REPO / "common/media/lua/client/PlantsGrowing.lua").read_text(encoding="utf-8", errors="replace")
for m in re.finditer(r'altName\s*=\s*"([A-Za-z]+)"', pg):
    for cand in ("Hydrocraft.HC" + m.group(1), "Base." + m.group(1), "farming." + m.group(1)):
        if cand in items or cand in van_items:
            reachable.add(cand)

ITEM_LINE = re.compile(r'^item\s+(\d+)\s+(.*)$')
def groups_of(lines, consumed_only=False):
    out = []
    for line in lines:
        m = ITEM_LINE.match(line)
        if not m: out.append((0, None, line)); continue
        rest = m.group(2).strip()
        if consumed_only and "mode:keep" in rest: continue
        if rest.startswith("tags["): out.append((int(m.group(1)), None, rest)); continue
        lm = re.match(r'^\[([^\]]*)\]', rest)
        ids = [x.strip() for x in lm.group(1).split(";")] if lm else [rest.split()[0]]
        ids = [i for i in ids if i]
        out.append((int(m.group(1)), None if "*" in ids else ids, rest))
    return out

def outputs_ids(r):
    ids = []
    for cnt, lst, raw in groups_of(r["outputs"]): ids += lst or []
    return ids

craftable, changed = set(), True
while changed:
    changed = False
    # ReplaceOnDeplete/Use/Cooked: достижимый источник порождает замену
    for fid, it in items.items():
        if fid in reachable:
            for rp in it.get("repl", []):
                if rp in items and rp not in reachable:
                    reachable.add(rp); changed = True
    for r in recipes.values():
        if r["name"] in craftable: continue
        ok = all(lst is None or any(i in reachable for i in lst)
                 for cnt, lst, raw in groups_of(r["inputs"], consumed_only=True))
        if ok:
            craftable.add(r["name"])
            for o in outputs_ids(r):
                if o not in reachable: reachable.add(o); changed = True

uncraftable = [r for r in recipes.values() if r["name"] not in craftable]
unreachable = [f for f in items if f not in reachable]
no_source = [f for f in unreachable if not M["producers"].get(f)]

root = Counter()
for r in uncraftable:
    for cnt, lst, raw in groups_of(r["inputs"], consumed_only=True):
        if lst and not any(i in reachable for i in lst):
            for i in lst: root[i] += 1

file_unreach = Counter(items[f]["file"] for f in unreachable)
lines = []
lines.append(f"ВАРИАНТ B (фермерство достижимо): недостижимых предметов {len(unreachable)} "
             f"(без источника {len(no_source)}), некрафтуемых рецептов {len(uncraftable)}")
lines.append("\nТоп файлов по недостижимым:")
for f, n in file_unreach.most_common(15): lines.append(f"  {n:4}  {f}")
lines.append("\nТоп-40 корневых блокеров:")
for i, n in root.most_common(40): lines.append(f"  {n:4}  {i} — {ru(i)}")
lines.append("\nКниги недостижимы: " + ", ".join(sorted(b for b in {b for bl in book_teaches.values() for b in bl} if b not in reachable)))
out = HERE / "gaps_variant_b.txt"
out.write_text("\n".join(lines), encoding="utf-8")
# полный дамп безысточниковых для лут-генератора
from collections import defaultdict as dd
by_file = dd(list)
for f in no_source:
    by_file[items[f]["file"]].append({"id": f, "en": items[f]["en"], "ru": ru(f), "cat": items[f]["cat"], "type": items[f]["type"]})
(HERE / "no_source.json").write_text(json.dumps(by_file, ensure_ascii=False, indent=1), encoding="utf-8")
print("\n".join(lines[:60]))

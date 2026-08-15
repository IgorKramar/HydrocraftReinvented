# -*- coding: utf-8 -*-
"""Поиск пробелов: недостижимые предметы, некрафтуемые рецепты, битые ссылки."""
import re
from collections import defaultdict

from hcr_paths import HERE, LUA, find_game, load_model, read_text

M = load_model()
items, recipes = M["items"], M["recipes"]
ru_items, ru_recipes, van_ru = M["ru_items"], M["ru_recipes"], M["van_ru"]
book_teaches = M["book_teaches"]

GAME = find_game()

def ru(fid):
    return ru_items.get(fid) or van_ru.get(fid) or fid

# ---------- ванильные предметы (полный список из скриптов игры) ----------
van_items = set()
for f in (GAME / "media/scripts").rglob("*.txt"):
    txt = read_text(f)
    for mm in re.finditer(r'^\s*module\s+(\w+)|^\s*item\s+(\S+)\s*$', txt, re.M):
        pass
    module = "Base"
    for line in txt.splitlines():
        m = re.match(r'^\s*module\s+(\w+)', line)
        if m: module = m.group(1); continue
        m = re.match(r'^\s*item\s+(\S+)\s*$', line)
        if m: van_items.add(f"{module}.{m.group(1)}")
print("vanilla items:", len(van_items))

# ---------- 1. Битые ссылки ----------
ITEM_LINE = re.compile(r'^item\s+(\d+)\s+(.*)$')
def groups_of(lines, consumed_only=False):
    """[(count, [ids] | None(tags/fluid), raw)]"""
    out = []
    for line in lines:
        m = ITEM_LINE.match(line)
        if not m:
            out.append((0, None, line)); continue
        rest = m.group(2).strip()
        if consumed_only and "mode:keep" in rest:
            continue
        if rest.startswith("tags["):
            out.append((int(m.group(1)), None, rest)); continue
        lm = re.match(r'^\[([^\]]*)\]', rest)
        ids = [x.strip() for x in lm.group(1).split(";")] if lm else [rest.split()[0]]
        ids = [i for i in ids if i]
        if "*" in ids:  # wildcard «любой предмет» (обычно с flags/fluid) — не ограничение
            out.append((int(m.group(1)), None, rest))
        else:
            out.append((int(m.group(1)), ids, rest))
    return out

def exists(fid):
    if fid in items or fid in van_items: return True
    # HCR пишет иногда без модуля? или Base-алиасы
    if "." not in fid: return ("Hydrocraft." + fid) in items or ("Base." + fid) in van_items
    return False

broken = []  # (recipe, id, where)
for r in recipes.values():
    for where, lines in (("вход", r["inputs"]), ("выход", r["outputs"])):
        for cnt, ids, raw in groups_of(lines):
            for i in ids or []:
                if not exists(i):
                    broken.append((r["name"], i, where))

# ---------- 2. Книги: висячие ссылки и недостижимые книги ----------
dangling_books = sorted(set(book_teaches) - set(recipes))

# ---------- 3. Источники вне крафта: все строковые литералы из lua ----------
lua_strings = set()
for f in LUA.rglob("*.lua"):
    txt = read_text(f)
    for m in re.finditer(r'"([A-Za-z0-9._\- ]{2,64})"|\'([A-Za-z0-9._\- ]{2,64})\'', txt):
        lua_strings.add((m.group(1) or m.group(2)).strip())

def in_lua(fid):
    short = fid.split(".", 1)[-1]
    return fid in lua_strings or short in lua_strings or ("Hydrocraft." + short) in lua_strings

# ---------- 4. Достижимость (fixpoint) ----------
reachable = set(van_items)
for fid in items:
    if in_lua(fid):
        reachable.add(fid)
seed_reach = len(reachable)

def outputs_ids(r):
    ids = []
    for cnt, lst, raw in groups_of(r["outputs"]):
        ids += lst or []
    return ids

changed = True
craftable = set()
while changed:
    changed = False
    for r in recipes.values():
        if r["name"] in craftable: continue
        ok = True
        for cnt, lst, raw in groups_of(r["inputs"], consumed_only=True):
            if lst is None:  # tags / fluid / energy — считаем доступными
                continue
            if not any((i in reachable) or exists(i) and i in reachable for i in lst):
                if not any(i in reachable for i in lst):
                    ok = False; break
        if ok:
            craftable.add(r["name"])
            for o in outputs_ids(r):
                if o not in reachable:
                    reachable.add(o); changed = True

uncraftable = [r for r in recipes.values() if r["name"] not in craftable]
unreachable = [f for f in items if f not in reachable]

# блокирующий ингредиент для некрафтуемых
def blockers(r):
    bl = []
    for cnt, lst, raw in groups_of(r["inputs"], consumed_only=True):
        if lst and not any(i in reachable for i in lst):
            bl.append(" / ".join(ru(i) for i in lst[:4]))
    return bl

# книги недостижимы?
books = {b for bl in book_teaches.values() for b in bl}
unreachable_books = sorted(b for b in books if b not in reachable)

# рецепты, чья книга недостижима
lost_learn = sorted(rn for rn, bl in book_teaches.items()
                    if rn in recipes and all(b not in reachable for b in bl))

# группировки
from collections import Counter
no_source = [f for f in unreachable if not M["producers"].get(f)]
blocked_chain = [f for f in unreachable if M["producers"].get(f)]
file_unreach = Counter(items[f]["file"] for f in unreachable)
file_uncraft = Counter(r["file"] for r in uncraftable)
root_block = Counter()
for r in uncraftable:
    for cnt, lst, raw in groups_of(r["inputs"], consumed_only=True):
        if lst and not any(i in reachable for i in lst):
            for i in lst:
                root_block[i] += 1

rep = []
rep.append("=== ГРУППИРОВКИ ===")
rep.append(f"Недостижимые предметы: всего {len(unreachable)}; из них ВООБЩЕ без источника (ни лута, ни рецепта): {len(no_source)}; "
           f"рецепт есть, но цепочка заблокирована: {len(blocked_chain)}")
rep.append("\nТоп файлов по недостижимым предметам:")
for f, n in file_unreach.most_common(20): rep.append(f"  {n:4}  {f}")
rep.append("\nТоп файлов по некрафтуемым рецептам:")
for f, n in file_uncraft.most_common(20): rep.append(f"  {n:4}  {f}")
rep.append("\nТоп-30 корневых блокеров (предмет -> сколько рецептов он запирает):")
for i, n in root_block.most_common(30):
    rep.append(f"  {n:4}  {i} — {ru(i)}")
rep.append("")
rep.append(f"=== 1. Битые ссылки на предметы: {len(broken)} ===")
for rn, i, w in broken[:30]:
    rep.append(f"  {rn} [{w}]: {i}")
rep.append(f"\n=== 2. Книги учат несуществующим рецептам: {len(dangling_books)} ===")
for x in dangling_books[:20]: rep.append(f"  {x}")
rep.append(f"\n=== 3. Недостижимые ПРЕДМЕТЫ (не в луте/lua, нет рецепта или рецепт мёртв): {len(unreachable)} ===")
for f in unreachable[:60]:
    rep.append(f"  {f} — {ru(f)} ({items[f]['file']})")
rep.append(f"\n=== 4. НЕКРАФТУЕМЫЕ рецепты (ингредиент недостижим): {len(uncraftable)} ===")
for r in uncraftable[:60]:
    rep.append(f"  {r['name']} [{r['file']}] — блок: {'; '.join(blockers(r))[:120]}")
rep.append(f"\n=== 5. Недостижимые КНИГИ: {len(unreachable_books)} ===")
for b in unreachable_books[:30]: rep.append(f"  {b} — {ru(b)}")
rep.append(f"\n=== 6. Рецепты, все книги которых недостижимы: {len(lost_learn)} ===")
for x in lost_learn[:30]: rep.append(f"  {x}")
rep.append(f"\nстартовая достижимость: {seed_reach - len(van_items)} HC-предметов из lua-источников; "
           f"после крафта достижимо {sum(1 for f in items if f in reachable)}/{len(items)}; "
           f"крафтуемо рецептов {len(craftable)}/{len(recipes)}")

out = HERE / "gaps_report.txt"
out.write_text("\n".join(rep), encoding="utf-8")
print("\n".join(rep[:8]))
print("...")
print(rep[-1])
print("full:", out)

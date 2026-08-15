# -*- coding: utf-8 -*-
"""Парсер скриптов HCR -> модель JSON (предметы, рецепты, книги, цепочки)."""
import json, re, sys
from pathlib import Path
from collections import defaultdict

from hcr_paths import MODEL as OUT, SCRIPTS, TR_RU, find_game, read_text

GAME = find_game(required=False)
VANILLA = (GAME / "media/lua/shared/Translate") if GAME else None
if GAME is None:
    print("! установка Project Zomboid не найдена — ванильные названия в модель не попадут "
          "(укажите --game <путь> или PZ_GAME_DIR)", file=sys.stderr)

# ---------- переводы ----------
ru_items = json.loads(read_text(TR_RU / "ItemName.json"))          # "Hydrocraft.X" -> RU
ru_recipes = json.loads(read_text(TR_RU / "Recipes.json"))         # "Recipe Name" -> RU

def parse_legacy(path: Path, prefix: str) -> dict:
    d = {}
    if not path.exists():
        return d
    txt = read_text(path)
    for m in re.finditer(prefix + r'([\w.\-]+)\s*=\s*"((?:[^"\\]|\\.)*)"', txt):
        d[m.group(1)] = m.group(2).replace('\\"', '"')
    return d

def load_dict(path) -> dict:
    return json.loads(read_text(path)) if path and path.exists() else {}

van_ru = load_dict(VANILLA / "RU/ItemName.json" if VANILLA else None)
van_en = load_dict(VANILLA / "EN/ItemName.json" if VANILLA else None)

# ---------- разбор скриптов ----------
items = {}     # full id -> dict
recipes = {}   # name -> dict
book_teaches = defaultdict(list)  # recipe name -> [book full id]

item_re = re.compile(r'^\s*item\s+(\S+)\s*$')
recipe_re = re.compile(r'^\s*craftRecipe\s+(.+?)\s*$')
field_re = re.compile(r'^\s*([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*?),?\s*$')

def parse_file(path: Path):
    lines = read_text(path).splitlines()
    module = "Hydrocraft"
    i, n = 0, len(lines)
    while i < n:
        line = lines[i]
        mm = re.match(r'^\s*module\s+(\S+)', line)
        if mm:
            module = mm.group(1); i += 1; continue
        m = item_re.match(line)
        if m and i + 1 < n and "{" in lines[i + 1] + line:
            name = m.group(1)
            depth = 0; fields = {}
            j = i
            while j < n:
                depth += lines[j].count("{") - lines[j].count("}")
                fm = field_re.match(lines[j])
                if fm and depth >= 1:
                    fields[fm.group(1)] = fm.group(2).strip()
                j += 1
                if depth == 0 and j > i + 1:
                    break
            fid = f"{module}.{name}"
            repl = []
            for rf in ("ReplaceOnDeplete", "ReplaceOnUse", "ReplaceOnCooked", "ReplaceOnRotten"):
                v = fields.get(rf)
                if v:
                    v = v.strip()
                    repl.append(v if "." in v else f"{module}.{v}")
            items[fid] = {
                "id": fid,
                "en": fields.get("DisplayName", name),
                "type": fields.get("ItemType", ""),
                "cat": fields.get("DisplayCategory", ""),
                "file": path.name,
                "repl": repl,
            }
            lr = fields.get("LearnedRecipes")
            if lr:
                for rn in [x.strip() for x in lr.split(";") if x.strip()]:
                    book_teaches[rn].append(fid)
            i = j; continue
        m = recipe_re.match(line)
        if m:
            rname = m.group(1)
            depth = 0; j = i
            fields = {}; inputs = []; outputs = []; bucket = None
            while j < n:
                cur = lines[j]
                if re.match(r'^\s*inputs\s*$', cur): bucket = inputs
                elif re.match(r'^\s*outputs\s*$', cur): bucket = outputs
                stripped = cur.strip().rstrip(",")
                if bucket is not None and (stripped.startswith("item ") or stripped.startswith("fluid ") or stripped.startswith("energy ")):
                    bucket.append(stripped)
                fm = field_re.match(cur)
                if fm and depth >= 1 and bucket is None:
                    fields[fm.group(1)] = fm.group(2).strip()
                depth += cur.count("{") - cur.count("}")
                j += 1
                if depth == 0 and j > i + 1:
                    break
            recipes[rname] = {
                "name": rname,
                "cat": fields.get("category", ""),
                "time": fields.get("time", ""),
                "skill": fields.get("SkillRequired", ""),
                "xp": fields.get("xpAward", ""),
                "learn": fields.get("NeedToBeLearn", "").lower() == "true",
                "inputs": inputs,
                "outputs": outputs,
                "file": path.name,
            }
            i = j; continue
        i += 1

for f in sorted(SCRIPTS.rglob("*.txt")):
    parse_file(f)

# ---------- потоки предметов ----------
ITEM_LINE = re.compile(r'^item\s+(\d+)\s+(.*)$')

def line_items(line: str):
    """-> (count, [item ids]) либо (count, []) для tags/fluid/energy."""
    m = ITEM_LINE.match(line)
    if not m:
        return None
    cnt, rest = int(m.group(1)), m.group(2).strip()
    if rest.startswith("tags["):
        return cnt, [], re.sub(r'^tags\[([^\]]*)\].*$', r'теги: \1', rest)
    lm = re.match(r'^\[([^\]]*)\]', rest)
    if lm:
        return cnt, [x.strip() for x in lm.group(1).split(";") if x.strip()], None
    sm = re.match(r'^(\S+)', rest)
    return cnt, [sm.group(1)] if sm else [], None

producers = defaultdict(set)   # item -> recipes с ним в выходах
consumers = defaultdict(set)   # item -> recipes с ним во входах
for r in recipes.values():
    for line in r["outputs"]:
        res = line_items(line)
        if res:
            for it in res[1]:
                producers[it].add(r["name"])
    for line in r["inputs"]:
        res = line_items(line)
        if res:
            for it in res[1]:
                consumers[it].add(r["name"])

def ru_item(fid: str) -> str:
    if fid in ru_items: return ru_items[fid]
    short = fid.split(".", 1)[-1]
    return van_ru.get(fid) or van_ru.get(short) or ""

def en_item(fid: str) -> str:
    if fid in items: return items[fid]["en"]
    short = fid.split(".", 1)[-1]
    return van_en.get(fid) or van_en.get(short) or short

model = {
    "items": items,
    "recipes": recipes,
    "book_teaches": {k: sorted(v) for k, v in book_teaches.items()},
    "producers": {k: sorted(v) for k, v in producers.items()},
    "consumers": {k: sorted(v) for k, v in consumers.items()},
    "ru_items": ru_items,
    "ru_recipes": ru_recipes,
    "van_ru": van_ru,
    "van_en": van_en,
}
OUT.write_text(json.dumps(model, ensure_ascii=False), encoding="utf-8")

# отчёт
n_book = sum(1 for r in recipes.values() if r["name"] in book_teaches)
print(f"items={len(items)} recipes={len(recipes)} taught={n_book}")
print(f"ru items covered={sum(1 for i in items if i in ru_items)}/{len(items)}")
print(f"ru recipes covered={sum(1 for r in recipes if r in ru_recipes)}/{len(recipes)}")
missing_learn = [r['name'] for r in recipes.values() if r['learn'] and r['name'] not in book_teaches]
print(f"NeedToBeLearn без книги: {len(missing_learn)}")

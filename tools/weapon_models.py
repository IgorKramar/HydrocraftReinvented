# -*- coding: utf-8 -*-
"""Аудит отображения оружия: у кого есть модель, у кого нет и чем закрыть.

В B41 предмет показывался в руках по полю WeaponSprite. В B42 нужен меш,
подключённый блоком model, и ссылка WorldStaticModel из предмета. Мод пришёл
из B41 со 187 предметами на WeaponSprite, и почти всем им меша не поставлялось:
они ссылались на ванильные спрайты B41.

Скрипт делит оружие на три группы:

  1. подключено      — есть WorldStaticModel, вопросов нет;
  2. чинится своими  — меш лежит в моде, нужен блок model;
  3. нужна ваниль    — меша нет; при установленной игре скрипт ищет ванильную
                       модель B42 с подходящим именем и печатает готовые строки
                       WorldStaticModel.

Запуск: python3 tools/weapon_models.py --game "<путь к Project Zomboid>"
Ничего не переписывает — только отчёт в tools/weapon_models.txt.
"""
import re
from collections import defaultdict

from hcr_paths import HERE, REPO, SCRIPTS, find_game, read_text

MODELS_X = REPO / "common/media/models_X"
TEXTURES = REPO / "common/media/textures"

ITEM_RE = re.compile(r'^\s*item\s+(\S+)\s*$')
MODEL_RE = re.compile(r'^\s*model\s+(\S+)\s*$')
FIELD_RE = re.compile(r'^\s*([A-Za-z_]\w*)\s*=\s*(.*?),?\s*$')


def blocks(path, header_re):
    """Пары (имя, [строки тела]) для блоков верхнего уровня."""
    lines = read_text(path).splitlines()
    i, n = 0, len(lines)
    while i < n:
        m = header_re.match(lines[i])
        if m:
            depth, j = 0, i
            while j < n:
                depth += lines[j].count("{") - lines[j].count("}")
                j += 1
                if depth == 0 and j > i + 1:
                    break
            yield m.group(1), lines[i:j]
            i = j
            continue
        i += 1


def fields(body):
    out = {}
    for ln in body:
        f = FIELD_RE.match(ln)
        if f:
            out[f.group(1)] = f.group(2).strip()
    return out


# ---------- что есть в моде ----------
weapons, models = {}, {}
for f in sorted(SCRIPTS.rglob("*.txt")):
    for name, body in blocks(f, ITEM_RE):
        fl = fields(body)
        if "WeaponSprite" in fl or fl.get("ItemType") == "base:weapon":
            weapons[name] = {"file": f.name, "sprite": fl.get("WeaponSprite", ""),
                             "model": fl.get("WorldStaticModel", "")}
    for name, body in blocks(f, MODEL_RE):
        models[name] = fields(body).get("mesh", "")

mod_meshes = {p.stem: p for p in MODELS_X.rglob("*") if p.is_file()}
mod_textures = {p.stem for p in TEXTURES.rglob("*.png")}

# ---------- ванильные модели ----------
game = find_game(required=False)
van_models = set()
if game:
    for f in (game / "media/scripts").rglob("*.txt"):
        van_models |= {m.group(1) for m, _ in ((mm, None) for mm in
                       (MODEL_RE.match(ln) for ln in read_text(f).splitlines())) if m}
else:
    print("! игра не найдена: третью группу закрыть нечем "
          "(укажите --game <путь> или PZ_GAME_DIR)")

# ---------- разбор ----------
wired, fixable, need_vanilla, hopeless = [], [], [], []
for name, w in sorted(weapons.items()):
    if w["model"]:
        wired.append(name)
    elif name in mod_meshes:
        has_tex = name in mod_textures
        (fixable if has_tex else hopeless).append((name, w, has_tex))
    else:
        sprite = w["sprite"].split(".")[-1]
        match = sprite if sprite in van_models else None
        (need_vanilla if match else hopeless).append((name, w, match))

lines = [f"Оружейных предметов: {len(weapons)}; блоков model в моде: {len(models)}; "
         f"мешей в models_X: {len(mod_meshes)}"]
lines.append(f"\n1. Подключено (WorldStaticModel есть): {len(wired)}")
lines += [f"   {n}" for n in wired]

lines.append(f"\n2. Чинится своими силами — меш и текстура в моде: {len(fixable)}")
for n, w, _ in fixable:
    lines.append(f"   {n:28} {w['file']:26} меш {mod_meshes[n].relative_to(MODELS_X)}")
    lines.append(f"      model {n} {{ mesh = {mod_meshes[n].parent.name}/{n}, texture = {mod_meshes[n].parent.name}/{n}, }}")
    lines.append(f"      WorldStaticModel = {n},")

lines.append(f"\n3. Нужна ванильная модель B42 — имя из WeaponSprite совпало: {len(need_vanilla)}")
for n, w, match in need_vanilla:
    lines.append(f"   {n:28} {w['file']:26} WorldStaticModel = {match},")

lines.append(f"\n4. Не закрывается автоматически: {len(hopeless)}")
by_file = defaultdict(list)
for n, w, _ in hopeless:
    by_file[w["file"]].append(f"{n} (WeaponSprite={w['sprite'] or '—'})")
for f, names in sorted(by_file.items()):
    lines.append(f"   {f}: {len(names)}")
    lines += [f"      {x}" for x in names]

out = HERE / "weapon_models.txt"
out.write_text("\n".join(lines), encoding="utf-8")
print("\n".join(lines[:40]))
print("...\nполный отчёт:", out)

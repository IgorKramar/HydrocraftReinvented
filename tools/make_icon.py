# -*- coding: utf-8 -*-
"""Сборка иконок для новых предметов в стиле мода.

Рисовать с нуля скрипт не умеет — он собирает новое из того, что в моде уже
есть. Иконки Hydrocraft к этому располагают: они 32×32, с тёмным контуром
и очень небольшим числом цветов, а варианты «то же самое, но из другого
металла» — буквально одна и та же картинка в другой палитре. Проверено на
семействе рыболовных крючков: у всех семи вариантов силуэт совпадает
пиксель в пиксель, отличаются только три цвета.

Режимы:

  recolor   перекрасить иконку в другой материал
            (bone, tin, copper, bronze, iron, steel, titanium — палитры взяты
            из самого мода; свои добавляются через --learn-from)

  compose   собрать иконку из двух: наложить предмет на контейнер, коробку,
            мешок. Масштаб — только целыми долями, чтобы не мылить пиксели.

  palette   привести стороннюю картинку к палитре мода: каждый цвет
            заменяется ближайшим из тех, что уже встречаются в иконках.
            Пригодится, если иконку рисовали снаружи.

  audit     что со ссылками на иконки: у каких предметов файла нет,
            какие текстуры не используются никем.

Примеры:

  python3 tools/make_icon.py recolor --base Item_HCFishhooksteel.png \\
      --material copper --out Item_HCFishhookcopper2.png
  python3 tools/make_icon.py compose --base Item_HCCardboardbox.png \\
      --overlay Item_HCScrewdriver.png --scale 0.5 --pos br --out Item_HCScrewdriverbox.png
  python3 tools/make_icon.py audit
"""
import argparse
import re
import sys
from collections import Counter

try:
    from PIL import Image
except ImportError:
    sys.exit("Нужен Pillow: pip install Pillow")

from hcr_paths import HERE, REPO, SCRIPTS, read_text

TEXTURES = REPO / "common/media/textures"

# Палитры материалов, снятые с семейства Item_HCFishhook*: контур, светлый, средний.
MATERIALS = {
    "bone":     ("#292721", "#e4dbc0", "#b5ae98"),
    "tin":      ("#171717", "#8c8c8c", "#646464"),
    "copper":   ("#321e09", "#b87a38", "#905f2a"),
    "bronze":   ("#332907", "#bc9d33", "#937c26"),
    "iron":     ("#060606", "#595959", "#323232"),
    "steel":    ("#212121", "#8d8d8d", "#666666"),
    "titanium": ("#111116", "#717288", "#505161"),
}


def hex2rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def lum(c):
    return 0.299 * c[0] + 0.587 * c[1] + 0.114 * c[2]


def load(path):
    p = path if "/" in str(path) else TEXTURES / path
    if not p.exists():
        sys.exit(f"нет файла: {p}")
    return Image.open(p).convert("RGBA")


def pixels(im):
    return list(im.get_flattened_data()) if hasattr(im, "get_flattened_data") else list(im.getdata())


def save(im, out):
    p = out if "/" in str(out) else TEXTURES / out
    im.save(p)
    print(f"сохранено: {p}")


# ---------- recolor ----------
def learn_family(prefix):
    """Палитра материала из готового семейства: файлы <prefix><материал>.png."""
    out = {}
    for f in sorted(TEXTURES.glob(f"{prefix}*.png")):
        mat = f.stem[len(prefix):].lower()
        cols = Counter(px[:3] for px in pixels(Image.open(f).convert("RGBA")) if px[3] > 8)
        ranked = sorted(cols, key=lum)
        if len(ranked) >= 3:
            out[mat] = (ranked[0], ranked[-1], ranked[len(ranked) // 2])
    return out


def cmd_recolor(a):
    table = {k: tuple(hex2rgb(x) for x in v) for k, v in MATERIALS.items()}
    if a.learn_from:
        table.update(learn_family(a.learn_from))
        print("палитры из семейства:", ", ".join(sorted(table)))
    if a.material not in table:
        sys.exit(f"неизвестный материал {a.material}; есть: {', '.join(sorted(table))}")
    dark, light, mid = table[a.material]

    im = load(a.base)
    px = pixels(im)

    def sat(c):
        return (max(c) - min(c)) / max(max(c), 1)

    # Металл в иконках мода почти серый, а дерево, кожа и ткань — цветные.
    # По умолчанию красим только серое, чтобы рукояти и обмотки уцелели.
    target = (lambda c: sat(c) <= a.sat_max) if not a.all_pixels else (lambda c: True)
    used = sorted({p[:3] for p in px if p[3] > 8 and target(p[:3])}, key=lum)
    if not used:
        sys.exit("в иконке нет непрозрачных пикселей")
    lo, hi = lum(used[0]), lum(used[-1])
    span = max(hi - lo, 1)

    def ramp(t):
        """0 — контур, 0.5 — средний тон, 1 — светлый."""
        if t <= 0.5:
            k = t / 0.5
            a_, b_ = dark, mid
        else:
            k = (t - 0.5) / 0.5
            a_, b_ = mid, light
        return tuple(int(round(a_[i] + (b_[i] - a_[i]) * k)) for i in range(3))

    out = []
    for p in px:
        if p[3] <= 8:
            out.append((0, 0, 0, 0))
        elif target(p[:3]):
            out.append((*ramp((lum(p[:3]) - lo) / span), p[3]))
        else:
            out.append(p)                       # цветное оставляем как есть
    new = Image.new("RGBA", im.size)
    new.putdata(out)
    save(new, a.out)
    kept = sum(1 for p in px if p[3] > 8 and not target(p[:3]))
    print(f"перекрашено цветов {len(used)}, материал {a.material}, "
          f"сохранено цветных пикселей {kept}")


# ---------- compose ----------
def cmd_compose(a):
    base, over = load(a.base), load(a.overlay)
    if a.scale != 1.0:
        w, h = max(1, int(over.width * a.scale)), max(1, int(over.height * a.scale))
        over = over.resize((w, h), Image.NEAREST)      # только nearest: пиксель-арт
    bw, bh = base.size
    ow, oh = over.size
    pad = a.pad
    pos = {"center": ((bw - ow) // 2, (bh - oh) // 2),
           "br": (bw - ow - pad, bh - oh - pad), "bl": (pad, bh - oh - pad),
           "tr": (bw - ow - pad, pad), "tl": (pad, pad)}[a.pos]
    if a.outline:
        dark = hex2rgb(MATERIALS["iron"][0])
        halo = Image.new("RGBA", (ow + 2, oh + 2), (0, 0, 0, 0))
        mask = over.split()[3]
        for dx in (0, 1, 2):
            for dy in (0, 1, 2):
                halo.paste(Image.new("RGBA", over.size, (*dark, 255)), (dx, dy), mask)
        base.alpha_composite(halo, (pos[0] - 1, pos[1] - 1))
    base.alpha_composite(over, pos)
    save(base, a.out)


# ---------- palette ----------
def mod_palette(limit=64):
    cols = Counter()
    for f in TEXTURES.glob("Item_*.png"):
        try:
            im = Image.open(f).convert("RGBA")
        except Exception:
            continue
        if im.size != (32, 32):
            continue
        cols.update(p[:3] for p in pixels(im) if p[3] > 8)
    return [c for c, _ in cols.most_common(limit)]


def cmd_palette(a):
    pal = mod_palette(a.colors)
    print(f"палитра мода: {len(pal)} цветов")
    im = load(a.input)
    out = []
    cache = {}
    for p in pixels(im):
        if p[3] <= 8:
            out.append((0, 0, 0, 0)); continue
        key = p[:3]
        if key not in cache:
            cache[key] = min(pal, key=lambda c: sum((c[i] - key[i]) ** 2 for i in range(3)))
        out.append((*cache[key], p[3]))
    new = Image.new("RGBA", im.size)
    new.putdata(out)
    save(new, a.out)


# ---------- audit ----------
def cmd_audit(a):
    icons, items = {}, 0
    for f in sorted(SCRIPTS.rglob("*.txt")):
        txt = read_text(f)
        for m in re.finditer(r'item\s+(\w+)\s*\n\s*\{(.*?)\n\s*\}', txt, re.S):
            items += 1
            ic = re.search(r'^\s*[Ii]con\s*=\s*(\S+?),', m.group(2), re.M)
            if ic:
                icons.setdefault(ic.group(1), []).append(m.group(1))
    have = {f.stem[5:] for f in TEXTURES.glob("Item_*.png")}
    missing = sorted(i for i in icons if i not in have)
    unused = sorted(have - set(icons))
    lines = [f"предметов {items}, ссылок на иконки {len(icons)}, файлов Item_*.png {len(have)}",
             f"\nиконка объявлена, файла нет: {len(missing)}"]
    for i in missing[:40]:
        lines.append(f"   {i:32} у предметов: {', '.join(icons[i][:3])}")
    lines.append(f"\nфайл есть, никто не ссылается: {len(unused)}")
    lines += [f"   {u}" for u in unused[:40]]
    out = HERE / "icon_audit.txt"
    out.write_text("\n".join(lines), encoding="utf-8")
    print("\n".join(lines[:50]))
    print("...\nполный отчёт:", out)


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--game")  # съедаем общий флаг hcr_paths
    sub = ap.add_subparsers(dest="cmd", required=True)

    r = sub.add_parser("recolor"); r.set_defaults(fn=cmd_recolor)
    r.add_argument("--base", required=True); r.add_argument("--material", required=True)
    r.add_argument("--out", required=True); r.add_argument("--learn-from", dest="learn_from")
    r.add_argument("--all-pixels", action="store_true",
                   help="красить всё, а не только серое (по умолчанию рукояти сохраняются)")
    r.add_argument("--sat-max", type=float, default=0.25,
                   help="порог насыщенности, ниже которого пиксель считается металлом")

    c = sub.add_parser("compose"); c.set_defaults(fn=cmd_compose)
    c.add_argument("--base", required=True); c.add_argument("--overlay", required=True)
    c.add_argument("--out", required=True); c.add_argument("--scale", type=float, default=0.75)
    c.add_argument("--pad", type=int, default=1, help="отступ от края базовой иконки")
    c.add_argument("--pos", default="br", choices=["center", "br", "bl", "tr", "tl"])
    c.add_argument("--outline", action="store_true")

    p = sub.add_parser("palette"); p.set_defaults(fn=cmd_palette)
    p.add_argument("--input", required=True); p.add_argument("--out", required=True)
    p.add_argument("--colors", type=int, default=64)

    a_ = sub.add_parser("audit"); a_.set_defaults(fn=cmd_audit)

    args = ap.parse_args()
    args.fn(args)


if __name__ == "__main__":
    main()

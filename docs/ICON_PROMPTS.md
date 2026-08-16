# Промпты для недостающих иконок

*Четырнадцать иконок, которых в моде нет, а предметы есть. Промпты написаны
по замерам существующих файлов, а не на глаз: размеры, число цветов, контур
и проекция взяты из самих ассетов. Текст промптов — по-английски, генераторы
на нём работают заметно точнее.*

*Актуальный список пробелов всегда можно пересобрать:
`python3 tools/make_icon.py audit`*

---

## Два стиля, не один

В моде два разных вида ассетов, и путать их нельзя.

| | **A. Ручные предметы** | **B. Объекты мира** |
|---|---|---|
| Размер | 32×32 | 176×149 (стол), 200×320 (растения) |
| Цветов в файле | медиана 19 | 3 000–6 400 |
| Вид | три четверти, предмет по диагонали | изометрия PZ (дважды шире, чем выше) |
| Контур | жёсткий, чаще всего чистый чёрный `#000000` | тёмная кромка силуэта, внутри мягкие переходы |
| Сглаживание | нет | есть |
| Фон | прозрачный | прозрачный |

Частые цвета мода: `#000000`, `#ffffff`, `#3a2c2c`, `#4a302b`, `#3a3f3a`,
`#5b5a5a`, `#c3c3c3`, `#efe4b0`. Дерево — тёплое коричневое (`#4a302b`),
металл — холодный серый (`#5b5a5a` … `#c3c3c3`).

## Как пользоваться

1. Если у иконки указан **референс** — генерируйте через img2img от него,
   сила преобразования 0.35–0.5. Так сохраняются пропорции, угол и палитра;
   text-to-image по такому узкому стилю почти всегда промахивается.
2. Генерируйте крупно (512–1024) и не мучайтесь с фоном: приёмка сама уберёт
   фон, обрежет поля, ужмёт и подгонит палитру.

```sh
python3 tools/make_icon.py import --input сгенерированное.png \
    --out Item_HCXxx.png              # группа A, 32×32
python3 tools/make_icon.py import --input сгенерированное.png \
    --out Item_HCXxx.png --size 176x149 --no-palette   # группа B, объекты мира
```

3. **Тёмным и массивным** предметам добавьте `--outline-fix --lighten 1.5`:
   чёрное на чёрном контуре сливается в пятно, а у соседей по моду силуэт
   всегда отбит. Проверено на дубинке — без этого читалась как палка.
   **Тонким предметам обводка вредит**: у кирки она съела рога, и остриё
   потеряло форму. Правило простое — толще трёх пикселей в самом узком
   месте, можно обводить; тоньше, лучше не трогать.
4. Проверить: `python3 tools/make_icon.py audit` — иконка должна исчезнуть
   из списка.

`--size` принимает и квадрат (`32`), и прямоугольник (`176x149`): содержимое
вписывается в нужное соотношение, а не растягивается. `--no-palette` для
группы B обязателен — у объектов мира тысячи цветов, и приведение к палитре
иконок их убьёт.

Полезные флаги приёмки: `--bg #rrggbb` если фон определился неверно,
`--bg-tol` для его допуска, `--margin` для воздуха по краям,
`--filter nearest` если картинка уже пиксельная и нужного размера.

---

## A. Ручные предметы, 32×32

**Общий хвост промпта** (добавлять к каждому):

> 32x32 pixel art game icon, transparent background, single object centered,
> three-quarter view tilted diagonally, hard 1px pure black `#000000` outline,
> flat limited palette of about 15–20 colors, crisp pixels with no
> anti-aliasing, no gradients, no drop shadow, no text, no border, no frame,
> 1990s survival game inventory sprite

**Общий негативный промпт:**

> blurry, anti-aliased, smooth gradients, glow, drop shadow, text, watermark,
> border, frame, multiple objects, photorealistic, 3d render, isometric

### `Item_HCBaton.png` — полицейская дубинка ✅ сделано в v1.5.11

Предмет `HCBaton` («Police Baton»), встречается в полицейском луте.
Референса в моде нет; ближе всего по духу — рукояти инструментов
(`Item_HCAxehandle.png`).

Принято с параметрами `--outline-fix --lighten 1.5`: 19 цветов, ровно
медиана мода. Промпт ниже сработал с первого раза.

> A black police baton (nightstick) with a short side handle, matte black
> rubber grip with subtle ribbing, slightly worn tip, lying diagonally from
> lower-left to upper-right

### `Item_HCPickaxe.png` — кирка ✅ сделано в v1.5.11

Предмет `HCPickaxe`, в двух списках лута. Стилевой референс —
`Item_HCSmithyhammersteel.png`: там ровно то сочетание, что нужно, —
деревянная рукоять `#4a302b` и стальная голова `#8d8d8d`/`#212121`.

> A pickaxe with a straight wooden handle and a double-pointed steel head,
> one end tapered to a point and the other flattened into a chisel, light
> rust speckles on the metal, diagonal composition with the head at the top

Из двух вариантов принят тот, где **оба конца изогнутые и заострённые**,
хотя промпт просил остриё плюс долото: плоский конец при 32 пикселях
превращается в серое пятно, а симметричная «рогатая» голова узнаётся сразу.
Принято без обводки и без поля, 31 цвет.

### `Item_HCDeskbell.png` — звонок на стойке ✅ сделано в v1.5.11

Предмет `HCDeskbell` из гостиничного лута.

> A brass hotel desk bell: rounded dome on a flat round base with a small
> pressable button on top, warm brass yellows `#bc9d33` and `#937c26`, one
> bright specular highlight on the dome, seen slightly from above

### `Item_HCCandybarzedtrash.png` — обёртка от батончика ✅ сделано в v1.5.11

Предмет `HCCandybar4trash` («Candy Bar Wrapper»).
**Референсы обязательны:** `Item_HCCandybarzed.png` — цвета и рисунок
самой обёртки, `Item_HCCandybarcoconuttrash.png` — как в этом моде выглядит
скомканная обёртка. Задача сводится к «возьми смятую форму первого
и раскрась цветами второго».

> A crumpled empty candy bar wrapper, torn open at one end, foil interior
> catching a little light, keep the original wrapper's colors and lettering
> blocks unreadable at this size

**Урок на будущее.** В первом заходе я написал в промпте «dark brown and red
wrapper colors», не посмотрев на сам батончик, — а `Item_HCCandybarzed.png`
зелёно-оливковый. Пришлось сдвигать оттенок скриптом уже после генерации:
насыщенные пиксели переведены на оттенок 63° (среднее по цветам батончика),
фольга и контур не тронуты. **Перед тем как писать про цвета — снимите их
с родственного предмета**, это две строки на Pillow.

---

## B. Объекты мира

**Общий хвост промпта:**

> isometric game sprite for Project Zomboid, dimetric projection (2:1),
> transparent background, soft shading with visible pixel structure, muted
> desaturated palette, no outline glow, no text, no background scenery,
> lighting from the upper left

**Общий негативный промпт:**

> cartoon, cel shading, thick black outline, bright saturated colors, text,
> watermark, background, ground shadow, multiple objects, front view,
> perspective view

### Стол для вскрытия, 176×149 ✅ сделано в v1.5.11

Референс для обоих: `Item_HCDissectiontable.png` (пустой стол) и
`Item_HCDissectiontabledissected.png` (вскрытое тело) — между ними и нужно
попасть.

**Что вылезло на приёмке.** Генератор пририсовал обеим картинкам тень на полу,
которой у оригиналов нет, и порогом её было не снять: у стола с телом тень
и сталь совпали по яркости (165 против 162). Помогла заливка от углов
с порогом «по соседу» — она уходит по фону и мягкой тени, но встаёт на жёстком
контуре предмета:

```sh
python3 tools/make_icon.py import --input стол.png \
    --out Item_HCDissectiontablebody.png --size 176x149 --no-palette \
    --bg flood --flood-tol 12
```

Порог подбирается: 10–12 для тёмной столешницы, 8 для светлой окровавленной —
при 12 заливка протекала внутрь через светлую сталь и съедала стол целиком.
Карманы фона между ножками добиваются по цвету затравки автоматически,
одиночные крапины снимает `--despeckle` (по умолчанию 4 пикселя).

**Главный критерий отбора для объектов мира — не качество картинки, а вещи
на своих местах.** В обоих принятых вариантах на нижней полке лежат тот же
чёрный рулон, мешок и лоток, что и на пустом столе. Первые версии были
нарисованы не хуже, но набор предметов на полке у них отличался — при смене
состояния стола вещи бы прыгали. Добавляйте в промпт перечисление того,
что лежит на полке, и сверяйте результат с базовым состоянием.

**`Item_HCDissectiontablebody.png`** — «Dissection Table with Corpse»:

> The same stainless steel dissection table, now with an intact pale corpse
> lying on it under a partial sheet, body untouched and unopened, the lower
> shelf still holding its tray, sandbag and blue bucket

**`Item_HCDissectiontablebloody.png`** — «Bloody Dissection Table»:

> The same stainless steel dissection table, empty but smeared with dried
> blood: dark red streaks and pooled stains on the tabletop and a few drips
> down the near edge, nothing lying on it

### Горшечные растения, 200×320

Все восемь — один и тот же деревянный ящик-кашпо с металлическими уголками
и тёмной землёй, меняется только растение. **Референс для каждого — базовый
вариант того же растения**, он в моде есть; менять нужно только листву
и плоды.

«Созревший» (`ready`) в этом моде означает пик плодоношения: плодов заметно
больше, чем в базовом варианте, листва густая и сочная.

| Файл | Референс | Что меняем |
|---|---|---|
| `Item_HCPottedtomatoready.png` | `Item_HCPottedtomato.png` | больше спелых красных черри, гроздьями, листва тёмно-зелёная |
| `Item_HCPottedpotatoready.png` | `Item_HCPottedpotato.png` | пышная ботва, у основания видны выступившие из земли красные клубни |
| `Item_HCPottedradishready.png` | `Item_HCPottedradish.png` | розово-красные плечики редиса торчат из земли, ботва высокая |
| `Item_HCPottedCabbageredready.png` | `Item_HCPottedCabbagered.png` | плотный фиолетово-красный кочан в центре, внешние листья отогнуты |
| `Item_HCPottedCabbagewhiteready.png` | `Item_HCPottedCabbagewhite.png` | плотный бледно-зелёный кочан, внешние листья отогнуты |
| `Item_HCPottedorangetreeready.png` | `Item_HCPottedorangetree.png` | много спелых оранжевых плодов по всей кроне |

Промпт для «созревшего» (подставить культуру):

> A potted <культура> plant at peak harvest in the same wooden planter box
> with metal corner brackets and dark soil, noticeably more ripe fruit than
> the reference, lush healthy foliage, same planter, same angle, same scale

Два оставшихся — увядание, а не созревание:

**`Item_HCPottedorangetreedead.png`**, референс `Item_HCPottedorangetree.png`:

> The same potted orange tree, now dead: bare grey-brown branches, no fruit,
> a few shrivelled brown leaves clinging on, dry cracked soil, planter
> unchanged

**`Item_HCPottedpeaplantsmalldry.png`**, референс `Item_HCPottedpeaplantsmall.png`
(там же рядом есть `Item_HCPottedpeaplantsmalldead.png` — целиться нужно
между базовым и им):

> The same small potted pea seedling, now dry and wilting: leaves drooping
> and yellowing at the edges, stems limp but still standing, soil pale and
> cracked, planter unchanged

---

## Проверка результата

- размер файла совпадает с референсом до пикселя;
- фон прозрачный, полупрозрачных пикселей по краю нет (генераторы любят
  оставлять кайму — обрежьте её);
- имя файла = `Item_` + значение поля `Icon` у предмета, регистр важен
  на linux-серверах;
- `python3 tools/make_icon.py audit` больше не показывает эту иконку.

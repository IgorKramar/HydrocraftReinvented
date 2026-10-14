"""Восемь отсутствующих состояний растений через fal, без ключей в файлах.

Требует Universal Modder в PYTHONPATH. Сырые результаты хранятся вне мода.
Запуск: python tools/generate_plant_icons.py --out <внешняя папка>.
"""
import argparse
import subprocess
import sys
from pathlib import Path

from hcr_paths import REPO

STATES = [
    ('HCPottedtomatoready', 'HCPottedtomato', 'Add clusters of ripe red tomatoes, keep the plant healthy.'),
    ('HCPottedpotatoready', 'HCPottedpotato', 'Mature lush potato foliage, a few red potato shoulders visible just above soil.'),
    ('HCPottedradishready', 'HCPottedradish', 'Mature radish plants with pink-red radish shoulders protruding slightly from the soil.'),
    ('HCPottedCabbageredready', 'HCPottedCabbagered', 'A mature dense purple-red cabbage head with outer leaves opened.'),
    ('HCPottedCabbagewhiteready', 'HCPottedCabbagewhite', 'A mature dense pale green cabbage head with outer leaves opened.'),
    ('HCPottedorangetreeready', 'HCPottedorangetree', 'Add more ripe oranges throughout the leafy canopy, retain the tree shape.'),
    ('HCPottedorangetreedead', 'HCPottedorangetree', 'Dead orange tree: bare dry brown branches, no fruit and no green leaves.'),
    ('HCPottedpeaplantsmalldry', 'HCPottedpeaplantsmall', 'Thirsty pea plant: wilted drooping olive green leaves, dry soil, still alive.'),
]


def main():
    from um.fal import generate
    ap = argparse.ArgumentParser()
    ap.add_argument('--out', type=Path, required=True)
    ap.add_argument('--limit', type=int, default=8)
    args = ap.parse_args()
    textures = REPO / 'common/media/textures'
    for index, (target, reference, change) in enumerate(STATES[:args.limit]):
        name = 'Item_' + target
        if (textures / (name + '.png')).exists():
            continue
        raw = args.out / (name + '.png')
        if not raw.exists():
            result = generate('fal-ai/nano-banana-2/edit', {
                'prompt': 'Edit only this Project Zomboid game sprite. ' + change +
                    ' Preserve the exact wooden square planter, isometric camera, scale, trunk position and game-art style. '
                    'Single object on a pure white background, no shadow outside the planter, no text, no border. '
                    'Do not redesign the planter. All foliage and branches must fit within the image.',
                'image_urls': ['@' + str(textures / ('Item_' + reference + '.png'))],
                'resolution': '0.5K', 'output_format': 'png', 'num_images': 1,
                'seed': 424200 + index,
            }, args.out, name)
            raw = Path(result['files'][0])
        subprocess.run([sys.executable, str(REPO / 'tools/make_icon.py'), 'import',
                        '--input', str(raw), '--out', name + '.png', '--size', '200x320',
                        '--no-palette', '--bg', 'flood', '--flood-tol', '10',
                        '--planter-from', 'Item_' + reference + '.png'], check=True)
    # Warm-colour alignment alone confuses stems/fruit with box walls. Finish
    # with the reviewed original atlas geometry, or fail on an unreviewed source.
    subprocess.run([sys.executable, str(REPO / 'tools/fit_planter_icons.py'),
                    '--out', str(args.out / 'fitted'), '--apply', '--names',
                    *[target for target, _, _ in STATES[:args.limit]]], check=True)


if __name__ == '__main__':
    main()

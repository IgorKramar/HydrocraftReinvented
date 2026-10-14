"""One fal edit; raw output outside the mod, deterministic 32px asset pipeline."""
import argparse
import subprocess
import sys
from pathlib import Path
from PIL import Image

REPO = Path(__file__).resolve().parents[1]
NAME = 'Item_HCSiliconpowder'
PROMPT = (
    'Edit only the supplied tiny Project Zomboid inventory powder sprite. '
    'Replace the brown iron powder with a mound of dark neutral grey crystalline silicon powder, '
    'small angular grains and a few cool grey mineral glints; charcoal-grey dark edges, medium grey body, '
    'subtle light-grey grain highlights. Preserve the exact low mound silhouette, isometric viewpoint, '
    '32-pixel inventory game sprite style, dark outline and modest rough-pixel shading. '
    'No brown, no copper, no gold, no white silver metal shine. One powder pile, no container, no tools, '
    'no label, no lettering, no text, no frame, no extra padding, no floor shadow. '
    'Plain pure-white background outside the pile so it can be removed cleanly.'
)

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--out', type=Path, required=True)
    args = parser.parse_args()
    raw = args.out / (NAME + '.png')
    reference = REPO / 'common/media/textures/Item_HCIronpowder.png'
    if not raw.exists():
        from um.fal import generate
        result = generate('fal-ai/nano-banana-2/edit', {
            'prompt': PROMPT, 'image_urls': ['@' + str(reference)],
            'resolution': '0.5K', 'output_format': 'png', 'num_images': 1,
            'seed': 424221,
        }, args.out, NAME)
        raw = Path(result['files'][0])
    cut = args.out / (NAME + '_cut.png')
    fitted = args.out / (NAME + '_fit.png')
    subprocess.run([sys.executable, '-m', 'um', 'sprite', 'cutout', str(raw), str(cut)], check=True)
    subprocess.run([sys.executable, '-m', 'um', 'sprite', 'fit', str(cut), str(fitted),
                    '--size', '32x32', '--hard-alpha'], check=True)
    image = Image.open(fitted).convert('RGBA')
    # Retain the original inventory pile's exact outline and alpha footprint.
    source = Image.open(reference).convert('RGBA')
    pixels, source_pixels = image.load(), source.load()
    luminance = source.convert('L').load()
    for y in range(image.height):
        for x in range(image.width):
            if source_pixels[x, y][3] and not pixels[x, y][3]:
                # A reference outline fragment may fall just outside the fitted
                # generated mound. Fill its RGB with controlled grey source
                # shading instead of exposing the removed white backdrop.
                shade = min(165, max(45, luminance[x, y]))
                pixels[x, y] = (shade, shade, shade, 255)
    image.putalpha(source.getchannel('A'))
    target = REPO / 'common/media/textures' / (NAME + '.png')
    image.save(target)
    subprocess.run([sys.executable, '-m', 'um', 'sprite', 'preview', str(target),
                    str(args.out / (NAME + '_preview.png')), '--scale', '12'], check=True)
    print('Silicon icon fitted to original 32x32 transparent inventory footprint')

if __name__ == '__main__':
    main()

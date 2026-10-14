"""Generate chainmail on the mod's existing shirt UV; retain exact alpha mask."""
from pathlib import Path
from PIL import Image
from um.fal import generate

REPO = Path(__file__).resolve().parents[1]
OUT = Path.home() / '.codex/modding-lab/hcr-assets'
REF = REPO / 'common/media/textures/clothing/HCShirtLinenWhite.png'
DEST = REPO / 'common/media/textures/clothing/HCArmorchainmail.png'

if __name__ == '__main__':
    raw = OUT / 'HCArmorchainmail_uv.png'
    if not raw.exists():
        result = generate('fal-ai/nano-banana-2/edit', {
            'prompt': 'Edit this flat clothing UV texture atlas for a game. Replace the pale linen fabric with tightly woven dark silver steel chainmail rings, small regular four-in-one interlinked rings, subtle worn metal highlights. Remove the central buttons and linen stitching. Preserve the exact atlas layout, shapes, edges and black unused lower region. Flat orthographic texture only, no garment illustration, no perspective, no added objects, no text. Even neutral lighting; rings must stay recognisable at low game resolution.',
            'image_urls': ['@' + str(REF)], 'resolution': '0.5K',
            'output_format': 'png', 'num_images': 1, 'seed': 424220,
        }, OUT, 'HCArmorchainmail_uv')
        raw = Path(result['files'][0])
    reference = Image.open(REF).convert('RGBA')
    texture = Image.open(raw).convert('RGBA').resize(reference.size, Image.Resampling.LANCZOS)
    texture.putalpha(reference.getchannel('A'))
    texture.save(DEST)
    print(DEST)

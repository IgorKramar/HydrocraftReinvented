"""Export portable fal provenance without credentials or machine paths."""
import json
from pathlib import Path
from generate_plant_icons import STATES

REPO = Path(__file__).resolve().parents[1]
RAW = Path.home() / '.codex/modding-lab/hcr-assets'
records = [record for line in (RAW / 'fal_manifest.jsonl').read_text().splitlines()
           if (record := json.loads(line)).get('request_id')]
recovered = {
    'name': 'Item_HCPottedtomatoready', 'endpoint': 'fal-ai/nano-banana-2/edit',
    'request_id': '01a13a52-8346-7723-9f3c-0a7a32c95246',
    'input': {'seed': 424200, 'prompt': 'Edit only this Project Zomboid game sprite. ' + STATES[0][2]
              + ' Preserve the exact wooden square planter, isometric camera, scale, trunk position and game-art style. '
              + 'Single object on a pure white background, no shadow outside the planter, no text, no border. '
              + 'Do not redesign the planter. All foliage and branches must fit within the image.'},
    'note': 'Output recovered after download TLS error; job was not resubmitted.',
}
if not any(r['request_id'] == recovered['request_id'] for r in records):
    records.insert(0, recovered)
references = {'Item_' + target: 'common/media/textures/Item_' + ref + '.png'
              for target, ref, _ in STATES}
references['HCArmorchainmail_uv'] = 'common/media/textures/clothing/HCShirtLinenWhite.png'
references['Item_HCSiliconpowder'] = 'common/media/textures/Item_HCIronpowder.png'
exported = []
for record in records:
    name = record['name']
    if name == 'HCRSpikeTrap':
        pipeline = json.loads((REPO / 'docs/SPIKE_TRAP_PIPELINE.json').read_text())
        exported.append({
            'asset': pipeline['asset'], 'texture': pipeline['texture'],
            'reference': 'common/media/textures/Item_Spiketrapclosed.png',
            'service': 'fal.ai', 'endpoint': record['endpoint'],
            'request_id': record['request_id'], 'seed': record.get('seed'),
            'generation': {'texture_size': record['input'].get('texture_size'),
                           'decimation_target': record['input'].get('decimation_target')},
            'processing': pipeline['processing'],
            'processing_tool': 'tools/import_spike_trap.py',
            'source_sha256': pipeline['source_sha256'],
            'output_sha256': pipeline['output_sha256'],
            'verification': 'DirectX round-trip and visible textured ground geometry verified after cold native 42.21 restart without static TXT NPE. Native SP placement, one sensor-triggered explosion and device removal passed; armed device retains native PlacedSprite. Damage and MP activation not measured.',
        })
        continue
    if name not in references:
        continue
    chainmail = name == 'HCArmorchainmail_uv'
    silicon = name == 'Item_HCSiliconpowder'
    exported.append({
        'asset': 'common/media/textures/clothing/HCArmorchainmail.png' if chainmail
                 else 'common/media/textures/' + name + '.png',
        'reference': references[name], 'service': 'fal.ai',
        'endpoint': record['endpoint'], 'request_id': record['request_id'],
        'seed': record.get('input', {}).get('seed'),
        'prompt': record.get('input', {}).get('prompt', STATES[0][2]),
        'processing': 'Resize to source UV size; preserve source alpha mask.' if chainmail
                      else 'Flood background removal; one nearest-neighbour fit to 32x32; preserve original pile alpha; grey source shading for outline fragments outside generated fit.' if silicon
                      else 'Initial fal foliage imported, then retained at 1:1 with reviewed masking/translation; original 110x123 planter pixels from hcBuilding2x.pack reused; transparent 200x424 canvas aligns the ground edge to native dropped-item 3/4-height anchor. No generated box geometry retained.',
        **({'processing_tool': 'tools/generate_silicon_icon.py'} if silicon else {}),
        **({'processing_tool': 'tools/fit_planter_icons.py', 'planter_reference': 'docs/PLANTER_SCALE.json'}
           if not chainmail and not silicon else {}),
        **({'matte_cleanup': 'Remove neutral white fringe pixels from isolated tomato foliage before atlas compositing; preserve coloured pixels and planter walls.'}
           if name == 'Item_HCPottedtomatoready' else {}),
        **({'note': record['note']} if 'note' in record else {}),
    })
regenerated=REPO/'docs/PLANT_REGENERATION.json'
if regenerated.exists():
    replacements={r['asset']:r for r in json.loads(regenerated.read_text(encoding='utf-8'))}
    for index,prior in enumerate(exported):
        if prior['asset'] in replacements:
            current=replacements[prior['asset']].copy()
            current['superseded_generations']=[{'endpoint':prior['endpoint'],'request_id':prior['request_id']}]
            exported[index]=current
(REPO / 'docs/ASSET_PROVENANCE.json').write_text(
    json.dumps(exported, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
print(f'Exported {len(exported)} generated asset records')

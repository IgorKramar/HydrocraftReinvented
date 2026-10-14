"""Apply reviewed B41 liquor/medical portions as native B42 fluid quantities."""
import argparse
import json
from pathlib import Path
from apply_playability_fixes import blocks
from hcr_paths import read_text
from repair_food_counts import FOOD_SCRIPTS

MANIFEST = Path(__file__).with_name('liquid_input_migrations.json')

def apply(check=False):
    manifest = json.loads(MANIFEST.read_text(encoding='utf-8'))
    for filename in sorted({e['file'] for e in manifest['migrations']}):
        path = FOOD_SCRIPTS / filename
        text = read_text(path)
        before = text
        for start, end, name, body in reversed(list(blocks(text, 'craftRecipe'))):
            for entry in manifest['migrations']:
                if (entry['file'], entry['recipe']) != (filename, name):
                    continue
                old, new = entry['before'], entry['after']
                if old in body:
                    if check:
                        raise RuntimeError(f'Unmigrated fluid input: {filename}/{name}')
                    body = body.replace(old, new)
                elif new not in body:
                    raise RuntimeError(f'Reviewed input changed: {filename}/{name}')
            text = text[:start] + body + text[end:]
        for entry in manifest.get('variants', []):
            if entry['file'] != filename:
                continue
            current = {n: b for _, _, n, b in blocks(text, 'craftRecipe')}
            if entry['recipe'] not in current:
                if check:
                    raise RuntimeError('Missing native fluid variant: ' + entry['recipe'])
                text = text.rstrip().rstrip('}') + '\n    ' + entry['body'] + '\n}\n'
        if text != before:
            path.write_text(text, encoding='utf-8', newline='')
    print('Reviewed liquor and disinfectant fluid inputs verified')

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true')
    apply(parser.parse_args().check)

"""Apply reviewed petrol charges and empty physical containers, idempotently."""
import argparse
import json
from pathlib import Path
from apply_playability_fixes import blocks
from hcr_paths import read_text
from repair_food_counts import FOOD_SCRIPTS

MANIFEST = Path(__file__).with_name('petrol_container_migrations.json')


def transform(text, entries, check=False):
    seen = set()
    for start, end, name, body in reversed(list(blocks(text, 'craftRecipe'))):
        for entry in entries:
            if entry['recipe'] != name:
                continue
            seen.add(name)
            old, new = entry['before'], entry['after']
            if new in body:
                continue
            if body.count(old) != 1:
                raise RuntimeError('Reviewed input changed: ' + name)
            if check:
                raise RuntimeError('Unmigrated input: ' + name)
            body = body.replace(old, new, 1)
        text = text[:start] + body + text[end:]
    if seen != {entry['recipe'] for entry in entries}:
        raise RuntimeError('Missing recipe: ' + str({e['recipe'] for e in entries} - seen))
    return text


def apply(check=False):
    entries = json.loads(MANIFEST.read_text(encoding='utf-8'))['migrations']
    for filename in sorted({e['file'] for e in entries}):
        path = FOOD_SCRIPTS / filename
        before_bytes = path.read_bytes()
        before = read_text(path)
        after = transform(before, [e for e in entries if e['file'] == filename], check)
        if before != after:
            if path.read_bytes() != before_bytes:
                raise RuntimeError('Concurrent file edit: ' + filename)
            path.write_text(after, encoding='utf-8', newline='')
    print(f"Verified {len(entries)} petrol/physical-container inputs")


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true')
    apply(parser.parse_args().check)

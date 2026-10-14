"""Remove reviewed absent IDs and their complete weights from reachable loot pools."""
import argparse
import json
from pathlib import Path

from hcr_paths import LUA, read_text

MANIFEST = Path(__file__).with_name('missing_loot_migrations.json')


def apply(check=False):
    manifest = json.loads(MANIFEST.read_text(encoding='utf-8'))
    changes = {}
    removed = 0
    for entry in manifest['removals']:
        path = LUA / entry['file']
        if path not in changes:
            original = read_text(path)
            changes[path] = [original, original]
        text = changes[path][1]
        token = entry['input']
        if entry['kind'] == 'weighted_pair':
            matches = [line for line in text.splitlines(keepends=True) if line.strip() == token]
            if len(matches) > entry['occurrences']:
                raise RuntimeError(f'Reviewed pair count changed: {entry["item"]}')
            if check and matches:
                raise RuntimeError(f'Absent ID still in loot pool: {entry["item"]}')
            for line in matches:
                text = text.replace(line, '', 1)
            removed += len(matches)
        else:
            count = text.count(token)
            if count > entry['occurrences']:
                raise RuntimeError(f'Reviewed list entry count changed: {entry["item"]}')
            if check and count:
                raise RuntimeError(f'Absent ID still in loot callback: {entry["item"]}')
            text = text.replace(token, '')
            removed += count
        changes[path][1] = text
    for entry in manifest.get('corrections', []):
        path = LUA / entry['file']
        if path not in changes:
            original = read_text(path)
            changes[path] = [original, original]
        text = changes[path][1]
        lines = text.splitlines(keepends=True)
        before = sum(line.strip() == entry['before'] for line in lines)
        after = sum(line.strip() == entry['after'] for line in lines)
        if before + after != entry['occurrences']:
            raise RuntimeError('Reviewed malformed loot input changed')
        if check and before:
            raise RuntimeError('Loot input has missing weight')
        changes[path][1] = ''.join(line.replace(entry['before'], entry['after'])
                                  if line.strip() == entry['before'] else line for line in lines)
    if not check:
        for path, (old, new) in changes.items():
            if read_text(path) != old:
                raise RuntimeError(f'Concurrent edit: {path}')
            if new != old:
                path.write_text(new, encoding='utf-8', newline='')
    print(f'absent loot entries removed={removed}')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true')
    apply(parser.parse_args().check)

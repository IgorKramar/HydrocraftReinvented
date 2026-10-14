"""Apply the checked-in, source-reviewed B41 whole-food migration manifest.

No inference is made while applying: partial food uses and ambiguous alternatives
stay untouched. Run with --check to verify the final state without writing.
"""
import argparse
import json
import re
from collections import defaultdict
from pathlib import Path

from apply_playability_fixes import blocks
from hcr_paths import SCRIPTS, read_text

MANIFEST = Path(__file__).with_name('food_count_migrations.json')
FOOD_SCRIPTS = SCRIPTS / 'HydrocraftReinvented'


def whole_input(line):
    if 'flags[' in line:
        return re.sub(r'flags\[([^]]*)\]',
                      lambda m: 'flags[' + m[1] + ';ItemCount]', line, count=1)
    return line.rstrip(',') + ' flags[ItemCount],'


def apply(check=False, manifest_path=MANIFEST):
    manifest = json.loads(manifest_path.read_text(encoding='utf-8'))
    by_file = defaultdict(lambda: defaultdict(list))
    for entry in manifest['migrations']:
        by_file[entry['file']][entry['recipe']].append(entry)
    changes = []
    migrated = already = 0
    for filename, recipes in sorted(by_file.items()):
        path = FOOD_SCRIPTS / filename
        old = read_text(path)
        new = old
        found = set()
        for start, end, name, body in reversed(list(blocks(old, 'craftRecipe'))):
            if name not in recipes:
                continue
            found.add(name)
            for entry in recipes[name]:
                before, after = entry['input'], whole_input(entry['input'])
                lines = body.splitlines(keepends=True)
                matches = sum(line.strip() == before for line in lines)
                done = sum(line.strip() == after for line in lines)
                if not matches and not done:
                    raise RuntimeError(f'Input changed since review: {filename} / {name} / {before}')
                if check and matches:
                    raise RuntimeError(f'Whole food still consumes uses: {filename} / {name}')
                migrated += matches
                already += done
                body = ''.join(line.replace(before, after) if line.strip() == before else line
                               for line in lines)
            new = new[:start] + body + new[end:]
        missing = set(recipes) - found
        if missing:
            raise RuntimeError(f'Missing reviewed recipes in {filename}: {sorted(missing)}')
        if old != new:
            changes.append((path, old, new))
    if not check:
        for path, old, new in changes:
            if read_text(path) != old:
                raise RuntimeError(f'Concurrent edit detected: {path.name}; rerun against current files')
            path.write_text(new, encoding='utf-8', newline='')
    print(f'whole-food lines migrated={migrated}; already correct={already}; files changed={len(changes)}')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true')
    apply(parser.parse_args().check)

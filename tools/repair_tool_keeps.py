"""Apply pinned-source tool keep corrections without treating fire charges as tools."""
import argparse
import json
from collections import defaultdict
from pathlib import Path

from apply_playability_fixes import blocks
from hcr_paths import SCRIPTS, read_text

MANIFEST = Path(__file__).with_name('tool_keep_migrations.json')


def kept_input(line):
    if 'mode:' in line:
        raise ValueError('Do not override an explicit input mode')
    return line.rstrip(',') + ' mode:keep,'


def apply(check=False):
    manifest = json.loads(MANIFEST.read_text(encoding='utf-8'))
    by_file = defaultdict(lambda: defaultdict(list))
    for entry in manifest['migrations']:
        by_file[entry['file']][entry['recipe']].append(entry)
    changes = []
    migrated = already = 0
    for filename, recipes in sorted(by_file.items()):
        path = SCRIPTS / 'HydrocraftReinvented' / filename
        old = read_text(path)
        new = old
        found = set()
        for start, end, name, body in reversed(list(blocks(old, 'craftRecipe'))):
            if name not in recipes:
                continue
            found.add(name)
            for entry in recipes[name]:
                before, after = entry['input'], kept_input(entry['input'])
                lines = body.splitlines(keepends=True)
                matches = sum(line.strip() == before for line in lines)
                done = sum(line.strip() == after for line in lines)
                if not matches and not done:
                    # Duplicated legacy recipe names may have different tools.
                    continue
                if check and matches:
                    raise RuntimeError(f'Tool is still consumed: {filename} / {name}')
                migrated += matches
                already += done
                body = ''.join(line.replace(before, after) if line.strip() == before else line
                               for line in lines)
            new = new[:start] + body + new[end:]
        if set(recipes) - found:
            raise RuntimeError(f'Missing reviewed recipes: {filename}')
        # Each portable entry records the total expected occurrences by name.
        for recipe, entries in recipes.items():
            recipe_bodies = [body for _, _, name, body in blocks(new, 'craftRecipe') if name == recipe]
            for entry in entries:
                count = sum(line.strip() == kept_input(entry['input'])
                            for body in recipe_bodies for line in body.splitlines())
                if count != entry['occurrences']:
                    raise RuntimeError(f'Reviewed tool count changed: {filename} / {recipe}: {count}')
        if new != old:
            changes.append((path, old, new))
    if not check:
        for path, old, new in changes:
            if read_text(path) != old:
                raise RuntimeError(f'Concurrent edit: {path.name}')
            path.write_text(new, encoding='utf-8', newline='')
    print(f'tool keep lines migrated={migrated}; already correct={already}; files changed={len(changes)}')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true')
    apply(parser.parse_args().check)

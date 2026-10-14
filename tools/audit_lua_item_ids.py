"""Literal item references against the installed game's script declarations."""
import re
from hcr_paths import SCRIPTS, LUA, find_game, read_text


def declared(root):
    names = set()
    for path in root.rglob('*.txt'):
        text = read_text(path)
        module = re.search(r'\bmodule\s+(\w+)\s*\{', text)
        if module:
            names.update(module[1] + '.' + name for name in
                         re.findall(r'^\s*item\s+(\w+)\s*\{?', text, re.M))
    return names


if __name__ == '__main__':
    names = declared(SCRIPTS) | declared(find_game() / 'media/scripts')
    missing = {}
    for path in LUA.rglob('*.lua'):
        for number, line in enumerate(read_text(path).splitlines(), 1):
            if line.lstrip().startswith('--'):
                continue
            for name in re.findall(r'["\']((?:Base|Hydrocraft|farming|Radio)\.[\w]+)["\']', line):
                if name not in names:
                    missing.setdefault(name, []).append(f'{path.relative_to(LUA)}:{number}')
    for name, locations in sorted(missing.items()):
        print(name + '  ' + ', '.join(locations[:4]))
    print(f'{len(missing)} distinct unrecognised literal references; review before changing')

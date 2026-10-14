"""Однократная миграция подтверждённых B41→B42 ошибок; не запускается игрой.

Сохранена для воспроизводимости правок. Повторный запуск безопасен.
"""
import json
import re
from pathlib import Path

from hcr_paths import REPO, SCRIPTS, LUA, read_text


def blocks(text, kind):
    for match in re.finditer(r'^\s*' + kind + r'\s+([^\n{]+)\s*\n\s*\{', text, re.M):
        opening = text.index('{', match.start())
        depth = 1
        end = opening + 1
        while depth and end < len(text):
            depth += (text[end] == '{') - (text[end] == '}')
            end += 1
        yield match.start(), end, match.group(1).strip(), text[match.start():end]


def write(path, old, new):
    if old != new:
        path.write_text(new, encoding='utf-8', newline='')
        print(path.relative_to(REPO))


def main():
    # Сигнатура B42: hasTrait(CharacterTrait), старого contains(String) нет.
    for path in LUA.rglob('*.lua'):
        old = read_text(path)
        new = re.sub(r"player:getTraits\(\):contains\('([^']+)'\)", r'HCR.hasTrait(player, "\1")', old)
        if new != old:
            new = 'require "HCR_Compatibility"\n' + new
            write(path, old, new)

    for path in SCRIPTS.rglob('*.txt'):
        old = read_text(path)
        new = old.replace('Base.BucketEmpty', 'Base.Bucket')
        # В Lua-списках раннего B41 также встречались другие module-prefix.
        for start, end, name, body in reversed(list(blocks(new, 'item'))):
            if not re.search(r'\bItemType\s*=', body, re.I):
                body = body.replace('{', '{\n        ItemType = base:normal,', 1)
                new = new[:start] + body + new[end:]
        for start, end, name, body in reversed(list(blocks(new, 'craftRecipe'))):
            # Эти операции переводят целые вещи; граммы/порции еды тут неверны.
            whole = (name.startswith(('Pack ', 'Unpack ', 'Slice ', 'Cut ', 'Heat MRE',
                                     'Heat up MRE', 'Shuck Corn', 'Fill Tupperware',
                                     'Fill Large Tupperware', 'Fill Medium Tupperware',
                                     'Fill Small Tupperware'))
                     or ('Jello' in name and name.startswith(('Pour ', 'Remove ')))
                     or ('Container' in name and name.startswith('Fill ')))
            if whole:
                def count_line(m):
                    line = m.group(0)
                    if 'mode:keep' in line or 'mode:destroy' in line or 'flags[' in line:
                        return line
                    return line[:-1] + ' flags[ItemCount],' if line.endswith(',') else line
                # Только inputs, outputs остаются прежними.
                inp = re.search(r'(inputs\s*\{)(.*?)(\n\s*\})', body, re.S)
                if inp:
                    lines = re.sub(r'item\s+\d+\s+\[[^\]]+\][^\n]*,', count_line, inp.group(2))
                    body = body[:inp.start(2)] + lines + body[inp.end(2):]
            if name.startswith('Shuck Corn'):
                body = re.sub(r'time\s*=\s*500', 'time = 40', body)
            # Распил/упаковка досок не требуют стола под открытым небом.
            if name.startswith(('Make Wood Plank', 'Stack Plank', 'Unstack Plank',
                                'Pack ', 'Unpack ', 'Stack Lumber')):
                body = re.sub(r'Tags\s*=\s*AnySurfaceCraft\s*,',
                              'Tags = AnySurfaceCraft;CanBeDoneFromFloor,', body)
            if name == 'Unpack Lumber Stack':
                body = body.replace('OnCreate = HCR42.recipe_hcrope,', '')
                body = body.replace('item 2 Base.Rope,', 'item 1 Base.Rope,')
                if 'item 1 Base.Rope' not in body:
                    body = body.replace('item 12 Base.Plank,', 'item 12 Base.Plank,\n            item 1 Base.Rope,')
            if name.startswith('Take Stick of Gum'):
                body = re.sub(r'Tags\s*=\s*AnySurfaceCraft\s*,',
                              'Tags = AnySurfaceCraft;CanBeDoneFromFloor,', body)
            new = new[:start] + body + new[end:]
        write(path, old, new)

    # Данные книг: некоторые строки потеряли модуль; remove cover падал случайно.
    path = LUA / 'server/BooksHCExtra.lua'
    old = read_text(path)
    new = re.sub(r"'BookTailoring([1-5])'", r"'Base.BookTailoring\1'", old)
    write(path, old, new)
    # Пробел внутри ID — не косметика, CreateItem вернёт nil.
    path = LUA / 'server/JunkyardExtra.lua'
    old = read_text(path)
    new = re.sub(r"'(Base\.[^']+|Hydrocraft\.[^']+|Radio\.[^']+)\s+'", lambda m: "'" + m.group(1).strip() + "'", old)
    write(path, old, new)
    path = REPO / '.luarc.json'
    config = json.loads(read_text(path))
    if 'CharacterTrait' not in config['diagnostics']['globals']:
        config['diagnostics']['globals'].append('CharacterTrait')
        path.write_text(json.dumps(config, indent=2) + '\n', encoding='utf-8')


if __name__ == '__main__':
    main()

"""Применить проверенную карту моделей к WeaponSprite и WorldStaticModel."""
import json
import re
from hcr_paths import REPO, SCRIPTS, read_text
from apply_playability_fixes import blocks, write


def main():
    data = json.loads(read_text(REPO / 'tools/weapon_mapping.json'))
    mapping = data['mapping']
    custom = {m['name'] for m in data['required_models']}
    custom.update(['HCBoxcutter', 'HCCrossbow', 'HCHomemadebattrimmer', 'HCLongbow',
                   'HCQuarterstaffBarbedWire', 'HCQuarterstaffGrip', 'HCUzi'])
    for path in SCRIPTS.rglob('*.txt'):
        old = read_text(path)
        new = old
        for a, z, name, body in reversed(list(blocks(new, 'item'))):
            sprite = re.search(r'WeaponSprite\s*=\s*([^,\n]+)', body)
            if sprite and sprite[1].strip() in mapping:
                target = mapping[sprite[1].strip()]
                body = body[:sprite.start(1)] + target + body[sprite.end(1):]
            body = re.sub(r'WorldStaticModel\s*=\s*([^,\n]+)',
                          lambda m: 'WorldStaticModel = ' + ('Hydrocraft.' + m[1].strip()
                                    if m[1].strip() in custom else m[1].strip()), body)
            new = new[:a] + body + new[z:]
        write(path, old, new)
    path = SCRIPTS / 'HydrocraftReinvented/HCR_WeaponModels.txt'
    old = read_text(path)
    new = old
    for model in data['required_models']:
        if re.search(r'\bmodel\s+' + re.escape(model['name']) + r'\s*\{', new):
            continue
        declaration = '\n    model {name}\n    {{\n        mesh = {mesh},\n        texture = {texture},\n    }}\n'.format(**model)
        pos = new.rfind('}')
        new = new[:pos] + declaration + new[pos:]
    new = re.sub(r'/\*.*?\*/', '''/*
    WeaponSprite указывает на модель оружия в руках, WorldStaticModel — на
    модель размещения. Имена чувствительны к регистру. Кастомные ссылки
    квалифицируются модулем Hydrocraft; голое имя ищется в Base.
    Проверено по ModelManager/HandWeapon установленной B42.
*/''', new, count=1, flags=re.S)
    write(path, old, new)


if __name__ == '__main__':
    main()

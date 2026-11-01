"""Явные границы настроек: добыча отдельно от строительства, производство от уборки."""
import hashlib
import json
import re
from apply_playability_fixes import blocks
from convert_water_recipes import callback
from hcr_paths import LUA, REPO, SCRIPTS, read_text
from build_juice_catalog import lua

MANIFEST=REPO/'tools/sandbox_catalog.json'
GROUPS={
    'Cannabis': lambda name: not name.startswith('Clean '),
    'Meth': lambda name: True,
    'Opium': lambda name: True,
    'Tobacco': lambda name: name.startswith(('Dry Leaves','Grind Tobacco','Roll Cigar','Put Tobacco')),
}


def main():
    prior=json.loads(MANIFEST.read_text(encoding='utf-8')) if MANIFEST.exists() else {}
    recipes, items, callbacks={},{},{}
    for group,enabled in GROUPS.items():
        path=SCRIPTS/f'HydrocraftReinvented/HCR_Drugs {group}.txt'
        text=read_text(path)
        for _,_,name,_ in blocks(text,'item'):
            items['Hydrocraft.'+name]='Enable'+group
        for start,end,name,body in reversed(list(blocks(text,'craftRecipe'))):
            if not enabled(name):
                continue
            option='Enable'+group
            recipes[name]=option
            token=hashlib.sha256(name.encode()).hexdigest()[:12]
            body,old=callback(body,'OnTest','HCRSandbox.Test_'+token)
            if old=='HCRSandbox.Test_'+token:
                old=prior['callbacks'][token].get('previous')
            callbacks[token]={'name':name,'option':option,'previous':old or ''}
            text=text[:start]+body+text[end:]
        path.write_text(text,encoding='utf-8')
    mining=[]
    for _,_,name,body in blocks(read_text(SCRIPTS/'HydrocraftReinvented/HCR_Mining.txt'),'craftRecipe'):
        if re.search(r'OnCreate\s*=\s*HCR42\.(HCMine|HCDarkmine|HCShovelClay|HCSiftDirt|HCMineStone)\s*,',body) or name in ('Mine Iron','Mine Coal'):
            mining.append(name)
    catalog=dict(recipes=recipes,items=items,callbacks=callbacks,mining={name:True for name in mining})
    MANIFEST.write_text(json.dumps(catalog,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    lines=['-- Генерируется tools/build_sandbox_catalog.py.','HCRSandboxCatalog = {']
    for section,values in catalog.items():
        lines.append('    '+section+' = {')
        lines += ['        ['+lua(key)+'] = '+lua(value)+',' for key,value in sorted(values.items())]
        lines.append('    },')
    lines.append('}')
    (LUA/'shared/HCR_SandboxCatalog.lua').write_text('\n'.join(lines)+'\n',encoding='utf-8')
    print(f'Sandbox: {len(recipes)} production recipes; {len(items)} loot IDs; {len(mining)} extraction recipes')


if __name__=='__main__':
    main()

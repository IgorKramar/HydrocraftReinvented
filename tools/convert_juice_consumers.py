"""Явный каталог потребителей сока: общий литраж вместо use разных старых сосудов."""
import hashlib
import json
import re
from apply_playability_fixes import blocks
from build_juice_catalog import lua
from convert_water_recipes import callback
from hcr_paths import LUA,REPO,SCRIPTS,read_text

MANIFEST=REPO/'tools/juice_consumers.json'
LEGACY=re.compile(r'Hydrocraft\.HC(?:(?:Popbottle|Waterbottle|Remoulade|Mayonnaise|Whiskey|Clingmug)(?:lemon|lime|tomato)juice|(?:Lemon|Lime)juice(?:bowl|bottle))\b')


def main():
    rules=json.loads(MANIFEST.read_text(encoding='utf-8')) if MANIFEST.exists() else {}
    for path in sorted(SCRIPTS.rglob('*.txt')):
        text=read_text(path)
        original=text
        for start,end,name,body in reversed(list(blocks(text,'craftRecipe'))):
            inputs=re.search(r'inputs\s*\{([^}]*)\}',body)
            if not inputs:
                continue
            lines=re.findall(r'(?m)^\s*item [^\r\n]+',inputs[1])
            matches=[(slot,line) for slot,line in enumerate(lines) if LEGACY.search(line)]
            token=hashlib.sha256(name.encode()).hexdigest()[:12]
            if matches:
                assert len(matches)==1,(name,matches)
                slot,line=matches[0]
                assert re.search(r'item 1 \[',line) and 'ItemCount' not in line and 'mode:' not in line,name
                fluids=sorted({'HCRJuice'+flavour for flavour in ('Lemon','Lime','Tomato')
                               if flavour.lower() in line.lower()})
                assert fluids,name
                replacement='\n            item 1 [*] mode:keep flags[ItemIsFluid;HandcraftOnly],\n            -fluid 0.1 ['+';'.join(fluids)+'] mode:primary,'
                body=body.replace(line,replacement,1)
                removed_callback=None
                if name=='Make Bottle of Homemade Disinfectant':
                    assert 'OnCreate = HCR42.recipe_hcbowl,' in body
                    body=body.replace('        OnCreate = HCR42.recipe_hcbowl,\n','')
                    removed_callback='HCR42.recipe_hcbowl'
                rules[token]=dict(name=name,file=str(path.relative_to(SCRIPTS)).replace('\\','/'),
                    slots={str(slot):True},litres=.1,fluids=fluids,nutrition='fixed-output',
                    originalInput=line.strip(),removedCallback=removed_callback)
            if token in rules and 'HCRDrinkProducts.Create_' not in body:
                body,_=callback(body,'Tooltip','Tooltip_HCR_JuiceConsumer_'+token)
                text=text[:start]+body+text[end:]
        if text!=original:
            path.write_text(text,encoding='utf-8')
    assert len(rules)==21,len(rules)
    MANIFEST.write_text(json.dumps(rules,ensure_ascii=False,indent=2,sort_keys=True)+'\n',encoding='utf-8')
    by_name={r['name']:{**r,'slots':{int(k):v for k,v in r['slots'].items()}} for r in rules.values()}
    (LUA/'shared/HCR_FluidRecipeRules.lua').write_text(
        '-- Генерируется tools/convert_juice_consumers.py.\nHCRFluidRecipeRules = '+lua(by_name)+'\n',encoding='utf-8')
    for lang in ('EN','RU'):
        path=LUA/f'shared/Translate/{lang}/Tooltip.json'
        translations=json.loads(path.read_text(encoding='utf-8'))
        for token in rules:
            translations['Tooltip_HCR_JuiceConsumer_'+token]=(
                'Uses 0.1 L of the specified juice; dilution with clean water is allowed. Other mixtures are unsuitable. The juice container is retained.' if lang=='EN' else
                'Расход указанного сока: 0,1 л; допускается разбавление чистой водой. Другие смеси не подходят. Сосуд с соком сохраняется.')
        path.write_text(json.dumps(translations,ensure_ascii=False,indent=4)+'\n',encoding='utf-8')
    print(f'juice consumers={len(rules)}; required juice=0.1 L per recipe')


if __name__=='__main__': main()

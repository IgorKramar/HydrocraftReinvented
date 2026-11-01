"""Inventory actual water-marked items; do not equate food returns with fluids."""
import argparse,json,re
from pathlib import Path
from apply_playability_fixes import blocks
from hcr_paths import SCRIPTS,read_text

def audit():
    items=[];recipes=[]
    for path in sorted(SCRIPTS.rglob('*.txt')):
        text=read_text(path)
        for _,_,name,body in blocks(text,'item'):
            def prop(key):
                match=re.search(r'(?im)^\s*'+key+r'\s*=\s*([^,\r\n]+)',body)
                return match[1].strip() if match else None
            if (prop('CanStoreWater') or '').lower()!='true':continue
            items.append({'id':'Hydrocraft.'+name,'file':path.name,'type':prop('ItemType'),
                'native_fluid':bool(re.search(r'component\s+FluidContainer\b',body)),
                'water_source':(prop('IsWaterSource') or '').lower()=='true',
                'use_delta':prop('UseDelta'),'fill_target':prop('ReplaceOnUseOn'),
                'deplete_target':prop('ReplaceOnDeplete')})
        recipes.extend((path.name,name,body) for _,_,name,body in blocks(text,'craftRecipe'))
    legacy=[r for r in items if not r['native_fluid']]
    ids={r['id'].split('.',1)[1] for r in legacy}
    references=[]
    for filename,name,body in recipes:
        found=ids & set(re.findall(r'\bHydrocraft\.([A-Za-z0-9_]+)',body))
        if found:references.append({'file':filename,'recipe':name,'items':sorted(found)})
    return {'summary':{'water_marked':len(items),'native_water_marked':len(items)-len(legacy),
        'legacy_water_marked':len(legacy),'legacy_water_sources':sum(r['water_source'] for r in legacy),
        'direct_legacy_recipes':len(references)},'items':items,'recipes':references}

if __name__=='__main__':
    ap=argparse.ArgumentParser(description=__doc__);ap.add_argument('--out',type=Path)
    args=ap.parse_args();result=audit()
    if args.out:args.out.write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print(json.dumps(result['summary'],ensure_ascii=False))

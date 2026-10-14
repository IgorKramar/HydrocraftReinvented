"""Indirect HC producers from the current shared timer table and recipe callbacks."""
import re
from collections import defaultdict
from apply_playability_fixes import blocks
from hcr_paths import LUA, SCRIPTS, read_text


def timer_edges(lua_root=LUA):
    source=read_text(lua_root/'shared/HCR_TimedDefinitions.lua')
    return dict(re.findall(r'\["([\w.]+)"\]\s*=\s*\{[^}]*target\s*=\s*"([\w.]+)"',source))


def callback_outputs(scripts=SCRIPTS,lua_root=LUA):
    """Literal AddItem(s) outputs only; do not turn a callback's input IDs into loot."""
    functions={}
    for path in lua_root.rglob('*.lua'):
        source=read_text(path)
        starts=list(re.finditer(r'^\s*function\s+([\w.]+)\s*\(',source,re.M))
        for index,start in enumerate(starts):
            end=starts[index+1].start() if index+1<len(starts) else len(source)
            body=source[start.start():end]
            functions[start[1]]=set(re.findall(r':AddItems?\s*\(\s*["\']([\w]+\.[\w]+)["\']',body))
    bridge=read_text(lua_root/'server/zzz_HCR42_RecipeCode.lua')
    aliases=dict(re.findall(r'HCR42\["([^"]+)"\]\s*=\s*wrap\("([^"]+)"\)',bridge))
    result=defaultdict(set)
    for path in scripts.rglob('*.txt'):
        for _,_,name,body in blocks(read_text(path),'craftRecipe'):
            call=re.search(r'\bOnCreate\s*=\s*([\w.]+)',body)
            if not call:continue
            callback=call[1]
            if callback.startswith('HCR42.'):
                callback=aliases.get(callback.split('.',1)[1],callback)
            outputs=functions.get(callback,set())
            if outputs:result[name].update(outputs)
    return dict(result)


def apply_timer_edges(reachable,edges,declared):
    """One step; callers repeat their recipe/timer fixed point until unchanged."""
    additions={target for source,target in edges.items() if source in reachable and target in declared}
    before=len(reachable)
    reachable.update(additions)
    return len(reachable)!=before

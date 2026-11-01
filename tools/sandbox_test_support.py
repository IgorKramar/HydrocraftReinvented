"""Загрузка реальных Sandbox модулей в автономных Lua-регрессиях."""
from hcr_paths import LUA, read_text


def load_sandbox(lua, loot=False):
    lua.execute('function require(_) end')
    for name in ('HCR_SandboxCatalog','HCR_Sandbox'):
        lua.execute(read_text(LUA/f'shared/{name}.lua'))
    if loot:
        lua.execute('''
            Events=Events or {}
            Events.OnInitGlobalModData={Add=function(fn) initSandboxLoot=fn end}
            Events.OnTickEvenPaused={Add=function() end}
            function isClient() return false end
            IsoWorld={parseDistributions=function() parses=(parses or 0)+1 end}
        ''')
        lua.execute(read_text(LUA/'server/HCR_SandboxLoot.lua'))

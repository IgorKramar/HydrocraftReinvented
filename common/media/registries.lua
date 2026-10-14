-- Native 42.21 loads this file before scripts on both clients and servers.
-- Do not register in shared Lua: item/recipe tag caches would already be built.
for _, name in ipairs({"potato", "roastingpanfull", "serveinpaperbag", "paperbagfull",
                      "nylonbag", "cereal", "shit", "disinfectant", "huntingshotgun"}) do
    local id = "hydrocraft:" .. name
    if not ItemTag.get(ResourceLocation.of(id)) then ItemTag.register(id) end
end

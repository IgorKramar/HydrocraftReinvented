-- Stage as HCRLabInputTags.lua. Prove eligibility once per unique selector,
-- rather than crafting every recipe or treating any literal tag as available.
HCRLabInputTags = HCRLabInputTags or {}
function HCRLabInputTags.run(profile)
    assert(profile == "HCRLab", "explicit private lab token required")
    local all, recipes, groups = getScriptManager():getAllItems(), getScriptManager():getAllCraftRecipes(), {}
    for i = 0, recipes:size() - 1 do
        local recipe = recipes:get(i)
        local module = recipe:getModule()
        if module and module:getName() == "Hydrocraft" then
            local inputs = recipe:getInputs()
            for j = 0, inputs:size() - 1 do
                local input = inputs:get(j)
                local line = input:getOriginalLine()
                local tags = line:match("tags%[([^%]]+)%]")
                if tags then
                    local named = line:match("item%s+[%d%.]+%s+(%[[^%]]+%])") or ""
                    local key = named .. " tags[" .. tags .. "]"
                    if not groups[key] then groups[key] = {input=input,tags=tags,recipes=0} end
                    groups[key].recipes = groups[key].recipes + 1
                end
            end
        end
    end
    local total, failures = 0, 0
    for key, group in pairs(groups) do
        total = total + 1
        local registered = true
        for token in group.tags:gmatch("[^;]+") do
            token = token:match("^%s*(.-)%s*$")
            if not ItemTag.get(ResourceLocation.of(token)) then registered = false end
        end
        local count, examples = 0, {}
        for i = 0, all:size() - 1 do
            local item = all:get(i)
            if group.input:containsItem(item) then
                count = count + 1
                if #examples < 4 then examples[#examples + 1] = item:getFullName() end
            end
        end
        local ok = registered and count > 0
        if not ok then failures = failures + 1 end
        print("[HCRLabInputTags] " .. key .. " " .. (ok and "PASS" or "FAIL")
            .. " registered=" .. tostring(registered) .. " eligible=" .. count
            .. " recipes=" .. group.recipes .. " sample=" .. table.concat(examples, ","))
    end
    print("[HCRLabInputTags] groups=" .. total .. " failures=" .. failures)
    return failures
end

-- Explicit native-client checks for an isolated HCR lab save. No event hooks.
-- Load this helper, then call HCRLabBooks.verifyNativeComplete(getPlayer()).
-- This invokes native ISReadABook:complete(), not the timed reading UI path.
require "TimedActions/ISReadABook"

HCRLabBooks = HCRLabBooks or {}

function HCRLabBooks.spawn(player, fullType)
    assert(player, "An explicit lab player is required")
    fullType = fullType or "Hydrocraft.HCBookarmorcrafting"
    local book = player:getInventory():AddItem(fullType)
    assert(book and book:getCategory() == "Literature", "Book did not instantiate as Literature")
    local recipes = book:getLearnedRecipes()
    assert(recipes and recipes:size() > 0, "Spawned book has no LearnedRecipes")
    print("[HCRLabBooks] " .. fullType .. " taught=" .. recipes:size()
        .. " pages=" .. book:getNumberOfPages()
        .. " title=" .. tostring(book:getModData().literatureTitle))
    return book
end

function HCRLabBooks.verifyNativeComplete(player, fullType)
    assert(not isClient(), "Run this check in a local lab game or authoritative server")
    local book = HCRLabBooks.spawn(player, fullType)
    local recipes = book:getLearnedRecipes()
    local recipe = recipes:get(0)
    local known = player:getKnownRecipes()
    local wasKnown = known:contains(recipe)
    -- Guarantee a negative control even when repeating the check in the lab.
    -- Restore this recipe on failure so the helper cannot erase existing knowledge.
    if wasKnown then known:remove(recipe) end
    assert(not known:contains(recipe), "Could not establish an unlearned recipe control")
    local ok, errorMessage = pcall(function()
        local action = ISReadABook:new(player, book)
        assert(action:complete() == true, "Native read completion did not succeed")
        assert(known:contains(recipe), "Native completion failed to teach " .. recipe)
        for i = 0, recipes:size() - 1 do
            assert(known:contains(recipes:get(i)), "Missing learned recipe " .. recipes:get(i))
        end
    end)
    if not ok then
        if wasKnown and not known:contains(recipe) then player:learnRecipe(recipe) end
        print("[HCRLabBooks] FAIL " .. tostring(errorMessage))
        error(errorMessage)
    end
    print("[HCRLabBooks] PASS native complete taught " .. recipes:size()
        .. " recipes; negative control=" .. recipe)
    -- Leave the spawned item available for a separate real tooltip/reading UI check.
    return book
end

return HCRLabBooks

-- API черт B42 принимает CharacterTrait, а не строки из списка B41.
HCR = HCR or {}

function HCR.hasTrait(character, legacyName)
    if not character then return false end
    local names = {Lucky = "LUCKY", Herbalist = "HERBALIST"}
    local trait = CharacterTrait and CharacterTrait[names[legacyName] or legacyName]
    if trait and character.hasTrait then
        return character:hasTrait(trait)
    end
    -- Lucky удалён из некоторых сборок B42: бонуса нет, действие продолжается.
    return false
end

---@class ArmourSetup : ToolClass
ArmourSetup = class()

local armour = {
    {
        uuid = sm.uuid.new("d39d911c-280b-429e-8168-2c6db39c4eaf"),
        slot = "head",
        renderable = "$CONTENT_DATA/Characters/Renderable/char_helldiver_armour_helmet.rend",
        stats = {
            damageReduction = 0.15
        },
        setId = "Helldiver"
    },
    {
        uuid = sm.uuid.new("f4aada57-e8ac-4a54-ba79-6cdb9d73f039"),
        slot = "torso",
        renderable = "$CONTENT_DATA/Characters/Renderable/char_helldiver_armour_chestplate.rend",
        stats = {
            damageReduction = 0.25
        },
        setId = "Helldiver"
    },
    {
        uuid = sm.uuid.new("2592e8f0-2bab-4f4f-b153-1566717ab42e"),
        slot = "leg",
        renderable = "$CONTENT_DATA/Characters/Renderable/char_helldiver_armour_leggings.rend",
        stats = {
            damageReduction = 0.25
        },
        setId = "Helldiver"
    },
    {
        uuid = sm.uuid.new("37eac317-fff1-47b7-86d0-e67c31cdf09a"),
        slot = "foot",
        renderable = "$CONTENT_DATA/Characters/Renderable/char_helldiver_armour_boots.rend",
        stats = {
            damageReduction = 0.15
        },
        setId = "Helldiver"
    }
}

function ArmourSetup:server_onCreate()
    if setupComplete then return end

    for k, v in pairs(armour) do
        sm.crashlander.addEquipment(v.uuid, v.slot, v.renderable, v.stats)
    end

    setupComplete = true
end

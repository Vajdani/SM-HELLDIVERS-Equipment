sm.log.info("[HELLDIVERS] Override script loaded")

local projectile_stratagem = sm.uuid.new("6411767a-8882-4b94-aae5-381057cde9f9")

---@param worldScript WorldClass
local function setupProjectiles(worldScript)
    local oldProjectile = worldScript.server_onProjectile
    function projectileHook(world, position, airTime, velocity, projectileName, shooter, damage, customData, normal, target, uuid)
        if uuid == projectile_stratagem then
            sm.event.sendToTool(sm.HELLDIVERSBACKEND, "OnStratagemHit",
                {
                    position = position,
                    normal = normal,
                    shooter = shooter,
                    data = customData
                }
            )
        end

        return oldProjectile(world, position, airTime, velocity, projectileName, shooter, damage, customData, normal, target, uuid)
    end
    worldScript.server_onProjectile = projectileHook
end


for k, obj in pairs(_G) do
    if type(obj) == "table" and obj.cellMaxX then
        sm.log.info("[HELLDIVERS] Hooking projectile function...")
        setupProjectiles(obj)
    end
end
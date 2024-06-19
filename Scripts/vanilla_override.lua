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
    if type(obj) == "table" then
        if obj.cellMaxX and not obj.PROJECTILESETUPCOMPLETE then
            sm.log.info("[HELLDIVERS] Hooking projectile function...")
            setupProjectiles(obj)
            obj.PROJECTILESETUPCOMPLETE = true
        elseif obj.server_onUnitUpdate then
            sm.log.info("[HELLDIVERS] Adding external takeDamage to unit...")
            obj.sv_e_takeDamage = function(obj, args)
                obj:sv_takeDamage(args.damage or 0, args.impact or sm.vec3.zero(), args.hitPos or obj.unit.character.worldPosition)
            end
        elseif obj.server_onShapeRemoved then
            sm.log.info("[HELLDIVERS] Adding external takeDamage to player...")
            obj.sv_e_takeDamage = function(obj, args)
                obj:sv_takeDamage(args.damage or 0, args.source or "impact")
            end
        end
    end
end



local playerPaths = {
    ["$GAME_DATA/Scripts/game/CreativePlayer.lua"] = "CreativePlayer",
    ["$SURVIVAL_DATA/Scripts/game/SurvivalPlayer.lua"] = "SurvivalPlayer",
    ["$CONTENT_DATA/Scripts/Player.lua"] = "Player",
}
oldDofile = oldDofile or dofile
local function dofileHook(path)
    oldDofile(path)

    local class = playerPaths[path]
    if class then
        sm.log.warning("[HELLDIVERS] Adding external takeDamage to player...")
        _G[class].sv_e_takeDamage = function(self, args)
            self:sv_takeDamage(args.damage or 0, args.source or "impact")
        end
    end
end
dofile = dofileHook



dofile "$GAME_DATA/Scripts/game/interactable/Package.lua"
function Package.sv_tryUnpack( self, delete )
    if not self.destroyed and self.shape.body.destructable then
        self.destroyed = true

        if not delete then
            sm.shape.destroyPart( self.shape )
        end

        return self:sv_unpack()
    end
end

function Package.sv_unpack( self )
    sm.effect.playEffect( self.data.unboxEffect01, self.shape.worldPosition, nil, self.shape.worldRotation, sm.vec3.new(1,1,1), { Color = self.shape.color } )

    local yaw = math.atan2( self.shape.up.y, self.shape.up.x ) - math.pi / 2
    local zShapeOffset = math.abs( ( self.shape.worldRotation * sm.item.getShapeOffset( self.shape.uuid ) ).z )
    local spawnOffset = sm.vec3.new( 0, 0, -zShapeOffset )
    return sm.unit.createUnit( sm.uuid.new( self.data.unitUuid ), self.shape.worldPosition + spawnOffset, yaw, { color = self.shape.color } )
end

function Package.sv_e_open( self, delete )
    local unit = self:sv_tryUnpack(delete)
    if delete then
        sm.event.sendToInteractable(self.interactable, "delay", unit)
    end
end

function Package:delay(unit)
    if unit and not sm.event.sendToUnit(unit, "sv_e_takeDamage", { damage = 999999999 }) then
        sm.event.sendToInteractable(self.interactable, "delay", unit)
        return
    end

    sm.shape.destroyPart( self.shape )
end
sm.log.info("[HELLDIVERS] Override script loaded")

local ToolItems = {
	["552b4ced-ca96-4a71-891c-ab54fe9c6873"] = sm.uuid.new("d48e6383-200a-4aa8-9901-47fdf7969ad9"), --HMG
}

oldGetToolProxyItem = oldGetToolProxyItem or GetToolProxyItem
local function getToolProxyItemHook( toolUuid )
	local item = oldGetToolProxyItem( toolUuid )
	if not item then
		item = ToolItems[tostring( toolUuid )]
	end

	return item
end
GetToolProxyItem = getToolProxyItemHook

if _GetToolProxyItem then
	oldGetToolProxyItem2 = oldGetToolProxyItem2 or _GetToolProxyItem
	local function getToolProxyItemHook2( toolUuid )
		local item = oldGetToolProxyItem2( toolUuid )
		if not item then
			item = ToolItems[tostring( toolUuid )]
		end

		return item
	end
	_GetToolProxyItem = getToolProxyItemHook2
end

if FantGetToolProxyItem then
	oldGetToolProxyItem3 = oldGetToolProxyItem3 or FantGetToolProxyItem
	local function getToolProxyItemHook3( toolUuid )
		local item = oldGetToolProxyItem3( toolUuid )
		if not item then
			item = ToolItems[tostring( toolUuid )]
		end

		return item
	end
	FantGetToolProxyItem = getToolProxyItemHook3
end


local bounceShapes = {}
for k, shape in pairs(sm.json.open("$CONTENT_e35b1c4e-d434-4102-88bf-95a16b8cff7d/Objects/Database/ShapeSets/dropPods.shapeset").partList) do
    bounceShapes[shape.uuid] = true
end

local projectile_stratagem = sm.uuid.new("6411767a-8882-4b94-aae5-381057cde9f9")

---@param worldScript WorldClass
local function setupProjectiles(worldScript)
    if worldScript or worldScript.PROJECTILESETUPCOMPLETE then return end

    local oldProjectile = worldScript.server_onProjectile
    function projectileHook(world, position, airTime, velocity, projectileName, shooter, damage, customData, normal, target, uuid)
        if uuid == projectile_stratagem then
            local bounce = false
            local type = type(target)
            if type == "Shape" and sm.exists(target) then
                bounce = bounceShapes[tostring(target.uuid)] == true
            elseif type == "Character" then
                bounce = true
            else
                bounce = normal.z <= 0.5
            end

            if bounce then
                if customData.bouncesLeft > 0 then
                    customData.bouncesLeft = customData.bouncesLeft - 1
                    sm.projectile.customProjectileAttack(customData, sm.uuid.new("6411767a-8882-4b94-aae5-381057cde9f9"), 0, position, normal * 10, shooter )
                end

                return
            end

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
    worldScript.PROJECTILESETUPCOMPLETE = true
end


for k, obj in pairs(_G) do
    if type(obj) == "table" then
        if obj.cellMaxX and not obj.PROJECTILESETUPCOMPLETE then
            sm.log.info("[HELLDIVERS] Hooking projectile function...")
            setupProjectiles(obj)
        elseif obj.server_onUnitUpdate then
            sm.log.info("[HELLDIVERS] Adding external takeDamage to unit...")
            obj.sv_e_takeDamage = function(obj, args)
                obj:sv_takeDamage(args.damage or 0, args.impact or sm.vec3.zero(), args.hitPos or obj.unit.character.worldPosition)
            end
        end
    end
end



local hooks = {
    ["BasePlayer"] = function(class)
        class.sv_e_takeDamage = function(self, args)
            self:sv_takeDamage(args.damage or 0, args.source or "impact")
        end
    end,
    ["BaseWorld"] = setupProjectiles,
    ["CreativeBaseWorld"] = setupProjectiles,
}
oldDofile = oldDofile or dofile
local function dofileHook(path)
    oldDofile(path)

    for k, v in pairs(hooks) do
        if path:find(k) then
            sm.log.info("[HELLDIVERS] Adding hook to", path)
            v(_G[k])
            break
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
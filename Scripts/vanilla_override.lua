---@diagnostic disable:inject-field

sm.log.info("[HELLDIVERS] Override script loaded")

local ToolItems = {
	["552b4ced-ca96-4a71-891c-ab54fe9c6873"] = sm.uuid.new("d48e6383-200a-4aa8-9901-47fdf7969ad9"), --HMG
    ["b3ad837a-2235-476e-9408-4b5321b1032f"] = sm.uuid.new("eac17336-0356-4a9f-b531-a6d44391a83b"), --AutoCannon
    ["e3b77d7e-05b6-493c-b6c3-a264f342519a"] = sm.uuid.new("7705f920-b4cb-41f7-8a9c-088539201c35"), --Stratagem
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
local canExplode = {
    ["07b1550e-e844-4bbe-b1c3-99e77e097965"] = {
        level = 6,
        destructionRadius = 0.5,
        impulseRadius = 1,
        magnitude = 15,
    } --AutoCannon
}

---@param worldScript WorldClass
local function setupProjectiles(worldScript, classname)
    if not worldScript then return end

    local id = "helldivers_"..classname.."_server_onProjectile"
    _G[id] = _G[id] or worldScript.server_onProjectile

    function worldScript.server_onProjectile(world, position, airTime, velocity, projectileName, shooter, damage, customData, normal, target, uuid)
        if uuid == projectile_stratagem then
            local bounce = false
            local type = type(target)
            if type == "Shape" and sm.exists(target) then
                bounce = bounceShapes[tostring(target.uuid)] == true --or sm.item.getQualityLevel(target.uuid) == 1
            elseif type == "Character" then
                bounce = true
            end

            bounce = bounce or normal.z <= 0.75

            if bounce then
                if customData.bouncesLeft > 0 then
                    customData.bouncesLeft = customData.bouncesLeft - 1
                    -- sm.projectile.customProjectileAttack(customData, projectile_stratagem, 0, position, normal * 10, shooter --[[@as Player]])

                    local vel = -velocity:normalize()
                    local cross = vel:cross(normal)
                    sm.projectile.customProjectileAttack(
                        customData, projectile_stratagem, 0, position,
                        normal:rotate(math.atan2(cross:length(), normal:dot(vel)), cross) * (velocity:length() * 0.25),
                        shooter --[[@as Player]]
                    )
                else
                    sm.event.sendToTool(sm.HELLDIVERSBACKEND, "OnStratagemTimedOut",
                        {
                            player = shooter,
                            code = customData.code
                        }
                    )
                end

                return
            end

            local dir = position - customData.origin; dir.z = 0
            sm.event.sendToTool(sm.HELLDIVERSBACKEND, "OnStratagemHit",
                {
                    position = position,
                    throwDirection = dir:normalize(),
                    normal = normal,
                    shooter = shooter,
                    data = customData
                }
            )
        elseif canExplode[tostring(uuid)] ~= nil then
            local data = canExplode[tostring(uuid)]
            sm.physics.explode(position, data.level, data.destructionRadius, data.impulseRadius, data.magnitude, data.effect, nil, data.params)
        end

        return _G[id](world, position, airTime, velocity, projectileName, shooter, damage, customData, normal, target, uuid)
    end
end


for k, obj in pairs(_G) do
    if type(obj) == "table" then
        if obj.cellMaxX and not obj.PROJECTILESETUPCOMPLETE then
            sm.log.info("[HELLDIVERS] Hooking projectile function...")
            setupProjectiles(obj, k)
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
            v(_G[k], k)
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



dofile( "$SURVIVAL_DATA/Scripts/game/managers/WaterManager.lua" )

function WaterManager:trigger_onProjectile(trigger, hitPos, hitTime, hitVelocity, _, attacker, damage, userData, hitNormal, projectileUuid)
    if projectileUuid == projectile_stratagem then
        return true
    end

	sm.effect.playEffect( "Projectile - HitWater", hitPos )
	return false
end
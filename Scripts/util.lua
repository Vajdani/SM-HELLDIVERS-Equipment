-- #region Setup
dofile("$CONTENT_DATA/Scripts/AnimationUtil.lua")
dofile "$CONTENT_DATA/Scripts/ProgressBar.lua"
dofile "tools/BaseGun.lua"
dofile("ProgressBar.lua")
dofile("VideoPlayer.lua")
dofile "StratagemDatabase.lua"
-- #endregion


STRATAGEMTYPETOCOLOUR = {
    supply    = sm.color.new("#00ffff"),
    mission   = sm.color.new("#00ffff"), --sm.color.new(1,1,0),
    defensive = sm.color.new("#00ff00"),
    offensive = sm.color.new("#ff0000"),
}

FIREMODESETTINGS_ALL = {
    {
		name = "Semi-Automatic",
		icon = "challenge_missing_icon_large.png"
	},
	{
		name = "Automatic",
		icon = "challenge_missing_icon_large.png"
	},
	{
		name = "Burst",
		icon = "challenge_missing_icon_large.png"
	}
}

FLASHLIGHTSETTINGS_ALL = {
    {
		name = "On",
		icon = "challenge_missing_icon_large.png"
	},
	{
		name = "Auto",
		icon = "challenge_missing_icon_large.png"
	},
	{
		name = "Off",
		icon = "challenge_missing_icon_large.png"
	}
}

STRATAGEMINVENTORYSIZE = 6
STRATAGEMMAXBOUNCEOUNT = 3
PLAYERDATAPATH = "$CONTENT_DATA/playerData.json"
SHOWSTRATAGEMCOOLDOWNTIME = 10
SHOWSTRATAGEMUSAGETIME = 5 * 40

MAXAIMDRAGANGLE = math.rad(30)

vec3_new     = sm.vec3.new
vec3_right   = vec3_new(1,0,0)
vec3_forward = vec3_new(0,1,0)
vec3_up      = vec3_new(0,0,1)
vec3_zero    = sm.vec3.zero()
vec3_one     = sm.vec3.one()

quat_identity = sm.quat.identity()

util_clamp = sm.util.clamp
util_lerp = sm.util.lerp

max = math.max

projectile_stratagem = sm.uuid.new("6411767a-8882-4b94-aae5-381057cde9f9")

dropPodRotation = sm.quat.angleAxis(math.rad(90), vec3_right)

indexToArrow = {
    ["1"] = "icon_keybinds_arrow_left.png",
    ["2"] = "icon_keybinds_arrow_right.png",
    ["3"] = "icon_keybinds_arrow_up.png",
    ["4"] = "icon_keybinds_arrow_down.png"
}

function GetRealLength(table)
    local count = 0
    for k, v in pairs(table) do
        count = count + 1
    end

    return count
end

function CreateEffect(data)
    local effect
    if type(data) == "string" then
        effect = sm.effect.createEffect(data)
    else
        effect = sm.effect.createEffect("ShapeRenderable")
        effect:setParameter("uuid", data)
    end

    return effect
end

function FormatStratagemTimer( seconds )
	local time = seconds / DAYCYCLE_TIME
	local minute = ( time * 24 ) % 24
	local second = ( minute % 1 ) * 60
	local minute1 = math.floor( minute / 10 )
	local minute2 = math.floor( minute - minute1 * 10 )
	local second1 = math.floor( second / 10 )
	local second2 = math.floor( second - second1 * 10 )
	return minute1..minute2..":"..second1..second2
end

function GetRandomStratagemCode()
    local code = ""
    for i = 1, math.random(4, 8) do
        code = code..math.random(1, 4)
    end

    return code
end

function GetFpBoneDir(tool, bone)
    local endPos = tool:getFpBonePos(bone.."_end")
    if endPos == vec3_zero then
        return tool:getDirection()
    end

	return (endPos - tool:getFpBonePos(bone)):normalize()
end

function GetYawPitch( direction )
    return math.atan2(direction.y, direction.x) - math.pi/2, math.asin(direction.z)
end

--https://github.com/godotengine/godot/blob/c6d130abd9188f313e6701d01a0ddd6ea32166a0/core/math/math_defs.h#L43
local TAU = 6.2831853071795864769252867666

--https://github.com/godotengine/godot/blob/c6d130abd9188f313e6701d01a0ddd6ea32166a0/core/math/math_funcs.h#L482
function AngleDifference(p_from, p_to)
	local difference = math.fmod(p_to - p_from, TAU);
	return math.fmod(2.0 * difference, TAU) - difference;
end

--https://github.com/godotengine/godot/blob/c6d130abd9188f313e6701d01a0ddd6ea32166a0/core/math/vector3.h#L313
function AngleTo(p_from, p_to)
	local cross = p_from:cross(p_to)
	return math.atan2(cross:length(), p_from:dot(p_to)), cross
end

function GetInventory()
	return
		sm.game.getLimitedInventory() and
		sm.localPlayer.getPlayer():getInventory() or
		sm.localPlayer.getPlayer():getHotbar()
end



-- #region Base game variables
blk_wood1 = sm.uuid.new( "df953d9c-234f-4ac2-af5e-f0490b223e71" )
obj_containers_woodbox = sm.uuid.new( "c3990931-b471-4e89-beb5-0baaef47f0af" )

DAYCYCLE_TIME = 1440.0 -- seconds (24 minutes)

projectile_potato = sm.uuid.new( "5e8eeaae-b5c1-4992-bb21-dec5254ce722" )
projectile_smallpotato = sm.uuid.new( "132c44d3-7436-419d-ac6b-fc178336dcb7" )
projectile_explosivetape = sm.uuid.new( "31b92b9a-a9f8-4f6d-988b-04ad479978ec" )
projectile_loot = sm.uuid.new( "45209992-1a59-479e-a446-57140b605836" )
projectile_epicloot = sm.uuid.new( "17cd4768-3123-4ce3-835a-362321dcf9de" )

function Round( value )
	return math.floor( value + 0.5 )
end

function IsAnyOf(is, off)
	for _, v in pairs(off) do
		if is == v then
			return true
		end
	end
	return false
end

function ShallowCopy( orig )
	local orig_type = type( orig )
	local copy
	if orig_type == 'table' then
		copy = {}
		for orig_key, orig_value in pairs( orig ) do
			copy[orig_key] = orig_value
		end
	else -- number, string, boolean, etc
		copy = orig
	end
	return copy
end

function SpawnLoot( origin, lootList, worldPosition, ringAngle )

	if worldPosition == nil then
		if type( origin ) == "Shape" then
			worldPosition = origin.worldPosition
		elseif type( origin ) == "Player" or type( origin ) == "Unit" then
			local character = origin:getCharacter()
			if character then
				worldPosition = character.worldPosition
			end
		elseif type( origin ) == "Harvestable" then
			worldPosition = origin.worldPosition
		end
	end

	ringAngle = ringAngle or math.pi / 18

	if worldPosition then
		for i = 1, #lootList do
			local dir
			local up
			if type( origin ) == "Shape" then
				dir = sm.vec3.new( 1.0, 0.0, 0.0 )
				up = sm.vec3.new( 0, 1, 0 )
			else
				dir = sm.vec3.new( 0.0, 1.0, 0.0 )
				up = sm.vec3.new( 0, 0, 1 )
			end

			local firstCircle = 6
			local secondCircle = 13
			local thirdCircle = 26

			if i < 6 then
				local divisions = ( firstCircle - ( firstCircle - math.min( #lootList, firstCircle - 1 ) ) )
				dir = dir:rotate( i * 2 * math.pi / divisions, up )
				local right = dir:cross( up )
				dir = dir:rotate( math.pi / 2 - ringAngle, right )
			elseif i < 13 then
				local divisions = ( secondCircle - ( secondCircle - math.min( #lootList - firstCircle + 1, secondCircle - firstCircle ) ) )
				dir = dir:rotate( i * 2 * math.pi / divisions, up )
				local right = dir:cross( up )
				dir = dir:rotate( math.pi / 2 - 2 * ringAngle, right )
			elseif i < 26 then
				local dvisions = ( thirdCircle - ( thirdCircle - math.min( #lootList - secondCircle + 1, thirdCircle - secondCircle ) ) )
				dir = dir:rotate( i * 2 * math.pi / dvisions, up )
				local right = dir:cross( up )
				dir = dir:rotate( math.pi / 2 - 4 * ringAngle, right )
			else
				-- Out of predetermined room, place randomly
				dir = dir:rotate( math.random() * 2 * math.pi, up )
				local right = dir:cross( up )
				dir = dir:rotate( math.pi / 2 - ringAngle - math.random() * ( 3 * ringAngle ), right )
			end

			local loot = lootList[i]
			local params = { lootUid = loot.uuid, lootQuantity = loot.quantity or 1, epic = loot.epic }
			local vel = dir * (4+math.random()*2)
			local projectileUuid = loot.epic and projectile_epicloot or projectile_loot
			if type( origin ) == "Shape" then
				sm.projectile.shapeCustomProjectileAttack( params, projectileUuid, 0, sm.vec3.new( 0, 0, 0 ), vel, origin, 0 )
			elseif type( origin ) == "Player" or type( origin ) == "Unit" then
				sm.projectile.customProjectileAttack( params, projectileUuid, 0, worldPosition, vel, origin, worldPosition, worldPosition, 0 )
			elseif type( origin ) == "Harvestable" then
				sm.projectile.harvestableCustomProjectileAttack( params, projectileUuid, 0, worldPosition, vel, origin, 0 )
			end
		end
	end
end
-- #endregion
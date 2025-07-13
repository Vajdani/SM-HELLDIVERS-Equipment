STRATAGEMTYPETOCOLOUR = {
    supply    = sm.color.new(0,1,1),
    mission   = sm.color.new(1,1,0),
    defensive = sm.color.new(0,1,0),
    offensive = sm.color.new(1,0,0),
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

MAXAIMDRAGANGLE = math.rad(30)

vec3_new     = sm.vec3.new
vec3_right   = vec3_new(1,0,0)
vec3_forward = vec3_new(0,1,0)
vec3_up      = vec3_new(0,0,1)
vec3_zero    = sm.vec3.zero()
vec3_one     = sm.vec3.one()

quat_identity = sm.quat.identity()

dropPodRotation = sm.quat.angleAxis(math.rad(90), vec3_right)

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



-- local function minQuatDifference( q1, q2 )
-- 	local minusDiff = math.max(
-- 		math.abs( q1.x - q2.x ),
-- 		math.abs( q1.y - q2.y ),
-- 		math.abs( q1.z - q2.z ),
-- 		math.abs( q1.w - q2.w )
-- 	)
-- 	local plusDiff = math.max(
-- 		math.abs( q1.x + q2.x ),
-- 		math.abs( q1.y + q2.y ),
-- 		math.abs( q1.z + q2.z ),
-- 		math.abs( q1.w + q2.w )
-- 	)
-- 	return min( minusDiff, plusDiff )
-- end

-- function getCameraMode( shapeRot )
-- 	local rotation = sm.camera.getRotation() * sm.quat.inverse( sm.camera.getDefaultRotation() )
-- 	local freeDiff = minQuatDifference( rotation, sm.quat.identity() )
-- 	local followDiff = minQuatDifference( rotation, sm.util.axesToQuat( shapeRot * vec3_up, vec3_up ) )
-- 	local strictDiff = minQuatDifference( rotation, shapeRot * sm.util.axesToQuat( -vec3_right, vec3_forward ) )

-- 	local lowestDiff, mode = freeDiff, "Free"
-- 	if followDiff < lowestDiff then
-- 		lowestDiff, mode = followDiff, "Follow"
-- 	end
-- 	if strictDiff < lowestDiff then
-- 		lowestDiff, mode = strictDiff, "Strict"
-- 	end

-- 	return mode
-- end


-- function getCameraCenter( mode, shapePos, shapeRot )
--   	if mode == "Strict" then
--    		return shapePos + shapeRot * sm.vec3.new( 0.0, 0.575, 0.0 )
--   	else
--     	return shapePos + sm.vec3.new( 0.0, 0.0, 0.575 )
--   	end
-- end


-- function getCameraOffset( pullback )
-- 	local _, pullback = sm.camera.getCameraPullback()
-- 	if pullback == 0 then
-- 		return sm.vec3.new( 0.0, -0.25, 0.0 )
-- 	else
-- 		local dist = 0.0575 * pullback ^ 2 + 0.575 * pullback + 1.5
-- 		return sm.vec3.new( 0.375, -dist, 0.0 )
-- 	end
-- end



dofile "StratagemDatabase.lua"
STRATAGEMTYPETOCOLOUR = {
    supply    = sm.color.new(0,1,1),
    mission   = sm.color.new(1,1,0),
    defensive = sm.color.new(0,0,1),
    offensive = sm.color.new(1,0,0),
}

STRATAGEMINVENTORYSIZE = 6
STRATAGEMMAXBOUNCEOUNT = 3
PLAYERDATAPATH = "$CONTENT_DATA/playerData.json"

vec3_right   = sm.vec3.new(1,0,0)
vec3_forward = sm.vec3.new(0,1,0)
vec3_up      = sm.vec3.new(0,0,1)

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
	return (tool:getFpBonePos(bone.."_end") - tool:getFpBonePos(bone)):normalize()
end

dofile "StratagemDatabase.lua"
STRATAGEMTYPETOCOLOUR = {
    supply    = sm.color.new(0,1,1),
    mission   = sm.color.new(1,1,0),
    defensive = sm.color.new(0,1,0),
    offensive = sm.color.new(1,0,0),
}

STRATAGEMINVENTORYSIZE = 6
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



dofile "StratagemDatabase.lua"
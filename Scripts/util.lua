dofile "StratagemDatabase.lua"

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
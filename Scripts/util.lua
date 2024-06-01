STRATAGEMTYPETOCOLOUR = {
    supply    = sm.color.new("#7BAFD4"),
    mission   = sm.color.new("#F4C430"),
    defensive = sm.color.new("#93C57"),
    offensive = sm.color.new("#CD5C5C"),
}

vec3_right   = sm.vec3.new(1,0,0)
vec3_forward = sm.vec3.new(0,1,0)
vec3_up      = sm.vec3.new(0,0,1)

function GetStratagemByCode(code)
    for k, v in pairs(Stratagem.variants) do
        if v.code == code then
            return v
        end
    end
end
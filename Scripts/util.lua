STRATAGEMTYPETOCOLOUR = {
    mission     = sm.color.new("#F4C430"),
    defensive   = sm.color.new("#93C57"),
    offensive   = sm.color.new("#CD5C5C"),
}

function GetStratagemByCode(code)
    for k, v in pairs(Stratagem.variants) do
        if v.code == code then
            return v
        end
    end
end
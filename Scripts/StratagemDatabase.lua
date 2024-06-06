---@class StratagemObj
---@field uuid string
---@field cooldown number
---@field activation number
---@field dropEffect? string|Uuid
---@field update function

---@type StratagemObj[]
local stratagems =  {
    {
        uuid = "5fe2e519-9c05-4b4d-b0d6-3dc6fa7357c8",
        cooldown = 160 * 40,
        activation = 12 * 40,
        dropEffect = sm.uuid.new("b63d99e5-06e5-4397-bb3d-27c396124334"),
        update = function(self)
            local rotation = sm.quat.angleAxis(math.rad(90), vec3_right)
            sm.shape.createPart(self.dropEffect, self.hitData.position + self.hitData.normal * 0.5 - rotation * sm.item.getShapeOffset(self.dropEffect), rotation, false, true)

            return true
        end
    },
    {
        uuid = "4778cafb-d7d0-44cd-bca0-a2494018108b",
        cooldown = 160 * 40,
        activation = 3 * 40,
        update = function(self)
            sm.physics.explode(self.hitData.position, 100, 50, 75, 1000, "PropaneTank - ExplosionBig")
            return true
        end
    },
    {
        uuid = "bd7e37ba-844c-4c57-b660-e93048cd48a6",
        cooldown = 120 * 40,
        activation = 3 * 40,
        update = function(self)
            if self.tick%80 == 0 then
                local origin = self.hitData.position + sm.vec3.new(0,0,20)
                for i = 0, 6 do
                    local dir = vec3_forward:rotate(-math.rad(math.random(45, 75)), vec3_right):rotate(math.rad(i * 60), vec3_up)
                    sm.projectile.projectileAttack(sm.uuid.new( "31b92b9a-a9f8-4f6d-988b-04ad479978ec" ), 100, origin, dir * 100, self.hitData.shooter)
                    sm.effect.playEffect("PropaneTank - ExplosionSmall", origin)
                end
            end

            self.tick = self.tick + 1
            return self.tick >= 240
        end,
        tick = 0
    },
    {
        uuid = "53d9dc66-e90c-4ea2-9795-7522206a0549",
        cooldown = 80 * 40,
        activation = 1 * 40,
        update = function(self)
            if self.tick%2 == 0 then
                local origin = self.hitData.position + sm.vec3.new(0,0,20)
                local dir = vec3_forward:rotate(-math.rad(math.random(45, 75)), vec3_right):rotate(math.rad(math.random(0, 359)), vec3_up)
                sm.projectile.projectileAttack(projectile_potato, 100, origin, dir * 100, self.hitData.shooter)
                sm.effect.playEffect("SpudgunSpinner - SpinnerMuzzel", origin, sm.vec3.zero(), sm.vec3.getRotation(dir, vec3_up))
            end

            self.tick = self.tick + 1
            return self.tick >= 160
        end,
        tick = 0
    }
}

local stratagemUUIDToIndex = {}
for k, v in pairs(stratagems) do
    stratagemUUIDToIndex[v.uuid] = k
end



local stratagemUserdata = {
    ["5fe2e519-9c05-4b4d-b0d6-3dc6fa7357c8"] = {
        name = "Resupply",
        description = "omg ammo no way",
        icon = "bfcfac34-db0f-42d6-bd0c-74a7a5c95e82", --Potato
        type = "mission",
        code = "4432",
        cost = {
            {
                uuid = sm.uuid.new( "5530e6a0-4748-4926-b134-50ca9ecb9dcf" ), --Component kit
                amount = 5
            },
            {
                uuid = sm.uuid.new( "f152e4df-bc40-44fb-8d20-3b3ff70cdfe3" ), --Circuit
                amount = 5
            }
        }
    },
    ["4778cafb-d7d0-44cd-bca0-a2494018108b"] = {
        name = "Eagle 500kg Bomb",
        description = "big domb goes big boom",
        icon = "24001201-40dd-4950-b99f-17d878a9e07b", --large explosive
        type = "offensive",
        code = "32444",
        cost = {
            {
                uuid = sm.uuid.new( "5530e6a0-4748-4926-b134-50ca9ecb9dcf" ), --Component kit
                amount = 5
            },
            {
                uuid = sm.uuid.new( "f152e4df-bc40-44fb-8d20-3b3ff70cdfe3" ), --Circuit
                amount = 5
            }
        }
    },
    ["bd7e37ba-844c-4c57-b660-e93048cd48a6"] = {
        name = "Orbital Airburst Strike",
        description = "very random very good",
        icon = "8d3b98de-c981-4f05-abfe-d22ee4781d33", --small explosive
        type = "offensive",
        code = "222",
        cost = {
            {
                uuid = sm.uuid.new( "5530e6a0-4748-4926-b134-50ca9ecb9dcf" ), --Component kit
                amount = 5
            },
            {
                uuid = sm.uuid.new( "f152e4df-bc40-44fb-8d20-3b3ff70cdfe3" ), --Circuit
                amount = 5
            }
        }
    },
    ["53d9dc66-e90c-4ea2-9795-7522206a0549"] = {
        name = "Orbital Gatling Barrage",
        description = "ratatatatatata",
        icon = "9fde0601-c2ba-4c70-8d5c-2a7a9fdd122b", --Gatling
        type = "offensive",
        code = "24133",
        cost = {
            {
                uuid = sm.uuid.new( "5530e6a0-4748-4926-b134-50ca9ecb9dcf" ), --Component kit
                amount = 5
            },
            {
                uuid = sm.uuid.new( "f152e4df-bc40-44fb-8d20-3b3ff70cdfe3" ), --Circuit
                amount = 5
            }
        }
    }
}

function GetStratagem(id, override)
    override = override or stratagems
    if type(id) == "string" then
        for k, v in pairs(override) do
            local uuid = v.uuid
            if GetStratagemUserdata(uuid).code == id then
                return v, uuid
            end
        end
    else
        return stratagems[id]
    end
end

function GetStratagemByUUUID(uuid)
    return stratagems[stratagemUUIDToIndex[uuid]]
end

function GetStratagems()
    return stratagems
end

function GetStratagemPages()
    return math.ceil(#stratagems/6)
end

function GetStratagemUserdata(id)
    if type(id) == "string" then
        return stratagemUserdata[id]
    else
        local uuid = stratagems[id].uuid
        return stratagemUserdata[uuid], uuid
    end
end

local typeNames = {
    supply    = "SUPPLY STRATAGEMT PERMIT",
    mission   = "MISSION STRATAGEMT PERMIT",
    defensive = "DEFENSIVE STRATAGEMT PERMIT",
    offensive = "OFFENSIVE STRATAGEMT PERMIT"
}
function GetTypeFullName(type)
    return typeNames[type]
end

function GetClStratagemProgression(uuid)
    return g_cl_stratagemProgression[uuid] or { unlocked = false, charges = 0 }
end

function GetSvStratagemProgression(player, uuid)
    local playerData = g_sv_stratagemProgression[player.id] or {}
    return playerData[uuid] or { unlocked = false, charges = 0 }
end

function GetStratagemsFromClProgression()
    local stratagems_ = {}
    for k, v in pairs(g_cl_stratagemProgression) do
        local userdata = GetStratagemUserdata(k)
        table.insert(stratagems_, { uuid = k, charges = v.charges, icon = userdata.icon, code = userdata.code })
    end

    return stratagems_
end
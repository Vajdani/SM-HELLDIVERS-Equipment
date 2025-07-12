---@class StratagemObj
---@field uuid string
---@field cooldown number
---@field activation number
---@field dropEffect? string|Uuid
---@field update function

---@class StratagemUserdata
---@field name string
---@field description string
---@field icon string
---@field type string
---@field code string
---@field cost { uuid: Uuid, amount: number }[]
---@field preview? number

local function SpawnStaticDropPod(self, position)
    return sm.shape.createPart(self.dropEffect, position - dropPodRotation * sm.item.getShapeOffset(self.dropEffect), dropPodRotation, false, true)
end

local function SpawnDropPod(self, override)
    if type(override) == "RaycastResult" then
        local shape = override:getShape()
        if not shape.isBlock then
            SpawnStaticDropPod(self, override.pointWorld)
            return true
        end

        shape.body:createPart(self.dropEffect, shape:getClosestBlockLocalPosition(override.pointWorld + override.normalLocal), dropPodRotation * vec3_up, dropPodRotation * vec3_right)

        return true
    end

    SpawnStaticDropPod(self, override or self.hitData.position)

    return true
end

---@type StratagemObj[]
local stratagems = {
    {
        uuid = "5fe2e519-9c05-4b4d-b0d6-3dc6fa7357c8",
        cooldown = 1,--160 * 40,
        activation = 3 * 40, --12 * 40,
        dropEffect = sm.uuid.new("b63d99e5-06e5-4397-bb3d-27c396124334"),
        update = SpawnDropPod
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
                local origin = self.hitData.position + vec3_new(0,0,20)
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
                local origin = self.hitData.position + vec3_new(0,0,20)
                local dir = vec3_forward:rotate(-math.rad(math.random(45, 75)), vec3_right):rotate(math.rad(math.random(0, 359)), vec3_up)
                sm.projectile.projectileAttack(projectile_potato, 100, origin, dir * 100, self.hitData.shooter)
                sm.effect.playEffect("SpudgunSpinner - SpinnerMuzzel", origin, vec3_zero, sm.vec3.getRotation(dir, vec3_up))
            end

            self.tick = self.tick + 1
            return self.tick >= 160
        end,
        tick = 0
    },
    {
        uuid = "59a3c3e8-4c75-4f68-b550-22eed1b0ec53",
        cooldown = 1,--160 * 40,
        activation = 3 * 40, --12 * 40,
        dropEffect = sm.uuid.new("a8d6cc6d-dec6-4ba4-ac78-cc6fe3130d9f"),
        update = SpawnDropPod
    },
}

local stratagemUUIDToIndex = {}
local function BakeUUIDToIndex()
    for k, v in pairs(stratagems) do
        stratagemUUIDToIndex[v.uuid] = k
    end
end
BakeUUIDToIndex()



---@type { [string]: StratagemUserdata }
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
        description = "big bomb goes big boom",
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
    },
    ["59a3c3e8-4c75-4f68-b550-22eed1b0ec53"] = {
        name = "Heavy Machine Gun",
        description = "ratatatatatata",
        icon = "552b4ced-ca96-4a71-891c-ab54fe9c6873", --HMG
        type = "defensive",
        code = "44344",
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

for k, v in pairs(stratagemUserdata) do
    local path = "$CONTENT_DATA/Gui/StratagemVideos/"..k.."/video.json"
    if sm.json.fileExists(path) then
        stratagemUserdata[k].preview = tonumber(sm.json.open(path).frameCount)
    end
end



local customStratagemFunctions = {
    VehicleSpawn = function(self)
        if self.tick == 0 then
            local builder = SpawnStaticDropPod({ dropEffect = self.pelicanEffect }, self.hitData.position)
            builder.interactable:setParams(self.blueprint)
        end

        self.tick = self.tick + 1
        return self.tick >= self.lifeTime
    end
}

local customStratagemTemplates = {
    VehicleSpawn = {
        obj = {
            cooldown = 1,
            activation = 7 * 40,
            pelicanEffect = sm.uuid.new("687465a4-d956-4001-9163-1eab2a7798e0"),
            update = "VehicleSpawn",
            blueprint = "",
            tick = 0,
            lifeTime = 4 * 40
        },
        userdata = {
            name = "",
            description = "Custom creation stratagem",
            icon = "ad35f7e6-af8f-40fa-aef4-77d827ac8a8a",
            type = "supply",
            code = "",
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

function GetStratagemPageCount(itemsPerPage)
    return math.ceil(#stratagems/itemsPerPage)
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
    supply    = "SUPPLY STRATAGEM PERMIT",
    mission   = "MISSION STRATAGEM PERMIT",
    defensive = "DEFENSIVE STRATAGEM PERMIT",
    offensive = "OFFENSIVE STRATAGEM PERMIT"
}
function GetTypeFullName(type)
    return typeNames[type]
end

function GetClStratagemProgression(uuid)
    if not sm.game.getLimitedInventory() then
        return { unlocked = true, charges = 1000 }
    end

    return g_cl_stratagemProgression[uuid] or { unlocked = false, charges = 0 }
end

function GetSvStratagemProgression(player, uuid)
    local playerData = g_sv_stratagemProgression[player.id] or {}
    return playerData[uuid] or { unlocked = false, charges = 0 }
end

function GetFullStratagemProgression()
    local progression = {}
    for k, v in pairs(stratagems) do
        local uuid = v.uuid
        progression[uuid] = GetClStratagemProgression(uuid)
    end

    return progression
end

function GetStratagemsFromClProgression()
    local progression = sm.game.getLimitedInventory() and g_cl_stratagemProgression or GetFullStratagemProgression()
    local stratagems_ = {}
    for k, v in pairs(progression) do
        local userdata = GetStratagemUserdata(k)
        table.insert(stratagems_, { uuid = k, charges = v.charges, icon = userdata.icon, code = userdata.code })
    end

    return stratagems_
end

function ParseCustomStratagems(data)
    for k, v in pairs(data) do
        local uuid = v.uuid
        if not stratagemUUIDToIndex[uuid] then
            local stratagem = shallowcopy(v.obj)
            stratagem.uuid = uuid
            stratagem.update = customStratagemFunctions[stratagem.update]
            table.insert(stratagems, stratagem)

            stratagemUserdata[uuid] = v.userdata
        end
    end

    BakeUUIDToIndex()
end

function GetCustomStratagemTemplate(name)
    return shallowcopy(customStratagemTemplates[name])
end
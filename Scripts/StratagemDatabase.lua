---@class StratagemObj
---@field uuid string
---@field cooldown number
---@field activation number
---@field lifeTime number
---@field dropEffect? string|Uuid
---@field update string|function
---@field create? function
---@field pelicanEffect? Uuid

---@class StratagemHitData
---@field position Vec3
---@field throwDirection Vec3
---@field normal Vec3
---@field shooter Player
---@field data table

---@class StratagemWorldObj : StratagemObj
---@field dropStartTime number
---@field hitData StratagemHitData

---@class StratagemUserdata
---@field name string
---@field description string
---@field icon string
---@field type string
---@field code string
---@field cost { uuid: Uuid, amount: number }[]
---@field preview? number

---@class TemplateStratagemObj : StratagemObj
---@field uuid nil

---@class CustomStratagemTemplate
---@field uuid? string
---@field obj TemplateStratagemObj
---@field userdata StratagemUserdata

local function SpawnStaticDropPod(self, position)
    return sm.shape.createPart(self.dropEffect, vec3_new(self.hitData.position.x, self.hitData.position.y, position.z) - dropPodRotation * sm.item.getShapeOffset(self.dropEffect), dropPodRotation, false, true)
end

---@param override RaycastResult
local function SpawnDropPod(self, override)
    if type(override) == "RaycastResult" then
        local shape = override:getShape()
        if not shape.isBlock then
            SpawnStaticDropPod(self, override.pointWorld)
            return true
        end

        shape.body:createPart(self.dropEffect, shape:getClosestBlockLocalPosition(override.pointWorld) + vec3_new(-2, 2, 1), dropPodRotation * vec3_up, dropPodRotation * vec3_right)

        return true
    end

    SpawnStaticDropPod(self, override or self.hitData.position)

    return true
end

local function SpawnCreation(self, override, path, offset)
    local position
    if override then
        if type(override) == "RaycastResult" then
            position = override.pointWorld
        else
            position = override
        end
    else
        position = self.hitData.position
    end

    sm.creation.importFromFile(sm.world.getCurrentWorld(), path, position + offset)

    return true
end

---@type StratagemObj[]
local stratagems = {
    {
        uuid = "5fe2e519-9c05-4b4d-b0d6-3dc6fa7357c8",
        cooldown = 5 * 40,--160 * 40,
        activation = 3 * 40, --12 * 40,
        lifeTime = 0,
        dropEffect = sm.uuid.new("b63d99e5-06e5-4397-bb3d-27c396124334"),
        update = SpawnDropPod
    },
    {
        uuid = "4778cafb-d7d0-44cd-bca0-a2494018108b",
        cooldown = 5 * 40, --160 * 40,
        activation = 3 * 40,
        lifeTime = 0,
        update = function(self)
            sm.physics.explode(self.hitData.position, 100, 50, 75, 1000, "PropaneTank - ExplosionBig")
            return true
        end
    },
    {
        uuid = "bd7e37ba-844c-4c57-b660-e93048cd48a6",
        cooldown = 120 * 40,
        activation = 3 * 40,
        lifeTime = 240,
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
            return self.tick >= self.lifeTime
        end,
        tick = 0
    },
    {
        uuid = "53d9dc66-e90c-4ea2-9795-7522206a0549",
        cooldown = 5 * 40, --80 * 40,
        activation = 1 * 40,
        lifeTime = 160,
        update = function(self)
            if self.tick%2 == 0 then
                local origin = self.hitData.position + vec3_new(0,0,20)
                local dir = vec3_forward:rotate(-math.rad(math.random(45, 75)), vec3_right):rotate(math.rad(math.random(0, 359)), vec3_up)
                sm.projectile.projectileAttack(projectile_potato, 100, origin, dir * 100, self.hitData.shooter)
                sm.effect.playEffect("SpudgunSpinner - SpinnerMuzzel", origin, vec3_zero, sm.vec3.getRotation(dir, vec3_up))
            end

            self.tick = self.tick + 1
            return self.tick >= self.lifeTime
        end,
        tick = 0
    },
    {
        uuid = "59a3c3e8-4c75-4f68-b550-22eed1b0ec53",
        cooldown = 1, --160 * 40,
        activation = 3 * 40, --12 * 40,
        lifeTime = 0,
        dropEffect = sm.uuid.new("a8d6cc6d-dec6-4ba4-ac78-cc6fe3130d9f"),
        update = SpawnDropPod
    },
    {
        uuid = "dc80a180-cacf-4b21-a896-d85dd3d32d70",
        cooldown = 1, --160 * 40,
        activation = 3 * 40, --12 * 40,
        lifeTime = 0,
        dropEffect = sm.uuid.new("559b5c5d-9e48-4cdd-a078-a751c8a6357e"),
        update = function(self, override)
            return SpawnCreation(self, override, "$CONTENT_DATA/Objects/turretEmplacement.json", vec3_new(1.875, 0.625, 0.375))
        end
    },
    {
        uuid = "578b35aa-3865-4297-989b-4734417338c3",
        cooldown = 1, --160 * 40,
        activation = 3 * 40, --12 * 40,
        lifeTime = 0,
        dropEffect = sm.uuid.new("b63d99e5-06e5-4397-bb3d-27c396124334"),
        update = SpawnDropPod
    },
    {
        uuid = "8a5a03ac-5969-4b8a-b22e-624173a96119",
        cooldown = 3 * 40, --80 * 40,
        activation = 1 * 40,
        lifeTime = 30 * 40,
        create = function(self)
            self.hotspots = {}

            local seed = self.hitData.throwDirection.x + self.hitData.throwDirection.y
            for x = 0, 100 do
                for y = 0, 100 do
                    local noise = math.abs(sm.noise.perlinNoise2d(x * 0.1, y * 0.1, seed))
                    if noise > 0.4 then
                        table.insert(self.hotspots, vec3_new(-50 + x, -50 + y, 0) * 0.5)
                    end
                end
            end

            self.origin = self.hitData.position + vec3_new(100, -50, 150)
        end,
        update = function(self)
            if self.burstCount == 0 and self.tick%100 == 0 then
                self.burstCount = 3
            end

            if self.tick%20 == 0 and self.burstCount > 0 then
                local hotspot = math.random(#self.hotspots)
                local low, high = sm.projectile.solveBallisticArc(self.origin, self.hitData.position + (self.hotspots[hotspot] or vec3_zero), 250, sm.physics.getGravity())
                sm.projectile.projectileAttack(projectile_explosivetape, 1000, self.origin, low * 250, self.hitData.shooter)

                self.burstCount = self.burstCount - 1
                table.remove(self.hotspots, hotspot)
            end

            self.tick = self.tick + 1
            return self.tick >= self.lifeTime
        end,
        tick = 0,
        burstCount = 0
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
        name = "Heavy Machinegun",
        description = "ratatatatatata",
        icon = "552b4ced-ca96-4a71-891c-ab54fe9c6873", --HMG
        type = "supply",
        code = "41344",
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
    ["dc80a180-cacf-4b21-a896-d85dd3d32d70"] = {
        name = "HMG Emplacement",
        description = "Manned turret",
        icon = "559b5c5d-9e48-4cdd-a078-a751c8a6357e", --Pod
        type = "defensive",
        code = "431221",
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
    ["578b35aa-3865-4297-989b-4734417338c3"] = {
        name = "Hellbomb",
        description = "very big boom",
        icon = "b63d99e5-06e5-4397-bb3d-27c396124334", --Pod
        type = "mission",
        code = "43143243",
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
    ["8a5a03ac-5969-4b8a-b22e-624173a96119"] = {
        name = "Barrage",
        description = "very big boom",
        icon = "b63d99e5-06e5-4397-bb3d-27c396124334", --Pod
        type = "offensive",
        code = "44444",
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
        v.preview = tonumber(sm.json.open(path).frameCount)
    end

    v.name = v.name:upper()
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

---@type { [string]: CustomStratagemTemplate }
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

function GetStratagemByUUID(uuid)
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
            local stratagem = ShallowCopy(v.obj)
            stratagem.uuid = uuid
            stratagem.update = customStratagemFunctions[stratagem.update]
            table.insert(stratagems, stratagem)

            stratagemUserdata[uuid] = v.userdata
        end
    end

    BakeUUIDToIndex()
end

---@return CustomStratagemTemplate template
function GetCustomStratagemTemplate(name)
    return ShallowCopy(customStratagemTemplates[name])
end

function SortStratagemListByIndex(stratagems_)
    table.sort(stratagems_, function(a, b) return stratagemUUIDToIndex[tostring(a.uuid)] < stratagemUUIDToIndex[tostring(b.uuid)] end)
end



if sm.HELLDIVERSBACKEND then
    sm.event.sendToTool(sm.HELLDIVERSBACKEND, "OnStratagemDBLoaded")
end
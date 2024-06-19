dofile "$SURVIVAL_DATA/Scripts/game/survival_loot.lua"

---@class DropPod : ShapeClass
DropPod = class()
DropPod.pickupRegions = {}

function DropPod:server_onCreate()
    self.loaded = true

    local data = self.storage:load() or {}
    local items = data.items
    if not items then
        items = {}
        for k, v in pairs(self.pickupRegions) do
            items[k] = v.items
        end
    end

    self.sv_regions = items
    local col = data.col
    if #items > 0 and not col then
        local pos = self.shape.localPosition + self.shape.localRotation * sm.vec3.new(1,1,1)
        col = self.shape.body:createPart(sm.uuid.new("70cc47b6-429b-482f-bf83-765da7a1a3db"), pos, self.shape.zAxis, self.shape.xAxis, true)
        col.interactable:setParams({ parent = self.shape })
    end
    self.col = col

    self:sv_sync()
end

function DropPod:server_onDestroy()
    if not self.loaded then return end

    if self.col and sm.exists(self.col) then
        self.col:destroyShape()
    end

    self:sv_destroy()
end

function DropPod:sv_destroy(external)
    if external and GetRealLength(self.sv_regions) == 0 then return end

    local player = sm.player.getAllPlayers()[1]
    for k, items in pairs(self.sv_regions) do
        local lootList = {}
        for _k, item in pairs(items) do
            table.insert(lootList, { uuid = item.uuid, quantity = item.amount, epic = false })
        end

        SpawnLoot( player, lootList, self.pos + self.rot * self.pickupRegions[k].hitbox.offset, k <= 2 and -90 or 90 )
    end

    if external then
        self.loaded = false
        self.shape:destroyShape()
    end
end

function DropPod:server_onUnload()
    self.loaded = false
end

function DropPod:sv_sync()
    self.storage:save({ items = self.sv_regions, col = self.col })

    local indexes = {}
    for k, v in pairs(self.sv_regions) do
        table.insert(indexes, k)
    end

    self.network:setClientData(indexes)
end

function DropPod:sv_redeem(args)
    ---@type Player
    local player = args.player
    local index = args.data.index
    local items = self.sv_regions[index]
    if not items then return end

    sm.container.beginTransaction()
    if sm.game.getLimitedInventory() then
        local inventory = player:getInventory()
        for k, item in pairs(items) do
            sm.container.collect(inventory, item.uuid, item.amount, false)
        end
    else
        local inventory = player:getHotbar()
        local item = items[1]
        inventory:setItem(args.data.slot, item.uuid, item.amount)
    end
    sm.container.endTransaction()

    self.sv_regions[index] = nil
    if GetRealLength(self.sv_regions) == 0 then
        self.col:destroyShape()
        self.col = nil
    end

    self:sv_sync()
end

function DropPod:server_onFixedUpdate()
    self.pos = self.shape.worldPosition
    self.rot = self.shape.worldRotation
end



function DropPod:client_onCreate()
    self.animProgress = 0
    self.interactable:setAnimEnabled("unfold", true)
end

function DropPod:client_onClientDataUpdate(data, channel)
    if self.pickups then
        for k, v in pairs(self.pickups) do
            v.effect:destroy()
            sm.areaTrigger.destroy(v.trigger)
        end
    end

    self.pickups = {}
    for k, v in pairs(data) do
        local region = self.pickupRegions[v]
        local pickup = {}

        local bone = region.bone
        local effectData = region.effect
        local effectName = effectData.name
        local effect
        if type(effectName) == "string" then
            effect = sm.effect.createEffect(effectName, self.interactable, bone)
            effect:setScale(effectData.size or sm.vec3.one())
        else
            effect = sm.effect.createEffect("ShapeRenderable", self.interactable, bone)
            effect:setParameter("uuid", effectName)
            effect:setScale((effectData.size or sm.vec3.one()) * 0.25)
        end

        effect:setOffsetPosition(effectData.offset or sm.vec3.zero())
        effect:setOffsetRotation(effectData.rotation or sm.quat.identity())

        effect:start()
        pickup.effect = effect

        local hitbox = region.hitbox
        local trigger = sm.areaTrigger.createAttachedBox(self.interactable, hitbox.size, hitbox.offset, sm.quat.identity(), nil, { index = v })
        pickup.trigger = trigger

        if false then
            local triggerEffect = sm.effect.createEffect("ShapeRenderable", self.interactable)
            triggerEffect:setParameter("uuid", blk_wood1)
            triggerEffect:setScale(hitbox.size * 2)
            triggerEffect:setOffsetPosition(hitbox.offset)
            triggerEffect:start()

            pickup.triggerEffect = triggerEffect
        end

        self.pickups[v] = pickup
    end

    self.shouldBeActive = #data > 0
end

function DropPod:client_onUpdate(dt)
    if self.shouldBeActive then
        self.animProgress = math.min(self.animProgress + dt * 2.5, 1)
    else
        self.animProgress = math.max(self.animProgress - dt * 2.5, 0.04)
    end
    self.interactable:setAnimProgress("unfold", self.animProgress)
end



---@class DropPod_collision : ShapeClass
DropPod_collision = class()

function DropPod_collision:server_onCreate()
    self.loaded = true
    self.parent = self.storage:load() or (self.params or {}).parent
    self.storage:save(self.parent)
end

function DropPod_collision:server_onDestroy()
    if not self.loaded or not sm.exists(self.parent) then return end

    sm.event.sendToInteractable(self.parent.interactable, "sv_destroy", true)
end

function DropPod_collision:server_onUnload()
    self.loaded = false
end

function DropPod_collision:sv_redeem(args, caller)
    sm.event.sendToInteractable(self.parent.interactable, "sv_redeem", { data = args, player = caller })
end

local filter = sm.physics.filter.dynamicBody + sm.physics.filter.staticBody + sm.physics.filter.terrainAsset + sm.physics.filter.terrainSurface + sm.physics.filter.areaTrigger
function DropPod_collision:client_canInteract(char)
    local start = sm.localPlayer.getRaycastStart()
    local hit, result = sm.physics.raycast(start, start + sm.localPlayer.getDirection() * 7.5, nil, filter)
    local trigger = result:getAreaTrigger()
    if not trigger or not sm.exists(trigger) then return false end

    local userData = trigger and trigger:getUserData()
    return trigger ~= nil and userData ~= nil
end

function DropPod_collision:client_onInteract(char, state)
    if not state then return end

    local start = sm.localPlayer.getRaycastStart()
    local hit, result = sm.physics.raycast(start, start + sm.localPlayer.getDirection() * 7.5, nil, filter)
    self.network:sendToServer("sv_redeem", { index = result:getAreaTrigger():getUserData().index, slot = sm.localPlayer.getSelectedHotbarSlot() })
end



ResupplyPod = class(DropPod)
ResupplyPod.pickupRegions = {
    {
        hitbox = {
            offset = sm.vec3.new(0, 0.875, 0.214221),
            size   = sm.vec3.one() * 0.15,
        },
        effect = {
            name   = "Stratagem - Beacon",
        },
        bone   = "jnt_right_upper",
        items  = {
            {
                uuid = sm.uuid.new( "bfcfac34-db0f-42d6-bd0c-74a7a5c95e82" ), --potato
                amount = 100
            }
        }
    },
    {
        hitbox = {
            offset = sm.vec3.new(0, 0.374984, 0.214221),
            size   = sm.vec3.one() * 0.15,
        },
        effect = {
            name   = "Stratagem - Beacon",
        },
        bone   = "jnt_right_lower",
        items  = {
            {
                uuid = sm.uuid.new( "bfcfac34-db0f-42d6-bd0c-74a7a5c95e82" ), --potato
                amount = 100
            }
        }
    },
    {
        hitbox = {
            offset = sm.vec3.new(0, 0.875, -0.214221),
            size   = sm.vec3.one() * 0.15,
        },
        effect = {
            name   = "Stratagem - Beacon",
        },
        bone   = "jnt_left_upper",
        items  = {
            {
                uuid = sm.uuid.new( "bfcfac34-db0f-42d6-bd0c-74a7a5c95e82" ), --potato
                amount = 100
            }
        }
    },
    {
        hitbox = {
            offset = sm.vec3.new(0, 0.374984, -0.214221),
            size   = sm.vec3.one() * 0.15,
        },
        effect = {
            name   = "Stratagem - Beacon",
        },
        bone   = "jnt_left_lower",
        items  = {
            {
                uuid = sm.uuid.new( "bfcfac34-db0f-42d6-bd0c-74a7a5c95e82" ), --potato
                amount = 100
            }
        }
    }
}



HMG = class(DropPod)
HMG.pickupRegions = {
    {
        hitbox = {
            offset = sm.vec3.new(0, 0.624984, 0.214221),
            size   = sm.vec3.new(0.2, 0.45, 0.2),
        },
        effect = {
            name     = sm.uuid.new( "b633c3ee-2cda-4096-989a-60e90cd220aa" ),
            size     = sm.vec3.one() * 0.9,
            offset   = sm.vec3.new(0.15, 0.27, 0.0625),
            rotation = sm.quat.angleAxis(math.rad(90), vec3_right) * sm.quat.angleAxis(math.rad(90), vec3_up)
        },
        bone   = "jnt_right_middle",
        items  = {
            {
                uuid = sm.uuid.new( "9fde0601-c2ba-4c70-8d5c-2a7a9fdd122b" ), --gatling
                amount = 1
            }
        }
    }
}
---@class DropPod : ShapeClass
DropPod = class()
DropPod.pickupRegions = {}

function DropPod:server_onCreate()
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
    if self.col and sm.exists(self.col) then
        self.col:destroyShape()
    end
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
        local effect = sm.effect.createEffect(region.effect, self.interactable, bone)
        if not bone then
            effect:setOffsetPosition(region.offset)
        end

        effect:start()
        pickup.effect = effect

        local trigger = sm.areaTrigger.createAttachedBox(self.interactable, region.size, region.offset, sm.quat.identity(), nil, { index = v })
        pickup.trigger = trigger

        self.pickups[v] = pickup
    end

    self.shouldBeActive = #data > 0
end

function DropPod:client_onUpdate(dt)
    --[[sm.particle.createParticle("paint_smoke", self.shape:transformLocalPoint(self.pickupRegions[1].offset))
    sm.particle.createParticle("paint_smoke", self.shape:transformLocalPoint(self.pickupRegions[2].offset))
    sm.particle.createParticle("paint_smoke", self.shape:transformLocalPoint(self.pickupRegions[3].offset))
    sm.particle.createParticle("paint_smoke", self.shape:transformLocalPoint(self.pickupRegions[4].offset))]]

    if self.shouldBeActive then
        self.animProgress = math.min(self.animProgress + dt * 2.5, 1)
    else
        self.animProgress = math.max(self.animProgress - dt * 2.5, 0)
    end
    self.interactable:setAnimProgress("unfold", self.animProgress)
end



---@class DropPod_collision : ShapeClass
DropPod_collision = class()

function DropPod_collision:server_onCreate()
    self.parent = self.storage:load() or (self.params or {}).parent
    self.storage:save(self.parent)
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
        offset = sm.vec3.new(0, 0.875, 0.214221),
        size   = sm.vec3.one() * 0.15,
        effect = "Stratagem - Beacon",
        bone   = "jnt_right_upper",
        items  = {
            {
                uuid = sm.uuid.new( "bfcfac34-db0f-42d6-bd0c-74a7a5c95e82" ), --potato
                amount = 100
            }
        }
    },
    {
        offset = sm.vec3.new(0, 0.374984, 0.214221),
        size   = sm.vec3.one() * 0.15,
        effect = "Stratagem - Beacon",
        bone   = "jnt_right_lower",
        items  = {
            {
                uuid = sm.uuid.new( "bfcfac34-db0f-42d6-bd0c-74a7a5c95e82" ), --potato
                amount = 100
            }
        }
    },
    {
        offset = sm.vec3.new(0, 0.875, -0.214221),
        size   = sm.vec3.one() * 0.15,
        effect = "Stratagem - Beacon",
        bone   = "jnt_left_upper",
        items  = {
            {
                uuid = sm.uuid.new( "bfcfac34-db0f-42d6-bd0c-74a7a5c95e82" ), --potato
                amount = 100
            }
        }
    },
    {
        offset = sm.vec3.new(0, 0.374984, -0.214221),
        size   = sm.vec3.one() * 0.15,
        effect = "Stratagem - Beacon",
        bone   = "jnt_left_lower",
        items  = {
            {
                uuid = sm.uuid.new( "bfcfac34-db0f-42d6-bd0c-74a7a5c95e82" ), --potato
                amount = 100
            }
        }
    }
}
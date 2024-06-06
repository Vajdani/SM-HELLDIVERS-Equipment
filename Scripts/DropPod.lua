---@class DropPod : ShapeClass
DropPod = class()
DropPod.poseWeightCount = 1
DropPod.pickupRegions = {}

function DropPod:server_onCreate()
    local items = self.storage:load()
    if not items then
        items = {}
        for k, v in pairs(self.pickupRegions) do
            items[k] = v.items
        end
    end

    self.sv_regions = items
    self:sv_sync()
end

function DropPod:sv_sync()
    self.storage:save(self.sv_regions)

    local indexes = {}
    for k, v in pairs(self.sv_regions) do
        table.insert(indexes, k)
    end

    self.network:setClientData(indexes)
end

---@param caller Player
function DropPod:sv_redeem(args, caller)
    local index = args.index
    local items = self.sv_regions[index]
    if not items then return end

    if sm.game.getLimitedInventory() then
        local inventory = caller:getInventory()
        sm.container.beginTransaction()
        for k, item in pairs(items) do
            sm.container.collect(inventory, item.uuid, item.amount, false)
        end
        sm.container.endTransaction()
    else
        local inventory = caller:getHotbar()
        sm.container.beginTransaction()
        local item = items[1]
        inventory:setItem(args.slot, item.uuid, item.amount)
        sm.container.endTransaction()
    end

    self.sv_regions[index] = nil
    self:sv_sync()
end



function DropPod:client_onCreate()
    self.animProgress = 0
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

        local effect = sm.effect.createEffect(region.effect, self.interactable)
        effect:setOffsetPosition(region.offset)
        effect:start()
        pickup.effect = effect

        local trigger = sm.areaTrigger.createAttachedBox(self.interactable, region.size, region.offset, sm.quat.identity(), -1, { index = v })
        pickup.trigger = trigger

        self.pickups[v] = pickup
    end

    self.shouldBeActive = #data > 0
end

function DropPod:client_onUpdate(dt)
    if self.shouldBeActive then
        self.animProgress = math.min(self.animProgress + dt * 5, 1)
    else
        self.animProgress = math.max(self.animProgress - dt * 5, 0)
    end
    self.interactable:setPoseWeight(0, self.animProgress)
end

local function IsFluid(userData)
    return userData.water or userData.chemical or userData.oil
end

local filter = sm.physics.filter.dynamicBody + sm.physics.filter.staticBody + sm.physics.filter.terrainAsset + sm.physics.filter.terrainSurface + sm.physics.filter.areaTrigger
function DropPod:client_canInteract(char)
    local start = sm.localPlayer.getRaycastStart()
    local hit, result = sm.physics.raycast(start, start + sm.localPlayer.getDirection() * 7.5, nil, filter)
    local trigger = result:getAreaTrigger()
    if not trigger or not sm.exists(trigger) then return false end

    local userData = trigger and trigger:getUserData()
    local canInteract = trigger ~= nil and userData ~= nil and not IsFluid(userData)

    return canInteract
end

function DropPod:client_onInteract(char, state)
    if not state then return end

    local start = sm.localPlayer.getRaycastStart()
    local hit, result = sm.physics.raycast(start, start + sm.localPlayer.getDirection() * 7.5, nil, filter)
    self.network:sendToServer("sv_redeem", { index = result:getAreaTrigger():getUserData().index, slot = sm.localPlayer.getSelectedHotbarSlot() })
end



ResupplyPod = class(DropPod)
ResupplyPod.pickupRegions = {
    {
        offset = sm.vec3.new(0,0.25,0.25),
        size   = sm.vec3.new(0.15,0.15,0.15),
        effect = "Stratagem - Beacon",
        items  = {
            {
                uuid = sm.uuid.new( "bfcfac34-db0f-42d6-bd0c-74a7a5c95e82" ), --potato
                amount = 100
            }
        }
    },
    {
        offset = sm.vec3.new(0,-0.25,0.25),
        size   = sm.vec3.new(0.15,0.15,0.15),
        effect = "Stratagem - Beacon",
        items  = {
            {
                uuid = sm.uuid.new( "bfcfac34-db0f-42d6-bd0c-74a7a5c95e82" ), --potato
                amount = 100
            }
        }
    },
    {
        offset = sm.vec3.new(0,0.25,-0.25),
        size   = sm.vec3.new(0.15,0.15,0.15),
        effect = "Stratagem - Beacon",
        items  = {
            {
                uuid = sm.uuid.new( "bfcfac34-db0f-42d6-bd0c-74a7a5c95e82" ), --potato
                amount = 100
            }
        }
    },
    {
        offset = sm.vec3.new(0,-0.25,-0.25),
        size   = sm.vec3.new(0.15,0.15,0.15),
        effect = "Stratagem - Beacon",
        items  = {
            {
                uuid = sm.uuid.new( "bfcfac34-db0f-42d6-bd0c-74a7a5c95e82" ), --potato
                amount = 100
            }
        }
    }
}
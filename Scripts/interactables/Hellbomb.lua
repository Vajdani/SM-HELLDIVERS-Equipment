dofile "VehicleBuilder.lua"

---@class Hellbomb : VehicleBuilder
Hellbomb = class(VehicleBuilder)

local CountdownTime = 10 * 40

function Hellbomb:server_onCreate()
    self.sv_currentCode = ""

    local storage = self.storage:load() or {}
    self.sv_complete = storage.complete or false

    self.network:sendToClients("cl_updateState", self.sv_complete)
    self.storage:save({ complete = self.sv_complete })
end

function Hellbomb:server_onFixedUpdate()
    if self.exploded then return end

    if self.activated then
        self.countdown = self.countdown - 1
        if self.countdown <= 0 then
            self:sv_explode()
        end
    end
end

function Hellbomb:server_onExplosion()
    self:sv_explode()
end

function Hellbomb:server_onMelee()
    self:sv_explode()
end

function Hellbomb:server_onProjectile()
    self:sv_explode()
end

function Hellbomb:sv_codeSuccess()
    self.activated = true
    self.countdown = CountdownTime
    self.network:sendToClients("cl_OnComplete")
end

function Hellbomb:sv_explode()
    if not self.activated then return end

    self.exploded = true
    sm.physics.explode(self.shape.worldPosition, 1000, 50, 100, 10000, "PropaneTank - ExplosionBig")
end
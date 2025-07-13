---@class TurretEmplacementPod : ShapeClass
TurretEmplacementPod = class()

-- function TurretEmplacementPod:sv_export()
--     sm.json.save(sm.creation.exportToTable(self.shape.body, false, false), "$CONTENT_DATA/turret.json")
-- end

-- function TurretEmplacementPod:sv_import()
--     sm.effect.playEffect("Part - Upgrade", self.shape.worldPosition + vec3_up * 10)
--     sm.creation.importFromFile(sm.world.getCurrentWorld(), "$CONTENT_DATA/turret.json", self.shape.worldPosition + vec3_up * 10 + vec3_new(0.125, 2.875, 0.375))
-- end



function TurretEmplacementPod:client_onCreate()
    self.interactable:setAnimEnabled("unfold", true)
    self.interactable:setAnimProgress("unfold", 0.04)
    self.interactable:setSubMeshVisible("supplystand", false)
end

-- function TurretEmplacementPod:client_onUpdate()
--     if self.bp then
--         self.bp:setPosition(self.shape.worldPosition + vec3_new(1.875, 0.625, 0.375))
--         self.bp:setRotation(self.shape.worldRotation * sm.quat.angleAxis(math.rad(-90), vec3_right))
--     end
-- end

-- function TurretEmplacementPod:client_onInteract(character, state)
--     if not state then return end

--     -- self.network:sendToServer("sv_export")

--     if not self.bp then
--         self.bp = sm.visualization.createBlueprint("$CONTENT_DATA/Objects/turretEmplacement.json")
--     end
-- end

-- function TurretEmplacementPod:client_onTinker(character, state)
--     if not state then return end

--     self.network:sendToServer("sv_import")
-- end



local connection_bearing = sm.interactable.connectionType.bearing

---@class TurretEmplacementSeat : ShapeClass
TurretEmplacementSeat = class()
TurretEmplacementSeat.maxParentCount = 0
TurretEmplacementSeat.maxChildCount = 3
TurretEmplacementSeat.connectionOutput = connection_bearing + sm.interactable.connectionType.seated

local LR_col = sm.color.new("#eeeeee")
local UD_col = sm.color.new("#222222")

local normalTurnSpeed = math.pi
local turnSpeedLimit = 1000

function TurretEmplacementSeat:server_onCreate()
    self.yaw, self.pitch = 0, 0
    for k, bearing in pairs(self.interactable:getChildren(connection_bearing)) do
        bearing:setTargetAngle( 0, 100, 400 )

        if bearing.color == LR_col then
            self.LRBearing = bearing
        elseif bearing.color == UD_col then
            self.UDBearing = bearing
        end
    end
end

function TurretEmplacementSeat:server_onFixedUpdate()
    if not (sm.exists(self.LRBearing) and sm.exists(self.UDBearing)) then return end

    local char = self.interactable:getSeatCharacter()
    if not char then
        self.LRBearing:setTargetAngle( self.yaw, normalTurnSpeed, turnSpeedLimit )
        self.UDBearing:setTargetAngle( self.pitch, normalTurnSpeed, turnSpeedLimit )
        return
    end

    local playerDir, seatDir = char.direction, self.shape.up
    local yaw, pitch = GetYawPitch(playerDir)
    local _yaw, _pitch = GetYawPitch(seatDir)
    local speed = (math.abs(AngleDifference(_yaw, yaw)) + math.abs(pitch - _pitch)) * 2

    self.LRBearing:setTargetAngle( yaw, speed, turnSpeedLimit )
    self.UDBearing:setTargetAngle( pitch, speed, turnSpeedLimit )

    self.yaw, self.pitch = yaw, pitch
end

-- function TurretEmplacementSeat:sv_updateCameraMode(mode)
--     print(mode)
-- end



-- function TurretEmplacementSeat:client_onFixedUpdate()
--     print(getCameraMode(self.shape.worldRotation))
-- end

function TurretEmplacementSeat:client_onInteract(character, state)
    if not state or self.interactable:getSeatCharacter() then return end

    sm.localPlayer.setLockedControls(true)
    sm.localPlayer.setDirection(self.shape.up)
    sm.event.sendToInteractable(self.interactable, "cl_seat", character)
end

-- local modeEnum = {
--     Free   = 1,
--     Follow = 2,
--     Strict = 3,
-- }
function TurretEmplacementSeat:client_onAction(action, state)
    if action == 19 then
        if state then
            self.interactable:pressSeatInteractable(0)
        else
            self.interactable:releaseSeatInteractable(0)
        end
    end

    if state then
        if action == 15 then
            self.interactable:setSeatCharacter(sm.localPlayer.getPlayer().character)
            sm.camera.setCameraState(0)
            self.gui:close()
        end

        -- if action == 0 then
        --     self.network:sendToServer("sv_updateCameraMode", modeEnum[getCameraMode(self.shape.worldRotation)])
        -- end
    end


    return action ~= 0
end

function TurretEmplacementSeat:cl_seat(character)
    sm.localPlayer.setLockedControls(false)

    self.interactable:setSeatCharacter(character)
    sm.camera.setCameraPullback(0,0)
    sm.camera.setCameraState(0)

    self.gui = sm.gui.createGuiFromLayout("$CONTENT_DATA/Gui/Layouts/Empty.layout", true, {
        isHud           = true,
        isInteractive   = false,
        needsCursor     = false,
        hidesHotbar     = true,
        isOverlapped    = false,
        backgroundAlpha = 0.0,
    })
    self.gui:open()
end
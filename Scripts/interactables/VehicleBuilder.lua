dofile "$SURVIVAL_DATA/Scripts/blueprint_util.lua"

---@class VehicleBuilder : ShapeClass
VehicleBuilder = class()

function VehicleBuilder:server_onCreate()
    self.sv_currentCode = ""

    local storage = self.storage:load() or {}
    local blueprint = storage.blueprint or self.params or "$CONTENT_DATA/UserBlueprints/bp1.json"
    self.sv_blueprint = blueprint

    self.sv_complete = storage.complete or false
    if not self.sv_complete then
        self.network:setClientData(sm.json.open(blueprint), 1)
    end

    self.network:sendToClients("cl_updateState", self.sv_complete)
    self.storage:save({ blueprint = blueprint, complete = self.sv_complete })
end

---@param player Player
function VehicleBuilder:sv_interact(state, player)
    if self.sv_complete then return end

    if state and not self.sv_controller then
        self.sv_controller = player

        self.sv_currentCode = ""
        self:sv_generateCode()

        self.network:sendToClients("cl_interact", self.sv_controller)
    elseif not state and self.sv_controller == player then
        self.sv_controller = nil
        self.sv_currentCode = ""
        self.sv_correctCode = ""
        self.network:setClientData(self.sv_correctCode, 2)
        self.network:sendToClients("cl_interact", self.sv_controller)
    end
end

function VehicleBuilder:sv_codeInput(input)
    local newCode = self.sv_currentCode..input
    local fail = false
    for i = 1, #newCode do
        if newCode:sub(i, i) ~= self.sv_correctCode:sub(i,i) then
            fail = true
            break
        end
    end

    if fail then
        self:sv_generateCode()
        self.sv_currentCode = ""
    else
        self.sv_currentCode = newCode
        if newCode == self.sv_correctCode then
            self:sv_interact(false, self.sv_controller)
            self.sv_complete = true
            self.network:sendToClients("cl_updateState", self.sv_complete)
            self.storage:save({ blueprint = self.sv_blueprint, complete = self.sv_complete })
            self:sv_codeSuccess()
        end
    end

    self.network:sendToClients("cl_codeInput", self.sv_currentCode)
end

function VehicleBuilder:sv_generateCode()
    self.sv_correctCode = ""
    for i = 1, math.random(4, 8) do
        self.sv_correctCode = self.sv_correctCode..math.random(1, 4)
    end
    self.network:setClientData(self.sv_correctCode, 2)
end

function VehicleBuilder:sv_codeSuccess()
    local json = sm.json.open(self.sv_blueprint)
    for k, v in pairs(json.bodies) do
        v.type = 0
    end

    sm.creation.importFromString(sm.world.getCurrentWorld(), sm.json.writeJsonString(json), self.shape.worldPosition, self.shape.worldRotation * sm.quat.angleAxis(math.rad(-90), vec3_right))
    self.network:sendToClients("cl_OnComplete")
end



function VehicleBuilder:client_onCreate()
    self.cl_correctCode = ""
    self.cl_currentCode = ""
    self.cl_complete = false
end

function VehicleBuilder:client_onDestroy()
    self:cl_OnComplete()
end

function VehicleBuilder:client_onUpdate()
    if self.cl_controller ~= sm.localPlayer.getPlayer() then return end

    local correctCode = self.cl_correctCode:gsub("1", "<img bg='gui_keybinds_bg' spacing='0'>icon_keybinds_arrow_left.png</img>"):gsub("2", "<img bg='gui_keybinds_bg' spacing='0'>icon_keybinds_arrow_right.png</img>"):gsub("3", "<img bg='gui_keybinds_bg' spacing='0'>icon_keybinds_arrow_up.png</img>"):gsub("4", "<img bg='gui_keybinds_bg' spacing='0'>icon_keybinds_arrow_down.png</img>")
    local currentCode = self.cl_currentCode:gsub("1", "<img bg='gui_keybinds_bg' spacing='0'>icon_keybinds_arrow_left.png</img>"):gsub("2", "<img bg='gui_keybinds_bg' spacing='0'>icon_keybinds_arrow_right.png</img>"):gsub("3", "<img bg='gui_keybinds_bg' spacing='0'>icon_keybinds_arrow_up.png</img>"):gsub("4", "<img bg='gui_keybinds_bg' spacing='0'>icon_keybinds_arrow_down.png</img>")
    --sm.gui.setInteractionText(correctCode)
    sm.gui.setInteractionText(correctCode, "|\t|", currentCode)
end

function VehicleBuilder:client_canInteract()
    return not self.cl_complete and self.cl_controller == nil
end

function VehicleBuilder:client_onInteract(char, state)
    if not state then return end

    self.network:sendToServer("sv_interact", true)
end

local stratagemCodeInput = {
    [1] = true,
    [2] = true,
    [3] = true,
    [4] = true,
}
function VehicleBuilder:client_onAction(action, state)
    if not state then return true end

    if action == 15 then
        self.network:sendToServer("sv_interact", false)
    elseif stratagemCodeInput[action] == true then
        self.network:sendToServer("sv_codeInput", action)
    end

    return true
end

function VehicleBuilder:client_onClientDataUpdate(data, channel)
    if channel == 1 then
        local blueprint = sm.visualization.createBlueprint( data )
        blueprint:setPosition(self.shape.worldPosition)
        blueprint:setRotation(self.shape.worldRotation * sm.quat.angleAxis(math.rad(-90), vec3_right))
        self.blueprint = blueprint
    else
        self.cl_correctCode = data
    end
end

function VehicleBuilder:cl_interact(controller)
    local player = sm.localPlayer.getPlayer()
    if controller and controller == player then
        player.character:setLockingInteractable(self.interactable)
    elseif not controller and self.cl_controller == player then
        player.character:setLockingInteractable(nil)
    end

    self.cl_controller = controller
    self.cl_currentCode = ""
end

function VehicleBuilder:cl_codeInput(code)
    self.cl_currentCode = code
end

function VehicleBuilder:cl_updateState(state)
    self.cl_complete = state
end

function VehicleBuilder:cl_OnComplete()
    if self.blueprint then
        self.blueprint:destroy()
        self.blueprint = nil
    end
end
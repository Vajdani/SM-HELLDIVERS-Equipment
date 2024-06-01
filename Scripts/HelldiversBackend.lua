dofile "util.lua"

gameHooked = gameHooked or false
local function attemptHook()
    if not gameHooked then
        dofile("$SURVIVAL_DATA/Scripts/game/worlds/Overworld.lua")
        dofile("$SURVIVAL_DATA/Scripts/game/worlds/WarehouseWorld.lua")
        dofile("$CONTENT_e35b1c4e-d434-4102-88bf-95a16b8cff7d/Scripts/vanilla_override.lua")
        gameHooked = true
    end
end

oldHud = oldHud or sm.gui.createSurvivalHudGui
local function hudHook()
    attemptHook()
	return oldHud()
end
sm.gui.createSurvivalHudGui = hudHook

oldBind = oldBind or sm.game.bindChatCommand
local function bindHook(command, params, callback, help)
    attemptHook()
	return oldBind(command, params, callback, help)
end
sm.game.bindChatCommand = bindHook



---@class HelldiversBackend : ToolClass
HelldiversBackend = class()

function HelldiversBackend:server_onCreate()
    if setupComplete then return end

    if sm.crashlander then
        local armour = {
            {
                uuid = sm.uuid.new("d39d911c-280b-429e-8168-2c6db39c4eaf"),
                slot = "head",
                renderable = "$CONTENT_e35b1c4e-d434-4102-88bf-95a16b8cff7d/Characters/Renderable/char_helldiver_armour_helmet.rend",
                stats = {
                    damageReduction = 0.15
                },
                setId = "Helldiver"
            },
            {
                uuid = sm.uuid.new("f4aada57-e8ac-4a54-ba79-6cdb9d73f039"),
                slot = "torso",
                renderable = "$CONTENT_e35b1c4e-d434-4102-88bf-95a16b8cff7d/Characters/Renderable/char_helldiver_armour_chestplate.rend",
                stats = {
                    damageReduction = 0.25
                },
                setId = "Helldiver"
            },
            {
                uuid = sm.uuid.new("2592e8f0-2bab-4f4f-b153-1566717ab42e"),
                slot = "leg",
                renderable = "$CONTENT_e35b1c4e-d434-4102-88bf-95a16b8cff7d/Characters/Renderable/char_helldiver_armour_leggings.rend",
                stats = {
                    damageReduction = 0.25
                },
                setId = "Helldiver"
            },
            {
                uuid = sm.uuid.new("37eac317-fff1-47b7-86d0-e67c31cdf09a"),
                slot = "foot",
                renderable = "$CONTENT_e35b1c4e-d434-4102-88bf-95a16b8cff7d/Characters/Renderable/char_helldiver_armour_boots.rend",
                stats = {
                    damageReduction = 0.15
                },
                setId = "Helldiver"
            }
        }

        for k, v in pairs(armour) do
            sm.crashlander.addEquipment(v.uuid, v.slot, v.renderable, v.stats)
        end

        sm.log.info("[HELLDIVERS] Armour setup complete")
    else
        sm.log.info("[HELLDIVERS] Non crashlander gamemode, armour setup aborted")
    end

    setupComplete = true

    sm.HELLDIVERSBACKEND = self.tool

    self.queuedStratagems = {}
end

function HelldiversBackend:server_onFixedUpdate()
    for k, v in pairs(self.queuedStratagems) do
        v.activation = v.activation - 1
        if v.activation <= 0 then
            if v:summon() then
                self.queuedStratagems[k] = nil
                self.network:sendToClients("cl_DeleteStratagem", k)
            end
        end
    end
end

function HelldiversBackend:OnStratagemHit(args)
    local stratagem = shallowcopy(GetStratagemByCode(args.data.code))
    stratagem.hitData = args
    table.insert(self.queuedStratagems, stratagem)
    self.network:sendToClients("cl_OnStratagemHit", stratagem)
end



function HelldiversBackend:client_onCreate()
    self.cl_queuedStratagems = {}
end

function HelldiversBackend:client_onFixedUpdate()
    for k, v in pairs(self.cl_queuedStratagems) do
        v.activation = v.activation - 1
        if v.activation >= 0 then
            v.gui:setText("Text", ("%.0fs"):format(v.activation/40))
        else
            v.gui:setText("Text", "Activating...")
        end
    end
end

function HelldiversBackend:cl_OnStratagemHit(args)
    local pos = args.hitData.position

    local beaconScale = sm.vec3.new(1,500,1)
    local beacon = sm.effect.createEffect("Stratagem - Beacon")
    beacon:setParameter("Color", STRATAGEMTYPETOCOLOUR[args.type])
    beacon:setParameter("Scale", beaconScale)
    beacon:setPosition(pos + vec3_up * beaconScale.y * 0.125)
    beacon:start()
    args.beacon = beacon

    local gui = sm.gui.createNameTagGui(true)
    gui:setRequireLineOfSight(false)
    gui:setText("Text", ("%.0fs"):format(args.activation/40))
    gui:setWorldPosition(pos)
    gui:open()
    args.gui = gui

    table.insert(self.cl_queuedStratagems, args)
end

function HelldiversBackend:cl_DeleteStratagem(index)
    self.cl_queuedStratagems[index].gui:close()
    self.cl_queuedStratagems[index].beacon:destroy()
    self.cl_queuedStratagems[index] = nil
end
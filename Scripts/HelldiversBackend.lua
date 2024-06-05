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
                uuid = sm.uuid.new("32271c87-97db-4158-aeed-5fed1dbc1ed7"),
                slot = "acc",
                renderable = "$CONTENT_e35b1c4e-d434-4102-88bf-95a16b8cff7d/Characters/Renderable/char_helldiver_armour_gloves.rend",
                stats = {},
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

    local storage = {} --self.storage:load() or {}
    g_sv_stratagemProgression = storage.progression or {}
    self.loadouts = storage.loadouts or {}
    self.cooldownsPerPlayer = storage.cooldowns or {}

    self.queuedStratagems = {}
end

function HelldiversBackend:server_onFixedUpdate()
    for k, stratagem in pairs(self.queuedStratagems) do
        stratagem.activation = stratagem.activation - 1
        if stratagem.activation <= 0 then
            if stratagem:summon() then
                self.queuedStratagems[k] = nil
                self.network:sendToClients("cl_DeleteStratagem", k)
            end
        end
    end
end

function HelldiversBackend:OnStratagemHit(args)
    local stratagem = shallowcopy(GetStratagem(args.data.code))
    stratagem.hitData = args

    local id = ("%s_%s"):format(args.shooter.id, stratagem.uuid)
    self.queuedStratagems[id] = stratagem

    self.network:sendToClients("cl_OnStratagemHit",
        {
            id = id,
            hitData = args,
            activation = stratagem.activation,
        }
    )
end

function HelldiversBackend:sv_save()
    self.storage:save(
        {
            loadouts = self.loadouts,
            progression = g_sv_stratagemProgression,
            cooldowns = self.cooldownsPerPlayer
        }
    )
end

function HelldiversBackend:sv_requestData(args, caller)
    self.network:sendToClient(caller, "cl_recieveData",{
        loadout = self.loadouts[caller.id] or {},
        progression = g_sv_stratagemProgression[caller.id] or {},
        cooldowns = self.cooldownsPerPlayer[caller.id] or {}
    })
end

function HelldiversBackend:sv_purchaseStratagem(args)
    local player, uuid = args.player, args.uuid
    local progression = GetSvStratagemProgression(player, uuid)
    progression.unlocked = true
    progression.charges = progression.charges + 1

    local pId = player.id
    if not g_sv_stratagemProgression[pId] then
        g_sv_stratagemProgression[pId] = {}
    end

    g_sv_stratagemProgression[pId][uuid] = progression
    self:sv_save()
    self:sv_requestData(nil, player)
end

function HelldiversBackend:sv_setLoadout(args)
    self.loadouts[args.player.id] = args.loadout
    self:sv_save()
    self:sv_requestData(nil, args.player)
end



function HelldiversBackend:client_onCreate()
    if g_cl_stratagemProgression then return end

    g_cl_queuedStratagems = {}
    g_cl_loadout = {}
    g_cl_stratagemProgression = {}
    g_cl_cooldowns = {}
    self.network:sendToServer("sv_requestData")
end

function HelldiversBackend:client_onFixedUpdate()
    if not g_cl_queuedStratagems then return end

    for k, v in pairs(g_cl_queuedStratagems) do
        v.activation = v.activation - 1
        if v.activation >= 0 then
            v.gui:setText("Text", ("Inbound T-%.0fs"):format(v.activation/40))
        else
            v.gui:setText("Text", "Ongoing...")
        end
    end
end

function HelldiversBackend:OnStratagemThrow(args)
    local player, stratagem = args.player, GetStratagem(args.code)
    local pId, uuid = player.id, stratagem.uuid
    local progression = GetSvStratagemProgression(player, uuid)
    if progression.charges == 0 then return end

    if not self.cooldownsPerPlayer[pId] then
        self.cooldownsPerPlayer[pId] = {}
    end

    local tick = sm.game.getServerTick()
    if (self.cooldownsPerPlayer[pId][uuid] or tick) > tick then return end

    self.cooldownsPerPlayer[pId][uuid] = tick + stratagem.cooldown
    progression.charges = progression.charges - 1
    g_sv_stratagemProgression[pId][uuid] = progression

    sm.projectile.customProjectileAttack({ code = args.code }, sm.uuid.new("6411767a-8882-4b94-aae5-381057cde9f9"), 0, args.pos, player.character.direction * 35, player )

    self:sv_save()
    self:sv_requestData(nil, player)
end

function HelldiversBackend:cl_OnStratagemHit(args)
    local pos = args.hitData.position
    local id = args.id
    local userdata = GetStratagemUserdata(id:sub(3, #id))

    local beaconScale = sm.vec3.new(1,500,1)
    local beacon = sm.effect.createEffect("Stratagem - Beacon")
    beacon:setParameter("Color", STRATAGEMTYPETOCOLOUR[userdata.type])
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

    g_cl_queuedStratagems[id] = args
end

function HelldiversBackend:cl_DeleteStratagem(index)
    local data = g_cl_queuedStratagems[index]
    data.gui:close()
    data.beacon:destroy()
    g_cl_queuedStratagems[index] = nil
end

function HelldiversBackend:cl_recieveData(data)
    g_cl_loadout = data.loadout
    g_cl_stratagemProgression = data.progression
    g_cl_cooldowns = data.cooldowns

    if g_stratagemTerminal then
        sm.event.sendToInteractable(g_stratagemTerminal, "cl_refresh")
    end
end
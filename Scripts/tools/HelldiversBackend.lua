dofile "$CONTENT_DATA/Scripts/util.lua"

gameHooked = gameHooked or false
local function attemptHook()
    if not gameHooked then
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

local dropPodStartHeight = sm.vec3.new(0,0,500)
local blueprintsPath = "$CONTENT_DATA/UserBlueprints/"
local blueprintTracker = blueprintsPath.."blueprintTracker.json"

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
    self.customStratagems = storage.customStratagems or {}

    self.queuedStratagems = {}

    if not sm.json.fileExists(blueprintTracker) then
        sm.json.save({}, blueprintTracker)
    end
end

function HelldiversBackend:server_onFixedUpdate()
    if sm.HELLDIVERSBACKEND ~= self.tool then return end

    for k, stratagem in pairs(self.queuedStratagems) do
        local skip = false

        stratagem.activation = stratagem.activation - 1
        if stratagem.dropStartTime and stratagem.activation <= stratagem.dropStartTime then
            local pos = stratagem.hitData.position
            local start = sm.vec3.lerp(pos, pos + dropPodStartHeight, stratagem.activation/stratagem.dropStartTime)
            local _end = sm.vec3.lerp(pos, pos + dropPodStartHeight, (stratagem.activation - 1)/stratagem.dropStartTime)
            local hit, result = sm.physics.spherecast(start, _end, 0.75)
            local hitType = result.type
            if hitType == "character" then
                print("hit char")
                local char = result:getCharacter()
                if char:isPlayer() then
                    sm.event.sendToPlayer(char:getPlayer(), "sv_e_takeDamage", { damage = 999999999 })
                else
                    sm.event.sendToUnit(char:getUnit(), "sv_e_takeDamage", { damage = 999999999 })
                end
            elseif hitType == "body" then
                local shape = result:getShape()
                local data = sm.item.getFeatureData(shape.uuid)
                if data and data.classname == "Package" then
                    print("hit package")
                    sm.event.sendToInteractable( shape.interactable, "sv_e_open", true )
                else
                    print("hit body")
                    stratagem:update(result)
                    skip = true
                end
            elseif hitType == "terrainSurface" or hitType == "terrainAsset" then
                print("hit terrain")
                stratagem:update(result.pointWorld)
                skip = true
            end
        end

        if stratagem.activation <= 0 and stratagem:update() or skip then
            self.queuedStratagems[k] = nil
            self.network:sendToClients("cl_DeleteStratagem", k)
        end
    end
end

function HelldiversBackend:OnStratagemThrow(args)
    local player, stratagem = args.player, GetStratagem(args.code)
    local pId, uuid = player.id, stratagem.uuid

    if sm.game.getLimitedInventory() and GetSvStratagemProgression(player, uuid).charges == 0 then
        return
    end

    if not self.cooldownsPerPlayer[pId] then
        self.cooldownsPerPlayer[pId] = {}
    end

    local tick = sm.game.getServerTick()
    if (self.cooldownsPerPlayer[pId][uuid] or tick) > tick then return end

    sm.projectile.customProjectileAttack({ code = args.code, bouncesLeft = STRATAGEMMAXBOUNCEOUNT }, sm.uuid.new("6411767a-8882-4b94-aae5-381057cde9f9"), 0, args.pos, player.character.direction * 35, player )

    self:sv_save()
    self:sv_requestData(nil, player)
end

function HelldiversBackend:OnStratagemHit(args)
    local stratagem = shallowcopy(GetStratagem(args.data.code))
    local player = args.shooter
    local pId, uuid = player.id, stratagem.uuid
    local id = ("%s_%s"):format(pId, uuid)

    local tick = sm.game.getServerTick()
    if self.queuedStratagems[id] or (self.cooldownsPerPlayer[pId][uuid] or tick) > tick then
        return
    end

    if sm.game.getLimitedInventory() then
        local progression = GetSvStratagemProgression(player, uuid)
        progression.charges = progression.charges - 1
        g_sv_stratagemProgression[pId][uuid] = progression
    end

    self.cooldownsPerPlayer[pId][uuid] = sm.game.getServerTick() + stratagem.cooldown

    args.data = nil
    stratagem.hitData = args

    if stratagem.dropEffect then
        stratagem.dropStartTime = math.min(stratagem.activation, 3 * 40)
    end

    self.queuedStratagems[id] = stratagem

    self.network:sendToClients("cl_OnStratagemHit",
        {
            id = id,
            hitData = args,
            activation = stratagem.activation,
            dropEffect = stratagem.dropEffect,
            pelicanEffect = stratagem.pelicanEffect
        }
    )

    self:sv_save()
    self:sv_requestData(nil, player)
end

function HelldiversBackend:AddCustomStratagem(args)
    local stratagemType = args.type
    local stratagem = GetCustomStratagemTemplate(stratagemType)
    stratagem.uuid = tostring(sm.uuid.generateRandom())
    stratagem.userdata.code = GetRandomStratagemCode()

    if stratagemType == "VehicleSpawn" then
        local bpName = args.name
        local tracker = sm.json.open(blueprintTracker) or {}
        local blueprintPath = ("%s%s.json"):format(blueprintsPath, bpName)

        --[[if isAnyOf(blueprintPath, tracker) then
            return
        end]]

        local creation = sm.creation.exportToTable(args.body, false, true)
        local com = sm.vec3.zero()
        local count = 0
        for k, body in pairs(creation.bodies) do
            for _k, shape in pairs(body.childs) do
                local controller = shape.controller
                if controller then
                    if controller.containers then
                        for __k, data in pairs(controller.containers) do
                            data.container = {}
                        end
                    end

                    if controller.container then
                        controller.container = {}
                    end
                end

                com = com + sm.vec3.new(shape.pos.x, shape.pos.y, shape.pos.z)
                count = count + 1
            end
        end

        com = com / count

        for k, body in pairs(creation.bodies) do
            for _k, shape in pairs(body.childs) do
                shape.pos.x = round(shape.pos.x - com.x)
                shape.pos.y = round(shape.pos.y - com.y)
                shape.pos.z = round(shape.pos.z - com.z)
            end
        end

        for _k, shape in pairs(creation.joints or {}) do
            shape.posA.x = round(shape.posA.x - com.x)
            shape.posA.y = round(shape.posA.y - com.y)
            shape.posA.z = round(shape.posA.z - com.z)

            shape.posB.x = round(shape.posB.x - com.x)
            shape.posB.y = round(shape.posB.y - com.y)
            shape.posB.z = round(shape.posB.z - com.z)
        end

        --if true then return end
        sm.json.save(creation, blueprintPath)

        table.insert(tracker, blueprintPath)
        sm.json.save(tracker, blueprintTracker)

        stratagem.obj.blueprint = blueprintPath
        stratagem.userdata.name = bpName
    end

    table.insert(self.customStratagems, stratagem)
    self:sv_save()
    for k, v in pairs(sm.player.getAllPlayers()) do
        self:sv_requestData(nil, v)
    end
end

function HelldiversBackend:sv_save()
    self.storage:save(
        {
            loadouts = self.loadouts,
            progression = g_sv_stratagemProgression,
            cooldowns = self.cooldownsPerPlayer,
            customStratagems = self.customStratagems
        }
    )
end

function HelldiversBackend:sv_requestData(args, caller)
    self.network:sendToClient(caller, "cl_recieveData",{
        loadout = self.loadouts[caller.id] or {},
        progression = g_sv_stratagemProgression[caller.id] or {},
        cooldowns = self.cooldownsPerPlayer[caller.id] or {},
        customStratagems = self.customStratagems
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
    if cl_setupComplete then return end

    if not sm.HELLDIVERSBACKEND then
        sm.HELLDIVERSBACKEND = self.tool
    end

    g_cl_queuedStratagems = {}
    g_cl_loadout = {}
    g_cl_stratagemProgression = {}
    g_cl_cooldowns = {}
    self.network:sendToServer("sv_requestData")

    cl_setupComplete = true
end

function HelldiversBackend:client_onFixedUpdate()
    if sm.HELLDIVERSBACKEND ~= self.tool or not g_cl_queuedStratagems then return end

    for k, v in pairs(g_cl_queuedStratagems) do
        v.activation = v.activation - 1
        if v.activation >= 0 then
            v.gui:setText("Text", ("Inbound T-%s"):format(FormatStratagemTimer(v.activation/40)))
        else
            v.gui:setText("Text", "Ongoing...")
        end
    end
end

local pelicanCargoOffset = vec3_forward * 2.25
function HelldiversBackend:client_onUpdate(dt)
    if sm.HELLDIVERSBACKEND ~= self.tool or not g_cl_queuedStratagems then return end

    for k, v in pairs(g_cl_queuedStratagems) do
        if v.pod and v.activation <= v.dropStartTime * 40 then
            if not v.pod:isPlaying() then
                v.pod:start()
            end

            v.dropTime = math.min(v.dropTime + dt / v.dropStartTime, 1)
            local pos = v.hitData.position
            v.pod:setPosition(sm.vec3.lerp(pos + dropPodStartHeight, pos, v.dropTime))
        end

        if v.pelicanMovement then
            local pos, rot = v.pelicanMovement:getCameraPosition() or v.hitData.position, (v.pelicanMovement:getCameraRotation() or sm.quat.identity())
            v.pelican:setPosition(pos)
            v.pelican:setRotation(rot)

            if v.activation <= 0 then
                if v.pelicanCargo:isPlaying() then
                    v.pelicanCargo:stop()
                end
            else
                v.pelicanCargo:setPosition(pos - rot * pelicanCargoOffset)
                v.pelicanCargo:setRotation(rot)
            end
        end
    end
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

    local dropEffect = args.dropEffect
    if dropEffect then
        local pod = CreateEffect(dropEffect)
        pod:setRotation(dropPodRotation)
        pod:setScale(sm.vec3.one() * 0.25)

        args.pod = pod
        args.dropStartTime = math.min(args.activation/40, 3)
        args.dropTime = 0
    end

    local pelicanEffect = args.pelicanEffect
    if pelicanEffect then
        local pelicanMovement = sm.effect.createEffect("Pelican - Movement")
        pelicanMovement:setRotation(dropPodRotation)
        pelicanMovement:setPosition(pos)
        pelicanMovement:start()

        local _pos, rot = pelicanMovement:getCameraPosition(), pelicanMovement:getCameraRotation()
        local pelican = sm.effect.createEffect("Pelican")
        pelican:setScale(sm.vec3.one() * 0.25 * 0.5)
        pelican:setPosition(_pos)
        pelican:setRotation(rot)
        pelican:start()

        local pelicanCargo = CreateEffect(pelicanEffect)
        pelicanCargo:setScale(sm.vec3.one() * 0.25)
        pelicanCargo:setPosition(_pos - rot * pelicanCargoOffset)
        pelicanCargo:setRotation(rot)
        pelicanCargo:start()

        args.pelicanMovement = pelicanMovement
        args.pelican = pelican
        args.pelicanCargo = pelicanCargo
    end

    g_cl_queuedStratagems[id] = args
end

function HelldiversBackend:cl_DeleteStratagem(index)
    local data = g_cl_queuedStratagems[index]
    data.gui:close()
    data.beacon:destroy()

    if data.pod then
        sm.effect.playEffect("DropPod - Land", data.hitData.position)

        data.pod:destroy()
    end

    if data.pelicanMovement then
        data.pelicanMovement:destroy()
        data.pelican:destroy()
        data.pelicanCargo:destroy()
    end

    g_cl_queuedStratagems[index] = nil
end

function HelldiversBackend:cl_recieveData(data)
    g_cl_loadout = data.loadout
    g_cl_stratagemProgression = data.progression
    g_cl_cooldowns = data.cooldowns

    ParseCustomStratagems(data.customStratagems)

    if g_stratagemTerminal then
        sm.event.sendToInteractable(g_stratagemTerminal, "cl_refresh")
    end
end
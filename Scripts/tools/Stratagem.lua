dofile "$GAME_DATA/Scripts/game/AnimationUtil.lua"
dofile "$SURVIVAL_DATA/Scripts/util.lua"
dofile "$SURVIVAL_DATA/Scripts/game/survival_shapes.lua"
dofile "$CONTENT_DATA/Scripts/ProgressBar.lua"

---@class StratagemHUD
---@field gui GuiInterface
---@field isOpen boolean
---@field progressbars ProgressBar[]

---@class Stratagem : ToolClass
---@field fpAnimations table
---@field tpAnimations table
---@field isLocal boolean
---@field equipped boolean
---@field wantEquipped boolean
---@field pendingThrow boolean
---@field blendTime number
Stratagem = class()

local renderables = {
    "$CONTENT_DATA/Tools/Stratagem/char_stratagem.rend"
}
local renderablesTp = {
    "$SURVIVAL_DATA/Character/Char_Male/Animations/char_male_tp_eattool.rend",
    "$SURVIVAL_DATA/Character/Char_Tools/Char_eattool/char_eattool_tp.rend",

    "$SURVIVAL_DATA/Character/Char_Male/Animations/char_male_tp_glowstick.rend"
}
local renderablesFp = {
    "$SURVIVAL_DATA/Character/Char_Male/Animations/char_male_fp_eattool.rend",
    "$SURVIVAL_DATA/Character/Char_Tools/Char_eattool/char_eattool_fp.rend",

    "$SURVIVAL_DATA/Character/Char_Male/Animations/char_male_fp_glowstick.rend"
}

sm.tool.preloadRenderables( renderables )
sm.tool.preloadRenderables( renderablesTp )
sm.tool.preloadRenderables( renderablesFp )



function Stratagem:sv_throwAnim()
    self.network:sendToClients("cl_throwAnim")
end

---@param args table
---@param caller Player
function Stratagem:sv_throwStratagem( args, caller )
    self:sv_cancel(nil, caller)
    sm.event.sendToTool(sm.HELLDIVERSBACKEND, "OnStratagemThrow", { player = caller, code = args.code, pos = args.pos })
end

---@param args any
---@param caller Player
function Stratagem:sv_cancel(args, caller)
    if not self.input then return end

    self.network:sendToClient(caller, "cl_lock", nil)
    self.input:destroyShape()
    self.input = nil
end

---@param args any
---@param caller Player
function Stratagem:sv_prime(args, caller)
    local char = caller.character
    local shape = sm.shape.createPart(sm.uuid.new("09a84352-04b2-47d1-9346-15ae4f768d03"), char.worldPosition - sm.vec3.new(0,0,250), sm.quat.identity(), false, true)
    self.network:sendToClient(caller, "cl_lock", shape)

    self.input = shape
end

function Stratagem:sv_saveLoadout(loadout, caller)
    sm.event.sendToTool(sm.HELLDIVERSBACKEND, "sv_setLoadout", { player = caller, loadout = loadout })
end

function Stratagem:sv_updateStratagemColour(type)
    self.network:sendToClients("cl_updateStratagemColour", type)
end



function Stratagem:client_onCreate()
    self.isLocal = self.tool:isLocal()

    if not self.isLocal then return end

    g_stratagemActivated = false
    self.pendingThrow = false

    g_playerData = { hasPlayedTutorial = false, controlScheme = 1 }
    if sm.json.fileExists(PLAYERDATAPATH) then
        g_playerData = sm.json.open(PLAYERDATAPATH)
    end
end

function Stratagem:client_onDestroy()
    if not self.isLocal then return end

    g_stratagemHud.gui:destroy()
    g_stratagemHud = nil
end

function Stratagem.loadAnimations( self )
	self.tpAnimations = createTpAnimations(
        self.tool,
        {
            idle = { "Idle" },
            use = { "glowstick_use", { nextAnimation = "idle" } },
            sprint = { "Sprint_fwd" },
            pickup = { "Pickup", { nextAnimation = "idle" } },
            putdown = { "Putdown" }
        }
    )
    local movementAnimations = {
        idle = "Idle",

        runFwd = "Run_fwd",
        runBwd = "Run_bwd",

        sprint = "Sprint_fwd",

        jump = "Jump",
        jumpUp = "Jump_up",
        jumpDown = "Jump_down",

        land = "Jump_land",
        landFwd = "Jump_land_fwd",
        landBwd = "Jump_land_bwd",

        crouchIdle = "Crouch_idle",
        crouchFwd = "Crouch_fwd",
        crouchBwd = "Crouch_bwd"
    }

    for name, animation in pairs( movementAnimations ) do
        self.tool:setMovementAnimation( name, animation )
    end

    if self.isLocal then
        self.fpAnimations = createFpAnimations(
            self.tool,
            {
                idle = { "Idle", { looping = true } },
                use = { "glowstick_use", { nextAnimation = "idle" } },
                equip = { "Pickup", { nextAnimation = "idle" } },
                unequip = { "Putdown" }
            }
        )

        setFpAnimation( self.fpAnimations, "idle", 5.0 )
    end

    setTpAnimation( self.tpAnimations, "idle", 5.0 )
    self.blendTime = 0.2
end

function Stratagem:client_onFixedUpdate()
    if not self.isLocal or not g_stratagemHud or not g_stratagemHud.gui:isActive() or sm.game.getServerTick()%40 ~= 0 then return end

    UpdateStratagemHud()
end

function Stratagem.client_onUpdate( self, dt )
	if self.isLocal then
		updateFpAnimations( self.fpAnimations, self.equipped, dt )

        if self.pendingThrow then
            local time, frameTime = 0, 0
            if self.fpAnimations.currentAnimation == "use" then
                time = self.fpAnimations.animations["use"].time
                frameTime = 1.175
            end

            if time >= frameTime and frameTime ~= 0 then
                self.network:sendToServer(
                    "sv_throwStratagem",
                    {
                        pos = self.tool:isInFirstPersonView() and sm.camera.getPosition() or self.tool:getTpBonePos("root_item"),
                        code = g_strataGemCode
                    }
                )

                self.pendingThrow = false
                g_stratagemActivated = false
                g_strataGemCode = nil
                self.stratagemUserdata = nil
                self:cl_updateStratagemColour()
            end
        end
	end


	if not self.equipped then
		if self.wantEquipped then
			self.wantEquipped = false
			self.equipped = true
		end
		return
	end


	local crouchWeight = self.tool:isCrouching() and 1.0 or 0.0
	local normalWeight = 1.0 - crouchWeight
	local totalWeight = 0.0

	for name, animation in pairs( self.tpAnimations.animations ) do
		animation.time = animation.time + dt

		if name == self.tpAnimations.currentAnimation then
			animation.weight = math.min( animation.weight + ( self.tpAnimations.blendSpeed * dt ), 1.0 )

			if animation.time >= animation.info.duration - self.blendTime then
				if ( name == "eat" ) then
					setTpAnimation( self.tpAnimations, "pickup",  10.05 )
				elseif name == "drink" then
						setTpAnimation( self.tpAnimations, "pickup", 10.05 )
				elseif name == "pickup" then
					setTpAnimation( self.tpAnimations, "idle", 0.001 )
				elseif animation.nextAnimation ~= "" then
					setTpAnimation( self.tpAnimations, animation.nextAnimation, 1 )
				end
			end
		else
			animation.weight = math.max( animation.weight - ( self.tpAnimations.blendSpeed * dt ), 0.0 )
		end

		totalWeight = totalWeight + animation.weight
	end

	totalWeight = totalWeight == 0 and 1.0 or totalWeight
	for name, animation in pairs( self.tpAnimations.animations ) do
		local weight = animation.weight / totalWeight
		if name == "idle" then
			self.tool:updateMovementAnimation( animation.time, weight )
		elseif animation.crouch then
			self.tool:updateAnimation( animation.info.name, animation.time, weight * normalWeight )
			self.tool:updateAnimation( animation.crouch.name, animation.time, weight * crouchWeight )
		else
			self.tool:updateAnimation( animation.info.name, animation.time, weight )
		end
	end
end

function Stratagem:client_onReload()
    return true
end

function Stratagem:client_onToggle()
    if sm.exists(self.tutorialGui) then
        self.tutorialGui:close()
    end

    local lock = sm.localPlayer.getPlayer().character:getLockingInteractable()
    if lock and lock.shape.uuid == sm.uuid.new("09a84352-04b2-47d1-9346-15ae4f768d03") then return true end

    self.available = {}
    self.selected = {}

    local stratagems = GetStratagemsFromClProgression()
    self.originalLength = #stratagems
    for k, v in pairs(stratagems) do
        if isAnyOf(v.uuid, g_cl_loadout) then
            table.insert(self.selected, v)
        else
            table.insert(self.available, v)
        end
    end

    self.loadoutGui = sm.gui.createGuiFromLayout("$CONTENT_DATA/Gui/Layouts/LoadoutTerminal.layout", true)
    self.loadoutGui:createGridFromJson("AvailableGrid",
        {
            type = "materialGrid",
            layout = "$CONTENT_DATA/Gui/Layouts/Loadout_GridItem.layout",
            itemWidth = 44,
            itemHeight = 60,
            itemCount = self.originalLength,
        }
    )

    self:cl_refreshGrid("AvailableGrid", self.available, self.originalLength)
    self.loadoutGui:setGridButtonCallback("Click", "cl_onSelect")

    self.loadoutGui:createGridFromJson("SelectedGrid",
        {
            type = "materialGrid",
            layout = "$CONTENT_DATA/Gui/Layouts/Loadout_GridItem.layout",
            itemWidth = 44,
            itemHeight = 60,
            itemCount = STRATAGEMINVENTORYSIZE,
        }
    )
    self:cl_refreshGrid("SelectedGrid", self.selected, STRATAGEMINVENTORYSIZE)

    self.loadoutGui:setOnCloseCallback("cl_onClose")

    self.loadoutGui:open()

    return true
end

function Stratagem:cl_refreshGrid(grid, items, size)
    for i = 1, size do
        local data = items[i]
        if data then
            self.loadoutGui:setGridItem(grid, i - 1, {
                itemId = data.icon,
                quantity = data.charges,
                stratagem = i
            })
        else
            self.loadoutGui:setGridItem(grid, i - 1, nil)
        end
    end
end

function Stratagem:cl_onSelect(button, id, data, gridName)
    if gridName == "AvailableGrid" then
        if #self.selected == STRATAGEMINVENTORYSIZE then
            sm.audio.play("RaftShark")
            return
        end

        table.insert(self.selected, self.available[id + 1])
        table.remove(self.available, id + 1)
    else
        table.insert(self.available, self.selected[id + 1])
        table.remove(self.selected, id + 1)
    end

    self:cl_refreshGrid("AvailableGrid", self.available, self.originalLength)
    self:cl_refreshGrid("SelectedGrid", self.selected, STRATAGEMINVENTORYSIZE)
end

function Stratagem:cl_onClose()
    local stratagems = {}
    for k, v in pairs(self.selected) do
        table.insert(stratagems, v.uuid)
    end

    self.network:sendToServer("sv_saveLoadout", stratagems)
end

function Stratagem:client_onEquip()
	self.wantEquipped = true

	self:cl_updateRends()

	self:loadAnimations()

	setTpAnimation( self.tpAnimations, "pickup", 0.0001 )
	if self.isLocal then
		swapFpAnimation( self.fpAnimations, "unequip", "equip", 0.2 )

        if not g_playerData.hasPlayedTutorial then
            self.tutorialGui = sm.gui.createGuiFromLayout( "$GAME_DATA/Gui/Layouts/Tutorial/PopUp_Tutorial.layout", true, { isHud = true, isInteractive = false, needsCursor = false } )
            self.tutorialGui:setText( "TextTitle", "HOW TO USE STRATAGEMS" )
            self.tutorialGui:setText( "TextMessage",
                ("1. Buy stratagems at #ff0000Stratagem Terminals#a5a5a5\n2. Press #df7f00%s#a5a5a5 to create your #ff0000loadout#a5a5a5\n3. Hold #df7f00%s#a5a5a5 to #ff0000type#a5a5a5\n4. #ff0000Type#a5a5a5 in the stratagem code with #df7f00%s%s%s%s#a5a5a5\n5. #ff0000Throw#a5a5a5 the stratagem with #df7f00%s#a5a5a5"):format(
                    sm.gui.getKeyBinding("NextCreateRotation"),
                    sm.gui.getKeyBinding("Create"),
                    sm.gui.getKeyBinding("Forward"),
                    sm.gui.getKeyBinding("Backward"),
                    sm.gui.getKeyBinding("StrafeLeft"),
                    sm.gui.getKeyBinding("StrafeRight"),
                    sm.gui.getKeyBinding("Create")
                )
            )
            local dismissText = string.format( sm.gui.translateLocalizationTags( "#{TUTORIAL_DISMISS}" ), sm.gui.getKeyBinding( "NextCreateRotation" ) )
            self.tutorialGui:setText( "TextDismiss", dismissText )
            self.tutorialGui:setImage( "ImageTutorial", "gui_tutorial_image_hunger.png" )
            self.tutorialGui:open()

            g_playerData.hasPlayedTutorial = true
            sm.json.save(g_playerData, PLAYERDATAPATH)
        end

        if not g_stratagemHud then
            ---@type StratagemHUD
            g_stratagemHud = {
                gui = sm.gui.createGuiFromLayout("$CONTENT_DATA/Gui/Layouts/StratagemHud.layout", false, { isHud = true, isInteractive = false, needsCursor = false }),
                progressbars = {},
                isOpen = false
            }

            for i = 1, STRATAGEMINVENTORYSIZE do
                g_stratagemHud.progressbars[i] = ProgressBar():init(g_stratagemHud.gui, "stratagem"..i.."_cooldown", "$CONTENT_DATA/Gui/StratagemCooldown", 100)
            end
        end

        UpdateStratagemHud()
        g_stratagemHud.gui:open()
	end
end

function Stratagem.client_onUnequip( self )
	self.wantEquipped = false
	self.equipped = false

	if sm.exists( self.tool ) then
		setTpAnimation( self.tpAnimations, "putdown" )
		if self.isLocal then
			self.tool:setMovementSlowDown( false )
			self.tool:setBlockSprint( false )
			self.tool:setCrossHairAlpha( 1.0 )
			self.tool:setInteractionTextSuppressed( false )
			if self.fpAnimations.currentAnimation ~= "unequip" then
				swapFpAnimation( self.fpAnimations, "equip", "unequip", 0.2 )
			end

            if sm.exists(self.tutorialGui) then
                self.tutorialGui:close()
            end

            g_stratagemActivated = false
            g_strataGemCode = nil
            self.stratagemUserdata = nil
            self.pendingThrow = false

            g_stratagemHud.isOpen = false
            g_stratagemHud.gui:close()

            self.network:sendToServer("sv_cancel")
		end
	end
end

local indexToArrow = {
    ["1"] = "icon_keybinds_arrow_left.png",
    ["2"] = "icon_keybinds_arrow_right.png",
    ["3"] = "icon_keybinds_arrow_up.png",
    ["4"] = "icon_keybinds_arrow_down.png"
}

local col_bright = sm.color.new("ffffff")
local col_dark = sm.color.new("999999")
function UpdateStratagemHud()
    local progression = g_cl_loadout
    local tick = sm.game.getServerTick()
    local id = sm.localPlayer.getPlayer().id.."_"
    local gui = g_stratagemHud.gui
    local open = g_stratagemHud.isOpen
    for i = 1, STRATAGEMINVENTORYSIZE do
        local uuid = progression[i]
        local widget = "stratagem"..i

        if uuid then
            local stratagem = GetStratagemUserdata(uuid)
            local isActive = g_stratagemActivated and stratagem.code == g_strataGemCode
            gui:setVisible(widget, open or isActive)

            gui:setText(widget.."_name", stratagem.name)
            gui:setIconImage(widget.."_preview", sm.uuid.new(stratagem.icon))
            gui:setText(widget.."_charges", tostring(GetClStratagemProgression(uuid).charges))

            if isActive then
                gui:setText(widget.."_status", "Activating...")
                gui:setVisible(widget.."_codePanel", false)

                goto continue
            end

            local stratagemInbound = g_cl_queuedStratagems[id..uuid]
            if stratagemInbound then
                local time = stratagemInbound.activation/40
                if time > 0 then
                    gui:setText(widget.."_status", ("Inbound T-%s"):format(FormatStratagemTimer(time)))
                else
                    gui:setText(widget.."_status", "Ongoing...")
                end
            end

            local bar = g_stratagemHud.progressbars[i]
            local stratagemCooldown = g_cl_cooldowns[uuid] or 0
            local isOnCooldown = stratagemCooldown > tick
            gui:setVisible(widget.."_codePanel", not isOnCooldown)
            if isOnCooldown then
                local seconds = (stratagemCooldown - tick)/40
                if not stratagemInbound then
                    gui:setText(widget.."_status", ("Cooldown T-%s"):format(FormatStratagemTimer(seconds)))
                end

                bar:update_percentage(1 - seconds/(GetStratagemByUUUID(uuid).cooldown/40))
            else
                gui:setText(widget.."_status", "")
                bar:update_percentage(1)

                local code = stratagem.code
                if g_strataGemCode then
                    local codeLength = #g_strataGemCode
                    local subCode = code:sub(1, codeLength)
                    if subCode == g_strataGemCode then
                        for j = 1, 8 do
                            local box = widget.."_codeDigit"..j
                            gui:setImage(box, indexToArrow[code:sub(j, j)] or "$GAME_DATA/Textures/transparent.tga")
                            gui:setColor(box, j <= codeLength and col_bright or col_dark)
                        end
                    else
                        for j = 1, 8 do
                            local box = widget.."_codeDigit"..j
                            gui:setImage(box, indexToArrow[code:sub(j, j)] or "$GAME_DATA/Textures/transparent.tga")
                            gui:setColor(box, col_dark)
                        end
                    end
                else
                    for j = 1, 8 do
                        local box = widget.."_codeDigit"..j
                        gui:setImage(box, indexToArrow[code:sub(j, j)] or "$GAME_DATA/Textures/transparent.tga")
                        gui:setColor(box, col_bright)
                    end
                end
            end
        else
            gui:setVisible(widget, false)
        end
        ::continue::
    end
end

function Stratagem:client_onEquippedUpdate( lmb, rmb, f )
    if sm.world.getCurrentWorld():isIndoor() then
        sm.gui.setInteractionText("<p bg='gui_keybinds_bg' spacing='0'>Stratagems are disabled indoors!</p>")
        return true, false
    end

    if g_stratagemActivated then
        if self.pendingThrow then return true, true end

        if lmb == 1 then
            self.pendingThrow = true
            self.network:sendToServer("sv_throwAnim")
        end

        sm.gui.setInteractionText("", sm.gui.getKeyBinding("Create", true), "Throw "..self.stratagemUserdata.name)
        sm.gui.setInteractionText("", sm.gui.getKeyBinding("Attack", true), "Cancel")

        if rmb == 1 and not self.pendingThrow then
            g_stratagemActivated = false
            g_strataGemCode = nil
            self.stratagemUserdata = nil
            self.network:sendToServer("sv_updateStratagemColour")
            UpdateStratagemHud()
        end

        return true, true
    else
        if lmb == 1 then
            if #g_cl_loadout == 0 then
                sm.gui.displayAlertText("Your loadout is empty!")
            end

            g_stratagemHud.isOpen = true
            UpdateStratagemHud()
            --g_stratagemHud.gui:open()
            self.network:sendToServer("sv_prime")
        elseif lmb == 3 then
            g_stratagemHud.isOpen = false
            --g_stratagemHud.gui:close()
            self.network:sendToServer("sv_cancel")

            if g_strataGemCode then
                local stratagems = {}
                local tick = sm.game.getServerTick()
                for k, v in pairs(GetStratagems()) do
                    local uuid = v.uuid
                    if isAnyOf(uuid, g_cl_loadout) and GetClStratagemProgression(uuid).charges > 0 and (g_cl_cooldowns[uuid] or tick) <= tick then
                        table.insert(stratagems, v)
                    end
                end

                local stratagem = GetStratagem(g_strataGemCode, stratagems)
                if stratagem then
                    g_stratagemActivated = true
                    self.stratagemUserdata = GetStratagemUserdata(GetStratagem(g_strataGemCode).uuid)
                    self.network:sendToServer("sv_updateStratagemColour", self.stratagemUserdata.type)
                else
                    sm.audio.play("RaftShark")
                    g_strataGemCode = nil
                end
            end

            UpdateStratagemHud()
        else
            sm.gui.setInteractionText(sm.gui.getKeyBinding("Create", true).."Call", "")
        end
    end

	return true, false
end

function Stratagem:cl_updateRends()
    local currentRenderablesTp = {}
	local currentRenderablesFp = {}
	for k,v in pairs( renderablesTp ) do currentRenderablesTp[#currentRenderablesTp+1] = v end
	for k,v in pairs( renderablesFp ) do currentRenderablesFp[#currentRenderablesFp+1] = v end
    for k,v in pairs( renderables ) do
        currentRenderablesTp[#currentRenderablesTp+1] = v
        currentRenderablesFp[#currentRenderablesFp+1] = v
    end

	self.tool:setTpRenderables( currentRenderablesTp )
    if self.isLocal then
		self.tool:setFpRenderables( currentRenderablesFp )
    end
end

function Stratagem:cl_throwAnim()
    if self.isLocal then
        setFpAnimation( self.fpAnimations, "use", 0.25 )
        self.fpAnimations.animations.use.time = 0.6

        self.pendingThrow = true
    end
    setTpAnimation( self.tpAnimations, "use", 2.5 )
    self.tpAnimations.animations.use.time = 0.6

    sm.audio.play("Sledgehammer - Swing", self.tool:getPosition())
end

function Stratagem:cl_updateStratagemColour(type)
    local col = sm.color.new("ffffff")
    if type then
        sm.effect.playHostedEffect("Stratagem - Armed", self.tool:getOwner().character)
        col = STRATAGEMTYPETOCOLOUR[type]
    end

    self.tool:setTpColor(col)
    if self.isLocal then
        self.tool:setFpColor(col)
    end
end

function Stratagem:cl_lock(shape)
    if not sm.exists(shape) then
        sm.event.sendToTool(self.tool, "cl_lock", shape)
        return
    end

    sm.localPlayer.getPlayer().character:setLockingInteractable(shape.interactable)
end



---@class Input : ShapeClass
Input = class()

local blockActions = {
    [1] = {
        [1] = true,
        [2] = true,
        [3] = true,
        [4] = true
    },
    [2] = {
        [5] = true,
        [6] = true,
        [7] = true,
        [8] = true
    }
}

local convertInputs = {
    [1] = "1",
    [2] = "2",
    [3] = "3",
    [4] = "4",
    [5] = "1",
    [6] = "2",
    [7] = "3",
    [8] = "4"
}

function Input:client_onAction(action, state)
    if g_stratagemActivated then
        sm.log.warning("[HELLDIVERS] Blocked invalid stratagem input")
        return false
    end

    local isBlocked = blockActions[g_playerData.controlScheme][action] == true and state
    if isBlocked then
        g_strataGemCode = (g_strataGemCode or "")..convertInputs[action]
        UpdateStratagemHud()
        sm.audio.play("PaintTool - ColorPick")
    end

    return isBlocked
end
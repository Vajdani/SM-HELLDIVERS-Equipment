dofile "$GAME_DATA/Scripts/game/AnimationUtil.lua"
dofile "$SURVIVAL_DATA/Scripts/util.lua"
dofile "$SURVIVAL_DATA/Scripts/game/survival_shapes.lua"

---@class Stratagem : ToolClass
---@field fpAnimations table
---@field tpAnimations table
---@field isLocal boolean
---@field equipped boolean
---@field wantEquipped boolean
---@field pendingThrow boolean
---@field blendTime number
Stratagem = class()
Stratagem.variants = {
    {
        name = "Resupply",
        code = "4432",
        cooldown = 160 * 40,
        activation = 12 * 40,
        type = "mission",
        summon = function(self)
            local uuid = sm.uuid.new("ad35f7e6-af8f-40fa-aef4-77d827ac8a8a")
            local rotation = sm.quat.angleAxis(math.rad(90), sm.vec3.new(1,0,0))
            local chest = sm.shape.createPart(uuid, self.hitData.position - rotation * sm.item.getShapeOffset(uuid), rotation, false, true)
            local container = chest.interactable:getContainer(0)
            for k, v in pairs(self.items) do
                sm.container.beginTransaction()
                sm.container.collect(container, v.uuid, v.amount)
                sm.container.endTransaction()
            end

            return true
        end,
        items = {
            {
                uuid = obj_plantables_potato,
                amount = 500
            },
            {
                uuid = obj_consumable_glowstick,
                amount = 100
            },
            {
                uuid = obj_interactive_propanetank_large,
                amount = 5
            },
            {
                uuid = obj_interactive_propanetank_small,
                amount = 10
            }
        }
    },
    {
        name = "Eagle 500kg Bomb",
        code = "32444",
        cooldown = 160 * 40,
        activation = 3 * 40,
        type = "offensive",
        summon = function(self)
            sm.physics.explode(self.hitData.position, 100, 50, 75, 1000, "PropaneTank - ExplosionBig")
            return true
        end
    },
    {
        name = "Orbital Airburst Strike",
        code = "222",
        cooldown = 120 * 40,
        activation = 3 * 40,
        type = "offensive",
        summon = function(self)
            if self.tick%40 == 0 then
                local origin = self.hitData.position + sm.vec3.new(0,0,20)
                for i = 0, 6 do
                    local dir = sm.vec3.new(0,1,0):rotate(-math.rad(math.random(45, 75)), sm.vec3.new(1,0,0)):rotate(math.rad(i * 60), sm.vec3.new(0,0,1))
                    sm.projectile.projectileAttack(projectile_explosivetape, 100, origin, dir * 100, self.hitData.shooter)
                    sm.effect.playEffect("PropaneTank - ExplosionSmall", origin)
                end
            end

            self.tick = self.tick + 1
            return self.tick >= 120
        end,
        tick = 0
    },
    {
        name = "Orbital Gatling Barrage",
        code = "24133",
        cooldown = 80 * 40,
        activation = 1 * 40,
        type = "offensive",
        summon = function(self)
            if self.tick%2 == 0 then
                local origin = self.hitData.position + sm.vec3.new(0,0,20)
                local dir = sm.vec3.new(0,1,0):rotate(-math.rad(math.random(45, 75)), sm.vec3.new(1,0,0)):rotate(math.rad(math.random(0, 359)), sm.vec3.new(0,0,1))
                sm.projectile.projectileAttack(projectile_potato, 100, origin, dir * 100, self.hitData.shooter)
                sm.effect.playEffect("SpudgunSpinner - SpinnerMuzzel", origin, sm.vec3.zero(), sm.vec3.getRotation(dir, sm.vec3.new(0,0,1)))
            end

            self.tick = self.tick + 1
            return self.tick >= 160
        end,
        tick = 0
    }
}

local renderables = {
    "$CONTENT_DATA/Tools/Renderables/char_stratagem.rend"
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
    sm.projectile.customProjectileAttack({ code = args.code }, sm.uuid.new("6411767a-8882-4b94-aae5-381057cde9f9"), 0, args.pos, caller.character.direction * 35, caller )
end

---@param args any
---@param caller Player
function Stratagem:sv_cancel(args, caller)
    if not self.input then return end

    caller.character:setLockingInteractable(nil)
    self.input:destroyShape()
    self.input = nil
end

---@param args any
---@param caller Player
function Stratagem:sv_prime(args, caller)
    local char = caller.character
    local shape = sm.shape.createPart(sm.uuid.new("09a84352-04b2-47d1-9346-15ae4f768d03"), char.worldPosition - sm.vec3.new(0,0,250), sm.quat.identity(), false, true)
    char:setLockingInteractable(shape.interactable)

    self.input = shape
end



function Stratagem:client_onCreate()
    self.isLocal = self.tool:isLocal()

    if not self.isLocal then return end

    self.activated = false
    self.pendingThrow = false
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

                self.activated = false
                self.pendingThrow = false
                g_strataGemCode = nil
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

function Stratagem:client_onToggle()
	return true
end

function Stratagem:client_onEquip()
	self.wantEquipped = true

	self:cl_updateRends()

	self:loadAnimations()

	setTpAnimation( self.tpAnimations, "pickup", 0.0001 )
	if self.isLocal then
		swapFpAnimation( self.fpAnimations, "unequip", "equip", 0.2 )
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
		end
	end
end

function Stratagem:client_onEquippedUpdate( lmb, rmb, f )
    if self.activated then
        if lmb == 1 then
            self.network:sendToServer("sv_throwAnim")
        end
    else
        if lmb == 1 then
            self.network:sendToServer("sv_prime")
        elseif lmb == 2 then
            sm.gui.setInteractionText("Code:", g_strataGemCode or "", "")
        elseif lmb == 3 then
            self.network:sendToServer("sv_cancel")

            if GetStratagemByCode(g_strataGemCode) then
                self.activated = true
                sm.effect.playHostedEffect("Stratagem - Armed", self.tool:getOwner().character)
            else
                sm.audio.play("RaftShark")
                g_strataGemCode = nil
            end
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



---@class Input : ShapeClass
Input = class()

local blockActions = {
    [1] = true,
    [2] = true,
    [3] = true,
    [4] = true
}

function Input:client_onAction(action, state)
    local isBlocked = blockActions[action] == true and state
    if isBlocked then
        g_strataGemCode = (g_strataGemCode or "")..action
        sm.audio.play("PaintTool - ColorPick")
    end

    return isBlocked
end
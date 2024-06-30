---@class GunSetting
---@field name string
---@field icon string

---@class GunSettings
---@field fireMode? GunSetting[]
---@field flashLight? GunSetting[]
---@field sight? GunSetting[]

---@class AmmoData
---@field uuid Uuid
---@field amount number

---@class FireMode
---@field fireCooldown function|number
---@field spreadCooldown number
---@field spreadIncrement number
---@field spreadMinAngle number
---@field spreadMaxAngle number
---@field fireVelocity number
---@field minDispersionStanding number
---@field minDispersionCrouching number
---@field maxMovementDispersion number
---@field jumpDispersionMultiplier number

---@class ShootData
---@field ammo AmmoData
---@field projectile Uuid
---@field damage number
---@field pellets number
---@field normalFireMode FireMode
---@field aimFireMode FireMode

---@class BaseGun : ToolClass
---@field isLocal boolean
---@field shootEffect Effect
---@field shootEffectFP Effect
---@field tpAnimations table
---@field fpAnimations table
---@field fireCooldownTimer number
---@field spreadCooldownTimer number
---@field movementDispersion number
---@field sprintCooldownTimer number
---@field sprintCooldown number
---@field aimBlendSpeed number
---@field blendTime number
---@field jointWeight number
---@field spineWeight number
---@field aimWeight number
---@field aiming boolean
---@field equipped boolean
---@field wantEquipped boolean
---@field magCapacity number
---@field magAmount number
---@field hipRecoilRecoverySpeed number
---@field aimRecoilRecoverySpeed number
---@field settings GunSettings
---@field defaultSettings { [string]: number }
---@field shootEffectNameTP string
---@field shootEffectNameFP string
---@field shootData ShootData
---@field renderables string[]
---@field renderablesTp string[]
---@field renderablesFp string[]
BaseGun = class()

function BaseGun:server_onCreate()
	local data = self.storage:load() or {}
	self.sv_ammo = data.ammo or self.magCapacity
	self.sv_mags = data.mags or self.magAmount
	self.sv_settings = data.settings or self.defaultSettings

	self:sv_saveAndSync()
end

function BaseGun:server_onFixedUpdate(dt)
    if not self.equipped then
        self.sv_reloadTime = nil
        return
    end

    if self.sv_reloadTime then
        self.sv_reloadTime = self.sv_reloadTime - dt
        if self.sv_reloadTime <= 0 then
            self.sv_reloadTime = nil
            self.sv_ammo = self.magCapacity
            self.sv_mags = self.sv_mags - 1
        	self:sv_saveAndSync()
        end
    end
end

function BaseGun:sv_save()
	self.storage:save({ ammo = self.sv_ammo, mags = self.sv_mags, settings = self.sv_settings })
end

function BaseGun:sv_saveAndSync()
	local data = { ammo = self.sv_ammo, mags = self.sv_mags, settings = self.sv_settings }
	self.storage:save(data)
	self.network:setClientData(data)
end

function BaseGun:sv_updateFireMode(mode)
	self.sv_settings.fireMode = mode
	self:sv_saveAndSync()
end

function BaseGun:sv_startReload(duration)
    if not self:canReload() or self.sv_mags == 0 then return end

    self.sv_reloadTime = duration
    self.network:sendToClients("cl_startReload")
end



function BaseGun:client_onCreate()
	self.isLocal = self.tool:isLocal()
	self.shootEffect = sm.effect.createEffect(self.shootEffectNameTP)
	self.shootEffectFP = sm.effect.createEffect(self.shootEffectNameFP)

	self.recoil_target_x = 0
	self.recoil_target_y = 0
	self.recoil_x = 0
	self.recoil_y = 0

    self.fireCooldownTimer = 0.0
	self.spreadCooldownTimer = 0.0

	self.movementDispersion = 0.0

	self.sprintCooldownTimer = 0.0
	self.sprintCooldown = 0.3

	self.aimBlendSpeed = 3.0
	self.blendTime = 0.2

	self.jointWeight = 0.0
	self.spineWeight = 0.0
	local cameraWeight, cameraFPWeight = self.tool:getCameraWeights()
	self.aimWeight = math.max(cameraWeight, cameraFPWeight)

	if not self.isLocal then return end

	self.cl_ammo = 0
	self.cl_mags = 0
	self.cl_settings = {}
end

function BaseGun:client_onEquip(animate)
	if animate then
		sm.audio.play("PotatoRifle - Equip", self.tool:getPosition())
	end

	self.wantEquipped = true
	self.aiming = false
	local cameraWeight, cameraFPWeight = self.tool:getCameraWeights()
	self.aimWeight = math.max(cameraWeight, cameraFPWeight)
	self.jointWeight = 0.0

	local currentRenderablesTp = { "$CONTENT_DATA/Tools/char_male_recoil.rend" }
	local currentRenderablesFp = { "$CONTENT_DATA/Tools/char_male_recoil.rend" }

	for k, v in pairs(self.renderablesTp) do currentRenderablesTp[#currentRenderablesTp + 1] = v end
	for k, v in pairs(self.renderablesFp) do currentRenderablesFp[#currentRenderablesFp + 1] = v end
	for k, v in pairs(self.renderables) do
        currentRenderablesTp[#currentRenderablesTp + 1] = v
        currentRenderablesFp[#currentRenderablesFp + 1] = v
    end

	self.tool:setTpRenderables(currentRenderablesTp)
    if self.isLocal then
		self.tool:setFpRenderables(currentRenderablesFp)
    end

	self:loadAnimations()

	setTpAnimation(self.tpAnimations, "pickup", 0.0001)
	if self.isLocal then
		swapFpAnimation(self.fpAnimations, "unequip", "equip", 0.2)
	end
end

function BaseGun:client_onUnequip(animate)
	self.wantEquipped = false
	self.equipped = false
	self.aiming = false
	if sm.exists(self.tool) then
		if animate then
			sm.audio.play("PotatoRifle - Unequip", self.tool:getPosition())
		end
		setTpAnimation(self.tpAnimations, "putdown")

		self.tool:updateAnimation("recoil_horizontal", 0, 0)
		self.tool:updateAnimation("recoil_vertical", 0, 0)

		if self.isLocal then
			self.tool:setMovementSlowDown(false)
			self.tool:setBlockSprint(false)
			self.tool:setCrossHairAlpha(1.0)
			self.tool:setInteractionTextSuppressed(false)

			self.tool:updateFpAnimation("recoil_horizontal", 0.5, 0, false)
			self.tool:updateFpAnimation("recoil_vertical", 0.5, 0, false)

			if self.fpAnimations.currentAnimation ~= "unequip" then
				swapFpAnimation(self.fpAnimations, "equip", "unequip", 0.2)
			end
		end
	end
end

local aimAnims = {
    aimInto = true,
    aimIdle = true,
    aimShoot = true
}

function BaseGun:client_onUpdate(dt)
	-- First person animation	
	local isSprinting = self.tool:isSprinting()
	local isCrouching = self.tool:isCrouching()

	if self.isLocal then
		if self.equipped then
			local currentAnim = self.fpAnimations.currentAnimation
			if isSprinting and currentAnim ~= "sprintInto" and currentAnim ~= "sprintIdle" then
				swapFpAnimation(self.fpAnimations, "sprintExit", "sprintInto", 0.0)
			elseif not isSprinting and (currentAnim == "sprintIdle" or currentAnim == "sprintInto") then
				swapFpAnimation(self.fpAnimations, "sprintInto", "sprintExit", 0.0)
			end

            local aimActive = aimAnims[currentAnim] == true
			if self.aiming and not aimActive then
				swapFpAnimation(self.fpAnimations, "aimExit", "aimInto", 0.0)
            elseif not self.aiming and aimActive then
				swapFpAnimation(self.fpAnimations, "aimInto", "aimExit", 0.0)
			end

            local x, y = sm.localPlayer.getMouseDelta()
            self.x = (self.x or 0) + x * 0.5
            self.y = (self.y or 0) + y * 0.5

			self.tool:updateFpAnimation("recoil_horizontal", 0.5 + self.recoil_x + self.x, 1, false)
			self.tool:updateFpAnimation("recoil_vertical", 0.5 - self.recoil_y + self.y, 1, false)

            self.x = sm.util.lerp(self.x, 0, dt * 10)
            self.y = sm.util.lerp(self.y, 0, dt * 10)
		end
		updateFpAnimations(self, self.equipped, dt)
	end

	if not self.equipped then
		if self.wantEquipped then
			self.wantEquipped = false
			self.equipped = true
		end
		return
	end

	self.tool:updateAnimation("recoil_horizontal", 0.5 + self.recoil_x, 1)
	self.tool:updateAnimation("recoil_vertical", 0.5 - self.recoil_y, 1)

	self.recoil_x = sm.util.lerp(self.recoil_x, self.recoil_target_x, dt * 10)
	self.recoil_y = sm.util.lerp(self.recoil_y, self.recoil_target_y, dt * 10)

	local recoilRecovery = self.aiming and self.aimRecoilRecoverySpeed or self.hipRecoilRecoverySpeed
	self.recoil_target_x = sm.util.lerp(self.recoil_target_x, 0, dt * recoilRecovery)
	self.recoil_target_y = sm.util.lerp(self.recoil_target_y, 0, dt * recoilRecovery)

	if self.isLocal then
		local effectPos
		local dir = sm.localPlayer.getDirection()
		local firePos = self.tool:getFpBonePos("pejnt_barrel")

		if not self.aiming then
			effectPos = firePos + dir * 0.2
		else
			effectPos = firePos + dir * 0.45
		end

		self.shootEffectFP:setPosition(effectPos)
		self.shootEffectFP:setVelocity(self.tool:getMovementVelocity())
		self.shootEffectFP:setRotation(sm.vec3.getRotation(sm.vec3.new(0, 0, 1), dir))
	end

	local dir = self.tool:getTpBoneDir("pejnt_barrel")
	local pos = self.tool:getTpBonePos("pejnt_barrel") + dir * 0.2

	self.shootEffect:setPosition(pos)
	self.shootEffect:setVelocity(self.tool:getMovementVelocity())
	self.shootEffect:setRotation(sm.vec3.getRotation(sm.vec3.new(0, 0, 1), dir))

	-- Timers
	self.fireCooldownTimer = math.max(self.fireCooldownTimer - dt, 0.0)
	self.spreadCooldownTimer = math.max(self.spreadCooldownTimer - dt, 0.0)
	self.sprintCooldownTimer = math.max(self.sprintCooldownTimer - dt, 0.0)


	if self.isLocal then
		local dispersion = 0.0
		local fireMode = self.aiming and self.shootData.aimFireMode or self.shootData.normalFireMode
		local recoilDispersion = 1.0 - (math.max(fireMode.minDispersionCrouching, fireMode.minDispersionStanding) + fireMode.maxMovementDispersion)

		if isCrouching then
			dispersion = fireMode.minDispersionCrouching
		else
			dispersion = fireMode.minDispersionStanding
		end

		if self.tool:getRelativeMoveDirection():length() > 0 then
			dispersion = dispersion + fireMode.maxMovementDispersion * self.tool:getMovementSpeedFraction()
		end

		if not self.tool:isOnGround() then
			dispersion = dispersion * fireMode.jumpDispersionMultiplier
		end

		self.movementDispersion = dispersion

		self.spreadCooldownTimer = clamp(self.spreadCooldownTimer, 0.0, fireMode.spreadCooldown)
		local spreadFactor = fireMode.spreadCooldown > 0.0 and clamp(self.spreadCooldownTimer / fireMode.spreadCooldown, 0.0, 1.0) or 0.0

		self.tool:setDispersionFraction(clamp(self.movementDispersion + spreadFactor * recoilDispersion, 0.0, 1.0))

		if self.aiming then
			if self.tool:isInFirstPersonView() then
				self.tool:setCrossHairAlpha(0.0)
			else
				self.tool:setCrossHairAlpha(1.0)
			end
			self.tool:setInteractionTextSuppressed(true)
		else
			self.tool:setCrossHairAlpha(1.0)
			self.tool:setInteractionTextSuppressed(false)
		end
	end

	-- Sprint block
	local blockSprint = self.aiming or self.sprintCooldownTimer > 0.0
	self.tool:setBlockSprint(blockSprint)

	local playerDir = self.tool:getSmoothDirection()
	local angle = math.asin(playerDir:dot(sm.vec3.new(0, 0, 1))) / (math.pi / 2)

	local crouchWeight = isCrouching and 1.0 or 0.0
	local normalWeight = 1.0 - crouchWeight

    local totalWeight = 0.0
	for name, animation in pairs( self.tpAnimations.animations ) do
		animation.time = animation.time + dt

		if name == self.tpAnimations.currentAnimation then
			animation.weight = math.min( animation.weight + ( self.tpAnimations.blendSpeed * dt ), 1.0 )

			if animation.time >= animation.info.duration - self.blendTime then
				if ( name == "shoot" or name == "aimShoot" ) then
					setTpAnimation( self.tpAnimations, self.aiming and "aim" or "idle", 10.0 )
				elseif name == "pickup" then
					setTpAnimation( self.tpAnimations, self.aiming and "aim" or "idle", 0.001 )
				elseif animation.nextAnimation ~= "" then
					setTpAnimation( self.tpAnimations, animation.nextAnimation, 0.001 )
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

	-- Third Person joint lock
	local relativeMoveDirection = self.tool:getRelativeMoveDirection()
	if (((isAnyOf(self.tpAnimations.currentAnimation, { "aimInto", "aim", "shoot" }) and (relativeMoveDirection:length() > 0 or isCrouching)) or (self.aiming and (relativeMoveDirection:length() > 0 or isCrouching))) and not isSprinting) then
		self.jointWeight = math.min(self.jointWeight + (10.0 * dt), 1.0)
	else
		self.jointWeight = math.max(self.jointWeight - (6.0 * dt), 0.0)
	end

	if (not isSprinting) then
		self.spineWeight = math.min(self.spineWeight + (10.0 * dt), 1.0)
	else
		self.spineWeight = math.max(self.spineWeight - (10.0 * dt), 0.0)
	end

	local finalAngle = (0.5 + angle * 0.5)
	self.tool:updateAnimation("spudgun_spine_bend", finalAngle, self.spineWeight)

	local totalOffsetZ = lerp(-22.0, -26.0, crouchWeight)
	local totalOffsetY = lerp(6.0, 12.0, crouchWeight)
	local crouchTotalOffsetX = clamp((angle * 60.0) - 15.0, -60.0, 40.0)
	local normalTotalOffsetX = clamp((angle * 50.0), -45.0, 50.0)
	local totalOffsetX = lerp(normalTotalOffsetX, crouchTotalOffsetX, crouchWeight)

	local finalJointWeight = (self.jointWeight)

	self.tool:updateJoint("jnt_hips", sm.vec3.new(totalOffsetX, totalOffsetY, totalOffsetZ), 0.35 * finalJointWeight * (normalWeight))
	local crouchSpineWeight = (0.35 / 3) * crouchWeight

	self.tool:updateJoint("jnt_spine1", sm.vec3.new(totalOffsetX, totalOffsetY, totalOffsetZ), (0.10 + crouchSpineWeight) * finalJointWeight)
	self.tool:updateJoint("jnt_spine2", sm.vec3.new(totalOffsetX, totalOffsetY, totalOffsetZ), (0.10 + crouchSpineWeight) * finalJointWeight)
	self.tool:updateJoint("jnt_spine3", sm.vec3.new(totalOffsetX, totalOffsetY, totalOffsetZ), (0.45 + crouchSpineWeight) * finalJointWeight)
	self.tool:updateJoint("jnt_head", sm.vec3.new(totalOffsetX, totalOffsetY, totalOffsetZ), 0.3 * finalJointWeight)

	-- Camera update
	local bobbing = 1
	if self.aiming then
		local blend = 1 - math.pow(1 - 1 / self.aimBlendSpeed, dt * 60)
		self.aimWeight = sm.util.lerp(self.aimWeight, 1.0, blend)
		bobbing = 0.12
	else
		local blend = 1 - math.pow(1 - 1 / self.aimBlendSpeed, dt * 60)
		self.aimWeight = sm.util.lerp(self.aimWeight, 0.0, blend)
		bobbing = 1
	end

	self.tool:updateCamera(2.8, 30.0, sm.vec3.new(0.65, 0.0, 0.05), self.aimWeight)
	self.tool:updateFpCamera(30.0, sm.vec3.new(0.0, 0.0, 0.0), self.aimWeight, bobbing)
end

function BaseGun:client_onClientDataUpdate(data)
	self.cl_ammo = data.ammo
	self.cl_mags = data.mags
	self.cl_settings = data.settings
end

function BaseGun:client_onReload()
	if self:canReload() and self.cl_mags > 0 then
		self.network:sendToServer("sv_startReload", self.fpAnimations.animations.reload.info.duration)
	end

	return true
end


function BaseGun:client_onToggle()
	self.cl_settings.fireMode = self.cl_settings.fireMode < #self.settings.fireMode and self.cl_settings.fireMode + 1 or 1
    sm.gui.displayAlertText(tostring(self.cl_settings.fireMode), 2.5)
	self.network:sendToServer("sv_updateFireMode", self.cl_settings.fireMode)

	return true
end

function BaseGun:sv_n_onAim(aiming)
	self.network:sendToClients("cl_n_onAim", aiming)
end

function BaseGun:cl_n_onAim(aiming)
	if not self.isLocal and self.tool:isEquipped() then
		self:onAim(aiming)
	end
end

function BaseGun:onAim(aiming)
	self.aiming = aiming
	if self.tpAnimations.currentAnimation == "idle" or self.tpAnimations.currentAnimation == "aim" or self.tpAnimations.currentAnimation == "relax" and self.aiming then
		setTpAnimation(self.tpAnimations, self.aiming and "aim" or "idle", 5.0)
	end
end

function BaseGun:sv_n_onShoot(recoil)
    self.sv_ammo = self.sv_ammo - 1
    self:sv_save()
	self.network:sendToClients("cl_n_onShoot", recoil)
end

function BaseGun:cl_n_onShoot(recoil)
	if not self.isLocal and self.tool:isEquipped() then
		self:onShoot(recoil)
	end
end

function BaseGun:onShoot(recoil)
	self.tpAnimations.animations.idle.time = 0
	self.tpAnimations.animations.shoot.time = 0
	self.tpAnimations.animations.aimShoot.time = 0

	setTpAnimation(self.tpAnimations, self.aiming and "aimShoot" or "shoot", 10.0)

	self.recoil_target_x = sm.util.clamp(self.recoil_target_x + recoil.x, -0.5, 0.5)
	self.recoil_target_y = sm.util.clamp(self.recoil_target_y + recoil.y, -0.5, 0.5)

	if self.tool:isInFirstPersonView() then
		self.shootEffectFP:start()
	else
		self.shootEffect:start()
	end
end

function BaseGun:cl_onPrimaryUse()
	if self.fireCooldownTimer > 0 then
		return false
	end

    local data = self.shootData
	if not sm.game.getEnableAmmoConsumption() and  self.cl_ammo > 0 then
		local firstPerson = self.tool:isInFirstPersonView()

		local dir = firstPerson and GetFpBoneDir(self.tool, "pejnt_barrel") or self.tool:getTpBoneDir("pejnt_barrel")

		local firePos = self:calculateFirePosition()
		local fakePosition = self:calculateTpMuzzlePos()
		local fakePositionSelf = fakePosition
		if firstPerson then
			fakePositionSelf = self:calculateFpMuzzlePos()
		end

		-- Aim assist
		--[[if not firstPerson then
			local raycastPos = sm.camera.getPosition() +
			sm.camera.getDirection() *
			sm.camera.getDirection():dot(GetOwnerPosition(self.tool) - sm.camera.getPosition())
			local hit, result = sm.localPlayer.getRaycast(250, raycastPos, sm.camera.getDirection())
			if hit then
				local norDir = sm.vec3.normalize(result.pointWorld - firePos)
				local dirDot = norDir:dot(dir)

				if dirDot > 0.96592583 then -- max 15 degrees off
					dir = norDir
				else
					local radsOff = math.asin(dirDot)
					dir = sm.vec3.lerp(dir, norDir, math.tan(radsOff) / 3.7320508) -- if more than 15, make it 15
				end
			end
		end]]

		--dir = dir:rotate(math.rad(0.955), sm.camera.getRight()) -- 50 m sight calibration

		-- Spread
		local fireMode = self.aiming and data.aimFireMode or data.normalFireMode
		local recoilDispersion = 1.0 - (math.max(fireMode.minDispersionCrouching, fireMode.minDispersionStanding) + fireMode.maxMovementDispersion)

		local spreadFactor = fireMode.spreadCooldown > 0.0 and clamp(self.spreadCooldownTimer / fireMode.spreadCooldown, 0.0, 1.0) or 0.0
		spreadFactor = clamp(self.movementDispersion + spreadFactor * recoilDispersion, 0.0, 1.0)
		local spreadDeg = fireMode.spreadMinAngle + (fireMode.spreadMaxAngle - fireMode.spreadMinAngle) * spreadFactor

        local owner = self.tool:getOwner()
        for i = 1, data.pellets do
            sm.projectile.projectileAttack(data.projectile, data.damage, firePos, sm.noise.gunSpread(dir, spreadDeg) * fireMode.fireVelocity, owner, fakePosition, fakePositionSelf)
        end

        self.cl_ammo = self.cl_ammo - 1

		-- Timers
        local cooldown = fireMode.fireCooldown
        if type(cooldown) == "function" then
            cooldown = cooldown(self)
        end

		self.fireCooldownTimer = cooldown
		self.spreadCooldownTimer = math.min(self.spreadCooldownTimer + fireMode.spreadIncrement, fireMode.spreadCooldown)
		self.sprintCooldownTimer = self.sprintCooldown

		-- Send TP shoot over network and dircly to self
		local recoil = self:getRecoil()
		self:onShoot(recoil)
		self.network:sendToServer("sv_n_onShoot", recoil)

		-- Play FP shoot animation
		setFpAnimation(self.fpAnimations, self.aiming and "aimShoot" or "shoot", 0.05)

        return true
	else
        local cooldown = (self.aiming and data.aimFireMode or data.normalFireMode).fireCooldown
        if type(cooldown) == "function" then
            cooldown = cooldown(self)
        end

		self.fireCooldownTimer = cooldown
		sm.audio.play("PotatoRifle - NoAmmo")
	end

    return false
end

function BaseGun:cl_onSecondaryUse(state)
	local aiming = state == 1 or state == 2
	if state ~= self.aiming then
		self.aiming = aiming
		self.tpAnimations.animations.idle.time = 0

		self:onAim(aiming)
		self.tool:setMovementSlowDown(aiming)
		self.network:sendToServer("sv_n_onAim", aiming)
	end
end

function BaseGun:client_onEquippedUpdate(lmb, rmb, f)
    local fireMode = self:getFiringMode()
	if fireMode == 1 then       --Semi Auto
        if lmb == 1 then
			self:cl_onPrimaryUse()
		end
	elseif fireMode == 2 then   --Full Auto
		if lmb == 1 or lmb == 2 then
			self:cl_onPrimaryUse()
		end
    elseif fireMode == 3 then   --Burst
        if lmb == 1 and not self.burstActive then
            self.burstProgress = 0
            self.burstActive = true
        end

        if self.burstActive then
            if self:cl_onPrimaryUse() then
                self.burstProgress = self.burstProgress + 1
                if self.burstProgress == 3 then
                    self.burstActive = false
                end
            end
        end
	end

	if rmb ~= self.prevSecondaryState then
		self:cl_onSecondaryUse(rmb)
		self.prevSecondaryState = rmb
	end

	return true, true
end

function BaseGun:cl_startReload()
    setTpAnimation(self.tpAnimations, "reload", 1)
    if self.isLocal then
        setFpAnimation(self.fpAnimations, "reload", 1)
    end
end



function BaseGun:canReload()
    return (self.sv_ammo or self.cl_ammo) < self.magCapacity
end

--- +x -> right +fy -> up
function BaseGun:getRecoil()
	return { x = 0, y = 0 }
end

function BaseGun:getFiringMode()
    return 1
end

function BaseGun:loadAnimations() end

function BaseGun:calculateFirePosition()
	local crouching = self.tool:isCrouching()
	local firstPerson = self.tool:isInFirstPersonView()
	local dir = sm.localPlayer.getDirection()
	local pitch = math.asin(dir.z)
	local right = sm.localPlayer.getRight()

	local fireOffset = sm.vec3.new(0.0, 0.0, 0.0)

	if crouching then
		fireOffset.z = 0.15
	else
		fireOffset.z = 0.45
	end

	if firstPerson then
		if not self.aiming then
			fireOffset = fireOffset + right * 0.05
		end
	else
		fireOffset = fireOffset + right * 0.25
		fireOffset = fireOffset:rotate(math.rad(pitch), right)
	end
	local firePosition = GetOwnerPosition(self.tool) + fireOffset
	return firePosition
end

function BaseGun:calculateTpMuzzlePos()
	local crouching = self.tool:isCrouching()
	local dir = sm.localPlayer.getDirection()
	local pitch = math.asin(dir.z)
	local right = sm.localPlayer.getRight()
	local up = right:cross(dir)

	local fakeOffset = sm.vec3.new(0.0, 0.0, 0.0)

	--General offset
	fakeOffset = fakeOffset + right * 0.25
	fakeOffset = fakeOffset + dir * 0.5
	fakeOffset = fakeOffset + up * 0.25

	--Action offset
	local pitchFraction = pitch / (math.pi * 0.5)
	if crouching then
		fakeOffset = fakeOffset + dir * 0.2
		fakeOffset = fakeOffset + up * 0.1
		fakeOffset = fakeOffset - right * 0.05

		if pitchFraction > 0.0 then
			fakeOffset = fakeOffset - up * 0.2 * pitchFraction
		else
			fakeOffset = fakeOffset + up * 0.1 * math.abs(pitchFraction)
		end
	else
		fakeOffset = fakeOffset + up * 0.1 * math.abs(pitchFraction)
	end

	local fakePosition = fakeOffset + GetOwnerPosition(self.tool)
	return fakePosition
end

function BaseGun:calculateFpMuzzlePos()
	local fovScale = (sm.camera.getFov() - 45) / 45

	local up = sm.localPlayer.getUp()
	local dir = sm.localPlayer.getDirection()
	local right = sm.localPlayer.getRight()

	local muzzlePos45 = sm.vec3.new(0.0, 0.0, 0.0)
	local muzzlePos90 = sm.vec3.new(0.0, 0.0, 0.0)

	if self.aiming then
		muzzlePos45 = muzzlePos45 - up * 0.2
		muzzlePos45 = muzzlePos45 + dir * 0.5

		muzzlePos90 = muzzlePos90 - up * 0.5
		muzzlePos90 = muzzlePos90 - dir * 0.6
	else
		muzzlePos45 = muzzlePos45 - up * 0.15
		muzzlePos45 = muzzlePos45 + right * 0.2
		muzzlePos45 = muzzlePos45 + dir * 1.25

		muzzlePos90 = muzzlePos90 - up * 0.15
		muzzlePos90 = muzzlePos90 + right * 0.2
		muzzlePos90 = muzzlePos90 + dir * 0.25
	end

	return self.tool:getFpBonePos("pejnt_barrel") + sm.vec3.lerp(muzzlePos45, muzzlePos90, fovScale)
end
function createTpAnimations( tool, animationMap )
	local data = {}
	data.tool = tool
	data.animations = {}

	for name, pair in pairs(animationMap) do

		local animation = {
			info = tool:getAnimationInfo(pair[1]),
			time = 0.0,
			weight = 0.0,
			playRate = pair[2] and pair[2].playRate or 1.0,
			looping =  pair[2] and pair[2].looping or false,
			nextAnimation = pair[2] and pair[2].nextAnimation or nil,
			blendNext = pair[2] and pair[2].blendNext or 0.0
		}

		if pair[2] and pair[2].dirs then
			animation.dirs = {
				up = tool:getAnimationInfo(pair[2].dirs.up),
				fwd = tool:getAnimationInfo(pair[2].dirs.fwd),
				down = tool:getAnimationInfo(pair[2].dirs.down)
			}
		end

		if pair[2] and pair[2].crouch then
			animation.crouch = tool:getAnimationInfo(pair[2].crouch)
		end

		if animation.info == nil then
			print("Error: failed to get third person animation info for: ", pair[1])
			animation.info = {name = name, duration = 1.0, looping = false }
		end

		data.animations[name] = animation;
	end
	data.blendSpeed = 0.0
	data.currentAnimation = ""
	return data
end

function setTpAnimation( data, name, blendSpeed )
	if name == nil then
		return
	end
	data.currentAnimation = name
	if data.animations[data.currentAnimation] ~= nil then
		data.animations[data.currentAnimation].time = 0
		data.blendSpeed = blendSpeed and blendSpeed or data.blendSpeed  
	end
end


function createFpAnimations( tool, animationMap ) 

	local data = {}
	data.isLocal = tool:isLocal()
	if not data.isLocal then
		return data
	end 
	data.tool = tool
	data.animations = {}

	for name, pair in pairs(animationMap) do 

		local animation = {
			info = tool:getFpAnimationInfo(pair[1]),
			time = 0.0,
			weight = 0.0,
			playRate = pair[2] and pair[2].playRate or 1.0,
			looping =  pair[2] and pair[2].looping or false,
			nextAnimation = pair[2] and pair[2].nextAnimation or nil,
			blendNext = pair[2] and pair[2].blendNext or 0.0
		}

		if animation.info == nil then
			print("Error: failed to get firspperson animation info for: ", pair[1])
			animation.info = { name = name, duration = 1, looping = false }
		end

		data.animations[name] = animation
	end
	data.blendSpeed = 0.0
	data.currentAnimation = ""

	return data
end

function setFpAnimation( data, name, blendSpeed )
	if not data.isLocal or name == nil then
		return
	end
	data.currentAnimation = name
	if data.animations[data.currentAnimation] ~= nil then
		data.animations[data.currentAnimation].time = 0.0
		data.blendSpeed = blendSpeed
	end
end

function forceSetFpAnimation( data, name )
	if not data.isLocal or name == nil then
		return
	end

	data.currentAnimation = name
	for name, animation in pairs(data.animations) do
		animation.weight = 0.0
	end

	if data.animations[data.currentAnimation] ~= nil then
		data.animations[data.currentAnimation].time = 0.0
		data.animations[data.currentAnimation].weight = 1.0
	end
end

function getFpAnimationProgress( data, name )
	local progress = 0.0
	if data.animations[name].info.duration > 0.0 then
		progress = data.animations[name].time/data.animations[name].info.duration
	end
	return progress
end

function setFpAnimationProgress( data, name, progress )
	data.animations[name].time = data.animations[name].info.duration*progress
end

function swapFpAnimation( data, from, to, blendTime )
	local p = 0.0
	if data.currentAnimation == from then
		p = util_clamp(1.0-getFpAnimationProgress(data, from), 0.0, 1.0)
	end
	setFpAnimation(data, to, blendTime)
	setFpAnimationProgress(data, to, p)
end

function updateFpAnimations( self, equipped, dt )
	local data = self.fpAnimations
	if data ~= nil and data.isLocal and (equipped or data.currentAnimation == "unequip") then
		-- data.blendSpeed = 0.0
		local totalWeight = 0.0
		local frameCurrent = data.currentAnimation
		local blendStep = 1.0
		if data.blendSpeed ~= 0.0 then blendStep = (1.0/data.blendSpeed) * dt end

		for name, animation in pairs(data.animations) do
			-- animation.playRate = 0.1
			animation.time = animation.time+animation.playRate*dt

			if name == frameCurrent then
				animation.weight = math.min(animation.weight+blendStep, 1.0)
				if animation.time >= animation.info.duration and not animation.looping then
					if animation.nextAnimation then
						local nextAnim = animation.nextAnimation
						if type(nextAnim) == "function" then
							nextAnim = nextAnim(self)
						end

						setFpAnimation(data, nextAnim, animation.blendNext)
					else
						animation.weight = 0.0
					end
				end
			else
				animation.weight = max(animation.weight-blendStep, 0.0)
			end

			totalWeight = totalWeight + animation.weight
		end
		-- Balance weight
		if totalWeight == 0.0 then totalWeight = 1.0 end
		for name, animation in pairs(data.animations) do
			data.tool:updateFpAnimation( animation.info.name, animation.time, animation.weight / totalWeight, animation.looping )
		end
	end
end

function updateTpAnimations( self, equipped, dt )
	local data = self.tpAnimations
	if data ~= nil and (equipped or data.currentAnimation == "unequip") then
		--[[local totalWeight = 0.0
		local frameCurrent = data.currentAnimation
		local blendStep = 1.0
		local crouchWeight = data.tool:isCrouching() and 1.0 or 0.0
		local normalWeight = 1.0 - crouchWeight
		if data.blendSpeed ~= 0.0 then blendStep = (1.0/data.blendSpeed) * dt end

		for name, animation in pairs(data.animations) do
			animation.time = animation.time+animation.playRate*dt

			if name == frameCurrent then
				animation.weight = math.min(animation.weight+blendStep, 1.0)
				if animation.time >= animation.info.duration and not animation.looping and animation.nextAnimation then
					local nextAnim = animation.nextAnimation
					if type(nextAnim) == "function" then
						nextAnim = nextAnim(self)
					end

					print(nextAnim, animation.blendNext, animation)
					setTpAnimation(data, nextAnim, animation.blendNext)
				end
			else
				animation.weight = max(animation.weight-blendStep, 0.0)
			end

			totalWeight = totalWeight + animation.weight
		end

		totalWeight = totalWeight == 0 and 1.0 or totalWeight
		for name, animation in pairs(data.animations) do
			local weight = animation.weight / totalWeight
			if name == "idle" then
				data.tool:updateMovementAnimation(animation.time, weight)
			elseif animation.crouch then
				data.tool:updateAnimation(animation.info.name, animation.time, weight * normalWeight)
				data.tool:updateAnimation(animation.crouch.name, animation.time, weight * crouchWeight)
			else
				data.tool:updateAnimation(animation.info.name, animation.time, weight)
			end
		end]]

		local crouchWeight = self.tool:isCrouching() and 1.0 or 0.0
		local normalWeight = 1.0 - crouchWeight

		local totalWeight = 0.0
		for name, animation in pairs( data.animations ) do
			animation.time = animation.time + dt

			if name == data.currentAnimation then
				animation.weight = math.min( animation.weight + ( data.blendSpeed * dt ), 1.0 )

				if animation.time >= animation.info.duration - self.blendTime then
					if ( name == "shoot" or name == "aimShoot" ) then
						setTpAnimation( data, self.aiming and "aim" or "idle", 10.0 )
					elseif name == "pickup" then
						setTpAnimation( data, self.aiming and "aim" or "idle", 0.001 )
					elseif animation.nextAnimation ~= "" then
						setTpAnimation( data, animation.nextAnimation, 0.001 )
					end
				end
			else
				animation.weight = max( animation.weight - ( data.blendSpeed * dt ), 0.0 )
			end

			totalWeight = totalWeight + animation.weight
		end

		totalWeight = totalWeight == 0 and 1.0 or totalWeight
		for name, animation in pairs( data.animations ) do
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
end
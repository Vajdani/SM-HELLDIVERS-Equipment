dofile ("../util.lua")

---@class AutoCannon : BaseGun
AutoCannon = class(BaseGun)
AutoCannon.settings = {
	fireMode = FIREMODESETTINGS_ALL
}
AutoCannon.defaultSettings = { fireMode = 1 }
AutoCannon.shootData = {
	projectile = sm.uuid.new("07b1550e-e844-4bbe-b1c3-99e77e097965"),
	damage = 150,
	pellets = 1,
	normalFireMode = {
		fireCooldown = 0.35,
		spreadCooldown = 0.18,
		spreadIncrement = 3.9,
		spreadMinAngle = 0.25,
		spreadMaxAngle = 32,
		fireVelocity = 300.0,

		minDispersionStanding = 0.1,
		minDispersionCrouching = 0.04,

		maxMovementDispersion = 0.4,
		jumpDispersionMultiplier = 2
	},
	aimFireMode = {
		fireCooldown = 0.35,
		spreadCooldown = 0.18,
		spreadIncrement = 1.95,
		spreadMinAngle = 0.25,
		spreadMaxAngle = 24,
		fireVelocity = 300.0,

		minDispersionStanding = 0.01,
		minDispersionCrouching = 0.01,

		maxMovementDispersion = 0.4,
		jumpDispersionMultiplier = 2
	}
}
AutoCannon.magCapacity = 100000
AutoCannon.magAmount = 0
AutoCannon.hipRecoilRecoverySpeed = 5
AutoCannon.aimRecoilRecoverySpeed = 7.5
AutoCannon.shootEffectNameTP = "AutoCannon - ShootTP"
AutoCannon.shootEffectNameFP = "AutoCannon - ShootFP"
AutoCannon.renderables = {
	"$CONTENT_DATA/Tools/AutoCannon/char_autocannon.rend"
}
AutoCannon.renderablesTp = {
	"$CONTENT_DATA/Tools/AutoCannon/Renderables/char_male_tp_autocannon.rend",
	"$CONTENT_DATA/Tools/AutoCannon/Renderables/char_autocannon_tp_animlist.rend",
}
AutoCannon.renderablesFp = {
	"$CONTENT_DATA/Tools/AutoCannon/Renderables/char_male_fp_autocannon.rend",
	"$CONTENT_DATA/Tools/AutoCannon/Renderables/char_autocannon_fp_animlist.rend",
}

function AutoCannon:loadAnimations()
	self.tpAnimations = createTpAnimations(
		self.tool,
		{
			shoot = { "spudgun_shoot", { crouch = "spudgun_crouch_shoot" } },
			aim = { "spudgun_aim", { crouch = "spudgun_crouch_aim" } },
			aimShoot = { "spudgun_aim_shoot", { crouch = "spudgun_crouch_aim_shoot" } },
			idle = { "spudgun_idle" },
			pickup = { "spudgun_pickup", { nextAnimation = "idle" } },
			putdown = { "spudgun_putdown" },

			reload = { "autocannon_reload", { nextAnimation = "idle" } },
		}
	)

	local movementAnimations = {
		idle = "spudgun_idle",
		idleRelaxed = "spudgun_relax",

		sprint = "spudgun_sprint",
		runFwd = "spudgun_run_fwd",
		runBwd = "spudgun_run_bwd",

		jump = "spudgun_jump",
		jumpUp = "spudgun_jump_up",
		jumpDown = "spudgun_jump_down",

		land = "spudgun_jump_land",
		landFwd = "spudgun_jump_land_fwd",
		landBwd = "spudgun_jump_land_bwd",

		crouchIdle = "spudgun_crouch_idle",
		crouchFwd = "spudgun_crouch_fwd",
		crouchBwd = "spudgun_crouch_bwd"
	}

	for name, animation in pairs(movementAnimations) do
		self.tool:setMovementAnimation(name, animation)
	end

	if self.isLocal then
		self.fpAnimations = createFpAnimations(
			self.tool,
			{
				equip = { "spudgun_pickup", { nextAnimation = "idle" } },
				unequip = { "spudgun_putdown" },

				idle = { "autocannon_idle", { looping = true } },
				shoot = { "autocannon_shoot", { nextAnimation = "idle" } },

				aimInto = { "spudgun_aim_into", { nextAnimation = "aimIdle" } },
				aimExit = { "spudgun_aim_exit", { nextAnimation = "idle", blendNext = 0 } },
				aimIdle = { "spudgun_aim_idle", { looping = true } },
				aimShoot = { "spudgun_aim_shoot", { nextAnimation = "aimIdle" } },

				sprintInto = { "spudgun_sprint_into", { nextAnimation = "sprintIdle", blendNext = 0.2 } },
				sprintExit = { "spudgun_sprint_exit", { nextAnimation = "idle", blendNext = 0 } },
				sprintIdle = { "spudgun_sprint_idle", { looping = true } },

				reload = { "autocannon_reload", { nextAnimation = "idle" } },
			}
		)
	end
end

function AutoCannon:getRecoil()
	return { x = math.random(20, 40) * 0.01, y = 0.2 }
end

function AutoCannon:canReload()
    return (self.sv_ammo or self.cl_ammo)/5 <= 1
end
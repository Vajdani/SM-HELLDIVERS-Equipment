dofile("$CONTENT_DATA/Scripts/AnimationUtil.lua")
dofile("$SURVIVAL_DATA/Scripts/util.lua")
dofile("$SURVIVAL_DATA/Scripts/game/survival_shapes.lua")
dofile("$SURVIVAL_DATA/Scripts/game/survival_projectiles.lua")

dofile "BaseGun.lua"

local rpm = {
	[1] = 1 / (450/60),
	[2] = 1 / (750/60),
	[3] = 1 / (900/60),
}

---@class HMG : BaseGun
HMG = class(BaseGun)
HMG.settings = {
	fireMode = FIREMODESETTINGS_ALL,
	flashLight = FLASHLIGHTSETTINGS_ALL,
	sight = FLASHLIGHTSETTINGS_ALL,
	rpm = {
		{
			name = "450rpm",
			icon = "challenge_missing_icon_large.png"
		},
		{
			name = "750rpm",
			icon = "challenge_missing_icon_large.png"
		},
		{
			name = "900rpm",
			icon = "challenge_missing_icon_large.png"
		}
	}
}
HMG.defaultSettings = { fireMode = 2, rpm = 1 }
HMG.shootData = {
	projectile = projectile_smallpotato,
	damage = 50,
	pellets = 1,
	normalFireMode = {
		fireCooldown = function(self)
			return rpm[self.cl_settings.rpm]
		end,
		spreadCooldown = 0.18,
		spreadIncrement = 3.9,
		spreadMinAngle = 0.25,
		spreadMaxAngle = 2,
		fireVelocity = 130.0,

		minDispersionStanding = 0.1,
		minDispersionCrouching = 0.04,

		maxMovementDispersion = 0.4,
		jumpDispersionMultiplier = 2
	},
	aimFireMode = {
		fireCooldown = function(self)
			return rpm[self.cl_settings.rpm]
		end,
		spreadCooldown = 0.18,
		spreadIncrement = 1.95,
		spreadMinAngle = 0.25,
		spreadMaxAngle = 1,
		fireVelocity = 130.0,

		minDispersionStanding = 0.01,
		minDispersionCrouching = 0.01,

		maxMovementDispersion = 0.4,
		jumpDispersionMultiplier = 2
	}
}
HMG.magCapacity = 75
HMG.magAmount = 2
HMG.hipRecoilRecoverySpeed = 5
HMG.aimRecoilRecoverySpeed = 7.5
HMG.shootEffectNameTP = "SpudgunSpinner - SpinnerMuzzel"
HMG.shootEffectNameFP = "SpudgunSpinner - FPSpinnerMuzzel"
HMG.renderables = {
	"$GAME_DATA/Character/Char_Tools/Char_spudgun/Base/char_spudgun_base_basic.rend",
	"$GAME_DATA/Character/Char_Tools/Char_spudgun/Barrel/Barrel_spinner/char_spudgun_barrel_spinner.rend",
	"$GAME_DATA/Character/Char_Tools/Char_spudgun/Sight/Sight_spinner/char_spudgun_sight_spinner.rend",
	"$GAME_DATA/Character/Char_Tools/Char_spudgun/Stock/Stock_broom/char_spudgun_stock_broom.rend",
	"$GAME_DATA/Character/Char_Tools/Char_spudgun/Tank/Tank_basic/char_spudgun_tank_basic.rend"
}
HMG.renderablesTp = {
	"$CONTENT_DATA/Tools/HMG/char_male_tp_hmg.rend",
	"$GAME_DATA/Character/Char_Tools/Char_spudgun/char_spudgun_tp_animlist.rend"
}
HMG.renderablesFp = {
	"$CONTENT_DATA/Tools/HMG/char_male_fp_hmg.rend",
	"$GAME_DATA/Character/Char_Tools/Char_spudgun/char_spudgun_fp_animlist.rend"
}

function HMG:loadAnimations()
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

	setTpAnimation(self.tpAnimations, "idle", 5.0)

	if self.isLocal then
		self.fpAnimations = createFpAnimations(
			self.tool,
			{
				equip = { "spudgun_pickup", { nextAnimation = "idle" } },
				unequip = { "spudgun_putdown" },

				idle = { "spudgun_idle", { looping = true } },
				shoot = { "spudgun_shoot", { nextAnimation = "idle" } },

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

function HMG:getRecoil()
	local x = math.random(-10, 10) * 0.005
	local y = 0.03 * math.random(10, 15) * 0.1
	return { x = x, y = y }
end
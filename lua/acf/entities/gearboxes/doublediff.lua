local ACF       = ACF
local Gearboxes = ACF.Classes.Gearboxes

-- Weight
local GearDDSW = 45
local GearDDMW = 85
local GearDDLW = 180
-- Torque Rating
local GearDDST = 20000
local GearDDMT = 45000
local GearDDLT = 100000

local function InitGearbox(Gearbox)
	Gearbox.DoubleDiff = true
	Gearbox.SteerRate  = 0

	Gearbox:SetBodygroup(1, 1)
end

Gearboxes.RegisterGroup("DoubleDiff", {
	Name		= "Double Differential",
	CreateMenu	= ACF.ManualGearboxMenu,
	Gears = {
		Min	= 0,
		Max	= 1,
	},
	OnSpawn = InitGearbox,
	OnUpdate = InitGearbox,
	SetupInputs = function(List)
		List[#List + 1] = "Steer Rate (A -1 to 0 to -1 steering rate for apply power to each side individually)"
	end,
	OnLast = function(Gearbox)
		Gearbox.DoubleDiff = nil
		Gearbox.SteerRate  = nil

		Gearbox:SetBodygroup(1, 0)
	end,
})

do -- Transaxial Gearboxes
	Gearboxes.Register("DoubleDiff-T-S", "DoubleDiff", {
		Name		= "Double Differential, Small",
		Description	= "A light duty regenerative steering transmission.",
		Model		= "models/engines/transaxial_s.mdl",
		Mass		= GearDDSW,
		Switch		= 0.2,
		MaxTorque	= GearDDST,
		DualClutch	= true,
		Preview = {
			FOV = 85,
		},
	})

	Gearboxes.Register("DoubleDiff-T-M", "DoubleDiff", {
		Name		= "Double Differential, Medium",
		Description	= "A medium regenerative steering transmission.",
		Model		= "models/engines/transaxial_m.mdl",
		Mass		= GearDDMW,
		Switch		= 0.35,
		MaxTorque	= GearDDMT,
		DualClutch	= true,
		Preview = {
			FOV = 85,
		},
	})

	Gearboxes.Register("DoubleDiff-T-L", "DoubleDiff", {
		Name		= "Double Differential, Large",
		Description	= "A heavy regenerative steering transmission.",
		Model		= "models/engines/transaxial_l.mdl",
		Mass		= GearDDLW,
		Switch		= 0.5,
		MaxTorque	= GearDDLT,
		DualClutch	= true,
		Preview = {
			FOV = 85,
		},
	})
end

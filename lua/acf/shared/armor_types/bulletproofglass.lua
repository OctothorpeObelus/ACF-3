-- Level 3 Bulletproof Glass
-- http://www.sdplastics.com/polycastacryshieldl3bulletresistantacrylicsheet.html

local Armor = ACF.RegisterArmorType("BulletproofGlass", "RHA")

function Armor:OnLoaded()
	self.Name		 = "Bulletproof Glass"
	self.Density     = 1.18 -- g/cm3
	self.Tensile     = 64.81 -- MPa
	self.Description = "Level 3 bulletproof glass, immune to .44 magnum at 1.25\" thick."
end
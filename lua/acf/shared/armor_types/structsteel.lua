-- Steel A36
-- https://www.metalsupermarkets.com/grade-guide-a36-steel/

local Armor = ACF.RegisterArmorType("StructSteel", "RHA")

function Armor:OnLoaded()
	self.Name		 = "Structural Steel A36"
	self.Density     = 7.8 -- g/cm3
	self.Tensile     = 475 -- MPa
	self.Description = "Structural steel used for basic support structures."
end
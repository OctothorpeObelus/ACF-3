-- American White Oak Wood 
-- http://www.matweb.com/search/datasheet_print.aspx?matguid=44cdf6b01d004baaa7e9510575891dc3&n=1

local Armor = ACF.RegisterArmorType("Wood", "RHA")

function Armor:OnLoaded()
	self.Name		 = "Wood"
	self.Density     = 0.6 -- g/cm3
	self.Tensile     = 5.5 -- MPa
	self.Description = "It's just Oak Wood, doesn't stop much."
end
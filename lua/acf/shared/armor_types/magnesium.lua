-- AZ80 Magnesium Alloy
-- https://www.azom.com/article.aspx?ArticleID=6709

local Armor = ACF.RegisterArmorType("Magnesium", "RHA")

function Armor:OnLoaded()
	self.Name		 = "Magnesium AZ80"
	self.Density     = 1.8 -- g/cm3
	self.Tensile     = 380 -- MPa
	self.Description = "Magnesium most commonly found in vehicle rims, but it's not too shabby as kinetic protection. Slightly flammable."
end
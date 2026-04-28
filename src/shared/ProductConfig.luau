-- ProductConfig.luau
-- Developer Product IDs for Robux purchases
-- Each building has its own Developer Product (create in Creator Dashboard)
-- Product IDs must be filled in after creating them in Roblox Studio/Dashboard

local ProductConfig = {}

-- Building → Developer Product ID
-- TODO: Replace 0 with actual Developer Product IDs from Creator Dashboard
ProductConfig.BUILDING_PRODUCTS = {
	AltarOfBlessing = 0,
	Campfire        = 0,
	ClockTower      = 0,
	Farm            = 0,
	GiantFurnace    = 0,
	HotSpring       = 0,
	Laboratory      = 0,
	Mine            = 0,
	PotionCafe      = 0,
	TreeOfGrowth    = 0,
}

-- Egg → Developer Product ID
ProductConfig.EGG_PRODUCTS = {
	Egg_Common    = 0,
	Egg_Rare      = 0,
	Egg_Epic      = 0,
	Egg_Legendary = 0,
}

-- Reverse lookup: productId → { type = "building"/"egg", itemName = "..." }
ProductConfig._productLookup = {}

function ProductConfig.init()
	ProductConfig._productLookup = {}
	for itemName, productId in ProductConfig.BUILDING_PRODUCTS do
		if productId > 0 then
			ProductConfig._productLookup[productId] = { type = "building", itemName = itemName }
		end
	end
	for eggType, productId in ProductConfig.EGG_PRODUCTS do
		if productId > 0 then
			ProductConfig._productLookup[productId] = { type = "egg", itemName = eggType }
		end
	end
end

function ProductConfig.getProductId(itemType: string, itemName: string): number
	if itemType == "building" then
		return ProductConfig.BUILDING_PRODUCTS[itemName] or 0
	elseif itemType == "egg" then
		return ProductConfig.EGG_PRODUCTS[itemName] or 0
	end
	return 0
end

function ProductConfig.getItemFromProduct(productId: number): { type: string, itemName: string }?
	return ProductConfig._productLookup[productId]
end

ProductConfig.init()

return ProductConfig

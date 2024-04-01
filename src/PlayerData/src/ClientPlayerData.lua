-- Modules
-- This module can be obtained here: https://github.com/Sleitnick/RbxUtil
local SignalLib = require(game.ReplicatedStorage:WaitForChild("SignalLib"))
local OnDataChangedSignal = SignalLib.new("OnPlayerDataChanged")

-- Remotes
local Remotes = game.ReplicatedStorage:WaitForChild("Game"):WaitForChild("PlayerData")

-- Types
export type ShopCategory = "Auras" | "Buddies" | "Death Effects" | "Emotes" | "Skins" | "Tanks"
export type PlayerData = {
	RollbackId: number,
	DataVersion: number,
	LevelCalculationVersion: number,
	Stats: {
		Credits: number,
		Gems: number,
		Level: number,
		XP: number,
		MaxXP: number,
		TotalXP: number -- Helps when XP recalculation happens, we can change their level + XP
	},
	Inventory: {
		[ShopCategory]: {string}
	},
	Equipped: {
		[ShopCategory]: string?
	},
	ClientConfigs: {[string]: any},
	RedeemedCodes: {[string]: boolean}
}

local ClientPlayerData = {Data = nil}

function ClientPlayerData.RetrieveData(): PlayerData?
	if not ClientPlayerData.Data then
		ClientPlayerData.Data = Remotes.RequestData:InvokeServer()
	end
	
	return ClientPlayerData.Data
end

function ClientPlayerData.OwnItem(Category: ShopCategory, ItemName: string): boolean
	local PlayerData = ClientPlayerData.RetrieveData()
	if not PlayerData then
		error(`Cannot retrieve player data. Data possibly corrupted.`)
	end
	if not PlayerData.Inventory[Category] then
		error(`Invalid shop category (or corrupted data causing category to not exist): {Category}`)
	end

	return table.find(PlayerData.Inventory[Category], ItemName) ~= nil
end

function ClientPlayerData.HasEquippedItem(Category: ShopCategory, ItemName: string): boolean
	local PlayerData = ClientPlayerData.RetrieveData()
	if not PlayerData then
		error(`Cannot retrieve player data. Data possibly corrupted.`)
	end
	-- Why this check exist? It's to ensure you implement in this logic: Owned? -> HasEquipped? -> stuffs
	if not ClientPlayerData.OwnItem(Category, ItemName) then
		error(`Player do not own item {ItemName}.`)
	end

	return PlayerData.Equipped[Category] == ItemName
end

function ClientPlayerData.PurchaseItem(Category: ShopCategory, ItemName: string)
	local PlayerData = ClientPlayerData.RetrieveData()
	if not PlayerData then
		error(`Cannot retrieve player data. Data possibly corrupted.`)
	end
	if ClientPlayerData.OwnItem(Category, ItemName) then
		return
	end

	Remotes.PurchaseShopItem:FireServer(Category, ItemName)
end

function ClientPlayerData.EquipItem(Category: ShopCategory, ItemName: string)
	local PlayerData = ClientPlayerData.RetrieveData()
	if not PlayerData then
		error(`Cannot retrieve player data. Data possibly corrupted.`)
	end
	if ClientPlayerData.HasEquippedItem(Category, ItemName) then
		return
	end

	Remotes.EquipShopItem:FireServer(Category, ItemName)
end

function ClientPlayerData.UnequipCategory(Category: ShopCategory)
	local PlayerData = ClientPlayerData.RetrieveData()
	if not PlayerData then
		error(`Cannot retrieve player data. Data possibly corrupted.`)
	end
	if not PlayerData.Equipped[Category] then
		error(`Invalid shop category (or corrupted data causing category to not exist): {Category}`)
	end

	Remotes.UnequipCategory:FireServer(Category)
end

function ClientPlayerData.ChangeConfig(ConfigName: string, ConfigValue: any)
	local PlayerData = ClientPlayerData.RetrieveData()
	if not PlayerData then
		error(`Cannot retrieve player data. Data possibly corrupted.`)
	end
	if not tostring(ConfigName) then
		error(`Config name "{ConfigName} must be a string."`)
	end
	
	PlayerData.ClientConfigs[ConfigName] = ConfigValue -- Change locally
	Remotes.ChangeConfig:FireServer(ConfigName, ConfigValue)
end

function ClientPlayerData.OnDataChangedSignal(func: (PlayerData) -> ())
	return OnDataChangedSignal:Connect(func)
end

Remotes.OnNewData.OnClientEvent:Connect(function(PlayerData: PlayerData?)
	if not PlayerData then
		return
	end
	
	ClientPlayerData.Data = PlayerData
	OnDataChangedSignal:Fire(PlayerData)
end)

ClientPlayerData.Data = ClientPlayerData.RetrieveData()

return ClientPlayerData
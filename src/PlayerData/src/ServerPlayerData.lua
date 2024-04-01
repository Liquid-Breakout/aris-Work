local DataStoreService = game:GetService("DataStoreService")
local PlayerDataStore: DataStore = DataStoreService:GetDataStore("PlayerData")

local ShopsFolder = game.ReplicatedStorage:WaitForChild("Shops")

-- Remotes
local Remotes = game.ReplicatedStorage:WaitForChild("Game"):WaitForChild("PlayerData")
local AlertRemote = game.ReplicatedStorage:WaitForChild("Remote"):WaitForChild("Alert")

-- Config
local ValidStatToAdd = {"Credits", "Gems", "XP"} 
local StatAddThreshold = 99999

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

local RollbackDates: {DateTime} = {
	DateTime.fromUniversalTime(2023, 12, 24, 18, 0, 0, 0)
}

-- Template
local PlayerDataTemplate: PlayerData = {
	RollbackId = 1,
	DataVersion = 3,
	LevelCalculationVersion = 1,
	Stats = {
		Credits = 0,
		Gems = 0,
		Level = 1,
		XP = 0,
		MaxXP = 0,
		TotalXP = 0,
	},
	Inventory = {
		Auras = {},
		Buddies = {},
		["Death Effects"] = {},
		Emotes = {},
		Skins = {},
		Tanks = {}
	},
	Equipped = {
		Auras = nil,
		Buddies = nil,
		["Death Effects"] = nil,
		Emotes = nil,
		Skins = nil,
		Tanks = nil
	},
	ClientConfigs = {},
	RedeemedCodes = {}
}

local FlagsDataStore = DataStoreService:GetDataStore("Flags")

local ServerPlayerData = {
	PlayerDataContainer = {},
	Overwritable = {}
}

local function DeepCopyTable(t)
	local copy = {}
	for key, value in pairs(t) do
		if type(value) == "table" then
			copy[key] = DeepCopyTable(value)
		else
			copy[key] = value
		end
	end
	return copy
end

local function ReconcileTable(target, template)
	for k, v in template do
		if type(k) == "string" then -- Only string keys will be reconciled
			if target[k] == nil then
				if type(v) == "table" then
					target[k] = DeepCopyTable(v)
				else
					target[k] = v
				end
			elseif type(target[k]) == "table" and type(v) == "table" then
				ReconcileTable(target[k], v)
			end
		end
	end

	for k, v in target do
		if type(k) == "string" or type(k) == "table" then
			if template[k] == nil then
				if type(v) == "table" then
					target[k] = nil
				end
			end
		end
	end
end

local function FindInChildren(ChildrenTable: {Instance}, FindFunction: (Instance) -> boolean): Instance?
	for _, Child in ChildrenTable do
		if FindFunction(Child) then
			return Child
		end
	end
	return nil
end

function ServerPlayerData._syncData(Player: Player)
	local PlayerData: PlayerData? = ServerPlayerData.RetrieveData(Player)
	if not PlayerData then
		return
	end
	Remotes.OnNewData:FireClient(Player, PlayerData)
end

function ServerPlayerData._flagPlayerData(Player: Player, Info: string)
	FlagsDataStore:UpdateAsync("PlayerData", function(Data)
		if not Data then
			Data = {}
		end
		
		if not Data[Player.UserId] then
			Data[Player.UserId] = {}
		end
		
		table.insert(Data[Player.UserId], Info)
		
		return Data
	end)
end

-- Used only for purchases
function ServerPlayerData.FlagPlayerFailedStatApply(Player: Player, Info: string)
	FlagsDataStore:UpdateAsync("PlayerStatApplyFailure", function(Data)
		if not Data then
			Data = {}
		end

		if not Data[Player.UserId] then
			Data[Player.UserId] = {}
		end

		table.insert(Data[Player.UserId], {
			UnixTimestamp = DateTime.now().UnixTimestamp,
			Info = Info
		})

		return Data
	end)
end

function ServerPlayerData.PerformRollback(UserId: number, RollbackId: number)
	RollbackId = if type(RollbackId) == "number" and RollbackId >= 0 then RollbackId else 0
	for Id, Date in next, RollbackDates do
		if Id > RollbackId then
			print(`Attempting to roll back {UserId} to {Date.UnixTimestamp}`)
			local Recovered, RecoveredData = pcall(function()
				return PlayerDataStore:GetVersionAsync(
					UserId,
					PlayerDataStore:ListVersionsAsync(
						UserId,
						Enum.SortDirection.Descending,
						0,
						Date.UnixTimestampMillis,
						1
					):GetCurrentPage()[1].Version
				)
			end)
			if not Recovered then
				warn(`Could not recover {UserId} data, it may be expired`)
				return
			end
			return RecoveredData
		end
	end
end

function ServerPlayerData.TransformToNewTemplate(Data): PlayerData
	local NewData: PlayerData = DeepCopyTable(PlayerDataTemplate)
	NewData.RollbackVersion = 0
	NewData.LevelCalculationVersion = 0 -- None
	NewData.Stats.Credits = Data.Credits
	NewData.Stats.Gems = Data.Gems
	NewData.Stats.Level = 1
	NewData.Stats.XP = 0
	NewData.ClientConfigs = Data.ClientConfigs
	NewData.RedeemedCodes = Data.RedeemedCodes
	
	for Category, CategoryData in Data.ShopData do
		if not NewData.Inventory[Category] then
			NewData.Inventory[Category] = {}
		end
		for ItemName, ItemData in CategoryData do
			if ItemData.Owned and not table.find(NewData.Inventory[Category], ItemName) then
				table.insert(NewData.Inventory[Category], ItemName)
				if ItemData.Equipped then
					NewData.Equipped[Category] = ItemName
				end
			end
		end
	end
	
	return NewData
end

local LevelingInfo = {
	XPIncrement = 25
}

function ServerPlayerData.CalculateTotalXPRequiredToReachLevel(Level: number): number
	return ((Level ^ 2 - Level) * LevelingInfo.XPIncrement) * .5
end

function ServerPlayerData.CanLevelUp(Level: number, XP: number): boolean
	local TotalXPToReachCurrentLevel = ServerPlayerData.CalculateTotalXPRequiredToReachLevel(Level)
	return XP + TotalXPToReachCurrentLevel >= ServerPlayerData.CalculateTotalXPRequiredToReachLevel(Level + 1)
end

-- Formula referenced: https://gamedev.stackexchange.com/questions/110431/how-can-i-calculate-current-level-from-total-xp-when-each-level-requires-propor
function ServerPlayerData.GetLevelFromTotalXP(TotalXP: number): number
	return math.floor((1 + (math.sqrt(1 + 8 * TotalXP / LevelingInfo.XPIncrement))) * .5)
end

function ServerPlayerData.GetXPFromLevelAndTotalXP(Level: number, TotalXP: number): number
	local TotalXPToReachCurrentLevel = ServerPlayerData.CalculateTotalXPRequiredToReachLevel(Level)
	return TotalXP - TotalXPToReachCurrentLevel
end

function ServerPlayerData.LevelUp(Level: number, XP: number): (number, number) -- (Level, XP)
	if not ServerPlayerData.CanLevelUp(Level, XP) then
		return Level, XP
	end
	
	local TotalXPToReachCurrentLevel = ServerPlayerData.CalculateTotalXPRequiredToReachLevel(Level)
	local TotalXPEarned = TotalXPToReachCurrentLevel + XP
	Level = ServerPlayerData.GetLevelFromTotalXP(TotalXPEarned)
	XP = ServerPlayerData.GetXPFromLevelAndTotalXP(Level, TotalXPEarned)
	
	return Level, XP
end

function ServerPlayerData.RecalculateLevelXP(PlayerData: PlayerData)
	-- Legacy
	if PlayerData.LevelCalculationVersion == 0 then
		local TotalXPToReachCurrentLevel = ServerPlayerData.CalculateTotalXPRequiredToReachLevel(PlayerData.Stats.Level)
		local TotalXPEarned = TotalXPToReachCurrentLevel + PlayerData.Stats.XP
		
		PlayerData.Stats.Level = ServerPlayerData.GetLevelFromTotalXP(TotalXPEarned)
		PlayerData.Stats.XP = ServerPlayerData.GetXPFromLevelAndTotalXP(PlayerData.Stats.Level, TotalXPEarned)
	end
end

-- just a fancy wrapper
function ServerPlayerData.UpdateMaxXP(PlayerData: PlayerData)
	local TotalXPToReachCurrentLevel = ServerPlayerData.CalculateTotalXPRequiredToReachLevel(PlayerData.Stats.Level)
	local TotalXPToReachNextLevel = ServerPlayerData.CalculateTotalXPRequiredToReachLevel(PlayerData.Stats.Level + 1)
	PlayerData.Stats.MaxXP = TotalXPToReachNextLevel - TotalXPToReachCurrentLevel
end

function ServerPlayerData.RetrieveData(Player: Player): PlayerData?
	local UserId = Player.UserId
	
	if ServerPlayerData.PlayerDataContainer[UserId] then
		-- prevent conflict if multiple scripts are calling this with the same player
		while ServerPlayerData.PlayerDataContainer[UserId][1] do
			task.wait()
		end
		
		return ServerPlayerData.PlayerDataContainer[UserId][2]
	end
	
	ServerPlayerData.PlayerDataContainer[UserId] = {true}
	
	local FoundData
	
	local Success, Result = pcall(function()
		FoundData = PlayerDataStore:GetAsync(UserId)
	end)
	
	if not Success or type(FoundData) ~= "table" then
		FoundData = DeepCopyTable(PlayerDataTemplate)
		warn(`Failed to load data for player {UserId}: {Result}`)
		-- oops
		--[[Player:Kick(`Failed to load data, please rejoin. Error: {if type(FoundData) ~= "table" then "Corrupted data." else Result}`)
		return PlayerDataTemplate]]
	end
	
	local RollbackData = ServerPlayerData.PerformRollback(UserId, FoundData.RollbackId)
	if RollbackData then
		FoundData = RollbackData
	end
	
	-- Check if found data is a pre-1.14 save
	if not FoundData.DataVersion then
		FoundData = ServerPlayerData.TransformToNewTemplate(FoundData)
	end
	
	ServerPlayerData.RecalculateLevelXP(FoundData)
	ServerPlayerData.UpdateMaxXP(FoundData)
	ReconcileTable(FoundData, PlayerDataTemplate)
	
	ServerPlayerData.PlayerDataContainer[UserId][1] = nil
	ServerPlayerData.PlayerDataContainer[UserId][2] = FoundData
	
	return FoundData
end

function ServerPlayerData.ReleaseSession(Player: Player)
	if not ServerPlayerData.PlayerDataContainer[Player.UserId] then
		return
	end
	local Data = ServerPlayerData.PlayerDataContainer[Player.UserId][2]
	ServerPlayerData.PlayerDataContainer[Player.UserId] = nil
	local Success, Result = pcall(function()
		PlayerDataStore:SetAsync(Player.UserId, Data)
	end)
	if not Success then
		warn(`Cannot save data for player {Player.UserId}: {Result}`)
	end
end

function ServerPlayerData.CheckStats(Player: Player)
	local PlayerData = ServerPlayerData.RetrieveData(Player)
	if not PlayerData then
		return
	end
	
	for StatName, Value in PlayerData.Stats do
		local DirtyString
		if Value == nil or Value ~= Value then
			DirtyString = "nil or NaN"
		elseif Value < 0 then
			DirtyString = "negative"
		elseif math.abs(Value) == math.huge then
			DirtyString = "infinite"
		end
		if DirtyString then
			PlayerData.Stats[StatName] = PlayerDataTemplate.Stats[StatName]
			ServerPlayerData._flagPlayerData(Player, `Stat "{StatName}" is {DirtyString}`)
		end
	end
	
	if ServerPlayerData.CanLevelUp(PlayerData.Stats.Level, PlayerData.Stats.XP) then
		local NewLevel, NewXP = ServerPlayerData.LevelUp(PlayerData.Stats.Level, PlayerData.Stats.XP)
		PlayerData.Stats.Level = NewLevel
		PlayerData.Stats.XP = NewXP
		game.ReplicatedStorage.Game.LevelUp:FireClient(Player)
	end
	ServerPlayerData.UpdateMaxXP(PlayerData)
end

-- TODO: offer bulk alternative
function ServerPlayerData.AddStat(Player: Player, StatName: "Credits" | "Gems" | "XP", Amount: number)
	local PlayerData = ServerPlayerData.RetrieveData(Player)
	if not PlayerData then
		error(`Cannot retrieve player data. Provided Player object: {Player:GetFullName()}`)
	end
	
	if not table.find(ValidStatToAdd, StatName) then
		error(`Cannot add stat {StatName}. Must be {table.concat(ValidStatToAdd, " or ")}`)
	end
	if not tonumber(Amount) then
		error(`Amount "{Amount}" is not a number.`)
	end
	if math.abs(Amount) > StatAddThreshold then
		error(`Cannot add amount.`)
	end
	
	PlayerData.Stats[StatName] += Amount
	if StatName == "XP" then
		PlayerData.Stats.TotalXP += Amount
	end
	
	ServerPlayerData.CheckStats(Player)
	ServerPlayerData._syncData(Player)
end

function ServerPlayerData.ChangeStat(Player: Player, StatName: "Credits" | "Gems" | "XP", Value: number)
	local PlayerData = ServerPlayerData.RetrieveData(Player)
	if not PlayerData then
		error(`Cannot retrieve player data. Provided Player object: {Player:GetFullName()}`)
	end

	if not table.find(ValidStatToAdd, StatName) then
		error(`Cannot add stat {StatName}. Must be {table.concat(ValidStatToAdd, " or ")}`)
	end
	if not tonumber(Value) or Value ~= Value then
		error(`Amount "{Value}" is not a number.`)
	end
	if math.abs(Value) == math.huge then
		error(`Cannot change.`)
	end

	local OldValue = PlayerData.Stats[StatName]
	PlayerData.Stats[StatName] = Value
	if StatName == "XP" then
		PlayerData.Stats.TotalXP = PlayerData.Stats.TotalXP - OldValue + Value
	end

	ServerPlayerData.CheckStats(Player)
	ServerPlayerData._syncData(Player)
end

function ServerPlayerData.OwnItem(Player: Player, Category: ShopCategory, ItemName: string): boolean
	local PlayerData = ServerPlayerData.RetrieveData(Player)
	if not PlayerData then
		error(`Cannot retrieve player data. Provided Player object: {Player:GetFullName()}`)
	end
	if not PlayerData.Inventory[Category] then
		error(`Invalid shop category (or corrupted data causing category to not exist): {Category}`)
	end
	
	return table.find(PlayerData.Inventory[Category], ItemName) ~= nil
end

function ServerPlayerData.HasEquippedItem(Player: Player, Category: ShopCategory, ItemName: string): boolean
	local PlayerData = ServerPlayerData.RetrieveData(Player)
	if not PlayerData then
		error(`Cannot retrieve player data. Provided Player object: {Player:GetFullName()}`)
	end
	-- Why this check exist? It's to ensure you implement in this logic: Owned? -> HasEquipped? -> stuffs
	if not ServerPlayerData.OwnItem(Player, Category, ItemName) then
		error(`Player do not own item {ItemName}.`)
	end
	
	return PlayerData.Equipped[Category] == ItemName
end

function ServerPlayerData.PurchaseItem(Player: Player, Category: ShopCategory, ItemName: string)
	local PlayerData = ServerPlayerData.RetrieveData(Player)
	if not PlayerData then
		error(`Cannot retrieve player data. Provided Player object: {Player:GetFullName()}`)
	end
	if ServerPlayerData.OwnItem(Player, Category, ItemName) then
		warn(`Player already owned item {ItemName}.`)
		AlertRemote:FireClient(Player, `You already owned item {ItemName}.`, Color3.fromRGB(255, 119, 0))
		return -2
	end
	
	local ShopItemContainer = ShopsFolder:FindFirstChild(Category)
	if not ShopItemContainer then
		AlertRemote:FireClient(Player, `Category {Category} does not exist in 'Shops' folder.`, Color3.fromRGB(255, 119, 0))
		return
	end
	local ShopItem = FindInChildren(ShopItemContainer:GetChildren(), function(Child: Instance)
		return Child:FindFirstChild("ItemName") and Child.ItemName.Value == ItemName
	end)
	if not ShopItem then
		return
	end

	local UseCurrency = "Credits"
	if ShopItem:FindFirstChild("Gems") and ShopItem.Gems.Value == true then
		UseCurrency = "Gems"
	end

	if PlayerData.Stats[UseCurrency] >= ShopItem.Price.Value then
		-- We don't use AddStat as this is an internal function (lol totally)
		-- plus calling that will sync data, which we won't do yet
		PlayerData.Stats[UseCurrency] -= ShopItem.Price.Value
		table.insert(PlayerData.Inventory[Category], ItemName)
		AlertRemote:FireClient(Player, `Successfully purchased {ItemName}!`, Color3.fromRGB(0, 255, 0))
		ServerPlayerData._syncData(Player)
		return
	else
		AlertRemote:FireClient(
			Player,
			`You need {ShopItem.Price.Value - PlayerData.Stats[UseCurrency]} more {UseCurrency} to purchase this!`,
			Color3.fromRGB(255, 0, 0)
		)
		return
	end
end

function ServerPlayerData.EquipItem(Player: Player, Category: ShopCategory, ItemName: string)
	local PlayerData = ServerPlayerData.RetrieveData(Player)
	
	if not PlayerData then
		error(`Cannot retrieve player data. Provided Player object: {Player:GetFullName()}`)
	end
	
	if ServerPlayerData.HasEquippedItem(Player, Category, ItemName) then
		AlertRemote:FireClient(Player, `You already equipped item {ItemName}.`, Color3.fromRGB(255, 119, 0))
		return
	end
	
	PlayerData.Equipped[Category] = ItemName
	ServerPlayerData._syncData(Player)
	if ServerPlayerData.Overwritable.OnEquip then
		ServerPlayerData.Overwritable.OnEquip(Player, PlayerData, Category)
	end
end

-- UnequipItem don't make sense when you can only equip an item.
-- im adding two per category in most categories in 1.15 btw
function ServerPlayerData.UnequipCategory(Player: Player, Category: ShopCategory)
	local PlayerData = ServerPlayerData.RetrieveData(Player)
	if not PlayerData then
		error(`Cannot retrieve player data. Provided Player object: {Player:GetFullName()}`)
	end
	
	-- it just sets the thing to nil why is this necessary
	--[[if not PlayerData.Equipped[Category] then
		if type(PlayerDataTemplate.Inventory[Category]) == "table" then
			PlayerData.Equipped[Category] = ""
		else
			warn(`Invalid shop category (or corrupted data causing category to not exist): {Category}`)
			AlertRemote:FireClient(Player, `Invalid shop category (or corrupted data causing category to not exist): {Category}`, Color3.fromRGB(255, 119, 0))
		end
		return
	end]]

	PlayerData.Equipped[Category] = nil
	ServerPlayerData._syncData(Player)
	if ServerPlayerData.Overwritable.OnUnequip then
		ServerPlayerData.Overwritable.OnUnequip(Player, PlayerData, Category)
	end
end

function ServerPlayerData.UnequipAllCategories(Player: Player, Category: ShopCategory)
	local PlayerData = ServerPlayerData.RetrieveData(Player)
	if not PlayerData then
		error(`Cannot retrieve player data. Provided Player object: {Player:GetFullName()}`)
	end
	
	table.clear(PlayerData.Equipped)
	
	ServerPlayerData._syncData(Player)
	if ServerPlayerData.Overwritable.OnUnequip then
		ServerPlayerData.Overwritable.OnUnequip(Player, PlayerData, "all")
	end
end

function ServerPlayerData.ChangeConfig(Player: Player, ConfigName: string, ConfigValue: any)
	local PlayerData = ServerPlayerData.RetrieveData(Player)
	if not PlayerData then
		error(`Cannot retrieve player data. Provided Player object: {Player:GetFullName()}`)
	end
	if not tostring(ConfigName) then
		error(`Config name "{ConfigName} must be a string."`)
	end
	
	if PlayerData.ClientConfigs[ConfigName] ~= ConfigValue then
		PlayerData.ClientConfigs[ConfigName] = ConfigValue
		ServerPlayerData._syncData(Player)
	end
end

-- Overwritable
function ServerPlayerData.Overwritable.OnEquip(Player: Player, PlayerData: PlayerData, Category: ShopCategory)
end

function ServerPlayerData.Overwritable.OnUnequip(Player: Player, PlayerData: PlayerData, Category: ShopCategory | "all")
end

Remotes.PurchaseShopItem.OnServerEvent:Connect(ServerPlayerData.PurchaseItem)
Remotes.EquipShopItem.OnServerEvent:Connect(ServerPlayerData.EquipItem)
Remotes.UnequipCategory.OnServerEvent:Connect(ServerPlayerData.UnequipCategory)
Remotes.ChangeConfig.OnServerEvent:Connect(ServerPlayerData.ChangeConfig)
Remotes.RequestData.OnServerInvoke = ServerPlayerData.RetrieveData

return ServerPlayerData
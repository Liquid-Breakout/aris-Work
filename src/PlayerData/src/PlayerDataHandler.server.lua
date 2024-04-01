-- A rewrite to the old, shitty script.
-- cutymeo

local DataStoreService = game:GetService("DataStoreService")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MapTestHubDataStore = DataStoreService:GetDataStore("MapTest-Hub")
local MapTestHubDataCache = {}
local HubLoaded = false

local GameLib = require(game.ReplicatedStorage.GameLib)
local ServerPlayerData = require(script.Parent:WaitForChild("ServerPlayerData"))

local ShopsFolder = if not GameLib.MapTestPlaces[game.PlaceId] then game.ReplicatedStorage:WaitForChild("Shops") else Instance.new("Folder")
local ShopsIndex = {}
local RemoteFolder = game.ReplicatedStorage:WaitForChild("Remote")

local AlertRemote = RemoteFolder.Alert
local UpdatePlayerDataRemote = RemoteFolder.UpdatePlayerData
local DataRemote = ReplicatedStorage:WaitForChild("DataShopCommunicator")
local DataRemoteServer = ReplicatedStorage:WaitForChild("DataShopCommunicator_Server")
local LeaderboardRemoteServer = ReplicatedStorage:WaitForChild("LeaderboardsCommunicator_Server")
local UpdateMapTestHubData = ReplicatedStorage.Remote:WaitForChild("UpdateMapTestHubData")

--local HistoryDataStore: DataStore = DataStoreService:GetDataStore("PlayerHistory")
--local VersionString = "1.14.0.1"

local LevelTagStorage = ReplicatedStorage:WaitForChild("ClientStorage"):WaitForChild("LevelTags")

-- FE2 classic yay
codes = {
}
--[[
msg = The code's rewards
reward = What the player is given ("Credits", "Gems", "XP")
ammount = How much Credits/Gems/XP they get
expired = If it's redeemable or not
admin = If it's for admins/developers only
]]

local PlayerLeaderboardInfo = {}
--local PendingLeaderboardXPAppend = {}

local function FindInTable(Table: { any }, FindFunction): Instance?
	for _, Child in Table do
		if FindFunction(Child) then
			return Child
		end
	end
	return nil
end

-- Binds
ServerPlayerData.Overwritable.OnEquip = function(Player: Player, PlayerData: ServerPlayerData.PlayerData, Category: ShopCategory | "all")
	if (Category == "all" or Category == "Auras") and PlayerData.Equipped.Auras then
		local ShopItem = ShopsIndex.Auras[PlayerData.Equipped.Auras]
		if ShopItem then
			pcall(function()
				for _,v in Player.Character:GetDescendants() do
					if string.sub(v.Name, 1, 5) == "Aura_" then
						v:Destroy()
					end
				end
				for _,v in ShopItem.Content:GetDescendants() do
					if v:IsA("ParticleEmitter") or v:IsA("Attachment") or v:IsA("Light") or v:IsA("Trail") then
						local clone = v:Clone()
						local parent = Player.Character[v.Parent.Name]
						if clone.ClassName ~= "Attachment" then
							clone.Enabled = true
							if clone.ClassName == "Trail" then
								local a1, a2 = Instance.new("Attachment"), Instance.new("Attachment")
								a1.Name = "Aura_"; a2.Name = "Aura_"
								a1.CFrame = CFrame.new(0, 0.5, 0); a2.CFrame = CFrame.new(0, -0.5, 0)
								clone.Attachment0 = a1; clone.Attachment1 = a2
								a1.Parent = parent; a2.Parent = parent
							end
						end
						clone.Parent = parent
					end
				end
			end)
		else
			ServerPlayerData.UnequipCategory(Player, "Auras")
		end
	end
	if (Category == "all" or Category == "Emotes") and PlayerData.Equipped.Emotes then
		game.ReplicatedStorage.Remote.NewEmote:FireClient(Player, ShopsFolder.Emotes[PlayerData.Equipped.Emotes])
	end
	if (Category == "all" or Category == "Death Effects") and PlayerData.Equipped["Death Effects"] then
		local ShopItem = ShopsIndex["Death Effects"][PlayerData.Equipped["Death Effects"]]
		if ShopItem then
			Player.Character.Effect.Value = ShopItem.EffectName
		else
			ServerPlayerData.UnequipCategory(Player, "Death Effects")
		end
	end
	if (Category == "all" or Category == "Tanks") and PlayerData.Equipped.Tanks then
		local ShopItem = ShopsIndex.Tanks[PlayerData.Equipped.Tanks]

		if ShopItem then
			for _,i in Player.Character:GetChildren() do
				if i.Name == "Tank" then
					i:Destroy()
				end
			end

			for _, children in ShopItem.Content:GetDescendants() do
				if children:FindFirstChild("Center") then
					local newTank = children:Clone()
					newTank.Name = "Tank"
					newTank.PrimaryPart = newTank.Center

					for _, tankDescendant in newTank:GetDescendants() do
						if tankDescendant ~= newTank.Center and tankDescendant:IsA("BasePart") then
							local newConstraint = Instance.new("WeldConstraint")
							newConstraint.Part0 = tankDescendant
							newConstraint.Part1 = newTank.Center
							newConstraint.Parent = tankDescendant
						end
					end

					local primaryWeld = Instance.new("ManualWeld")
					primaryWeld.Name = "MainWeld"
					primaryWeld.Part0 = newTank.Center
					primaryWeld.Part1 = Player.Character.Torso
					primaryWeld.Parent = newTank.Center
					newTank:SetPrimaryPartCFrame(Player.Character.Torso.CFrame)
					newTank.Parent = Player.Character
				end
			end
		else
			ServerPlayerData.UnequipCategory(Player, "Tanks")
		end
	end
	if (Category == "all" or Category == "Buddies") and PlayerData.Equipped.Buddies then
		local CurrentBuddy = FindInTable(workspace.BuddiesContainer:GetChildren(), function(Child)
			return Child:FindFirstChild("Buddy")
				and Child.Buddy:FindFirstChild("Owner")
				and Child.Buddy.Owner.Value == Player
		end)
		if CurrentBuddy then
			CurrentBuddy:Destroy()
		end

		local ShopItem = ShopsIndex.Buddies[PlayerData.Equipped.Buddies]

		if ShopItem then
			local NewBuddy = ShopItem.Content.Buddy:Clone()
			if not NewBuddy:FindFirstChild("Buddy") then
				return
			end
			if not NewBuddy.Buddy:FindFirstChild("Owner") then
				return
			end

			for _, Part in NewBuddy:GetDescendants() do
				if Part:IsA("BasePart") then
					Part.CollisionGroup = "Buddies"
				end
			end

			NewBuddy.Buddy.Owner.Value = Player
			NewBuddy.Parent = workspace.BuddiesContainer
			NewBuddy.HumanoidRootPart.CFrame = Player.Character.HumanoidRootPart.CFrame + Vector3.new(5, 2.5, 0)
		else
			ServerPlayerData.UnequipCategory(Player, "Buddies")
		end
	end
	if (Category == "all" or Category == "Skins") and PlayerData.Equipped.Skins then
		local ShopItem = ShopsIndex.Skins[PlayerData.Equipped.Skins]
		
		for _, c in Player.Character:GetChildren() do
			if c.Name ~= "HumanoidRootPart" and c:IsA("BasePart") then
				c.Transparency = 0
			end
		end

		if ShopItem then
			Player:ClearCharacterAppearance()
			task.wait(--[[0.05]])
			for _, Uhh in ShopItem.Content:GetChildren() do
				Player:LoadCharacterAppearance(Uhh:Clone())
			end
		else
			ServerPlayerData.UnequipCategory(Player, "Skins")
		end
	end
end

ServerPlayerData.Overwritable.OnUnequip = function(Player: Player, PlayerData: ServerPlayerData.PlayerData, Category)
	if Category == "Auras" and not PlayerData.Equipped.Auras then
		for _, v in Player.Character:GetDescendants() do
			if string.sub(v.Name, 1, 5) == "Aura_" then
				v:Destroy()
			end
		end
	end
	if Category == "Emotes" and not PlayerData.Equipped.Emotes then
		game.ReplicatedStorage.Remote.NewEmote:FireClient(Player, nil)
	end
	if Category == "Death EFfects" and not PlayerData.Equipped["Death Effects"] then
		Player.Character.Effect.Value = "None"
	end
	if Category == "Tanks" and not PlayerData.Equipped.Tanks then
		for _, Children in Player.Character:GetChildren() do
			if Children.Name == "Tank" then
				Children:Destroy()
			end
		end
	end
	if Category == "Buddies" and not PlayerData.Equipped.Buddies then
		local CurrentBuddy = FindInTable(workspace.BuddiesContainer:GetChildren(), function(Child)
			return Child:FindFirstChild("Buddy")
				and Child.Buddy:FindFirstChild("Owner")
				and Child.Buddy.Owner.Value == Player
		end)
		if CurrentBuddy then
			CurrentBuddy:Destroy()
		end
	end
	if Category == "Skins" and not PlayerData.Equipped.Skins then
		-- bad method, using old method
		--[[local humanoidDescription = game:GetService("Players"):GetHumanoidDescriptionFromUserId(Player.UserId)
		Player:LoadCharacterWithHumanoidDescription(humanoidDescription)]]
		for _, c in Player.Character:GetChildren() do
			if c.Name ~= "HumanoidRootPart" and c:IsA("BasePart") then
				c.Transparency = 0
			end
		end
		
		local model = game:GetService("Players"):GetCharacterAppearanceAsync(Player.UserId)
		Player:ClearCharacterAppearance()
		for _, child in model:GetChildren() do
			Player:LoadCharacterAppearance(child)
		end
	end	
end

local function giveRewardsImTired(PlayerGuy, LeaderboardNameGuy, FirstPlaceGuysXP)
	local PlayerData = ServerPlayerData.RetrieveData(PlayerGuy)
	if PlayerData.PreviousWonLB ~= LeaderboardNameGuy then
		PlayerData.PreviousWonLB = LeaderboardNameGuy
		game.BadgeService:AwardBadge(PlayerGuy.UserId, 2146671806)
		ServerPlayerData.AddStat(PlayerGuy, "Credits", 10000)
		ServerPlayerData.AddStat(PlayerGuy, "Gems", 10000)
		game.ReplicatedStorage.Remote.ShowPlaceUI:FireClient(PlayerGuy, LeaderboardNameGuy, FirstPlaceGuysXP)
	end
end
game.ReplicatedStorage.Remote.GiveLBRewards.Event:Connect(giveRewardsImTired)

function OnUniversalInvoke(Player: Player, Action: string, Arguments: { any }): any
	if Player then
		while type(ServerPlayerData.RetrieveData(Player)) ~= "table" do
			task.wait()
		end
	end
	if Player then
		if Action == "GetData" then
			return ServerPlayerData.RetrieveData(Player)
		elseif Action == "ChangeData" then -- Seems like the server would need this, instead of the client, so it is re-implemented
			if Arguments.Method == "Add" then
				ServerPlayerData.AddStat(Player, Arguments.DataEntry, Arguments.Amount)
				if Arguments.DataEntry == "Credits" or Arguments.DataEntry == "credits" then
					game.ReplicatedStorage.Remote.Summary.UpdStat:FireClient(Player, "coin", Arguments.Amount)
				elseif Arguments.DataEntry == "Gems" or Arguments.DataEntry == "gems" then
					game.ReplicatedStorage.Remote.Summary.UpdStat:FireClient(Player, "gem", Arguments.Amount)
					--elseif Arguments.DataEntry == "Amythests" or Arguments.DataEntry == "amythests" then
					--	game.ReplicatedStorage.Remote.Summary.UpdStat:FireClient(Player, "amythest", Arguments.Amount)
				elseif Arguments.DataEntry == "XP" or Arguments.DataEntry == "xp" then
					game.ReplicatedStorage.Remote.Summary.UpdStat:FireClient(Player, "xp", Arguments.Amount)
					--giveXp(Player, Arguments.Amount)
				end
			elseif Arguments.Method == "Subtract" then
				ServerPlayerData.AddStat(Player, Arguments.DataEntry, -Arguments.Amount)
			elseif Arguments.Method == "Change" then
				ServerPlayerData.ChangeStat(Player, Arguments.DataEntry, Arguments.Amount)
			end
			ServerPlayerData._syncData(Player)
		end
	end
	if GameLib.MapTestPlaces[game.PlaceId] then
		if Action == "RequestHubData" then
			if not HubLoaded then
				repeat task.wait() until HubLoaded
			end
			return if Arguments and Arguments.ID then MapTestHubDataCache[Arguments.ID] else MapTestHubDataCache
		elseif Action == "UpdateHubEntry" then
			MapTestHubDataCache[Arguments.ID] = Arguments.Data
			local Success, Result = pcall(function()
				MapTestHubDataStore:UpdateAsync("Data", function(Data)
					if not Data then
						Data = {}
					end
					Data[Arguments.ID] = Arguments.Data
					return Data
				end)
			end)
			if not Success then
				warn(`Failed to save hub entry ({Arguments.ID}): {Result}`)
			end
			UpdateMapTestHubData:FireAllClients(MapTestHubDataCache)
		end
	end
	return true
end

function OnCharacterAdded(Character: Model)
	Character.HumanoidRootPart.CanCollide = true
	Character.HumanoidRootPart.CustomPhysicalProperties = PhysicalProperties.new(3.15, 0.5, 1, 0.3, 1)
	for _, Item in Character:GetDescendants() do
		if Item:IsA("BasePart") then
			Item.CollisionGroup = if Item.Name == "HumanoidRootPart" then "PlayerCharCollide" else "PlayerChars"
		end
	end
	Character.Humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
end

function OnCharacterFullyLoaded(Player: Player)
	OnCharacterAdded(Player.Character) -- Re-apply
	if not GameLib.MapTestPlaces[game.PlaceId] then
		local Character = Player.Character
		
		local PlayerData = ServerPlayerData.RetrieveData(Player)
		local StupidTag = script.LevelTag:Clone()
		StupidTag.Parent = Character.Head
		
		-- get rid of the game:GetDescendants() nonsense with THIS!!!!!!!!!!!!
		local TagPointer = Instance.new("ObjectValue", game.ReplicatedStorage.ClientStorage.LevelTags)
		TagPointer.Value = StupidTag
		TagPointer.Name = "Tag"
		
		local removeConnection
		removeConnection = Player.CharacterRemoving:Connect(function(c)
			if c == Character then
				removeConnection:Disconnect()
				TagPointer:Destroy()
			end
		end)
		
		TagPointer.Parent = LevelTagStorage
		
		if Player.DisplayName == Player.Name then
			StupidTag.Main.PlrName.Text = Player.Name
		elseif Player.DisplayName ~= Player.Name then
			StupidTag.Main.PlrName.Text = Player.DisplayName .. " (@" .. Player.Name .. ")"
		end

		task.spawn(function()
			while StupidTag.Parent ~= nil do
				StupidTag.Main.Level_XP.Text = `Level {PlayerData.Stats.Level} | {PlayerData.Stats.XP}/{PlayerData.Stats.MaxXP} XP`

				local FoundCurrentMonth = false
				local FoundPreviousMonth = false
				
				if PlayerLeaderboardInfo[Player.UserId] then
					if PlayerLeaderboardInfo[Player.UserId].CurrentMonth ~= -1 then
						StupidTag.Placements.Monthly.Text = `#{PlayerLeaderboardInfo[Player.UserId].CurrentMonth}`
						FoundCurrentMonth = true
					end
					if PlayerLeaderboardInfo[Player.UserId].PreviousMonth ~= -1 then
						StupidTag.Placements.Global.Text = `#{PlayerLeaderboardInfo[Player.UserId].PreviousMonth}`
						FoundPreviousMonth = true
					end
				end
				
				if not FoundCurrentMonth then
					StupidTag.Placements.Monthly.Text = `Unranked`
				end
				
				if not FoundPreviousMonth then
					StupidTag.Placements.Global.Text = `Unranked`
				end
				
				task.wait(1)
			end
		end)
		
		ServerPlayerData.Overwritable.OnEquip(Player, PlayerData, "all")
	end
end

DataRemoteServer.OnInvoke = OnUniversalInvoke

MarketplaceService.ProcessReceipt = function(receiptInfo): Enum.ProductPurchaseDecision
	if GameLib.MapTestPlaces[game.PlaceId] then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local Player = game.Players:GetPlayerByUserId(receiptInfo.PlayerId)
	if not Player then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local Item = FindInTable(ShopsFolder.Currency:GetChildren(), function(Child)
		return Child:FindFirstChild("ProductID") and Child.ProductID.Value == receiptInfo.ProductId
	end)
	if not Item then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local SuccessApply = true
	for _, SetValue in Item.Content:GetChildren() do
		local Success, Output = pcall(function()
			ServerPlayerData.AddStat(Player, SetValue.Name, SetValue.Value)
		end)
		if not Success then
			SuccessApply = false
			local ErrString = `Fail to add {SetValue.Name} with amount {SetValue.Value}: {Output}`
			warn(ErrString)
			ServerPlayerData.FlagPlayerFailedStatApply(Player, ErrString)
		end
	end
	UpdatePlayerDataRemote:FireClient(Player, ServerPlayerData.RetrieveData(Player))
	AlertRemote:FireClient(Player, "Successfully purchased " .. Item.ItemName.Value .. "!", Color3.fromRGB(0, 255, 0))
	task.spawn(function()
		ReplicatedStorage.Game.PlayerData.SuccessfulPurchase:FireClient(Player)
	end)
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

game.Players.PlayerAdded:Connect(function(Player: Player)
	--[[task.spawn(function()
		local options = Instance.new("DataStoreGetOptions")
		options.UseCache = false
		local data = HistoryDataStore:GetAsync(VersionString, options)
		if not data then
			data = {}
		end
		if table.find(data, Player.UserId) then
			return
		end
		table.insert(data, Player.UserId)
		HistoryDataStore:SetAsync(VersionString, data)
	end)]]
	
	Player.NameDisplayDistance = 0; Player.HealthDisplayDistance = 0
	
	Player.CharacterAdded:Connect(OnCharacterAdded)
	Player.CharacterAppearanceLoaded:Connect(function()
		OnCharacterFullyLoaded(Player)
	end)
	if Player.Character then
		OnCharacterAdded(Player.Character)
	end
end)

game.Players.PlayerRemoving:Connect(function(Player: Player)
	ServerPlayerData.ReleaseSession(Player)
end)

if GameLib.MapTestPlaces[game.PlaceId] then
	task.spawn(function()
		while true do
			table.clear(MapTestHubDataCache)
			HubLoaded = false

			local Success, Data = pcall(function()
				return MapTestHubDataStore:GetAsync("Data")
			end)
			if Success and Data then
				MapTestHubDataCache = Data
			end

			HubLoaded = true
			task.wait(3)
		end
	end)
else
	task.spawn(function()
		while true do
			local LBData = LeaderboardRemoteServer:Invoke(nil, "Request", { PreviousMonth = true, CurrentMonth = true })
			for _, Entry in LBData.CurrentMonth.Data do
				if not PlayerLeaderboardInfo[Entry.UserId] then
					PlayerLeaderboardInfo[Entry.UserId] = { PreviousMonth = -1, CurrentMonth = -1 }
				end
				PlayerLeaderboardInfo[Entry.UserId].CurrentMonth = Entry.Rank
			end
			for _, Entry in LBData.PreviousMonth.Data do
				if not PlayerLeaderboardInfo[Entry.UserId] then
					PlayerLeaderboardInfo[Entry.UserId] = { PreviousMonth = -1, CurrentMonth = -1 }
				end
				PlayerLeaderboardInfo[Entry.UserId].PreviousMonth = Entry.Rank
			end
			task.wait(12)
		end
	end)
end

function giveRewards(reward, player, ammount)
	local PlayerData = ServerPlayerData.RetrieveData(player)
	local validRewards = { "Credits", "Gems", "XP", "Level" }
	if PlayerData then
		if typeof(reward) == "string" and table.find(validRewards, reward) then
			PlayerData.Stats[reward] += ammount
		elseif typeof(reward) == "table" then
			for i, rew in pairs(reward) do
				local ammountE = ammount[i]
				if ammountE and PlayerData.Stats[rew] and table.find(validRewards, rew) then
					ServerPlayerData.AddStat(player, rew, ammountE)
				end
			end
		end
	end
end

RemoteFolder.RequestCode.OnServerInvoke = function(player, key, code)
	local PlayerData = ServerPlayerData.RetrieveData(player)
	if codes[code] then
		if codes[code].expired == true then
			return "This code is expired!", Color3.new(1)
		elseif PlayerData.RedeemedCodes[code] then
			return "You've already redeemed this code!", Color3.fromRGB(255, 255, 127)
		elseif codes[code].admin == true and not GameLib.HasControlPrivileges(player) then
			-- AlertRemote:FireClient(player, "This code is for admins/developers only!", Color3.fromRGB(255, 0, 0))
		else
			giveRewards(codes[code].reward, player, codes[code].ammount)
			PlayerData.RedeemedCodes[code] = true
			ServerPlayerData._syncData(player)
			return `Successfully redeemed! <font weight="Medium">Earned {codes[code].msg}!</font>`, Color3.new(0, 1)
		end
	else
		for testCode in codes do
			if string.lower(code) == string.lower(testCode) then
				return "Codes are case sensitive!", Color3.new(1)
			end
		end
		return "This code doesn't exist!", Color3.new(1)
	end
end

ReplicatedStorage.Game.PlayerData.ConvertCredits.OnServerInvoke = function(player, credits)
	-- prevents non-numbers, NaNs, or negatives
	if type(credits) ~= "number" or credits ~= credits or credits < 0 then
		return "Illegal number"
	end
	
	if credits < 10 then
		return "Too little Credits!"
	end
	
	local totalCost = credits - credits % 10
	local data = ServerPlayerData.RetrieveData(player)
	
	if data then
		if data.Stats.Credits >= totalCost then
			if credits == 69420 then
				AlertRemote:FireClient(player, "interesting number")
			end
			ServerPlayerData.AddStat(player, "Credits", -totalCost)
			ServerPlayerData.AddStat(player, "Gems", math.floor(totalCost / 10))
			return true
		end
		return "Not enough Credits!"
	end
	
	return "Unexpected server error"
end

-- Prepare shop index
local ShopTitleFlavors = {
	Halloween = "🎃 ",
	Christmas = "❄️ ",
	["Anniv."] = "🎂 ",
}

--[[local ShopPriceFlavors = {
	Robux = "R$",
	Coins = "💰",
	Gems = "💎",
}]]

local ShopPriceFlavors = {
	Robux = "R$",
	Gems = " Gems",
}

local AllowedItemInfoType = {"IntValue", "NumberValue", "StringValue", "BoolValue"}

for _, CategoryFolder in ShopsFolder:GetChildren() do
	ShopsIndex[CategoryFolder.Name] = {}
	-- TODO: improve this???
	for _, ItemInfo in CategoryFolder:GetChildren() do
		local Data = ItemInfo:GetChildren()
		local InfoTable = {}
		local ItemName = ItemInfo:FindFirstChild("ItemName") and ItemInfo.ItemName.Value
		if not ItemName then
			continue
		end
		
		for _, Value in Data do
			if table.find(AllowedItemInfoType, Value.ClassName) then
				InfoTable[Value.Name] = Value.Value
			else
				InfoTable[Value.Name] = Value
			end
		end
		
		if InfoTable.ItemName then
			InfoTable.FlavoredName = (ShopTitleFlavors[InfoTable.Season] or "") .. InfoTable.ItemName
		end
		if InfoTable.Price then
			local SelectedFlavor = " Credits"
			for Key, Flavor in ShopPriceFlavors do
				if InfoTable[Key] then
					SelectedFlavor = Flavor
					break
				end
			end
			InfoTable.FlavoredPrice = `{InfoTable.Price}{SelectedFlavor}`
		end
		InfoTable.Category = CategoryFolder.Name
		
		ShopsIndex[CategoryFolder.Name][ItemName] = InfoTable
	end
end

ReplicatedStorage.Game.RequestShopItems.OnServerInvoke = function()
	return ShopsIndex
end
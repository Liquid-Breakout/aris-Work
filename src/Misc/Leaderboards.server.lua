local DataStoreService = game:GetService("DataStoreService")
local UserService = game:GetService("UserService")

local NotifyUpdateRemote = game.ReplicatedStorage.Game:WaitForChild("OnLeaderboardsDataUpdate")
local Communicator = game.ReplicatedStorage:WaitForChild("LeaderboardsCommunicator")
local CommunicatorServer = game.ReplicatedStorage:WaitForChild("LeaderboardsCommunicator_Server")

local MonthNames = {
	"January",
	"February",
	"March",
	"April",
	"May",
	"June",
	"July",
	"August",
	"September",
	"October",
	"November",
	"December",
}

local LeaderboardsDataStore = {
	AllTime = { Name = "All Time", Store = DataStoreService:GetDataStore("Leaderboards-AllTime") },
	CurrentMonth = { Name = "N/A 20??", Store = nil },
	PreviousMonth = { Name = "N/A 20??", Store = nil },
}
local LeaderboardsCache = nil
local UserInfosMapCache = {}
local LeaderboardsQueue = {AllTime = {}, CurrentMonth = {}}
local FirstPlaceGuy = ""

local function UpdateLeaderboardsDataStore()
	local CurrentDateValue = os.date("*t")
	LeaderboardsDataStore.CurrentMonth.Name = `{MonthNames[CurrentDateValue.month]} {CurrentDateValue.year}`
	LeaderboardsDataStore.CurrentMonth.Store =
		DataStoreService:GetDataStore(`Leaderboards-{MonthNames[CurrentDateValue.month]}-{CurrentDateValue.year}`)

	local PreviousMonth = CurrentDateValue.month - 1
	local PreviousYear = CurrentDateValue.year
	if PreviousMonth < 1 then
		PreviousMonth = 12
		PreviousYear -= 1
	end
	LeaderboardsDataStore.PreviousMonth.Name = `{MonthNames[PreviousMonth]} {PreviousYear}`
	LeaderboardsDataStore.PreviousMonth.Store =
		DataStoreService:GetDataStore(`Leaderboards-{MonthNames[PreviousMonth]}-{PreviousYear}`)
end

local function RetrieveAllDataFromDataStore(RequestedOrderedDataStore: OrderedDataStore): { [number]: { any } }
	local Data = {}
	local Success: boolean, LBData: any = pcall(function()
		return RequestedOrderedDataStore:GetAsync("Data")
	end)

	if Success and LBData then
		table.sort(LBData, function(a, b)
			return a.XP > b.XP
		end)
		for Rank, Entry in LBData do
			Data[Rank] = Entry
		end
	end

	return Data
end

local function MapUserInfosFromLeaderboard(LeaderboardData: any)
	local UserIds = table.create(#LeaderboardData)
	local Count = 0
	for i = 1, #LeaderboardData do
		if not UserInfosMapCache[LeaderboardData[i].UserId] then
			Count += 1
			UserIds[Count] = LeaderboardData[i].UserId
		end
	end
	
	local ChunksToProcess = math.ceil(#UserIds / 200)
	for Chunk = 1, ChunksToProcess do
		local UserIdsChunk = table.move(UserIds, 200 * (Chunk - 1) + 1, math.min(200 * Chunk, #UserIds), 1, table.create(200))
		local Success, ChunkInfo = pcall(function()
			return UserService:GetUserInfosByUserIdsAsync(UserIdsChunk)
		end)
		if Success then
			for _, UserInfo in ChunkInfo do
				UserInfosMapCache[UserInfo.Id] = if UserInfo.Username ~= UserInfo.DisplayName then `{UserInfo.DisplayName} (@{UserInfo.Username})` else UserInfo.Username
			end
		end
		task.wait(1)
	end
end

local function RenewLeaderboardData(LeaderboardName: string)
	local ReturnData = {
		Name = LeaderboardsDataStore[LeaderboardName].Name,
		Data = {},
	}

	local LeaderboardData = RetrieveAllDataFromDataStore(LeaderboardsDataStore[LeaderboardName].Store)
	MapUserInfosFromLeaderboard(LeaderboardData)
	for Rank, Entry in LeaderboardData do
		table.insert(ReturnData.Data, {
			Rank = Rank,
			Name = UserInfosMapCache[tonumber(Entry.UserId)] or "Unknown", --ConstructPlayerName(tonumber(Entry.UserId) :: number),
			UserId = tonumber(Entry.UserId),
			XP = Entry.XP,
		})
	end

	return ReturnData
end

local function ConstructDataForRemote(AllTime, CurrentMonth, PreviousMonth)
	UpdateLeaderboardsDataStore()
	
	local Data = {}
	
	if AllTime then
		Data.AllTime = RenewLeaderboardData("AllTime")
	end
	
	if CurrentMonth then
		Data.CurrentMonth = RenewLeaderboardData("CurrentMonth")
	end
	
	for i = 1, 3 do
		workspace.LeaderboardLB.Podiums[i].Info.SurfaceGui.Enabled = false
	end
	
	if PreviousMonth then
		Data.PreviousMonth = RenewLeaderboardData("PreviousMonth")

		for _, Entry in Data.PreviousMonth.Data do
			pcall(function()
				if Entry.Rank >= 1 and Entry.Rank <= 3 then
					local PodiumPlayerName = game.Players:GetNameFromUserIdAsync(tonumber(Entry.UserId))
					if Entry.Rank == 1 then
						FirstPlaceGuy = PodiumPlayerName
					end
					workspace.LeaderboardLB.Podiums[Entry.Rank].Info.SurfaceGui.Enabled = true
					workspace.LeaderboardLB.Podiums[Entry.Rank].Info.SurfaceGui.Username.Text =
						`@{PodiumPlayerName}`
					workspace.LeaderboardLB.Podiums[Entry.Rank].Info.SurfaceGui.XPCount.Text =
						`Earned {Entry.XP} XP`
					local HumDesc = game.Players:GetHumanoidDescriptionFromUserId(Entry.UserId)
					workspace.LeaderboardLB.Podiums[Entry.Rank].NPC.Humanoid:ApplyDescription(HumDesc)
				end
			end)
		end
	end
	return Data
end

function OnUniversalInvoke(IsServer: boolean, Player: Player, Action: string, Arguments: any): any
	if not Arguments then
		Arguments = {}
	end
	UpdateLeaderboardsDataStore()
	if Action == "Request" then
		if Arguments.AllTime and Arguments.CurrentMonth and Arguments.PreviousMonth and LeaderboardsCache then
			return LeaderboardsCache
		end
		return ConstructDataForRemote(Arguments.AllTime, Arguments.CurrentMonth, Arguments.PreviousMonth)
	elseif Action == "Add" then
		if IsServer then
			--[[if not LeaderboardsQueue[Player.UserId] then
				LeaderboardsQueue[Player.UserId] = 0
			end
			LeaderboardsQueue[Player.UserId] += Arguments]]

			local Success, LBData = pcall(function()
				return LeaderboardsDataStore.AllTime.Store:GetAsync("Data")
			end)
			if Success and not LBData then
				LeaderboardsDataStore.AllTime.Store:SetAsync("Data", {})
			end
			pcall(function()
				LeaderboardsDataStore.AllTime.Store:UpdateAsync("Data", function(CurrentData)
					local Found = false
					for _, Entry in CurrentData do
						if Entry.UserId == Player.UserId then
							Entry.XP += Arguments
							Found = true
							break
						end
					end

					if not Found then
						table.insert(CurrentData, {
							UserId = Player.UserId,
							XP = Arguments
						})
					end

					return CurrentData
				end)
			end)

			Success, LBData = pcall(function()
				return LeaderboardsDataStore.CurrentMonth.Store:GetAsync("Data")
			end)
			if Success and not LBData then
				LeaderboardsDataStore.CurrentMonth.Store:SetAsync("Data", {})
			end
			pcall(function()
				LeaderboardsDataStore.CurrentMonth.Store:UpdateAsync("Data", function(CurrentData)
					local Found = false
					for _, Entry in CurrentData do
						if Entry.UserId == Player.UserId then
							Entry.XP += Arguments
							Found = true
							break
						end
					end

					if not Found then
						table.insert(CurrentData, {
							UserId = Player.UserId,
							XP = Arguments
						})
					end

					return CurrentData
				end)
			end)
		end
	end
	return
end

function wipeLBData(Data)
	if not Data then
		return
	end

	local UserId = Data
	if typeof(Data) == "string" then
		UserId = game.Players:GetUserIdFromNameAsync(Data)
	end
	for _, LeaderboardStore in {LeaderboardsDataStore.AllTime.Store, LeaderboardsDataStore.CurrentMonth.Store, LeaderboardsDataStore.PreviousMonth.Store} do
		if LeaderboardStore then
			pcall(function()
				LeaderboardStore:UpdateAsync("Data", function(CurrentData)
					for i, Entry in CurrentData do
						if Entry.UserId == UserId then
							table.remove(CurrentData, i)
							break
						end
					end

					return CurrentData
				end)
			end)
		end
	end
end
game.ReplicatedStorage.Remote.WipeLeaderboardData.Event:Connect(wipeLBData)

Communicator.OnServerInvoke = function(...)
	return OnUniversalInvoke(false, ...)
end

CommunicatorServer.OnInvoke = function(...)
	return OnUniversalInvoke(true, ...)
end

task.spawn(function()
	while true do
		print("generating leaderboard cache")
		LeaderboardsCache = ConstructDataForRemote(true, true, true)
		print("generated leaderboard cache")
		task.spawn(function()
			for _, player in next, game:GetService("Players"):GetPlayers() do
				if player.PlayState.Value == "None" then
					NotifyUpdateRemote:FireClient(player, LeaderboardsCache)
				end
			end
		end)
		task.wait(15)
	end
end)

task.wait(5)
task.spawn(function()
	while task.wait(5) do
		if game.Players:FindFirstChild(FirstPlaceGuy) then
			game.ReplicatedStorage.Remote.GiveLBRewards:Fire(
				game.Players[FirstPlaceGuy],
				LeaderboardsDataStore.CurrentMonth.Name
			)
		end
	end
end)

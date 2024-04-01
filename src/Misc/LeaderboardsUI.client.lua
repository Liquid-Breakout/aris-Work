-- cutymeo has appeared again
local UserService = game:GetService("UserService")
local TweenService = game:GetService("TweenService")
local Player = game.Players.LocalPlayer
local PlayerId = Player.UserId

local Communicator = game.ReplicatedStorage:WaitForChild("LeaderboardsCommunicator")
local OnUpdateRemote = game.ReplicatedStorage.Game:WaitForChild("OnLeaderboardsDataUpdate")

local LeaderboardPart = workspace:WaitForChild("LeaderboardLB")
local LeaderboardUI = LeaderboardPart:WaitForChild("Leaderboard").MainFrame.Leaderboard
local Title = LeaderboardUI.LB_Title
local PlayerList = LeaderboardUI.LB_List
local LBOptions = LeaderboardUI.LB_Options
local LBType = LeaderboardUI.LB_Type
local PersonalRankUI = LeaderboardUI.LB_PersonalRank

local ViewingLB = "AllTime"
local CardColor = {
	AllTime = Color3.fromRGB(98, 0, 111),
	CurrentMonth = Color3.fromRGB(0, 72, 127),
	PreviousMonth = Color3.fromRGB(111, 102, 0),
}
local RankTextColor = {
	[1] = Color3.fromRGB(255, 255, 0),
	[2] = Color3.fromRGB(255, 255, 255),
	[3] = Color3.fromRGB(221, 123, 85),
	Default = Color3.fromRGB(116, 116, 116)
}
local CurrentPage = {
	AllTime = 1,
	CurrentMonth = 1,
	PreviousMonth = 1,
}
local SearchFilter = ""
local ReceivedLBData = {
	AllTime = {},
	CurrentMonth = {},
	PreviousMonth = {},
}
local RealLBData = {
	AllTime = {},
	CurrentMonth = {},
	PreviousMonth = {},
}
local PersonalRankData = {
	AllTime = { Rank = 0, XP = 0 },
	CurrentMonth = { Rank = 0, XP = 0 },
	PreviousMonth = { Rank = 0, XP = 0 },
}

local function ConstructPlayerName(UserId: number): string
	local UserInfo

	if PlayerId == UserId then
		UserInfo = { Username = Player.Name, DisplayName = Player.DisplayName }
	else
		pcall(function()
			UserInfo = UserService:GetUserInfosByUserIdsAsync({ UserId })[1]
		end)
	end

	if UserInfo then
		if UserInfo.Username == UserInfo.DisplayName then
			return UserInfo.Username
		else
			return `{UserInfo.DisplayName} (@{UserInfo.Username})`
		end
	end

	return "nil"
end

local function Show1stPlaceUI()
	script.LeaderboardWin:Play()
	local ui = script.Parent.Leader_Results.Frame
	TweenService
		:Create(
			ui,
			TweenInfo.new(0.5, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out),
			{ Position = UDim2.new(0.5, 0, 0.5, 0) }
		)
		:Play()
	TweenService
		:Create(ui.UIScale, TweenInfo.new(0.5, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), { Scale = 1 })
		:Play()
	TweenService
		:Create(
			ui.Parent.Outline,
			TweenInfo.new(0.5, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out),
			{ Position = UDim2.new(0.5, 0, 0.5, 0) }
		)
		:Play()
	TweenService
		:Create(
			ui.Parent.Outline.UIScale,
			TweenInfo.new(0.5, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out),
			{ Scale = 1 }
		)
		:Play()
	ui.Return.Text = `{PersonalRankData.PreviousMonth.XP} XP - {RealLBData.PreviousMonth.Name}`
	ui.List.StatsName.Text =
		`Congratulations! You took #1 of {RealLBData.PreviousMonth.Name}! You've been awarded with the following below:`
end
game.ReplicatedStorage.Remote.ShowPlaceUI.OnClientEvent:Connect(Show1stPlaceUI)
local function UpdateLeaderboardsRanking()
	Title.Text = RealLBData[ViewingLB].Name

	PersonalRankUI.PlaceUser.Text = `#{PersonalRankData[ViewingLB].Rank}: {ConstructPlayerName(PlayerId)}`
	PersonalRankUI.PlaceUser.TextColor3 = RankTextColor[PersonalRankData[ViewingLB].Rank] or RankTextColor.Default
	PersonalRankUI.XPCount.Text = `{PersonalRankData[ViewingLB].XP} XP`

	CurrentPage[ViewingLB] = if #RealLBData[ViewingLB].Data > 0
		then math.clamp(CurrentPage[ViewingLB], 1, RealLBData[ViewingLB].MaxPages)
		else 0
	LBOptions.Pages.MaxPage.PageNum.Text = CurrentPage[ViewingLB]
	LBOptions.Pages.MaxPage.Text = `/{RealLBData[ViewingLB].MaxPages}`

	local StartPageIndex = 20 * (CurrentPage[ViewingLB] - 1)
	for CardId = 1, 20 do
		task.spawn(function()
			if RealLBData[ViewingLB].Data[StartPageIndex + CardId] then
				local PlayerRank = RealLBData[ViewingLB].Data[StartPageIndex + CardId].Rank
				local PlayerXP = RealLBData[ViewingLB].Data[StartPageIndex + CardId].XP
				local PlayerName = RealLBData[ViewingLB].Data[StartPageIndex + CardId].Name
				
				local CardColor = {CardColor[ViewingLB]:ToHSV()}
				
				-- RRGaming2017
				-- TODO: Desaturate and lighten if the entry is the player's
				PlayerList[CardId].BackgroundColor3 = Color3.fromHSV(CardColor[1], CardColor[2], CardColor[3])
				
				PlayerList[CardId].PlaceUser.Text = `#{PlayerRank}: {PlayerName}`
				PlayerList[CardId].PlaceUser.TextColor3 = RankTextColor[PlayerRank] or RankTextColor.Default
				PlayerList[CardId].XPCount.Text = `{PlayerXP} XP`
				PlayerList[CardId].Visible = true
			else
				PlayerList[CardId].Visible = false
			end
		end)
	end
end

local function UpdateLeaderboardsData(Data)
	if Data then
		ReceivedLBData = Data
	end

	table.clear(RealLBData[ViewingLB])
	RealLBData[ViewingLB] = {
		Name = ReceivedLBData[ViewingLB].Name,
		Data = {},
		MaxPages = 0,
	}

	for i, Entry in ReceivedLBData[ViewingLB].Data do
		if Entry.UserId == PlayerId then
			PersonalRankData[ViewingLB].Rank = Entry.Rank
			PersonalRankData[ViewingLB].XP = Entry.XP
		end
		if string.find(string.lower(Entry.Name), string.lower(SearchFilter)) then
			table.insert(RealLBData[ViewingLB].Data, Entry)
		end
	end
	RealLBData[ViewingLB].MaxPages = math.ceil(#RealLBData[ViewingLB].Data / 20)
	UpdateLeaderboardsRanking()
end

local function SwitchLBView(NewView: string)
	ViewingLB = NewView
	UpdateLeaderboardsData()
end

UpdateLeaderboardsData(
	Communicator:InvokeServer("Request", { AllTime = true, CurrentMonth = true, PreviousMonth = true })
)
OnUpdateRemote.OnClientEvent:Connect(UpdateLeaderboardsData)

LBType.Current.MouseButton1Click:Connect(function()
	SwitchLBView("CurrentMonth")
	--Show1stPlaceUI()
end)
LBType.Previous.MouseButton1Click:Connect(function()
	SwitchLBView("PreviousMonth")
end)
LBType.Lifetime.MouseButton1Click:Connect(function()
	SwitchLBView("AllTime")
end)
LBOptions.Pages.MaxPage.PageNum.FocusLost:Connect(function()
	local GotPageNumber = tonumber(LBOptions.Pages.MaxPage.PageNum.Text)
	if GotPageNumber then
		CurrentPage[ViewingLB] = GotPageNumber
	end
	UpdateLeaderboardsRanking()
end)
LBOptions.Search.TextBox.FocusLost:Connect(function()
	SearchFilter = LBOptions.Search.TextBox.Text
	UpdateLeaderboardsData()
end)
LBOptions.Pages.Previous.MouseButton1Click:Connect(function()
	CurrentPage[ViewingLB] -= 1
	if CurrentPage[ViewingLB] < 1 then
		CurrentPage[ViewingLB] = RealLBData[ViewingLB].MaxPages
	end

	UpdateLeaderboardsRanking()
end)
LBOptions.Pages.Next.MouseButton1Click:Connect(function()
	CurrentPage[ViewingLB] += 1
	if CurrentPage[ViewingLB] > RealLBData[ViewingLB].MaxPages then
		CurrentPage[ViewingLB] = 1
	end

	UpdateLeaderboardsRanking()
end)

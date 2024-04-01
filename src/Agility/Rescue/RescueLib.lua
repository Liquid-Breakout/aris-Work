-- Handles Rescue Mission
-- cutymeo

local Handler = {
	Rounds = 3,
	Rescue = false,
	RescueCutscene = false,
}

local GameLib = require(game.ReplicatedStorage.GameLib)

local RescueMonitor = workspace.RescueMonitor
local RoundCounter = 0

local EscapeesParts = {
	"Humanoid",
	"Head",
	"Torso",
	"Left Arm",
	"Left Leg",
	"Right Arm",
	"Right Leg",
	"HumanoidRootPart",
	"RescueZone",
}

local function AddRescueEntry(Text, Color, Scaled)
	local HolderLabel = RescueMonitor.TV.SurfaceGui.Frame.TextLabel
	local EntryLabel = RescueMonitor.TV.SurfaceGui.Frame.TextLabel.TextLabel

	local CurrentLabels = #HolderLabel:GetChildren() - 1

	HolderLabel.Position -= UDim2.fromOffset(0, EntryLabel.Size.Y.Offset)

	local NewEntry = EntryLabel:Clone()
	NewEntry.Position += UDim2.fromOffset(0, EntryLabel.Size.Y.Offset * CurrentLabels)
	NewEntry.Parent = RescueMonitor.TV.SurfaceGui.Frame.TextLabel
	NewEntry.Text = Text
	NewEntry.TextColor3 = Color and Color or NewEntry.TextColor3
	NewEntry.TextScaled = Scaled or true
end

function Handler.GetEscapeeSetting(Escapee, Setting)
	if not Escapee:FindFirstChild("EscapeeSettings") then
		return nil
	end
	if not Escapee.EscapeeSettings:FindFirstChild(Setting) then
		return nil
	end
	return Escapee.EscapeeSettings[Setting].Value
end

local function CheckEscapee(Escapee)
	for _, Part in pairs(EscapeesParts) do
		if not Escapee:FindFirstChild(Part) then
			return false, Part
		end
	end
	if not Escapee:FindFirstChild("Marker") then
		local Marker = script.Marker:Clone()
		
		Marker.RescueTextLabel.Text = utf8.char(0x26A0)
		
		Marker.Parent = Escapee.HumanoidRootPart
		Marker.Adornee = Escapee.HumanoidRootPart
		
		game:GetService("TweenService"):Create(Marker.MkImg.Gradient, TweenInfo.new(1.25, Enum.EasingStyle.Linear, Enum.EasingDirection.In, -1), {Offset = Vector2.new(0, 1)}):Play()
		game:GetService("TweenService"):Create(Marker.RescueTextLabel.Gradient, TweenInfo.new(1.25, Enum.EasingStyle.Linear, Enum.EasingDirection.In, -1), {Offset = Vector2.new(0, 1)}):Play()
	end
	if
		not Escapee.HumanoidRootPart.Marker:FindFirstChild("MkImg")
		and not Escapee.HumanoidRootPart.Marker:FindFirstChild("MarkerImage")
	then
		return false, "MarkerImage / MkImg"
	elseif not Escapee.HumanoidRootPart.Marker:FindFirstChild("RescueTextLabel") then
		return false, "RescueTextLabel"
	elseif not Escapee.RescueZone:FindFirstChild("Hitbox") then
		return false, "Rescue Hitbox"
	elseif not Escapee.RescueZone:FindFirstChild("Platform") then
		return false, "Rescue Platform"
	elseif not Escapee.RescueZone:FindFirstChild("GradientPart") then
		return false, "GradientPart"
	end
	return true
end

local function UpdateEscapeeAppearance(Escapee)
	local UserIdSetting = Handler.GetEscapeeSetting(Escapee, "AppearanceByUserId") or 0
	pcall(function()
		local LoadedModel = game.Players:GetCharacterAppearanceAsync(UserIdSetting)
		for _, Part in pairs(Escapee:GetChildren()) do
			if not table.find(EscapeesParts, Part.Name) then
				Part:Destroy()
			end
		end
		for _, AppearancePart in pairs(LoadedModel:GetChildren()) do
			local NewPart = AppearancePart:Clone()
			if NewPart:IsA("SpecialMesh") or NewPart:IsA("BlockMesh") or NewPart:IsA("CylinderMesh") then
				NewPart.Parent = Escapee.Head
			elseif NewPart:IsA("Accessory") then
				NewPart.Parent = Escapee
				NewPart.Handle.AccessoryWeld.Part1 = Escapee[tostring(NewPart.Handle.AccessoryWeld.Part1)]
			elseif NewPart:IsA("Decal") then
				Escapee.Head.face.Texture = NewPart.Texture
			elseif
				NewPart:IsA("BodyColors")
				or NewPart:IsA("CharacterMesh")
				or NewPart:IsA("Shirt")
				or NewPart:IsA("Pants")
				or NewPart:IsA("ShirtGraphic")
			then
				if Escapee:findFirstChild("Body Colors") then
					Escapee["Body Colors"]:Destroy()
				end
				NewPart.Parent = Escapee
			elseif NewPart:IsA("Hat") then
				NewPart.Parent = Escapee
				NewPart.Handle.CFrame = Escapee.Head.CFrame
					* CFrame.new(0, Escapee.Head.Size.Y / 2, 0)
					* NewPart.AttachmentPoint:inverse()
			end
		end
	end)
	if not Escapee.Head:FindFirstChildOfClass("SpecialMesh") then
		local Mesh = Instance.new("SpecialMesh", Escapee.Head)
		Mesh.MeshType = Enum.MeshType.Head
		Mesh.Scale = Vector3.new(1.25, 1.25, 1.25)
	end
end

function Handler.Run(Map, CanRescue, Forced)
	if CanRescue == nil then
		CanRescue = true
	end

	Handler.Rescue = false
	Handler.RescueCutscene = false

	game.ReplicatedStorage.Game.IsRescue.Value = false
	game.ReplicatedStorage.Game.RescueCutscene.Value = false

	local Escapees = {}
	local RescueAlertString = ""

	local CanCutscene = true

	if Map.Settings:FindFirstChild("RescueCutscene") then
		CanCutscene = Map.Settings.RescueCutscene.Value
	end
	Handler.RescueCutscene = CanCutscene

	game.ReplicatedStorage.Game.RescueCutscene.Value = CanCutscene

	RoundCounter += 1

	for _, Model in pairs(Map:GetDescendants()) do
		if Model:IsA("Model") and Model.Name == "Escapee" and CheckEscapee(Model) then
			table.insert(Escapees, Model)
		end
	end

	if #Escapees == 0 then
		RoundCounter -= 1
		return
	elseif #Escapees == 1 then
		RescueAlertString = Handler.GetEscapeeSetting(Escapees[1], "EscapeeName") or "Escapee"
	else
		RescueAlertString = #Escapees .. " Escapees"
	end

	if CanRescue and (RoundCounter % Handler.Rounds == 0 or Forced) then
		Handler.Rescue = true
		game.ReplicatedStorage.Game.IsRescue.Value = true

		local EscapeesHolder = Instance.new("Folder", Map)
		EscapeesHolder.Name = "_RescueEscapees"

		for _, Escapee in Escapees do
			local EscapeeHumanoid: Humanoid? = Escapee:FindFirstChild("Humanoid")
			if EscapeeHumanoid then
				for _, State in Enum.HumanoidStateType:GetEnumItems() do
					pcall(EscapeeHumanoid.SetStateEnabled, EscapeeHumanoid, State, false)
				end
			end
			for _, EscapeePart in Escapee:GetDescendants() do
				if EscapeePart:IsA("BasePart") then
					EscapeePart.Anchored = true
					EscapeePart.CanCollide = false
					pcall(function()
						EscapeePart.CollisionGroup = "IgnorePlayer"
					end)
				end
				if EscapeePart:IsA("MeshPart") then
					EscapeePart.RenderFidelity = Enum.RenderFidelity.Automatic
					EscapeePart.CollisionFidelity = Enum.CollisionFidelity.Box
				end
			end
			task.spawn(UpdateEscapeeAppearance, Escapee)
			Escapee.Parent = EscapeesHolder
		end

		task.delay(1.2, function()
			AddRescueEntry(">> DISTRESS CALL:", Color3.fromRGB(255, 0, 0))
			AddRescueEntry(
				RescueAlertString .. " found in: " .. Map.Settings.MapName.Value,
				Color3.fromRGB(255, 0, 0),
				true
			)
		end)

		for _, Player in pairs(GameLib.GetLoadingPlayers() or GameLib.GetPlayersWithPlayState("Playing")) do
			if Player.Character then
				game.ReplicatedStorage.Game.PromptRescue:FireClient(Player, Escapees, CanCutscene, RescueAlertString)
			end
		end
	else
		for _, Escapee in pairs(Escapees) do
			Escapee:Destroy()
		end
	end
end

return Handler

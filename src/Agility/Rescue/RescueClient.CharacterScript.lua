local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local ContentProviderService = game:GetService("ContentProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameLib = require(game.ReplicatedStorage.GameLib)
local RescueLib = require(game.ReplicatedStorage.RescueLib)

local Player = game.Players.LocalPlayer
local Character = Player.Character or Player.CharacterAdded:Wait()
local Humanoid = Character.Humanoid

local BlackoutEffect = nil
local BlackourBlurEffect = nil

TweenLib = require(game.ReplicatedStorage.TweenLib)

local EscapeeAlarm = Instance.new("Sound", script)
EscapeeAlarm.SoundId = "rbxassetid://9097521793"
EscapeeAlarm.PlaybackSpeed = 1.25
EscapeeAlarm.Volume = 1

local EscapeeHitboxTouched = Instance.new("Sound", script)
EscapeeHitboxTouched.SoundId = "rbxassetid://147490163"
EscapeeHitboxTouched.PlaybackSpeed = 1.25
EscapeeHitboxTouched.Volume = 1

local EscapeeSurvive = Instance.new("Sound", script)
EscapeeSurvive.SoundId = "rbxassetid://983016958"
EscapeeSurvive.PlaybackSpeed = 1.5
EscapeeSurvive.Volume = 1

local FadeInfo = TweenInfo.new(.5, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut)

local FollowDelay = 0
local GotEscapees = 0
local Survived = false
local CaptureMovement = false

local CurrentEscapees
local SpawnNotification = game.ReplicatedStorage.ClientStorage.SpawnNotification

local function StartRescue(Escapees)
	CurrentEscapees = Escapees
	for i, Escapee in CurrentEscapees do
		local EscapeeName = RescueLib.GetEscapeeSetting(Escapee, "EscapeeName") or "Escapee"
		local Marker = Escapee.HumanoidRootPart.Marker

		local Rescuing = false
		local CurrentFrame = 0
		local MovementLerp = 0
		local State = "Idle"
		local DistanceToInitiateStates = {
			Idle = .015,
			Move = .5
		}
		local MovementFrames = {}
		local Connections = {}

		local function ConfigureEscapeeProperties(Escapee)
			for _,v in Escapee:GetDescendants() do
				if v:IsA("BasePart") and not v:FindFirstAncestor("RescueZone") then
					v.Anchored = if v:FindFirstAncestorOfClass("Accessory") then false else true
				end
			end
		end

		local function FadeEscapee(Escapee, FadeTransparency)
			for _,v in Escapee:GetDescendants() do
				if v:IsA("BasePart") or v:IsA("Texture") or v:IsA("Decal") and v.Name ~= "HumanoidRootPart" then
					TweenService:Create(v, FadeInfo, {Transparency = FadeTransparency}):Play()
				elseif v.Name == "HumanoidRootPart" then
					v.Transparency = 1
				end
			end
		end

		local function Movement(MovementGap)
			Connections.Movement = RunService.RenderStepped:Connect(function(deltaTime)
				-- Taken from movement lerp patch
				-- Making sure there's always a gap (delay) between the current frame and the captured frames
				if #MovementFrames <= MovementGap then
					return
				end

				local TargetFrame = #MovementFrames - MovementGap
				local TrackFrame = MovementFrames[TargetFrame]

				if TrackFrame then		
					local NextState = if State == "Idle" then "Move" else "Idle"
					if (TrackFrame.Torso.Position - Character.Torso.Position).Magnitude <= DistanceToInitiateStates[NextState] then
						State = NextState
						MovementLerp = 0
					end

					for Part, CF in TrackFrame do
						Escapee[Part].CFrame = Escapee[Part].CFrame:Lerp(CF, MovementLerp)
					end

					table.remove(MovementFrames, TargetFrame)
				end
				MovementLerp = math.clamp(MovementLerp + deltaTime * .5, 0, .5)
			end)
		end
		
		local function EscapeeGhost()
			for _, EscapeePart in Escapee:GetDescendants() do
				if (EscapeePart:IsA("BasePart") or EscapeePart:IsA("Texture") or EscapeePart:IsA("Decal")) and EscapeePart.Name ~= "HumanoidRootPart" then
					Connections[EscapeePart] = RunService.Heartbeat:Connect(function()
						local LocalTransparency = 1 - ((Character.HumanoidRootPart.Position - Escapee.HumanoidRootPart.Position).Magnitude) * .2
						EscapeePart.LocalTransparencyModifier = LocalTransparency
					end)
				end	
			end
		end

		local function End()
			for ConnectionName, Connection in Connections do
				if ConnectionName ~= "Movement" then
					Connection:Disconnect()
				end
			end
			FadeEscapee(Escapee, 1)
			task.delay(FadeInfo.Time + .1, function()
				if Connections.Movement then
					Connections.Movement:Disconnect()
				end
				Escapee:Destroy()
			end)
		end

		if Marker:FindFirstChild("Background") then
			Marker.Background.ImageTransparency = .75
			Marker.Background.Image = "rbxassetid://530269709"
		end

		Marker.RescueTextLabel.Text = "⚠"
		Marker.RescueTextLabel.TextTransparency = 0
		Marker.MkImg.Image = "rbxassetid://5248559528"
		Marker.MkImg.ImageTransparency = 0

		Escapee.RescueZone.Hitbox.Touched:Connect(function(Touched)
			if not Rescuing and Touched.Parent == Character then
				Rescuing = true
				game.ReplicatedStorage.Remote.OnRescue:FireServer()
				GotEscapees += 1
				CaptureMovement = true
				EscapeeHitboxTouched:Play()
				Debris:AddItem(Escapee.RescueZone, 0)
				Debris:AddItem(Marker, 1 / 30)

				FollowDelay += .5
				SpawnNotification:Invoke("⚠️ Rescuing " .. EscapeeName .. ": Get to the Exit! ⚠️", Color3.new(0.596078, 0.760784, 0.858824), 7, "rescue", "ingame")

				Connections.Checking = RunService.Heartbeat:Connect(function()
					if Survived then
						End()
					end
				end)
				
				Connections.Tracking = RunService.RenderStepped:Connect(function(deltaTime)
					if not CaptureMovement then
						return
					end

					table.insert(MovementFrames, {
						HumanoidRootPart = Character.HumanoidRootPart.CFrame,
						Head = Character.Head.CFrame,
						["Left Arm"] = Character["Left Arm"].CFrame,
						["Left Leg"] = Character["Left Leg"].CFrame,
						["Right Arm"] = Character["Right Arm"].CFrame,
						["Right Leg"] = Character["Right Leg"].CFrame,
						Torso = Character.Torso.CFrame,
					})
				end)

				ConfigureEscapeeProperties(Escapee)
				EscapeeGhost()
				
				task.delay(FollowDelay, function()
					local MovementGap = #MovementFrames
					Movement(MovementGap)
				end)
				
				-- also use this remoteevent for registering the rescue to the server
				game.ReplicatedStorage.Game.PromptRescue:FireServer(Escapee)
			end
		end)
		Humanoid.Died:Connect(function()
			workspace.CurrentCamera.CameraType = "Custom"
			workspace.CurrentCamera.CameraSubject = Character.Humanoid

			GotEscapees -= 1
			CaptureMovement = false
			End()
		end)
	end
end

game.ReplicatedStorage.Game.PromptRescue.OnClientEvent:Connect(function(Escapees, CanCutscene, AlertString)
	FollowDelay = 0
	GotEscapees = 0
	Survived = false
	CaptureMovement = false
	StartRescue(Escapees)

	if CanCutscene then
		workspace.CurrentCamera.CameraType = Enum.CameraType.Scriptable
		workspace.CurrentCamera.CFrame = workspace.RescueCam.CFrame
		script.DoingRescueCutscene.Value = true
		
		task.delay(.5, function()
			local function resetHeadCframe()
				workspace.CurrentCamera.CameraType = Enum.CameraType.Custom
				workspace.CurrentCamera.CameraSubject = Character.Humanoid
				script.DoingRescueCutscene.Value = false
				pcall(function()
					if Player.Character then
						workspace.CurrentCamera.CFrame = workspace.Multiplayer.Map.Spawn.CFrame * CFrame.Angles(math.pi / -9, 0, 0)
					end
				end)
			end
			
			task.spawn(pcall, function()
				Player.PlayerScripts.Game.EffectsManager_Rewrite.ForceLobbyParent:Invoke(true)
			end)
			
			local thread = pcall(function()
				workspace.CurrentCamera.FieldOfView = ReplicatedStorage.ClientConfig.CurrentFOV.Value + 10
				TweenService:Create(workspace.Camera, TweenInfo.new(.75, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {FieldOfView = ReplicatedStorage.ClientConfig.CurrentFOV.Value}):Play()
				task.wait(2.15)
				local color = Instance.new("ColorCorrectionEffect", game:GetService("Lighting"))
				local tween = TweenService:Create(color, TweenInfo.new(.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, true), {TintColor = Color3.new()})
				tween:Play()
				tween.Completed:Connect(function()
					color:Destroy()
					tween:Destroy()
				end)
				TweenService:Create(workspace.Camera, TweenInfo.new(.5, Enum.EasingStyle.Exponential, Enum.EasingDirection.In), {FieldOfView = ReplicatedStorage.ClientConfig.CurrentFOV.Value - 10}):Play()
				task.wait(0.5)
				resetHeadCframe()
				workspace.CurrentCamera.FieldOfView = ReplicatedStorage.ClientConfig.CurrentFOV.Value + 5
				TweenService:Create(workspace.Camera, TweenInfo.new(1, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {FieldOfView = ReplicatedStorage.ClientConfig.CurrentFOV.Value}):Play()
				if Player.PlayState == "Playing" then
					Player.PlayerScripts.Game.EffectsManager_Rewrite.ForceLobbyParent:Invoke(nil)
				end
			end)
			
			if not thread then
				resetHeadCframe()
			end
		end)
		task.wait(1.7)
	end

	EscapeeAlarm:Play()
	SpawnNotification:Invoke(`⚠️ Distress Call: Rescue {AlertString}! ⚠️`, Color3.new(0.596078, 0.760784, 0.858824), 7, "rescue", "lift")
end)

game.ReplicatedStorage.Game.EndRescue.OnClientEvent:Connect(function(Map)
	CaptureMovement = false
	if GotEscapees == 0 or Survived then return end
	Survived = true

	local EscapeeName = ""
	if GotEscapees == 1 then
		EscapeeName = RescueLib.GetEscapeeSetting(CurrentEscapees[1], "EscapeeName") or "Escapee"
	else
		EscapeeName = #CurrentEscapees .. " Escapees"
	end

	EscapeeSurvive:Play()
	game.ReplicatedStorage.Game.EndRescue:FireServer(GotEscapees, #CurrentEscapees)

	if GameLib.MapTestPlaces[game.PlaceId] then
		SpawnNotification:Invoke(`✔️ Rescued {EscapeeName}!`)
	else
		if Map.Settings.Difficulty.Value <= 2 then
			SpawnNotification:Invoke(`🗒 Rescued {EscapeeName}! +{5 * GotEscapees} EXP 🗒`, Color3.new(0.596078, 0.760784, 0.858824), 7, "rescue")
		elseif Map.Settings.Difficulty.Value > 2 and Map.Settings.Difficulty.Value <= 4 then
			SpawnNotification:Invoke(`💰 Rescued {EscapeeName}! +{15 * GotEscapees} Credits 💰`, Color3.new(0.596078, 0.760784, 0.858824), 7, "rescue")
		elseif Map.Settings.Difficulty.Value > 4 then
			SpawnNotification:Invoke(`💎 Rescued {EscapeeName}! +{3 * GotEscapees} Gems 💎`, Color3.new(0.596078, 0.760784, 0.858824), 7, "rescue")
		end
	end
	game.ReplicatedStorage.Game.EscapeeRescued.Value = true
	GotEscapees = 0
end)

workspace.CurrentCamera.CameraType = "Custom"
workspace.CurrentCamera.CameraSubject = Character.Humanoid
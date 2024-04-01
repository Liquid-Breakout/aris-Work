-- Wallrun mechanic (using TRIA.OS wallrun detection (change if you want))
-- cutymeo
-- i absolutely hate this

local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Player = game.Players.LocalPlayer
local Character = script.Parent
local Humanoid = Character.Humanoid
local HumanoidRootPart = Character.HumanoidRootPart
local GripLookVector = -Vector3.zAxis
local WallJumpSoundURL = "rbxassetid://8766224782"
local WallAttachSoundURL = "rbxassetid://8766059658"
local WallRejectSoundURL = "rbxassetid://11808573283"
local WallRunSound = Instance.new("Sound")
WallRunSound.Name = "WallRunSound"
WallRunSound.SoundId = WallJumpSoundURL
WallRunSound.PlaybackSpeed = 1.25
WallRunSound.Volume = 2.5
WallRunSound.Parent = HumanoidRootPart
local WallGripAnim = script:WaitForChild("WallGripAnim")
local WallGripAnimTrack = nil

local IsWallrun = false
local PartDebounce = {}
local GrabWait = 0

local RaycastParam = RaycastParams.new()
RaycastParam.FilterDescendantsInstances = {Character}
RaycastParam.FilterType = Enum.RaycastFilterType.Exclude

function Wallrun(Wall: BasePart, RaycastResult)
	IsWallrun = true
	
	local StepEvent, InputEvent, DiedEvent
	local Speed = Wall:GetAttribute("Speed") or 10
	
	HumanoidRootPart.Anchored = true
	Humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
	
	local function ExitWallrun(CanDoMomentum)
		StepEvent:Disconnect()
		InputEvent:Disconnect()
		DiedEvent:Disconnect()
		IsWallrun = false
		
		HumanoidRootPart.Anchored = false
		PartDebounce[Wall] = true
		task.delay(.45, function()
			PartDebounce[Wall] = false
		end)
		
		WallGripAnimTrack:Stop()
		WallRunSound.SoundId = if CanDoMomentum then WallJumpSoundURL else WallRejectSoundURL
		WallRunSound:Play()
	
		if CanDoMomentum then
			Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
			local NoMomentum = Wall:GetAttribute("NoMomentum")
			if (NoMomentum ~= nil and NoMomentum) then
				HumanoidRootPart.AssemblyLinearVelocity = Vector3.new(0, Humanoid.JumpPower * 1.1, 0) + (GripLookVector * Humanoid.JumpPower)
				return
			else
				local Momentum = Wall:GetAttribute("Momentum")
				local ZVelocity =  HumanoidRootPart.CFrame.LookVector * Humanoid.JumpPower
				local YVelocity = HumanoidRootPart.CFrame.LookVector + Vector3.new(0, Humanoid.JumpPower * .95, 0)
				local MomentumVelocity = if Momentum then Wall.CFrame.LookVector * Speed * Momentum else Vector3.new()
				HumanoidRootPart.AssemblyLinearVelocity = ZVelocity + YVelocity + MomentumVelocity
			end
		end
	end
	
	local LocationOnWall = Wall.CFrame:ToObjectSpace(CFrame.new(RaycastResult.Position + RaycastResult.Normal, RaycastResult.Position + RaycastResult.Normal * 2))
	StepEvent = RunService.Heartbeat:Connect(function(deltaTime: number)
		LocationOnWall -= Vector3.new(0, 0, Speed * math.min(deltaTime, .25))
		GrabWait = math.max(GrabWait - deltaTime, 0)
		HumanoidRootPart.CFrame = Wall.CFrame * LocationOnWall
		HumanoidRootPart.AssemblyLinearVelocity = Vector3.zero
		GripLookVector = (Wall.CFrame * LocationOnWall).LookVector
		local FoundAnotherRaycast = workspace:Raycast(HumanoidRootPart.CFrame.Position, -Character.HumanoidRootPart.CFrame.LookVector * 2, RaycastParam)
		if FoundAnotherRaycast and (if GrabWait == 0 then not Humanoid.Jump else true) then
			if FoundAnotherRaycast.Instance ~= Wall and FoundAnotherRaycast.Instance:GetAttribute("_action") == "WallRun" then
				StepEvent:Disconnect()
				InputEvent:Disconnect()
				DiedEvent:Disconnect()
				task.delay(.45, function()
					PartDebounce[Wall] = false
				end)
				Wallrun(FoundAnotherRaycast.Instance, FoundAnotherRaycast)
			else
				if (FoundAnotherRaycast.Instance ~= Wall) then
					ExitWallrun()
				end
			end
		else
			ExitWallrun()
		end
	end)
	InputEvent = UserInputService.JumpRequest:Connect(function()
		ExitWallrun(true)
	end)
	DiedEvent = Humanoid.Died:Connect(ExitWallrun)
end

RunService.Heartbeat:Connect(function()
	if not IsWallrun and Humanoid:GetState() == Enum.HumanoidStateType.Freefall then
		local PartRaycast = workspace:Raycast(HumanoidRootPart.CFrame.Position, HumanoidRootPart.CFrame.LookVector * 2, RaycastParam)
		if PartRaycast and PartRaycast.Instance:GetAttribute("_action") == "WallRun" and not PartDebounce[PartRaycast.Instance] then
			WallRunSound.SoundId = WallAttachSoundURL
			WallRunSound:Play()
			WallGripAnimTrack:Play()
			GrabWait = .15
			
			Wallrun(PartRaycast.Instance, PartRaycast)
		end
	end
end)

WallGripAnimTrack = Humanoid:LoadAnimation(WallGripAnim)
WallGripAnimTrack.Priority = Enum.AnimationPriority.Movement
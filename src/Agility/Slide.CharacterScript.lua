-- Slide script, cleaned up
-- cutymeo
-- Note: Script has been modified to remove changes from others
-- (also Fart is by cyriss lol)

local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")

local Player = game.Players.LocalPlayer
local Character = Player.Character or Player.CharacterAdded:Wait()
local Humanoid: Humanoid = Character:WaitForChild("Humanoid")
local RootPart = Character:WaitForChild("HumanoidRootPart")

local IsSliding = script:WaitForChild("IsSliding")
local DoingSliding = script:WaitForChild("DoingSliding")

local DiveAnimation = nil

local BufferQueue = {
	Enabled = false,
	BufferTime = 0,
}

local SlideKeybind = Enum.KeyCode.E

function CanSlide(State)
	State = State or Humanoid:GetState()
	return State ~= Enum.HumanoidStateType.Freefall
		and State ~= Enum.HumanoidStateType.Dead
		and State ~= Enum.HumanoidStateType.RunningNoPhysics
end

function CanDive()
	return Humanoid:GetState() == Enum.HumanoidStateType.Freefall
end

local Fart = false

function CanStopSlide()
	local State = Humanoid:GetState()
	return State ~= Enum.HumanoidStateType.Running
		and State ~= Enum.HumanoidStateType.RunningNoPhysics
		and State ~= Enum.HumanoidStateType.Freefall
		and State ~= Enum.HumanoidStateType.Landed
end

function IsSwimming()
	return RootPart:FindFirstChild("SwimmingVelocity")
end

for i, p in ipairs(script:WaitForChild("DiveParticles"):GetChildren()) do
	local g = p:Clone()
	g.Parent = RootPart
end

task.spawn(function()
	while task.wait() do
		if IsSliding.Value and IsSwimming() then
			IsSliding.Value = false
			Fart = false
		end
	end
end)

local AirDiving = false

game:GetService("RunService").Heartbeat:Connect(function()
	if (AirDiving) then
		if (require(game.ReplicatedStorage.Utils).IsPlayerAbleToJump(Humanoid) or RootPart.Anchored or RootPart:FindFirstChildOfClass("BallSocketConstraint") ~= nil) then
			AirDiving = false
			DiveAnimation:Stop()
		end
	end
end)

task.spawn(function()
	while task.wait() do
		if IsSliding.Value then
			local QueueUseInputEnd = true
			
			if not CanSlide() then
				BufferQueue.Enabled = true

				if CanDive() then
					AirDiving = true
					script.AirDive:Play()
					RootPart.AirDive:Emit(2)
					RootPart.AirDive.Enabled = true
					DiveAnimation:Play()
					RootPart.Velocity = Vector3.new(RootPart.Velocity.X, math.min(-50, RootPart.Velocity.Y), RootPart.Velocity.Z)
				end
				
				while not (CanSlide() or not IsSliding.Value) do
					task.wait()
				end
				
				RootPart.AirDive.Enabled = false
				QueueUseInputEnd = IsSliding.Value
			end
			
			if IsSliding.Value and not Fart then
				Fart = true
				DoingSliding.Value = true

				local SlideTimer = 0.7
				local SlideSparkles = script.SlideParticles:Clone()
				SlideSparkles.Parent = RootPart
				RootPart.Size = Vector3.new(2, 1, 0.5)
				Humanoid.HipHeight = -1.5

				local Sound = script.Slide:Clone()
				Sound.PlaybackSpeed = 1 + math.random(0, 5) / 100
				Sound.Parent = Character
				Sound.PlayOnRemove = true
				Sound:Destroy()

				-- In FE2, HumanoidRootPart was applied a force of -35 Y velocity (aka dive -cuty)
				RootPart.Velocity = Vector3.new(RootPart.Velocity.X, -35, RootPart.Velocity.Z)
				
				local animationTick = tick()
				
				if SlideAnimation then
					SlideAnimation:Play(0.08)
				end

				repeat
					Humanoid:MoveTo(RootPart.Position + RootPart.CFrame.LookVector * 1.2)
					SlideTimer -= task.wait()
				until IsSwimming()
					or SlideTimer <= 0
					or (QueueUseInputEnd and not IsSliding.Value)
					or CanStopSlide()

				DoingSliding.Value = false
				SlideSparkles.Rate = 0
				game.Debris:AddItem(SlideSparkles, 2)
				Humanoid.HipHeight = 0
				RootPart.Size = Vector3.new(2, 2, 1)

				BufferQueue.Enabled = false
				IsSliding.Value = false

				Fart = false
				
				if SlideAnimation then
					SlideAnimation:Stop(math.min(0.1, tick() - animationTick))
				end
				
				continue
			end
			
			IsSliding.Value = false
		end
	end
end)

local cas = game:GetService("ContextActionService")

local result = Enum.ContextActionResult.Sink

function processSliding(_, inputState: Enum.UserInputState, inputObj: InputObject)
	local keyCode = inputObj.KeyCode
	
	if inputState == Enum.UserInputState.Begin then
		IsSliding.Value = not IsSwimming()
	elseif inputState == Enum.UserInputState.End then
		if not IsSwimming() then
			IsSliding.Value = false
		end
	end
end

function bindSliding(keybind)
	cas:UnbindAction("!LB_Slide")
	cas:BindAction(
		"!LB_Slide",
		processSliding,
		false,
		keybind
	)
end

bindSliding(SlideKeybind)

DiveAnimation = script.Parent.Humanoid:LoadAnimation(script.DiveAnim)
DiveAnimation.Priority = Enum.AnimationPriority.Action4

SlideAnimation = script.Parent.Humanoid:LoadAnimation(script.SlideAnim) :: AnimationTrack
SlideAnimation.Priority = Enum.AnimationPriority.Action4
SlideAnimation:AdjustWeight(15)
-- Explosion module.
-- Made by cutymeo.
-- Modified by funrider28 for the fizzle size effect.
-- Modified once again by cutymeo to clean up the messy and fix some bugs.

local wait = task.wait
local spawn = task.spawn

local Explosion = { FilterList = {} }

local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local Shake = require(game.ReplicatedStorage.ShakeLib)
local RandomLua = require(game.ReplicatedStorage.RandomLua).lcg()

local function ExplosionFizzle(Color, Position, Size)
	local fizzle = script.FizzleParticle:Clone()
	fizzle.Position = Position
	fizzle.Attachment0.Position = Vector3.new(0, RandomLua:random(Size / 2, Size * 2) / 50, 0)
	fizzle.Attachment1.Position = Vector3.new(0, -RandomLua:random(Size / 2, Size * 2) / 50, 0)
	fizzle.Trail.Color = ColorSequence.new(Color)
	fizzle.Parent = workspace

	local SteppedEvent = RunService:IsServer() and RunService.Heartbeat or RunService.RenderStepped

	spawn(function()
		local StartPoint = CFrame.new(Position, Position + Vector3.new(RandomLua:random(-180, 180), 0, RandomLua:random(-180, 180)))
		local DestinationPoint = StartPoint * CFrame.new(0, 0, -RandomLua:random(Size / 2, Size * 2))
		local Tick = .5
		local GravityForce = Vector3.new(0, -RandomLua:random(Size * 4, Size * 32), 0)
		
		local StartCF = StartPoint * Vector3.new(0, 0, 0)
		local Velocity = (DestinationPoint.Position - StartCF - GravityForce / 2 * Tick * Tick) / Tick
		fizzle.CFrame = StartPoint

		local Elapsed = 0
		while Elapsed < Tick do
			local AheadTime = Elapsed + 0.01
			local CurrentPosition = GravityForce / 2 * Elapsed ^ 2 + Velocity * Elapsed + StartCF
			local NextPosition = GravityForce / 2 * AheadTime ^ 2 + Velocity * AheadTime + StartCF

			fizzle.CFrame = CFrame.new(CurrentPosition, NextPosition)
			Elapsed += SteppedEvent:Wait()
		end

		wait(.6)
		fizzle:Destroy()
	end)
end

local function CreateExplosion(InnerColor, OuterColor, Position, Size, FizzleRange, DoShake)
	local Model = Instance.new("Model", workspace)
	Debris:AddItem(Model, 1.5)

	local Inner = Instance.new("Part", Model)
	Inner.Name = "Inner"
	Inner.Shape = Enum.PartType.Ball
	Inner.Color = InnerColor or Color3.fromRGB(245, 205, 48)
	Inner.Material = "Neon"
	Inner.Anchored = true
	Inner.CanCollide = false
	Inner.Transparency = 0.3

	local Outer = Instance.new("Part", Model)
	Outer.Name = "Outer"
	Outer.Shape = Enum.PartType.Ball
	Outer.Color = OuterColor or Color3.fromRGB(188, 125, 0)
	Outer.Material = "Neon"
	Outer.Anchored = true
	Outer.Transparency = 0.6
	Outer.CanCollide = false

	Inner.Position = Position
	Outer.Position = Position

	Inner.Size = Vector3.new()
	Outer.Size = Vector3.new()

	spawn(function()
		local StartExplosionTweenInfo = TweenInfo.new(.14, Enum.EasingStyle.Cubic, Enum.EasingDirection.InOut)
		TweenService:Create(Inner, StartExplosionTweenInfo, { Size = Vector3.new(Size / 1.3, Size / 1.3, Size / 1.3) }):Play()
		local WaitTween = TweenService:Create(Outer, StartExplosionTweenInfo, { Size = Vector3.new(Size, Size, Size) })
		WaitTween:Play()
		WaitTween.Completed:Wait()

		local EndExplosionTweenInfo = TweenInfo.new(.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		TweenService:Create(Inner, EndExplosionTweenInfo, { Size = Vector3.new(0, 0, 0) }):Play()
		TweenService:Create(Outer, EndExplosionTweenInfo, { Size = Vector3.new(0, 0, 0) }):Play()
	end)
	
	for i = 1, RandomLua:random(FizzleRange[1], FizzleRange[2]) do
		ExplosionFizzle(Outer.Color, Position, Size)
	end
	if DoShake then
		Shake.Filter(Explosion.FilterList).DoShake(Position, .016, .06, 1.3, Vector3.new(.02, .02, .02))
	end
end

function Explosion.Create(
	InnerColor: Color3?,
	OuterColor: Color3?,
	Position: Vector3,
	Size: number,
	FizzleRange: { any },
	NewThread: boolean?,
	DoShake: boolean?
)
	if NewThread then
		spawn(CreateExplosion, InnerColor, OuterColor, Position, Size, FizzleRange, DoShake)
	else
		CreateExplosion(InnerColor, OuterColor, Position, Size, FizzleRange, DoShake)
	end
end

function Explosion.Filter(FilterTbl: { Player })
	local NewExplosion = table.clone(Explosion)
	NewExplosion.FilterList = FilterTbl
	return NewExplosion
end

return Explosion
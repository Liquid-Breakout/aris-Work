--!strict
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")

local RandomLua = require(game.ReplicatedStorage.RandomLua).mwc()
local ExplosionLib = require(game.ReplicatedStorage.ExplosionLib)
local ShakeLib = require(game.ReplicatedStorage.ShakeLib)

local LightningLib = { Filter = {} }
function LightningLib.Create(
	Origin: Vector3,
	Destination: Vector3,
	Size: number?,
	Color: Color3?,
	FadeTime: number,
	Segments: number?,
	SegmentSpreadValue: number?,
	DoExplosion: boolean?
)
	Size = Size or 1
	Color = Color or Color3.fromRGB(151, 175, 202)

	local LightningHolder = Instance.new("Model")
	LightningHolder.Name = "Lightning"

	local Positions = { Origin, Destination }
	if Segments ~= nil and Segments > 0 then
		SegmentSpreadValue = SegmentSpreadValue or 0.25

		for Segment = 1, Segments do
			local SegmentPositions = { Origin }
			for i = 1, #Positions - 1 do
				table.insert(
					SegmentPositions,
					Positions[i]:Lerp(Positions[i + 1], 0.5)
						+ (
								Vector3.new(
									RandomLua:random(-68, 68),
									RandomLua:random(-45, 5),
									RandomLua:random(-68, 68)
								) / 100
							)
							* ((Positions[i] - Positions[i + 1]).Magnitude * (SegmentSpreadValue :: number))
				)
			end
			table.insert(SegmentPositions, Destination)
			Positions = SegmentPositions
		end
	end

	for i = 1, #Positions - 1 do
		local Part = Instance.new("Part")
		Part.Color = Color :: Color3
		Part.Material = Enum.Material.Neon
		Part.Anchored = true
		Part.CanCollide = false
		Part.CFrame = CFrame.new(Positions[i], Positions[i + 1])
		Part.Position = Positions[i]:Lerp(Positions[i + 1], 0.5)
		Part.Size = Vector3.new(Size, Size, (Positions[i] - Positions[i + 1]).Magnitude)
		Part.Parent = LightningHolder
		TweenService:Create(Part, TweenInfo.new(FadeTime), { Transparency = 1 }):Play()
	end
	LightningHolder.Parent = workspace
	Debris:AddItem(LightningHolder, FadeTime)

	if DoExplosion then
		local ExplosionModule = if #LightningLib.Filter > 0
			then ExplosionLib.Filter(LightningLib.Filter)
			else ExplosionLib
		local ShakeModule = if #LightningLib.Filter > 0
			then ShakeLib.Filter(LightningLib.Filter)
			else ShakeLib
		ExplosionModule.Create(Color, Color, Destination, 12, { 3, 16 }, false)
		ShakeModule.DoShake(Destination, 0, 0.08, 1.4, Vector3.new(0.025, 0.025, 0.025))
	end
end

function LightningLib.FilterExplosion(FilterTbl: { Player })
	local NewLightningLib = table.clone(LightningLib)
	NewLightningLib.Filter = FilterTbl
	return NewLightningLib
end

return LightningLib

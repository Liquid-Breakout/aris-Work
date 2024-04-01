local Utilities = script.Parent:WaitForChild("Utilities")
local PartCache = require(Utilities:WaitForChild("PartCache"))

local Renderer = {
	Bases = {
		Hitbox = nil,
		Segment = nil
	},
	SegmentsCache = nil,
	Settings = {
		InitialPartCacheSize = 1000,
		MaxSegments = 100,
	}
}
Renderer.__index = Renderer

local function PointsDistance(Points: {Vector3})
	local TotalIncrement = 0
	for i = 1, #Points - 1 do
		TotalIncrement = TotalIncrement + ((Points[i] - Points[i + 1]).Magnitude)
	end
	return math.ceil(TotalIncrement * 2)
end

local function CurveIterations(Points: {Vector3}, IsCatmull: boolean): number
	local ZiplineClass = require(script.Parent)
	
	local DistanceDivide = if IsCatmull then 2 else 5
	local MaxIterations = if IsCatmull then Renderer.Settings.MaxSegments * 3 else Renderer.Settings.MaxSegments
	return math.clamp(PointsDistance(Points) / DistanceDivide, 1, MaxIterations)
end

function Renderer.Init(ZiplineVariables: {[any]: any})
	Renderer.Bases.Hitbox = Instance.new("Part")
	Renderer.Bases.Hitbox.Anchored = true
	Renderer.Bases.Hitbox.Name = ZiplineVariables.HitboxName
	Renderer.Bases.Hitbox.Material = Enum.Material.Neon
	Renderer.Bases.Hitbox.CanCollide = false
	Renderer.Bases.Hitbox.Shape = Enum.PartType.Ball
	Renderer.Bases.Hitbox:GetPropertyChangedSignal("Name"):Connect(function()
		Renderer.Bases.Hitbox.Name = ZiplineVariables.HitboxName
	end)

	Renderer.Bases.Segment = Instance.new("Part")
	Renderer.Bases.Segment.Name = ZiplineVariables.RopeStickName
	Renderer.Bases.Segment.Anchored = true
	Renderer.Bases.Segment.CanCollide = false
	Renderer.Bases.Segment.CanQuery = false
	--Renderer.Bases.Segment.CastShadow = false
	Renderer.Bases.Segment:GetPropertyChangedSignal("Name"):Connect(function()
		Renderer.Bases.Segment.Name = ZiplineVariables.RenderRopeModelName
	end)

	Renderer.SegmentsCache = PartCache.new(Renderer.Bases.Segment, Renderer.Settings.InitialPartCacheSize, workspace.PartCacheStorage)
end

function Renderer.attach(ZiplineClass) 
	local self = setmetatable({
		_segmentPoints = table.create(Renderer.Settings.MaxSegments * 3),

		RenderedSegments = table.create(Renderer.Settings.MaxSegments),
		AttachedClass = ZiplineClass
	}, Renderer)
	return self
end

function Renderer:_joinSegmentPoints(): number
	local Iterations = #self.RenderedSegments
	local Settings = self.AttachedClass.previousSettings
	local Points = self._segmentPoints
	
	local SegmentCFrames = table.create(Iterations)
	local TotalSegmentLength = 0
	
	for i = 1, Iterations do
		local StartPoint = Points[i]
		local EndPoint = Points[i + 1]
		
		-- We check if points are enough
		-- If not (only for plugin), we just set to the segment's CFrame for BulkMoveTo
		if StartPoint and EndPoint then
			local SegmentCFrame = CFrame.new((StartPoint + EndPoint) * .5, EndPoint)
			local SegmentLength = (EndPoint - StartPoint).Magnitude

			self.RenderedSegments[i].Size = Vector3.new(Settings.Thickness, Settings.Thickness, SegmentLength)
			self.RenderedSegments[i].Parent = self.AttachedClass.ropeRenderModel

			TotalSegmentLength += SegmentLength
			table.insert(SegmentCFrames, SegmentCFrame)
		else
			table.insert(SegmentCFrames, self.RenderedSegments[i].CFrame)
		end
	end

	workspace:BulkMoveTo(self.RenderedSegments, SegmentCFrames, Enum.BulkMoveMode.FireCFrameChanged)
	return TotalSegmentLength
end

function Renderer:DrawHitbox(HitboxCFrame: CFrame)
	if not self.AttachedClass.hitbox then
		self.AttachedClass.hitbox = Renderer.Bases.Hitbox:Clone()
		self.AttachedClass.hitbox.Parent = self.AttachedClass.ropeRenderModel
		self.AttachedClass.hitbox:GetPropertyChangedSignal("Parent"):Connect(function()
			if self.AttachedClass.ropeRenderModel == nil or self.AttachedClass.ropeRenderModel.Parent == nil or self.AttachedClass.hitbox.Parent == nil then
				return self.AttachedClass.hitbox:Destroy()
			end
			self.AttachedClass.hitbox.Parent = self.AttachedClass.ropeRenderModel
		end)
	end
	
	local Settings = self.AttachedClass.previousSettings
	self.AttachedClass.hitbox.Color = Settings.HitboxColor
	self.AttachedClass.hitbox.Transparency = Settings.HitboxTransparency
	self.AttachedClass.hitbox.Size = 
		if typeof(Settings.HitboxSize) == "Vector3" then Settings.HitboxSize 
		else Vector3.new(Settings.HitboxSize, Settings.HitboxSize, Settings.HitboxSize)
	self.AttachedClass.hitbox.CFrame = HitboxCFrame
end

function Renderer:DrawSegments(Points: {Vector3})
	local IsCatmullCurve = self.AttachedClass.curvePoints.ClassName == "CatmullRomSpline"
	local Settings = self.AttachedClass.previousSettings

	table.clear(self._segmentPoints)
	local Iterations = math.floor(CurveIterations(Points, IsCatmullCurve))
	local Increment = 1 / Iterations
	local Count = 0

	for i = Increment, 1 + Increment, Increment do
		Count += 1
		local Segment = if self.RenderedSegments[Count] and self.RenderedSegments[Count].Parent then self.RenderedSegments[Count] else Renderer.SegmentsCache:GetPart()
		Segment.Material = Settings.Material
		Segment.Color = Settings.Color
		Segment.Transparency = Settings.Transparency

		self.RenderedSegments[Count] = Segment
		table.insert(self._segmentPoints, self.AttachedClass.curvePoints:CalculatePositionAt(i - Increment))
	end
	table.insert(self._segmentPoints, self.AttachedClass.curvePoints:CalculatePositionAt(1))

	-- Return to cache for other ziplines to utilize
	if Count < #self.RenderedSegments then
		local Offset = Count + 1
		for _ = Count + 1, #self.RenderedSegments do
			local Segment = self.RenderedSegments[Offset]
			if not Segment then
				break
			end
			
			if not Renderer.SegmentsCache:IsInCache(Segment) then
				Renderer.SegmentsCache:ReturnPart(Segment)
			end
			table.remove(self.RenderedSegments, Offset)
			Segment = nil
		end
	end
	
	-- Join the parts
	return self:_joinSegmentPoints()
end

return Renderer
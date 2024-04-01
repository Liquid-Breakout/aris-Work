local Marker = {}
Marker.__index = Marker

local TweenService = game:GetService("TweenService")

function Marker.new(Parent: BasePart)
	local RopeMarker = script.RopeMarker:Clone()

	RopeMarker.Adornee = Parent
	RopeMarker.StudsOffset = Vector3.new(0, 0, .15)
	RopeMarker.Parent = Parent
	
	local RotationInfo = TweenInfo.new(1.15, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut, -1)
	TweenService:Create(RopeMarker.MkImg, RotationInfo, {Rotation = 360}):Play()
	TweenService:Create(RopeMarker.MkImg.UIGradient, RotationInfo, {Rotation = -360}):Play()
	
	return setmetatable({
		parent = Parent,
		marker = RopeMarker,
	}, Marker)
end

function Marker:Update(Settings: {[any]: {any}}, Length: number)
	if not self.parent or self.parent.Parent == nil then
		return self:Destroy()
	end

	self.marker.Enabled = Settings.EnableMarker
	if not Settings.EnableMarker then
		return
	end

	self.marker.RideTime.Text = string.format("%0.2fs", Length / Settings.Speed)
	self.marker.Mechanics.Cancel.Visible = Settings.CanCancel
end

function Marker:Destroy()
	if self.marker then
		self.marker:Destroy()
	end
	
	setmetatable(self, nil)
end

return Marker
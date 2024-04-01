debug.setmemorycategory("Zipline Module")

local Zipline = {}

Zipline.Global = {
	-- Public
	Variables = {
		RopeName = "_Rope",
		PointName = "Point",
		SplinePointName = "SplinePoint",
		RopeStickName = "RopeStick",
		HitboxName = "_Hitbox",
		RenderRopeModelName = "RenderedRope"
	},
	LockedFPS = 60,
	Ziplining = false,
	RenderParent = nil,
	Settings = script.Parent.Parent.Settings,
	Sounds = script.Parent.Parent.Sounds,

	-- Private
	_metatables = {},
	_afterTouchConnections = {},
	_loadedAnims = {},
}
Zipline.__index = Zipline

local Debris = game:GetService("Debris")
local RunService = game:GetService("RunService")
local HttpService = game:GetService('HttpService')

-- This module can be obtained here: https://github.com/Sleitnick/RbxUtil
local SignalLib = require(game.ReplicatedStorage.SignalLib)
local ZipliningSignal = SignalLib.new("IsZiplining")

local CurveGenerators = script:WaitForChild("CurveGenerators")
local Bezier = require(CurveGenerators:WaitForChild("Bezier"))
local CatmullRom = require(CurveGenerators:WaitForChild("CatmullRom"))

local Marker = require(script:WaitForChild("Marker"))
local Renderer = require(script:WaitForChild("Renderer"))
Renderer.Init(Zipline.Global.Variables)

local function bindRenderParentFunctions(RenderParent: Folder)
	RenderParent.ChildRemoved:Connect(function(Child)
		if RenderParent.Parent == nil then return end

		local gotZipline = Zipline.fromRenderModel(Child)
		if gotZipline then
			gotZipline:Destroy()
		end
	end)
end

Zipline.Global.RenderParent = workspace:FindFirstChild("CustomRopesRender")
if not Zipline.Global.RenderParent then
	Zipline.Global.RenderParent = Instance.new("Folder")
	Zipline.Global.RenderParent.Name = "CustomRopesRender"
	Zipline.Global.RenderParent.Parent = workspace
end
bindRenderParentFunctions(Zipline.Global.RenderParent)

local SettingsDictionary: {[any]: {any}} = {
	Speed = {"Speed", 40},
	Marker = {"EnableMarker", false},
	IsActive = {"Enabled", true},
	CanCancel = {"CanCancel", false},
	RopeColor = {"Color"},
	RopeThickness = {"Thickness", .25},
	RopeMaterial = {"Material"},
	RopeTransparency = {"Transparency"},
	HitboxColor = {"HitboxColor", Color3.new(0, 1, 0)},
	HitboxSize = {"HitboxSize", 3},
	HitboxTransparency = {"HitboxTransparency", .75},
	JumpOffMomentum = {"JumpOffMomentum", true},
	CurveType = {"CurveType", 1},
	CatmullCurveTension = {"CatmullCurveTension", .5},
	IsStatic = {"Static", false},
	UseDefaultRenderer = {"UseDefaultRenderer", true},
	CastShadow = {"CastShadow", false}
}

local function LoadAnimation(Humanoid: Humanoid, Animation: string): AnimationTrack
	if not Zipline.Global._loadedAnims[Humanoid] then
		Zipline.Global._loadedAnims[Humanoid] = {}
	end
	if not Zipline.Global._loadedAnims[Humanoid][Animation] then
		local AnimationInstance = Instance.new("Animation")
		AnimationInstance.AnimationId = Animation
		Zipline.Global._loadedAnims[Humanoid][Animation] = Humanoid:LoadAnimation(AnimationInstance)
	end

	return Zipline.Global._loadedAnims[Humanoid][Animation]
end

local function Compare2Tables(Table1: {any}?, Table2: {any}?): boolean
	if Table1 == nil or Table2 == nil then return false end
	if #Table1 ~= #Table2 then return false end

	for Name, Value in Table1 do
		if Value ~= Table2[Name] then
			return false
		end
	end

	return true
end

local function Compare2VectorTables(Table1: {Vector3}?, Table2: {Vector3}?): boolean
	if Table1 == nil or Table2 == nil then return false end
	if #Table1 ~= #Table2 then return false end

	for _, Vector in Table1 do
		if not table.find(Table2, Vector) then
			return false
		end
	end

	return true
end

function Zipline.CompileSettings(SettingsFolder: Folder?): {[any]: any}
	local Compiled = {}

	for Value, Table in SettingsDictionary do
		local GotValue: Instance? = if SettingsFolder then SettingsFolder:FindFirstChild(Value) else nil
		if GotValue then
			Compiled[Table[1]] = (GotValue :: any).Value
		else
			Compiled[Table[1]] = if Table[2] ~= nil then Table[2] else "None"
		end
	end

	return Compiled
end

function Zipline.cleanTouchConnections()
	if #Zipline.Global._afterTouchConnections > 0 then
		for i, connection in Zipline.Global._afterTouchConnections do
			connection:Disconnect()
			Zipline.Global._afterTouchConnections[i] = nil
		end
	end
end

function Zipline.new(ropeModel: Model, settingsFolder: Folder?)
	-- Check if a metatable with the ropeModel exists
	for _, metatable in Zipline.Global._metatables do
		if metatable.ropeModel == ropeModel then
			return
		end
	end

	local self = setmetatable({
		settingsFolder = settingsFolder,
		curvePoints = nil,
		ropeModel = ropeModel,
		ropeRenderModel = nil,
		ropePoints = nil,
		splinePoints = nil,
		length = 0,
		hitbox = nil,
		marker = nil,
		isRendering = false,
		previousSettings = nil,
		renderer = nil,
		connections = {}
	}, Zipline)
	self.renderer = Renderer.attach(self)
	
	self.connections[0] = ropeModel.AncestryChanged:Connect(function()
		if not ropeModel:IsDescendantOf(workspace) then
			self:Destroy()
		end
	end)
	
	Zipline.Global._metatables[#Zipline.Global._metatables + 1] = self
	task.defer(Zipline.Global._metatables[#Zipline.Global._metatables].Render, self)
	
	return self
end

function Zipline.isValidName(name: string): boolean
	if type(Zipline.Global.Variables.RopeName) == "table" then
		for _, validName: string in Zipline.Global.Variables.RopeName do
			if string.sub(name, 1, #validName) == validName then
				return true
			end
		end
	elseif type(Zipline.Global.Variables.RopeName) == "string" then
		return string.sub(name, 1, #Zipline.Global.Variables.RopeName) == Zipline.Global.Variables.RopeName
	end

	return false
end

function Zipline.fromHitbox(Hitbox: BasePart?)
	if Hitbox == nil or Hitbox.Name ~= Zipline.Global.Variables.HitboxName then return nil end

	for _, metatable in Zipline.Global._metatables do
		if metatable.hitbox == Hitbox then
			return metatable
		end
	end

	return nil
end

function Zipline.fromRopeModel(RopeModel: Model?)
	if RopeModel == nil or string.sub(RopeModel.Name, 1, #Zipline.Global.Variables.RopeName) ~= Zipline.Global.Variables.RopeName then return nil end

	for _, metatable in Zipline.Global._metatables do
		if metatable.ropeModel == RopeModel then
			return metatable
		end
	end

	return nil
end

function Zipline.fromRenderModel(RenderModel: Model?)
	if RenderModel == nil or RenderModel.Name ~= Zipline.Global.Variables.RenderRopeModelName then
		return nil
	end

	for _, metatable in Zipline.Global._metatables do
		if metatable.ropeRenderModel == RenderModel then
			return metatable
		end
	end

	return nil
end

function Zipline.fromRopePoints(ropePoints: {Vector3}?)
	if ropePoints == nil then
		return nil
	end

	for _, metatable in Zipline.Global._metatables do
		if Compare2VectorTables(metatable.ropePoints, ropePoints) then
			return metatable
		end
	end

	return nil
end

function Zipline:Render()
	if self.ropeModel == nil or self.ropeModel.Parent == nil then
		return self:Destroy()
	end
	if self.isRendering then return end

	self.isRendering = true

	local Settings = Zipline.CompileSettings(self.settingsFolder)
	
	if Settings.UseDefaultRenderer == false then
		return
	end
	
	-- does not affect the first connection, indexed at 0
	while #self.connections > 0 do
		if self.connections[1].Connected then
			self.connections[1]:Disconnect()
		end
		table.remove(self.connections, 1)
	end
	
	if not self.ropeRenderModel or not self.ropeRenderModel.Parent then
		local ropeModel = Instance.new("Model")
		ropeModel.Name = Zipline.Global.Variables.RenderRopeModelName
		ropeModel:GetPropertyChangedSignal("Name"):Connect(function()
			ropeModel.Name = Zipline.Global.Variables.RenderRopeModelName
		end)

		self.ropeRenderModel = ropeModel
	end
	self.ropeRenderModel.Parent = Zipline.Global.RenderParent
	
	local RopeChildren = self.ropeModel:GetChildren()

	local RopePoints = {} --table.create(#RopeChildren)
	local SplinePoints = {} --table.create(2)

	local PointName = Zipline.Global.Variables.PointName
	local SplinePointName = Zipline.Global.Variables.SplinePointName
	local SettingsCurveType = math.clamp(math.floor(Settings.CurveType), 1, 2)
	
	for _, Part: BasePart? in RopeChildren do
		if Part.ClassName == "Part" then
			if string.sub(Part.Name, 1, #PointName) == PointName then
				if Part.Name == `{PointName}1` then
					if Settings.Transparency == "None" then
						Settings.Transparency = 0
					end
					if Settings.Material == "None" then
						Settings.Material = Part.Material
					end
					if Settings.Color == "None" then
						Settings.Color = Part.Color
					end
				end

				Part.Transparency = 1
				table.insert(RopePoints, Part)
			elseif string.sub(Part.Name, 1, #SplinePointName) == SplinePointName then
				Part.Transparency = 1
				table.insert(SplinePoints, Part)
			end
		end
	end
	
	if #RopePoints < 2 then
		return
	end
	if SettingsCurveType == 2 and #SplinePoints < 2 then
		return
	end

	local PointNameLength = #Zipline.Global.Variables.PointName
	table.sort(RopePoints, function(a, b)
		local Point = tonumber(string.sub(a.Name, PointNameLength + 1))
		local Next = tonumber(string.sub(b.Name, PointNameLength + 1))

		if Point and Next then
			return Point < Next
		end

		return false
	end)

	local SplinePointNameLength = #Zipline.Global.Variables.SplinePointName
	table.sort(SplinePoints, function(a, b)
		local Point = tonumber(string.sub(a.Name, SplinePointNameLength + 1))
		local Next = tonumber(string.sub(b.Name, SplinePointNameLength + 1))

		if Point and Next then
			return Point < Next
		end

		return false
	end)

	for i = 1, #RopePoints do
		RopePoints[i] = RopePoints[i].Position
	end
	for i = 1, #SplinePoints do
		SplinePoints[i] = SplinePoints[i].Position
	end

	if (self.previousSettings and (self.previousSettings.CurveType ~= Settings.CurveType or self.previousSettings.CatmullCurveTension ~= Settings.CatmullCurveTension)) or not Compare2VectorTables(self.ropePoints, RopePoints) or not Compare2VectorTables(self.splinePoints, SplinePoints) then
		self.ropePoints = RopePoints
		self.splinePoints = SplinePoints

		if SettingsCurveType == 1 then
			self.curvePoints = Bezier.new(unpack(self.ropePoints))
		else
			local catmullPoints = {self.splinePoints[1]}
			table.move(self.ropePoints, 1, #self.ropePoints, 2, catmullPoints)
			table.insert(catmullPoints, self.splinePoints[2])
			
			self.curvePoints = CatmullRom.new(catmullPoints, Settings.CatmullCurveTension)
		end
	else
		-- Check if both settings and position is the same
		if Compare2Tables(self.previousSettings, Settings) then
			self.isRendering = false
			return
		end
	end
	self.previousSettings = Settings
	
	if self.settingsFolder then
		table.insert(self.connections, self.settingsFolder.ChildAdded:Connect(function()
			self:Render()
		end))
		table.insert(self.connections, self.settingsFolder.ChildRemoved:Connect(function()
			self:Render()
		end))
		for _, Setting: ValueBase? in self.settingsFolder:GetChildren() do
			if Setting:IsA("ValueBase") then
				table.insert(self.connections, Setting:GetPropertyChangedSignal("Value"):Connect(function()
					self:Render()
				end))
			end
		end
	end

	-- Create the hitbox and segment
	self.Hitbox = self.renderer:DrawHitbox(CFrame.new(self.ropePoints[1]))
	self.length = self.renderer:DrawSegments(RopePoints)
	
	-- Create the rope's marker
	if not self.marker then
		self.marker = Marker.new(self.hitbox)
	end
	self.marker:Update(Settings, self.length)

	self.isRendering = false
end

function Zipline:Travel(Character: Model?, Offset: number?)
	if Character == nil then return end
	if Zipline.Global.Ziplining then return end

	local Humanoid: Humanoid? = Character:FindFirstChild("Humanoid")
	local HumanoidRootPart: BasePart? = Character:FindFirstChild("HumanoidRootPart")
	if HumanoidRootPart == nil then return end

	Offset = Offset or 0
	local CancelRide = false
	local function afterTouch(touchedPart: BasePart)
		if Zipline.Global.Ziplining then
			Zipline.cleanTouchConnections()
			return
		end
		
		if Humanoid == nil then return end
		-- print(touchedPart.Name)
		if touchedPart.Name == Zipline.Global.Variables.HitboxName then return end
		if touchedPart.Name ~= Zipline.Global.Variables.RopeStickName then return end

		local renderedRopeModel = touchedPart.Parent
		local gotZipline = Zipline.fromRenderModel(renderedRopeModel)
		if gotZipline ~= nil and self ~= gotZipline then
			local CurrentPos = HumanoidRootPart.Position
			local NearestPos = Vector3.new(math.huge, math.huge, math.huge)
			local MinMagnitude = math.huge

			gotZipline.curvePoints:UpdateLength()
			local GotCurveT = 0
			while GotCurveT <= 1 do
				local BezierPosAt = gotZipline.curvePoints:CalculatePositionRelativeToLength(GotCurveT)
				local CurrentMagnitude = (CurrentPos - BezierPosAt).Magnitude

				if CurrentMagnitude < MinMagnitude then
					MinMagnitude = CurrentMagnitude
				else
					break
				end
				GotCurveT += 1 / Zipline.Global.LockedFPS
			end

			Zipline.cleanTouchConnections()
			gotZipline:Travel(Character, GotCurveT)
		end
	end

	self.curvePoints:UpdateLength() -- Arc-length
	Zipline.Global.Ziplining = true
	Zipline.Global.Sounds.GrabZipline:Play()
	Zipline.Global.Sounds.Zipline.Playing = true
	ZipliningSignal:Fire(Zipline.Global.Ziplining)

	local ZiplineAnimation = LoadAnimation(Humanoid, `rbxassetid://{Zipline.Global.Settings.Animation.Value}`)
	ZiplineAnimation:Play()
	Humanoid:ChangeState(Enum.HumanoidStateType.Physics)

	local SparklePart = Instance.new("Part")
	SparklePart.Name = "ZiplineSparkle"
	SparklePart.CanQuery = false
	SparklePart.CanTouch = false
	SparklePart.Size = Vector3.new(0.2, 0.2, 0.2)
	SparklePart.Anchored = true
	SparklePart.CanCollide = false
	SparklePart.Transparency = 1

	local Sparkle = Instance.new("Sparkles")
	Sparkle.SparkleColor = Color3.fromRGB(255, 179, 0)
	Sparkle.Parent = SparklePart
	SparklePart.Parent = Character

	local bodyPos = Instance.new("BodyPosition")
	bodyPos.Position = HumanoidRootPart.Position
	bodyPos.MaxForce = Vector3.new(10000, 10000, 10000)
	bodyPos.P = 10000
	bodyPos.Parent = HumanoidRootPart

	local previousCF = CFrame.new()
	local rotationDegrees = 0
	local curveT = Offset
	local startRiding = tick()
	
	while curveT <= 1 and task.wait() do
		if Humanoid == nil or HumanoidRootPart == nil or Humanoid.Health <= 0 or CancelRide then break end

		local startMovingTime = tick()

		-- Constantly updating rideTime
		local Settings = Zipline.CompileSettings(self.settingsFolder)
		local rideTime = (1 / Zipline.Global.LockedFPS) / (self.length / Settings.Speed)

		local BezierPosition = self.curvePoints:CalculatePositionRelativeToLength(curveT)
		
		local Retry = 0
		
		while BezierPosition ~= BezierPosition do
			Retry += 0.0000000000000001 -- this is a terrible band-aid
			BezierPosition = self.curvePoints:CalculatePositionRelativeToLength(curveT)
		end
		
		local NextBezierPosition = self.curvePoints:CalculatePositionRelativeToLength(math.clamp(curveT + rideTime, 0, 1))
		
		if BezierPosition == NextBezierPosition then -- avoid 2 same points, causing NaN on orientation
			NextBezierPosition = previousCF.Rotation
		end
		
		local RideCFrame = if typeof(NextBezierPosition) == "Vector3" then 
			CFrame.new(BezierPosition, NextBezierPosition) else
			CFrame.new(BezierPosition) * NextBezierPosition
		local lookVectorVal = math.abs(RideCFrame.LookVector.X) > math.abs(RideCFrame.LookVector.Z) and "X" or "Z"
		local oppositeLookVector = lookVectorVal == "X" and "Z" or "X"

		local rotationDirection = if Zipline.Global.Settings.Rotate.Value then (RideCFrame.LookVector[oppositeLookVector] < 0 and -1 or 1) else 0
		local rotationAngle = math.floor((RideCFrame[lookVectorVal .. "Vector"].Z - previousCF[lookVectorVal .. "Vector"].Z) * 400 + 0.5) * 40

		previousCF = RideCFrame
		rotationDegrees += (math.clamp(rotationDirection * rotationAngle, -68, 68) - rotationDegrees) * .04

		HumanoidRootPart.CFrame = RideCFrame * CFrame.Angles(0, 0, math.rad(rotationDegrees)) * CFrame.new(Zipline.Global.Settings.Offset.Value)
		HumanoidRootPart.AssemblyLinearVelocity = Vector3.new()
		HumanoidRootPart.AssemblyAngularVelocity = Vector3.new()
		bodyPos.Position = HumanoidRootPart.Position
		SparklePart.CFrame = RideCFrame

		local timeTaken = tick() - startMovingTime
		local frameDeltaTime = RunService.RenderStepped:Wait()
		local scaledDeltaTime = (timeTaken + frameDeltaTime) / (1 / Zipline.Global.LockedFPS)

		if curveT <= 1 then
			if curveT < 1 then -- ensure curveT is set to 1 as last ride lerp
				curveT = math.clamp(curveT + rideTime * scaledDeltaTime, 0, 1)
			else
				curveT += rideTime * scaledDeltaTime
			end
		end
		if tick() - startRiding >= .1 and Humanoid.Jump and (Settings.CanCancel or Character:FindFirstChild("IsTripmineTrouble").Value) then
			CancelRide = true
		end
	end

	Zipline.Global.Sounds.DropZipline:Play()
	Zipline.Global.Sounds.Zipline.Playing = false
	
	ZiplineAnimation:Stop()
	Humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
	Debris:AddItem(SparklePart, 0.5)
	bodyPos:Destroy()
	
	Zipline.Global.Ziplining = false
	ZipliningSignal:Fire(Zipline.Global.Ziplining)

	if CancelRide then
		local Settings = Zipline.CompileSettings(self.settingsFolder)

		if Settings.JumpOffMomentum then
			HumanoidRootPart.AssemblyLinearVelocity = HumanoidRootPart.CFrame:Inverse():VectorToObjectSpace(Vector3.new(0, Settings.Speed * 1.22, -Settings.Speed * 1.45))
		else
			HumanoidRootPart.AssemblyLinearVelocity = Vector3.new(0, 50, 0)
		end
		table.insert(Zipline.Global._afterTouchConnections, Character.Head.Touched:Connect(afterTouch))
		table.insert(Zipline.Global._afterTouchConnections, Character.HumanoidRootPart.Touched:Connect(afterTouch))
	end
end

function Zipline:Destroy()
	table.remove(Zipline.Global._metatables, table.find(Zipline.Global._metatables, self))

	if self.ropeRenderModel then
		self.ropeRenderModel:Destroy()
		-- self.ropeRenderModel = nil
	end
	if self.hitbox then
		self.hitbox:Destroy()
		-- self.hitbox = nil
	end
	if self.marker then
		if self.marker.Destroy then
			self.marker:Destroy()
		end
		-- self.marker = nil
	end
	
	for _, connection: RBXScriptConnection in self.connections do
		if connection.Connected then
			connection:Disconnect()
		end
	end

	self = setmetatable(self, nil)
	self = nil
end

workspace.ChildRemoved:Connect(function(Child)
	if Child == Zipline.Global.RenderParent then
		Zipline.Global.RenderParent = Instance.new("Folder")
		Zipline.Global.RenderParent.Name = "CustomRopesRender"
		Zipline.Global.RenderParent.Parent = workspace
		bindRenderParentFunctions(Zipline.Global.RenderParent)

		for _, metatable in Zipline.Global._metatables do
			if metatable.ropeRenderModel then
				metatable.ropeRenderModel:Destroy()
				metatable.ropeRenderModel = nil
			end
			if metatable.hitbox then
				metatable.hitbox:Destroy()
				metatable.hitbox = nil
			end
			metatable:Render()
		end
	end
end)

return Zipline
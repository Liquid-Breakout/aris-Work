--!native
--!nocheck
--// created by bhristt (november 23 2021)
--// updated (january 10 2022)
--// creates a catmull rom spline given a parameter tau (Ï) and 4 points p_(i-1), p_i, p_(i+1), p_(i+2)
--// see more information on the dev-forum: 
--// https://devforum.roblox.com/t/catmull-rom-spline-module-smooth-curve-that-goes-through-control-points/1568205?u=bhristt

-- Modified by cutymeo to fix optimization for zipline module.

--// services
local TweenService = game:GetService("TweenService")


--// catmull-rom spline
local CatmullRomSpline = {}
local CatmullRomSplineFunctions = {}


--// constructor
--// returns a new catmull-rom spline with the given tension and the given control points
--// if not given tension or control points, will default to tension = 0.5 and control points = {}
function CatmullRomSpline.new(controlPoints: {number} | {Vector2} | {Vector3 | BasePart} | {BasePart}?, tension: number?): CatmullRomSplineObject
	local self = {}
	--// main properties
	self.ClassName = "CatmullRomSpline"
	self.Tension = tension or 0.5
	self.Points = {}
	--// length properties
	self.LengthIterations = 1000
	self.LengthIndices = {}
	self.Length = 0
	--// connected splines
	self.ConnectedSplines = {}
	--// holds the connections from the baseparts
	self._connections = {}
	--// add points
	if controlPoints ~= nil then
		for _, point in pairs(controlPoints) do
			CatmullRomSplineFunctions.AddPoint(self, point)
		end
	end
	--// set metatable
	setmetatable(self, {
		__index = CatmullRomSplineFunctions,
		__newindex = function(tbl, index, value)
			error("Cannot add new indices to CatmullRomSplineObject!")
		end,
	})
	return self
end


--// changes the tension of the CatmullRomSpline object
--// calling this method is the correct way to change the tension of the catmull-rom spline
--// without calling this function, the length won't change unless you manually call
--// CatmullRomSpline:UpdateLength() after changing the tension by indexing
--// this only changes the tension of the given CatmullRomSpline object, not the connected splines
function CatmullRomSplineFunctions:ChangeTension(tension: number, updateLength: boolean?)
	--// check if given input is a number
	if type(tension) ~= "number" then
		error("CatmullRomSpline:ChangeTension() expected a number as an input, got " .. tostring(tension) .. "!")
	end
	self.Tension = tension

	if updateLength then
		CatmullRomSplineFunctions.UpdateLength(self)
	end
end



--// changes the tension of the CatmullRomSpline object and its connected splines
--// does the same thing as CatmullRomSpline:ChangeTension(), but calls this function for all connected splines
function CatmullRomSplineFunctions:ChangeAllSplineTensions(tension: number)
	--// check if input is a number
	if type(tension) ~= "number" then
		error("CatmullRomSpline:ChangeAllSplineTensions() expected a number as an input, got " .. tostring(tension) .. "!")
	end
	--// iterate through associated splines and change tension
	local allSplines = CatmullRomSplineFunctions.GetSplines(self)
	for _, spline in pairs(allSplines) do
		spline:ChangeTension(tension)
	end
end


--// adds a point to the CatmullRomSpline object
--// will error if not given a number, vector3 or basepart
--// optional index parameter for including the index where the point will be added in the catmull-rom spline
function CatmullRomSplineFunctions:AddPoint(p: number | Vector2 | Vector3 | BasePart, index: number?, updateLength: boolean?)
	local points = self.Points
	--// checks to see if the type of point is the same as the other points in the CatmullRomSplineObject
	local function checkIfPointsMatch(point)
		local allPoints = CatmullRomSplineFunctions.GetPoints(self)
		for _, v in pairs(allPoints) do
			if typeof(v) ~= typeof(point) then
				return false
			end
		end
		return true
	end
	--// check if there are already 4 points in the spline
	if #points == 4 then
		if typeof(p) == "number" or typeof(p) == "Vector2" or typeof(p) == "Vector3" then
			if checkIfPointsMatch(p) then
				local allSplines = CatmullRomSplineFunctions.GetSplines(self)
				local lastSpline = allSplines[#allSplines]
				local newSpline = CatmullRomSpline.new({lastSpline.Points[2], lastSpline.Points[3], lastSpline.Points[4], p}, lastSpline.Tension)
				CatmullRomSplineFunctions.ConnectSpline(self, newSpline)
			end
		elseif p:IsA("BasePart") then
			if checkIfPointsMatch(p.Position) then
				local allSplines = CatmullRomSplineFunctions.GetSplines(self)
				local lastSpline = allSplines[#allSplines]
				local newSpline = CatmullRomSpline.new({lastSpline.Points[2], lastSpline.Points[3], lastSpline.Points[4], p}, lastSpline.Tension)
				CatmullRomSplineFunctions.ConnectSpline(self, newSpline)
			end
		end
	else
		if typeof(p) == "number" then
			if checkIfPointsMatch(p) then
				table.insert(points, index or #points + 1, p)
			end
		elseif typeof(p) == "Vector2" then
			if checkIfPointsMatch(p) then
				table.insert(points, index or #points + 1, p)
			end
		elseif typeof(p) == "Vector3" then
			if checkIfPointsMatch(p) then
				table.insert(points, index or #points + 1, p)
			end
		elseif p:IsA("BasePart") then
			if checkIfPointsMatch(p.Position) then
				table.insert(points, index or #points + 1, p)
				self._connections[p] = p.Changed:Connect(function(prop)
					if prop == "Position" then
						CatmullRomSplineFunctions.UpdateLength(self)
					end
				end)
			end
		else
			error("Invalid input received for CatmullRomSpline:AddPoint(), expected Vector3 or BasePart, got " .. tostring(p) .. "!")
		end
	end
	--// check if there are enough points to calculate the length of the catmull rom spline
	if #points == 4 and updateLength then
		CatmullRomSplineFunctions.UpdateLength(self)
	end
end


--// removes a point from the CatmullRomSpline object at the given index
--// if index is not given, this will error
function CatmullRomSplineFunctions:RemovePoint(index: number)
	--// check if input is valid
	if type(index) ~= "number" then
		error("CatmullRomSpline:RemovePoint() expected a number as the input, got " .. tostring(index) .. "!")
	end
	--// remove point
	local points = self.Points
	local point = table.remove(points, index)
	if point ~= nil and typeof(point) == "Instance" and point:IsA("BasePart") then
		if self._connections[point] then
			self._connections[point]:Disconnect()
			self._connections[point] = nil
		end
	end
end

function CatmullRomSplineFunctions:ClearAll()
	for _, point in self.Points do
		if typeof(point) == "Instance" and point:IsA("BasePart") then
			if self._connections[point] then
				self._connections[point]:Disconnect()
				self._connections[point] = nil
			end
		end
	end

	table.clear(self.Points)
end


--// returns the points of the catmull-rom spline in number or vector3 form
--// important to use because points given to the CatmullRomSpline object can be
--// numbers, baseparts or Vector3s
function CatmullRomSplineFunctions:GetPoints(): {number} | {Vector2} | {Vector3}
	local points = {}
	--// iterate through points
	for i = 1, #self.Points do
		points[i] = typeof(self.Points[i]) == "Instance" and self.Points[i].Position or self.Points[i]
	end
	--// return points
	return points
end


--// connects a CatmullRomSpline object to the current CatmullRomSpline object
--// if the given spline does not match the type of points in the main spline object,
--// the splines cannot be connected
--// can only connect splines that are connected to eachother via 3 control points
--// example of connected splines: 
--// spline1: {p1, p2, p3, p4} spline2: {p2, p3, p4, p5}
function CatmullRomSplineFunctions:ConnectSpline(spline: CatmullRomSplineObject, updateLength: boolean?)
	--// the points of the given spline
	local points = spline.Points
	--// check if spline shares two beginning control points or two end control points with one of the associated splines
	local allSplines = CatmullRomSplineFunctions.GetSplines(self)
	local associatedSpline = allSplines[#allSplines]
	local associatedPoints = associatedSpline.Points
	--// checks to see if the type of point is the same as the other points in the CatmullRomSplineObject
	local function checkIfPointsMatch(point)
		local allPoints = CatmullRomSplineFunctions.GetPoints(self)
		for _, v in pairs(allPoints) do
			if typeof(v) ~= typeof(point) then
				return false
			end
		end
		return true
	end
	if not checkIfPointsMatch((typeof(associatedPoints[1]) == "number" or typeof(associatedPoints[1]) == "Vector3") and associatedPoints[1] or associatedPoints[1].Position) then
		error("Cannot connect the spline because the splines do not have the same types of points!")
	end
	if associatedPoints[2] == points[1] and associatedPoints[3] == points[2] and associatedPoints[4] == points[3] then
		table.insert(self.ConnectedSplines, spline)
		if updateLength then
			CatmullRomSplineFunctions.UpdateLength(self)
		end
	else
		error("Cannot connect the spline because the splines do not share 3 common points!")
	end
end


--// returns a table with all the splines associated with the current CatmullRomSpline object
--// this table is returned in order
function CatmullRomSplineFunctions:GetSplines(): {CatmullRomSplineObject}
	local allSplines = {self}
	for i = 1, #self.ConnectedSplines do
		table.insert(allSplines, self.ConnectedSplines[i])
	end
	return allSplines
end


--// returns the spline associated with the t value
--// when connecting splines, the t value still ranges from 0 to 1, but the splines remain separated
--// this function must return the spline associated with the t value, and a transformed t value associated with the position t in the entire curve
function CatmullRomSplineFunctions:GetSplineAt(t: number): (CatmullRomSplineObject, number)
	local allSplines = CatmullRomSplineFunctions.GetSplines(self)
	--// given a number x in between a and b, returns a number between 0 and 1 that represents
	--// the percentage location of x in between a and b
	--// (the inverse of linear interpolation)
	local function percentage(x: number, a: number, b: number)
		local s = 1 / (b - a);
		return s * x - s * b + 1;
	end
	--// check to make sure t is a number
	if type(t) ~= "number" then
		error("CatmullRomSpline:GetSplineAt() expected a number as an input, got " .. tostring(t) .. "!")
	end
	--// if the number of splines is 1, return the spline and t
	if #allSplines == 1 then
		return self, t
	end
	--// if the number of splines if more than 1, return a transformed parameter t
	local recip = 1 / #allSplines
	if t <= 0 then
		return self, t * recip
	elseif t >= 1 then
		return allSplines[#allSplines], 1 + (t - 1) * recip
	else
		local splineIndex = math.ceil(t * #allSplines)
		local spline = allSplines[splineIndex]
		return spline, percentage(t, (splineIndex - 1) * recip, (splineIndex) * recip)
	end
end


--// updates the length and length indices of the CatmullRomSpline object
--// only works if there are enough points in the CatmullRomSpline object to calculate position and derivative
--// this function does not need to be called, this will be called automatically as the curve
--// is updated
function CatmullRomSplineFunctions:UpdateLength()
	--// stores the total length of the catmull-rom spline
	local l = 0
	--// important values
	local points = {} do
		local allSplines = CatmullRomSplineFunctions.GetSplines(self)
		for i, spline in pairs(allSplines) do
			local localPoints = CatmullRomSplineFunctions.GetPoints(spline)
			if #localPoints ~= 4 then
				error("Cannot get the length of the CatmullRomSpline object, expected 4 control points for all splines, got " .. tostring(#points) .. " points for spline " .. tostring(i) .. "!")
			end
			for _, localPoint in pairs(localPoints) do
				table.insert(points, localPoint)
			end
		end
	end
	local iterations = self.LengthIterations
	--// start iteration
	local sums = {}
	for i = 1, iterations do
		local dldt = CatmullRomSplineFunctions.CalculateDerivativeAt(self, (i - 1) / (iterations - 1))
		if typeof(dldt) == "number" then
			l += dldt * (1 / iterations)
		else
			l += dldt.Magnitude * (1 / iterations)
		end
		table.insert(sums, {((i - 1) / (iterations - 1)), l, dldt})
	end
	--// return length and sum table
	self.Length, self.LengthIndices = l, sums
end


--// catmull-rom spline functions
--// this function returns a point inside the catmull-rom spline as long as t is a number
--// for expected results, try to keep t withing the interval [0, 1]
function CatmullRomSplineFunctions:CalculatePositionAt(t: number): Vector2 | Vector3 | number
	--// check if t is between 0 and 1
	if type(t) ~= "number" then
		error("The given t value in CatmullRomSpline:CalculatePositionAt() was not between 0 and 1, got " .. tostring(t) .. "!")
	end
	--// make sure the correct the position is being calculated from the correct spline
	self, t = CatmullRomSplineFunctions.GetSplineAt(self, t)
	--// check if the catmull-rom has enough points to calculate a point
	local points = CatmullRomSplineFunctions.GetPoints(self)
	if #points ~= 4 then
		error("The CatmullRomSpline object has an invalid number of points (" .. tostring(#points) .. "), expected 4 points!")
	end
	--// calculate cubic function constants
	local tension = self.Tension
	local c0 = points[2]
	local c1 = tension * (points[3] - points[1])
	local c2 = 3 * (points[3] - points[2]) - tension * (points[4] - points[2]) - 2 * tension * (points[3] - points[1])
	local c3 = -2 * (points[3] - points[2]) + tension * (points[4] - points[2]) + tension * (points[3] - points[1])
	--// calculate point
	local pointV3 = c0 + c1 * t + c2 * t^2 + c3 * t^3
	--// return point
	return pointV3
end


--// this function returns a point inside the catmull-rom spline as long as t is in between 0 and 1
--// unlike CatmullRomSpline:CalculatePositionAt(), this function is relative to the length of the spline
--// and t acts as the percentage of the length of the spline
--// if t is not between 0 and 1, this function will error
function CatmullRomSplineFunctions:CalculatePositionRelativeToLength(t: number, length: number?, lengthIndices): Vector2 | Vector3 | number
	--// check if t is a number between 0 and 1
	if type(t) ~= "number" then
		error("CatmullRomSpline:CalculatePositionRelativeToLength() only accepts a number, got " .. tostring(t) .. "!")
	end
	--// start algorithm to calculate position in catmull-rom spline
	local points = self.Points
	local numPoints = #points
	--// check if there are enough points
	if numPoints == 4 then
		--// important values
		if length then
			rawset(self, "Length", length)
		end
		if lengthIndices then
			rawset(self, "LengthIndices", lengthIndices)
		end
		if not self.Length or #self.LengthIndices == 0 then
			CatmullRomSplineFunctions.UpdateLength(self)
		end

		local length = self.Length
		local lengthIndices = self.LengthIndices
		local iterations = self.LengthIterations
		local points = CatmullRomSplineFunctions.GetPoints(self)
		--// get length of section
		local targetLength = length * t
		--// iterate through sum table
		local nearestParameterIndex, nearestParameter
		for i, orderedPair in ipairs(lengthIndices) do
			if targetLength - orderedPair[2] <= 0 then
				nearestParameterIndex = i
				nearestParameter = orderedPair
				break
			elseif i == #lengthIndices then
				nearestParameterIndex = i
				nearestParameter = orderedPair
				break
			end
		end
		--// calculate percent error
		local p0, p1
		if lengthIndices[nearestParameterIndex - 1] then
			p0 = CatmullRomSplineFunctions.CalculatePositionAt(self, lengthIndices[nearestParameterIndex - 1][1])
			p1 = CatmullRomSplineFunctions.CalculatePositionAt(self, nearestParameter[1])
		else
			p0 = CatmullRomSplineFunctions.CalculatePositionAt(self, nearestParameter[1])
			p1 = CatmullRomSplineFunctions.CalculatePositionAt(self, lengthIndices[nearestParameterIndex + 1][1])
		end
		if typeof(p0) == "number" and typeof(p1) == "number" then
			local percentError = (nearestParameter[2] - targetLength) / (p1 - p0)
			--// return the position at the nearestParameter
			return p0 + (p1 - p0) * (1 - percentError)
		else
			local percentError = (nearestParameter[2] - targetLength) / (p1 - p0).Magnitude
			--// return the position at the nearestParameter
			return p0 + (p1 - p0) * (1 - percentError)
		end
	else
		--// not enough points to get a position
		error("The CatmullRomSpline object has an invalid number of points (" .. tostring(#points) .. "), expected 4 points!")
	end
end


--// this function returns the tangent vector of the catmull-rom spline at the point where t is the given number
--// if t is not between 0 and 1, this function will error
function CatmullRomSplineFunctions:CalculateDerivativeAt(t: number): Vector2 | Vector3 | number
	--// check if t is between 0 and 1
	if type(t) ~= "number" then
		error("The given t value in CatmullRomSpline:CalculateDerivativeAt() was not between 0 and 1, got " .. tostring(t) .. "!")
	end
	--// make sure the correct the derivative is being calculated from the correct spline
	self, t = CatmullRomSplineFunctions.GetSplineAt(self, t)
	--// check if the catmull-rom has enough points to calculate a point
	local points = CatmullRomSplineFunctions.GetPoints(self)
	if #points ~= 4 then
		error("The CatmullRomSpline object has an invalid number of points (" .. tostring(#points) .. "), expected 4 points!")
	end
	--// calculate cubic function constants
	local tension = self.Tension
	local c1 = tension * (points[3] - points[1])
	local c2 = 3 * (points[3] - points[2]) - tension * (points[4] - points[2]) - 2 * tension * (points[3] - points[1])
	local c3 = -2 * (points[3] - points[2]) + tension * (points[4] - points[2]) + tension * (points[3] - points[1])
	--// calculate tangent vector
	local lineV3 = c1 + 2 * c2 * t + 3 * c3 * t^2
	--// return tangent vector
	return lineV3
end


--// this function returns a tangent vector at the given t the catmull-rom spline as long as t is in between 0 and 1
--// unlike CatmullRomSpline:CalculateDerivativeAt(), this function is relative to the length of the spline
--// and t acts as the percentage of the length of the spline
--// if t is not between 0 and 1, this function will error
function CatmullRomSplineFunctions:CalculateDerivativeRelativeToLength(t: number, length: number?, lengthIndices): Vector2 | Vector3 | number
	--// check if t is a number between 0 and 1
	if type(t) ~= "number" then
		error("CatmullRomSpline:CalculateDerivativeRelativeToLength() only accepts a number, got " .. tostring(t) .. "!")
	end
	--// start algorithm to calculate derivative in catmull-rom spline relative to length
	local points = self.Points
	local numPoints = #points
	--// check if there are enough points
	if numPoints == 4 then
		--// important values
		if length then
			rawset(self, "Length", length)
		end
		if lengthIndices then
			rawset(self, "LengthIndices", lengthIndices)
		end
		if not self.Length or #self.LengthIndices == 0 then
			CatmullRomSplineFunctions.UpdateLength(self)
		end

		local length = self.Length
		local lengthIndices = self.LengthIndices
		local iterations = self.LengthIterations
		local points = CatmullRomSplineFunctions.GetPoints(self)
		--// get length of section
		local targetLength = length * t
		--// iterate through sum table
		local nearestParameterIndex, nearestParameter
		for i, orderedPair in ipairs(lengthIndices) do
			if targetLength - orderedPair[2] <= 0 then
				nearestParameterIndex = i
				nearestParameter = orderedPair
				break
			elseif i == #lengthIndices then
				nearestParameterIndex = i
				nearestParameter = orderedPair
				break
			end
		end
		--// calculate percent error
		local d0, d1
		if lengthIndices[nearestParameterIndex - 1] then
			d0 = CatmullRomSplineFunctions.CalculateDerivativeAt(self, lengthIndices[nearestParameterIndex - 1][1])
			d1 = CatmullRomSplineFunctions.CalculateDerivativeAt(self, nearestParameter[1])
		else
			d0 = CatmullRomSplineFunctions.CalculateDerivativeAt(self, nearestParameter[1])
			d1 = CatmullRomSplineFunctions.CalculateDerivativeAt(self, lengthIndices[nearestParameterIndex + 1][1])
		end
		local percentError
		if typeof(d0) == "number" and typeof(d1) == "number" then
			if math.abs(d1 - d0) > 0 then
				percentError = (nearestParameter[2] - targetLength) / (d1 - d0)
			else
				percentError = 0
			end
		else
			if (d1 - d0).Magnitude > 0 then
				percentError = (nearestParameter[2] - targetLength) / (d1 - d0).Magnitude
			else
				percentError = 0
			end
		end
		--// return the position at the nearestParameter
		return d0 + (d1 - d0) * (1 - percentError)
	else
		--// not enough points to get a tangent vector
		error("The CatmullRomSpline object has an invalid number of points (" .. tostring(#points) .. "), expected 4 points!")
	end
end


--// creates a tween for the given instance in the given property
--// this function will error if the given property is not a numerical value of some sort that can be tweened
--// this function has an optional relativeToSplineLength argument that judges whether the tween
--// should tween relative to the Catmull-Rom spline's length, or just as t goes from 0 to 1.
--// the propertyTable should be a table containing strings
--// for example: {"CFrame"} or {"Position"}
function CatmullRomSplineFunctions:CreateTween(instance: Instance, tweenInfo: TweenInfo, propertyTable: {string}, relativeToSplineLength: boolean?): Tween
	--// check if the given instance is really an instance
	if typeof(instance) == "Instance" then
	else
		error("CatmullRomSplineObject:CreateTween() expected an instance as the first input, got " .. tostring(instance) .. "!")
	end
	--// check if the given tween info is really a tween info
	if typeof(tweenInfo) == "TweenInfo" then
	else
		error("CatmullRomSplineObject:CreateTween() expected a TweenInfo object as the second input, got " .. tostring(tweenInfo) .. "!")
	end
	--// check that the properties in the property table are properties of the instance given
	local propertiesFound = true
	for _, propName in pairs(propertyTable) do
		local success, result = pcall(function()
			return instance[propName]
		end)
		if not success or result == nil then
			propertiesFound = false
		end
	end
	if not propertiesFound then
		error("CatmullRomSplineObject:CreateTween() was given properties in the property table that do not belong to the instance!")
	end
	--// start tween
	local numValue = Instance.new("NumberValue")
	local newTween = TweenService:Create(numValue, tweenInfo, {Value = 1})
	local numValueChangedConnection = nil
	--// tween connection 
	newTween.Changed:Connect(function(prop)
		if prop == "PlaybackState" then
			local playbackState = newTween.PlaybackState
			if playbackState == Enum.PlaybackState.Playing then
				numValueChangedConnection = numValue.Changed:Connect(function(t)
					for _, propName in pairs(propertyTable) do
						local pos = relativeToSplineLength and CatmullRomSplineFunctions.CalculatePositionRelativeToLength(self, t) or CatmullRomSplineFunctions.CalculatePositionAt(self, t)
						local derivative = relativeToSplineLength and CatmullRomSplineFunctions.CalculateDerivativeRelativeToLength(self, t) or CatmullRomSplineFunctions.CalculateDerivativeAt(self, t)
						local val = (typeof(pos) == "Vector3" and typeof(derivative) == "Vector3") and CFrame.new(pos, pos + derivative) or pos
						if typeof(instance[propName]) == "number" or typeof(instance[propName] == "Vector2") or typeof(instance[propName]) == "CFrame" then
							instance[propName] = val
						elseif typeof(instance[propName] == "Vector3") then
							instance[propName] = val.Position
						else
							error("CatmullRomSplineObject:CreateTween() could not set the value of the instance property " .. tostring(propName) .. ", not a numerical value!")
						end
					end
				end)
			else
				if numValueChangedConnection ~= nil then
					numValueChangedConnection:Disconnect()
					numValueChangedConnection = nil
				end
			end
		end
	end)
	--// return tween
	return newTween
end


--// return class
export type CatmullRomSplineClass = typeof(CatmullRomSpline)
export type CatmullRomSplineObject = typeof(CatmullRomSpline.new())
return CatmullRomSpline
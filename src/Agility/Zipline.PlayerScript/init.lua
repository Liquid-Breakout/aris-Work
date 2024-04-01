local RunService = game:GetService("RunService")

local Player = game.Players.LocalPlayer
local Character = Player.Character or Player.CharacterAdded:Wait()
local CharacterEvents = {HumanoidRootPart = {}, Humanoid = {}}

local function ApplyCharacterEvents()
	for Property, EventTable in CharacterEvents do
		local ToApply = Character

		if Property ~= "" then
			ToApply = Character:WaitForChild(Property, 3)
			if not ToApply then return end
		end

		for _, currentEvent in EventTable do
			ToApply[currentEvent.Event]:Connect(currentEvent.Function)
		end
	end
end

Player.CharacterAdded:Connect(function(AddedChar)
	Character = AddedChar
	ApplyCharacterEvents()
end)

local Zipline = require(script:WaitForChild("Modules").Zipline)

-- Find ziplines
for _, Descendant in workspace:GetDescendants() do
	if Descendant:IsA("Model") and Zipline.isValidName(Descendant.Name) then
		if Zipline.fromRopeModel(Descendant) then return end

		-- Create new ZiplineObject
		Zipline.new(Descendant, Descendant:WaitForChild("Settings", 3))
	end
end

-- Check if new zipline is added
workspace.DescendantAdded:Connect(function(Descendant)
	if Descendant:IsA("Model") and Zipline.isValidName(Descendant.Name) then
		-- Create new ZiplineObject
		Zipline.new(Descendant, Descendant:WaitForChild("Settings", 3))
	end
end)

-- These two connections waste computational power and i HATE it!!!!!!!!!!

-- Check if a zipline is deleted
--[[workspace.DescendantRemoving:Connect(function(Descendant)
	if Descendant:IsA("Model") and Zipline.isValidName(Descendant.Name) then
		local ZiplineObject = Zipline.fromRopeModel(Descendant)
		if ZiplineObject then
			ZiplineObject:Destroy()
		end
	end
end)]]

-- A loop to render all ziplines
--[[RunService.Heartbeat:Connect(function()
	for _, metatable in pairs(Zipline.Global._metatables) do
		if metatable == nil then continue end
		if metatable.isRendering then continue end

		metatable:Render()
	end
end)]]

-- Zipline hitbox detect
table.insert(CharacterEvents.HumanoidRootPart, {
	Event = "Touched",
	Function = function(touchedPart: BasePart)
		if touchedPart.Name == Zipline.Global.Variables.HitboxName then
			local gotZipline = Zipline.fromHitbox(touchedPart)
			if gotZipline and not Zipline.Global.Ziplining then
				gotZipline:Travel(Character)
			end
		end
	end,
})
table.insert(CharacterEvents.Humanoid, {
	Event = "StateChanged",
	Function = function(_, newState: Enum.HumanoidStateType)
		if newState == Enum.HumanoidStateType.Landed then
			Zipline.cleanTouchConnections()
		end
	end,
})

ApplyCharacterEvents()

script:WaitForChild("IsZiplining").OnInvoke = function()
	return Zipline.Global.Ziplining
end
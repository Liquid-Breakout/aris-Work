local InsertService = game:GetService("InsertService")
local GameLib = require(game.ReplicatedStorage.GameLib)

local IsTestingPlace = game.PlaceId == 6711772071
local IsMapTestPlace = GameLib.MapTestPlaces[game.PlaceId]

local LogHolder = require(script.Parent.LogHolder)
local InstallMap = script.Parent.MapInstaller.InstallMap
local UninstallMap = script.Parent.MapInstaller.UninstallMap

local MapsAssetId = {
	Main = {
	},
	Testing = { -- USE THIS TO INCLUDE NEW MAPLIST MODELS
	},
	MapTest = {}
}

local FirstTime = true

local function Install(map)
	local success, messages = InstallMap:Invoke(map, "Normal", true)
	local log = LogHolder.new()
	log:BulkLog(messages)
	log:SendToServerLog()
end

local function CreateMapIdentifier(MapModel)
	-- Check for timelines
	if not MapModel:FindFirstChild("Settings") then
		return game:GetService("HttpService"):GenerateGUID(false)
	end
	local Attributes = MapModel.Settings:GetAttributes()
	if MapModel.Settings:FindFirstChild("MapName") and MapModel.Settings:FindFirstChild("Creator") then
		return `{MapModel.Settings.MapName.Value}-{MapModel.Settings.Creator.Value}`
	elseif MapModel:FindFirstChild("Timelines") and Attributes.MapName and Attributes.Creator then
		return `{Attributes.MapName or "Unknown Name"}-{Attributes.Creator or "Unknown Creator"}`
	else
		return "Unknown Name-Unknown Creator"
	end
end

local function GetLinkedInfoWithMap(MapName, Creator)
	for _, MapInfo in game.ReplicatedStorage.InstalledMapInfo:GetChildren() do
		if MapInfo.LinkedMap.Value.Settings.MapName.Value == MapName and MapInfo.LinkedMap.Value.Settings.Creator.Value == Creator then
			return MapInfo
		end
	end

	return nil
end

function Uninstall(mapInfo)
	if game.ReplicatedStorage.Game.CurrentMap.Value and GetLinkedInfoWithMap(game.ReplicatedStorage.Game.CurrentMap.Value) then
		game.ReplicatedStorage.Game.CurrentMap.Changed:Wait()
	end

	UninstallMap:Invoke(mapInfo.Name, true)
end

function ReloadMaps()
	print("[Dynamic Maps Loader]: Reloading Maps")

	local ModelsMap = {}
	local LoadedMaps = {}
	if IsMapTestPlace then
		for _, ID in MapsAssetId.MapTest do
			local LoadSuccess, LoadedMapsContainer = pcall(function()
				return InsertService:LoadAsset(ID):GetChildren()[1]
			end)
			if LoadSuccess then
				print("[Dynamic Maps Loader]: Loaded ID " .. ID .. " (Map Test Map List) successfully; adding.")
				for _, Map in LoadedMapsContainer:GetChildren() do
					local MapIdentifer = CreateMapIdentifier(Map)
					ModelsMap[MapIdentifer] = Map

					local RelatedMapInfo = GetLinkedInfoWithMap(Map.Settings.MapName.Value, Map.Settings.Creator.Value)
					if RelatedMapInfo then
						if RelatedMapInfo.InstallType.Value == "Local" or RelatedMapInfo.InstallType.Value == "Special" then
							warn("[Dynamic Maps Loader]: Map Identifier " .. MapIdentifer .. " is installed as \"" ..  RelatedMapInfo.InstallType.Value .. "\"; skipping.")
							ModelsMap[MapIdentifer] = nil
							table.insert(LoadedMaps, MapIdentifer)
							continue
						end
						RelatedMapInfo.LinkedMap.Value:Destroy()
						RelatedMapInfo:Destroy()
					end
					Install(Map)
					ModelsMap[MapIdentifer] = nil
					table.insert(LoadedMaps, MapIdentifer)
				end
			else
				warn("[Dynamic Maps Loader]: ID " .. ID .. " (Map Test Map List) loaded failed: " .. LoadedMapsContainer)
			end

			task.wait()
		end
	else
		for _, ID in MapsAssetId.Main do
			local LoadSuccess, LoadedMapsContainer = pcall(function()
				return InsertService:LoadAsset(ID):GetChildren()[1]
			end)
			if LoadSuccess then
				print("[Dynamic Maps Loader]: Loaded ID " .. ID .. " (Main Map List) successfully; adding.")
				for _, Map in LoadedMapsContainer:GetChildren() do
					ModelsMap[CreateMapIdentifier(Map)] = Map
				end
			else
				warn("[Dynamic Maps Loader]: ID " .. ID .. " (Main Map List) loaded failed: " .. LoadedMapsContainer)
			end
		end
		
		for i, Map in ModelsMap do
			if Map == nil or Map.Parent == game.ServerStorage.InstalledMaps then
				continue
			end

			local IsTimeline = Map:FindFirstChild("Timelines") ~= nil
			local MapName = if IsTimeline then Map.Settings:GetAttribute("MapName") else Map.Settings.MapName.Value
			local CreatorValue = if IsTimeline then Map.Settings:GetAttribute("Creator") else Map.Settings.Creator.Value
			local RelatedMapInfo = GetLinkedInfoWithMap(MapName, CreatorValue)
			if RelatedMapInfo then
				if RelatedMapInfo.InstallType.Value == "Local" or RelatedMapInfo.InstallType.Value == "Special" then
					warn("[Dynamic Maps Loader]: Map Identifier " .. i .. " is installed as \"" ..  RelatedMapInfo.InstallType.Value .. "\"; skipping.")
					ModelsMap[i] = nil
					table.insert(LoadedMaps, i)
					continue
				end
				RelatedMapInfo.LinkedMap.Value:Destroy()
				RelatedMapInfo:Destroy()
			end
			Install(Map)
			ModelsMap[i] = nil
			table.insert(LoadedMaps, i)
			task.wait()
		end
		
		if IsTestingPlace then
			for _, ID in MapsAssetId.Testing do
				local LoadSuccess, LoadedMapsContainer = pcall(function()
					return InsertService:LoadAsset(ID):GetChildren()[1]
				end)
				if LoadSuccess then
					print("[Dynamic Maps Loader]: Loaded ID " .. ID .. " (Testing Map List) successfully; adding.")
					for _, Map in LoadedMapsContainer:GetChildren() do
						ModelsMap[CreateMapIdentifier(Map)] = Map
					end
				else
					warn("[Dynamic Maps Loader]: ID " .. ID .. " (Testing Map List) loaded failed: " .. LoadedMapsContainer)
				end
			end

			for i, Map in ModelsMap do
				if Map == nil or Map.Parent == game.ServerStorage.InstalledMaps then
					continue
				end

				local IsTimeline = Map:FindFirstChild("Timelines") ~= nil
				local MapName = if IsTimeline then Map.Settings:GetAttribute("MapName") else Map.Settings.MapName.Value
				local CreatorValue = if IsTimeline then Map.Settings:GetAttribute("Creator") else Map.Settings.Creator.Value
				local RelatedMapInfo = GetLinkedInfoWithMap(MapName, CreatorValue)
				if RelatedMapInfo then
					if RelatedMapInfo.InstallType.Value == "Local" or RelatedMapInfo.InstallType.Value == "Special" then
						warn("[Dynamic Maps Loader]: Map Identifier " .. i .. " is installed as \"" ..  RelatedMapInfo.InstallType.Value .. "\"; skipping.")
						ModelsMap[i] = nil
						table.insert(LoadedMaps, i)
						continue
					end
					RelatedMapInfo.LinkedMap.Value:Destroy()
					RelatedMapInfo:Destroy()
				end
				Install(Map)
				ModelsMap[i] = nil
				table.insert(LoadedMaps, i)
				task.wait()
			end
		end
	end

	-- Remove maps
	for _, MapInfo in game.ReplicatedStorage.InstalledMapInfo:GetChildren() do
		local MapIdentifer = CreateMapIdentifier(MapInfo.LinkedMap.Value)
		if not table.find(LoadedMaps, MapIdentifer) then
			-- Extra check, just in case
			if MapInfo.InstallType.Value == "Local" or MapInfo.InstallType.Value == "Special" then
				warn("[Dynamic Maps Loader]: Map Identifier " .. MapIdentifer .. " is installed as \"" ..  MapInfo.InstallType.Value .. "\"; skipping.")
				continue
			end
			print("[Dynamic Maps Loader]: Removing map with identifier: " .. MapIdentifer)
			task.spawn(Uninstall, MapInfo)
		end
	end

	if FirstTime then
		FirstTime = false
		game.ReplicatedStorage.Remote.Alert:FireAllClients("All maps have been loaded.")
	end
end

game.Players.PlayerAdded:Connect(function(Player)
	if GameLib.HasControlPrivileges(Player) then
		Player.Chatted:Connect(function(newMessage)
			if newMessage == "/reloadmaps" then
				game.ReplicatedStorage.Remote.Alert:FireAllClients("Received request to manually reload all maps.")
				ReloadMaps()
			end
		end)
	end
end)

script.Reload.OnInvoke = ReloadMaps

if game:GetService("RunService"):IsStudio() then
	warn("[Dynamic Maps Loader] This game is running in Roblox Studio. Cannot run automatically.")
	return
end

task.wait(2)
while true do
	ReloadMaps()
	task.wait(60 * 60 * 30)
end
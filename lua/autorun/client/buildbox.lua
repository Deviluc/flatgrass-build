buildBoxes = {}
startPos1 = Vector(-15000,-15000, -12800)
startPos2 = Vector(-15000, 12000, -12800)


function mulVec(vec, num)
	return Vector(vec.x * num, vec.y *num, vec.z * num)
end

function addVec(vec1, vec2)
	return Vector(vec1.x + vec2.x, vec1.y + vec2.y, vec1.z + vec2.z)
end

function subVec(vec1, vec2)
	return Vector(vec1.x - vec2.x, vec1.y - vec2.y, vec1.z - vec2.z)
end


function findPlayerByName(name)
	if name then
		lowerName = string.lower(name)

		for k, v in pairs(player.GetAll()) do
			if string.find(string.lower(v:Name()), lowerName, 1, true) then
				return v
			end
		end
	end

	return nil
end




function createBuildBox(ply, size, minPos, color)
	local box = {}
	
	box.Player = ply
	box.AllowedPlayers = {ply}
	
	local halfSize = mulVec(size, 0.5)
	
	
	box.Pos = addVec(minPos, halfSize)
	box.Size = size
	box.Min = minPos
	box.Max = addVec(minPos, size)
	
	function box.CheckEntities()
		if SERVER then
			local Ents = ents.FindInBox(box.Min, box.Max)
			
			for k, v in pairs(Ents) do
				owner = v:CPPIGetOwner()
				
				if owner and not v:IsPlayer() and not v:GetParent():IsPlayer() and v:GetModel() and v:GetClass() != "env_spritetrail" then
					if not table.HasValue(box.AllowedPlayers, owner)  then
						v:Remove()
					end
				end
			end
		end
		
	end
	
	function box.IsInBox(vec)
		if vec then
			return vec:WithinAABox(box.Min, box.Max)
		end
		
		return false
	end

	function box.CheckAllowedPlayers()

		index = 1

		for k, v in pairs(box.AllowedPlayers) do
			if not v then
				table.remove(box.AllowedPlayers, index)
			end

			index = index + 1
		end
	end
	
	function box.RefreshPos()
		box.Pos = addVec(box.Min, mulVec(subVec(box.Max, box.Min), 0.5))
		box.Size = subVec(box.Max, box.Min)
	end

	function box.ToString()
		return box.Size.x .. "," .. box.Size.y .. "," .. box.Size.z .. "|" .. box.Min.x .. "," .. box.Min.y .. "," .. box.Min.z .. "|#"
	end
	
	return box
end

local function printBox(box)
	print(box )
	print("Min", box.Min)
	print("Max", box.Max)
	print("Player", box.Player)
	print("Pos", box.Pos)
end

function getBoxes() 
	return buildBoxes
end

function setBoxes(boxes)
	if boxes then
		buildBoxes = boxes
		
		for k, v in pairs(buildBoxes) do
			printBox(v)
		end
		
		syncFromClient()	
	end
end

function drawAllBoxes()
	if CLIENT then

		ply = LocalPlayer()

		cam.Start3D(pos, EyeAngles())

		for k, v in pairs(buildBoxes) do
			color = Color(200, 0, 0, 255)

				if v.Player == LocalPlayer() then
					color = Color(0, 200, 0, 255)
				elseif v.AllowedPlayers then
					if table.HasValue(v.AllowedPlayers, ply) then
						color = Color(0, 200, 0, 255)
					end
				end

			render.DepthRange(0.0, 1.0)

			render.DrawWireframeBox(v.Pos, Angle(0, 0, 0), subVec(v.Min, v.Pos), subVec(v.Max, v.Pos), color, true)
		end	

		cam.End3D()
	end

	
	return false
end

function showHelpMenu()
	if CLIENT then
		local frame = vgui.Create( "DFrame" )
		frame:SetSize( 780, 680 )
		frame:SetTitle( "Buildbox Help" )
		frame:SetVisible( true )
		frame:SetDraggable( true )
		frame:Center()

		local checkbox = vgui.Create("DCheckBox", frame)
		checkbox:SetPos(5, 640)
		checkbox:SetValue(tonumber(LocalPlayer():GetPData("showHelpAgain")))

		function checkbox:OnChange(state)
			if state then
				LocalPlayer():SetPData("showHelpAgain", "1")
			else
				LocalPlayer():SetPData("showHelpAgain", "0")
			end
		end

		local checkboxLabel = vgui.Create("DLabel", frame)
		checkboxLabel:SetPos(30, 640)
		checkboxLabel:SetText("Show this menu again on next spawn in server")
		checkboxLabel:SetSize(300, 25)

		local html = vgui.Create( "HTML" , frame )
		html:SetSize(770, 600)
		html:SetPos(5, 30)
		html:OpenURL("http://deviluc.bplaced.net/gmod/helpmenu.html")
		frame:SetBackgroundBlur(true)
		frame:SetSizable(true)
		frame:MakePopup()

	end
end

function createBuildBoxMenu()

	if CLIENT then
		if not LocalPlayer():IsAdmin() then
			return false
		end

		local Frame = vgui.Create( "DFrame" )

		local Size = {x = 600, y = 375}
		local Pos = {x = (ScrW() * 0.5) - (Size.x * 0.5), y = (ScrH() * 0.5) - (Size.y * 0.5)}
		local LineStart = {x = 5, y = 30}
		local LineWidth = 25
		local LineCounter = 0


		Frame:SetSize(Size.x, Size.y)
		Frame:SetPos(Pos.x, Pos.y)
		Frame:SetTitle("BuildBox-Menu")
		Frame:MakePopup()

		local BoxList = vgui.Create( "DListView" , Frame)
		BoxList:SetPos(LineStart.x, LineStart.y + LineCounter * LineWidth)
		BoxList:SetSize(Size.x - (LineStart.x * 2), LineWidth * 12)
		LineCounter = 12.5

		BoxList:SetMultiSelect( false )
		BoxList:AddColumn( "ID" )
		BoxList:AddColumn( "X_min" )
		BoxList:AddColumn( "Y_min" )
		BoxList:AddColumn( "Z_min" )
		BoxList:AddColumn( "X_max" )
		BoxList:AddColumn( "Y_max" )
		BoxList:AddColumn( "Z_max" )


		local function refreshList()
			
			BoxList:Clear()
			
			for I = 1, #buildBoxes, 1 do
				local box = buildBoxes[I]
				BoxList:AddLine(I, box.Min.x, box.Min.y, box.Min.z, box.Max.x, box.Max.y, box.Max.z)
			end
		end

		local function createBoxMenu(ID)

			local Box = buildBoxes[ID]

			if ID > #buildBoxes then
				Box = createBuildBox(nil, Vector(0, 0, 0), Vector(0, 0, 0))
			end
						

			local BoxFrame = vgui.Create( "DFrame" )
			local Pos = {x = (ScrW() * 0.5) - (Size.x * 0.5), y = (ScrH() * 0.5) - (Size.y * 0.5)}
			local Size = {x = 200, y = 260}
			local LineStart = {x = 5, y = 30}
			local LineWidth = 25
			local LineCounter = 0
			
			BoxFrame:SetSize(Size.x, Size.y)
			BoxFrame:SetPos(Pos.x, Pos.y)
			BoxFrame:SetTitle("Box_" .. ID)
			BoxFrame:MakePopup()
			
			local function createLine(text, number, isLeft, allowInput, isNumber)
				
				
				local XStart = LineStart.x
				
				if !isLeft then
					XStart = LineStart.x + (Size.x / 2)
				end
				
				local LineLabel = vgui.Create("DLabel", BoxFrame)
				LineLabel:SetPos(XStart, LineStart.y + (LineCounter * LineWidth))
				LineLabel:SetSize(Size.x / 2.1, LineWidth)
				LineLabel:SetText(text)
				
				local LineNumber = vgui.Create("DTextEntry", BoxFrame)
				LineNumber:SetPos(XStart + (Size.x / 2.1), LineStart.y + (LineCounter * LineWidth))
				LineNumber:SetSize(Size.x / 2.1, LineWidth)
				LineNumber:SetText(number)
				LineNumber:SetEditable(allowInput)
				
				LineNumber:SetNumeric(isNumber)
				
				LineCounter = LineCounter + 1

				return {Label = LineLabel, Input = LineNumber}
				
			end
			
			local function readTextEntry(textEntry)
				local number = textEntry:GetFloat()
				
				if not number then
					return 0
				end
				
				return number
				
			end
			
			
			local idField = createLine("ID", ID, true, false, true).Input
			local xMinField = createLine("X-Minimum", Box.Min.x, true, true, true).Input
			local yMinField = createLine("Y-Minimum", Box.Min.y, true, true, true).Input
			local zMinField = createLine("Z-Minimum", Box.Min.z, true, true, true).Input
			local xMaxField = createLine("X-Maximum", Box.Max.x, true, true, true).Input
			local yMaxField = createLine("Y-Maximum", Box.Max.y, true, true, true).Input
			local zMaxField = createLine("Z-Maximum", Box.Max.z, true, true, true).Input
			
			if IsValid(Box.Player) then
				createLine("Player", Box.Player:Name(), true, false, false)
			end
			
			LineCounter = LineCounter + 1
			
			local saveButton = vgui.Create("DButton", BoxFrame)
			saveButton:SetText("SAVE")
			saveButton:SetSize(Size.x / 2.1, LineWidth)
			saveButton:SetPos(LineStart.x, LineStart.y + (LineCounter * LineWidth))
			saveButton.DoClick = function()
				
				Box.Min = Vector(readTextEntry(xMinField), readTextEntry(yMinField), readTextEntry(zMinField))
				Box.Max = Vector(readTextEntry(xMaxField), readTextEntry(yMaxField), readTextEntry(zMaxField))
				
				//PrintTable(Box)
				//print("Table: " .. Box.Min.x)
				buildBoxes[ID] = Box
				BoxFrame:Close()
				syncFromClient()
				timer.Create("refreshList", 0.8, 1, refreshList)
			end
			
			local cancelButton = vgui.Create("DButton", BoxFrame)
			cancelButton:SetText("CANCEL")
			cancelButton:SetSize(Size.x / 2.1, LineWidth)
			cancelButton:SetPos(LineStart.x + (Size.x / 2.1), LineStart.y + (LineCounter * LineWidth))
			cancelButton.DoClick = function()
				BoxFrame:Close()
				refreshList()
			end
			
			LineCounter = LineCounter + 1
			
			
		end


		function BoxList:DoDoubleClick(lineID, line)
			createBoxMenu(lineID)
		end

		local addBoxButton = vgui.Create("DButton", Frame)
		addBoxButton:SetText("Add Box")
		addBoxButton:SetSize(75, LineWidth)
		addBoxButton:SetPos(LineStart.x, LineStart.y + LineCounter * LineWidth)
		addBoxButton.DoClick = function()
			createBoxMenu(#buildBoxes + 1)
		end

		local removeBoxButton = vgui.Create("DButton", Frame)
		removeBoxButton:SetText("Remove Box")
		removeBoxButton:SetSize(75, LineWidth)
		removeBoxButton:SetPos(LineStart.x + 80, LineStart.y + LineCounter * LineWidth)
		removeBoxButton.DoClick = function()
			deleteBoxFromClient(BoxList:GetSelectedLine())
			timer.Create("refreshList", 0.8, 1, refreshList)
		end
		
		local loadMapDefaultsButton = vgui.Create("DButton", Frame)
		loadMapDefaultsButton:SetText("Load Map Default")
		loadMapDefaultsButton:SetSize(125, LineWidth)
		loadMapDefaultsButton:SetPos(LineStart.x + 160, LineStart.y + LineCounter * LineWidth)
		loadMapDefaultsButton.DoClick = function()
			net.Start("loadDefault")
			net.SendToServer()
			timer.Create("refreshList", 0.8, 1, refreshList)
		end
		
		local saveMapDefaultsButton = vgui.Create("DButton", Frame)
		saveMapDefaultsButton:SetText("Save as Map Default")
		saveMapDefaultsButton:SetSize(125, LineWidth)
		saveMapDefaultsButton:SetPos(LineStart.x + 290, LineStart.y + LineCounter * LineWidth)
		saveMapDefaultsButton.DoClick = function()
			net.Start("saveDefault")
			net.SendToServer()
			timer.Create("refreshList", 0.8, 1, refreshList)
		end



		refreshList()
	end
end


function canSpawn(ply)
	local eyeTrace = ply:GetEyeTrace()
	
	if eyeTrace.Hit then
		local spawnPos = eyeTrace.HitPos
		
		for k, v in pairs(buildBoxes) do
			if spawnPos:WithinAABox(v.Min, v.Max) then
				for k, v in pairs(v.AllowedPlayers) do
					if v == ply then
						return true
					end
				end
				
				return false
			end
		end
	else
		return false
	end
	
	return true
end

function canMove(ply, moveData)
	local speed = 0.0005 * FrameTime()
	local nextPos = addVec(ply:GetPos(), mulVec(moveData:GetVelocity(), speed))
	
	for k, v in pairs(buildBoxes) do
		
		if nextPos:WithinAABox(v.Min, v.Max) then
			for kp, vp in pairs(v.AllowedPlayers) do
				if vp == ply then
					return false
				end
			end
			
			
			moveData:SetOrigin(ply:GetPos())
			moveData:SetVelocity(mulVec(moveData:GetVelocity(), -2))
			return true
		end
	end
	
	return false
end

function playerDisconnected(ply)
	removeBuildBox(ply)
	syncFromServer()
end

function playerSay(ply, text, team)
	
	if ply then
		
		args = string.Explode(" ", text, false)

		if string.lower(text) == "!getbox" then
			giveBuildBox(ply)
			syncFromServer()
			return false
		end

		if string.lower(text) == "!removebox" then
			removeBuildBox(ply)
			syncFromServer()
			return false
		end

		if string.lower(args[1]) == "!addplayer" then
			plyToAdd = findPlayerByName(args[2])

			allowPlayerToBox(ply, plyToAdd)
			syncFromServer()
			return false
		end

		if string.lower(args[1]) == "!removeplayer" then
			plyToRemove = findPlayerByName(args[2])

			removePlayerFromBox(ply, plyToRemove)
			syncFromServer()
			return false
		end
		
		if string.lower(args[1]) == "!spawninbox" then
			if ply:GetNWBool("SpawnInBox", false) then
				ply:SetNWBool("SpawnInBox", false)
				ply:ChatPrint("You will no longer spawn in your buildbox")
			else
				ply:SetNWBool("SpawnInBox", true)
				ply:ChatPrint("You will now spawn in your buildbox")
			end
			
			return false
		end

		if string.lower(args[1]) == "!boxmenu" then
			if ply:IsAdmin() then
				ply:ConCommand("createBuildBoxMenu")
			else
				print(ply, "is not admin!")
			end
			
			return false
		end

		if string.lower(args[1]) == "!boxhelp" then
			ply:ConCommand("buildBoxHelp")

			return false
		end


	end

	return text
end

function canDamage(target, dmgInfo)
	
	for k, v in pairs(buildBoxes) do

		if v.IsInBox(target:GetPos()) then
			attacker = dmgInfo:GetAttacker()

			if attacker:IsPlayer() then
				if not table.HasValue(v.AllowedPlayers, attacker) then
					return true
				end
			else
				attacker = attacker:CPPIGetOwner()

				if attacker then
					if attacker:IsPlayer() then
						if not table.HasValue(v.AllowedPlayers, attacker) then
							return true
						end
					end
				end
			end
		end

	end
end

function playerSpawnSendHints(ply)
	ply:SendHint("BuildBox", 10)
	ply:SendHint("AddBox", 13)
	ply:SendHint("RemoveBox", 13)
	ply:SendHint("AddPlayer", 18)
	ply:SendHint("RemovePlayer", 18)
	ply:SendHint("SpawnInBox", 23)
end

function playerSpawnInBox(ply)
	if ply:GetNWBool("SpawnInBox", false) then
		index = getPlayerBox(ply)
		
		if index then
			Pos = buildBoxes[index].Pos
			Pos.z = buildBoxes[index].Min.z + 20
			ply:SetPos(Pos)
		end
	end
end

function syncFromServer()
	net.Start("serverSync")
	net.WriteInt(#buildBoxes, 32)

	for k, v in pairs(buildBoxes) do
		net.WriteInt(k, 32)
		net.WriteEntity(v.Player)
		net.WriteTable(v.AllowedPlayers)
		net.WriteVector(v.Min)
		net.WriteVector(v.Max)
	end

	net.Broadcast()
end

function clientSyncRequest()
	net.Start("clientSyncRequest")
	net.SendToServer()
end

function syncFromClient()
	net.Start("clientSync")
	net.WriteInt(#buildBoxes, 32)

	for k, v in pairs(buildBoxes) do
		net.WriteInt(k, 32)
		net.WriteEntity(v.Player)
		net.WriteTable(v.AllowedPlayers)
		net.WriteVector(v.Min)
		net.WriteVector(v.Max)
	end

	net.SendToServer()
end

function saveBuildBoxMapDefault()
	if SERVER then
		if not file.IsDir("buildboxes", "DATA") then
			file.CreateDir("buildboxes")
		end

		local mapFileString = ""

		for k, v in pairs(buildBoxes) do
			mapFileString = mapFileString .. v.ToString()
		end

		file.Write("buildboxes/" .. game.GetMap() .. ".txt", mapFileString)
		
		//print("New map-default saved: ", mapFileString)
	end
end

function loadBuildBoxMapDefault()
	if SERVER then
		
		
		local mapFile = "buildboxes/" .. game.GetMap() .. ".txt"

		if file.Exists(mapFile, "DATA") then
			local mapFileString = file.Read(mapFile, "DATA")
			local buildBoxStrings = string.Explode("#", mapFileString)

			buildBoxes = {}
			
			//print(mapFileString)
			
			for k, v in pairs(buildBoxStrings) do
				if #string.Explode("|", v) == 3 then
					boxValueStrings = string.Explode("|", v)
					boxSizeStrings = string.Explode(",", boxValueStrings[1])
					boxMinStrings = string.Explode(",", boxValueStrings[2])
					index = (#buildBoxes + 1)
					box = createBuildBox(nil, Vector(tonumber(boxSizeStrings[1], 10), tonumber(boxSizeStrings[2], 10), tonumber(boxSizeStrings[3], 10)), Vector(tonumber(boxMinStrings[1], 10), tonumber(boxMinStrings[2], 10), tonumber(boxMinStrings[3], 10)))
					box.Player = nil
					//PrintTable(box)
					buildBoxes[index] = box
				end
			end

			syncFromServer()
			return true
		else
			print("error loading map defaults")
			return false
		end
	end
end

function deleteBoxFromClient(id)
	if CLIENT then
		net.Start("deleteBox")
		net.WriteInt(id, 32)
		net.SendToServer()
	end
end

function getPlayerBox(ply)

	if ply then

		for k, v in pairs(buildBoxes) do
			if v.Player == ply then
				return k
			end
		end

	end

	return nil

end

function giveBuildBox(ply)

	if ply then

		emptyIndex = -1

		for k, v in pairs(buildBoxes) do
			
			print("BOX" .. k .. ":")
			print("Player", v.Player)

			if not v.Player and emptyIndex == -1 then
				emptyIndex = k
			end
			
			if v.Player  and emptyIndex == -1 then
				if v.Player == ents.GetByIndex(0) then
					emtyIndex = k
				end
			end

			if v.Player == ply then
				ply:ChatPrint("You already have a buildbox, you can find it by searching the green one.")
				return false
			end

		end

		if emptyIndex == -1 then
			ply:ChatPrint("There is no unused buildbox left, sorry!")
			return false
		end
		
		buildBoxes[emptyIndex].Player = ply
		buildBoxes[emptyIndex].AllowedPlayers = {ply}

		ply:ChatPrint("A buildbox has been assigned to you...")
		

		return true

	end

	return false

end

function removeBuildBox(ply)

	index = getPlayerBox(ply)

	if index then
		
		if buildBoxes[index].IsInBox(ply:GetPos()) then
			ply:Kill()
		end
		
		buildBoxes[index].Player = nil
		buildBoxes[index].AllowedPlayers = {}
		
		ply:ChatPrint("The buildbox has been unassigned from you...")
	else
		ply:ChatPrint("You don't have a buildbox assigned to you!")
	end

end

function allowPlayerToBox(ply, plyToAdd)

	index = getPlayerBox(ply)

	if index and plyToAdd then
		if not table.HasValue(buildBoxes[index].AllowedPlayers, plyToAdd) then
			ply:ChatPrint("Added: " .. plyToAdd:Name())
			table.insert(buildBoxes[index].AllowedPlayers, plyToAdd)
		end
	elseif index then
		ply:ChatPrint("The player could not be found!")
	else
		ply:ChatPrint("You don't have a buildbox to add players to!")
	end

end

function removePlayerFromBox(ply, plyToRemove)

	index = getPlayerBox(ply)

	if index and plyToRemove then

		i = 1

		for k, v in pairs(buildBoxes[index].AllowedPlayers) do
			if v == plyToRemove then
				if buildBoxes[index].IsInBox(plyToRemove:GetPos()) then
					plyToRemove:Kill()
				end
				ply:ChatPrint("Removed: " .. table.remove(buildBoxes[index].AllowedPlayers, i):Name())
			end

			i = i + 1
		end
	elseif index then
		ply:ChatPrint("The player could not be found!")
	else
		ply:ChatPrint("You don't have a buildbox to remove players from!")
	end
end

function setShowHelpAgain(ply, cmd, args)
	if CLIENT then
		ply:SetPData("showHelpAgain", args[1])
		print("showHelpAgain set to " .. args[1])
	end
end

function shouldShowHelp(ply)
	if CLIENT then
		if ply:GetPData("showHelpAgain") == "1" then
			showHelpMenu()
		end
	end
end

if SERVER then
	timer.Create("CheckBoxes", 0.2, 0, function()
		for k, v in pairs(buildBoxes) do
			v.CheckEntities()
		end
	end)

	timer.Create("CheckPlayers", 1, 0, function()
		for k, v in pairs(player.GetAll()) do
			if v:Alive() then
				for kb, vb in pairs(buildBoxes) do
					if vb.IsInBox(v:GetPos()) and not table.HasValue(vb.AllowedPlayers, v) then
						v:Kill()
						break
					end
				end
			end
		end
	end)
	
	util.AddNetworkString("syncTables")
	util.AddNetworkString("loadDefault")
	util.AddNetworkString("saveDefault")
	util.AddNetworkString("serverSync")
	util.AddNetworkString("clientSyncRequest")
	util.AddNetworkString("clientSync")
	util.AddNetworkString("deleteBox")

	net.Receive("clientSyncRequest", function(length, ply)
		syncFromServer()
	end)
	
	net.Receive("clientSync", function(length, ply)
		boxCount = net.ReadInt(32)

		buildBoxes = {}

		for var = 1, boxCount + 1, 1 do
			boxIndex = net.ReadInt(32)
			buildBoxes[boxIndex] = createBuildBox(nil, Vector(0, 0, 0), Vector(0, 0, 0))
			buildBoxes[boxIndex].Player = net.ReadEntity()
			buildBoxes[boxIndex].AllowedPlayers = net.ReadTable()
			buildBoxes[boxIndex].Min = net.ReadVector()
			buildBoxes[boxIndex].Max = net.ReadVector()

			buildBoxes[boxIndex].RefreshPos()
		end

		syncFromServer()
	end)

	net.Receive("loadDefault", function(length, ply)
		loadBuildBoxMapDefault()
	end)

	net.Receive("saveDefault", function(length, ply)
		saveBuildBoxMapDefault()
	end)

	net.Receive("deleteBox", function(length, ply)
		if ply:IsAdmin() then
			boxIndex = net.ReadInt(32)
			table.remove(buildBoxes, boxIndex)
			
			net.Start("deleteBox")
			net.WriteInt(boxIndex, 32)
			net.Broadcast()
		else
			print(ply:Nick() .. " tried to delete a box!")
		end
	end)

	if game.GetMap() == "gm_flatgrass" and not loadBuildBoxMapDefault() then
		boxIndex = 1
	
		for var = 0, 7, 1 do
			
			doAdd = 0
			
			if var > 0 then
				doAdd = 1
			end
			
			local minPos1 = addVec(startPos1, Vector(3000 * var, 0, 0))
			local minPos2 = addVec(startPos2, Vector(3000 * var, 0, 0))
	
			
			buildBoxes[boxIndex] =  createBuildBox(nil, Vector(3000, 3000, 3000), minPos1)
			boxIndex= boxIndex + 1
			buildBoxes[boxIndex] =  createBuildBox(nil, Vector(3000, 3000, 3000), minPos2)
			boxIndex= boxIndex + 1
			
		end
		
		saveBuildBoxMapDefault()
	elseif not game.GetMap() == "gm_flatgrass" then
		loadBuildBoxMapDefault()
	end

	print("SERVER-INIT: DONE")
end

if CLIENT then
	net.Receive("syncTables", function (length)
		print("[DEPRECATED] - SyncTables")
		boxIndex = net.ReadInt(32)
		
		netPlayer = net.ReadEntity()
		netAllowed = net.ReadTable()
		netMin = net.ReadVector()
		netMax = net.ReadVector()
		
		
		//print("Count: " ..#buildBoxes, " Index: ", boxIndex)
		//print("Min", netMin, "Max", netMax)
		//print("netPlayer", netPlayer, "netAllowed", netAllowed)
		
		buildBoxes[boxIndex] = createBuildBox(nil, Vector(0, 0, 0), Vector(0, 0, 0))
		
		
		//print("ne")
		
		buildBoxes[boxIndex].Player = netPlayer
		buildBoxes[boxIndex].AllowedPlayers = netAllowed
		buildBoxes[boxIndex].Min = netMin
		buildBoxes[boxIndex].Max = netMax
		
		buildBoxes[boxIndex].RefreshPos()
		
		//PrintTable(buildBoxes[boxIndex])
		
	end)

	net.Receive("serverSync", function(length)
		boxCount = net.ReadInt(32)

		buildBoxes = {}

		for var = 1, boxCount + 1, 1 do
			boxIndex = net.ReadInt(32)
			buildBoxes[boxIndex] = createBuildBox(nil, Vector(0, 0, 0), Vector(0, 0, 0))
			buildBoxes[boxIndex].Player = net.ReadEntity()

			

			if not pcall(function()
				buildBoxes[boxIndex].AllowedPlayers = net.ReadTable()
			end) then
				buildBoxes[boxIndex].AllowedPlayers = {}
			end
			
			buildBoxes[boxIndex].Min = net.ReadVector()
			buildBoxes[boxIndex].Max = net.ReadVector()

			buildBoxes[boxIndex].RefreshPos()
		end

	end)

	net.Receive("deleteBox", function(length)
		table.remove(buildBoxes, net.ReadInt(32))
	end)
	
	language.Add("Hint_BuildBox", "If you want to build in peace you can get a buildbox!")
	language.Add("Hint_AddBox", "To get a buildbox write \"!getBox\" in chat")
	language.Add("Hint_RemoveBox", "To unassign the buildbox from you write \"!removeBox\" in chat")
	language.Add("Hint_AddPlayer", "To allow other players to build in your box write \"!addPlayer [NAME]\" in chat")
	language.Add("Hint_RemovePlayer", "To disallow other players to build in your box write \"!removePlayer [NAME]\" in chat")
	language.Add("Hint_SpawnInBox", "If you wish to spawn in your box, you can toggle this by writing \"!spawnInBox\" in chat")
	
	clientSyncRequest()
	
	print("CLIENT-INIT: DONE")
end

concommand.Add("createBuildBoxMenu", createBuildBoxMenu)
concommand.Add("buildBoxHelp", showHelpMenu)
concommand.Add("showHelpAgain", setShowHelpAgain)
concommand.Add("shouldShowHelp", shouldShowHelp)

hook.Add("BuildBox", "GetBoxes", getBoxes)
hook.Add("BuildBox", "SetBoxes", setBoxes)

hook.Add("PostDrawOpaqueRenderables", "RenderBox", drawAllBoxes)
hook.Add("PlayerSpawnEffect", "CanSpawnEffect", canSpawn)
hook.Add("PlayerSpawnNPC", "CanSpawnNPC", canSpawn)
hook.Add("PlayerSpawnObject", "CanSpawnObject", canSpawn)
hook.Add("PlayerSpawnProp", "CanSpawnProp", canSpawn)
hook.Add("PlayerSpawnRagdoll", "CanSpawnRagdoll", canSpawn)
hook.Add("PlayerSpawnSENT", "CanSpawnSENT", canSpawn)
hook.Add("PlayerSpawnSWEP", "CanSpawnSWEAP", canSpawn)
hook.Add("PlayerSpawnVehicle", "CanSpawnVehicle", canSpawn)
hook.Add("CanTool", "CanTool", canSpawn)
hook.Add("Move", "CanMove", canMove)
hook.Add("PlayerDisconnected", "RemoveBuildBoxOnDisconnect", playerDisconnected)
hook.Add("PlayerSay", "ChatCommands", playerSay)
hook.Add("PlayerSpawn", "SendHints", playerSpawnSendHints)
hook.Add("PlayerSpawn", "SpawnInBox", playerSpawnInBox)
hook.Add("EntityTakeDamage", "CanDamage", canDamage)

hook.Add("PlayerInitialSpawn", "SetShowHelpAgain", function(ply) 
	ply:ConCommand("showHelpAgain 1")
	timer.Create("ShowHelp", 20, 1, function()
		ply:ConCommand("buildBoxHelp")
	end)
end)

hook.Add("PlayerSpawn", "ShowHelp", function(ply) ply:ConCommand("shouldShowHelp") end)
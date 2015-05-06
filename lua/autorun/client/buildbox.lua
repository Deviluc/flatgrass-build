buildBoxes = {}
startPos1 = Vector(-15000,-15000, -12810)
startPos2 = Vector(-15000, 12000, -12810)

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
	
	return box
end

function drawAllBoxes()
	if CLIENT then

		ply = LocalPlayer()
		
		local trace = LocalPlayer():GetEyeTrace()
		local angle = trace.HitNormal:Angle()

		//cam.Start({angles = ply:GetRenderAngles(), origin = ply:GetRenderOrigin(), type = "3D"})
		cam.Start3D(ply:EyePos(), EyeAngles())

		for k, v in pairs(buildBoxes) do
			color = Color(200, 0, 0, 255)

			if v.Player == LocalPlayer() then
				color = Color(0, 200, 0, 255)
			end

			render.DrawWireframeBox(v.Pos, Angle(0, 0, 0), mulVec(v.Size, -0.5), mulVec(v.Size, 0.5), color)
		end	

		cam.End3D()
	end

	
	return false
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

function canMoveVehicle(ply, vech, moveData)
	local speed = 0.0005 * FrameTime()
	local nextPos = addVec(vech:GetPos(), mulVec(moveData:GetVelocity(), speed))
	
	for k, v in pairs(buildBoxes) do
		if nextPos:WithinAABox(v.Min, v.Max) then
			for k, v in pairs(v.AllowedPlayers) do
				if v == ply then
					return false
				end
			end
			
			if SERVER then
				ply:Kill()
			end
			
			vech:Remove()
			
			moveData:SetOrigin(subVec(moveData:GetOrigin(), moveData:GetVelocity()))
			moveData:SetVelocity(mulVec(moveData:GetVelocity(), -1))
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

		if text == "!getBox" then
			giveBuildBox(ply)
			syncFromServer()
			return false
		end

		if text == "!removeBox" then
			removeBuildBox(ply)
			syncFromServer()
			return false
		end

		if args[1] == "!addPlayer" then
			plyToAdd = findPlayerByName(args[2])

			allowPlayerToBox(ply, plyToAdd)
			syncFromServer()
			return false
		end

		if args[1] == "!removePlayer" then
			plyToRemove = findPlayerByName(args[2])

			removePlayerFromBox(ply, plyToRemove)
			syncFromServer()
			return false
		end
		
		if args[1] == "!spawnInBox" then
			if ply:GetNWBool("SpawnInBox", false) then
				ply:SetNWBool("SpawnInBox", false)
				ply:ChatPrint("You will no longer spawn in your buildbox")
			else
				ply:SetNWBool("SpawnInBox", true)
				ply:ChatPrint("You will now spawn in your buildbox")
			end
			
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
	
	for k, v in pairs (buildBoxes) do
		net.Start("syncTables")
		net.WriteInt(k, 32)
		net.WriteEntity(v.Player)
		net.WriteTable(v.AllowedPlayers)
		net.Broadcast()
	end
end

function syncFromClient()
	for k, v in pairs (buildBoxes) do
		net.Start("syncTables")
		net.WriteInt(k, 32)
		net.WriteEntity(v.Player)
		net.WriteTable(v.AllowedPlayers)
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

			if not v.Player and emptyIndex == -1 then
				emptyIndex = k
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

print("Boxes created...")

if SERVER then
	timer.Create("CheckBoxes", 0.2, 0, function()
		for k, v in pairs(buildBoxes) do
			v.CheckEntities()
		end
	end)
	
	util.AddNetworkString("syncTables")
	
	net.Receive("syncTables", function(length, ply)
		boxIndex = net.ReadInt(32)
		
		buildBoxes[boxIndex].Player = net.ReadEntity()
		buildBoxes[boxIndex].AllowedPlayers = net.ReadTable()
		
		net.Start("syncTables")
		net.ReadInt(32)
		net.WriteEntity(buildBoxes[boxIndex].Player)
		net.WriteTable(buildBoxes[boxIndex].AllowedPlayers)
		net.Broadcast()
	end)
end

if CLIENT then
	net.Receive("syncTables", function (length)
		boxIndex = net.ReadInt(32)
		
		buildBoxes[boxIndex].Player = net.ReadEntity()
		buildBoxes[boxIndex].AllowedPlayers = net.ReadTable()
		
	end)
	
	language.Add("Hint_BuildBox", "If you want to build in peace you can get a buildbox!")
	language.Add("Hint_AddBox", "To get a buildbox write \"!getBox\" in chat")
	language.Add("Hint_RemoveBox", "To unassign the buildbox from you write \"!removeBox\" in chat")
	language.Add("Hint_AddPlayer", "To allow other players to build in your box write \"!addPlayer [NAME]\" in chat")
	language.Add("Hint_RemovePlayer", "To disallow other players to build in your box write \"!removePlayer [NAME]\" in chat")
	language.Add("Hint_SpawnInBox", "If you wish to spawn in your box, you can toggle this by writing \"!spawnInBox\" in chat")
	
end

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
hook.Add("VehicleMove", "CanMoveVehicle", canMoveVehicle)
hook.Add("PlayerDisconnected", "RemoveBuildBoxOnDisconnect", playerDisconnected)
hook.Add("PlayerSay", "ChatCommands", playerSay)
hook.Add("PlayerSpawn", "SendHints", playerSpawnSendHints)
hook.Add("PlayerSpawn", "SpawnInBox", playerSpawnInBox)
hook.Add("EntityTakeDamage", "CanDamage", canDamage)
local function shieldOn(ply)
	if ply then
		ply:SetMaterial("prop_freeze.vtf")
		ply:GodEnable()
		if SERVER then
			ply:SendHint("GodOn", 1)
		end
	end
end

local function shieldOff(ply)
	if ply then
		ply:SetMaterial("")
		ply:GodDisable()
		if SERVER then
			ply:SendHint("GodOff", 1)
		end
	end
end

function playerSpawn(ply)
    timer.Create("spawnTimer", 0.01, 1, function()
    	shieldOn(ply)
	end)
end
 
function playerSwitchWeapon(ply, oldWeapon, newWeapon)
    if ply:HasGodMode() then
    	local find1 = string.find(newWeapon:GetClass(), "tool")
    	local find2 = string.find(newWeapon:GetClass(), "camera")
    	
        if newWeapon:IsWeapon() and not find1 and not find2 then
            if newWeapon:GetClass() != "weapon_physgun" then
                shieldOff(ply)
            end
        end
    end
end
 
function playerEnteredVehicle(ply, vehicle, role)
    if ply:HasGodMode() then
        shieldOff(ply)
    end
end
 
function playerSpawnedNPC(ply, ent)
    if ply:HasGodMode() then
        shieldOff(ply)
    end
end

function playerShouldTakeDamage(ply, attacker)
	if ply then
		if ply:HasGodMode() then
			return false
		end
		
		if attacker then
			if attacker:IsPlayer() then
				if attacker:HasGodMode() then
					return false
				else
					return true
				end
			elseif attacker:IsWorld() then
				return true
			elseif attacker:GetOwner() then
				if attacker:GetOwner():IsPlayer() then
					if attacker:GetOwner():HasGodMode() then
						return false
					else
						return true
					end
				end
			end
		end
	end
	return true
end

function initialSpawn(ply)
	if CLIENT then
		language.Add("Hint_GodOn", "Godmode ENABLED!")
		language.Add("Hint_GodOff", "Godmode DISABLED!")
	end
end
   
hook.Add("PlayerSpawnedNPC", "NPC", playerSpawnedNPC)
hook.Add("PlayerEnteredVehicle", "Entered", playerEnteredVehicle)
hook.Add("PlayerSwitchWeapon", "Switched", playerSwitchWeapon)
hook.Add("PlayerSpawn", "Spawn", playerSpawn)
hook.Add("PlayerShouldTakeDamage", "Damage", playerShouldTakeDamage)
hook.Add("PlayerInitialSpawn", "Init", initialSpawn)
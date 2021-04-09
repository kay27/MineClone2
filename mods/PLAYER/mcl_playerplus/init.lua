local S = minetest.get_translator("mcl_playerplus")

local get_connected_players = minetest.get_connected_players
local dir_to_yaw = minetest.dir_to_yaw
local get_item_group = minetest.get_item_group
local check_player_privs = minetest.check_player_privs
local find_node_near = minetest.find_node_near
local get_name_from_content_id = minetest.get_name_from_content_id
local get_voxel_manip = minetest.get_voxel_manip
local add_particle = minetest.add_particle
local add_particlespawner = minetest.add_particlespawner

local is_sprinting = mcl_sprint.is_sprinting
local exhaust = mcl_hunger.exhaust
local playerphysics = playerphysics

local vector = vector
local math = math
-- Internal player state
local mcl_playerplus_internal = {}

local def = {}
local time = 0

local player_collision = function(player)

	local pos = player:get_pos()
	local vel = player:get_velocity()
	local x = 0
	local z = 0
	local width = .75

	for _,object in pairs(minetest.get_objects_inside_radius(pos, width)) do

		if object:is_player()
		or (object:get_luaentity()._cmi_is_mob == true and object ~= player) then

			local pos2 = object:get_pos()
			local vec  = {x = pos.x - pos2.x, z = pos.z - pos2.z}
			local force = (width + 0.5) - vector.distance(
				{x = pos.x, y = 0, z = pos.z},
				{x = pos2.x, y = 0, z = pos2.z})

			x = x + (vec.x * force)
			z = z + (vec.z * force)
		end
	end

	return({x * 5,z * 5})
end

-- converts yaw to degrees
local function degrees(rad)
	return rad * 180.0 / math.pi
end

local pi = math.pi
local atann = math.atan
local atan = function(x)
	if not x or x ~= x then
		return 0
	else
		return atann(x)
	end
end

local dir_to_pitch = function(dir)
	local dir2 = vector.normalize(dir)
	local xz = math.abs(dir.x) + math.abs(dir.z)
	return -math.atan2(-dir.y, xz)
end

local player_vel_yaws = {}

function limit_vel_yaw(player_vel_yaw, yaw)
	if player_vel_yaw < 0 then
		player_vel_yaw = player_vel_yaw + 360
	end

	if yaw < 0 then
		yaw = yaw + 360
	end

	if math.abs(player_vel_yaw - yaw) > 40 then
		local player_vel_yaw_nm, yaw_nm = player_vel_yaw, yaw
		if player_vel_yaw > yaw then
			player_vel_yaw_nm = player_vel_yaw - 360
		else
			yaw_nm = yaw - 360
		end
		if math.abs(player_vel_yaw_nm - yaw_nm) > 40 then
			local diff = math.abs(player_vel_yaw - yaw)
			if diff > 180 and diff < 185 or diff < 180 and diff > 175 then
				player_vel_yaw = yaw
			elseif diff < 180 then
				if player_vel_yaw < yaw then
					player_vel_yaw = yaw - 40
				else
					player_vel_yaw = yaw + 40
				end
			else
				if player_vel_yaw < yaw then
					player_vel_yaw = yaw + 40
				else
					player_vel_yaw = yaw - 40
				end
			end
		end
	end

	if player_vel_yaw < 0 then
		player_vel_yaw = player_vel_yaw + 360
	elseif player_vel_yaw > 360 then
		player_vel_yaw = player_vel_yaw - 360
	end

	return player_vel_yaw
end

local pitch, name, node_stand, node_stand_below, node_head, node_feet, pos

minetest.register_globalstep(function(dtime)

	time = time + dtime

	for _,player in pairs(get_connected_players()) do

		c_x, c_y = unpack(player_collision(player))

		if player:get_velocity().x + player:get_velocity().y < .5 and c_x + c_y > 0 then
			--minetest.chat_send_player(player:get_player_name(), "pushed at " .. c_x + c_y .. " parsecs.")
			player:add_velocity({x=c_x, y=0, z=c_y})
		end

		--[[
						 _                 _   _
			  __ _ _ __ (_)_ __ ___   __ _| |_(_) ___  _ __  ___
			 / _` | '_ \| | '_ ` _ \ / _` | __| |/ _ \| '_ \/ __|
			| (_| | | | | | | | | | | (_| | |_| | (_) | | | \__ \
			 \__,_|_| |_|_|_| |_| |_|\__,_|\__|_|\___/|_| |_|___/

		]]--

		local controls = player:get_player_control()
		local name = player:get_player_name()
		local meta = player:get_meta()
		local parent = player:get_attach()
		local wielded = player:get_wielded_item()
		local player_velocity = player:get_velocity() or player:get_player_velocity()

		-- controls head bone
		local pitch = - degrees(player:get_look_vertical())
		local yaw = degrees(player:get_look_horizontal())

		local player_vel_yaw = degrees(dir_to_yaw(player_velocity))
		if player_vel_yaw == 0 then
			player_vel_yaw = player_vel_yaws[name] or yaw
		end
		player_vel_yaw = limit_vel_yaw(player_vel_yaw, yaw)
		player_vel_yaws[name] = player_vel_yaw

		-- controls right and left arms pitch when shooting a bow
		if string.find(wielded:get_name(), "mcl_bows:bow") and controls.RMB and not controls.LMB and not controls.up and not controls.down and not controls.left and not controls.right then
			player:set_bone_position("Arm_Right_Pitch_Control", vector.new(-3,5.785,0), vector.new(pitch+90,-30,pitch * -1 * .35))
			player:set_bone_position("Arm_Left_Pitch_Control", vector.new(3.5,5.785,0), vector.new(pitch+90,43,pitch * .35))
		-- when punching
		elseif controls.LMB and not parent then
			player:set_bone_position("Arm_Right_Pitch_Control", vector.new(-3,5.785,0), vector.new(pitch,0,0))
			player:set_bone_position("Arm_Left_Pitch_Control", vector.new(3,5.785,0), vector.new(0,0,0))
		-- when holding an item.
		elseif wielded:get_name() ~= "" then
			player:set_bone_position("Arm_Right_Pitch_Control", vector.new(-3,5.785,0), vector.new(20,0,0))
			player:set_bone_position("Arm_Left_Pitch_Control", vector.new(3,5.785,0), vector.new(0,0,0))
		-- resets arms pitch
		else
			player:set_bone_position("Arm_Left_Pitch_Control", vector.new(3,5.785,0), vector.new(0,0,0))
			player:set_bone_position("Arm_Right_Pitch_Control", vector.new(-3,5.785,0), vector.new(0,0,0))
		end

		if parent then
			local parent_yaw = degrees(parent:get_yaw())
			player:set_properties({collisionbox = {-0.35,0,-0.35,0.35,1.8,0.35}, eye_height = 1.5, nametag_color = { r = 225, b = 225, a = 225, g = 225 }})
			player:set_bone_position("Head", vector.new(0,6.3,0), vector.new(pitch, -limit_vel_yaw(yaw, parent_yaw) + parent_yaw, 0))
			player:set_bone_position("Body_Control", vector.new(0,6.3,0), vector.new(0,0,0))
		elseif controls.sneak then
			-- controls head pitch when sneaking
			player:set_bone_position("Head", vector.new(0,6.3,0), vector.new(pitch+36,0,0))
			-- sets eye height, and nametag color accordingly
			player:set_properties({collisionbox = {-0.35,0,-0.35,0.35,1.8,0.35}, eye_height = 1.35, nametag_color = { r = 225, b = 225, a = 0, g = 225 }})
			-- sneaking body conrols
			player:set_bone_position("Body_Control", vector.new(0,6.3,0), vector.new(0,0,0))
		elseif get_item_group(mcl_playerinfo[name].node_head, "water") ~= 0 and is_sprinting(name) == true then
			-- set head pitch and yaw when swimming
			player:set_bone_position("Head", vector.new(0,6.3,0), vector.new(pitch+90-degrees(dir_to_pitch(player_velocity)),player_vel_yaw - yaw,0))
			-- sets eye height, and nametag color accordingly
			player:set_properties({collisionbox = {-0.35,0,-0.35,0.35,0.8,0.35}, eye_height = 0.5, nametag_color = { r = 225, b = 225, a = 225, g = 225 }})
			-- control body bone when swimming
			player:set_bone_position("Body_Control", vector.new(0,6.3,0), vector.new(degrees(dir_to_pitch(player_velocity)) - 90,-player_vel_yaw + yaw + 180,0))
		else
			-- sets eye height, and nametag color accordingly
			player:set_properties({collisionbox = {-0.35,0,-0.35,0.35,1.8,0.35}, eye_height = 1.5, nametag_color = { r = 225, b = 225, a = 225, g = 225 }})

			player:set_bone_position("Head", vector.new(0,6.3,0), vector.new(pitch, player_vel_yaw - yaw, 0))
			player:set_bone_position("Body_Control", vector.new(0,6.3,0), vector.new(0, -player_vel_yaw + yaw, 0))
		end

		-- Update jump status immediately since we need this info in real time.
		-- WARNING: This section is HACKY as hell since it is all just based on heuristics.

		if mcl_playerplus_internal[name].jump_cooldown > 0 then
			mcl_playerplus_internal[name].jump_cooldown = mcl_playerplus_internal[name].jump_cooldown - dtime
		end

		if controls.jump and mcl_playerplus_internal[name].jump_cooldown <= 0 then

			pos = player:get_pos()

			node_stand = mcl_playerinfo[name].node_stand
			node_stand_below = mcl_playerinfo[name].node_stand_below
			node_head = mcl_playerinfo[name].node_head
			node_feet = mcl_playerinfo[name].node_feet
			if not node_stand or not node_stand_below or not node_head or not node_feet then
				return
			end
			if not minetest.registered_nodes[node_stand] or not minetest.registered_nodes[node_stand_below] or not minetest.registered_nodes[node_head] or not minetest.registered_nodes[node_feet] then
				return
			end

			-- Cause buggy exhaustion for jumping

			--[[ Checklist we check to know the player *actually* jumped:
				* Not on or in liquid
				* Not on or at climbable
				* On walkable
				* Not on disable_jump
			FIXME: This code is pretty hacky and it is possible to miss some jumps or detect false
			jumps because of delays, rounding errors, etc.
			What this code *really* needs is some kind of jumping “callback” which this engine lacks
			as of 0.4.15.
			]]

			if get_item_group(node_feet, "liquid") == 0 and
					get_item_group(node_stand, "liquid") == 0 and
					not minetest.registered_nodes[node_feet].climbable and
					not minetest.registered_nodes[node_stand].climbable and
					(minetest.registered_nodes[node_stand].walkable or minetest.registered_nodes[node_stand_below].walkable)
					and get_item_group(node_stand, "disable_jump") == 0
					and get_item_group(node_stand_below, "disable_jump") == 0 then
			-- Cause exhaustion for jumping
			if is_sprinting(name) then
				exhaust(name, mcl_hunger.EXHAUST_SPRINT_JUMP)
			else
				exhaust(name, mcl_hunger.EXHAUST_JUMP)
			end

			-- Reset cooldown timer
				mcl_playerplus_internal[name].jump_cooldown = 0.45
			end
		end
	end

	-- Run the rest of the code every 0.5 seconds
	if time < 0.5 then
		return
	end

	-- reset time for next check
	-- FIXME: Make sure a regular check interval applies
	time = 0

	-- check players
	for _,player in pairs(get_connected_players()) do
		-- who am I?
		local name = player:get_player_name()

		-- where am I?
		local pos = player:get_pos()

		-- what is around me?
		local node_stand = mcl_playerinfo[name].node_stand
		local node_stand_below = mcl_playerinfo[name].node_stand_below
		local node_head = mcl_playerinfo[name].node_head
		local node_feet = mcl_playerinfo[name].node_feet
		if not node_stand or not node_stand_below or not node_head or not node_feet then
			return
		end

		-- set defaults
		def.speed = 1

		-- Standing on soul sand? If so, walk slower (unless player wears Soul Speed boots)
		if node_stand == "mcl_nether:soul_sand" then
			-- TODO: Tweak walk speed
			-- TODO: Also slow down mobs
			-- Slow down even more when soul sand is above certain block
			local boots = player:get_inventory():get_stack("armor", 5)
			local soul_speed = mcl_enchanting.get_enchantment(boots, "soul_speed")
			if soul_speed > 0 then
				playerphysics.add_physics_factor(player, "speed", "mcl_playerplus:surface", soul_speed * 0.105 + 1.3)
			else
				if node_stand_below == "mcl_core:ice" or node_stand_below == "mcl_core:packed_ice" or node_stand_below == "mcl_core:slimeblock" or node_stand_below == "mcl_core:water_source" then
					playerphysics.add_physics_factor(player, "speed", "mcl_playerplus:surface", 0.1)
				else
					playerphysics.add_physics_factor(player, "speed", "mcl_playerplus:surface", 0.4)
				end
			end
		elseif get_item_group(node_feet, "liquid") ~= 0 and mcl_enchanting.get_enchantment(player:get_inventory():get_stack("armor", 5), "depth_strider") then
			local boots = player:get_inventory():get_stack("armor", 5)
			local depth_strider = mcl_enchanting.get_enchantment(boots, "depth_strider")

			if depth_strider > 0 then
				playerphysics.add_physics_factor(player, "speed", "mcl_playerplus:surface", (depth_strider / 3) + 0.75)
			end
		else
			playerphysics.remove_physics_factor(player, "speed", "mcl_playerplus:surface")
		end

		-- Is player suffocating inside node? (Only for solid full opaque cube type nodes
		-- without group disable_suffocation=1)
		local ndef = minetest.registered_nodes[node_head]

		if (ndef.walkable == nil or ndef.walkable == true)
		and (ndef.collision_box == nil or ndef.collision_box.type == "regular")
		and (ndef.node_box == nil or ndef.node_box.type == "regular")
		and (ndef.groups.disable_suffocation ~= 1)
		and (ndef.groups.opaque == 1)
		and (node_head ~= "ignore")
		-- Check privilege, too
		and (not check_player_privs(name, {noclip = true})) then
			if player:get_hp() > 0 then
				mcl_death_messages.player_damage(player, S("@1 suffocated to death.", name))
				player:set_hp(player:get_hp() - 1)
			end
		end

		-- Am I near a cactus?
		local near = find_node_near(pos, 1, "mcl_core:cactus")
		if not near then
			near = find_node_near({x=pos.x, y=pos.y-1, z=pos.z}, 1, "mcl_core:cactus")
		end
		if near then
			-- Am I touching the cactus? If so, it hurts
			local dist = vector.distance(pos, near)
			local dist_feet = vector.distance({x=pos.x, y=pos.y-1, z=pos.z}, near)
			if dist < 1.1 or dist_feet < 1.1 then
				if player:get_hp() > 0 then
					mcl_death_messages.player_damage(player, S("@1 was prickled to death by a cactus.", name))
					player:set_hp(player:get_hp() - 1, { type = "punch", from = "mod" })
				end
			end
		end

		--[[ Swimming: Cause exhaustion.
		NOTE: As of 0.4.15, it only counts as swimming when you are with the feet inside the liquid!
		Head alone does not count. We respect that for now. ]]
		if not player:get_attach() and (get_item_group(node_feet, "liquid") ~= 0 or
				get_item_group(node_stand, "liquid") ~= 0) then
			local lastPos = mcl_playerplus_internal[name].lastPos
			if lastPos then
				local dist = vector.distance(lastPos, pos)
				mcl_playerplus_internal[name].swimDistance = mcl_playerplus_internal[name].swimDistance + dist
				if mcl_playerplus_internal[name].swimDistance >= 1 then
					local superficial = math.floor(mcl_playerplus_internal[name].swimDistance)
					exhaust(name, mcl_hunger.EXHAUST_SWIM * superficial)
					mcl_playerplus_internal[name].swimDistance = mcl_playerplus_internal[name].swimDistance - superficial
				end
			end

		end

		-- Underwater: Spawn bubble particles
		if get_item_group(node_head, "water") ~= 0 then
			add_particlespawner({
				amount = 10,
				time = 0.15,
				minpos = { x = -0.25, y = 0.3, z = -0.25 },
				maxpos = { x = 0.25, y = 0.7, z = 0.75 },
				attached = player,
				minvel = {x = -0.2, y = 0, z = -0.2},
				maxvel = {x = 0.5, y = 0, z = 0.5},
				minacc = {x = -0.4, y = 4, z = -0.4},
				maxacc = {x = 0.5, y = 1, z = 0.5},
				minexptime = 0.3,
				maxexptime = 0.8,
				minsize = 0.7,
				maxsize = 2.4,
				texture = "mcl_particles_bubble.png"
			})
		end

		-- Show positions of barriers when player is wielding a barrier
		local wi = player:get_wielded_item():get_name()
		if wi == "mcl_core:barrier" or wi == "mcl_core:realm_barrier" then
			local pos = vector.round(player:get_pos())
			local r = 8
			local vm = get_voxel_manip()
			local emin, emax = vm:read_from_map({x=pos.x-r, y=pos.y-r, z=pos.z-r}, {x=pos.x+r, y=pos.y+r, z=pos.z+r})
			local area = VoxelArea:new{
				MinEdge = emin,
				MaxEdge = emax,
			}
			local data = vm:get_data()
			for x=pos.x-r, pos.x+r do
			for y=pos.y-r, pos.y+r do
			for z=pos.z-r, pos.z+r do
				local vi = area:indexp({x=x, y=y, z=z})
				local nodename = get_name_from_content_id(data[vi])
				local tex
				if nodename == "mcl_core:barrier" then
					tex = "mcl_core_barrier.png"
				elseif nodename == "mcl_core:realm_barrier" then
					tex = "mcl_core_barrier.png^[colorize:#FF00FF:127^[transformFX"
				end
				if tex then
					add_particle({
						pos = {x=x, y=y, z=z},
						expirationtime = 1,
						size = 8,
						texture = tex,
						glow = 14,
						playername = name
					})
				end
			end
			end
			end
		end

		-- Update internal values
		mcl_playerplus_internal[name].lastPos = pos

	end

end)

-- set to blank on join (for 3rd party mods)
minetest.register_on_joinplayer(function(player)
	local name = player:get_player_name()

	mcl_playerplus_internal[name] = {
		lastPos = nil,
		swimDistance = 0,
		jump_cooldown = -1,	-- Cooldown timer for jumping, we need this to prevent the jump exhaustion to increase rapidly
	}
end)

-- clear when player leaves
minetest.register_on_leaveplayer(function(player)
	local name = player:get_player_name()

	mcl_playerplus_internal[name] = nil
end)

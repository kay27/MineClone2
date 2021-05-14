--License for code WTFPL and otherwise stated in readmes

local S = minetest.get_translator("mobs_mc")

mobs:register_mob("mobs_mc:pig", {
	description = S("Pig"),
	type = "animal",
	spawn_class = "passive",
	skittish = true,
	rotate = 270,
	hp_min = 10,
	hp_max = 10,
	xp_min = 1,
	xp_max = 3,
	collisionbox = {-0.45, -0.01, -0.45, 0.45, 0.865, 0.45},
	visual = "mesh",
	mesh = "mobs_mc_pig.b3d",
	textures = {{
		"blank.png", -- baby
		"mobs_mc_pig.png", -- base
		"blank.png", -- saddle
	}},

	--head code
	has_head = true,
	head_bone = "head",

	swap_y_with_x = false,
	reverse_head_yaw = false,

	head_bone_pos_y = 2.4,
	head_bone_pos_z = 0,

	head_height_offset = 1.1,
	head_direction_offset = 0,
	head_pitch_modifier = 0,
	--end head code

	visual_size = {x=2.5, y=2.5},
	makes_footstep_sound = true,
	walk_velocity = 1,
	run_velocity = 3,
	follow_velocity = 3.4,
	breed_distance = 1.5,
	baby_size = 0.5,
	follow_distance = 2,
	drops = {
		{name = mobs_mc.items.porkchop_raw,
		chance = 1,
		min = 1,
		max = 3,
		looting = "common",},
	},
	fear_height = 4,
	sounds = {
		random = "mobs_pig",
		death = "mobs_pig_angry",
		damage = "mobs_pig",
		eat = "mobs_mc_animal_eat_generic",
		distance = 16,
	},
	animation = {
		stand_speed = 40,
		walk_speed = 40,
		run_speed = 90,
		stand_start = 0,
		stand_end = 0,
		walk_start = 0,
		walk_end = 40,
		run_start = 0,
		run_end = 40,
	},
	follow = "mcl_farming:carrot_item",
	view_range = 8,
	do_custom = function(self, dtime)

		-- set needed values if not already present
		if not self.v2 then
			self.v2 = 0
			self.max_speed_forward = 4
			self.max_speed_reverse = 2
			self.accel = 4
			self.terrain_type = 3
			self.driver_attach_at = {x = 0.0, y = 2.75, z = -1.5}
			self.driver_eye_offset = {x = 0, y = 3, z = 0}
			self.driver_scale = {x = 1/self.visual_size.x, y = 1/self.visual_size.y}
		end

		-- if driver present allow control of horse
		if self.driver then

			mobs.drive(self, "walk", "stand", false, dtime)

			return false -- skip rest of mob functions
		end

		return true
	end,

	on_die = function(self, pos)

		-- drop saddle when horse is killed while riding
		-- also detach from horse properly
		if self.driver then
			mobs.detach(self.driver, {x = 1, y = 0, z = 1})
		end
	end,

	on_rightclick = function(self, clicker)
		if not clicker or not clicker:is_player() then
			return
		end

		--attempt to enter breed state
		if mobs.enter_breed_state(self,clicker) then
			return
		end

		--ignore other logic
		--make baby grow faster
		if self.baby then
			mobs.make_baby_grow_faster(self,clicker)
			return
		end

		if self.child then
			return
		end

		-- Put saddle on pig
		local item = clicker:get_wielded_item()
		local wielditem = item
		
		if item:get_name() == mobs_mc.items.saddle and self.saddle ~= "yes" then
			self.base_texture = {
				"blank.png", -- baby
				"mobs_mc_pig.png", -- base
				"mobs_mc_pig_saddle.png", -- saddle
			}
			self.object:set_properties({
				textures = self.base_texture
			})
			self.saddle = "yes"
			self.tamed = true
			self.drops = {
				{name = mobs_mc.items.porkchop_raw,
				chance = 1,
				min = 1,
				max = 3,},
				{name = mobs_mc.items.saddle,
				chance = 1,
				min = 1,
				max = 1,},
			}
			if not minetest.is_creative_enabled(clicker:get_player_name()) then
				local inv = clicker:get_inventory()
				local stack = inv:get_stack("main", clicker:get_wield_index())
				stack:take_item()
				inv:set_stack("main", clicker:get_wield_index(), stack)
			end
			minetest.sound_play({name = "mcl_armor_equip_leather"}, {gain=0.5, max_hear_distance=8, pos=self.object:get_pos()}, true)
			return
		end

		-- Mount or detach player
		local name = clicker:get_player_name()
		if self.driver and clicker == self.driver then
			-- Detach if already attached
			mobs.detach(clicker, {x=1, y=0, z=0})
			return

		elseif not self.driver and self.saddle == "yes" and wielditem:get_name() == mobs_mc.items.carrot_on_a_stick then
			-- Ride pig if it has a saddle and player uses a carrot on a stick

			mobs.attach(self, clicker)

			if not minetest.is_creative_enabled(clicker:get_player_name()) then

				local inv = self.driver:get_inventory()
				-- 26 uses
				if wielditem:get_wear() > 63000 then
					-- Break carrot on a stick
					local def = wielditem:get_definition()
					if def.sounds and def.sounds.breaks then
						minetest.sound_play(def.sounds.breaks, {pos = clicker:get_pos(), max_hear_distance = 8, gain = 0.5}, true)
					end
					wielditem = {name = mobs_mc.items.fishing_rod, count = 1}
				else
					wielditem:add_wear(2521)
				end
				inv:set_stack("main",self.driver:get_wield_index(), wielditem)
			end
			return
		end
	end,

	on_breed = function(parent1, parent2)
		local pos = parent1.object:get_pos()
		local child = mobs:spawn_child(pos, parent1.name)
		if child then
			local ent_c = child:get_luaentity()
			ent_c.tamed = true
			ent_c.owner = parent1.owner
			return false
		end
	end,
})

mobs:spawn_specific(
"mobs_mc:pig",
"overworld",
"ground",
{
	"FlowerForest_beach",
	"Forest_beach",
	"StoneBeach",
	"ColdTaiga_beach_water",
	"Taiga_beach",
	"Savanna_beach",
	"Plains_beach",
	"ExtremeHills_beach",
	"ColdTaiga_beach",
	"Swampland_shore",
	"JungleM_shore",
	"Jungle_shore",
	"MesaPlateauFM_sandlevel",
	"MesaPlateauF_sandlevel",
	"MesaBryce_sandlevel",
	"Mesa_sandlevel",
	"Mesa",
	"FlowerForest",
	"Swampland",
	"Taiga",
	"ExtremeHills",
	"Jungle",
	"Savanna",
	"BirchForest",
	"MegaSpruceTaiga",
	"MegaTaiga",
	"ExtremeHills+",
	"Forest",
	"Plains",
	"Desert",
	"ColdTaiga",
	"IcePlainsSpikes",
	"SunflowerPlains",
	"IcePlains",
	"RoofedForest",
	"ExtremeHills+_snowtop",
	"MesaPlateauFM_grasstop",
	"JungleEdgeM",
	"ExtremeHillsM",
	"JungleM",
	"BirchForestM",
	"MesaPlateauF",
	"MesaPlateauFM",
	"MesaPlateauF_grasstop",
	"MesaBryce",
	"JungleEdge",
	"SavannaM",
},
9,
minetest.LIGHT_MAX+1,
30,
15000,
8,
mobs_mc.spawn_height.overworld_min,
mobs_mc.spawn_height.overworld_max)

-- spawn eggs
mobs:register_egg("mobs_mc:pig", S("Pig"), "mobs_mc_spawn_icon_pig.png", 0)

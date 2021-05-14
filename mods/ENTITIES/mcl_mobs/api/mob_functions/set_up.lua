local math_random = math.random

local minetest_settings                     = minetest.settings

-- get entity staticdata
mobs.mob_staticdata = function(self)

	--despawn mechanism
	--don't despawned tamed or bred mobs
	if not self.tamed and not self.bred then
		if not mobs.check_for_player_within_area(self, 64) then
			--print("removing SERIALIZED!")
			self.object:remove()
			return
		end
	end

	self.remove_ok = true
	self.attack = nil
	self.following = nil

	if use_cmi then
		self.serialized_cmi_components = cmi.serialize_components(self._cmi_components)
	end

	local tmp = {}

	for _,stat in pairs(self) do

		local t = type(stat)

		if  t ~= "function"
		and t ~= "nil"
		and t ~= "userdata"
		and _ ~= "_cmi_components" then
			tmp[_] = self[_]
		end
	end

	return minetest.serialize(tmp)
end


-- activate mob and reload settings
mobs.mob_activate = function(self, staticdata, def, dtime)

	-- remove monsters in peaceful mode
	if self.type == "monster" and minetest_settings:get_bool("only_peaceful_mobs", false) then
		mcl_burning.extinguish(self.object)
		self.object:remove()
		return
	end

	-- load entity variables
	local tmp = minetest.deserialize(staticdata)

	if tmp then
		for _,stat in pairs(tmp) do
			self[_] = stat
		end
	end

	--set up wandering
	if not self.wandering then
		self.wandering = true
	end

	--clear animation
	self.current_animation = nil

	-- select random texture, set model and size
	if not self.base_texture then

		-- compatiblity with old simple mobs textures
		if type(def.textures[1]) == "string" then
			def.textures = {def.textures}
		end

		self.base_texture = def.textures[math_random(1, #def.textures)]
		self.base_mesh = def.mesh
		self.base_size = self.visual_size
		self.base_colbox = self.collisionbox
		self.base_selbox = self.selectionbox
	end

	-- for current mobs that dont have this set
	if not self.base_selbox then
		self.base_selbox = self.selectionbox or self.base_colbox
	end

	-- set texture, model and size
	local textures = self.base_texture
	local mesh = self.base_mesh
	local vis_size = self.base_size
	local colbox = self.base_colbox
	local selbox = self.base_selbox

	-- specific texture if gotten
	if self.gotten == true
	and def.gotten_texture then
		textures = def.gotten_texture
	end

	-- specific mesh if gotten
	if self.gotten == true
	and def.gotten_mesh then
		mesh = def.gotten_mesh
	end

	-- set baby mobs to half size
	if self.baby == true then

		vis_size = {
			x = self.base_size.x * self.baby_size,
			y = self.base_size.y * self.baby_size,
		}

		if def.child_texture then
			textures = def.child_texture[1]
		end

		colbox = {
			self.base_colbox[1] * self.baby_size,
			self.base_colbox[2] * self.baby_size,
			self.base_colbox[3] * self.baby_size,
			self.base_colbox[4] * self.baby_size,
			self.base_colbox[5] * self.baby_size,
			self.base_colbox[6] * self.baby_size
		}
		selbox = {
			self.base_selbox[1] * self.baby_size,
			self.base_selbox[2] * self.baby_size,
			self.base_selbox[3] * self.baby_size,
			self.base_selbox[4] * self.baby_size,
			self.base_selbox[5] * self.baby_size,
			self.base_selbox[6] * self.baby_size
		}
	end

	--stop mobs from reviving
	if not self.dead and not self.health then
		self.health = math_random (self.hp_min, self.hp_max)
	end

	

	if not self.random_sound_timer then
		self.random_sound_timer = math_random(self.random_sound_timer_min,self.random_sound_timer_max)
	end

	if self.breath == nil then
		self.breath = self.breath_max
	end

	-- pathfinding init
	self.path = {}
	self.path.way = {} -- path to follow, table of positions
	self.path.lastpos = {x = 0, y = 0, z = 0}
	self.path.stuck = false
	self.path.following = false -- currently following path?
	self.path.stuck_timer = 0 -- if stuck for too long search for path

	-- Armor groups
	-- immortal=1 because we use custom health
	-- handling (using "health" property)
	local armor
	if type(self.armor) == "table" then
		armor = table.copy(self.armor)
		armor.immortal = 1
	else
		armor = {immortal=1, fleshy = self.armor}
	end
	self.object:set_armor_groups(armor)
	self.old_y = self.object:get_pos().y
	self.old_health = self.health
	self.sounds.distance = self.sounds.distance or 10
	self.textures = textures
	self.mesh = mesh
	self.collisionbox = colbox
	self.selectionbox = selbox
	self.visual_size = vis_size
	self.standing_in = "ignore"
	self.standing_on = "ignore"
	self.jump_sound_cooloff = 0 -- used to prevent jump sound from being played too often in short time
	self.opinion_sound_cooloff = 0 -- used to prevent sound spam of particular sound types

	self.texture_mods = {}
	

	self.v_start = false
	self.timer = 0
	self.blinktimer = 0
	self.blinkstatus = false


	--continue mob effect on server restart
	if self.dead or self.health <= 0 then
		self.object:set_texture_mod("^[colorize:red:120")
	else
		self.object:set_texture_mod("")
	end
			

	-- set anything changed above
	self.object:set_properties(self)

	--update_tag(self)
	--mobs.set_animation(self, "stand")

	-- run on_spawn function if found
	if self.on_spawn and not self.on_spawn_run then
		if self.on_spawn(self) then
			self.on_spawn_run = true --  if true, set flag to run once only
		end
	end

	-- run after_activate
	if def.after_activate then
		def.after_activate(self, staticdata, def, dtime)
	end

	if use_cmi then
		self._cmi_components = cmi.activate_components(self.serialized_cmi_components)
		cmi.notify_activate(self.object, dtime)
	end
end
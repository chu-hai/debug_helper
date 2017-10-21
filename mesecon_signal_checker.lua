local signalchecker_rules = {}
for x = -4, 4 do
	for y = -4, 4 do
		for z = -4, 4 do
			if x ~= 0 or y ~= 0 or z ~= 0 then
				table.insert(signalchecker_rules, vector.new(x, y, z))
			end
		end
	end
end

local node_box = {
	{-0.4375, -0.4375, -0.4375, 0.4375, 0.4375, 0.4375},
	{0.4375, -0.5, -0.5, 0.5, 0.5, -0.4375},
	{0.4375, -0.5, -0.5, 0.5, -0.4375, 0.5},
	{0.4375, -0.5, 0.4375, 0.5, 0.5, 0.5},
	{0.4375, 0.4375, -0.5, 0.5, 0.5, 0.5},
	{-0.5, -0.5, 0.4375, -0.4375, 0.5, 0.5},
	{-0.5, -0.5, -0.5, -0.4375, -0.4375, 0.5},
	{-0.5, -0.5, -0.5, -0.4375, 0.5, -0.4375},
	{-0.5, 0.4375, -0.5, -0.4375, 0.5, 0.5},
	{-0.5, -0.5, -0.5, 0.5, -0.4375, -0.4375},
	{-0.5, 0.4375, -0.5, 0.5, 0.5, -0.4375},
	{-0.5, 0.4375, 0.4375, 0.5, 0.5, 0.5},
	{-0.5, -0.5, 0.4375, 0.5, -0.4375, 0.5}
}

local sel_box = {
	{-0.5, -0.5, -0.5, 0.5, 0.5, 0.5}
}


-------------------------------------------
----  Local functions
-------------------------------------------
local function mesecon_checker_on_place(itemstack, placer, pointed_thing)
	if not pointed_thing.type == "node" then
		return itemstack
	end

	local under_node = minetest.get_node(pointed_thing.under)
	if not under_node then
		return
	end
	local under_def = minetest.registered_nodes[under_node.name]
	if under_def and under_def.on_rightclick then
		return under_def.on_rightclick(pointed_thing.under, under_node, placer, itemstack, pointed_thing)
	end

	local above_node = minetest.get_node(pointed_thing.above)
	local above_def = minetest.registered_nodes[above_node.name]
	if above_def and not above_def.buildable_to then
		return itemstack
	end

	local node = {name = "debug_helper:mesecon_checker_off"}
	local pos = pointed_thing.above

	minetest.set_node(pos, node)
	mesecon.execute_autoconnect_hooks_now(pos, node)

	for _, r in ipairs(signalchecker_rules) do
		if mesecon.is_powered(pos, r) then
			minetest.set_node(pos, {name = "debug_helper:mesecon_checker_on"})
			break
		end
	end

	if not minetest.settings:get_bool("creative_mode") then
		itemstack:take_item()
	end
	return itemstack
end


--------------------------------------
-- Node definitions
--------------------------------------

-- Mesecon Signal Checker
for _, stat in ipairs({"on", "off"}) do
	local tile
	local not_in_c_inv = nil
	local light_source = nil
	local action_on = nil
	local action_off = nil

	if stat == "off" then
		tile = "debug_helper_mesecon_checker_off.png"
		action_on = function(pos, node)
			node.name = "debug_helper:mesecon_checker_on"
			minetest.swap_node(pos, node)
		end
	else
		not_in_c_inv = 1
		tile = "debug_helper_mesecon_checker_on.png"
		light_source = default.LIGHT_MAX
		action_off = function(pos, node)
			node.name = "debug_helper:mesecon_checker_off"
			minetest.swap_node(pos, node)
		end
	end

	minetest.register_node("debug_helper:mesecon_checker_" .. stat, {
		description = "Mesecon Signal Checker",
		tiles = {tile},
		paramtype = "light",
		drawtype = "nodebox",
		node_box = {
			type = "fixed",
			fixed = node_box
		},
		selection_box = {
			type = "fixed",
			fixed = sel_box
		},

		light_source = light_source,
		groups = {dig_immediate = 2, not_in_creative_inventory = not_in_c_inv},
		sounds = default.node_sound_glass_defaults(),
		drop = "debug_helper:mesecon_checker_off",
		on_place = mesecon_checker_on_place,
		mesecons = {
			effector = {
				rules = signalchecker_rules,
				action_on = action_on,
				action_off = action_off
			}
		}
	})
end
minetest.register_alias("debug_helper:mesecon_checker", "debug_helper:mesecon_checker_off")
debug_helper.itemlist_register_item("debug_helper:mesecon_checker")

-- Mesecon Signal Emitter
for _, stat in ipairs({"on", "off"}) do
	local tile
	local not_in_c_inv = nil
	local light_source = nil
	local mesecon_state = nil
	local on_punch = nil

	if stat == "off" then
		tile = "debug_helper_mesecon_emitter_off.png"
		mesecon_state = mesecon.state.off
		on_punch = function(pos, node)
			node.name = "debug_helper:mesecon_emitter_on"
			minetest.swap_node(pos, node)
			mesecon.receptor_on(pos, signalchecker_rules)
		end
	else
		not_in_c_inv = 1
		tile = "debug_helper_mesecon_emitter_on.png"
		light_source = default.LIGHT_MAX
		mesecon_state = mesecon.state.on
		on_punch = function(pos, node)
			node.name = "debug_helper:mesecon_emitter_off"
			minetest.swap_node(pos, node)
			mesecon.receptor_off(pos, signalchecker_rules)
		end
	end

	minetest.register_node("debug_helper:mesecon_emitter_" .. stat, {
		description = "Mesecon Signal Emitter",
		tiles = {tile},
		paramtype = "light",
		drawtype = "nodebox",
		node_box = {
			type = "fixed",
			fixed = node_box
		},
		selection_box = {
			type = "fixed",
			fixed = sel_box
		},

		light_source = light_source,
		groups = {dig_immediate = 2, not_in_creative_inventory = not_in_c_inv},
		sounds = default.node_sound_glass_defaults(),
		drop = "debug_helper:mesecon_emitter_off",
		on_punch = on_punch,
		mesecons = {
			receptor = {
				state = mesecon_state,
				rules = signalchecker_rules
			}
		}
	})
end

minetest.register_alias("debug_helper:mesecon_emitter", "debug_helper:mesecon_emitter_off")
debug_helper.itemlist_register_item("debug_helper:mesecon_emitter")

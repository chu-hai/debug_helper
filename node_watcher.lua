-------------------------------------
-- Local functions
--------------------------------------
local function sorted_pairs(tbl)
	local sorted = {}
	for k, _ in pairs(tbl) do
		table.insert(sorted, k)
	end
	table.sort(sorted)

	local i = 0
	return function()
		i = i + 1
		if i > #sorted then
			return nil,nil
		else
			local k = sorted[i]
			return k, tbl[k]
		end
	end
end

local function convert_table(tbl, parents)
	local result = {}
	for k, v in sorted_pairs(tbl) do
		local p = parents and table.copy(parents) or {}
		if type(v) == "table" then
			table.insert(p, k)
			for _, data in ipairs(convert_table(v, p)) do
				table.insert(result, data)
			end
		else
			local data = v
			if p[1] and p[1] == "inventory" then
				if v:get_name() ~= "" then
					data = ("%s %s"):format(v:get_name(), v:get_count())
				else
					data = "** empty **"
				end
			end
			table.insert(result, {parents = p, name = k, data = data})
		end
	end

	return result
end

local function create_table_data(tbl, idx)
	local result = ""
	local parent_color = "#c0c0ff"

	for i, v in ipairs(tbl) do
		local name = table.concat(v.parents, ".") .. "." .. v.name
		result = result .. (#result ~= 0 and "," or "")
		result = result .. ("%s,%s,%s,%s"):format(i == idx and 1 or 0,
												parent_color,
												name,
												string.gsub(tostring(minetest.formspec_escape(v.data)), "\n", "\\\\n")												)
	end

	result = result .. (";%d]"):format(idx)
	return result
end

local function create_formspec(pos, player)
	local meta = minetest.get_meta(pos)
	local node = minetest.get_node(pos)
	local t_pos = vector.add(pos, minetest.wallmounted_to_dir(node.param2))
	local t_meta = minetest.get_meta(t_pos)
	local t_name = minetest.get_node(t_pos).name
	if not minetest.registered_nodes[t_name] then
		debug_helper.send_message(player:get_player_name(), "Can not watch unknown node.", debug_helper.MSG_COLOR.WARN)
		return
	end
	local t_desc = minetest.registered_nodes[t_name].description
	local t_table = convert_table(t_meta:to_table())

	local form = "size[10,7]" ..
				 "background[0,0;10,7;debug_helper_form_bg.png;true]" ..
				 "bgcolor[#00000000]" ..
				 "label[0,0;Node Watcher]" ..
				 "checkbox[0.5,0.5;node_watching;Enable node watching;" .. meta:get_string("node_watching") .. "]" ..
				 "field[5,0.8;4.8,1;msg_receiver;Message Receiver;" .. meta:get_string("msg_receiver") .. "]" ..
				 "box[0.5,1.5;1,1;#101010]" ..
				 "button[0.5,6.5;2,0.7;refresh;Refresh]" ..
				 "button_exit[7.5,6.5;2,0.7;exit;Exit]" ..
				 "item_image[0.6,1.55;1,1;" .. t_name .. "]" ..
				 "label[1.8,1.56;" .. string.gsub(t_desc, "\n", "\\\\n") .. "]" ..
				 "label[1.8,2.06;" .. t_name .. "]" ..
				 "tablecolumns[image,1=debug_helper_node_watcher_checkicon.png,width=2;color,span=1;text;text]" ..
				 "tableoptions[color=#e0e0e0;highlight_text=#e0e0e0;background=#303030;highlight=#404040]" ..
				 "table[0.5,3;8.8,3;meta_fields;" .. create_table_data(t_table, meta:get_int("selected_index"))

	meta:set_string("target_meta_fields", minetest.serialize(t_table))
	return form
end

local function show_formspec(pos, player)
	local formspec = create_formspec(pos, player)
	if formspec then
		local formname = "debug_helper:node_watcher_" .. minetest.pos_to_string(pos)
		minetest.show_formspec(player:get_player_name(), formname, formspec)
	end
end

local function update_infotext(pos, meta)
	if meta:get_string("node_watching") == "true" then
		meta:set_string("infotext", "Message Receiver: " .. meta:get_string("msg_receiver"))
	else
		meta:set_string("infotext", "Disabled")
	end
end

local function on_punch(pos, node, puncher)
	local meta = minetest.get_meta(pos)
	meta:set_int("counter", 0)
	update_infotext(pos, meta)
end

local function on_rightclick(pos, node, clicker, itemstack, pointed_thing)
	show_formspec(pos, clicker)
end

local function after_place_node(pos, placer, itemstack, pointed_thing)
	local meta = minetest.get_meta(pos)
	meta:set_int("counter", 0)

	meta:set_string("node_watching", "false")
	meta:set_string("msg_receiver", placer:get_player_name())
	meta:set_int("selected_index", 1)
	meta:set_string("selected_data_cache", minetest.serialize(""))
	update_infotext(pos, meta)
end


--------------------------------------
-- Register callbacks
--------------------------------------
minetest.register_on_player_receive_fields(function(player, formname, fields)
	if not string.match(formname, "^debug_helper:node_watcher_") then
		return
	end

	local playername = player:get_player_name()
	local pos = minetest.string_to_pos(string.sub(formname, string.len("debug_helper:node_watcher_") + 1))
	local meta = minetest.get_meta(pos)
	local need_update = false

	if fields.node_watching then
		meta:set_string("node_watching", fields.node_watching)
		meta:set_int("counter", 0)
		need_update = true
	end

	if fields.msg_receiver then
		meta:set_string("msg_receiver", fields.msg_receiver)
		need_update = true
	end

	if fields.refresh then
		need_update = true
	end

	if fields.meta_fields then
		local clicked = minetest.explode_table_event(fields.meta_fields)
		local table = minetest.deserialize(meta:get_string("target_meta_fields"))
		meta:set_int("selected_index", clicked.row)
		meta:set_string("selected_data_cache", minetest.serialize(table[clicked.row]))
	end

	if fields.exit then
		return true
	end

	if need_update then
		update_infotext(pos, meta)
		show_formspec(pos, player)
	end
end)


--------------------------------------
-- ABM
--------------------------------------
minetest.register_abm({
	nodenames = {"debug_helper:node_watcher"},
	interval = 1.0,
	chance = 1,
	action = function(pos, node, active_object_count, active_object_count_wider)
		local function read_target_metadata(t_meta, tbl)
			if not tbl then
				return ""
			end
			if not t_meta then
				return "Can't get target meta data."
			end

			local result = ""
			local tm = t_meta:to_table()
			for _, v in ipairs(tbl.parents) do
				if not tm[v] then
					break
				end
				tm = tm[v]
			end

			if tm then
				local data = tm[tbl.name]
				if tbl.parents[1] == "inventory" then
					if data:get_name() ~= "" then
						result = ("%s %s"):format(data:get_name(), data:get_count())
					else
						result = "** empty **"
					end
				else
					result = string.gsub(tostring(data), "\n", "\\\\n")
				end
				result = table.concat(tbl.parents, ".") .. "." .. tbl.name .. " - " .. result
			end
			return #result > 80 and string.sub(result, 0, 80) .. "..." or result
		end

		local meta = minetest.get_meta(pos)
		if meta:get_string("node_watching") == "false" then
			return
		end

		local cnt = meta:get_int("counter") + 1
		local receiver = meta:get_string("msg_receiver")

		local data = minetest.deserialize(meta:get_string("selected_data_cache"))
		if data == "" then
			local table = minetest.deserialize(meta:get_string("target_meta_fields"))
			data = table[meta:get_int("selected_index")]
			meta:set_string("selected_data_cache", minetest.serialize(data))
		end

		local t_pos = vector.add(pos, minetest.wallmounted_to_dir(node.param2))
		local t_meta = minetest.get_meta(t_pos)
		local msg = ("Counter:%d [%s]"):format(cnt, read_target_metadata(t_meta, data))
		debug_helper.send_message(receiver, msg, debug_helper.MSG_COLOR.INFO)
		meta:set_int("counter", cnt)
		update_infotext(pos, meta)
	end
})


--------------------------------------
-- Node definitions
--------------------------------------
minetest.register_node("debug_helper:node_watcher", {
	description = "Node Watcher",
	tiles = {
		"debug_helper_node_watcher.png"
	},
	drawtype = "nodebox",
	node_box = {
		type = "wallmounted",
		wall_top    = {-0.25, 0.25, -0.25, 0.25, 0.5, 0.25},
		wall_bottom = {-0.25, -0.5, -0.25, 0.25, -0.25, 0.25},
		wall_side   = {-0.5, -0.25, -0.25, -0.25, 0.25, 0.25},
	},
	walkable = true,
	groups = {dig_immediate = 2, attached_node = 1},
	paramtype = "light",
	paramtype2 = "wallmounted",
	sunlight_propagates = true,

	sounds = default.node_sound_stone_defaults(),

	on_rotate = screwdriver.disallow,
	after_place_node = after_place_node,
	on_rightclick = on_rightclick,
	on_punch = on_punch,
})

debug_helper.itemlist_register_item("debug_helper:node_watcher")

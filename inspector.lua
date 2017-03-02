local player_datas = {}

local target_types = {
	NODE   = "node",
	OBJECT = "object"
}

local detail_types = {
	[target_types.NODE] = {
		"Meta data",
		"Node definition"
	},
	[target_types.OBJECT] = {
		"LuaEntity",
		"Object Methods",
		"Object Properties"
	}
}

local formspec_prefix = "debug_helper:ui_inspector_"

-------------------------------------------
----  Local functions
-------------------------------------------
local function remove_player_data(playername)
	player_datas[playername] = nil
end

local function set_player_data(player, pos, target_type, detail_idx, object_id)
	local playername = player:get_player_name()

	if not player_datas[playername] then
		player_datas[playername] = {
			pos = nil,
			object_id = nil,
			target_type = nil,
			detail_type_idx = {
				[target_types.NODE] = 1,
				[target_types.OBJECT] = 1
			}
		}
	end

	if pos then
		player_datas[playername].pos = vector.new(pos)
	end
	if object_id then
		player_datas[playername].object_id = object_id
	end
	if target_type then
		player_datas[playername].target_type = target_type
	end
	if detail_idx then
		player_datas[playername].detail_type_idx[target_type] = detail_idx
	end
end

local function get_player_data(playername)
	if player_datas[playername] then
		return player_datas[playername]
	end
	return nil
end

local function get_object_id(object)
	for k, v in pairs(minetest.object_refs) do
		if v == object then
			return k
		end
	end
	return nil
end

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

local function convert_table(tbl, tree_level, inventory_mode)
	local result = ""
	local parent_color = "#c0c0ff"
	local child_color  = "#a0a0a0"

	for k, v in sorted_pairs(tbl) do
		local line = ""
		if type(v) == "table" then
			line = line .. ("%d,%s,%s,%s"):format(tree_level, parent_color, k, inventory_mode and #v .. " slot(s)" or "")
			local sub_tree = convert_table(v, tree_level + 1, (k == "inventory") and true or inventory_mode)
			line = line .. ("%s%s"):format(#sub_tree ~= 0 and "," or "", sub_tree)
		else
			if inventory_mode then
				local i_name = v:get_name()
				local i_desc = "** Unknown item **"
				local i_count = v:get_count()
				if minetest.registered_items[i_name] then
					i_desc = minetest.registered_items[i_name].description
				end

				if i_count > 0 then
					line = line .. ("%d,%s,%s,%s"):format(tree_level, child_color, k,
							("%s: %d (%s)"):format(i_desc, i_count, i_name))
				end
			else
				line = line .. ("%d,%s,%s,%s"):format(tree_level, child_color, k,
						string.gsub(minetest.formspec_escape(tostring(v)), "\n", "\\\\n"))
			end
		end

		result = result .. ("%s%s"):format((#result ~= 0 and #line ~= 0) and "," or "", line)
	end
	return result
end

local function create_formspec_for_node(playername, data)
	local node = minetest.get_node(data.pos)
	local meta = minetest.get_meta(data.pos)
	local ndef = minetest.registered_nodes[node.name]
	if not ndef then
		debug_helper.send_message(playername, "Can not inspect unknown node.", debug_helper.MSG_COLOR.WARN)
		debug_helper.send_message(playername, ("[%s]"):format(node.name), debug_helper.MSG_COLOR.NORMAL)
		return nil
	end

	-- Item icon / Description
	local formspec = "size[12,9.3]" ..
		"background[0,0;12,9.3;debug_helper_form_bg.png;true]" ..
		"bgcolor[#00000000]" ..
		"label[0,0;" .. string.gsub(ndef.description, "\n", "\\\\n") .. "]" ..
		"box[0,0.65;1,1;#202020]" ..
		"item_image[0.1,0.7;1,1;" .. node.name .. "]"

	-- Node data(pos, name, param, param2, light, timer)
	local line = "#c0c0ff,Position," .. minetest.formspec_escape(minetest.pos_to_string(data.pos))
	for k, v in sorted_pairs(node) do
		line = line .. (",#c0c0ff,%s,%s"):format(k, v)
	end
	local light = minetest.get_node_light(data.pos)
	line = line .. (",#c0c0ff,%s,%s"):format("Light Level", light)

	local timer = minetest.get_node_timer(data.pos)
	line = line .. (",#c0c0ff,%s,%s"):format("Timer.timeout", timer:get_timeout())
	line = line .. (",#c0c0ff,%s,%s"):format("Timer.elapsed", timer:get_elapsed())
	line = line .. (",#c0c0ff,%s,%s"):format("Timer.is_started", timer:is_started())

	formspec = formspec ..
		"tablecolumns[color,span=1;text,width=7.5;text]" ..
		"tableoptions[color=#e0e0e0;highlight_text=#e0e0e0;background=#303030;highlight=#404040]" ..
		"table[1.5,0.65;10,1.5;node_data;" .. line .. ";1]"

	-- Meta data / Node definition
	local details = ""
	local formspec_name = formspec_prefix
	local detail_idx = data.detail_type_idx[data.target_type]
	for _, v in ipairs(detail_types[target_types.NODE]) do
		details = details .. ("%s%s"):format(#details ~= 0 and "," or "", v)
	end
	formspec = formspec ..
		"dropdown[0.2,2.5;3;detail_type;" .. details .. ";" .. detail_idx .. "]" ..
		"tablecolumns[tree;color,span=1;text,width=7;text]" ..
		"tableoptions[color=#e0e0e0;highlight_text=#e0e0e0;background=#303030;highlight=#404040;opendepth=3]"

	if detail_idx == 1 then
		formspec = formspec .. "table[0.2,3.5;11.3,5;detail;" .. convert_table(meta:to_table(), 1) .. ";1]"
		formspec_name = formspec_name .. "metadata"
	else
		formspec = formspec .. "table[0.2,3.5;11.3,5;detail;" .. convert_table(ndef, 1) .. ";1]"
		formspec_name = formspec_name .. "nodedata"
	end

	-- Other buttons
	formspec = formspec .. "button[3.5,2.55;2,0.7;refresh;Refresh]"
	formspec = formspec .. "button_exit[10,8.8;2,0.7;exit_button;Exit]"

	return formspec, formspec_name
end

local function create_formspec_for_object(playername, data)
	local obj = minetest.object_refs[data.object_id]
	if not obj then
		debug_helper.send_message(playername, "Can not inspect object. (object is nil)", debug_helper.MSG_COLOR.WARN)
		return nil
	end

	local luaentity = obj:get_luaentity()
	if obj:is_player() then
		debug_helper.send_message(playername, "Can not inspect player.", debug_helper.MSG_COLOR.WARN)
		return nil
	elseif not luaentity then
		debug_helper.send_message(playername, "Can not inspect object. (luaentity is nil)", debug_helper.MSG_COLOR.WARN)
		return nil
	end

	local formspec = "size[12,9.3]" ..
		"background[0,0;12,9.3;debug_helper_form_bg.png;true]" ..
		"bgcolor[#00000000]" ..
		"label[0,0;Object ID: " .. tostring(data.object_id) .. "]" ..
		"label[2,0;LuaEntity Name: " .. luaentity.name .. "]"

	local details = ""
	local formspec_name = formspec_prefix
	local detail_idx = data.detail_type_idx[data.target_type]
	for _, v in ipairs(detail_types[target_types.OBJECT]) do
		details = details .. ("%s%s"):format(#details ~= 0 and "," or "", v)
	end
	formspec = formspec ..
		"dropdown[0.2,0.7;3;detail_type;" .. details .. ";" .. detail_idx .. "]" ..
		"tablecolumns[tree;color,span=1;text,width=7;text]" ..
		"tableoptions[color=#e0e0e0;highlight_text=#e0e0e0;background=#303030;highlight=#404040;opendepth=3]"

	local table = {}
	if detail_idx == 1 then
		-- luaentity table
		table = luaentity
		table.name = luaentity.name
		formspec_name = formspec_name .. "luaentity"
	elseif detail_idx == 2 then
		-- object method table
		table["getpos()"] = obj:getpos()
		table["get_hp()"] = obj:get_hp()
		table["get_inventory()"] = obj:get_inventory()
		table["get_wield_list()"] = obj:get_wield_list()
		table["get_wield_index()"] = obj:get_wield_index()
		table["get_armor_groups()"] = obj:get_armor_groups()
		table["get_animation()"] = obj:get_animation()
		table["get_attach()"] = obj:get_attach()
		table["is_player()"] = obj:is_player()
		table["get_nametag_attributes()"] = obj:get_nametag_attributes()
		table["getvelocity()"] = obj:getvelocity()
		table["getacceleration()"] = obj:getacceleration()
		table["getyaw()"] = obj:getyaw()
		formspec_name = formspec_name .. "object_methods"
	else
		-- object property table
		table = obj:get_properties()
		formspec_name = formspec_name .. "object_properties"
	end
	formspec = formspec .. "table[0.5,1.65;11.3,6.7;detail;" .. convert_table(table, 1) .. ";1]"

	-- Other buttons
	formspec = formspec .. "button[3.5,0.75;2,0.7;refresh;Refresh]"
	formspec = formspec .. "button_exit[10,8.8;2,0.7;exit_button;Exit]"

	return formspec, formspec_name
end

local function create_formspec(playername)
	local data = get_player_data(playername)
	if not data then
		debug_helper.send_message(playername, "Failed to create formspec: player data not found.", debug_helper.MSG_COLOR.ERROR)
		return nil
	end

	if data.target_type == target_types.NODE then
		return create_formspec_for_node(playername, data)
	else
		return create_formspec_for_object(playername, data)
	end
end


-------------------------------------------
----  Register callbacks
-------------------------------------------
minetest.register_on_leaveplayer(function(player)
	remove_player_data(player:get_player_name())
end)

minetest.register_on_player_receive_fields(function(player, formname, fields)
	local function get_detail_types_idx(target, detail_type_str)
		for i, v in ipairs(detail_types[target]) do
			if v == detail_type_str then
				return i
			end
		end
		return 1
	end

	local playername = player:get_player_name()
	if string.match(formname, "^" .. formspec_prefix) then
		local data = get_player_data(playername)
		if not data then
			debug_helper.send_message(playername, "Failed to create formspec: player data not found.", debug_helper.MSG_COLOR.ERROR)
			return
		end

		if fields.detail_type then
			local target_type = data.target_type
			local detail_idx = get_detail_types_idx(target_type, fields.detail_type)
			set_player_data(player, nil, target_type, detail_idx)
		end

		if fields.refresh or (fields.detail_type and not fields.detail) then
			local formspec, formname = create_formspec(playername)
			if formspec then
				minetest.show_formspec(playername, formname, formspec)
			end
		end
		return true
	end
end)


-------------------------------------------
----  Tool definitions
-------------------------------------------
minetest.register_tool("debug_helper:inspector", {
	description = "Inspector",
	inventory_image = "debug_helper_inspector.png",
	on_use = function(itemstack, user, pointed_thing)
		local playername = user:get_player_name()
		if pointed_thing.type == "node" then
			local pos = pointed_thing.under
			set_player_data(user, pos, target_types.NODE)
		elseif pointed_thing.type == "object" then
			set_player_data(user, nil, target_types.OBJECT, nil, get_object_id(pointed_thing.ref))
		else
			return
		end

		local formspec, formname = create_formspec(playername)
		if formspec then
			minetest.show_formspec(playername, formname, formspec)
		end
	end
})

debug_helper.itemlist_register_item("debug_helper:inspector")

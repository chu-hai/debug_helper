local target_types = {
	NODE   = "node",
	PLAYER = "player"
}

local locations = {
	[target_types.PLAYER] = {
		"current_player"
	},
	[target_types.NODE] = {
		"context",
		"current_name"
	}
}

local formspec_name = "debug_helper:ui_inv_viewer"

local player_data = {}


-------------------------------------------
----  Local functions
-------------------------------------------
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

local function convert_table(tbl, tree_level)
	local result = ""
	local parent_color = "#c0c0ff"
	local child_color  = "#a0a0a0"

	for k, v in sorted_pairs(tbl) do
		local line = ""
		if type(v) == "table" then
			line = line .. ("%d,%s,%s,"):format(tree_level, parent_color, k)
			local sub_tree = convert_table(v, tree_level + 1)
			line = line .. ("%s%s"):format(#sub_tree ~= 0 and "," or "", sub_tree)
		else
			line = line .. ("%d,%s,%s,%s"):format(tree_level, child_color, k,
					string.gsub(minetest.formspec_escape(tostring(v)), "\n", "\\\\n"))
		end

		result = result .. ("%s%s"):format((#result ~= 0 and #line ~= 0) and "," or "", line)
	end
	return result
end

local function create_formspec(playername)
	local data = player_data[playername]
	local invdef = data.inv_def[data.sel_list]
	local invdata = data.inv_data[invdef.name]

	local formspec = "size[9,10]" ..
		"background[0,0;12,8;debug_helper_form_bg.png;true]" ..
		"bgcolor[#00000000]" ..
		"label[0.5,0.2;" .. minetest.formspec_escape(data.title) .. "]" ..
		"label[0.5,0.9;Inventory]" ..
		"button[6.5,0.86;2,0.7;refresh;Refresh]" ..
		"box[0.4,2.45;8,4;#2f2f2f]"

	-- Inventory List Dropdown
	local list_index = 1
	for i, v in ipairs(data.inv_list) do
		if v == data.sel_list then
			list_index = i
			break
		end
	end
	formspec = formspec .. "dropdown[2.5,0.8;3;inv_list;" ..
		table.concat(data.inv_list, ",") .. ";" .. list_index .. "]"

	-- Combine Player Inventory Checkbox
	formspec = formspec .. "checkbox[0.5,1.4;combine_pinv;Combine Player Inventory;" ..
		tostring(data.combine_pinv) .. "]"

	-- Inventory Buttons
	local height = invdef.height
	local width = invdef.width
	local step = math.min(math.min(4 / height, 8 / width), 1)
	local size = math.min(math.min(4 / height, 8 / width), 1)
	local imgbtn = "item_image_button[%f,%f;%f,%f;%s;%s;]"
	for h = 0, height - 1 do
		for w = 0, width - 1 do
			local idx = invdef.start + 1 + w + h * width
			local itemname = invdata[idx]:get_name()
			formspec = formspec .. imgbtn:format(
				0.5 + step * w,
				2.5 + step * h,
				size,
				size,
				itemname,
				"invbtn_" .. idx
			)

			if data.sel_idx == idx then
				formspec = formspec	.. ("box[%f,%f;%f,%f;#60c0ff]"):format(
					0.4  + step * w,
					2.45 + step * h,
					size,
					size
				)
			end
		end
	end

	-- Item Detail
	local stack = invdata[data.sel_idx]
	local item_detail = ""
	if stack and stack:get_name() ~= "" then
		item_detail = convert_table(stack:to_table(), 1)
	end

	formspec = formspec ..
		"tablecolumns[tree;color,span=1;text,width=7;text]" ..
		"tableoptions[color=#e0e0e0;highlight_text=#e0e0e0;background=#303030;highlight=#404040;opendepth=3]" ..
		"table[0.4,7;8,3;detail;" .. item_detail .. ";1]"

	return formspec
end

local function get_invdef(formspec, target_type, combine_pinv)
	local function convert_formspec(formspec)
		local tbl = {}
		for _, v in ipairs(string.split(formspec:gsub("%s+", ""), "]", false, -1)) do
			table.insert(tbl, string.split(v, "["))
		end
		return tbl
	end
	local list = {}
	local list_names = {}
	for _, v in ipairs(convert_formspec(formspec)) do
		if v[1] == "list" then
			local fields = string.split(v[2], ";")
			for _, loc in ipairs(locations[target_type]) do
				if fields[1] == loc then
					local size = string.split(fields[4], ",")
					local listname = fields[2]
					if list_names[listname] then
						if combine_pinv and listname == "main" and loc == "current_player" then
							list[listname] = {
								loc = loc,
								name = fields[2],
								width = "8",
								height = "4",
								start = "0"
							}
							listname = nil
						else
							list_names[listname] = list_names[listname] + 1
							listname = ("%s_%d"):format(listname, list_names[listname])
						end
					else
						list_names[listname] = 1
					end
					if listname then
						list[listname] = {
							loc = loc,
							name = fields[2],
							width = size[1],
							height = size[2],
							start = fields[5] or "0"
						}
					end
				end
			end
		end
	end
	return list
end

local function get_invlist(invdef)
	local tbl = {}
	for name, _ in sorted_pairs(invdef) do
		table.insert(tbl, name)
	end
	return tbl
end

local function get_invdata(inv, invdef)
	local invdata = {}
	for name, list in pairs(inv:get_lists()) do
		if invdef[name] then
			invdata[name] = {}
			for i, item in ipairs(list) do
				invdata[name][i] = ItemStack(item)
			end
		end
	end
	return invdata
end

local function get_player_inventory_data(player, target_player)
	local playername = player:get_player_name()
	local targetname = target_player:get_player_name()
	local invdef = get_invdef(target_player:get_inventory_formspec(),
			target_types.PLAYER,
			player_data[playername].combine_pinv)
	local invlist = get_invlist(invdef)

	player_data[playername] = {
		combine_pinv = player_data[playername].combine_pinv,
		type = target_types.PLAYER,
		target = target_player,
		target_name = targetname,
		title = ("Player [%s]"):format(targetname),
		sel_list = invlist[1],
		sel_idx = 0,
		inv_list = invlist,
		inv_def = invdef,
		inv_data = get_invdata(target_player:get_inventory(), invdef),
		formspec = target_player:get_inventory_formspec()
	}
end

local function get_node_inventory_data(player, pos)
	local playername = player:get_player_name()
	local node = minetest.get_node(pos)
	local meta = minetest.get_meta(pos)
	local invdef = get_invdef(meta:get_string("formspec"), target_types.NODE, false)
	local invlist = get_invlist(invdef)

	player_data[playername] = {
		combine_pinv = player_data[playername].combine_pinv,
		type = target_types.NODE,
		target = vector.new(pos),
		target_name = node.name,
		title = ("Node [%s] %s"):format(node.name, minetest.pos_to_string(pos)),
		sel_list = invlist[1],
		sel_idx = 0,
		inv_list = invlist,
		inv_def = invdef,
		inv_data = get_invdata(meta:get_inventory(), invdef),
		formspec = meta:get_string("formspec")
	}
end


-------------------------------------------
----  Register callbacks
-------------------------------------------
minetest.register_on_joinplayer(function(player)
	player_data[player:get_player_name()] = {
		combine_pinv = true
	}
end)

minetest.register_on_leaveplayer(function(player)
	player_data[player:get_player_name()] = nil
end)

minetest.register_on_player_receive_fields(function(player, formname, fields)
	if formname ~= formspec_name then
		return
	end

	local playername = player:get_player_name()
	local refresh = false
	local data = player_data[playername]

	if fields.inv_list and data.sel_list ~= fields.inv_list then
		data.sel_list = fields.inv_list
		data.sel_idx = 0
		refresh = true
	end

	if fields.refresh then
		if data.type == target_types.PLAYER then
			if data.target:get_player_name() == data.target_name then
				get_player_inventory_data(player, data.target)
				refresh = true
			else
				debug_helper.send_message(playername, "Can not refresh. (Target lost)", debug_helper.MSG_COLOR.INFO)
			end
		elseif data.type == target_types.NODE then
			if minetest.get_node(data.target).name == data.target_name then
				get_node_inventory_data(player, data.target)
				refresh = true
			else
				debug_helper.send_message(playername, "Can not refresh. (Target lost)", debug_helper.MSG_COLOR.INFO)
			end
		end
	end

	if fields.combine_pinv then
		local combine_pinv = (fields.combine_pinv == "true")
		data.combine_pinv = combine_pinv

		local invdef = data.inv_def[data.sel_list]
		local invdata = data.inv_data[invdef.name]
		if data.sel_list ~= invdef.name then
			data.sel_list = invdef.name
			data.sel_idx = 0
		end

		local flag = false
		if data.type == target_types.PLAYER then
			flag = combine_pinv
		end
		data.inv_def = get_invdef(data.formspec, data.type, flag)
		data.inv_list = get_invlist(data.inv_def)

		refresh = true
	end

	for name, _ in pairs(fields) do
		if name:match("^invbtn_%d+$") then
			data.sel_idx = tonumber(name:match("%d+$"))
			refresh = true
			break
		end
	end

	if refresh then
		minetest.show_formspec(playername, formspec_name, create_formspec(playername))
	end
end)


-------------------------------------------
----  Tool definitions
-------------------------------------------
minetest.register_tool("debug_helper:inv_viewer", {
	description = "Inventory Viewer",
	inventory_image = "debug_helper_inv_viewer.png",
	on_use = function(itemstack, user, pointed_thing)
		local playername = user:get_player_name()

		if user:get_player_control().sneak or pointed_thing.type == "nothing" then
			get_player_inventory_data(user, user)
		elseif pointed_thing.type == "node" then
			get_node_inventory_data(user, pointed_thing.under)
		elseif pointed_thing.type == "object" then
			local obj = pointed_thing.ref
			if obj:is_player() then
				get_player_inventory_data(user, obj)
			else
				debug_helper.send_message(playername, "Entity is not supported.", debug_helper.MSG_COLOR.INFO)
				return
			end
		end

		if #player_data[playername].inv_list > 0 then
			minetest.show_formspec(playername, formspec_name, create_formspec(playername))
		end
	end
})

debug_helper.itemlist_register_item("debug_helper:inv_viewer")

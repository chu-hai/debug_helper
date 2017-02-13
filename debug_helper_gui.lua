local dh_registered_items = {}
local selected_items = {}
local formspec_name = "debug_helper:dh_itemlist_form"


-------------------------------------------
----  Global functions
-------------------------------------------
function debug_helper.itemlist_register_item(item_name)
	if not minetest.registered_items[item_name] then
		minetest.log("warning", ("[Debug Helper] %s is not registered."):format(item_name))
		return
	end

	local duplicate = false
	for _, v in ipairs(dh_registered_items) do
		if v == item_name then
			minetest.log("warning", ("[Debug Helper] %s is already registered."):format(item_name))
			duplicate = true
			break
		end
	end
	if not duplicate then
		table.insert(dh_registered_items, item_name)
	end
end


-------------------------------------------
----  Functions
-------------------------------------------
local function create_formspec(player_name, item_idx)
	local lines = ""
	for i, v in ipairs(dh_registered_items) do
		local desc = minetest.registered_items[v].description
		lines = lines .. ("%s#a0a0f0,%s,%s"):format((lines ~= "" and "," or ""), desc, v)
	end

	local item_name = ""
	local item_desc = ""
	if #dh_registered_items > 0 then
		item_name = dh_registered_items[item_idx]
		item_desc = minetest.registered_items[item_name].description
	end

	local formspec = "size[10,6.3]" ..
		"background[0,0;10,6.3;debug_helper_form_bg.png;true]" ..
		"bgcolor[#00000000]" ..

		"label[0,0;Debughelper Itemlist]" ..
		"box[0,0.65;1,1;#101010]" ..
		"item_image[0.1,0.7;1,1;" .. item_name .. "]" ..

		"label[1.3,0.71;" .. item_desc .. "]" ..
		"label[1.3,1.21;" .. item_name .. "]" ..

		"label[7,0.5;Give me:]" ..
		"button[7,1;1,0.8;giveme_1;+1]" ..
		"button[8,1;1,0.8;giveme_10;+10]" ..
		"button[9,1;1,0.8;giveme_99;+99]" ..

		"tablecolumns[color,span=1;text;text]" ..
 		"tableoptions[color=#e0e0e0;highlight_text=#f0f0f0;background=#303030;highlight=#404040]" ..
 		"table[0,2;9.8,3.5;itemlist;" .. lines .. ";" .. item_idx .. "]" ..

		"button_exit[8,5.62;2.02,0.8;exit;Exit]"

	selected_items[player_name] = item_name
	return formspec
end


-------------------------------------------
----  Register callbacks
-------------------------------------------
minetest.register_on_leaveplayer(function(player)
	selected_items[player:get_player_name()] = nil
end)

minetest.register_on_player_receive_fields(function(player, formname, fields)
	local playername = player:get_player_name()
	if formname == formspec_name then
		if fields.itemlist then
			local clicked = minetest.explode_table_event(fields.itemlist)
			if clicked and clicked.type == "CHG" then
				local formspec = create_formspec(playername, clicked.row)
				if formspec then
					minetest.show_formspec(playername, formspec_name, formspec)
					return true
				end
			end
		end

		local count = nil
		for k, _ in pairs(fields) do
			count = k:match("giveme_(.*)")
			if count then
				break
			end
		end
		count = tonumber(count)
 		if count and count > 0 then
  			local p_inv = player:get_inventory()
			local item_name = selected_items[playername]
			if item_name ~= "" then
				local item_max = minetest.registered_items[item_name].stack_max or 99
				local add_cnt = math.min(count, item_max)

				local stack = ItemStack({name = selected_items[playername], count = add_cnt})

				if p_inv:room_for_item("main", stack) then
		  			p_inv:add_item("main", stack)
					debug_helper.send_message(player:get_player_name(),
											 ("[%s] add %s item(s) to inventory."):format(item_name, add_cnt),
											 debug_helper.MSG_COLOR.INFO)
				else
					debug_helper.send_message(player:get_player_name(),
											 ("[%s] can't add %s item(s) to inventory."):format(item_name, add_cnt),
											 debug_helper.MSG_COLOR.WARN)
				end
			end
 		end
	end
end)


-------------------------------------------
----  Register Chat commands
-------------------------------------------
minetest.register_chatcommand("dh", {
	params = "",
	description = "Show the DebugHelper's Itemlist form.",
	func = function(name, param)
		minetest.after(0.1, function()	-- workaround for "can't show formspec with command"
			local formspec = create_formspec(name, 1)
			if formspec then
				minetest.show_formspec(name, formspec_name, formspec)
			end
		end)
	end
})

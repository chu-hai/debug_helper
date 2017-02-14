local MAX_LOG_ROW = 15
local FORMSPEC_MAIN = "debug_helper:ui_digilines_logger_main"
local FORMSPEC_DETAIL = "debug_helper:ui_digilines_logger_detail"

local log_buffer = {}
local player_data = {}

-------------------------------------------
----  Local Functions
-------------------------------------------
local function pos_to_string(pos)
	local function val_to_str(val)
		return (val >= 0 and "P" or "N") .. tostring(math.abs(val))
	end
	return val_to_str(pos.x) .. val_to_str(pos.y) .. val_to_str(pos.z)
end

local function add_logdata(pos, channel, msg)
	local meta = minetest.get_meta(pos)
	local pos_str = meta:get_string("pos_str")

	if not log_buffer[pos_str] then
		log_buffer[pos_str] = {}
	end

	local buf = log_buffer[pos_str]
	if #buf >= MAX_LOG_ROW then
		table.remove(buf, 1)
	end
	buf[#buf + 1] = {
		time = os.date("%H:%M:%S"),
		channel = channel,
		msg = msg
	}
end

local function create_formspec_main(playername)
	local data = ""
	local separater = ""
	local pos_str = pos_to_string(player_data[playername].pos)
	local idx = #log_buffer[pos_str]

	for _, v in ipairs(log_buffer[pos_str]) do
		local msg = minetest.formspec_escape(string.gsub(dump(v.msg), "\n", ""))
		data = data .. ("%s%s,%s,%s,%s"):format(separater, v.time, "#f0e0e0", v.channel, msg)
		separater = ","
	end

	local formspec = "" ..
		"size[12,8]" ..
		"background[0,0;12,8;debug_helper_form_bg.png;true]" ..
		"bgcolor[#00000000]" ..
		"label[0.2,0.2;Digilines Log (Main)]" ..
		"button[0.4,7.2;2,0.7;clear;Clear]" ..
		"button[9.6,7.3;2,0.7;refresh;Refresh]" ..
		"tablecolumns[text;color,span=1;text;text]" ..
		"tableoptions[color=#ffffff;highlight_text=#ffffff;background=#303030;highlight=#404040]" ..
		"table[0.4,1;11,6;logdata;" .. data .. ";" .. idx .. "]"

	return formspec
end

local function create_formspec_detail(playername, row)
	local data = player_data[playername].logcache[row]
	local msg = (dump(data.msg)):gsub("\t", "        ")
	local formspec = "" ..
		"size[12,8]" ..
		"background[0,0;12,8;debug_helper_form_bg.png;true]" ..
		"bgcolor[#00000000]" ..
		"label[0.2,0.2;Digilines Log (Detail)]" ..
		"label[0.4,0.8;Time: " .. data.time .. "]" ..
		"label[3.4,0.8;Channel: " .. data.channel .. "]" ..
		"button[9.6,7.3;2,0.7;close;Close]" ..
		"textarea[0.7,1.5;11.2,6.5;detail;;" .. minetest.formspec_escape(msg) .. "]"
	return formspec
end

local function on_construct(pos)
	local meta = minetest.get_meta(pos)
	meta:set_string("pos_str", pos_to_string(pos))
end

local function on_rightclick(pos, node, clicker, itemstack, pointed_thing)
	local playername = clicker:get_player_name()
	local pos_str = pos_to_string(pos)

	if not log_buffer[pos_str] then
		log_buffer[pos_str] = {}
	end

	player_data[playername] = {
		pos = vector.new(pos),
		logcache = table.copy(log_buffer[pos_str])
	}
	minetest.show_formspec(playername, FORMSPEC_MAIN, create_formspec_main(playername))
end

local function on_timer(pos, elapsed)
	local node = minetest.get_node(pos)
	node.name = "debug_helper:digilines_logger_off"
	minetest.swap_node(pos, node)

	return false
end

local function after_dig_node(pos, oldnode, oldmetadata, digger)
	log_buffer[pos_to_string(pos)] = nil
end

local function digiline_receive(pos, node, channel, msg)
	local meta = minetest.get_meta(pos)
	if node.name == "debug_helper:digilines_logger_off" then
		node.name = "debug_helper:digilines_logger_on"
		minetest.swap_node(pos, node)
	end
	add_logdata(pos, channel, msg)
	minetest.get_node_timer(pos):start(2)
	minetest.sound_play("debug_helper_info", {pos = pos})
end


-------------------------------------------
----  Register callbacks
-------------------------------------------
minetest.register_on_leaveplayer(function(player)
	player_data[player:get_player_name()] = nil
end)

minetest.register_on_player_receive_fields(function(player, formname, fields)
	local playername = player:get_player_name()

	if formname == FORMSPEC_MAIN then
		local pos_str = pos_to_string(player_data[playername].pos)
		if fields.logdata and #player_data[playername].logcache > 0 then
			local clicked = minetest.explode_table_event(fields.logdata)
			if clicked and clicked.type == "DCL" then
				local formspec = create_formspec_detail(playername, clicked.row)
				if formspec then
					minetest.show_formspec(playername, FORMSPEC_DETAIL, formspec)
				end
			end
		end
		if fields.clear then
			log_buffer[pos_str] = {}
			player_data[playername].logcache = {}
		end
		if fields.refresh or fields.clear then
			if fields.refresh then
				player_data[playername].logcache = table.copy(log_buffer[pos_str])
			end

			local formspec = create_formspec_main(playername)
			if formspec then
				minetest.show_formspec(playername, FORMSPEC_MAIN, formspec)
			end
		end
		if fields.quit then
			player_data[playername] = nil
		end
		return true
	elseif formname == FORMSPEC_DETAIL then
		if fields.close then
			local formspec = create_formspec_main(playername)
			if formspec then
				minetest.show_formspec(playername, FORMSPEC_MAIN, formspec)
			end
		end
		if fields.quit then
			player_data[playername] = nil
		end
		return true
	end
end)


-------------------------------------------
----  Node definitions
-------------------------------------------
for _, stat in pairs({"on", "off"}) do
	minetest.register_node("debug_helper:digilines_logger_" .. stat, {
		description = "Digilines Message Logger",
		tiles = {
				"debug_helper_logger_top.png",
				"debug_helper_logger_bottom.png",
				"debug_helper_logger_right_" .. stat .. ".png",
				"debug_helper_logger_left_" .. stat .. ".png",
				"debug_helper_logger_back_" .. stat .. ".png",
				"debug_helper_logger_front_" .. stat .. ".png"
		},
		drawtype = "nodebox",
		node_box = {
			type = "fixed",
			fixed = {
				{-0.5, -0.5, -0.5, 0.5, -0.1875, 0.5},
				{0.1875, -0.1875, 0.125, 0.375, 0.4375, 0.3125},
			}
		},

		paramtype = "light",
		paramtype2 = "facedir",
		sunlight_propagates = true,
		walkable = true,
		groups = {dig_immediate = 2, not_in_creative_inventory = ((stat == "on") and 1 or nil)},
		sounds = default.node_sound_stone_defaults(),

		on_construct = on_construct,
		on_rightclick = on_rightclick,
		on_timer = (stat == "on") and on_timer or nil,
		after_dig_node = after_dig_node,

		digiline = {
			effector = {
				action = digiline_receive
			}
		}
	})
end

minetest.register_alias("debug_helper:digilines_logger", "debug_helper:digilines_logger_off")
debug_helper.itemlist_register_item("debug_helper:digilines_logger")

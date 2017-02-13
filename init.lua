debug_helper = {}

debug_helper.MSG_COLOR = {
	ERROR  = "#FF4040",
	WARN   = "#ffff40",
	INFO   = "#c0ff80",
	NORMAL = "#ffffff"
}


-------------------------------------------
----  Common functions
-------------------------------------------
function debug_helper.send_message(playername, msg, color)
	if not msg or not playername or playername == "" then
		return
	end
	if color and minetest.colorize then
		msg = minetest.colorize(color, msg)
	end
	minetest.chat_send_player(playername, os.date("%H:%M:%S ") .. msg)
end


-------------------------------------------
----  Initialize
-------------------------------------------
local modpath = minetest.get_modpath(minetest.get_current_modname())
local worldpath = minetest.get_worldpath()
dofile(modpath .. "/debug_helper_gui.lua")

minetest.after(1, function()
	local function register_itemfile(filename)
		if not file_exists(filename) then
			return
		end

		local f = io.open(filename, "r")
		for line in f:lines() do
			line = string.trim(line)
			if not string.match(line, "^#") and #line > 0 then
				debug_helper.itemlist_register_item(line)
			end
		end
		f:close()
	end
	register_itemfile(worldpath .. "/" .. "debughelper_itemlist.conf")
	register_itemfile(modpath .. "/" .. "debughelper_itemlist.conf")
end)

minetest.log("action", "[MOD Debug Helper] Loaded!")

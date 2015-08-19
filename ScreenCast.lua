-- Standard awesome library
local gears = require("gears")
local awful = require("awful")
-- Widget and layout library
local wibox = require("wibox")
-- Notification library
local naughty = require("naughty")
local menubar = require("menubar")

local Events = require("Objects/Events") -- Event handler

local ScreenCast = {
	icon='/usr/share/icons/gnome/48x48/actions/media-record.png',
	default	= { -- copied by new
		-- TODO Add a means of clearing. default.clear? Perhaps copy IdleScript's Generative Functions
		recording = 0,
		events	= {},
		widget	= {},
		textw	= {},
		imgw	= {},
	},
}

-----------------------
-- Helper Functions {{{
-----------------------
local function TableOverwrite(orig,newvals)
	newvals = newvals or {}
	for k,v in pairs(newvals) do
		orig[k] = v
	end
	return orig -- Not necessary, but possibly convienent
end
-- Clone: Originily by Doub on https://stackoverflow.com/questions/640642/how-do-you-copy-a-lua-table-by-value
-- Modified by FireFish5000@gmail.com
local function TableCopy(orig,newvals)
  local t2 = {}
  for k,v in pairs(orig) do
    t2[k] = v
  end
	newvals = newvals or {}
  for k,v in pairs(newvals) do
    t2[k] = v
  end
  return t2
end

-- Helper Functions }}}
-----------------------

function ScreenCast:init()
	self.recording = 0
	self.events = Events.new()
	self.widget = wibox.layout.fixed.horizontal()
	self.textw = wibox.widget.textbox()
	self.imgw = wibox.widget.imagebox()
	self.widget:add(self.imgw)
	self.widget:add(self.textw)
	
	self.events:new_event("ScreenCast::StartRecording")
	self.events:new_event("ScreenCast::StopRecording")

	self.events:add_call("ScreenCast::StartRecording", function(args)
		self.recording=1
		self.imgw:set_image(self.icon)
		self.textw:set_text(" Recording ")
--		self.widget.visible=true;
--		self.imgw.visible=true;
--		self.textw.visible=true;
	end)
	self.events:add_call("ScreenCast::StartRecording", function(args)
		self:Record(args)
	end)
	
	self.events:add_call("ScreenCast::StopRecording", function()
		MkLaunch{bg=1,cmd="kill \"$(cat /tmp/ScreenCast.pid)\""   }()
		self.recording=0
		self.imgw:set_image(nil)
		self.textw:set_text("")
--		self.widget.visible=false;
--		self.imgw.visible=false;
--		self.textw.visible=false;
	end)

	return self
end

function ScreenCast:new()
	local original = self or ScreenCast
	local s = TableCopy(original, original.default)
	s:init()
	return s
end


function ScreenCast:start(args)
	if self.recording ~= 1 then
		self.events:poll("ScreenCast::StartRecording",args)
	end
end


function ScreenCast:stop()
	if self.recording == 1 then
		self.events:poll("ScreenCast::StopRecording")
	end
end
function ScreenCast:toggle(args)
	if self.recording ~= 1 then
		self.events:poll("ScreenCast::StartRecording",args)
	else
		self.events:poll("ScreenCast::StopRecording")
	end
end



function ScreenCast:Record(args)
	-- xrandr can be used for screen, if xregionsel falls through
	local framerate		= args.framerate or 25
	local size			= args.size or "\"$(xdpyinfo | grep 'dimensions' | awk '{print $2}' | head -n1)\""
	local pos			= args.pos or "0,0"
	local vcodec		= args.vcodec or "libx264"
	local screen		= args.screen or ":0.0"
	local name	= args.name or "~/ScreenCast"
	local format		= args.format or "mkv"
	local extra			= args.extra or "-vcodec libx264 -threads 0"
	local selection		= args.selection or 0
	-- TODO Make Preset local extra		= args.extra or "-vcodec libx264 -vpre lossless_ultrafast -threads 0"
--	return function(name)
		local cmd
		name = name .. "_" .. tostring(os.time())
--		-- Dont change default!
--		local pos = pos
--		local size = size
		if selection == 1 then
			-- FIXME Notify is being sent after rect sel???? WHY??????
			cmd = "for i in {0..3}; do selection=\"$(xregionsel -s | perl -pe 's{\\+(\\d+)\\+(\\d+)$}{ $1,$2}' || echo 'ERROR')\"; [[ \"$selection\" == 'ERROR' ]] || break ; sleep 0.1; done; size=\"${selection%% *}\"; pos=\"${selection##* }\"; "
			cmd = cmd .. " ffmpeg -f x11grab -r " .. framerate
			cmd = cmd .. " -s \"${size}\" "
			cmd = cmd .. " -i " .. screen .. "+${pos}" .. " " .. extra .. " " .. name .. "." .. format
		else
			cmd = "ffmpeg -f x11grab -r " .. framerate
			cmd = cmd .. " -s " .. size
			cmd = cmd .. " -i " .. screen .. "+" .. pos .. " " .. extra .. " " .. name .. "." .. format
		end
		MkLaunch{bg=1,cmd= "[[ -e '/tmp/ScreenCast.pid' ]] && kill \"$(cat /tmp/ScreenCast.pid)\"; " .. cmd .. " & echo $! > /tmp/ScreenCast.pid"   }()
--	end
end

-- NOTE FIXME !!! 'Control' Must be pressed before 'Alt' !!! 'Alt' will mask further control chracter presses!!!
function ScreenCast.plugin()
	right_layout:add(self.widget)
	Base:AddToType{AMacro:BuildNewKey{ Name="Screenshot",
		{ {							}, "Print", function() end,MkLaunch{bg=1,cmd="scrot   "} },
		{ {"Mod4"					}, "Print", function() end,MkLaunch{bg=1,cmd="scrot -m"} },
		{ {"Control"				}, "Print", function() end,MkLaunch{bg=1,cmd="scrot -s"} },
		-- Screen Cast
		{ {"Mod1"					}, "Print", Launch_FFCast{} }, -- Same Problem, without wierd extra error error
		{ {"Mod1", "Control"		}, "Print", Launch_FFCast{selection=1} }, -- rectangle selection
	}}

end


return ScreenCast

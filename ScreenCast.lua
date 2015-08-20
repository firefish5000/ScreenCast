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
	widget={},
	screencast = {
		recording=0,
		icon='/usr/share/icons/gnome/48x48/actions/media-record.png',
		imgw={},
		textw={},
	},
	screenshot = {
		icon='/usr/share/icons/Faenza/apps/scalable/shotwell.svg',
		imgw={},
		textw={},
	},
	default	= { -- copied by new
		-- TODO Add a means of clearing. default.clear? Perhaps copy IdleScript's Generative Functions
		recording = 0,
		events	= {},
		widget	= {},
		textw	= {},
		imgw	= {},
		cmd		= nil,
	},
}

local asyncshell = require("Modules/asyncshell")
require("components/helpers")

-----------------------
-- Helper Functions {{{
-----------------------
local function execute_once(delay, func)
   if delay == nil or delay < 0 then delay = 0 end
   local t = timer({ timeout = delay })
   t:connect_signal("timeout", function()
      t:stop()
      func()
   end)
   if delay > 0 then
      t:start()
   else
      func()
   end
   return t
end
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

---------------------
-- Screen Casting {{{

function ScreenCast:init()
	self.events = Events.new()
	self.widget = wibox.layout.fixed.horizontal()
	self:screencast_init()
	self:screenshot_init()
	self.widget:add(self.screencast.imgw)
	self.widget:add(self.screencast.textw)
	self.widget:add(self.screenshot.imgw)
	self.widget:add(self.screenshot.textw)

	return self
end
function ScreenCast:screencast_init()
	-- Set vars
	self.screencast.recording = 0
	-- Create Widgits
	self.screencast.textw = wibox.widget.textbox()
	self.screencast.imgw = wibox.widget.imagebox()

	-- Create and Register Events
	self.events:new_event("ScreenCast::StartRecording")
	self.events:new_event("ScreenCast::StopRecording")

	self.events:add_call("ScreenCast::StartRecording", function(args)
		self.screencast.recording=1
		self.screencast.imgw:set_image(self.screencast.icon)
		self.screencast.textw:set_text(" Recording ")
	end)
	self.events:add_call("ScreenCast::StartRecording", function(args)
		self:Record(args)
	end)
	
	self.events:add_call("ScreenCast::StopRecording", function()
		MkLaunch{bg=1,cmd="kill \"$(cat /tmp/ScreenCast.pid)\""   }()
		self.screencast.recording=0
		self.screencast.imgw:set_image(nil)
		self.screencast.textw:set_text("")
	end)
	return self
end
function ScreenCast:screenshot_init()

	self.screenshot.textw = wibox.widget.textbox()
	self.screenshot.imgw = wibox.widget.imagebox()

	-- Events
	self.events:new_event("ScreenShot::Pending")
	self.events:new_event("ScreenShot::Taken")

	self.events:add_call("ScreenShot::Pending", function(args)
		local file = args.file or "<NoFile>"
		if args.show_pending ~= true then
			return
		end
		self.screenshot.imgw:set_image(self.screenshot.icon)
		self.screenshot.textw:set_text(" Taking SelectionShot. Will Save at: '" .. file .. "'" )
	end)
	self.events:add_call("ScreenShot::Taken", function(args)
		local file = args.file or "<NoFile>"
		self.screenshot.imgw:set_image(self.screenshot.icon)
		self.screenshot.textw:set_text(" Took Screenshot. Saved at: '" .. file .. "'" )
		execute_once(10, function()
			self.screenshot.imgw:set_image(nil)
			self.screenshot.textw:set_text("")
		end)
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
	if self.screencast.recording ~= 1 then
		self.events:poll("ScreenCast::StartRecording",args)
	end
end


function ScreenCast:stop()
	if self.screencast.recording == 1 then
		self.events:poll("ScreenCast::StopRecording")
	end
end
function ScreenCast:toggle(args)
	if self.screencast.recording ~= 1 then
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

-- Screen Casting }}}
---------------------

------------------
-- Screen Shot {{{

-- TODO add event on scrot end,
-- allowing effects to be added.
-- TODO Delays?
-- TODO Image Processing?
-- TODO Formating/Container/Compression options?
function ScreenCast:ScreenShot_via(args)
	local args = args or {}
	local cmd = args.cmd or self.screenshot.cmd or "scrot"
	cmd = cmd .. " " .. (args.args or self.screenshot.args or "")
	local file = args.file
	if not args.file then
		file = args.prefix or self.screenshot.prefix or "ScreenShot"
		file = file .. (args.suffix or self.screenshot.suffix or "-" .. tostring(os.time()) )
		file = file .. "." ..  (args.extention or self.screenshot.extention or "png" )
		args.file = file
	end
	cmd = cmd .. " " .. file
	args.cmd = cmd
	self.events:poll("ScreenShot::Pending",args)
	--io.popen() -- For processing images?
	asyncshell.request( cmd, function()
		self.events:poll("ScreenShot::Taken",args)
	end)
end

function ScreenCast:ScreenShot(args)
	local args = args or {}
	args.type="screen"
	self:ScreenShot_via(args)
end
function ScreenCast:SelectionShot(args)
	local args = args or {}
	args.args= " -s " .. (args.args or "")
	args.type="selection"
	args.show_pending = args.show_pending or true
	self:ScreenShot_via(args)
end

function ScreenCast:X11Shot()
	local args = args or {}
	args.args= " -m " .. args.args
	args.type="X11"
	self:ScreenShot_via(args)
end

-- Screen Shot }}}
------------------

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

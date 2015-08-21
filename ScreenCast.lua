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
	liveview = {
		viewing=0,
		icon='/usr/share/icons/gnome/256x256/apps/applets-screenshooter.png',
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
-- Helpers currently writes in our enviorment, but extended helpers are return only.
local ExtHelp = require("components/helpers")

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
	self.widget:add(self.liveview.imgw)
	self.widget:add(self.liveview.textw)
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
	self.liveview.textw = wibox.widget.textbox()
	self.liveview.imgw = wibox.widget.imagebox()

	-- Create and Register Events
	self.events:new_event("Error::SelectionFaild")
	self.events:new_event("Error::SelectionRetry")

	self.events:new_event("ScreenCast::Pending")
	self.events:new_event("ScreenCast::StartRecording")
	self.events:new_event("ScreenCast::StopRecording")
	-- FIXME Live view and screencast need to know when they are killed externally
	-- FIXME ESPECIALY when only one is killed. Eg, mpv is closed by user. Meanwhile, ffmpeg is waiting with its pipe... forever.... 
	-- At least is what I am guessing is happening, because I 
	self.events:new_event("LiveView::Pending")
	self.events:new_event("LiveView::Start")
	self.events:new_event("LiveView::Stop")
	self.events:add_call("LiveView::Pending", function(args)
		local file = args.output or "<NoOutput>"
		if args.show_pending == false then
			return
		end
		self.liveview.imgw:set_image(self.liveview.icon)
		if args.selection ~= false then
			self.liveview.textw:set_text(" Will do LiveView of Selection. ")
		else
			self.liveview.textw:set_text(" Starting Liveview ")
		end
	end)
	self.events:add_call("LiveView::Start", function(args)
		local file = args.output or "<NoOutput>"
		self.liveview.viewing=1
		self.liveview.imgw:set_image(self.liveview.icon)
		self.liveview.textw:set_text(" LiveView Started! ")
		execute_once(5, function()
			if self.liveview.viewing==1 then
				self.liveview.textw:set_text(" LiveViewing ")
			end
		end)
		self.liveview.rec_args=args
	end)
	self.events:add_call("LiveView::Stop", function()
		self.liveview.rec_args = nil
		MkLaunch{bg=1,cmd="pkill -TERM -P \"$(cat /tmp/ScreenCastPreview.pid)\" ;  kill -TERM \"$(cat /tmp/ScreenCastPreview.pid)\" "   }()
		self.liveview.viewing=0
		self.liveview.imgw:set_image(self.liveview.icon)
		self.liveview.textw:set_text(" LiveView Disconnnected ")
		execute_once(3, function()
			if self.liveview.viewing==0 then
				self.liveview.imgw:set_image(nil)
				self.liveview.textw:set_text("")
			end
		end)
	end)

	self.events:add_call("ScreenCast::Pending", function(args)
		local file = args.output or "<NoOutput>"
		if args.show_pending == false then
			return
		end
		self.screencast.imgw:set_image(self.screencast.icon)
		if args.selection ~= false then
			self.screencast.textw:set_text(" Taking SelectionCast. Will Record To: '" .. file .. "'")
		else
			self.screencast.textw:set_text(" Will Record To: '" .. file .. "'")
		end
	end)
	-- Preliminary LiveView should be optional for selections
	self.events:add_call("ScreenCast::Pending", function(args)
		if args.preview == true then
			self:LiveView(args)
		end
	end)
	self.events:add_call("ScreenCast::StartRecording", function(args)
		local file = args.output or "<NoOutput>"
		self.screencast.recording=1
		self.screencast.imgw:set_image(self.screencast.icon)
		self.screencast.textw:set_text(" Recording To: '" .. file .. "'")
		execute_once(5, function()
			if self.screencast.recording==1 then
				self.screencast.textw:set_text(" Recording ")
			end
		end)
		self.screencast.rec_args=args
	end)
	self.events:add_call("ScreenCast::StartRecording", function(args)
		if args.preview==true and args.selection==true then
			self:LiveView(args)
		end
	end)
	
	self.events:add_call("ScreenCast::StopRecording", function()
		local file = self.screencast.rec_args.output or "<NoOutput>"
		MkLaunch{bg=1,cmd="pkill -TERM -P \"$(cat /tmp/ScreenCast.pid)\"; kill -TERM \"$(cat /tmp/ScreenCast.pid)\""   }()
		self.screencast.recording=0
		self.screencast.imgw:set_image(self.screencast.icon)
		self.screencast.textw:set_text(" Recording saved at: '" .. file .. "'!")
		execute_once(5, function()
			if self.screencast.recording==0 then
				self.screencast.imgw:set_image(nil)
				self.screencast.textw:set_text("")
			end
		end)
	end)
	self.events:add_call("ScreenCast::StopRecording", function(args)
		if self.screencast.rec_args.preview==true then
			self.events:poll("LiveView::Stop")
		end
		self.screencast.rec_args = nil
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
		self:Record(args)
	end
end


function ScreenCast:stop()
	if self.screencast.recording == 1 then
		self.events:poll("ScreenCast::StopRecording")
	end
end
function ScreenCast:LiveView_Start(args)
	if self.screencast.recording ~= 1 then
		self:LiveView(args)
	end
end


function ScreenCast:LiveView_Stop()
	if self.screencast.recording == 1 then
		self.events:poll("LiveView::Stop")
	end
end
function ScreenCast:LiveView_toggle(args)
	if self.liveview.viewing ~= 1 then
		self:LiveView(args)
	else
		self.events:poll("LiveView::Stop")
	end
end

function ScreenCast:toggle(args)
	if self.screencast.recording ~= 1 then
		self:Record(args)
	else
		self.events:poll("ScreenCast::StopRecording")
	end
end



function ScreenCast:Record(args)
	-- xrandr can be used for screen, if xregionsel falls through
	local args = args or {}
	args.framerate		= args.framerate or 25
	if (not args.size) or (not string.match(args.size,"^(%d+)x(%d+)$") ) then
		local size_p = io.popen("xdpyinfo | grep 'dimensions' | awk '{print $2}' | head -n1 | tr -d '\n'")
		args.size=size_p:read("*all") or nil
		size_p:close()
		args.size=args.size or "800x400"
	end
	args.width = args.width or string.match(args.size,"^(%d+)x")
	args.height = args.height or string.match(args.size,"x(%d+)$")
	args.xpos= args.xpos or 0
	args.ypos= args.ypos or 0
	
	args.vcodec		= args.vcodec or "libx264"
	args.screen		= args.screen or ":0.0"
	args.basepath	= args.basepath or "~/ScreenCast"
	args.format		= args.format or "mkv"
	args.output		= args.output or (args.basepath .. "_" .. tostring(os.time()) .. "." .. args.format)
	args.extra			= args.extra or "-vcodec libx264 -threads 0"
	args.preview		= args.preview or false
	args.selection		= args.selection or false
	args.show_pending= args.show_pending or args.selection
	-- TODO Make Preset local extra		= args.extra or "-vcodec libx264 -vpre lossless_ultrafast -threads 0"

	-- FIXME Region Selector stops redraws untill region has been selects. Meaning we wont see the selection message....?.
	self.events:poll("ScreenCast::Pending",args)
	local cmd
		if args.selection == true then
			-- FIXME Notify is being sent after rect sel???? WHY??????
			for i=1,3 do
				-- TODO Make selection another function. Make retries a event called on failure. Retiesexist because it is easy to hit an exta key, which disables selection.
				local size_p = io.popen("xregionsel -s | tr -d '\n'")
				local region = size_p:read("*all") or nil
				size_p:close()
				-- FIXME we can surely do this in one move
				if string.match(region,'^%d+x%d+%+%d+%+%d+$') then
					args.width, args.height, args.xpos, args.ypos = string.match(region,'^(%d+)x(%d+)%+(%d+)%+(%d+)$')
					args.size= args.width .. "x" .. args.height
					args.pos= args.xpos .. "," .. args.ypos
					break
				elseif i == 3 then
					self.events:poll("Error::SelectionFaild")
					return
				end
				self.events:poll("Error::SelectionRetry")
			end
		end
		cmd = "ffmpeg -f x11grab -r " .. args.framerate
		cmd = cmd .. " -s " .. args.size
		cmd = cmd .. " -i " .. args.screen .. "+" .. args.xpos .. "," .. args.ypos .. " " .. args.extra .. " " .. args.output
		self.events:poll("ScreenCast::StartRecording",args)
		MkLaunch{bg=1,cmd= "[[ -e '/tmp/ScreenCast.pid' ]] && pkill -TERM -P \"$(cat /tmp/ScreenCast.pid)\" ; kill -TERM \"$(cat /tmp/ScreenCast.pid)\" ; " .. cmd .. " & echo $! > /tmp/ScreenCast.pid"   }()
--	end
end
-- When it comes to previewing, there are a number of extra questions we have to try to answer
-- if the user doen't providew defaults.
-- For one, we need o support multiple players, like vlc, mpv, mplayer, ffplayer, etc.
-- Then there is means and quality of the preview stream.
-- Are we just tapping into the normal capture?
-- Shouldn we aim for live stream preview, which would need to bypass encoding and cache/buffers,
-- or encoding preview, which will have a more of a delay as ffmpeg encodes it?

-- If doing a live preview, how do we interact with the normal ffmpeg capture, if at all?
-- does it do multiple outputes (from my attempts and understqanding, all are encoded at the same time at the same gereal location.
-- Meaning 'live' stream will be just as slow as encoded stream)
-- Do we output to a 'live' stream of sorts, such as a rtmp stream, and then have a player follow it and another ffmpeg process do normal encoding?
-- Output a rawstream to 2 pipes and have player play one and ffmpeg encode the other?
-- Output raw stream (for viewing, raw stream is quickest) to file, tail it withthe player, and encode with ffmpeg? Horible idea! 30 second raw video takes 2gb!
--
--The last option is to run two instances, which is the only option I can readily do atm. As succh, here is an example
-- EXAMPLE using pipes and mpv
-- ffmpeg -f x11grab -r 100 -s "3360x1080" -i :0.0 -preset ultrafast -f rawvideo pipe:1 |  mpv --no-cache --demuxer=rawvideo --demuxer-rawvideo-fps=125 --demuxer-rawvideo-mp-format=bgr0 --demuxer-rawvideo-codec=lavc:rawvideo --demuxer-rawvideo=w=3360:h=1080  --no-fs --geometry=840x270+1060+800 --force-window-position --name 'ScreenCastPreview' /dev/stdin
-- NOTE we must make ScreenCastPreview floating in rules.lua (unfortunatly, it only matches the last class if multiple exist, and thus rule has to apply to mpv class...)
-- You should also set the screen, width, and hight there.
function ScreenCast:LiveView(args)
	-- FIXME Record and LiveView are not easily configurable...
	-- xrandr can be used for screen, if xregionsel falls through
	--local args = args or {}
	local oargs = args or {}
	local args = {}
	if oargs.preview ~= true then
		args = oargs
	else
		args.size	= oargs.size or nil
		args.pos	= oargs.pos or nil
		args.xpos	= oargs.xpos or nil
		args.ypos	= oargs.ypos or nil
		args.player = oargs.player or nil
	end
	args.framerate		= args.framerate or 25
	args.setup_cmds			= args.setup_cmds or "SIZE=\"$(xdpyinfo | grep 'dimensions' | awk '{print $2}' | head -n1 | tr -d '\n')\""
	if (not args.size) or (not string.match(args.size,"^(%d+)x(%d+)$") ) then
		local size_p = io.popen("xdpyinfo | grep 'dimensions' | awk '{print $2}' | head -n1 | tr -d '\n'")
		args.size=size_p:read("*all") or nil
		size_p:close()
		args.size=args.size or "800x400"
	end
	args.width = args.width or string.match(args.size,"^(%d+)x")
	args.height = args.height or string.match(args.size,"x(%d+)$")
	args.xpos= args.xpos or 0
	args.ypos= args.ypos or 0
	args.vcodec			= args.vcodec or ""
	args.screen			= args.screen or ":0.0"
	args.output			= args.output or "pipe:1"
	args.input			= args.input or "x11grab"
	args.format			= args.format or "rawvideo"
	args.extra			= args.extra or " -threads 0"
	args.selection		= args.selection or false
	args.player		= args.player or {}
	args.player.cmd		= args.player.cmd or "mpv"
	-- TODO Go back over --input  options. Looks like there are several ways to tie into/control mpv. 
	--args.player.args		= args.player.args or "--no-cache --demuxer=rawvideo --demuxer-rawvideo-fps=125 --demuxer-rawvideo-mp-format=bgr0 --demuxer-rawvideo-codec=lavc:rawvideo --no-fs --geometry=840x270+1060+800 --force-window-position --name 'ScreenCastPreview'"
	args.player.args		= args.player.args or "--no-cache --really-quiet --use-text-osd=no --no-osd-bar --no-osc --keepaspect-window --load-scripts=no --no-border --demuxer=rawvideo --demuxer-rawvideo-mp-format=bgr0 --demuxer-rawvideo-codec=lavc:rawvideo --no-fs --force-window-position --name 'ScreenCastPreview'"
	-- TODO make width/height/size a function. We pass wh, and user defined function returns required args if any.
	-- TODO Perhaps all player options should work that way. and mayby even some ffmpeg options? Could add easy switching from ffmpeg and libav (they couldn't hijack ffmpeg, 
	-- so they named themselevs after it's most popular library, probably to draw in confused users and developers who had problems running or building packages complaining about ffmpeg's "libav" missing)
	args.player.framerate_arg		= args.framerate_arg or "--demuxer-rawvideo-fps="
	args.player.framerate		= args.framerate or math.ceil(tonumber(args.framerate) * 1.5) + 1
	args.player.geometry_arg		= args.geometry_arg or "--geometry="
	args.player.width_arg		= args.player.width_arg or "--demuxer-rawvideo-w="
	args.player.height_arg		= args.player.height_arg or "--demuxer-rawvideo-h="
		local cmd
--		-- normally this would be done by Record, but you can run LiveView standalone, so we still have it here.
		self.events:poll("LiveView::Pending",args)
		if args.selection == true then
			-- FIXME Notify is being sent after rect sel???? WHY??????
			for i=1,3 do
				-- TODO Make selection another function. Make retries a event called on failure. Retiesexist because it is easy to hit an exta key, which disables selection.
				local size_p = io.popen("xregionsel -s | tr -d '\n'")
				local region = size_p:read("*all") or nil
				size_p:close()
				-- FIXME we can surely do this in one move
				if string.match(region,'^%d+x%d+%+%d+%+%d+$') then
					args.width, args.height, args.xpos, args.ypos = string.match(region,'^(%d+)x(%d+)%+(%d+)%+(%d+)$')
					args.size= args.width .. "x" .. args.height
					args.pos= args.xpos .. "," .. args.ypos
					break
				elseif i == 3 then
					self.events:poll("Error::SelectionFaild")
					return
				end
				self.events:poll("Error::SelectionRetry")
			end
		end
		--args.player.geometry = args.player.geometry or (args.size .. "+" .. args.xpos .. "+" .. args.ypos)
		-- Automatic options seems to have problems when used with selection? Once I figure it out ill use it by default for autoresize
		--args.player.geometry = args.player.geometry or ("50%+" .. args.xpos .. "+" .. args.ypos)
		if not args.player.width and not args.player.height then
			local fw = tonumber(args.width)/2
			local fh = tonumber(args.height)/2
			if fw >= 10 and fh >= 10 then
				args.player.width	= fw
				args.player.height	= fh
		 	end
		end
		args.player.width = args.player.width or args.width
		args.player.height = args.player.height or args.height
		-- I can easily do something like set it to 10 above and 10 to the left of the bottom right
		-- However, we could also do that(and hardset our size/geomotry completly) in aweful.rules
		-- Which is probably more appropriate. Us not touching it is the only easy way to enable us
		-- to be posistioned over the spot we are screencasting. So at least make an option to not do it.
		args.player.xpos = args.player.xpos or args.xpos
		args.player.ypos = args.player.ypos or args.ypos
		args.player.geometry = args.player.geometry or (args.player.width .. "x" .. args.player.height .. "+" .. args.player.xpos .. "+" .. args.player.ypos)
		
		cmd = "ffmpeg -f x11grab -r " .. args.framerate
		cmd = cmd .. " -s " .. args.size
		cmd = cmd .. " -i " .. args.screen .. "+" .. args.xpos .. "," .. args.ypos .. " " .. args.extra .. " -f " .. args.format .. " " .. args.output
		cmd = cmd .." | ".. args.player.cmd .. " " .. args.player.args .. " " .. args.player.width_arg .. args.width .. " " .. args.player.height_arg .. args.height .. " " .. args.player.geometry_arg .. args.player.geometry .. " /dev/stdin"
		
		-- No clue why,but Running as preview (when Record calls us), we cannot kill anythin?
		cmd= args.setup_cmds .. "; [[ -e '/tmp/ScreenCastPreview.pid' ]] && { pkill -TERM -P \"$(cat /tmp/ScreenCastPreview.pid)\" ; kill -TERM \"$(cat /tmp/ScreenCastPreview.pid)\" ; } ; { " .. cmd .. " ; } >/dev/null 2>/dev/null & echo $! > /tmp/ScreenCastPreview.pid"
		
		ExtHelp:Print({file="/tmp/COMMAND",text=cmd})
		self.events:poll("LiveView::Start",args)
		MkLaunch{bg=1,cmd=cmd }()
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

function ScreenCast:X11Shot(args)
	local args = args or {}
	args.args= " -m " .. (args.args or "")
	args.type="X11"
	self:ScreenShot_via(args)
end

-- Screen Shot }}}
------------------

-- NOTE FIXME !!! 'Control' Must be pressed before 'Alt' !!! 'Alt' will mask further control chracter presses!!!
function ScreenCast:keys()
	return unpack({
		{ {							}, "Print", nil, function() self:ScreenShot{} end },
		{ {"Mod4"					}, "Print", nil, function() self:X11Shot{} end },
		{ {"Control"				}, "Print", nil, function() self:SelectionShot{} end },
		-- Screen Cast
		{ {"Shift"					}, "Print", nil, function() self:toggle{} end }, -- Same Problem, without wierd extra error error
		{ {"Shift", "Control"		}, "Print", nil, function() self:toggle{selection=true} end }, -- rectangle selection
		{ {"Shift", "Mod4"			}, "Print", nil, function() self:toggle{preview=true} end }, -- rectangle selection
		{ {"Shift","Mod4","Control"	}, "Print", nil, function() self:toggle{preview=true,selection=true} end}, -- rectangle selection
		{ {"Mod1"					}, "Print", nil, function() self:LiveView_toggle{} end }, -- Same Problem, without wierd extra error error
		{ {"Mod1", "Control"		}, "Print", nil, function() self:LiveView_toggle{selection=true} end }, -- rectangle selection
	})
end


return ScreenCast

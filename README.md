
ScreenCast
----------

ScreenCast is a screen shot and screen capturing script utilizing scrot and ffmpeg.

For best experience, we recommend using firefish5000/xregionsel,
a ffcast and xrectsel and scrot based (and scrot like) X11 region selector. However, xrectsel will give ~= results and your distro may actualy have a package for it, so...

# Usage

Basic API
Somewhere near the top of your awesome rc.lua add
	ScreenCast=require("ScreenCast/ScreenCast")
	ScreenCast:init()
	-- Uses xrectsel by default. Uncomment this if you have xregionsel installed
	-- ScreenCast.selection_cmd = "xregionsel -s | tr -d '\n'" -- Can also grab windows when clicked


Add keybindings to us
Here we bind to various PrintScreen combinations.
	globalkey = { unpack(globalkeys),
		{ {							}, "Print", nil, function() self:ScreenShot{} end },
		{ {"Control"				}, "Print", nil, function() self:SelectionShot{} end },

		-- Screen Cast
		{ {"Shift"					}, "Print", nil, function() self:toggle{} end },
		{ {"Shift", "Control"		}, "Print", nil, function() self:toggle{selection=true} end }, -- rectangle selection
		{ {"Shift", "Mod4"			}, "Print", nil, function() self:toggle{preview=true} end }, -- With LiveView
		{ {"Shift","Mod4","Control"	}, "Print", nil, function() self:toggle{preview=true,selection=true} end}, -- rectangle selection with LiveView
		
		-- LiveView
		-- NOTE Mod1=Alt, and Alt may mask Control if you try Alt>Control>Print. So be sure to start live view by pressing and holding Control,
		-- then Alt, and then Print. 
		{ {"Mod1"					}, "Print", nil, function() self:LiveView_toggle{} end },
		{ {"Mod1", "Control"		}, "Print", nil, function() self:LiveView_toggle{selection=true} end }, -- rectangle selection
	}

Add widget to awesomewm taskbar
	right_layout:add(ScreenCast.widget)

# Provided Methods

Usefull Provided methods include
	-- Take a ScreenShot
	ScreenCast:ScreenShot{}
	-- Draw a rectange and then take a ScreenShot
	ScreenCast:ScreenShot{selected=true}
	-- OR
	ScreenCast:SelectionShot{}

	-- ScreenCast/Capture to file
	-- NOTE we only support one recording stream right now,
	-- Consequtive Record calls will terminate previous ones first.
	ScreenCast:Record{}
	-- Draw a rectange and then ScreenCast/Capture to file
	ScreenCast:Record{selected=1}
	-- Draw a rectange and Display the contents of the rectangle in mpv while ScreenCast/Captureing the rectangle to a file
	ScreenCast:Record{selected=1, preview=1}
  
	-- Display the contents of the Display in mpv
	ScreenCast:LiveView{}
	-- Draw a rectangle and then Display the contents of the rectangle in mpv
	ScreenCast:LiveView{selected=1}

	-- Start a new ScreenCast if not already recording
	-- Takes same arguments as ScreenCast:Record
	ScreenCast:Start{}
	-- Stop ScreenCast if we are recording
	-- Takes no arguments
	ScreenCast:Stop{}
	-- Toggle ScreenCast On/Off. Takes same arguments as ScreenCast:Record
	ScreenCast:toggle{}

	-- Toggle LiveView On/Off. Takes same arguments as ScreenCast:LiveView
	ScreenCast:LiveView\_toggle{}

#Requires
- asyncshell

# Dependencies

##ScreenShot
- scrot

##ScreenCast
- ffmpeg

##SelectionCast
- xregionsel or xrectsel

##LiveView
- ffmpeg
- mpv

# EXAMPLE
[Here is a high-quality video showing us in use](https://www.youtube.com/watch?v=PKh3Dn6zGqw) Note that youtube will probably autoselect a low res option, and all quality options may not be displayed.
TODO, add gif.


# TODO

In the future, we plan to find a way to follow windows and follow the cursor. Allowing selected windows to be
resized and moved durring recording without loosing them.

# Current Issues

Configuring screencasting is overly difficault. Defaults are probably not the best for general use.

xregionsel and scrot freeze the screen durring selection ('scrot -s', 'xregionsel -s')

Icons have a hardcoeded path, no fallbacks

Only One instance of screencast and liveview may run at a time.

We do not keep up with if mpv/ffmpeg to see if they stopped by some other means, so the notifications may still say "recording" or "Live View" after killing ffmpeg or quiting mpv. 

LiveView does not have an option by default to display an already running SelectionCast. (hint: ScreenCast:LiveView{unpack(ScreenCast.screencast.rec_args), preview=1})

No audio by default. (I suppose we need alsa/pulse output captures, and normal alsa/pule input capture support. At least when there is only one capture device, we should be able to use it with little configuration no?)

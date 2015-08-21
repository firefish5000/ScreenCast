#! /usr/bin/env lua
--
-- Events.lua
-- Copyright (C) 2015 beck <beck@Kataomoi>
--
-- Distributed under terms of the MIT license.
--

-- Similar to emit_signal/connect_signal, but with order control.
-- TODO async/detatched polls
-- TODO import advanced openrc style order control from IdleScript.

local naughty = require("naughty")

local Events = {
	event = { }
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
local function TableClone(newvals)
  return self.TableCopy(self, newvals)
end

-- Helper Functions }}}
-----------------------

function Events.new()
	local EventHandler = TableCopy(Events,{event = {} })
	EventHandler:new_event("NewEvent")
	EventHandler:new_event("AssociatedCall")
	EventHandler:new_event("PolledEvent")
	EventHandler:new_event("Error::EventExists")
	EventHandler:new_event("Error::NoName")
	EventHandler:new_event("Error::NoSuchEvent")
	
	EventHandler:add_call("Error::EventExists", function(t)
			naughty.notify({timeout=1000,title="Error",text="Attempting to re-register '" .. t.name .. "', an alread registered event!"});
		end
	)
	EventHandler:add_call("Error::NoName", function(t)
			naughty.notify({timeout=1000,title="Error",text="Register, Polled, or Called called without an event."});
		end
	)
	EventHandler:add_call("Error::NoSuchEvent", function(t)
			if t.flaged == 0 then return end
			naughty.notify({timeout=1000,title="Error",text="Non-existing event ".. t.name .." polled or called. Creating event"});
			t.EventHandler.event[t.name]={}
			-- Flag indecates weather psudo error is handeld or not.
			t.flaged=0
		end
	)
	return EventHandler
end

-- Registers a new event prior to use
function Events:new_event(name)
	if name == nil then
		self:error_poll("Error::NoName", { EventHandler=self })
		return false
	end
	if self.event[name] == nil then
		self.event[name]={}
	else
		self:error_poll("Error::EventExists", { EventHandler=self, name=name })
	end
	return self.event[name]
end

function Events:add_call(name,func)
	if name == nil then
		self:error_poll("Error::NoName", { EventHandler=self })
		return false
	end
	if self.event[name] == nil then
		self:error_poll("Error::NoSuchEvent", { EventHandler=self, name=name })
	end
	local idx = #self.event[name]+1
	self.event[name][idx] = func
	return self.event[name][idx]
end

-- name: name of event
-- ... : arguments to pass to called functions
-- NOTE polls cannot get return value from called functions, as returning values from numerous unknown functions is nonsensical.
-- If you need values from called functions, pass a variable for them to store it in.
function Events:poll(name, ... )
	if name == nil then
		self:error_poll("Error::NoName", { EventHandler=self })
		return false
	end
	if self.event[name] == nil then
		self:error_poll("Error::NoSuchEvent", { EventHandler=self, name=name })
	end
	local calls = self.event[name]
	
	for idx=1,#calls do
		if type(calls[idx]) == "function" then
			calls[idx](...) -- passing variable num of args
		end
	end
end

-- Error polls require a tabel argument.
-- And will exit early if flag is lowered
-- FIXME should error_poll throw an error if it cannot handle it?
function Events:error_poll(name, t)
	t = t or {}
	if type(t) ~= "table" then
		-- TODO Some error handeling
		return
	end
	t.flaged = t.flaged or 1;
	
	if name == nil then
--		self:error_poll("Error::NoName", { EventHandler=self })
--		return false
		error("EventHandler: error_poll was called without an event")
	end
	if self.event[name] == nil then
--		self:error_poll("Error::NoSuchEvent", { EventHandler=self, name=name })
		error("EventHandler: error_poll was called on a non existent event")
	end
	local calls = self.event[name]
	
	for idx=1,#calls do
		if (t.flaged == 0 or not t.flaged) then
			return
		end
		if type(calls[idx]) == "function" then
			calls[idx](t) -- passing variable num of args
		end
	end
end

return Events

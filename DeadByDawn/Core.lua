local ADDON, ns = ...

DeadByDawnDB = DeadByDawnDB or {}

local GOLD, R = "|cffe6c35c", "|r"

ns.seen = {}

local lastHello = 0
local HELLO_GAP = 60

function ns.Hello(force)
	if not IsInGuild() then return end
	local now = GetTime()
	if not force and now - lastHello < HELLO_GAP then return end
	lastHello = now
	if C_ChatInfo and C_ChatInfo.SendAddonMessage then
		pcall(C_ChatInfo.SendAddonMessage, ns.PREFIX, "HI~" .. (ns.VERSION or "?"), "GUILD")
	end
end

function ns.NoteSeen(sender, version)
	if not sender then return end
	local bare = sender:match("^([^-]+)") or sender
	ns.seen[bare] = { version = version, t = GetTime() }
end

function ns.HasAddon(name)
	if not name then return nil end
	local bare = name:match("^([^-]+)") or name
	local me = (ns.Ranks and ns.Ranks.MyName and ns.Ranks:MyName()) or UnitName("player")
	if bare == me then return ns.VERSION or "?" end
	local rec = ns.seen[bare]
	return rec and (rec.version or "?") or nil
end

function ns.Broadcast(fmt, ...)
	local text = string.format(fmt, ...)
	print(ns.CHAT_TAG .. " " .. text)
	if C_ChatInfo and C_ChatInfo.SendAddonMessage and IsInGuild() then
		pcall(C_ChatInfo.SendAddonMessage, ns.PREFIX, "SAY~" .. text, "GUILD")
	end
end

function ns.Print(fmt, ...)
	print(GOLD .. "Dead by Dawn:" .. R .. " " .. string.format(fmt, ...))
end

function ns.FullName()
	local name = UnitName("player")
	if not name then return nil end
	local realm = GetRealmName and GetRealmName()
	if realm and realm ~= "" then return name .. "-" .. realm end
	return name
end

local guildKnown = false

function ns.GuildName()
	if not IsInGuild() then return nil, true end
	local name = GetGuildInfo("player")
	if not name then return nil, false end
	return name, true
end

function ns.IsOurGuild()
	local name, known = ns.GuildName()
	if not known then return nil end
	if not name then return false end
	if not ns.GUILD then return true end
	return name == ns.GUILD
end

function ns.Active()
	return ns.IsOurGuild() == true
end

local function RequestRoster()
	if C_GuildInfo and C_GuildInfo.GuildRoster then
		pcall(C_GuildInfo.GuildRoster)
	elseif GuildRoster then
		pcall(GuildRoster)
	end
end

local function OnRosterReady()
	if not ns.Active() then return end
	ns.Ranks:Scan()
	if ns.UI and ns.UI.Refresh then ns.UI.Refresh() end
end

local announcedFor = false

local function Announce()
	local state = ns.IsOurGuild()
	if state == nil then return end
	local name = ns.GuildName()
	if announcedFor == name then return end
	announcedFor = name
	if state then
		ns.Ranks:Scan()
		if ns.DEV then
			ns.Print("|cffff8000TEST MODE|r - any guild, all permissions. Turn off ns.DEV in Config.lua before release.")
		end
		return
	end
	ns.Print("dormant - this is for %s, you are in %s.",
		ns.GUILD or "a specific guild", name or "no guild")
end

local greeted = false

local function Greet()
	if greeted then return end
	if ns.IsOurGuild() ~= true then return end
	greeted = true
	ns.Ranks:Scan()
	local mine = ns.Ranks:MyIndex()
	ns.Print("%s ready. %d rank(s) detected. You are %s%s%s.",
		ns.VersionLabel(),
		ns.Ranks:Count(),
		GOLD, ns.Ranks:NameOf(mine) or "unranked", R)
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("PLAYER_GUILD_UPDATE")
f:RegisterEvent("GUILD_ROSTER_UPDATE")
f:SetScript("OnEvent", function(_, event)
	if event == "PLAYER_LOGIN" then
		DeadByDawnDB.caps = DeadByDawnDB.caps or {}
		if DeadByDawnDB.helpKeyword == nil then
			DeadByDawnDB.helpKeyword = ns.DEFAULT_HELP_KEYWORD
		end
		if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
			pcall(C_ChatInfo.RegisterAddonMessagePrefix, ns.PREFIX)
		end
		local relay = CreateFrame("Frame")
		relay:RegisterEvent("CHAT_MSG_ADDON")
		relay:SetScript("OnEvent", function(_, _, prefix, text, _, sender)
			if prefix ~= ns.PREFIX or not ns.Active() then return end
			local me = UnitName("player")
			if sender == me or (sender or ""):match("^([^-]+)") == me then return end
			local version = text:match("^HI~(.*)$")
			if version then
				ns.NoteSeen(sender, version)
				if ns.NoteRemoteVersion then ns.NoteRemoteVersion(version) end
				if C_Timer and C_Timer.After then
					C_Timer.After(1 + math.random() * 5, function() ns.Hello(false) end)
				end
				if ns.UI and ns.UI.Refresh then ns.UI.Refresh() end
				return
			end

			ns.NoteSeen(sender, nil)
			local body = text:match("^SAY~(.*)$")
			if body then print(ns.CHAT_TAG .. " " .. body) end
		end)

		if ns.QuestHelp and ns.QuestHelp.Init then ns.QuestHelp.Init() end
		if ns.Events and ns.Events.Init then ns.Events.Init() end
		if C_Timer and C_Timer.After then
			C_Timer.After(12, function() ns.Hello(true) end)
		end
		if SetGuildRosterShowOffline then pcall(SetGuildRosterShowOffline, true) end
		RequestRoster()
		if C_Timer and C_Timer.After then
			C_Timer.After(3, function() RequestRoster() ; Announce() ; Greet() end)
			C_Timer.After(10, function() Announce() ; Greet() end)
		end

	elseif event == "PLAYER_GUILD_UPDATE" then
		RequestRoster()
		Announce()

	elseif event == "GUILD_ROSTER_UPDATE" then
		OnRosterReady()
		Announce()
	end
end)

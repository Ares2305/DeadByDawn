local ADDON, ns = ...

local Events = {}
ns.Events = Events

local loaded = false
local lastScan = 0
local cache = {}
local known = {}
local primed = false
local authoringUntil = 0

local MONTHS = { "January", "February", "March", "April", "May", "June",
	"July", "August", "September", "October", "November", "December" }
local WEEKDAYS = { "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat" }

local function IsGuildType(t)
	if type(t) == "number" then
		local E = Enum and Enum.CalendarType
		if not E then return false end
		return t == E.Community
	end
	if type(t) == "string" then
		return t == "GUILD_ANNOUNCEMENT" or t == "GUILD_EVENT" or t == "COMMUNITY"
	end
	return false
end

local function EventTypeName(t)
	local E = Enum and Enum.CalendarEventType
	if not E or type(t) ~= "number" then return nil end
	if t == E.Raid then return "Raid" end
	if t == E.Dungeon then return "Dungeon" end
	if t == E.PvP then return "PvP" end
	if t == E.Meeting then return "Meeting" end
	return nil
end

function Events.EnsureCalendar()
	if loaded then return true end
	local loader = (C_AddOns and C_AddOns.LoadAddOn) or _G.LoadAddOn
	if loader then pcall(loader, "Blizzard_Calendar") end
	if C_Calendar and C_Calendar.OpenCalendar then pcall(C_Calendar.OpenCalendar) end
	loaded = (C_Calendar ~= nil)
	return loaded
end

function Events.Available()
	return (C_Calendar and C_Calendar.GetNumDayEvents and C_Calendar.GetDayEvent) and true or false
end

local function TypeName(e)
	return e.calendarType
end

local function Stamp(e, monthOffset, day)
	local st = e.startTime
	if type(st) == "table" and st.month and st.monthDay then
		return (st.year or 0) * 10000 + st.month * 100 + st.monthDay,
			st.hour or 0, st.minute or 0
	end
	return monthOffset * 100 + day, 0, 0
end

function Events.Upcoming(limit)
	limit = limit or 6
	local now = GetTime()
	if now - lastScan < 20 and #cache > 0 and limit <= #cache then return cache end
	lastScan = now

	local out = {}
	if not Events.EnsureCalendar() or not Events.Available() then
		cache = out
		return out
	end

	local today = C_DateAndTime and C_DateAndTime.GetCurrentCalendarTime
		and select(1, pcall(C_DateAndTime.GetCurrentCalendarTime))
	local currentDay
	if type(today) == "table" then currentDay = today.monthDay end
	if not currentDay and date then currentDay = tonumber(date("%d")) end

	for monthOffset = 0, 1 do
		for day = 1, 31 do
			local ok, n = pcall(C_Calendar.GetNumDayEvents, monthOffset, day)
			n = (ok and tonumber(n)) or 0
			for i = 1, n do
				local ok2, e = pcall(C_Calendar.GetDayEvent, monthOffset, day, i)
				if ok2 and type(e) == "table" and e.title then
					local isGuild = IsGuildType(TypeName(e))
					if isGuild and (monthOffset > 0 or not currentDay or day >= currentDay) then
						local key, hour, minute = Stamp(e, monthOffset, day)
						out[#out + 1] = {
							title = e.title,
							day = day,
							monthOffset = monthOffset,
							hour = hour,
							minute = minute,
							sort = key * 10000 + hour * 100 + minute,
							isGuild = isGuild,
							calendarType = TypeName(e),
							kind = EventTypeName(e.eventType),
							month = e.startTime and e.startTime.month,
							year = e.startTime and e.startTime.year,
							weekday = e.startTime and e.startTime.weekday,
							numInvites = e.numInvites,
							inviteStatus = e.inviteStatus,
						}
					end
				end
			end
		end
	end

	table.sort(out, function(a, b) return a.sort < b.sort end)

	local trimmed = {}
	for i = 1, math.min(limit, #out) do trimmed[i] = out[i] end
	cache = trimmed
	return trimmed
end

local function Signature(e)
	return ("%s|%s|%s|%s|%s"):format(tostring(e.title), tostring(e.year),
		tostring(e.month), tostring(e.day), tostring(e.sort))
end

function Events.MarkAuthoring()
	authoringUntil = GetTime() + 900
end

local function Alert(count)
	local id = DeadByDawnDB.eventSound
	if id == false then return end
	pcall(PlaySound, id or (SOUNDKIT and SOUNDKIT.RAID_WARNING) or 8959)
end

local function AnnounceNew(list)
	if DeadByDawnDB.eventChat == false then return end
	if GetTime() > authoringUntil then return end
	authoringUntil = 0
	local e = list[1]
	if not e then return end
	local text = ("%s Guild event scheduled: %s - %s. Sign up on the calendar.")
		:format(ns.CHAT_MARK, e.title, Events.Describe(e))
	pcall(SendChatMessage, text:sub(1, 255), "GUILD")
end

function Events.CheckForNew()
	local list = Events.Upcoming(60)
	local fresh = {}
	for _, e in ipairs(list) do
		local sig = Signature(e)
		if not known[sig] then
			known[sig] = true
			if primed then fresh[#fresh + 1] = e end
		end
	end
	if not primed then
		primed = true
		return
	end
	if #fresh == 0 then return end
	Alert(#fresh)
	AnnounceNew(fresh)
	if ns.UI and ns.UI.Refresh then ns.UI.Refresh() end
end

function Events.Describe(e)
	local parts = {}
	if e.weekday and WEEKDAYS[e.weekday] then
		parts[#parts + 1] = WEEKDAYS[e.weekday]
	end
	local monthName = e.month and MONTHS[e.month]
	if monthName then
		parts[#parts + 1] = ("%d %s"):format(e.day, monthName)
	else
		parts[#parts + 1] = ("day %d"):format(e.day)
	end
	local when = table.concat(parts, " ")
	if e.hour or e.minute then
		when = ("%s, %02d:%02d"):format(when, e.hour or 0, e.minute or 0)
	end
	if e.kind then
		when = ("%s   |cff808080%s|r"):format(when, e.kind)
	end
	return when
end

function Events.OpenCalendar()
	if ns.UI and ns.UI.HideWindow then ns.UI.HideWindow() end
	local loader = (C_AddOns and C_AddOns.LoadAddOn) or _G.LoadAddOn
	if loader then pcall(loader, "Blizzard_Calendar") end
	Events.MarkAuthoring()
	if _G.ToggleCalendar then
		local ok = pcall(_G.ToggleCalendar)
		if ok then return true end
	end
	local f = _G.CalendarFrame
	if f then
		if f:IsShown() then f:Hide() else f:Show() end
		return true
	end
	return false
end

function Events.Init()
	local f = CreateFrame("Frame")
	f:RegisterEvent("CALENDAR_UPDATE_EVENT_LIST")
	f:SetScript("OnEvent", function()
		if not ns.Active() then return end
		lastScan = 0
		if C_Timer and C_Timer.After then
			C_Timer.After(1, function() pcall(Events.CheckForNew) end)
		else
			pcall(Events.CheckForNew)
		end
	end)
	if C_Timer and C_Timer.After then
		C_Timer.After(10, function() pcall(Events.CheckForNew) end)
	end
end

function Events.CanOpenCalendar()
	return (_G.ToggleCalendar ~= nil or _G.CalendarFrame ~= nil)
end

function Events.CanCreateGuildEvent()
	return (C_Calendar and C_Calendar.CreateGuildSignUpEvent) and true or false
end

local ADDON, ns = ...

local QH = {}
ns.QuestHelp = QH

local PREFIX = "DBDQuestHelp"
local REQUEST_EXPIRE = 1800
local CHAT_COOLDOWN = 60
local REBROADCAST = 120

local lastChat = 0
local lastBroadcast = 0

QH.requests = {}
QH.mine = nil
QH.pending = nil

local function Clean(s)
	if type(s) ~= "string" then return "" end
	return (s:gsub("[~\n\r]", " "):sub(1, 80))
end

local function ShortName(name)
	return (name or ""):match("^([^-]+)") or name
end

function QH.QuestLogEntries()
	local out, source = {}, "none"
	if C_QuestLog and C_QuestLog.GetNumQuestLogEntries and C_QuestLog.GetInfo then
		local ok, n = pcall(C_QuestLog.GetNumQuestLogEntries)
		if ok and n then
			source = "C_QuestLog"
			for i = 1, n do
				local ok2, info = pcall(C_QuestLog.GetInfo, i)
				if ok2 and info and not info.isHeader and info.title then
					out[#out + 1] = { id = info.questID, title = info.title, level = info.level }
				end
			end
			return out, source
		end
	end
	if _G.GetNumQuestLogEntries and _G.GetQuestLogTitle then
		local ok, n = pcall(_G.GetNumQuestLogEntries)
		if ok and n then
			source = "legacy"
			for i = 1, n do
				local title, level, _, isHeader = _G.GetQuestLogTitle(i)
				if title and not isHeader then
					local id
					if _G.GetQuestIDForLogIndex then
						local ok2, v = pcall(_G.GetQuestIDForLogIndex, i)
						if ok2 then id = v end
					end
					out[#out + 1] = { id = id, title = title, level = level }
				end
			end
		end
	end
	return out, source
end

function QH.QuestLink(id, title)
	if id and _G.GetQuestLink then
		local ok, link = pcall(_G.GetQuestLink, id)
		if ok and link and link ~= "" then return link end
	end
	if id and id > 0 then
		return ("|cffffff00|Hquest:%d:-1|h[%s]|h|r"):format(id, title or "Quest")
	end
	return title and ("[" .. title .. "]") or nil
end

local function Alert()
	local id = DeadByDawnDB.helpSound
	if id == false then return end
	if not id then
		id = (SOUNDKIT and SOUNDKIT.TELL_MESSAGE) or 3081
	end
	pcall(PlaySound, id)
end

local function Send(msg, channel, target)
	if not (C_ChatInfo and C_ChatInfo.SendAddonMessage) then return end
	msg = ns.Stamp(msg)
	if channel == "WHISPER" then
		pcall(C_ChatInfo.SendAddonMessage, PREFIX, msg, "WHISPER", target)
	else
		pcall(C_ChatInfo.SendAddonMessage, PREFIX, msg, "GUILD")
	end
end

function QH.Broadcast(force)
	if not QH.mine then return end
	local now = GetTime()
	if not force and now - lastBroadcast < REBROADCAST then return end
	lastBroadcast = now
	local m = QH.mine
	Send(("ASK~%d~%s~%s~%s"):format(m.questID or 0, Clean(m.title),
		Clean(m.zone), Clean(m.note)), "GUILD")
end

function QH.Announce()
	local m = QH.mine
	if not m then return end
	if DeadByDawnDB.helpChat == false then return end
	local now = GetTime()
	if now - lastChat < CHAT_COOLDOWN then
		return ns.Print("guild chat announce is on cooldown, the request is still listed.")
	end
	lastChat = now
	local keyword = DeadByDawnDB.helpKeyword or "+"
	local what = m.questID and m.questID > 0 and QH.QuestLink(m.questID, m.title) or "questing"
	local text
	if m.note and m.note ~= "" then
		text = ("%s %s needs a hand with %s - %s. Type %s for an invite.")
			:format(ns.CHAT_MARK, ShortName(m.name), what, m.note, keyword)
	else
		text = ("%s %s needs a hand with %s. Type %s for an invite.")
			:format(ns.CHAT_MARK, ShortName(m.name), what, keyword)
	end
	pcall(SendChatMessage, text:sub(1, 255), "GUILD")
end

function QH.Open(questID, title, note)
	local zone = GetRealZoneText and GetRealZoneText() or nil
	QH.mine = {
		name = ns.FullName(),
		questID = questID or 0,
		title = title or "",
		zone = zone or "",
		note = note or "",
		t = GetTime(),
	}
	QH.Broadcast(true)
	QH.Announce()
	ns.Print("help request posted.")
	if ns.UI and ns.UI.Refresh then ns.UI.Refresh() end
end

function QH.Close()
	if not QH.mine then return end
	QH.mine = nil
	Send("DROP", "GUILD")
	ns.Print("help request withdrawn.")
	if ns.UI and ns.UI.Refresh then ns.UI.Refresh() end
end

function QH.Prune()
	local now = GetTime()
	for who, r in pairs(QH.requests) do
		if now - (r.t or 0) > REQUEST_EXPIRE then QH.requests[who] = nil end
	end
	if QH.pending and now - QH.pending.t > 60 then QH.pending = nil end
end

function QH.List()
	QH.Prune()
	local out = {}
	for _, r in pairs(QH.requests) do out[#out + 1] = r end
	if QH.mine then
		local copy = {}
		for k, v in pairs(QH.mine) do copy[k] = v end
		copy.isMine = true
		out[#out + 1] = copy
	end
	table.sort(out, function(a, b)
		if a.isMine ~= b.isMine then return a.isMine and true or false end
		return (a.t or 0) > (b.t or 0)
	end)
	return out
end

function QH.AskInvite(fullName)
	if IsInGroup() then return ns.Print("leave your group first.") end
	QH.pending = { name = fullName, t = GetTime() }
	Send("WANT", "WHISPER", fullName)
	ns.Print("asked %s for an invite.", ShortName(fullName))
end

local function InviteUnit(name)
	if C_PartyInfo and C_PartyInfo.InviteUnit then
		return pcall(C_PartyInfo.InviteUnit, name)
	elseif _G.InviteUnit then
		return pcall(_G.InviteUnit, name)
	end
end

local function CanInvite()
	if not IsInGroup() then return true end
	local n = GetNumGroupMembers() or 1
	local raid = IsInRaid()
	local lead = UnitIsGroupLeader("player")
	if not lead and raid and UnitIsGroupAssistant then lead = UnitIsGroupAssistant("player") end
	return lead and n < (raid and 40 or 5)
end

function QH.HandleWant(sender)
	if not QH.mine then return end
	if not CanInvite() then
		ns.Print("%s wants an invite but you cannot invite right now.", ShortName(sender))
		return
	end
	ns.Print("%s wants to join - inviting.", ShortName(sender))
	InviteUnit(sender)
end

local function OnAddonMessage(prefix, text, _, sender)
	if prefix ~= PREFIX or not sender then return end
	if ShortName(sender) == ShortName(UnitName("player")) then return end
	if not ns.Active() then return end

	local payload, remoteVersion = ns.Unstamp(text)
	ns.NoteRemoteVersion(remoteVersion)
	text = payload

	local kind, rest = text:match("^(%u+)~?(.*)$")
	kind = kind or text

	if kind == "ASK" then
		local questID, title, zone, note = rest:match("^([^~]*)~([^~]*)~([^~]*)~?(.*)$")
		QH.requests[sender] = {
			name = sender,
			questID = tonumber(questID) or 0,
			title = title or "",
			zone = zone or "",
			note = note or "",
			t = GetTime(),
		}
		Alert()
		if ns.UI and ns.UI.Refresh then ns.UI.Refresh() end

	elseif kind == "DROP" then
		QH.requests[sender] = nil
		if ns.UI and ns.UI.Refresh then ns.UI.Refresh() end

	elseif kind == "WANT" then
		QH.HandleWant(sender)
	end
end

local function OnGuildChat(text, sender)
	if not QH.mine or not sender then return end
	if not text then return end
	local keyword = DeadByDawnDB.helpKeyword or "+"
	local trimmed = text:match("^%s*(.-)%s*$")
	if trimmed:lower() ~= keyword:lower() then return end
	if ShortName(sender) == ShortName(UnitName("player")) then return end
	QH.HandleWant(sender)
end

local function OnInviteRequest(inviter)
	QH.Prune()
	if not QH.pending then return end
	if ShortName(inviter) ~= ShortName(QH.pending.name) then return end
	QH.pending = nil
	if AcceptGroup then AcceptGroup() end
	if StaticPopup_Hide then StaticPopup_Hide("PARTY_INVITE") end
end

function QH.Init()
	if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
		pcall(C_ChatInfo.RegisterAddonMessagePrefix, PREFIX)
	end

	local f = CreateFrame("Frame")
	f:RegisterEvent("CHAT_MSG_ADDON")
	f:RegisterEvent("CHAT_MSG_GUILD")
	f:RegisterEvent("PARTY_INVITE_REQUEST")
	f:RegisterEvent("PLAYER_LOGOUT")
	f:SetScript("OnEvent", function(_, event, a1, a2, a3, a4)
		if event == "CHAT_MSG_ADDON" then
			OnAddonMessage(a1, a2, a3, a4)
		elseif event == "CHAT_MSG_GUILD" then
			OnGuildChat(a1, a2)
		elseif event == "PARTY_INVITE_REQUEST" then
			OnInviteRequest(a1)
		elseif event == "PLAYER_LOGOUT" then
			if QH.mine then Send("DROP", "GUILD") end
		end
	end)

	if C_Timer and C_Timer.After then
		C_Timer.After(12, function()
			if ns.Active() then Send("HELLO", "GUILD") end
		end)
	end

	if C_Timer and C_Timer.NewTicker then
		C_Timer.NewTicker(15, function()
			QH.Prune()
			QH.Broadcast(false)
			if ns.UI and ns.UI.Refresh then ns.UI.Refresh() end
		end)
	end
end

local ADDON, ns = ...

local UI = {}
ns.UI = UI

local FRAME_W = 548
local PAD = 16
local ROW_H = 26
local NAME_W = 140
local CAP_W = 70
local HEADER_Y = 82
local HELP_ROWS = 8
local HELP_ROW_H = 34

local frame, host, tabs, panels
local rankRows, statusText
local infoName, infoMeta, infoEventsHeader, eventRows, calendarButton
local eventOffset = 0
local memberRows, memberStatus, memberOffset = nil, nil, 0
local helpRows, helpStatus, askButton, withdrawButton
local picker

local function DockOffset(h)
	if h == _G.CommunitiesFrame and h.ChatTab and h.ChatTab:IsShown() then return 78 end
	return 48
end

function UI.FollowHost(h)
	if not frame or not frame:IsShown() then return end
	if host ~= h then return end
	frame:ClearAllPoints()
	frame:SetPoint("TOPLEFT", h, "TOPRIGHT", DockOffset(h), 0)
	local height = h:GetHeight()
	if height and height > 260 then frame:SetHeight(height) end
end

function UI.HideWindow()
	if frame then frame:Hide() end
	if picker then picker:Hide() end
end

function UI.CloseIfDocked(h)
	if frame and frame:IsShown() and host == h then frame:Hide() end
	if picker then picker:Hide() end
end

local function CapForRank(rankIndex, capKey)
	local matrix = DeadByDawnDB.caps
	if matrix and matrix[rankIndex] and matrix[rankIndex][capKey] ~= nil then
		return matrix[rankIndex][capKey] and true or false
	end
	local threshold = ns.DEFAULT_CAPS_BY_RANK[capKey]
	if threshold == nil then return false end
	return rankIndex <= threshold
end

local function SetCap(rankIndex, capKey, value)
	DeadByDawnDB.caps = DeadByDawnDB.caps or {}
	DeadByDawnDB.caps[rankIndex] = DeadByDawnDB.caps[rankIndex] or {}
	DeadByDawnDB.caps[rankIndex][capKey] = value and true or false
	DeadByDawnDB.capsRevision = (DeadByDawnDB.capsRevision or 0) + 1
end

local function ShortName(name)
	return (name or ""):match("^([^-]+)") or name
end

local function CreateHelpRow(parent, index)
	local row = CreateFrame("Frame", nil, parent)
	row:SetSize(FRAME_W - PAD * 2, HELP_ROW_H)
	row:SetPoint("TOPLEFT", PAD, -(HEADER_Y + (index - 1) * HELP_ROW_H))

	row.action = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
	row.action:SetSize(90, 20)
	row.action:SetPoint("RIGHT", 0, 0)
	row.action:SetScript("OnClick", function()
		if not row.who then return end
		if row.isMine then
			ns.QuestHelp.Close()
		else
			ns.QuestHelp.AskInvite(row.who)
		end
	end)

	ns.Style.Stripe(row, index)
	ns.Style.Hover(row)

	row.top = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	row.top:SetPoint("TOPLEFT", 2, -2)
	row.top:SetPoint("RIGHT", row.action, "LEFT", -8, 0)
	row.top:SetJustifyH("LEFT")
	row.top:SetWordWrap(false)

	row.sub = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	row.sub:SetPoint("TOPLEFT", 2, -18)
	row.sub:SetPoint("RIGHT", row.action, "LEFT", -8, 0)
	row.sub:SetJustifyH("LEFT")
	row.sub:SetWordWrap(false)

	row:Hide()
	return row
end

local function CreateRankRow(parent, index)
	local row = CreateFrame("Frame", nil, parent)
	row:SetSize(FRAME_W - PAD * 2, ROW_H)
	row:SetPoint("TOPLEFT", PAD, -(HEADER_Y + 18 + (index - 1) * ROW_H))

	ns.Style.Stripe(row, index)

	row.name = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	row.name:SetPoint("LEFT", 2, 0)
	row.name:SetWidth(NAME_W)
	row.name:SetJustifyH("LEFT")
	row.name:SetWordWrap(false)

	row.boxes = {}
	for i, cap in ipairs(ns.CAPS) do
		local cb = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
		cb:SetSize(22, 22)
		cb:SetPoint("LEFT", NAME_W + 10 + (i - 1) * CAP_W + (CAP_W - 22) / 2, 0)
		cb:SetScript("OnClick", function(self)
			if not ns.Ranks:AmGuildMaster() then
				self:SetChecked(CapForRank(row.rankIndex, cap.key))
				return ns.Print("only the guild master can change this.")
			end
			if row.rankIndex == 0 then self:SetChecked(true) return end
			SetCap(row.rankIndex, cap.key, self:GetChecked())
		end)
		cb:SetScript("OnEnter", function(self)
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			GameTooltip:AddLine(cap.label)
			GameTooltip:Show()
		end)
		cb:SetScript("OnLeave", function() GameTooltip:Hide() end)
		row.boxes[cap.key] = cb
	end

	row:Hide()
	return row
end

local function RefreshInfo()
	local guild = ns.GuildName()
	local mine = ns.Ranks:MyIndex()
	infoName:SetText(("%s%s%s"):format(ns.Style.HEX_BLOOD, (guild or "No guild"):upper(), ns.Style.R))

	local total, online = 0, 0
	if GetNumGuildMembers then
		local ok, t, o = pcall(GetNumGuildMembers)
		if ok then total, online = t or 0, o or 0 end
	end
	infoMeta:SetText(("%s%s%s   %s%d online of %d%s")
		:format(ns.Style.HEX_BONE, ns.Ranks:NameOf(mine) or "unranked", ns.Style.R,
			ns.Style.HEX_ASH, online, total, ns.Style.R))

	local height = frame:GetHeight() or 520
	local room = height - 122 - 56
	local fits = math.max(1, math.min(#eventRows, math.floor(room / 30)))

	local list = ns.Events.Upcoming(60)
	local maxOffset = math.max(0, #list - fits)
	if eventOffset > maxOffset then eventOffset = maxOffset end
	if eventOffset < 0 then eventOffset = 0 end
	ns.UI.eventFits = fits
	ns.UI.eventTotal = #list
	if not ns.Events.Available() then
		infoEventsHeader:SetText(ns.Style.HEX_EMBER .. "UPCOMING GUILD EVENTS" .. ns.Style.R
			.. "   |cffff8080calendar unavailable|r")
	else
		local more = ""
		if #list > fits then
			more = ("   %s%d-%d of %d%s"):format(ns.Style.HEX_ASH,
				eventOffset + 1, math.min(eventOffset + fits, #list), #list, ns.Style.R)
		end
		infoEventsHeader:SetText(("%sUPCOMING GUILD EVENTS%s   %s%d%s%s"):format(
			ns.Style.HEX_EMBER, ns.Style.R, ns.Style.HEX_ASH, #list, ns.Style.R, more))
	end

	calendarButton:SetEnabled(ns.Events.CanOpenCalendar())

	for i = 1, #eventRows do
		local row, e = eventRows[i], (i <= fits) and list[i + eventOffset] or nil
		if e then
			row.title:SetText(ns.Style.HEX_BONE .. e.title .. ns.Style.R)
			row.when:SetText(ns.Events.Describe(e))
			row:Show()
		else
			row:Hide()
		end
	end
	if #list == 0 then
		eventRows[1].title:SetText("|cff808080No guild events scheduled.|r")
		eventRows[1].when:SetText("")
		eventRows[1]:Show()
	end
end

local function RefreshMembers()
	local online = ns.Ranks:OnlineMembers()
	local have, missing = {}, {}
	for _, m in ipairs(online) do
		if ns.HasAddon(m.name) then
			m.version = ns.HasAddon(m.name)
			have[#have + 1] = m
		else
			missing[#missing + 1] = m
		end
	end

	memberStatus:SetText(("%s%d of %d online have Dead by Dawn%s\n%sonly people online can be detected%s")
		:format(ns.Style.HEX_BONE, #have, #online, ns.Style.R,
			ns.Style.HEX_ASH, ns.Style.R))

	local list = {}
	for _, m in ipairs(have) do m.has = true ; list[#list + 1] = m end
	for _, m in ipairs(missing) do m.has = false ; list[#list + 1] = m end

	local fits = #memberRows
	ns.UI.memberFits, ns.UI.memberTotal = fits, #list
	if memberOffset > math.max(0, #list - fits) then
		memberOffset = math.max(0, #list - fits)
	end

	for i = 1, fits do
		local row, m = memberRows[i], list[i + memberOffset]
		if m then
			local short = (m.name or ""):match("^([^-]+)") or m.name
			row.name:SetText(ns.Style.ClassHex(m.class) .. short .. ns.Style.R)
			if m.has then
				row.state:SetText(("%syes%s  %s%s%s"):format(ns.Style.HEX_ROT, ns.Style.R,
					ns.Style.HEX_ASH, m.version or "", ns.Style.R))
			else
				row.state:SetText(ns.Style.HEX_ASH .. "no" .. ns.Style.R)
			end
			row:Show()
		else
			row:Hide()
		end
	end
end

local function RefreshHelp()
	local list = ns.QuestHelp.List()
	local keyword = DeadByDawnDB.helpKeyword or "+"
	helpStatus:SetText(("Open requests: %s%d%s   |cff808080guildmates can also type %s in guild chat|r")
		:format("|cffffd100", #list, "|r", keyword))

	local inGroup = IsInGroup()
	for i = 1, HELP_ROWS do
		local row, r = helpRows[i], list[i]
		if r then
			row.who = r.name
			row.isMine = r.isMine and true or false
			local what = (r.questID and r.questID > 0)
				and ns.QuestHelp.QuestLink(r.questID, r.title)
				or (r.title ~= "" and r.title or "grouping up")
			if r.isMine then
				row.top:SetText(("|cffffd100You|r  %s"):format(what or ""))
				row.action:SetText("Withdraw")
				row.action:SetEnabled(true)
			else
				row.top:SetText(("%s  %s"):format(ns.Style.Name(r.name), what or ""))
				row.action:SetText("Invite me")
				row.action:SetEnabled(not inGroup)
			end
			local bits = {}
			if r.zone and r.zone ~= "" then bits[#bits + 1] = r.zone end
			if r.note and r.note ~= "" then bits[#bits + 1] = r.note end
			row.sub:SetText(table.concat(bits, "  -  "))
			row:Show()
		else
			row:Hide()
		end
	end

	if #list == 0 then
		helpRows[1].who = nil
		helpRows[1].top:SetText("|cff808080Nobody needs help right now.|r")
		helpRows[1].sub:SetText("")
		helpRows[1].action:Hide()
		helpRows[1]:Show()
	else
		helpRows[1].action:Show()
	end

	askButton:SetText(ns.QuestHelp.mine and "Re-announce" or "Ask for help")
	withdrawButton:SetShown(ns.QuestHelp.mine ~= nil)
end

local function RefreshRanks()
	local isGM = ns.Ranks:AmGuildMaster()
	if ns.DEV then
		statusText:SetText("|cffff8000TEST MODE|r - all permissions granted regardless of rank.")
	elseif isGM then
		statusText:SetText("You are the guild master. Tick what each rank may do.")
	else
		statusText:SetText("|cff808080Only the guild master can change these.|r")
	end

	local ranks = ns.Ranks:All()
	for i = 1, #rankRows do
		local row, r = rankRows[i], ranks[i]
		if r then
			row.rankIndex = r.index
			local label = r.name or ("Rank " .. r.index)
			if r.index == 0 then label = label .. " |cffffd100(GM)|r" end
			row.name:SetText(label)
			for _, cap in ipairs(ns.CAPS) do
				local cb = row.boxes[cap.key]
				if r.index == 0 then
					cb:SetChecked(true)
					cb:SetEnabled(false)
				else
					cb:SetChecked(CapForRank(r.index, cap.key))
					cb:SetEnabled(isGM)
				end
			end
			row:Show()
		else
			row:Hide()
		end
	end
end

function UI.Refresh()
	if not frame or not frame:IsShown() then return end
	if panels.info:IsShown() then RefreshInfo()
	elseif panels.help:IsShown() then RefreshHelp()
	elseif panels.members:IsShown() then RefreshMembers()
	else RefreshRanks() end
end

local function ShowPanel(which)
	for name, p in pairs(panels) do p:SetShown(name == which) end
	for name, t in pairs(tabs) do
		t:SetChecked(name == which)
	end
	UI.Refresh()
end

local function BuildPicker()
	local p = CreateFrame("Frame", "DeadByDawnPicker", UIParent, "BasicFrameTemplateWithInset")
	p:SetSize(320, 400)
	p:SetFrameStrata("DIALOG")
	p:SetClampedToScreen(true)
	p:Hide()
	if p.SetTitle then p:SetTitle("Which quest?") elseif p.TitleText then p.TitleText:SetText("Which quest?") end

	p.rows = {}
	for i = 1, 12 do
		local b = CreateFrame("Button", nil, p, "UIPanelButtonTemplate")
		b:SetSize(288, 20)
		b:SetPoint("TOPLEFT", 16, -(34 + (i - 1) * 22))
		b:SetScript("OnClick", function(self)
			ns.QuestHelp.Open(self.questID, self.questTitle, nil)
			p:Hide()
		end)
		b:Hide()
		p.rows[i] = b
	end
	return p
end

local function OpenPicker()
	if not picker then picker = BuildPicker() end
	local quests = ns.QuestHelp.QuestLogEntries()

	local entries = { { id = 0, title = "Just grouping up" } }
	for _, q in ipairs(quests) do entries[#entries + 1] = q end

	for i, b in ipairs(picker.rows) do
		local e = entries[i]
		if e then
			b.questID = e.id or 0
			b.questTitle = e.title
			b:SetText(e.title:sub(1, 40))
			b:Show()
		else
			b:Hide()
		end
	end
	picker:ClearAllPoints()
	picker:SetPoint("TOPLEFT", frame, "TOPRIGHT", 4, 0)
	picker:Show()
end

local function CreateWindow()
	local f = CreateFrame("Frame", "DeadByDawnFrame", UIParent, "BasicFrameTemplateWithInset")
	f:SetSize(FRAME_W, 520)
	f:SetPoint("CENTER")
	f:SetMovable(true)
	f:EnableMouse(true)
	f:RegisterForDrag("LeftButton")
	f:SetScript("OnDragStart", function(self) host = nil ; self:StartMoving() end)
	f:SetScript("OnDragStop", f.StopMovingOrSizing)
	f:SetClampedToScreen(true)
	f:SetFrameStrata("HIGH")
	f:Hide()

	ns.Style.Backdrop(f)

	local topBar = ns.Style.AccentBar(f, 3)
	topBar:SetPoint("TOPLEFT", 6, -24)
	topBar:SetPoint("TOPRIGHT", -6, -24)

	if f.SetTitle then
		f:SetTitle("Dead by Dawn")
	elseif f.TitleText then
		f.TitleText:SetText("Dead by Dawn")
	elseif f.TitleContainer and f.TitleContainer.TitleText then
		f.TitleContainer.TitleText:SetText("Dead by Dawn")
	end

	f:SetHyperlinksEnabled(true)
	f:SetScript("OnHyperlinkClick", function(_, link, text, button)
		if SetItemRef then SetItemRef(link, text, button) end
	end)
	f:SetScript("OnHyperlinkEnter", function(self, link)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		pcall(GameTooltip.SetHyperlink, GameTooltip, link)
		GameTooltip:Show()
	end)
	f:SetScript("OnHyperlinkLeave", function() GameTooltip:Hide() end)

	panels = {
		info = CreateFrame("Frame", nil, f),
		help = CreateFrame("Frame", nil, f),
		ranks = CreateFrame("Frame", nil, f),
		members = CreateFrame("Frame", nil, f),
	}
	for _, p in pairs(panels) do
		p:SetPoint("TOPLEFT")
		p:SetPoint("BOTTOMRIGHT")
		p:Hide()
	end

	tabs = {}
	local function MakeTab(key, label, icon, index)
		local t = CreateFrame("CheckButton", nil, f)
		t:SetSize(32, 32)
		t:SetPoint("TOPLEFT", f, "TOPRIGHT", -1, -(36 + (index - 1) * 44))

		local bg = t:CreateTexture(nil, "BACKGROUND")
		bg:SetTexture("Interface\\SpellBook\\SpellBookSkillLineTab")
		bg:SetPoint("TOPLEFT", -3, 11)
		bg:SetSize(64, 64)

		local tex = t:CreateTexture(nil, "ARTWORK")
		tex:SetTexture(icon)
		tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
		tex:SetAllPoints()

		t:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square")
		local ht = t.GetHighlightTexture and t:GetHighlightTexture()
		if ht then ht:SetBlendMode("ADD") end

		t:SetCheckedTexture("Interface\\Buttons\\CheckButtonHilight")
		local ct = t.GetCheckedTexture and t:GetCheckedTexture()
		if ct then
			ct:SetBlendMode("ADD")
			ct:SetAlpha(0.85)
		end

		t:SetScript("OnClick", function() ShowPanel(key) end)
		t:SetScript("OnEnter", function(self)
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			GameTooltip:AddLine(label)
			GameTooltip:Show()
		end)
		t:SetScript("OnLeave", function() GameTooltip:Hide() end)
		tabs[key] = t
	end
	MakeTab("info", "Guild Info", "Interface\\Icons\\INV_Shirt_GuildTabard_01", 1)
	MakeTab("help", "Quest Help", "Interface\\Icons\\INV_Scroll_03", 2)
	MakeTab("ranks", "Ranks", "Interface\\Icons\\INV_Misc_Note_01", 3)
	MakeTab("members", "Who has the addon", "Interface\\Icons\\INV_Misc_GroupLooking", 4)

	memberStatus = panels.members:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	memberStatus:SetPoint("TOPLEFT", PAD, -40)
	memberStatus:SetPoint("TOPRIGHT", -PAD, -40)
	memberStatus:SetJustifyH("LEFT")
	memberStatus:SetHeight(32)
	memberStatus:SetWordWrap(true)

	panels.members:EnableMouseWheel(true)
	panels.members:SetScript("OnMouseWheel", function(_, delta)
		local fits = ns.UI.memberFits or 1
		local total = ns.UI.memberTotal or 0
		if total <= fits then return end
		memberOffset = memberOffset - delta
		if memberOffset < 0 then memberOffset = 0 end
		if memberOffset > total - fits then memberOffset = total - fits end
		UI.Refresh()
	end)

	memberRows = {}
	for i = 1, 14 do
		local row = CreateFrame("Frame", nil, panels.members)
		row:SetSize(FRAME_W - PAD * 2, 22)
		row:SetPoint("TOPLEFT", PAD, -(82 + (i - 1) * 22))
		ns.Style.Stripe(row, i)
		row.name = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		row.name:SetPoint("LEFT", 2, 0)
		row.name:SetWidth(200)
		row.name:SetJustifyH("LEFT")
		row.name:SetWordWrap(false)
		row.state = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
		row.state:SetPoint("LEFT", 210, 0)
		row.state:SetJustifyH("LEFT")
		row:Hide()
		memberRows[i] = row
	end

	infoName = panels.info:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	infoName:SetPoint("TOPLEFT", PAD, -40)
	infoName:SetJustifyH("LEFT")

	infoMeta = panels.info:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	infoMeta:SetPoint("TOPLEFT", PAD, -64)
	infoMeta:SetJustifyH("LEFT")

	ns.Style.Divider(panels.info, -88, PAD)

	infoEventsHeader = panels.info:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	infoEventsHeader:SetPoint("TOPLEFT", PAD, -96)
	infoEventsHeader:SetJustifyH("LEFT")

	panels.info:EnableMouseWheel(true)
	panels.info:SetScript("OnMouseWheel", function(_, delta)
		local fits = ns.UI.eventFits or 1
		local total = ns.UI.eventTotal or 0
		if total <= fits then return end
		eventOffset = eventOffset - delta
		if eventOffset < 0 then eventOffset = 0 end
		local maxOffset = total - fits
		if eventOffset > maxOffset then eventOffset = maxOffset end
		UI.Refresh()
	end)

	eventRows = {}
	for i = 1, 10 do
		local row = CreateFrame("Frame", nil, panels.info)
		row:SetSize(FRAME_W - PAD * 2, 30)
		row:SetPoint("TOPLEFT", PAD, -(122 + (i - 1) * 30))
			ns.Style.Stripe(row, i)
		ns.Style.Hover(row)
	row.title = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		row.title:SetPoint("TOPLEFT", 2, -2)
		row.title:SetJustifyH("LEFT")
		row.title:SetWordWrap(false)
		row.when = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
		row.when:SetPoint("TOPLEFT", 2, -16)
		row.when:SetJustifyH("LEFT")
		row:Hide()
		eventRows[i] = row
	end

	helpStatus = panels.help:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	helpStatus:SetPoint("TOPLEFT", PAD, -40)
	helpStatus:SetPoint("TOPRIGHT", -PAD, -40)
	helpStatus:SetJustifyH("LEFT")
	helpStatus:SetHeight(30)
	helpStatus:SetWordWrap(true)

	helpRows = {}
	for i = 1, HELP_ROWS do helpRows[i] = CreateHelpRow(panels.help, i) end

	askButton = CreateFrame("Button", nil, panels.help, "UIPanelButtonTemplate")
	askButton:SetSize(132, 24)
	askButton:SetPoint("BOTTOMLEFT", PAD, 16)
	askButton:SetScript("OnClick", function()
		if ns.QuestHelp.mine then ns.QuestHelp.Announce() else OpenPicker() end
	end)

	withdrawButton = CreateFrame("Button", nil, panels.help, "UIPanelButtonTemplate")
	withdrawButton:SetSize(110, 24)
	withdrawButton:SetPoint("LEFT", askButton, "RIGHT", 8, 0)
	withdrawButton:SetText("Withdraw")
	withdrawButton:SetScript("OnClick", function() ns.QuestHelp.Close() end)
	withdrawButton:Hide()

	statusText = panels.ranks:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	statusText:SetPoint("TOPLEFT", PAD, -40)
	statusText:SetPoint("TOPRIGHT", -PAD, -40)
	statusText:SetJustifyH("LEFT")
	statusText:SetHeight(30)
	statusText:SetWordWrap(true)

	for i, cap in ipairs(ns.CAPS) do
		local fs = panels.ranks:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
		fs:SetPoint("TOPLEFT", PAD + NAME_W + 10 + (i - 1) * CAP_W, -HEADER_Y)
		fs:SetWidth(CAP_W)
		fs:SetJustifyH("CENTER")
		fs:SetText(cap.short or cap.label)
	end
	local rankHeader = panels.ranks:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	rankHeader:SetPoint("TOPLEFT", PAD + 2, -HEADER_Y)
	rankHeader:SetText("Rank")

	calendarButton = CreateFrame("Button", nil, panels.info, "UIPanelButtonTemplate")
	calendarButton:SetSize(170, 24)
	calendarButton:SetPoint("BOTTOMLEFT", PAD, 16)
	calendarButton:SetSize(230, 24)
	calendarButton:SetText("Open Calendar to schedule")
	calendarButton:SetScript("OnClick", function()
		if not ns.Events.OpenCalendar() then
			ns.Print("the calendar is not available on this client.")
		end
	end)
	calendarButton:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:AddLine("Open Calendar")
		GameTooltip:AddLine("Pick a day, then Create Guild Event.", 0.8, 0.8, 0.8, true)
		GameTooltip:Show()
	end)
	calendarButton:SetScript("OnLeave", function() GameTooltip:Hide() end)

	rankRows = {}
	for i = 1, 10 do rankRows[i] = CreateRankRow(panels.ranks, i) end

	return f
end

local watching = false

function UI.WatchOtherWindows()
	if watching then return end
	watching = true

	if _G.ShowUIPanel then
		pcall(hooksecurefunc, "ShowUIPanel", function(f)
			if not frame or not frame:IsShown() then return end
			if f == frame or f == host then return end
			UI.HideWindow()
		end)
	end

	local watch = { "CalendarFrame", "WorldMapFrame", "CharacterFrame", "SpellBookFrame",
		"MerchantFrame", "BankFrame", "MailFrame", "TradeSkillFrame", "AuctionHouseFrame",
		"GossipFrame", "QuestFrame", "TaxiFrame", "TradeFrame", "GuildBankFrame",
		"ClassTrainerFrame", "PVPFrame", "LFGParentFrame", "PetStableFrame" }

	local function HookShow(name)
		local f = _G[name]
		if not f or not f.HookScript or f.deadByDawnHooked then return end
		f.deadByDawnHooked = true
		f:HookScript("OnShow", function()
			if frame and frame:IsShown() then UI.HideWindow() end
		end)
	end
	for _, name in ipairs(watch) do HookShow(name) end

	local later = CreateFrame("Frame")
	later:RegisterEvent("ADDON_LOADED")
	later:SetScript("OnEvent", function()
		for _, name in ipairs(watch) do HookShow(name) end
	end)
end

function UI.ToggleDocked(h)
	UI.WatchOtherWindows()
	if not frame then frame = CreateWindow() ; ShowPanel("info") end
	if frame:IsShown() and host == h then
		frame:Hide()
		if picker then picker:Hide() end
		return
	end
	host = h
	ns.Ranks:Scan()
	frame:Show()
	UI.FollowHost(h)
	UI.Refresh()
end

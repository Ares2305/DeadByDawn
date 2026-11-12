local ADDON, ns = ...

local Hook = {}
ns.GuildFrame = Hook

local byFrame = {}
local hosts = {}

local WATCH = { Blizzard_Communities = true, Blizzard_GuildUI = true }

local function Candidates()
	local out = {}
	if _G.CommunitiesFrame then
		out[#out + 1] = { frame = _G.CommunitiesFrame, kind = "communities" }
	end
	local guild = _G.GuildFrame
	if guild then
		local parent = guild.GetParent and guild:GetParent()
		local social = _G.FriendsFrame
		out[#out + 1] = { frame = guild, kind = (parent == social) and "social" or "guildui" }
	end
	return out
end

local function Attach(frame, kind)
	if byFrame[frame] then return false end

	local b = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	b:SetSize(112, 22)
	b:SetText("Dead by Dawn")
	if kind == "communities" then
		b:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -36, -28)
	else
		b:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -12, 12)
	end
	b:SetFrameLevel((frame:GetFrameLevel() or 1) + 10)
	b:SetScript("OnClick", function()
		if ns.UI and ns.UI.ToggleDocked then ns.UI.ToggleDocked(frame) end
	end)
	b:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_LEFT")
		GameTooltip:AddLine("Dead by Dawn")
		GameTooltip:AddLine("Guild scheduling and roster", 0.7, 0.7, 0.7)
		GameTooltip:Show()
	end)
	b:SetScript("OnLeave", function() GameTooltip:Hide() end)

	frame:HookScript("OnHide", function()
		if ns.UI and ns.UI.CloseIfDocked then ns.UI.CloseIfDocked(frame) end
	end)
	frame:HookScript("OnSizeChanged", function()
		if ns.UI and ns.UI.FollowHost then ns.UI.FollowHost(frame) end
	end)

	local tabs = (kind == "communities") and frame.ChatTab
	if tabs and tabs.HookScript then
		local function Follow()
			if ns.UI and ns.UI.FollowHost then ns.UI.FollowHost(frame) end
		end
		tabs:HookScript("OnShow", Follow)
		tabs:HookScript("OnHide", Follow)
	end

	byFrame[frame] = true
	hosts[#hosts + 1] = frame
	return true
end

function Hook.Scan()
	if not ns.Active() then return 0 end
	local added = 0
	for _, c in ipairs(Candidates()) do
		if not byFrame[c.frame] then
			local ok = pcall(Attach, c.frame, c.kind)
			if ok then added = added + 1 end
		end
	end
	return added
end

local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("GUILD_ROSTER_UPDATE")
f:SetScript("OnEvent", function(_, event, arg1)
	if event == "ADDON_LOADED" and not WATCH[arg1] then return end
	Hook.Scan()
	if C_Timer and C_Timer.After then
		C_Timer.After(1, Hook.Scan)
		C_Timer.After(5, Hook.Scan)
	end
end)

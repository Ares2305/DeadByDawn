local ADDON, ns = ...

local Ranks = {}
ns.Ranks = Ranks

local list = {}
local byName = {}
local classOf = {}
local myRosterName = nil

local lastScan = 0

function Ranks:Scan(force)
	local now = GetTime and GetTime() or 0
	if not force and now - lastScan < 5 and next(list) then return list end
	lastScan = now

	wipe(list)
	wipe(byName)
	wipe(classOf)
	myRosterName = nil
	local myGuid = UnitGUID and UnitGUID("player")

	local total = GetNumGuildMembers and GetNumGuildMembers() or 0
	for i = 1, total do
		local name, rankName, rankIndex, _, _, _, _, _, _, _, classFile,
			_, _, _, _, _, guid = GetGuildRosterInfo(i)
		if name and rankIndex then
			if not list[rankIndex] then list[rankIndex] = rankName or ("Rank " .. rankIndex) end
			byName[name] = rankIndex
			if classFile then classOf[name] = classFile end
			if myGuid and guid == myGuid then myRosterName = name end
		end
	end

	if GuildControlGetNumRanks and GuildControlGetRankName then
		local ok, n = pcall(GuildControlGetNumRanks)
		if ok and n then
			for i = 1, n do
				local ok2, rankName = pcall(GuildControlGetRankName, i)
				if ok2 and rankName then
					local idx = i - 1
					if not list[idx] then list[idx] = rankName end
				end
			end
		end
	end

	return list
end

function Ranks:All()
	local out = {}
	for idx, name in pairs(list) do
		out[#out + 1] = { index = idx, name = name }
	end
	table.sort(out, function(a, b) return a.index < b.index end)
	return out
end

function Ranks:OnlineMembers()
	local out = {}
	local total = GetNumGuildMembers and GetNumGuildMembers() or 0
	for i = 1, total do
		local name, rankName, rankIndex, level, _, _, _, _, online, _, classFile =
			GetGuildRosterInfo(i)
		if name and online then
			out[#out + 1] = {
				name = name,
				rank = rankName,
				rankIndex = rankIndex,
				level = level,
				class = classFile,
			}
		end
	end
	table.sort(out, function(a, b)
		if a.rankIndex ~= b.rankIndex then return a.rankIndex < b.rankIndex end
		return (a.name or "") < (b.name or "")
	end)
	return out
end

function Ranks:Count()
	local n = 0
	for _ in pairs(list) do n = n + 1 end
	return n
end

local function Variants(name)
	if not name or name == "" then return {} end
	local out = { name }
	local bare = name:match("^(.-)%-[^%-]*$")
	if bare and bare ~= "" and bare ~= name then out[#out + 1] = bare end
	return out
end

local function Lookup(tbl, name)
	for _, v in ipairs(Variants(name)) do
		if tbl[v] ~= nil then return tbl[v] end
	end
	return nil
end

function Ranks:ClassOf(fullName)
	return Lookup(classOf, fullName)
end

function Ranks:IndexOf(fullName)
	return Lookup(byName, fullName)
end

function Ranks:NameOf(index)
	return list[index]
end

function Ranks:MyName()
	return myRosterName or UnitName("player")
end

function Ranks:MyIndex()
	if myRosterName and byName[myRosterName] ~= nil then return byName[myRosterName] end
	local idx = Lookup(byName, ns.FullName())
	if idx ~= nil then return idx end
	return Lookup(byName, UnitName("player"))
end

function Ranks:IsGuildMaster(fullName)
	return Lookup(byName, fullName) == 0
end

function Ranks:AmGuildMaster()
	if ns.DEV then return true end
	if C_GuildInfo and C_GuildInfo.IsGuildLeader then
		local ok, v = pcall(C_GuildInfo.IsGuildLeader)
		if ok and v ~= nil then return v and true or false end
	end
	if IsGuildLeader then
		local ok, v = pcall(IsGuildLeader)
		if ok then return v and true or false end
	end
	return self:MyIndex() == 0
end

function Ranks:AmGuildMasterReally()
	if C_GuildInfo and C_GuildInfo.IsGuildLeader then
		local ok, v = pcall(C_GuildInfo.IsGuildLeader)
		if ok and v ~= nil then return v and true or false end
	end
	if IsGuildLeader then
		local ok, v = pcall(IsGuildLeader)
		if ok then return v and true or false end
	end
	return self:MyIndex() == 0
end

function Ranks:Can(capKey)
	if ns.DEV then return true end
	if self:AmGuildMaster() then return true end
	local mine = self:MyIndex()
	if not mine then return false end
	local matrix = DeadByDawnDB.caps
	if matrix and matrix[mine] and matrix[mine][capKey] ~= nil then
		return matrix[mine][capKey] and true or false
	end
	local threshold = ns.DEFAULT_CAPS_BY_RANK[capKey]
	if threshold == nil then return false end
	return mine <= threshold
end

function Ranks:SelfPermissions()
	return {
		guildMaster = self:AmGuildMaster(),
		officerNote = CanEditOfficerNote and CanEditOfficerNote() or false,
		invite = CanGuildInvite and CanGuildInvite() or false,
		promote = CanGuildPromote and CanGuildPromote() or false,
		remove = CanGuildRemove and CanGuildRemove() or false,
		guildInfo = CanEditGuildInfo and CanEditGuildInfo() or false,
	}
end

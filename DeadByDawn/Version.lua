local ADDON, ns = ...

local function Metadata(field)
	if C_AddOns and C_AddOns.GetAddOnMetadata then
		local ok, v = pcall(C_AddOns.GetAddOnMetadata, ADDON, field)
		if ok and v then return v end
	end
	if _G.GetAddOnMetadata then
		local ok, v = pcall(_G.GetAddOnMetadata, ADDON, field)
		if ok and v then return v end
	end
	return nil
end

ns.VERSION = Metadata("Version") or "0.0.0"

ns.STAGE = Metadata("X-Stage")

function ns.VersionLabel()
	if ns.STAGE and ns.STAGE ~= "" then
		return ns.VERSION .. " " .. ns.STAGE
	end
	return ns.VERSION
end

local knownNewer = nil
local notified = false

function ns.CompareVersions(v1, v2)
	local a1, b1, c1 = tostring(v1 or ""):match("^(%d+)%.(%d+)%.?(%d*)")
	local a2, b2, c2 = tostring(v2 or ""):match("^(%d+)%.(%d+)%.?(%d*)")
	if not a1 or not a2 then return 0 end
	if c1 == "" then c1 = "0" end
	if c2 == "" then c2 = "0" end
	a1, b1, c1 = tonumber(a1), tonumber(b1), tonumber(c1)
	a2, b2, c2 = tonumber(a2), tonumber(b2), tonumber(c2)
	if a1 ~= a2 then return a1 - a2 end
	if b1 ~= b2 then return b1 - b2 end
	return c1 - c2
end

function ns.NoteRemoteVersion(remote)
	if not remote or remote == "" then return end
	if ns.CompareVersions(remote, ns.VERSION) <= 0 then return end
	if not knownNewer or ns.CompareVersions(remote, knownNewer) > 0 then
		knownNewer = remote
	end
	if notified then return end
	notified = true
	ns.Print("|cffffd100a newer version (%s) is available - you are on %s.|r", remote, ns.VersionLabel())
	if ns.UPDATE_URL then
		ns.Print("get it at %s", ns.UPDATE_URL)
	end
end

function ns.KnownNewerVersion()
	return knownNewer
end

function ns.Stamp(payload)
	return ns.VERSION .. "#" .. payload
end

function ns.Unstamp(text)
	local ver, payload = tostring(text or ""):match("^([%d%.]*)#(.*)$")
	if ver then return payload, ver end
	return text, nil
end

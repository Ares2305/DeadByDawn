local ADDON, ns = ...

local S = {}
ns.Style = S

local WHITE = "Interface\\Buttons\\WHITE8X8"
local HIGHLIGHT = "Interface\\QuestFrame\\UI-QuestLogTitleHighlight"

S.BLOOD   = { 0.55, 0.05, 0.05 }
S.EMBER   = { 0.85, 0.35, 0.10 }
S.BONE    = { 0.90, 0.86, 0.78 }
S.ASH     = { 0.45, 0.43, 0.40 }
S.ROT     = { 0.35, 0.45, 0.25 }

S.HEX_BONE  = "|cffe6dcc6"
S.HEX_BLOOD = "|cffc01818"
S.HEX_EMBER = "|cffd96a1a"
S.HEX_ASH   = "|cff736e66"
S.HEX_ROT   = "|cff8fae5c"
S.R = "|r"

function S.Solid(parent, layer, r, g, b, a)
	local t = parent:CreateTexture(nil, layer or "BACKGROUND")
	t:SetTexture(WHITE)
	t:SetVertexColor(r, g, b, a or 1)
	return t
end

function S.AccentBar(parent, height)
	local t = S.Solid(parent, "ARTWORK", S.BLOOD[1], S.BLOOD[2], S.BLOOD[3], 0.9)
	t:SetHeight(height or 2)
	return t
end

function S.Divider(parent, y, pad)
	local t = S.Solid(parent, "ARTWORK", S.ASH[1], S.ASH[2], S.ASH[3], 0.35)
	t:SetHeight(1)
	t:SetPoint("TOPLEFT", pad, y)
	t:SetPoint("TOPRIGHT", -pad, y)
	return t
end

function S.Stripe(row, index)
	local t = S.Solid(row, "BACKGROUND", 1, 1, 1, 1)
	t:SetAllPoints(row)
	if index % 2 == 0 then
		t:SetVertexColor(1, 1, 1, 0.025)
	else
		t:SetVertexColor(0, 0, 0, 0.18)
	end
	return t
end

function S.Hover(row)
	local t = row:CreateTexture(nil, "HIGHLIGHT")
	t:SetTexture(HIGHLIGHT)
	t:SetBlendMode("ADD")
	t:SetAllPoints(row)
	t:SetAlpha(0.45)
	return t
end

function S.Backdrop(frame)
	local t = S.Solid(frame, "BACKGROUND", 0.04, 0.03, 0.03, 0.92)
	t:SetPoint("TOPLEFT", 4, -22)
	t:SetPoint("BOTTOMRIGHT", -4, 4)
	return t
end

local FALLBACK = { r = 0.9, g = 0.86, b = 0.78 }

function S.ClassColor(classFile)
	if not classFile then return FALLBACK end
	local t = (CUSTOM_CLASS_COLORS and CUSTOM_CLASS_COLORS[classFile])
		or (RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile])
	return t or FALLBACK
end

function S.ClassHex(classFile)
	local c = S.ClassColor(classFile)
	if c.colorStr then return "|c" .. c.colorStr end
	return ("|cff%02x%02x%02x"):format(c.r * 255, c.g * 255, c.b * 255)
end

function S.Name(fullName)
	local short = (fullName or ""):match("^([^-]+)") or fullName or "?"
	local class = ns.Ranks and ns.Ranks.ClassOf and ns.Ranks:ClassOf(fullName)
	if not class then return short end
	return S.ClassHex(class) .. short .. S.R
end

function S.Header(parent, text, x, y)
	local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	fs:SetPoint("TOPLEFT", x, y)
	fs:SetText(S.HEX_EMBER .. text:upper() .. S.R)
	return fs
end

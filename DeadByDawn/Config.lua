local ADDON, ns = ...

ns.GUILD = "Evil Dead"

ns.DEV = false

ns.PREFIX = "DeadByDawn"

ns.DEFAULT_HELP_KEYWORD = "+"

ns.CHAT_TAG = "|cffe6c35c[Dead by Dawn]|r"
ns.CHAT_MARK = "[Dead by Dawn]"

ns.UPDATE_URL = "https://github.com/Ares2305/DeadByDawn"

function ns.Log() end
function ns.LogOnce() end
function ns.Dump(v) return v end

ns.CAPS = {
	{ key = "createEvent",  short = "Create",   label = "Create events" },
	{ key = "editAnyEvent", short = "Edit any", label = "Edit or delete any event" },
	{ key = "announce",     short = "Announce", label = "Post guild announcements" },
	{ key = "viewHistory",  short = "History",  label = "View attendance history" },
	{ key = "settings",     short = "Settings", label = "Change addon settings" },
}

ns.DEFAULT_CAPS_BY_RANK = { createEvent = 2, editAnyEvent = 1, announce = 1,
	viewHistory = 3, settings = 0 }

# Dead by Dawn

A guild addon for World of Warcraft: Forever, built for the guild **Evil Dead Forever**.

It lives on your guild window rather than behind a slash command. Open the guild
or communities panel and there is a *Dead by Dawn* button; the addon slides out
alongside it with four tabs down the side.

**Guild Info** lists the upcoming guild calendar events with their day, time and
type, and opens the calendar to schedule one. When somebody schedules a new
guild event you get a raid-warning sound, and the person who created it posts it
to guild chat automatically.

**Quest Help** is the part that saves typing. Pick a quest out of your log — or
just "grouping up" — and it goes on a board every guildmate with the addon can
see, with the quest link, your zone and an optional note. It also announces once
in guild chat: *"Thalric needs a hand with [Deadmines] — type + for an invite."*
Anyone who types that keyword in guild chat gets invited automatically, and
anyone looking at the board can hit **Invite me** instead and be pulled in
without either of you typing a word. Requests clear themselves after 30 minutes,
on logout, or when you withdraw them.

**Ranks** is a permission grid: five capabilities — create events, edit or delete
any event, post announcements, view attendance history, change settings — ticked
per guild rank. Only the guild master can change it, and everyone else sees it
read-only. Sensible defaults apply until they do.

**Who has the addon** shows which guild members are running it and on which
version, so you can see who is out of date. The addon heartbeats its version
over the guild channel and tells you when it spots a newer one than yours.

It stays out of the way of other guilds. It is pointed at Evil Dead Forever and
goes dormant anywhere else, saying so once at login.

## Installing

Drop the `DeadByDawn` folder into `World of Warcraft\_forever_\Interface\AddOns\`
and restart the client. No dependencies, no slash commands, nothing to configure
to get started.

## Status

**1.0.1 prototype.** Requires interface 16001 (Forever, game version 1.60.1).

The version that travels over the guild channel is always the plain number —
`Version.lua` stamps every Quest Help message with it and parses it back out, so
the prototype label is carried separately in the `X-Stage` field of the `.toc`
and only ever shown on screen.

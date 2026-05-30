--[[
    Imported from luadch/scripts (etc_hubportier_0.1 (german)) on 2026-05-05.
    Audited for Lua 5.4 by Aybo. License: GPLv3.
    See https://github.com/luadch-ng/scripts/blob/master/docs/IMPORT_NOTES.md
    for the import-pass triage.

    Normalised on import: filename "etc_hubportier_v0.1.lua" -> "etc_hubportier.lua"
    (drops version from filename to match scriptname).
]]--

--[[

    etc_hubportier by pulsar

        v0.2:
            - i18n: route the per-level broadcast/welcome strings
              through lang (msg_login, msg_logout, msg_user_welcome).
              The previous N copies of identical text per level table
              are folded into a single key + a per-level enabled-flag
              table; per-level silencing is preserved.
              Part of luadch-ng/scripts #31 PR-3.

        v0.1:
            - Das Script sendet eine Willkommens-/Abschiedsnachricht an die User

]]--



--[SETTINGS]

local scriptname = "etc_hubportier"
local scriptversion = "0.2"

local scriptlang = cfg.get( "language" )
local lang, err = cfg.loadlanguage( scriptlang, scriptname ); lang = lang or {}; err = err and hub.debug( err )

-- Per-level toggle: which levels get a portier message?
local PortierActive = {
    [ 0 ]   = true,
    [ 10 ]  = true,
    [ 20 ]  = true,
    [ 30 ]  = true,
    [ 40 ]  = true,
    [ 60 ]  = true,
    [ 80 ]  = true,
    [ 100 ] = true,
}

local msg_login        = lang.msg_login        or "is back..."
local msg_logout       = lang.msg_logout       or "is leaving..."
local msg_user_welcome = lang.msg_user_welcome or "nice to have you back..."


--[CODE]

local seperator = "  "
hub.setlistener("onLogin", {},
    function(user)
        local level = user:level()
        if not PortierActive[level] then return nil end
        local nick = user:nick()
        local levelname = cfg.get("levels")[level] or "Unreg"
        hub.broadcast(levelname..seperator..nick..seperator..msg_login, hub.getbot())
        user:reply(levelname..seperator..nick..seperator..msg_user_welcome, hub.getbot())
    end
)

hub.setlistener("onLogout", {},
    function(user)
        local level = user:level()
        if not PortierActive[level] then return nil end
        local nick = user:nick()
        local levelname = cfg.get("levels")[level] or "Unreg"
        hub.broadcast(levelname..seperator..nick..seperator..msg_logout, hub.getbot())
    end
)

hub.debug("** Loaded "..scriptname.." "..scriptversion.." **")

--[END]

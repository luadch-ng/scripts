--[[
    Imported from luadch/scripts (etc_levelcheck_v0.1 (english)) on 2026-05-05.
    Audited for Lua 5.4 by Aybo. License: GPLv3.
    See https://github.com/luadch-ng/scripts/blob/master/docs/IMPORT_NOTES.md
    for the import-pass triage.
]]--

--[[

    etc_levelcheck.lua by pulsar

        requested by: Sopor

        v0.2:
            - i18n: route the kick reason + ops report through lang.
              Part of #31 PR-2.

        v0.1:
            - Fix issue #27: https://github.com/luadch/scripts/issues/27

]]--


--------------
--[SETTINGS]--
--------------

local scriptname = "etc_levelcheck"
local scriptversion = "0.2"

local scriptlang = cfg.get( "language" )
local lang, err = cfg.loadlanguage( scriptlang, scriptname ); lang = lang or {}; err = err and hub.debug( err )

local permission = {  -- who is allowed to join the hub?

    [ 0 ] = false,  -- unreg
    [ 10 ] = false,  -- guest
    [ 20 ] = false,  -- reg
    [ 30 ] = false,  -- vip
    [ 40 ] = false,  -- svip
    [ 50 ] = false,  -- server
    [ 55 ] = false,  -- sbot
    [ 60 ] = true,  -- operator
    [ 70 ] = true,  -- supervisor
    [ 80 ] = true,  -- admin
    [ 100 ] = true,  -- hubowner
}

--// imports
local report = hub.import( "etc_report" )

--// report feature
local report_activate = true -- send report?
local report_level = 60 -- report minlevel (only for hubbot message)
local report_hubbot = true -- send report to hubbot?
local report_opchat = false -- send report to opchat?

--// msgs
local msg_disconnect = lang.msg_disconnect or "You are temporary not allowed to join the hub because: Your reason"
local msg_report     = lang.msg_report     or "[ Levelcheck ]-> The following user was disconnected: "
local msg_unknown    = lang.msg_unknown    or "unknown"


----------
--[CODE]--
----------

hub.setlistener( "onConnect", {},
    function( user )
        if not permission[ user:level() ] then
            local user_nick = user:nick() or msg_unknown
            user:kill( "ISTA 230 " .. hub.escapeto( msg_disconnect ) .. "\n", "TL30" )
            report.send( report_activate, report_hubbot, report_opchat, report_level, msg_report .. user_nick )
            return PROCESSED
        end
        return nil
    end
)

hub.debug( "** Loaded " .. scriptname .. " " .. scriptversion .. " **" )
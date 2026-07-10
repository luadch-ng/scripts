--[[
    Imported from luadch/scripts (cmd_mainclear_v0.02 (german)) on 2026-05-05.
    Audited for Lua 5.4 by Aybo. License: GPLv3.
    See https://github.com/luadch-ng/scripts/blob/master/docs/IMPORT_NOTES.md
    for the import-pass triage.
]]--

--[[
        "cmd_mainclear.lua" v0.03 by Motnahp

        v0.03:
            - i18n: route user-facing strings through lang (msg_denied,
              msg_done_by, help_*, ucmd_menu). Fix typo `msg_denid` -> `msg_denied`.
              Part of luadch-ng/scripts #31 PR-2.

        v0.02:
            - Anzahl der zeilen können nun eingestellt werden.
            - sends a few empty lines to mainchat and seems to clear it

]]--


--[Settings}

local scriptname = "cmd_mainclear"
local scriptversion = "0.03"
local min_level = 60

local scriptlang = cfg.get( "language" )
local lang, err = cfg.loadlanguage( scriptlang, scriptname ); lang = lang or {}; err = err and hub.debug( err )

local help_title = lang.help_title or "Clear"
local help_usage = lang.help_usage or "[+!#]clear"
local help_desc  = lang.help_desc  or "sends a few empty lines to mainchat and seems to clear it"

local msg_denied  = lang.msg_denied  or "You are not allowed to use this command."
local msg_done_by = lang.msg_done_by or "\t Mainclean done by "

local ucmd_menu = lang.ucmd_menu or { "OP-Menu", "Clear main" }

local cmd = "clear"
local hubcmd
local emptylines = 7500
local hub_bot = hub.getbot()

local msg = string.rep("\n",emptylines)


--[Code]

local onbmsg = function( user)
    if user:level() < min_level then
        user:reply(msg_denied, hub_bot)
    else
        msg = msg .. msg_done_by .. user:nick()
        hub.broadcast(msg, hub_bot)
    end
    return PROCESSED
end

hub.setlistener( "onStart", { },
    function( )
        local help = hub.import "cmd_help"
        if help then
            help.reg( help_title, help_usage, help_desc, min_level )    -- reg help
        end
        local ucmd = hub.import "etc_usercommands"    -- add usercommand
        if ucmd then
            ucmd.add( ucmd_menu, cmd, { }, { "CT1" }, min_level )
        end
        hubcmd = hub.import "etc_hubcommands"    -- add hubcommand
        assert( hubcmd )
        assert( hubcmd.add( cmd, onbmsg, min_level ) )
        return nil
    end
)
hub.debug("** Loaded "..scriptname.." "..scriptversion.." **")

--[END]

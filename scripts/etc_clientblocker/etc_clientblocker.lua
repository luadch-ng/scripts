--[[
    Imported from luadch/scripts (etc_clientblocker_v0.1 (english)) on 2026-05-05.
    Audited for Lua 5.4 by Aybo. License: GPLv3.
    See https://github.com/luadch-ng/scripts/blob/master/docs/IMPORT_NOTES.md
    for the import-pass triage.
]]--

--[[

	etc_clientblocker.lua by pulsar

        v0.2:
            - i18n: route the default block-reason through lang
              (msg_client_not_allowed) + fix typo "ist not allowed"
              -> "is not allowed". Per-rule operator override via the
              client_tbl values still works. Part of #31 PR-2.

        v0.1:
            - blocks clients
        
]]--


--------------
--[SETTINGS]--
--------------

local scriptname = "etc_clientblocker"
local scriptversion = "0.2"

local scriptlang = cfg.get( "language" )
local lang, err = cfg.loadlanguage( scriptlang, scriptname ); lang = lang or {}; err = err and hub.debug( err )

local msg_client_not_allowed = lang.msg_client_not_allowed or "Your client is not allowed"

local check_level = {

		[ 0 ] = true,  --> UNREG
		[ 10 ] = true,  --> GUEST
		[ 20 ] = true,  --> REG
		[ 30 ] = true,  --> VIP
		[ 40 ] = true,  --> SVIP
		[ 50 ] = true,  --> SERVER
		[ 60 ] = false,  --> OPERATOR
		[ 70 ] = false,  --> SUPERVISOR
		[ 80 ] = false,  --> ADMIN
		[ 100 ] = true,  --> HUBOWNER

}

local client_tbl = {

    [ "0.7" ] = msg_client_not_allowed,           -- searching for all clients that includes "0.7" (all dc++ 0.7xx clients)
    [ "0.8" ] = msg_client_not_allowed,           -- searching for all clients that includes "0.8" (all dc++ 0.8xx clients)
    [ "AirDC%+%+%s2" ] = msg_client_not_allowed,  -- searching for all AirDC++ 2.xx
    [ "AirDC%+%+%s2.9" ] = msg_client_not_allowed,-- searching for all AirDC++ 2.9x
    [ "AirDC%+%+%s3" ] = msg_client_not_allowed,  -- searching for all AirDC++ 3.xx
    [ "AirDC%+%+%s3.0" ] = msg_client_not_allowed,-- searching for all AirDC++ 3.0x
}


----------------------------
--[DEFINITION/DECLARATION]--
----------------------------

--// table lookups
local hub_escapefrom = hub.escapefrom
local hub_escapeto = hub.escapeto
local hub_debug = hub.debug


----------
--[CODE]--
----------

local check_clients = function( user )
    local user_level = user:level()
    if check_level[ user_level ] then
        -- Phase 8a F-INF-1d (luadch-ng/luadch#121): user:version() is
        -- nil for clients that did not send VE in BINF. Pre-fix,
        -- hub_escapefrom(nil) (and the subsequent :find on the result)
        -- could crash depending on the C binding. A client with no VE
        -- has no version string to match against the blocklist, so
        -- skip the check entirely - mirrors the "no rule applies"
        -- semantic for any other missing input.
        local version = user:version()
        if not version then return end
        local user_client = hub_escapefrom( version )
        for k, v in pairs( client_tbl ) do
            if user_client:find( k ) then
                user:kill( "ISTA 231 " .. hub_escapeto( v ) .. " TL-1 \n" )
                return PROCESSED
            end
        end
    end
end

hub.setlistener( "onConnect", {}, check_clients )

hub_debug( "** Loaded " .. scriptname .. " " .. scriptversion .. " **" )
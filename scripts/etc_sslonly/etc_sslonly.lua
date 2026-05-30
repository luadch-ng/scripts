--[[
    Imported from luadch/scripts (etc_sslonly_v0.2 (german)) on 2026-05-05.
    Audited for Lua 5.4 by Aybo. License: GPLv3.
    See https://github.com/luadch-ng/scripts/blob/master/docs/IMPORT_NOTES.md
    for the import-pass triage.

    Normalised on import: filename "etc_sslonly_0.2.lua" -> "etc_sslonly.lua"
    (drops version from filename to match scriptname).
]]--

--[[

    etc_sslonly by pulsar

        Version: Luadch_0.08

            v0.3
                - i18n: route usermsg / teammsg / mainmsg through lang.
                  Part of luadch-ng/scripts #31 PR-2.

            v0.2
                - geändert: Listener

            v0.1
                - SSL/TLS Checker, um zu gewährleisten das User mit deaktivierter SSL/TLS-Funktion disconnected werden.

]]--



--------------
--[SETTINGS]--
--------------

--> Scriptname
local scriptname = "etc_sslonly"
local scriptversion = "0.3"

local scriptlang = cfg.get( "language" )
local lang, err = cfg.loadlanguage( scriptlang, scriptname ); lang = lang or {}; err = err and hub.debug( err )

--> Warnmeldung an User mit deaktivierter SSL/TLS-Funktion
local usermsg = lang.usermsg or [[

                                                          +++  WARNING - PLEASE READ +++

        The SSL/TLS feature of your client is disabled or the certificate cannot be loaded. Open your client
        settings ("Security certificates" menu), check the path to the private key + certificate, check the
        certificate exists, enable all TLS feature checkboxes. If it still does not work, generate a new
        certificate via the "Security certificates" menu.

    ]]

--> Soll Das Hubteam über den geblockten User als PM vom Hubbot informiert werden? (true=JA/false=NEIN)
local informteam = true

--> Hubteam Minlevel
local teamlevel = 60

--> Nachricht an das Hubteam
local teammsg = lang.teammsg or "Warning: the following user was disconnected because their SSL/TLS feature is disabled:  "

--> Sollen alle anderen User über den geblockten User im Main informiert werden? (true=JA/false=NEIN)
local informall = true

--> Nachricht an die User
local mainmsg = lang.mainmsg or "Warning: the following user was disconnected because their SSL/TLS feature is disabled:  "


----------
--[CODE]--
----------

local checkSSL = function(user, adccmd)
    local ssl1 = user:hasfeature("ADCS")
    local ssl2 = user:hasfeature("ADC0")
    local user_nick = user:nick()
    local hub_getusers = hub.getusers()
    local hub_getbot = hub.getbot()
    local hub_broadcast = hub.broadcast
    if not (ssl1 or ssl2) then
        user:reply(usermsg, hub_getbot)
        user:kill("sorry")
        if informteam then
            for sid, user in pairs(hub_getusers) do
                local opuser = user:level()
                if opuser >= teamlevel then
                    user:reply(teammsg..user_nick, hub_getbot, hub_getbot)
                end
            end
        end
        if informall then
            hub_broadcast(mainmsg..user_nick, hub_getbot)
        end
        return PROCESSED
    end
    return nil
end

hub.setlistener("onInf", {}, checkSSL)
--hub.setlistener("onLogin", {}, checkSSL) --> optional
--hub.setlistener("onSearch", {}, checkSSL) --> optional

hub.debug("** Loaded "..scriptname.." "..scriptversion.." **")

---------
--[END]--
---------

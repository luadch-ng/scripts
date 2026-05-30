--[[
    Imported from luadch/scripts (etc_openhubs_announcer_v0.2 (german)) on 2026-05-05.
    Audited for Lua 5.4 by Aybo. License: GPLv3.
    See https://github.com/luadch-ng/scripts/blob/master/docs/IMPORT_NOTES.md
    for the import-pass triage.

    Lua 5.4 fixes (this fork):
    - scriptname normalised "etc_openhubs_announcer_v0.2" -> "etc_openhubs_announcer".
    - 1-arg os.difftime( os.time() - start ) replaced with direct
      arithmetic (os.time() - start).
]]--

--[[

        etc_openhubs_announcer.lua by Motnahp

        v0.3:
            - i18n: route warn + op-report msgs through lang
              (badmsg, op_report). Part of luadch-ng/scripts #31 PR-2.

        v0.2:
            - Script übersichtlicher + Editierbare teile eingefügt

        v0.1:
            - Prüft die User kurz nach dem Login auf öffentliche Hubs

]]--

--[[ Settings ]]--

-- Nicht Editieren --
local scriptname = "etc_openhubs_announcer"
local scriptversion = "0.3"
local hub_bot = hub.getbot()
local min = 60
local start = os.time()

local scriptlang = cfg.get( "language" )
local lang, err = cfg.loadlanguage( scriptlang, scriptname ); lang = lang or {}; err = err and hub.debug( err )

--funtions
local reportItTo
local check
-->> nachfolgende Settings sind editierbar -->>
local recheck = true       -- sollen im Abstand von recheckdelay alle User geprüft werden?
local maxchecklvl = 50     -- maximale Level bis zu dem geprüft werden soll (einschliesslich)
local reportlvl = 60       -- minimale Level zu dem gemeldet werden soll (einschliesslich)
local warnUser = false     -- soll der User benachrichtigt/verwarnt werden?
local sendMain = true      -- soll im Mainchat an die OPs gemeldet werden?
local sendPM = true        -- soll per PM an die OPs gemeldet werden?
local recheckdelay = 3     --> Zeitverzögerung des Checks (in Minuten)

-- Nachricht an den User
local badmsg = lang.badmsg or [[

        According to your tag you are connected to a public hub.
        These are not tolerated on this hub. A misconduct notice
        has been sent to the OPs.

        ]]
-- op_report template: utf.format(op_report, nick, level)
local op_report = lang.op_report or "[[OPENHUBS]]--> The following user was identified as a user of a public hub: %s with profile [%s]"

--<< ende des editierbaren Teils --<<

recheckdelay = recheckdelay * min

--[[   Code   ]]--

hub.setlistener("onTimer", {},
    function()
        if recheck and ((os.time() - start) >= recheckdelay) then
            for sid, user in pairs(hub.getusers()) do
                check(user)
            end
            start = os.time( )
        end
        return nil
    end
)

function check(user)
    local hn, hr, ho = user:hubs()
    -- Phase 8a F-INF-1d (luadch-ng/luadch#121): hn is nil when the
    -- client did not send HN in BINF.
    local user_nick = user:nick()
    local user_level = user:level()
    local level = cfg.get("levels")[user_level] or "Unreg"

    if user_level <= maxchecklvl then
        if hn == nil or hn > 0 then
            if warnUser then
                user:reply(badmsg, hub.getbot(), hub.getbot())
            end
            local msg = utf.format(op_report, user_nick, level)
            reportItTo(reportlvl, msg)
        end
    end
end

function reportItTo(lvl, msg)
    for sid, user in pairs(hub.getusers()) do
        local targetuser = user:level()
        if targetuser >= lvl then
            if sendPM then
                user:reply(msg, hub_bot, hub_bot)
            end
            if sendMain then
                user:reply(msg, hub_bot)
            end
        end
    end
end

hub.debug( "** Loaded " .. scriptname .. " " .. scriptversion .. " **" )

--[[   End    ]]--

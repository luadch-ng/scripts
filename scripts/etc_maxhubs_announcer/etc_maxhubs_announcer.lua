--[[
    Imported from luadch/scripts (etc_maxhubs_announcer_v0.2 (german)) on 2026-05-05.
    Audited for Lua 5.4 by Aybo. License: GPLv3.
    See https://github.com/luadch-ng/scripts/blob/master/docs/IMPORT_NOTES.md
    for the import-pass triage.

    Lua 5.4 fixes (this fork):
    - scriptname normalised "etc_maxhubs_announcer_v0.2" -> "etc_maxhubs_announcer"
      (drops version from identifier, like wunschbrett did in #1).
    - 1-arg os.difftime( os.time() - start ) replaced with direct
      arithmetic (os.time() - start). Lua 5.4 strict-checks os.difftime
      arity; the upstream pattern errored at runtime.
]]--

--[[

       etc_maxhubs_announcer.lua by Motnahp

       v0.3:
            - i18n: route user warn + op report through lang
              (badmsg, op_report). The previous opmsg1/opmsg2/opmsg3
              token-paste is folded into a single utf.format template.
              Part of luadch-ng/scripts #31 PR-2.

       v0.2:
            - Script übersichtlicher + editierbare Teile eingefügt
            - Prüft die User nur noch nach einem bestimmten Zeitabstand und nicht mehr beim login

       v0.1:
            - Prüft die User kurz nach dem Login auf die maximale Anzahl auf Hubs

]]--

--[[ Settings ]]--

-- nicht Editieren --
local scriptname = "etc_maxhubs_announcer"
local scriptversion = "0.3"
local hub_bot = hub.getbot()
local min = 60
local start = os.time()

local scriptlang = cfg.get( "language" )
local lang, err = cfg.loadlanguage( scriptlang, scriptname ); lang = lang or {}; err = err and hub.debug( err )

--functions
local check
local reportItTo
-->> nachfolgende Settings sind editierbar -->>
local recheck = true       -- sollen im abstand von recheckdelay alle User geprüft werden?
local maxHubs = 11         -- wie viele Hubs sind erlaubt? (einschliesslich)
local maxchecklvl = 50     -- maximale Level bis zu dem geprüft werden soll (einschliesslich)
local reportlvl = 60       -- minimale Level zu dem gemeldet werden soll (einschliesslich)
local warnUser = false     -- soll der User benachrichtigt/verwarnt werden?
local sendMain = true      -- soll im Mainchat an die OPs gemeldet werden?
local sendPM = true        -- soll per PM an die OPs gemeldet werden?
local recheckdelay = 2     --> Zeitverzögerung des Checks (in Minuten)

-- Nachricht an den User (%s = maxHubs limit)
local badmsg = lang.badmsg or [[

        You are connected to more hubs than allowed, please check the rules.
        At the moment only %s hubs are allowed.
        A misconduct notice has been sent to the OPs.

        ]]

-- op_report template: utf.format(op_report, nick, level, hubs)
local op_report = lang.op_report or "[[MAXHUBS]]--> %s with profile [%s] was found connected to %s hubs"

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
    -- Phase 8a F-INF-1d (luadch-ng/luadch#121): a client BINF without
    -- the HN/HR/HO triplet returns nil from user:hubs(). Coerce each
    -- component to 0 so a partial / missing triplet is treated as 0.
    local hubs = ( hn or 0 ) + ( hr or 0 ) + ( ho or 0 )
    local user_nick = user:nick()
    local user_level = user:level()
    local level = cfg.get("levels")[user_level] or "Unreg"

    if user_level <= maxchecklvl then
        if (hubs > maxHubs) then
            if warnUser then
                user:reply(utf.format(badmsg, maxHubs), hub.getbot(), hub.getbot())
            end
            local msg = utf.format(op_report, user_nick, level, hubs)
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

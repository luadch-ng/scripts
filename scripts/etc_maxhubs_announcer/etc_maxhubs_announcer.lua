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
    
       etc_maxhubs_announcer.lua v0.2 by Motnahp
       
       - Script übersichtlicher + editierbare Teile eingefügt
       - Prüft die User nur noch nach einem bestimmten Zeitabstand und nicht mehr beim login
            >> recheckdelay editieren (2 Minuten voreingestellt)

            
       etc_maxhubs_announcer.lua v0.1 by Motnahp
       
       - Prüft die User kurz nach dem Login auf die maximale Anzahl auf Hubs

]]--

--[[ Settings ]]-- 

-- nicht Editieren --
local scriptname = "etc_maxhubs_announcer"
local hub_bot = hub.getbot()
local min = 60
local start = os.time()
--functions
local check
local reportItTo
-->> nachfolgende Settings sind editierbar -->>
local recheck = true -- sollen im abstand von recheckdelay alle User geprüft werden? (true = Ja / false = Nein)
local maxHubs = 11 -- wie viele Hubs sind erlaubt? ( einschliesslich)
local maxchecklvl = 50 -- maximale Level bis zu dem geprüft werden soll (einschliesslich)
local reportlvl = 60 -- minimale Level zu dem gemeldet werden soll (einschliesslich)
local warnUser = false -- soll der User benachrichtigt/verwarnt werden, dass er OpenHubs offen hat? (true = Ja / false = Nein)
local sendMain = true -- soll im Mainchat an die OPs gemeldet werden? (true = Ja / false = Nein)
local sendPM = true -- soll per PM an die OPs gemeldet werden? (true = Ja / false = Nein)
local recheckdelay = 2 --> Zeitverzögerung des Checks (in Minuten)

-- Nachricht an den User
local badmsg = [[

        Du bist in mehr Hubs als erlaubt, sieh im Regelwerk nach.
        Zur Zeit sind nur ]]..maxHubs..[[ Hubs erlaubt.
        Eine Nachricht über ein Fehlverhalten wurde an die OP's gesendet.
        
        Fall das nicht zutrifft melde dich bitte bei den OP's
        
        ]]
        
local opmsg1 = "[[MAXHUBS]]--> " -- erster Teil der OP Nachricht
local opmsg2 = " wurde mit " -- mittelteil der OP Nachricht
local opmsg3 = " Hubs entdeckt" -- ende der OP Nachricht
-- das Layout der Nachricht kann des weiteren in Zeile 84 verändert werden

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
    -- the HN/HR/HO triplet returns nil from user:hubs(). Pre-fix,
    -- the arithmetic on the next line crashed with "attempt to
    -- perform arithmetic on a nil value". Coerce each component to
    -- 0 so a partial / missing triplet is treated as zero hubs.
    local hubs = ( hn or 0 ) + ( hr or 0 ) + ( ho or 0 )
    local user_nick = user:nick()
    local user_level = user:level()
    local level = cfg.get("levels")[user_level] or "Unreg"
    local msg = ""

    if user_level <= maxchecklvl then
        if (hubs > maxHubs) then
            if warnUser then
                user:reply(badmsg, hub.getbot(), hub.getbot())
            end
            msg = msg..opmsg1..user_nick.." mit Profil ["..level.."]"..opmsg2..hubs..opmsg3 -- Zeile die für die OPs sichtbar ist
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

hub.debug( "** Loaded " .. scriptname .. ".lua **" )

--[[   End    ]]--      
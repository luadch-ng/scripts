--[[
    Imported from luadch/scripts (ptx_tophubbers_v0.1 (german)) on 2026-05-05.
    Audited for Lua 5.4 by Aybo. License: GPLv3.
    See https://github.com/luadch-ng/scripts/blob/master/docs/IMPORT_NOTES.md
    for the import-pass triage.

    Lua 5.4 fixes (this fork):
    - Removed module-level setmetatable( getfenv(1), nil ). getfenv is gone
      in Lua 5.4; the call would error at script load. The intent (clear any
      metatable on the script env) is moot in our empty-_ENV sandbox.
    - 1-arg os.difftime( os.time() - start ) replaced with direct
      arithmetic (os.time() - start).
]]--

--[[

    ptx_tophubbers (luadch-ng fork)

        v0.2:
            - i18n: route the user-facing chat / ucmd / stats strings
              through lang (msg_*, ucmd_*, fmt_duration). The rank names
              in tSettings.tRanks stay as operator config (whitespace-
              calibrated column padding); the on-screen rank legend in
              the !tophubbers output is also left as hardcoded German
              for the same column-layout reason. Both contain the
              upstream typo "Mittelgosser" (read: Mittelgrosser); the
              fix would shift column widths so it is deferred.
            - Bundled typo fix: the ucmd label "Zeige die Statisk eines
              Users" is corrected to "Zeige die Statistik eines Users"
              in lang.de (the label has no column-layout coupling).
              Part of luadch-ng/scripts #31 PR-4.

]]--

--[[

    luadch svn 230 port by blastbeat
        - fixed year bug in MinutesToTime


    TopHubbers 2.02 - LUA 5.0/5.1 by jiten
    ¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯
    Based on: OnHub Time Logger 1.65 by chill and Robocop's layout
    Übersetzt und angepasst für Leviathan Profile: Baba.runner
    Usage: !tophubbers; !tophubbers x-y; !hubtime <nick>; !myhubtime

    CHANGELOG:
    ¯¯¯¯¯¯¯¯¯¯
    Fixed: Typo in table.sort function;
    Added: OnExit (3/21/2006)
    Fixed: Missing pairs() in SaveToFile
    Changed: Removed iGlobalTime and added TotalTime count to OnTimer
    Changed: SecondsToTime function values (3/24/2006)
    Changed: math.floor/mod in TopHubbers' function; (3/5/2006)
    Changed: SecondsToTime month value (4/17/2006);
    Added: !hubtime <nick> - requested by speedX;
    Changed: SecondsToTime function and small code bits (8/16/2006)
    Changed: Table indexes;
    Changed: SecondsToTime function to MinutesToTime;
    Fixed: Inaccurate average uptime stuff (8/17/2006)
    Changed: Average uptime function;
    Changed: Session time for offline users doesn't get reset;
    Added: Average uptime warning on connect - requested by speedX (8/20/2006)
    Added: Customized profiles - requested by Naithif (8/20/2006)
    Added: User Commands - requested by TT;
    Added: Rankings and related commands [!myrank & !topranks] - requested by speedX;
    Added: Toggle rank info on connect - requested by TT;
    Fixed: !tophubbers x-y;
    Added: Comments to the code;
    Changed: Some code bits;
    Added: Toggle between total and average uptime (8/24/2006)
    Fixed: Minimum average uptime warning - reported by speedX;
    Added: Maximum shown hubbers - requested by Naithif (8/29/2006)
    Fixed: LUA 5.0/5.1 compatibility - reported by speedX (11/8/2006)
    Added: string.lower check - requested by SwapY and speedX (11/10/2006)

]]--

-- removed on import: setmetatable( getfenv( 1 ), nil ) -- getfenv() gone in
-- Lua 5.4; intent (clear metatable on script env) is moot in our empty-_ENV
-- sandbox.

local scriptname = "ptx_tophubbers"
local scriptversion = "0.2"

local scriptlang = cfg.get( "language" )
local lang, err = cfg.loadlanguage( scriptlang, scriptname ); lang = lang or {}; err = err and hub.debug( err )

local msg_no_perm        = lang.msg_no_perm        or "*** Fehler: Dir ist es nicht erlaubt diesen Befehl zu nutzen"
local msg_aut_warning    = lang.msg_aut_warning    or "*** Deine Durchschnitts-Online Zeit (DOT) ist kleiner als %d Stunde(n). Wir planen Einschränkungen einzuführen für User die die vorgeschriebene DOT nicht erreichen!"
local msg_top_empty      = lang.msg_top_empty      or "*** Fehler: Top Hubbers Tabelle ist zurzeit leer!"
local msg_hubtime_usage  = lang.msg_hubtime_usage  or "*** Eingabe Fehler: Versuch es wie folgt: !hubtime <nick>"
local msg_no_entry       = lang.msg_no_entry       or "*** Fehler: Keinen Eintrag gefunden für '%s'!"

local msg_top_header     = lang.msg_top_header     or "● Aktuelle Tophubbers  ●"
local msg_top_col_nr     = lang.msg_top_col_nr     or "Nr."
local msg_top_col_time   = lang.msg_top_col_time   or "Online Zeit:"
local msg_top_col_rank   = lang.msg_top_col_rank   or "Rang:"
local msg_top_col_status = lang.msg_top_col_status or "Status:"
local msg_top_col_nick   = lang.msg_top_col_nick   or "Nick:"
local msg_top_online     = lang.msg_top_online     or "*Online*"
local msg_top_offline    = lang.msg_top_offline    or "*Offline*"

local msg_stats_header   = lang.msg_stats_header   or "● Statistik von %s ●"
local msg_stats_nick     = lang.msg_stats_nick     or "Nick:"
local msg_stats_time     = lang.msg_stats_time     or "Onlinezeit:"
local msg_stats_avg      = lang.msg_stats_avg      or "Ø pro Tag:"
local msg_stats_rank     = lang.msg_stats_rank     or "Rang:"

local fmt_duration       = lang.fmt_duration       or "%i Jahr(e), %i Monat(e), %i Tag(e), %i Stunde(n), %i Minute(n)"

local ucmd_menu          = lang.ucmd_menu          or "Allgemein"
local ucmd_submenu       = lang.ucmd_submenu       or "Tophubbers"
local ucmd_show_top      = lang.ucmd_show_top      or "Zeige Top %d hubbers"
local ucmd_show_topxy    = lang.ucmd_show_topxy    or "Zeige Top x-y Hubbers"
local ucmd_input_topxy   = lang.ucmd_input_topxy   or "Zeige Rang x-y"
local ucmd_show_mytime   = lang.ucmd_show_mytime   or "Zeige deine Onlinezeit"
local ucmd_show_stats    = lang.ucmd_show_stats    or "Zeige die Statistik eines Users"
local ucmd_input_nick    = lang.ucmd_input_nick    or "Nick"
local ucmd_show_mystats  = lang.ucmd_show_mystats  or "Zeige meine Statistik"

tSettings = {
    -- Bot Name
    --sBot = frmHub:GetHubBotName(),
    sBot = hub.getbot( ), ----!

    -- Top Hubbers' DB
    fOnline = "scripts/tophubbers/tOnliners.tbl",

    -- RightClick Menu
    sMenu = "Top Hubbers",

    -- Maximum hubbers to show when using !tophubbers
    iMax = 100,

    -- Send message to users with lower than specified Average uptime (AUT) [true = on; false = off]
    bWarning = false,
    -- Minimum Average uptime (hours) that triggers the warning
    iAUT = 1,

    -- Send hubtime stats on connect [true = on; false = off]
    bRankOnConnect = false,

    -- Profiles checked [0 = off; 1 = on]
    tProfiles = { [0] = 0, [10] = 1, [20] = 1, [30] = 1, [40] = 1, [50] = 1, [60] = 1, [70] = 1, [80] = 1, [90] = 1, [100] = 1,},

    -- Ranks criteria ["average" = Average total uptime; "total" = Total uptime]
    sCriteria = "total",

    -- Ranks
    tRanks = { 
--[[        
        
        The ranks must be added in ascending order [from the lowest to the highest]

        { "Rank", [time][string] }

        [time] must be 1 or more digit(s)
        [string] must be: s = second; m = minute; h = hour; D = day; W = week; M = month; Y = year

        Example: { "God", "1M, 2D, 10s" } 
        Meaning: To become a God, your total uptime must be equal or higher than 1 month, 2 days and 10 seconds
]]--

        -- Total uptime rank table
		total = {
			{ "Kleine Sternschnuppe         ", "5D, 1h, 1m, 1s" }, { "Mittelgrosse Sternschnuppe", "10D" }, { "Grosse Sternschnuppe       ", "20D" }, 
			{ "Kleiner Meteorit                   ", "1M" }, { "Mittelgosser Meteorit           ", "2M" }, { "Grosser Meteorit                  ", "3M" }, 
			{ "Kleiner Asteroid                   ", "4M" }, { "Mittelgosser Asteroid           ", "5M" }, { "Grosser Asteroid                  ", "6M" }, 
			{ "Kleiner Mond                       ", "7M" }, { "Mittelgosser Mond               ", "8M" }, { "Grosser Mond                      ", "9M" }, 
			{ "Stern                                   ", "11M" }, { "Neutronenstern                    ", "2Y, 1h, 1m, 1s" }
		},

		-- Daily average uptime rank table
		average = { 
			{ "Kleine Sternschnuppe         ", "5D" }, { "Mittelgrosse Sternschnuppe", "10D" }, { "Grosse Sternschnuppe       ", "20D" }, 
			{ "Kleiner Meteorit                   ", "1M" }, { "Mittelgosser Meteorit           ", "2M" }, { "Grosser Meteorit                  ", "3M" }, 
			{ "Kleiner Asteroid                   ", "4M" }, { "Mittelgosser Asteroid           ", "5M" }, { "Grosser Asteroid                  ", "6M" }, 
			{ "Kleiner Mond                       ", "7M" }, { "Mittelgosser Mond               ", "8M" }, { "Grosser Mond                      ", "9M" }, 
			{ "Stern                                   ", "11M" }, { "Neutronenstern                    ", "2Y" }
		}
    }
}

tOnline = util.loadtable( tSettings.fOnline ) or { }

hub.setlistener( "onStart", { },
    function()
        -- Register BotName if not registered
        --if tSettings.sBot ~= frmHub:GetHubBotName() then frmHub:RegBot(tSettings.sBot) end ----!
        -- Load DB content
        --if loadfile(tSettings.fOnline) then dofile(tSettings.fOnline) end
        -- LUA 5.0/5.1 compatibility; Set and Start Timer
        string.gmatch = (string.gmatch or string.gfind)
        local ucmd = hub.import "etc_usercommands.lua"
        if ucmd then
            ucmd.add( { ucmd_menu, ucmd_submenu, utf.format( ucmd_show_top, tSettings.iMax ) }, "tophubbers", { }, { "CT1" }, 10 )
            ucmd.add( { ucmd_menu, ucmd_submenu, ucmd_show_mytime }, "myhubtime", { }, { "CT1" }, 10 )
        end
    end
)

local start = os.time()

hub.setlistener( "onTimer", { },
    function( )
        if (os.time() - start) >= 1 * 60 then
            for i, v in pairs(tOnline) do
            -- Online
                if hub.isnickonline(i) then
                    -- Sum
                    v.SessionTime = v.SessionTime + 1; v.TotalTime = v.TotalTime + 1
                end
            end
            start = os.time( )
        end
        return nil
    end
)

hub.setlistener( "onExit", { },
    function()
        -- Save
        util.savetable( tOnline, "tOnline", tSettings.fOnline )
        --local hFile = io.open(tSettings.fOnline, "w+") Serialize(tOnline, "tOnline", hFile); hFile:close()
    end
)

hub.setlistener( "onConnect", { },
    function(user)
        -- If profile has permission to be logged
        if tSettings.tProfiles[user:level()] and tSettings.tProfiles[user:level()] == 1 then
            --local tNick = GetOnliner(user.sName)
            local tNick = GetOnliner(user:nick()) ----!
            -- User already in DB
            if tNick then
                -- Warning on connect
                if tSettings.bWarning then
                    -- Days since first login
                    local iAverage = os.difftime(os.time(os.date("!*t")), tNick.Julian)/(60*60*24)
                    if iAverage < 1 then iAverage = 1 end
                    -- Less than allowed
                    if tNick.TotalTime/iAverage < tSettings.iAUT*60 then 
                        -- Warn
                        --user:SendPM(tSettings.sBot, "*** Deine Durchschnitts-Online Zeit (DOT) ist kleiner als "..tSettings.iAUT..
                        --" Stunde(n). Wir planen Einschränkungen einzuführen für User die die vorgeschriebene DOT nicht erreichen!")
                        user:reply(utf.format( msg_aut_warning, tSettings.iAUT ), tSettings.sBot) ----!
                    end
                end
                -- Reset and save time
                tNick.SessionTime = 0; tNick.Enter = os.date()
                -- Send rank info on connect
                if tSettings.bRankOnConnect then tCommands["myhubtime"].fFunction(user) end
            else
                -- Create new entry
                tOnline[user:nick()] = { Julian = os.time(os.date("!*t")), Enter = os.date(), SessionTime = 0, TotalTime = 0, Leave = os.date() }
            end
        end
        -- Supports UserCommands
        --if user.bUserCommand then
            -- For each entry in table
            for i, v in pairs(tCommands) do
                -- If member
                if v.tLevels[user:level()] then
                    -- For each type
                    --for n in ipairs(v.tRC) do
                        -- Send
                        --user:SendData("$UserCommand 1 3 "..tSettings.sMenu.."\\"..v.tRC[n][1]..
                        --"$<%[mynick]> !"..i..v.tRC[n][2].."&#124;")
                    --end
                end
            end
        --end
    end
)

hub.setlistener( "onLogout", { },
    function(user)
        local tNick = GetOnliner(user:nick())
        -- If profile must be logged and user is in DB
        if tSettings.tProfiles[user:level()] and tSettings.tProfiles[user:level()] == 1 and tNick then
            -- Log date
            tNick.Leave = os.date()
        end
    end
)

onbmsg = function(user, _, msg)
    -- Parse command
    local cmd = string.match( msg, "^[+!#](%a+) ?(.*)" )
    -- Exists
    if cmd and tCommands[string.lower(cmd)] then
        cmd = string.lower(cmd)
        -- PM
        local tmp = nil
        if to == tSettings.sBot then tmp = tSettings.sBot end
        -- If user has permission
        if tCommands[cmd].tLevels[user:level()] then
            return tCommands[cmd].fFunction(user, msg), 1
        else
            return user:reply(msg_no_perm, tSettings.sBot, tmp), 1
        end
    end
end

hub.setlistener( "onBroadcast", { }, onbmsg)
--hub.setlistener( "onPrivateMessage", { }, onbmsg )

tCommands = {
    tophubbers = {
        fFunction = function(user, data)
            -- Table isn't empty
            if next(tOnline) then
                -- Parse limits
                local _,_, iStart, iEnd = string.find(data, "^%S+%s+(%d+)%-(%d+)$")
                -- Set if not set
                iStart, iEnd = (iStart or 1), (iEnd or tSettings.iMax)
                -- Header
                local tCopy, msg = {}, "\r\n\t"..string.rep("_", 130).."\r\n\t"..msg_top_col_nr.."  "..msg_top_col_time.."\t\t\t\t\t\t"..
                "\t"..msg_top_col_rank.."\t\t\t\t"..msg_top_col_status.."\t\t"..msg_top_col_nick.."\r\n\t"..string.rep("¯", 130).."\r\n"
                -- Loop through hubbers
                for i, v in pairs(tOnline) do
                    -- Insert stats to temp table
                    table.insert(tCopy, { sEnter = v.Enter, iSessionTime = tonumber(v.SessionTime),
                    iTotalTime = tonumber(v.TotalTime), sLeave = v.Leave, sNick = i, sRank = GetRank(i) } )
                end
                -- Sort by total time
                table.sort(tCopy, function(a, b) return (a.iTotalTime > b.iTotalTime) end)
                -- Loop through temp table
                for i = iStart, iEnd, 1 do
                    -- i exists
                    if tCopy[i] then
                        -- Populate
                        local sStatus, v = msg_top_offline, tCopy[i]; local sRank = v.sRank
                        if hub.isnickonline(v.sNick) then sStatus = msg_top_online end
                        if string.len(v.sRank) < 9 then sRank = sRank.."\t" end
                        msg = msg.."\t"..i..".    "..MinutesToTime(v.iTotalTime).."\t\t"..sRank.."\t\t"..sStatus.."\t\t"..v.sNick.."\r\n"
                    end
                end
                msg = msg.."\t"..string.rep("-", 256).."\r\n"..
                "\tKleine Sternschnuppe\t Anfang\t"..
                "\tMittelgrosse Sternschnuppe\tab 10 Tagen"..
                "\tGrosse Sternschnuppe\tab 20 Tagen\r\n"..
                "\tKleiner Meteorit\t\tab 1 Monat"..
                "\tMittelgosser Meteorit\tab 2 Monate"..
                "\tGrosser Meteorit\t\tab 3 Monate\r\n"..
                "\tKleiner Asteroid\t\tab 4 Monate"..
                "\tMittelgosser Asteroid\tab 5 Monate"..
                "\tGrosser Asteroid\t\tab 6 Monate\r\n"..
                "\tKleiner Mond\t\tab 7 Monate"..
                "\tMittelgosser Mond\t\tab 8 Monate"..
                "\tGrosser Mond\t\tab 9 Monate\r\n"..
                "\tStern\t\t\tab 11 Monate"..
                "\tNeutronenstern\t\tab 2 Jahre\r\n"..
                "\t"..string.rep("-", 256).."\r\n"
                -- Send

                local logo = [[


                                                                                                                                  ]]..msg_top_header..[[

  ]]

                user:reply("\r\n"..logo..msg.."\r\n", tSettings.sBot, tSettings.sBot)
            else
                user:reply(msg_top_empty, tSettings.sBot)
            end
            return PROCESSED
        end,
        tLevels = {
            [0] = 0, [10] = 1, [20] = 1, [30] = 1, [40] = 1, [50] = 1, [60] = 1, [70] = 1, [80] = 0, [90] = 1, [100] = 1,
        },
        tRC = { { utf.format( ucmd_show_top, tSettings.iMax ), "" }, { ucmd_show_topxy, " %[line:"..ucmd_input_topxy.."]" } }
    },
    hubtime = {
        fFunction = function(user, data)
            -- Parse nick
            local _,_, nick = string.find(data, "^%S+%s+(%S+)$")
            -- Exists
            if nick then 
                -- Return
                BuildStats(user, nick)
            else
                user:reply(msg_hubtime_usage, tSettings.sBot)
            end
            return PROCESSED
        end,
        tLevels = { 
            [0] = 0, [10] = 1, [20] = 1, [30] = 1, [40] = 1, [50] = 1, [60] = 1, [70] = 1, [80] = 0, [90] = 1, [100] = 1,
        },
        tRC = { { ucmd_show_stats, " %[line:"..ucmd_input_nick.."]" } }
    },
    myhubtime = {
        fFunction = function(user)
            -- Return
            BuildStats(user, user:nick())
            return PROCESSED
        end,
        tLevels = { 
            [0] = 0, [10] = 1, [20] = 1, [30] = 1, [40] = 1, [50] = 1, [60] = 1, [70] = 1, [80] = 0, [90] = 1, [100] = 1,
        },
        tRC = { { ucmd_show_mystats, "" } }
    },
}

BuildStats = function(user, nick)
    local tNick = GetOnliner(nick)
    -- In DB
    if tNick then
        -- Average uptime in days
        local iAverage = os.difftime(os.time(os.date("!*t")), tNick.Julian)/(60*60*24)
        if iAverage < 1 then iAverage = 1 end
        -- Generate message
        --local sMsg = "\r\n\r\n\t\««« Statistik von "..nick.." »»»\r\n\t"..
        --"\r\n\tNick: "..nick.."\r\n\t- Gesamt Online-Zeit: "..
        --MinutesToTime(tNick.TotalTime, true).."\r\n\tTägliche Durchschnitts-Online-Zeit(DOT): "..
        --MinutesToTime((tNick.TotalTime/iAverage), true).."\r\n\tJetziger Rang: "..GetRank(nick).."\r\n"
        -- Send stats

        local logo2 = [[

		
  ]]
        local sMsg = "\r\n"..logo2.."\r\n\t\t\t"..utf.format( msg_stats_header, nick ).."\r\n\r\n\t"..
        "____________________________________________________________________ \r\n\r\n\t"..
        msg_stats_nick.."\t\t "..nick.." \r\n\t"..
        msg_stats_time.."\t "..MinutesToTime(tNick.TotalTime, true).." \r\n\t"..
        msg_stats_avg.."\t "..MinutesToTime((tNick.TotalTime/iAverage), true).." \r\n\t"..
        msg_stats_rank.."\t\t "..GetRank(nick).." \r\n\r\n\t"..
        "¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯ \r\n"

        user:reply(sMsg, tSettings.sBot, tSettings.sBot)
    else
        user:reply(utf.format( msg_no_entry, nick ), tSettings.sBot)
    end
end

GetRank = function(nick)
    local tNick = GetOnliner(nick)
    if tNick then
        -- Custom time table
        local tTime, sRank, iAverage = { s = 1/60, m = 1, h = 60, D = 60*24, W = 60*24*7, M = 60*24*30, Y = 60*24*30*12 }, tSettings.tRanks[string.lower(tSettings.sCriteria)][1][1]
        -- Average enabled
        if tSettings.bAverage then
            -- Days since first login
            iAverage = os.difftime(os.time(os.date("!*t")), tNick.Julian)/(60*60*24)
            if iAverage < 1 then iAverage = 1 end
        end
        -- For each rank
        for n in ipairs(tSettings.tRanks[string.lower(tSettings.sCriteria)]) do
            local iTime = 0
            -- For each digit and time string
            for i, v in string.gmatch(tSettings.tRanks[string.lower(tSettings.sCriteria)][n][2], "(%d+)(%w)") do
                -- Process
                if i and tTime[v] then iTime = iTime + i*tTime[v] end
            end
            local iValue = tNick.TotalTime
            -- Average
            if tSettings.bAverage then iValue = iValue/iAverage end
            -- Process rank if user hasn't logged in for the first time today
            if os.date("%d%m%y", tNick.Julian) ~= os.date("%d%m%y") and iValue > iTime then
                sRank = tSettings.tRanks[string.lower(tSettings.sCriteria)][n][1]
            end
        end
        return sRank
    end
end

MinutesToTime = function(iSeconds, bSmall)
    -- Build table with time fields
    local T = os.date("!*t", tonumber(iSeconds*60)); 
    -- Format to string
    local sTime = string.format(fmt_duration, (T.year-1970), T.month-1, T.day-1, T.hour, T.min)
    -- Small stat?
    if bSmall then
        -- For each digit
        for i in string.gmatch(sTime, "%d+") do
            -- Reduce if is preceeded by 0
            if tonumber(i) == 0 then sTime = string.gsub(sTime, "^"..i.."%s(%S+),%s", "") end
        end
    end
    -- Return
    return sTime
end


GetOnliner = function(user)
    -- For each hubber
    for i, v in pairs(tOnline) do
        -- Compare
        if string.lower(i) == string.lower(user) then
            -- Return
            return tOnline[i]
        end
    end
end

Serialize = function(tTable, sTableName, hFile, sTab)
    sTab = sTab or "";
    hFile:write(sTab..sTableName.." = {\n");
    for key, value in pairs(tTable) do
        if (type(value) ~= "function") then
            local sKey = (type(key) == "string") and string.format("[%q]", key) or string.format("[%d]", key);
            if(type(value) == "table") then
                Serialize(value, sKey, hFile, sTab.."\t");
            else
                local sValue = (type(value) == "string") and string.format("%q", value) or tostring(value);
                hFile:write(sTab.."\t"..sKey.." = "..sValue);
            end
            hFile:write(",\n");
        end
    end
    hFile:write(sTab.."}");
end

hub.debug( "** Loaded "..scriptname.." "..scriptversion.." **" )

--[END]

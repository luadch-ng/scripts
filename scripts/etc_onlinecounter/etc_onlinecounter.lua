--[[
    Imported from luadch/scripts (etc_onlinecounter_v1.4 (english)) on 2026-05-05.
    Audited for Lua 5.4 by Aybo. License: GPLv3.
    See https://github.com/luadch-ng/scripts/blob/master/docs/IMPORT_NOTES.md
    for the import-pass triage.

    Lua 5.4 fixes (this fork):
    - Two sites of 1-arg os.difftime( os.time() - X ) replaced with direct
      arithmetic (os.time() - X). Same family of fix as luadch-ng/scripts#6;
      Lua 5.4 strict-checks os.difftime arity.

    Behaviour fixes:

    Bug: month-rollover safe-month branch wiped v.TotalTime = 0 (luadch-ng/scripts#21
    follow-up). The wipe is silent for fresh users (TotalTime is already 0
    during their FreeMonth), but it bites later: an operator using +setsafe
    on an established user (e.g. a vacation grant) erases that user's earned
    online time at the next month rollover. Fix: drop the wipe; safe-month
    semantics are now "no iTUT*60 deduction" only.

    Per-minute accumulator FreeMonth gate (luadch-ng/scripts#21):
    The original Jerker/Kungen behaviour - "during a FreeMonth (or a global
    safe month like December) a user does NOT accumulate TotalTime, the
    grace month genuinely does not count" - is intentional and matches the
    +setsafe / new-registration UX 10+ year operators rely on. An earlier
    fix (commit 37fd345, closing upstream luadch/scripts#19) removed this
    gate, mistaking it for a "TotalTime stuck at 0" bug. That removal is
    now reverted.

    For operators who genuinely want the "accumulate-but-do-not-deduct"
    semantic (i.e. a free month that BANKS time the user can use later),
    a cfg toggle is provided: bAccumulateDuringSafeMonth = true.
    Default: false (matches Jerker/Kungen original behaviour).

    Users with negative TotalTime (already blocked) always accumulate so
    they can recover via online time, regardless of FreeMonth status.

    Lua 5.4 fixes (this fork):
    - Two sites of 1-arg os.difftime( os.time() - X ) replaced with direct
      arithmetic (os.time() - X). Same family of fix as luadch-ng/scripts#6;
      Lua 5.4 strict-checks os.difftime arity.
]]--

--[[

	etc_onlinecounter (luadch-ng fork)

		v1.6:
			- i18n: route the user-facing chat / ucmd / opchat / login-
			  warning / formatter strings through cfg.loadlanguage. New
			  lang files at scripts/etc_onlinecounter/lang/etc_onlinecounter.lang.{de,en}
			  (62 keys, structure-identical EN+DE). Adds German translation.
			- tSettings.sNoSearchMsg and tSettings.sNoCTMMsg now default
			  from lang.msg_search_blocked / msg_ctm_blocked when the
			  operator does not override them. Pre-existing operator
			  overrides in tSettings continue to work unchanged.
			- The plural() helper is REMOVED. Both EN and DE format
			  templates now use the static "(s)" / "(e)" / "(n)" pseudo-
			  plural form (e.g. "1 year(s)" instead of grammatically
			  polished "1 year"). The reason: with multi-spec DE
			  templates like "%i Monat(e), %i Tag(e), ..." the inter-
			  leaved plural-suffix args would crash string.format on
			  the second %i (string expected, got "s"). Acceptable
			  EN regression for cross-locale safety and consistency
			  with ptx_tophubbers' lang shape.
			- The tSettings.sMenu RC-menu container labels ("About You",
			  "Online Counter") stay as operator-config in tSettings;
			  the labels INSIDE the menu (Show My Online Time, ...) are
			  localised. Operators wanting a localised sMenu can override
			  the tSettings literals directly.
			  Part of luadch-ng/scripts #31 PR-6.

]]--

--[[

	Online Counter 1.4 - By Jerker/Kungen
	- With free months
	- Keeps track of online time
	- Blocks users from search and download if requirements are not met

	Usage:
		[+!#]onlinecounter toponline
		[+!#]onlinecounter toponlinexy x-y
		[+!#]onlinecounter hubtime <nick>
		[+!#]onlinecounter myhubtime
		[+!#]onlinecounter settime <nick> <time>
		[+!#]onlinecounter userlowuptime
		[+!#]onlinecounter setsafe <nick> <months> <reason>
		[+!#]onlinecounter delsafe <nick>
		[+!#]onlinecounter showsafe
		[+!#]onlinecounter showhelp

	v1.4: by Jerker/Kungen
		- Added setting bReset: Total uptime is reset to 0 every new month [true = on; false = off]
		- Minor bug fixes

	v1.3: by Jerker/Kungen
		 Added Safelist and RC for this
		 Added setting bOpWarning: Send message to opchat when user with lower than specified Total uptime logs in [true = on; false = off]
		 Year is shown if users have been online over one year
		 Minor bug fixes

	v1.2: by Jerker
		- Added RC to show help

	v1.1: by Jerker
		- Resets total time after first new month for new accounts
		- Show error if toponline is called with greater start value than number of users

]]--

local scriptname = "etc_onlinecounter"
local scriptversion = "1.6"

local scriptlang = cfg.get( "language" )
local lang, err = cfg.loadlanguage( scriptlang, scriptname ); lang = lang or {}; err = err and hub.debug( err )

local tSettings = {
	-- Bot Name
	sBot = hub.getbot( ),
	
	-- Command
	sCmd = "onlinecounter",
	
	-- RightClick Menu
	sMenu = { "About You", "Online Counter" },

	-- Online Counter's DB
	fOnlineCounter = "scripts/data/etc_onlinecounter.tbl",

	-- Maximum hubbers to show when using !toponline
	iMax = 30,

	-- Send message to users with lower than specified Total uptime (TUT) [true = on; false = off]
	bWarning = true,
	
	-- Send message to opchat when user with lower than specified Total uptime (TUT) logs in [true = on; false = off]
	bOpWarning = false,
	
	-- Minimum Total uptime (hours) that triggers the warning
	iTUT = 150,

	-- Max TotalTime, must be greater than or equal to iTUT
	MaxTime = 9800,

	--Reset uptime every month
	bReset = false,

	-- Accumulate TotalTime during a user's FreeMonth (and during a global
	-- safe month like December) [true = on; false = off]. Default false
	-- matches the original Jerker/Kungen behaviour where the grace month
	-- genuinely does not count - the user's TotalTime stays put for the
	-- duration of FreeMonth and accumulation resumes at the next rollover.
	-- Set to true if you want a "bank free time" semantic where the user
	-- accumulates during the grace month and benefits from no deduction
	-- at rollover (the post-luadch/scripts#19-fix behaviour).
	bAccumulateDuringSafeMonth = false,

	-- Send hubtime stats on connect [true = on; false = off]
	bRankOnConnect = false,
	
	-- Block search
	bSearch = true,
	
	-- Message when search is blocked. Default pulled from lang
	-- (msg_search_blocked); set a literal here to override.
	sNoSearchMsg = lang.msg_search_blocked or "Your uptime is too low, search is blocked",

	-- Block download
	bCTM = true,
	
	-- Message when download is blocked. Default pulled from lang
	-- (msg_ctm_blocked); set a literal here to override.
	sNoCTMMsg = lang.msg_ctm_blocked or "Your uptime is too low, download is blocked",

	-- Profiles checked [0 = off; 1 = on]
	tProfiles = {
		[0] = 1,
		[10] = 1,
		[20] = 1,
		[30] = 0,
		[35] = 0,
		[40] = 0,
		[50] = 0,
		[55] = 0,
		[60] = 0,
		[70] = 0,
		[80] = 0,
		[90] = 0,
		[100] = 0,
	},

	tFreeMonth =
	{
		["01"] = 1,
		["06"] = 1,
		["07"] = 1,
		["08"] = 1,
		["12"] = 1,
	},
}

local opchat = hub.import "bot_opchat"
local hub_debug = hub.debug

local tOnlineCounter = util.loadtable( tSettings.fOnlineCounter ) or { }
local Month = nil
local FreeMonth = false

local ShowHelp

--OnError Crew //Zido
local OnError = function(msg)
	opchat.feed(msg)
end
--OnError Crew //Zido

local GetOnliner = function(user)
	-- For each hubber
	for i, v in pairs(tOnlineCounter) do
		-- Compare
		if i:lower() == user:lower() then
			-- Return
			return tOnlineCounter[i]
		end
	end
end

local MinutesToTime = function(iMinutes, bSmall)
	-- Build table with time fields
	local T = os.date("!*t", math.abs(tonumber(iMinutes*60)));
	local sign = ""
	if tonumber(iMinutes) < 0 then
		sign = "-"
	end
	-- Format to string. Static "(s)" / "(e)" / "(n)" pseudo-plural
	-- in EN / DE templates; no plural-helper arg.
	local sTime = string.format(lang.fmt_duration or "%i month(s), %i day(s), %i hour(s), %i minute(s)", T.month-1, T.day-1, T.hour, T.min)
	if T.year > 1970 then
		sTime = string.format(lang.fmt_duration_year_prefix or "%i year(s), ", T.year - 1970)..sTime
	end
	-- Small stat?
	if bSmall then
		-- For each digit
		for i in string.gmatch(sTime, "%d+") do
		-- Reduce if is preceeded by 0
		if tonumber(i) == 0 then sTime = string.gsub(sTime, "^"..i.."%s(%S+),%s", "")
		end

		end
	end
	-- Return
	return sign..sTime
end

local HoursToDays = function(iHours)
	local days = math.floor(tonumber(iHours/24))
	local hours = tonumber(iHours-(days*24))
	return string.format(lang.fmt_hoursdays or "%i day(s), %i hour(s)", days, hours)
end

local BuildStats = function(user, nick)
	local tNick = GetOnliner(nick)
	-- In DB
	if tNick then
		-- Generate message
		local sMsg = "\r\n\r\n\t"..string.rep("=", 40).."\r\n\t\t\t"..(lang.label_stats_header or "Stats:").."\r\n\t"..
		string.rep("-", 80).."\r\n\t- "..(lang.label_stats_nick or "Nick:").." "..nick.."\r\n\t- "..(lang.label_stats_total or "Total uptime:").." "..
		MinutesToTime(tNick.TotalTime, true).."\r\n"

		if user:firstnick() == nick then
		sMsg = sMsg.."\r\n\t- "..utf.format(lang.msg_stats_block_warn or "If your online time is lower than %d hours (%s) every month, your account will be blocked for download!", tSettings.iTUT, HoursToDays(tSettings.iTUT))
		end

		if tNick.FreeMonth then
			sMsg = sMsg.."\r\n\r\n\t- "..(lang.label_stats_freemonth or "Free month(s):").." "..tNick.FreeMonth.."\r\n\t- "..(lang.label_stats_reason or "Free month reason:").." "..tNick.FreeMonthReason.."\r\n\t- "..(lang.label_stats_addedby or "Added by:").." "..tNick.FreeMonthAddBy
		end

		-- Send stats
		user:reply(sMsg, tSettings.sBot, tSettings.sBot)
	else
		user:reply(utf.format(lang.msg_no_record or "*** Error: No record found for '%s'!", nick), tSettings.sBot)
	end
end

local toponline = function(user, data)
	-- Table isn't empty
	if next(tOnlineCounter) then
		-- Parse limits
		local _,_, iStart, iEnd = data:find("^%S+%s+(%d+)%-(%d+)$")
		-- Set if not set
		iStart, iEnd = (iStart or 1), (iEnd or tSettings.iMax)
		-- Header
		local tCopy, msg, iCount = {}, "\r\n\t"..string.rep("=", 140).."\r\n\t"..(lang.msg_top_columns or "Nr.\tTotal:\t\t\t\t\tSession:\t\tEntered Hub:\t\tLeft Hub:\t\t\tStatus:\tName:").."\r\n\t"..string.rep("-", 280).."\r\n", 0
		-- Loop through hubbers
		for i, v in pairs(tOnlineCounter) do
			-- Insert stats to temp table
			table.insert(tCopy, { sEnter = v.Enter, iSessionTime = tonumber(v.SessionTime),
			iTotalTime = tonumber(v.TotalTime), sLeave = v.Leave, sNick = v.CurrentNick } )
			if tonumber(v.TotalTime) > 0 then
				iCount = iCount + 1
			end
		end
		if tonumber(iStart) <= iCount then
			-- Sort by total time
			table.sort(tCopy, function(a, b) return (a.iTotalTime > b.iTotalTime) end)
			-- Loop through temp table
			for i = iStart, iEnd, 1 do
				-- i exists
				if tCopy[i] then
					if tCopy[i].iTotalTime <= 0 then
						break
					end
					-- Populate
					local sStatus, v = (lang.msg_offline or "*Offline*"), tCopy[i]
					if hub.isnickonline(v.sNick) then sStatus = (lang.msg_online or "*Online*") end
					msg = msg.."\t"..i..".\t"..MinutesToTime(v.iTotalTime).."\t"..string.format("%.1f",tonumber(v.iSessionTime)/60).." h\t\t"
					..v.sEnter.."\t"..v.sLeave.."\t"..sStatus.."\t"..v.sNick.."\r\n"
				end
			end
			msg = msg.."\t"..string.rep("-", 280)
			-- Send
			user:reply((lang.msg_top_header or "Current Top Online:").."\r\n"..msg.."\r\n", tSettings.sBot, tSettings.sBot)
		else
			user:reply(utf.format(lang.msg_too_high or "*** Error: Only %d users in table, %d is too high!", iCount, iStart), tSettings.sBot)
		end
	else
		user:reply(lang.msg_table_empty or "*** Error: Online Counter's table is currently empty!", tSettings.sBot)
	end
end

local tCommands = {
	toponline = {
		fFunction = function(user, data)
			toponline(user, "")
			return PROCESSED
		end,
		minLevel = 10,
		tRC = {
			{ { utf.format(lang.label_show_top or "Show Top %d Online Time", tSettings.iMax) }, { }, { "CT1" } },
		},
		help = {
			{ "",  utf.format(lang.label_show_top or "Show Top %d Online Time", tSettings.iMax) },
		}
	},
	toponlinexy = {
		fFunction = function(user, data)
			toponline(user, data)
			return PROCESSED
		end,
		minLevel = 60,
		tRC = {
			{ { lang.label_show_topxy or "Show Top X-Y Online Time" }, { "%[line:"..(lang.ucmd_input_xy or "x-y").."]" }, { "CT1" } }
		},
		help = {
			{ lang.help_arg_xy or "<X-Y>", lang.label_show_topxy or "Show Top X-Y Online Time" }
		}
	},
	hubtime = {
		fFunction = function(user, data)
			-- Parse nick
			local _,_, sNick = data:find("^%S+%s+(%S+)$")
			-- Exists
			if sNick then
				local tUser = hub.isnickonline(sNick)
				if tUser then
					sNick = tUser:firstnick()
				end
				-- Return
				BuildStats(user, sNick)
			else
				user:reply(utf.format(lang.msg_syntax_hubtime or "*** Syntax Error: Type !%s hubtime <nick>", tSettings.sCmd), tSettings.sBot)
			end
			return PROCESSED
		end,
		minLevel = 60,
		tRC = {
			{ { lang.label_show_user or "Show User Online Time" }, { "%[line:"..(lang.ucmd_input_nick or "Nick").."]" }, { "CT1" } },
			{ { lang.label_show_user or "Show User Online Time" }, { "%[userNI]" }, { "CT2" } }
		},
		help = {
			{ lang.help_arg_nick or "<nick>", lang.label_show_user or "Show User Online Time" }
		}
	},
	myhubtime = {
		fFunction = function(user)
			-- Return
			BuildStats(user, user:firstnick())
			return PROCESSED
		end,
		minLevel = 20,
		tRC = {
			{ { lang.label_show_my or "Show My Online Time" }, { }, { "CT1" } }
		},
		help = {
			{ "", lang.label_show_my or "Show My Online Time" }
		}
	},
	settime = {
		fFunction = function(user, data)
			local tMultiplier = {
				["m"] = 1,
				["h"] = 60,
				["d"] = 24 * 60,
				["w"] = 7 * 24 * 60,
				["M"] = 30 * 24 * 60
			}
			local _,_, sNick = data:find("^%S+%s+(%S+)")
			if sNick then
				local tUser = hub.isnickonline(sNick)
				if tUser then
					sNick = tUser:firstnick()
				end
				local _,_, sTime, sMultiplier = data:find("^%S+%s+%S+%s+(-?%d+)(%a?)$")
				if sTime and tonumber(sTime) then
					if sMultiplier and tMultiplier[sMultiplier] then
						if sMultiplier == "M" and tonumber(sTime) > 0 then
							local d = os.date("*t", 0)
							local y = 0
							if tonumber(sTime) >= 12 then
								y = math.floor(tonumber(sTime) / 12)
								sTime = tonumber(sTime) - (tonumber(y) * 12)
							end
							d.year = d.year + tonumber(y)
							d.month = d.month + tonumber(sTime)
							sTime = os.time(d) / 60
						else
							sTime = tonumber(sTime) * tMultiplier[sMultiplier]
						end
					end
					if tonumber(sTime) > tSettings.MaxTime * 60 then
						sTime = tSettings.MaxTime * 60
					end
					local tNick = GetOnliner(sNick)
					if tNick then
						tNick.TotalTime = tonumber(sTime)
						user:reply(utf.format(lang.msg_settime_set or "New total time for %s is %s.", sNick, MinutesToTime(tNick.TotalTime, true)), tSettings.sBot)
					else
						user:reply(utf.format(lang.msg_no_record or "*** Error: No record found for '%s'!", sNick), tSettings.sBot)
					end
				else
					user:reply(utf.format(lang.msg_syntax_settime or "*** Syntax Error: Type !%s settime <nick> <time[m|h|d|w|M]>", tSettings.sCmd), tSettings.sBot)
				end
			else
				user:reply(utf.format(lang.msg_syntax_settime or "*** Syntax Error: Type !%s settime <nick> <time[m|h|d|w|M]>", tSettings.sCmd), tSettings.sBot)
			end
			return PROCESSED
		end,
		minLevel = 60,
		tRC = {
			{ { lang.label_set_user or "Set User Online Time" }, { "%[line:"..(lang.ucmd_input_nick or "Nick").."]", "%[line:"..(lang.ucmd_input_time or "Time").."]" }, { "CT1" } },
			{ { lang.label_set_user or "Set User Online Time" }, { "%[userNI]", "%[line:"..(lang.ucmd_input_time or "Time").."]" }, { "CT2" } }
		},
		help = {
			{ lang.help_arg_settime or "<nick> <time[m|h|d|w|M]>", lang.label_set_user or "Set User Online Time" }
		}
	},
	userlowuptime = {
		fFunction = function(user, data)
			local iCount = 0
			local msg = (lang.msg_lowuptime_header or "Users with too low online time:").."\r\n"
			if next(tOnlineCounter) then
				local _,regnicks = hub.getregusers( )
				for i, v in pairs(tOnlineCounter) do
					--check if user has free month and check profile
					if not v.FreeMonth then
						local tUser = regnicks[ i ]
						if tUser then
							--if to low online time block user
							if v.TotalTime < tSettings.iTUT*60 and tSettings.tProfiles[tUser.level] and tSettings.tProfiles[tUser.level] == 1 then
								msg = msg..i.."\t"..MinutesToTime(v.TotalTime, true).."\r\n"
								iCount = iCount + 1
							end
						end
					end
				end
			end
			if iCount > 0 then
				user:reply(msg, tSettings.sBot, tSettings.sBot)
			else
				user:reply(lang.msg_no_lowuptime or "No users with too low online time.", tSettings.sBot, tSettings.sBot)
			end
            return PROCESSED
		end,
		minLevel = 60,
		tRC = {
			{ { lang.label_show_lowuptime or "Show Users With Too Low Online Time" }, { }, { "CT1" } }
		},
		help = {
			{ "", lang.label_show_lowuptime or "Show Users With Too Low Online Time" }
		}
	},
	setsafe = {
		fFunction = function(user, data)
			local _,_, sNick, iMonth, sReason = data:find("^%S+%s+(%S+)%s+(%S+)%s+(.+)")
			if not sNick or not tonumber(iMonth) or not sReason then
				user:reply(utf.format(lang.msg_syntax_setsafe or "*** Syntax Error: Type !%s setsafe <nick> <months> <reason>", tSettings.sCmd), tSettings.sBot)
				return PROCESSED
			end

			iMonth = tonumber(iMonth)
			if iMonth > 5 then
				user:reply(lang.msg_safe_max or "Max 5 safe month.", tSettings.sBot)
				return PROCESSED
			end

			local tUser = hub.isnickonline(sNick)
			if tUser then
				sNick = tUser:firstnick()
			end
			local tNick = GetOnliner(sNick)

			if not tNick then
				user:reply(utf.format(lang.msg_no_record or "*** Error: No record found for '%s'!", sNick), tSettings.sBot)
				return PROCESSED
			end

			if iMonth <= 0 then
				tNick.FreeMonth = nil
				tNick.FreeMonthReason = nil
				tNick.FreeMonthAddBy = nil

				local msg = utf.format(lang.msg_safe_removed or "%s no clean month is now remove because of %s.", sNick, sReason)
				OnError(msg.." //"..user:nick())
				user:reply(msg, tSettings.sBot)
			else
				tNick.FreeMonth = iMonth
				tNick.FreeMonthReason = sReason
				tNick.FreeMonthAddBy = user:nick()
				if tNick.TotalTime < 0 then
					tNick.TotalTime = 0
				end
				local msg = utf.format(lang.msg_safe_added or "%s have get %d no clean month, because of %s.", sNick, iMonth, sReason)
				OnError(msg.." //"..user:nick())
				user:reply(msg, tSettings.sBot)
			end
			return PROCESSED
		end,
		minLevel = 60,
		tRC = {
			{ { lang.label_add_safe or "Add User To Safe List" }, { "%[line:"..(lang.ucmd_input_nick or "Nick").."]", "%[line:"..(lang.ucmd_input_months or "Months").."]", "%[line:"..(lang.ucmd_input_reason or "Reason").."]" }, { "CT1" } },
			{ { lang.label_add_safe or "Add User To Safe List" }, { "%[userNI]", "%[line:"..(lang.ucmd_input_months or "Months").."]", "%[line:"..(lang.ucmd_input_reason or "Reason").."]" }, { "CT2" } }
		},
		help = {
			{ lang.help_arg_setsafe or "<nick> <months> <reason>", lang.label_add_safe or "Add User To Safe List" }
		}
	},
	delsafe = {
		fFunction = function(user, data)
			local _,_, sNick = data:find("^%S+%s+(%S+)")
			if sNick then
				local tUser = hub.isnickonline(sNick)
				if tUser then
					sNick = tUser:firstnick()
				end
				local tNick = GetOnliner(sNick)
				if tNick then
					if tNick.FreeMonth and tNick.FreeMonth > 0 then
						tNick.FreeMonth = nil
						tNick.FreeMonthReason = nil
						tNick.FreeMonthAddBy = nil
						user:reply(utf.format(lang.msg_safe_unsafe or "%s is removed safe list.", sNick), tSettings.sBot)
					else
						user:reply(utf.format(lang.msg_safe_notonlist or "%s is not on safe list.", sNick), tSettings.sBot)
					end
				else
					user:reply(utf.format(lang.msg_no_record or "*** Error: No record found for '%s'!", sNick), tSettings.sBot)
				end
			else
				user:reply(utf.format(lang.msg_syntax_delsafe or "*** Syntax Error: Type !%s delsafe <nick>", tSettings.sCmd), tSettings.sBot)
			end
			return PROCESSED
		end,
		minLevel = 60,
		tRC = {
			{ { lang.label_remove_safe or "Remove User From Safe List" }, { "%[line:"..(lang.ucmd_input_nick or "Nick").."]" }, { "CT1" } },
			{ { lang.label_remove_safe or "Remove User From Safe List" }, { "%[userNI]" }, { "CT2" } }
		},
		help = {
			{ lang.help_arg_nick or "<nick>", lang.label_remove_safe or "Remove User From Safe List" }
		}
	},
	showsafe = {
		fFunction = function(user)
			local iCount = 0
			local iMaxLen = 0
			local msg = "\r\n"..(lang.msg_safelist_header or "Users on safe list:").."\r\n"
			if next(tOnlineCounter) then
				local _,regnicks = hub.getregusers( )
				for i, v in pairs(tOnlineCounter) do
					if v.FreeMonth and v.FreeMonth > 0 then
						iCount = iCount + 1
						iMaxLen = math.max(iMaxLen, string.len(i))
					end
				end

				local fmt = string.format("%%-%ii%%-%is%%-10s%%s", string.len(tostring(iCount)) + 2, iMaxLen + 4)
				iCount = 0
				for i, v in pairs(tOnlineCounter) do
					--check if user is safe
					if v.FreeMonth and v.FreeMonth > 0 then
						local tUser = regnicks[ i ]
						if tUser then
							iCount = iCount + 1
							msg = msg..string.format(fmt, iCount, i, string.format(lang.fmt_months or "%i Month(s)", v.FreeMonth), v.FreeMonthReason).."\r\n"
						end
					end
				end
			end
			if iCount > 0 then
				user:reply(msg, tSettings.sBot, tSettings.sBot)
			else
				user:reply(lang.msg_no_safelist or "No users on safe list.", tSettings.sBot, tSettings.sBot)
			end
            return PROCESSED
		end,
		minLevel = 60,
		tRC = {
			{ { lang.label_show_safe or "Show Users On Safe List" }, { }, { "CT1" } }
		},
		help = {
			{ "", lang.label_show_safe or "Show Users On Safe List" }
		}
	},
	showhelp = {
		fFunction = function(user)
			ShowHelp(user)
			return PROCESSED
		end,
		minLevel = 20,
		tRC = {
			{ { lang.label_show_help or "Show Help" }, { }, { "CT1" } }
		},
		help = {
			{ "", lang.label_show_help or "Show Help" }
		}
	},
}

ShowHelp = function(user)
	local sMsg = ""
	for i, v in pairs(tCommands) do
		if user:level() >= v.minLevel then
			for _, w in ipairs(v.help) do
				if w[1] ~= "" then
					sMsg = sMsg.."\r\n\t[+!#]"..tSettings.sCmd.." "..i.." "..w[1].."\t"..w[2]
				else
					sMsg = sMsg.."\r\n\t[+!#]"..tSettings.sCmd.." "..i.."\t\t"..w[2]
				end
			end
		end
	end
	if sMsg ~= "" then
		user:reply("\r\n\r\n\t"..(lang.msg_usage_header or "Usage:")..sMsg, tSettings.sBot, tSettings.sBot)
	end
end

local onbmsg = function(user, cmd, parameters, msg)
	local _,_, to = msg:find("^$To:%s(%S+)%s+From:")
    -- Parse command
	local subCmd = string.match( parameters, "^(%S+)" )
	-- Exists
	if subCmd and tCommands[string.lower(subCmd)] then
		subCmd = string.lower(subCmd)
		-- PM
		local tmp = nil
		if to and to == tSettings.sBot then tmp = tSettings.sBot end
		-- If user has permission
		if user:level() >= tCommands[subCmd].minLevel then
			return tCommands[subCmd].fFunction(user, parameters), 1
		else
			user:reply(lang.msg_no_perm or "*** Error: You are not allowed to use this command!", tSettings.sBot, tmp)
			return PROCESSED
		end
	end
end

local function TableConcat(t1, t2)
	local result = {}
    for i=1, #t1 do
        result[#result + 1] = t1[i]
    end
	for i=1, #t2 do
        result[#result + 1] = t2[i]
    end
    return result
end

hub.setlistener( "onStart", { },
	function()
		string.gmatch = (string.gmatch or string.gfind)
		local ucmd = hub.import( "etc_usercommands" )
		if ucmd then
			for i, v in pairs(tCommands) do
				for _, w in ipairs(v.tRC) do
					ucmd.add(TableConcat(tSettings.sMenu, w[1]), tSettings.sCmd.." "..i, w[2], w[3], v.minLevel)
				end
			end
		end
		local hubcmd = hub.import( "etc_hubcommands" )    -- add hubcommand
		assert( hubcmd )
		assert( hubcmd.add( tSettings.sCmd, onbmsg, tCommands.toponline.minLevel ) )

		--Set month //Zido
		Month = os.date("%m")
		
		--make check for free month
		if tSettings.tFreeMonth[ Month ] and tSettings.tFreeMonth[ Month ] == 1 then
			FreeMonth = true
		end

		--add hub reg to tOnlineCounter db
		local regusers, reggednicks, reggedcids = hub.getregusers( )
		if next(regusers) then
			for i, user in ipairs( regusers ) do
				if not user.is_bot then
					local tNick = GetOnliner(user.nick)
					if not tNick then
						-- Create new entry
						tOnlineCounter[user.nick] = {
							CurrentNick = user.nick,
							Julian = os.time(os.date("!*t")),
							Enter = os.date("%Y-%m-%d %H:%M:%S"),
							SessionTime = 0,
							TotalTime = 0,
							Leave = os.date("%Y-%m-%d %H:%M:%S"),
							FreeMonth = 1,
							FreeMonthReason = lang.msg_freemonth_newreg or "New reg",
							FreeMonthAddBy = lang.msg_freemonth_addedby_bot or "Bot"
						}
					end
				end
			end
		end
		
		-- Set and Start Timer
		tSettings.iTimer = os.time()
		tSettings.SaveData = os.time()
	end 
)

hub.setlistener( "onTimer", { },
	function()	
		if tSettings.iTimer and (os.time() - tSettings.iTimer) >= 60 then
			tSettings.iTimer = os.time()
			--check db if new month //Zido
			if Month ~= os.date("%m") then
				local _,regnicks = hub.getregusers( )
				local reloadUserList = false
				-- For each hubber
				for i, v in pairs(tOnlineCounter) do
					--check if reg
					local user = regnicks[ i ]
					if user then
						--check if user has free month and check profile
						if not v.FreeMonth or v.FreeMonth <= 0 then
							if not FreeMonth then -- Don't remove time if previous month was free month
								v.TotalTime = v.TotalTime - (tSettings.iTUT*60)
								if v.TotalTime < 0 then
									if hub.isnickonline(v.CurrentNick) then
										-- Warn user?
									end
								elseif tSettings.bReset then
									v.TotalTime = 0
								end
							end
						else
							--if user has free month count down or remove
							v.FreeMonth = v.FreeMonth-1
							-- Removed `v.TotalTime = 0` here (luadch-ng/scripts#21).
							-- The wipe is silent for fresh registrations because the
							-- accumulator gate keeps TotalTime at 0 throughout the
							-- FreeMonth, but it bites a +setsafe-on-an-established-user
							-- flow: the operator grants the user a safe month, the next
							-- rollover wipes their earned online time. Safe-month
							-- semantics are now "no iTUT*60 deduction" only.
							OnError(utf.format(lang.op_user_safemonth_status or "%s is not checked because %s and have %d no free month back. (Online time: %s)", i, v.FreeMonthReason, v.FreeMonth, MinutesToTime(v.TotalTime, true)))

						end
						if v.FreeMonth ~= nil and v.FreeMonth <= 0 then
							v.FreeMonth = nil
							v.FreeMonthReason = nil
							v.FreeMonthAddBy = nil
						end
						v.Julian = os.time(os.date("!*t"))
					else
						--Show/delete user data if not reg
						tOnlineCounter[i] = nil
						OnError(utf.format(lang.op_user_deleted or "%s user data is remove because the user is deleted.", i))
					end
				end
				--send msg to Crews
				OnError(lang.op_new_month or "New Month started, all online data is checked.")
				if reloadUserList then
					hub.reloadusers()
				end
			
				--set new month
				Month = os.date("%m")
				--make check for free month
				FreeMonth = false
				if tSettings.tFreeMonth[ Month ] and tSettings.tFreeMonth[ Month ] == 1 then
					FreeMonth = true
				end
			end
			--check db if new month //Zido
			
			-- For each hubber
			for i, v in pairs(tOnlineCounter) do
            -- Online
				if hub.isnickonline(v.CurrentNick) then
					v.SessionTime = v.SessionTime + 1
					-- Per-minute TotalTime accumulator (luadch-ng/scripts#21).
					-- Gate: a user with FreeMonth > 0 OR during a global safe
					-- month does NOT accumulate, matching the original
					-- Jerker/Kungen behaviour. Override via the cfg toggle
					-- bAccumulateDuringSafeMonth (default false).
					-- Exception: users with negative TotalTime (already
					-- blocked) always accumulate so they can recover via
					-- online time. The MaxTime cap keeps long-time users
					-- from overflowing.
					if v.TotalTime < tSettings.MaxTime * 60 then
						local user_safe = ( v.FreeMonth and v.FreeMonth > 0 ) or FreeMonth
						local accumulate = tSettings.bAccumulateDuringSafeMonth
							or ( not user_safe )
							or v.TotalTime < 0
						if accumulate then
							v.TotalTime = v.TotalTime + 1
						end
					end
				end
			end

		end
		
		if tSettings.SaveData and (os.time() - tSettings.SaveData) >= 10*60 then
			tSettings.SaveData = os.time()
			util.savetable( tOnlineCounter, "tOnlineCounter", tSettings.fOnlineCounter )
		end
	end
)

hub.setlistener( "onExit", { },
	function()
		-- Save
		util.savetable( tOnlineCounter, "tOnlineCounter", tSettings.fOnlineCounter )
	end
)

hub.setlistener( "onLogin", { },
	function(user)
		if not user:isbot( ) then
			-- For each hubber
			local tNick = tOnlineCounter[ user:firstnick() ]
		
			-- User already in DB
			if tNick then
				--MOD //Zido
				--remove msg about min time
				if not tNick.FreeMonth then
					-- Rank on connect bRankOnConnect
					if tSettings.bRankOnConnect then
						BuildStats(user, user:firstnick())
					end
					
					-- Warning on connect
					if tSettings.tProfiles[user:level()] and tSettings.tProfiles[user:level()] == 1 then
						-- Less than zero equals blocked
						if tNick.TotalTime < 0 then
							if tSettings.bOpWarning then
								OnError(utf.format(lang.op_user_blocked or "%s is blocked because of too low uptime.", user:nick()))
							end
							
						-- Less than allowed
						elseif tNick.TotalTime < tSettings.iTUT*60 and tonumber(os.date("%d")) > 20 and tSettings.bWarning and not FreeMonth then
							-- Warn
							user:reply(utf.format(lang.msg_login_warning or "*** Your Total Online Time Is %s. If your Online Time is lower than %d hours every month, your account will be blocked!", MinutesToTime(tNick.TotalTime, true), tSettings.iTUT), tSettings.sBot, tSettings.sBot)
						end
					end
				end
				--MOD //Zido
				
				-- Reset and save time
				tNick.SessionTime = 0
				tNick.Enter = os.date("%Y-%m-%d %H:%M:%S")
				tNick.CurrentNick = user:nick()
			else
				-- Create new entry
				tOnlineCounter[user:firstnick()] = {
					CurrentNick = user:nick(),
					Julian = os.time(os.date("!*t")),
					Enter = os.date("%Y-%m-%d %H:%M:%S"),
					SessionTime = 0,
					TotalTime = 0,
					Leave = os.date("%Y-%m-%d %H:%M:%S"),
					FreeMonth = 1,
					FreeMonthReason = lang.msg_freemonth_newreg or "New reg",
					FreeMonthAddBy = lang.msg_freemonth_addedby_bot or "Bot"
				}
			end
		end
	end
)

hub.setlistener( "onLogout", { },
	function(user)
		-- Log date
		local tNick = GetOnliner(user:firstnick())
		if tNick then
			tNick.Leave = os.date("%Y-%m-%d %H:%M:%S")
		end
	end
)

hub.setlistener( "onSearch", { },
	function(user, adccmd)
		if tSettings.bSearch then
			if tSettings.tProfiles[user:level()] and tSettings.tProfiles[user:level()] == 1 then
				local tNick = tOnlineCounter[ user:firstnick() ]
				if tNick and tNick.TotalTime < 0 then
					user:reply(tSettings.sNoSearchMsg, tSettings.sBot, tSettings.sBot)
					return PROCESSED
				end
			end
		end
	end
)

local checkuser = function(user, target, adccmd)
	if tSettings.bCTM then
		if tSettings.tProfiles[user:level()] and tSettings.tProfiles[user:level()] == 1 then
			local tNick = tOnlineCounter[ user:firstnick() ]
			if tNick and tNick.TotalTime < 0 then
				user:reply(tSettings.sNoCTMMsg, tSettings.sBot, tSettings.sBot)
				return PROCESSED
			end
		end
	end
end

hub.setlistener( "onConnectToMe", { }, checkuser) 

hub.setlistener( "onRevConnectToMe", { }, checkuser) 

hub_debug( "** Loaded " .. scriptname .. " " .. scriptversion .. " **" )

--// public //--

return {    -- export tOnlineCounter

    tOnlineCounter = tOnlineCounter,

}

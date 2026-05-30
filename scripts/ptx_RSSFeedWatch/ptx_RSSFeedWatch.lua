--[[
    Imported from luadch/scripts (ptx_RSSFeedWatch_v0.11 (english)) on 2026-05-05.
    Audited for Lua 5.4 by Aybo. License: GPLv3.
    See https://github.com/luadch-ng/scripts/blob/master/docs/IMPORT_NOTES.md
    for the import-pass triage.

    Hub requirement: luadch-ng/luadch v3.1.2 or later, which ships the
    canonical LuaSocket / LuaSec layout. The plugin's module-level
    `require "socket.http"` and `require "ssl.https"` only resolve on
    that layout. Earlier hub releases bundled flat
    (`lib/luasocket/lua/http.lua` etc.) and the plugin would not load.

    Bundled XML parser dep: slaxml/slaxml.lua ships in this plugin's
    folder. Operator-side install requires placing it at
    hub/lib/slaxml/slaxml.lua so `require "slaxml"` resolves via
    package.path's `lib/?/?.lua` rule. See Readme.txt for the
    upstream install steps.
]]--

--[[

	RSSFeedWatch script for Luadch rewritten from original Ptokax script:
		FeedWatch 1.0i LUA 5.1x [Strict][API 2]
		
	RSSFeedWatch.lua
		A socket script that watches an RSS feed for changes

		- this script adds a command "rss"
		- usage: [+!#]rss feedhelp for more instructions and a list of available commands

		v0.11: by Jerker
			- Fixed a problem where messages didn't end up in PM
			- Added new RCs

		v0.10: by Jerker
			- Renamed RCs
			- List feeds shows Tag instead of Url
			- Fixed format in Feed help and Settings

		v0.09: by Jerker
			- Added bot
			- Renamed RCs
			- Added new RCs
				* Mute a feed
				* Set refresh time
				* And more...
			- Checking http response code, 200 =  ok
			- Commands available from PM to bot
			Thanks to Kungen, Sopor and pulsar

		v0.08: by Jerker
			- Fixed a problem with character entities (&#nnn;)
			- Updated timer to use os.time

		v0.07: by Jerker
			- Added msgToPM option to send messages from commands to PM (true) or main (false)
			  when user hasn't selected channel, otherwise messages are sent to where user selected
			  Error messages are still sent to main
			- Converting non UTF-8 feeds to UTF-8
			- Don't truncate links
			- New labels for feed fields with tab count for formatting output
			- Added RC to Add and Delete feeds and to toggle ForceFeed setting

		v0.06: by Jerker
			- Added support for atom feeds
			- Added support for ssl

		v0.05: by Night
			- Fix a problem with using nick prefix script
			- Fix a typo in FeedHelp

		v0.04: by Night
			- Change the ForceFeed option to allow enabling multiple forced feeds
			- Add ForceFeedPM option to send forced feeds in PM

		v0.03: by Night
			- Better ways to change FeedText content

		v0.02: by Night
			- Add RC
			- Add option to Get all feeds at once ( ex. different release category links ) 
			- Don't list commands user is not allowed to use in FeedHelp

		v0.01: by Night
			- initial version


	Dependencies:
		Luasocket http.
		Luadch comes with these already so all you need to do is:
			-Create socket folder ../lib/luasocket/lua/socket/
			-Copy all files from ../lib/luasocket/lua/ folder into ../lib/luasocket/lua/socket/

		Luasec https.
		Luadch comes with these already so all you need to do is:
			-Create ssl folder ../lib/luasec/lua/ssl/
			-Copy all files from ../lib/luasec/lua/ folder into ../lib/luasec/lua/ssl/
		
		slaxml.lua
			-Copy folder slaxml to ../lib/

]]

--//--

--[[

    ptx_RSSFeedWatch (luadch-ng fork)

        v0.12:
            - i18n: route the user-facing chat / ucmd / command-help /
              "New Feed" header strings through cfg.loadlanguage. New
              lang files at scripts/ptx_RSSFeedWatch/lang/ptx_RSSFeedWatch.lang.{de,en}
              (119 keys, structure-identical EN+DE). Adds German
              translation.
            - Display-layout texts (the settings table contents, the
              lastfeed/listfeeds/listusers column outputs) keep their
              English column structure; only column HEADERS and
              standalone status messages are localised. This is the
              partial-i18n compromise for a 1472-LoC plugin: covers
              the user-visible chat surface, defers structural-text
              layout rewrites to a future iteration.
            - The cmd / subcommand-trigger word "rss" plus its sub-
              command names (feeds / lastfeed / addfeed / forcefeed /
              delfeed / refresh / maxfeeds / maxcache / maxwidth /
              getfeed / mutefeed / focefeedpm / msgtopm / simple /
              feedhelp / settings / listfeeds / listusers) stay
              English in both lang files - they are user-typed
              command words, not display labels.
              Part of luadch-ng/scripts #31 PR-7.

]]--

local scriptname = "ptx_RSSFeedWatch"
local scriptversion = "0.12"
local display_name = "RSSFeedWatch" -- shown in chat headers / ucmd labels
local cmd = "rss"

local scriptlang = cfg.get( "language" )
local lang, err = cfg.loadlanguage( scriptlang, scriptname ); lang = lang or {}; err = err and hub.debug( err )

--// imports
local help, ucmd, hubcmd

local socket = require "socket"
assert(socket,"Failed to load socket extension. Check files.")
local http = require("socket.http")
assert(http,"Failed to load http module. Check files.")
local https = require("ssl.https")
assert(https,"Failed to load https module. Check files.")

local cmd_text ="[+!#]rss "
local msg_usage = lang.msg_usage or "Usage: [+!#]rss cmd, type [+!#]rss feedhelp for further instructions."
local msg_denied = lang.msg_denied or "You are not allowed to use this command."

local hub_broadcast = hub.broadcast
local hub_sendtoall = hub.sendtoall
local hub_isnickonline = hub.isnickonline
local hub_loadsettings = hub.reloadcfg
local hub_import = hub.import
local hub_debug = hub.debug

local util_loadtable = util.loadtable
local util_savetable = util.savetable
local utf_gsub = utf.gsub
local utf_sub = utf.sub
local utf_find = utf.find
local utf_len = utf.len
local utf_match = utf.match
local utf_format = utf.format
local utf_char = utf.char
local string_rep, string_char = string.rep, string.char
local push, pop, concat, table_sort = table.insert, table.remove, table.concat, table.sort
local delete, os_time = os.remove, os.time

local Params = {
	["name"] = "",
	["plural"] = "",
	["count"] = "",
	["feed"] = "",
	}

local ucmd_root = lang.ucmd_menu_root or "RSSFeedWatch"
local ucmd_group_settings = lang.ucmd_menu_settings_group or "Settings"
local ucmd_menu_help = { ucmd_root, lang.ucmd_label_help or "Show help" }
local ucmd_menu_feeds = { ucmd_root, lang.ucmd_label_feeds or "Set feed settings" }
local ucmd_menu_lastfeed = { ucmd_root, lang.ucmd_label_lastfeed or "Show last feeds" }
local ucmd_menu_listusers = { ucmd_root, lang.ucmd_label_listusers or "List active feed users" }
local ucmd_menu_listfeeds = { ucmd_root, lang.ucmd_label_listfeeds or "List available feeds" }
local ucmd_menu_addfeed = { ucmd_root, lang.ucmd_label_addfeed or "Add a feed" }
local ucmd_menu_forcefeed = { ucmd_root, lang.ucmd_label_forcefeed or "Toggle force feed" }
local ucmd_menu_deletefeed = { ucmd_root, lang.ucmd_label_deletefeed or "Delete a feed" }
local ucmd_menu_getfeed = { ucmd_root, lang.ucmd_label_getfeed or "Get next feed" }
local ucmd_menu_mutefeed = { ucmd_root, lang.ucmd_label_mutefeed or "Mute//Unmute a feed" }
local ucmd_menu_refresh = { ucmd_root, ucmd_group_settings, lang.ucmd_label_refresh or "Set feed refresh" }
local ucmd_menu_maxfeeds = { ucmd_root, ucmd_group_settings, lang.ucmd_label_maxfeeds or "Set feeds to show" }
local ucmd_menu_maxcache = { ucmd_root, ucmd_group_settings, lang.ucmd_label_maxcache or "Set feeds to cache" }
local ucmd_menu_maxwidth = { ucmd_root, ucmd_group_settings, lang.ucmd_label_maxwidth or "Set max width" }
local ucmd_menu_focefeedpm = { ucmd_root, ucmd_group_settings, lang.ucmd_label_focefeedpm or "Toggle forced feeds to PM" }
local ucmd_menu_msgtopm = { ucmd_root, ucmd_group_settings, lang.ucmd_label_msgtopm or "Toggle messages to PM" }
local ucmd_menu_simple = { ucmd_root, ucmd_group_settings, lang.ucmd_label_simple or "Toggle simple display" }
local ucmd_menu_settings = { ucmd_root, ucmd_group_settings, lang.ucmd_label_settings or "Show settings" }

local minlevel = 10 -- local min level to use rss command, each command has its own min level settings
local Bot
-- Name of the bot
local BotName = "[--=FeedBot=--]"
local BotDescription = lang.bot_desc or "RSSFeedWatch"
-- Start with which feed?
local StartFeed = 1
-- Set the socket timeout value, in seconds
local TimeOut = 5
--Script data path
local Path = "scripts/data/RSSFeedWatch/"
-- File to save user data to
local UserFile = Path.."FeedUsers.tbl"
-- File to save feeds data to
local FeedsFile = Path.."Feeds.tbl"
-- File to save settings to
local SettingsFile = Path.."FeedSettings.tbl"
-- Savable settings table
local tSettings = {
	-- Set the update interval [in minutes]
	Refresh = 10,
	-- Get all Feeds at once in Refresh Time
	allFeedsAtOnce = false,
	-- Maximum number of feeds to display
	MaxFeeds = 5,
	-- Maximum number of feeds to cache to file
	MaxCache = 5,
	-- Truncate RSS fields, except links, to this width.
	MaxWidth = 120,
	-- Send Forced Feed in PM
	ForceFeedPM = false,
	-- Get StartFeed at script start? true/false [false = Get Feed at first timer interval]
	GetFeedAtStart = true,
	-- Remove all HTML <tags> in feed fields? true/false
	TagFilter = true,
	-- Use simple 'title' display only true/false
	Simple = false,
	-- Messages from command in PM
	msgToPM = true,
}

local Feeds = util_loadtable( FeedsFile ) or { }
--[[{
	{ url="http://feeds.bbci.co.uk/news/world/europe/rss.xml", tag="BBC", force=false },
	{ url="http://rss.cnn.com/rss/edition_world.rss", tag="CNN", force=false },
	{ url="http://yle.fi/uutiset/rss/uutiset.rss", tag="YLE", force=false },
	{ url="http://www.nytimes.com/services/xml/rss/nyt/HomePage.xml", tag="NYTimes", force=false },
	{ url="https://github.com/luadch/luadch/releases.atom", tag="Luadch", force=false },
}--]]

-- Body style. The "FeedWatch" decoration label is localised via lang.label_feedwatch_body.
local _body_label = lang.label_feedwatch_body or "FeedWatch"
local Body = "\n\n=== ".._body_label.." =======================================================================================\n%s\n======================================================================================= ".._body_label.." ===\n  "

local encoding = "UTF-8"

-- Change Feed text formats here. The "New Feed(s)" header line is localised via
-- lang.label_new_feed_header_{simple,pretty} with %s placeholders for count / plural / name.
local formatFeedText = function()
	local FeedText
	local hdr_simple = lang.label_new_feed_header_simple or "[ %s ] New Feed%s from: %s"
	local hdr_pretty = lang.label_new_feed_header_pretty or "[ %s ] New Feed%s from: %s"
	if tSettings.Simple then
		FeedText = utf_format(hdr_simple, Params["count"], Params["plural"], Params["name"]).."\r\n"..Params["feed"]
	else
		FeedText = "\r\n\r\n\t "..utf_format(hdr_pretty, Params["count"], Params["plural"], Params["name"]).."\r\n\r\n"..Params["feed"]
	end
	return FeedText
end

-- Enable capture of these RSS fields
-- name = field name in feed
-- label = label on screen
-- tabs = number of tabs between label and text
-- show = show the field
local RssFields = {
	[1] = {name="title", label="Title", tabs=2, show=true, },
	[2] = {name="link", label="Link", tabs=2, show=true, },
	[3] = {name="description", label="Desc", tabs=2, show=true, },
	[4] = {name="author", label="Auth", tabs=2, show=false, },
	[5] = {name="category", label="Cat", tabs=2, show=false, },
	[6] = {name="pubdate", label="Publ", tabs=2, show=true, },
	[7] = {name="guid", label="Id", tabs=2, show=false, },
	[8] = {name="comments", label="Comments", tabs=1, show=false, },
	}
-- Enable capture of these Atom fields
-- name = field name in feed
-- label = label on screen
-- tabs = number of tabs between label and text
-- show = show the field
-- specialCase = if text is in attribute or child field
--   source = source of text, "attr" = attribute, "kids" = child field
--   name = name of field or attribute
local AtomFields = {
	[1] = {name="title", label="Title", tabs=2, show=true, },
	[2] = {name="link", label="Link", tabs=2, show=true, specialCase={ source = "attr", name = "href"}, },
	[3] = {name="summary", label="Desc", tabs=2, show=true, },
	[4] = {name="author", label="Auth", tabs=2, show=false, specialCase={ source = "kids", name = "name"}, },
	[5] = {name="category", label="Cat", tabs=2, show=false, specialCase={ source = "attr", name = "term"}, },
	[6] = {name="published", label="Publ", tabs=2, show=true, },
	[7] = {name="id", label="Id", tabs=2, show=false, },
	}
-- Don't capture enabled fileds that contain these strings
local Negate = {"-MDT","TestString"}
-- Ascending list order true/false [false = descending]
local ListOrder = false

local Order = {"feeds","listusers","listfeeds","lastfeed","addfeed","forcefeed","delfeed","feedhelp","getfeed","mutefeed","refresh","maxfeeds","maxcache","settings"}

local Rep = {
	["<img [^>]->"] = "",
	["</?p>"] = "",
	["%s%s+"] = " ",
	["\160+"] = " ",
	["<a href.->(.-)</a>"] = function(x) return x end,
	["\t"] = " ",
	["\r\n"] = "",
	["<br.-/>"] = "",
	}

--//--

-- script functions
local FwCmds
local SaveFile
local SaveFeed
local GetFeed
local ChkUsers

local ParseFeed
local CreateXML
local FindElement
local FindAttibute
local GetEncoding
local TriggerGetFeed

local StartTime
local Users = util_loadtable( UserFile ) or {}

local fileExists = function(aFile)
   local f=io.open(aFile,"r")
   if f~=nil then io.close(f) return true else return false end
end

local ToUtf8 = function(data, enc)

	local Latin1 = {
		[128]="€",[130]="‚",[131]="ƒ",[132]="„",[133]="…",[134]="†",[135]="‡",
		[136]="ˆ",[137]="‰",[138]="Š",[139]="‹",[140]="Œ",[142]="Ž",[145]="‘",
		[146]="’",[147]="“",[148]="”",[149]="•",[150]="–",[151]="—",[152]="~",
		[153]="™",[154]="š",[155]="›",[156]="œ",[158]="ž",[159]="Ÿ",[160]=" ",
		[161]="¡",[162]="¢",[163]="£",[164]="¤",[165]="¥",[166]="¦",[167]="§",
		[168]="¨",[169]="©",[170]="ª",[171]="«",[172]="¬",[173]="­",[174]="®",
		[175]="¯",[176]="°",[177]="±",[178]="²",[179]="³",[180]="´",[181]="µ",
		[182]="¶",[183]="·",[184]="¸",[185]="¹",[186]="º",[187]="»",[188]="¼",
		[189]="½",[190]="¾",[191]="¿",[192]="À",[193]="Á",[194]="Â",[195]="Ã",
		[196]="Ä",[197]="Å",[198]="Æ",[199]="Ç",[200]="È",[201]="É",[202]="Ê",
		[203]="Ë",[204]="Ì",[205]="Í",[206]="Î",[207]="Ï",[208]="Ð",[209]="Ñ",
		[210]="Ò",[211]="Ó",[212]="Ô",[213]="Õ",[214]="Ö",[215]="×",[216]="Ø",
		[217]="Ù",[218]="Ú",[219]="Û",[220]="Ü",[221]="Ý",[222]="Þ",[223]="ß",
		[224]="à",[225]="á",[226]="â",[227]="ã",[228]="ä",[229]="å",[230]="æ",
		[231]="ç",[232]="è",[233]="é",[234]="ê",[235]="ë",[236]="ì",[237]="í",
		[238]="î",[239]="ï",[240]="ð",[241]="ñ",[242]="ò",[243]="ó",[244]="ô",
		[245]="õ",[246]="ö",[247]="÷",[248]="ø",[249]="ù",[250]="ú",[251]="û",
		[252]="ü",[253]="ý",[254]="þ",[255]="ÿ",
	}
	
	if enc ~= "UTF-8" then
		--convert to UTF-8
		for i,v in pairs(Latin1) do
			local c = string_char(i)
			data = utf_gsub(data, c, v)
		end
	end
	
	return data
end

local Decode = function(data)

	local entityMap = {
	["quot"] = "\"", ["apos"]="'", ["amp"] = "&", ["lt"] = "<", ["gt"] = ">", ["euro"] = "€",
	["sbquo"] = "‚", ["fnof"] = "ƒ", ["bdquo"] = "„", ["hellip"] = "…", ["dagger"] = "†",
	["Dagger"] = "‡", ["circ"] = "ˆ", ["permil"] = "‰", ["Scaron"] = "Š", ["lsaquo"] = "‹",
	["OElig"] = "Œ", ["lsquo"] = "‘", ["rsquo"] = "’", ["ldquo"] = "“", ["rdquo"] = "”",
	["bull"] = "•", ["ndash"] = "–", ["mdash"] = "—", ["tilde"] = "~", ["trade"] = "™",
	["scaron"] = "š", ["rsaquo"] = "›", ["oelig"] = "œ", ["Yuml"] = "Ÿ", ["nbsp"] = " ",
	["iexcl"] = "¡", ["cent"] = "¢", ["pound"] = "£", ["curren"] = "¤", ["yen"] = "¥",
	["brvbar"] = "¦", ["sect"] = "§", ["uml"] = "¨", ["copy"] = "©", ["ordf"] = "ª",
	["laquo"] = "«", ["not"] = "¬", ["shy"] = "­", ["reg"] = "®", ["macr"] = "¯", 
	["deg"] = "°", ["plusmn"] = "±", ["sup2"] = "²", ["sup3"] = "³", ["acute"] = "´",
	["micro"] = "µ", ["para"] = "¶", ["middot"] = "·", ["cedil"] = "¸", ["sup1"] = "¹",
	["ordm"] = "º", ["raquo"] = "»", ["frac14"] = "¼", ["frac12"] = "½", ["frac34"] = "¾",
	["iquest"] = "¿", ["Agrave"] = "À", ["Aacute"] = "Á", ["Acirc"] = "Â", ["Atilde"] = "Ã",
	["Auml"] = "Ä", ["Aring"] = "Å", ["AElig"] = "Æ", ["Ccedil"] = "Ç", ["Egrave"] = "È",
	["Eacute"] = "É", ["Ecirc"] = "Ê", ["Euml"] = "Ë", ["Igrave"] = "Ì", ["Iacute"] = "Í",
	["Icirc"] = "Î", ["Iuml"] = "Ï", ["ETH"] = "Ð", ["Ntilde"] = "Ñ", ["Ograve"] = "Ò",
	["Oacute"] = "Ó", ["Ocirc"] = "Ô", ["Otilde"] = "Õ", ["Ouml"] = "Ö", ["times"] = "×",
	["Oslash"] = "Ø", ["Ugrave"] = "Ù", ["Uacute"] = "Ú", ["Ucirc"] = "Û", ["Uuml"] = "Ü",
	["Yacute"] = "Ý", ["THORN"] = "Þ", ["szlig"] = "ß", ["agrave"] = "à", ["aacute"] = "á",
	["acirc"] = "â", ["atilde"] = "ã", ["auml"] = "ä", ["aring"] = "å", ["aelig"] = "æ",
	["ccedil"] = "ç", ["egrave"] = "è", ["eacute"] = "é", ["ecirc"] = "ê", ["euml"] = "ë",
	["igrave"] = "ì", ["iacute"] = "í", ["icirc"] = "î", ["iuml"] = "ï", ["eth"] = "ð",
	["ntilde"] = "ñ", ["ograve"] = "ò", ["oacute"] = "ó", ["ocirc"] = "ô", ["otilde"] = "õ",
	["ouml"] = "ö", ["divide"] = "÷", ["oslash"] = "ø", ["ugrave"] = "ù", ["uacute"] = "ú",
	["ucirc"] = "û", ["uuml"] = "ü", ["yacute"] = "ý", ["thorn"] = "þ", ["yuml"] = "ÿ",
	}
	local entitySwap = function(orig,n,s) return entityMap[s] or n=="#" and utf_char(tonumber('0'..s)) or orig end  
	
	return utf_gsub( data, '(&(#?)([%d%a]+);)', entitySwap )
end

CreateXML = function(xml)
	local SLAXML = require 'slaxml'
	local stack = {}
	local doc = { type="document", name="#doc" }
	local current = doc
	push(stack,doc)
	local builder = SLAXML:parser{
		startElement = function(name,nsURI)
			local el = { type="element", name=name, nsURI=nsURI }
			if current==doc then
				if doc.root then error(utf_format("Encountered element '%s' when the document already has a root '%s' element",name,doc.root.name)) end
				doc.root = el
			end
			if not current.kids then current.kids = { } end
			push(current.kids,el)
			current = el
			push(stack,el)
		end,
		attribute = function(name,value,nsURI)
			if not current or current.type~="element" then error(utf_format("Encountered an attribute %s=%s but I wasn't inside an element",name,value)) end
			local attr = {type='attribute',name=name,nsURI=nsURI,value=value}
			if not current.attr then current.attr = { } end
			push(current.attr,attr)
		end,
		closeElement = function(name)
			if current.name~=name or current.type~="element" then error(utf_format("Received a close element notification for '%s' but was inside a '%s' %s",name,current.name,current.type)) end
			pop(stack)
			current = stack[#stack]
		end,
		text = function(value)
			if current and current.type~='document' then
				if current.type~="element" then error(utf_format("Received a text notification '%s' but was inside a %s",value,current.type)) end
				value = utf_gsub(value, "^[\n%s]-", "")
				value = utf_gsub(value, "[\n%s]-$", "")
				if value ~= "" then
					current.value=value
				end
			end
		end
	}
	builder:parse(xml,{ simple=true })
	return doc
end

FindElement = function(element, name, specialCase)
	if element.kids then
		for k,v in pairs(element.kids) do
			if v.name and v.name == name then
				if specialCase then
					if specialCase.source == "attr" then
						return FindAttibute(v, specialCase.name)
					elseif specialCase.source == "kids" then
						return FindElement(v, specialCase.name)
					end
				else
					if v.value then
						return v.value
					end
				end
			end
		end
	end
end

FindAttibute = function(element, name)
	if element.attr then
		for k,v in pairs(element.attr) do
			if v.name and v.name == name then
				return v.value
			end
		end
	end
end

ParseFeed = function(xml,n)
	local New = { }
	local doc = CreateXML(xml)
	local base = {}
	local elementName
	local parseFields = {}
	for k,v in pairs(doc.root.kids) do
		if v.name == "channel" then --rss
			base = v
			elementName = "item"
			parseFields = RssFields
			break
		elseif v.name == "entry" then --atom
			base = doc.root
			elementName = "entry"
			parseFields = AtomFields
			break
		end
	end
	if not elementName then
		return
	end
	for k,v in pairs(base.kids) do
		local t = {}
		if v.name == elementName then
			for key,tField in ipairs(parseFields) do
				local s = ""
				if tField.show then
					local val = FindElement(v, tField.name, tField.specialCase)
					if val then
						val = Decode(val)
						for i,v in pairs(Rep) do val = utf_gsub(val,i,v) end
						if tSettings.TagFilter then 
							val = utf_gsub(val,"%b<>","") 
						end
						s = s.." "..tField.label..":"..string_rep("\t",tField.tabs)
						if utf_len(val) > tSettings.MaxWidth and tField.name:lower() ~= "link" then
							s = s..utf_sub(val,1,tSettings.MaxWidth).."..."
						else
							s = s..val..""
						end
					end
					if utf_len(s) > 0 then push(t,s) end
				end
			end
		end
		local ChkFld = function(s)
			if next(Negate) then
				for i,v in ipairs(Negate) do
					if utf_find(s,v,1,true) then return false end
				end
			end
			return true
		end
		if next(t) and ChkFld(t[1]) then push(New,t) end
	end
	if next(New) then
		if ListOrder then
			local Tab = {}
			for i = 1, #New do push(Tab,1,New[i]) end
			New = Tab
		end
		local reply,cnt = "",0
		while #New > tSettings.MaxCache do pop(New) end
		local Old = util_loadtable(Feeds[n].filepath)
		for key,val in ipairs(New) do
			local bool = true
			if Old and next(Old) then
				for i,v in ipairs(Old) do if v[2] == val[2] then bool = false break end end
			end
			if bool then
				cnt = cnt + 1
				if cnt <= tSettings.MaxFeeds then
					if tSettings.Simple then
						reply = reply..tostring(key)..". "..utf_gsub(val[1],parseFields[1].label.."%:[^%S]+","")
					else
						for i,v in ipairs(val) do reply = reply.."\t".. utf_gsub(v, "\n+", " " ) .. "\n" end
					end
					reply = reply.."\n"
				end
			end
		end
		if utf_len(reply) > 0 then
			local plural = ""
			if cnt > 1 then plural = "s" end
			SaveFile(Feeds[n].filepath,New,"Old")
			if Old then Old = nil end
			Params["name"] = Feeds[n].host
			Params["count"] = tostring(cnt)
			Params["plural"] = plural
			Params["feed"] = reply

			local txt = formatFeedText()
			return txt
		end
		if Old then Old = nil end
	end
end

GetEncoding = function(xml)
	local temp = utf_match(xml, "^<%?xml%s.-encoding=\"(.-)\".->")
	if temp and utf_len(temp) > 0 then
		return temp:upper()
	else
		return "UTF-8" --UTF-8 is default encoding for XML
	end
end

GetFeed = function(n)
	local st = socket.gettime()
	n = math.min(n,#Feeds)
	if n == 0 then
		return
	end
	local s,fd,sz,hd
	if utf_sub(Feeds[n].url, 1, 5):lower() == "https" then
		--Not possible to set TIMEOUT for HTTPS, yet...
		--https.TIMEOUT = TimeOut
		s,fd,sz,hd = "",https.request(Feeds[n].url)
	else
		http.TIMEOUT = TimeOut
		s,fd,sz,hd = "",http.request(Feeds[n].url)
	end
	if fd and sz and sz == 200 then
		local msg_
		encoding = GetEncoding(fd)
		msg_ = ParseFeed(ToUtf8(fd, encoding), n)
		local td,plural = socket.gettime()-st,(lang.val_part_second or "of a second.")
		if td > 1 then plural = (lang.val_seconds or "seconds.") end
		local time = utf_format("%.2f "..plural,td)

		if msg_ and utf_len(msg_) > 0 then
			if not tSettings.Simple then msg_ = msg_.."\t "..(lang.label_processed_in or "Processed In:").." "..time.."\n\n" end
			if Feeds[n].force then
				if tSettings.ForceFeedPM then
					hub_broadcast(utf_format( Body, msg_ ), Bot, Bot)
				else
					hub_broadcast(utf_format( Body, msg_ ), Bot)
				end
			else
				for i,v in ipairs(Users) do
					local user = hub_isnickonline(v[1])
					if user and v[3] and ((v[4] == nil) or (v[4][n] ~= true)) then
						if v[2] == "p" then
							user:reply(utf_format( Body, msg_ ), Bot, Bot)
						elseif v[2] == "m" then
							user:reply(utf_format( Body, msg_ ), Bot)
						end
					end
				end
			end
		end
	end
end


ChkUsers = function(n)
	for i,v in ipairs(Users) do
		if n:lower() == v[1]:lower() then
			return i
		end
	end
end

FwCmds = {
	feeds = {function(user,data,cmd2,data2,private)
		if user then
			local choice = data
			if choice then
				local t = {["on"] = true,["off"] = {true,false},["m"] = (lang.val_main_chat or "main chat"),["p"] = (lang.val_pm or "private message")}
				if t[choice] then
					local b,save = ChkUsers(user:nick())
					local tab = {["true"] = (lang.val_enabled or "enabled"),["false"] = (lang.val_disabled or "disabled")}
					if not b then
						if choice == "off" then
							return utf_format(lang.msg_feeds_already_disabled or "%s, feeds are already disabled for you.", user:nick()), private
						end
						local channel = "p"
						if choice == "m" then
							channel = "m"

						end
						local mute = { }
						for i=1, #Feeds do
							push(mute, false)
						end
						push(Users,{user:nick(),channel,true,mute})
						save = true
						b = #Users
					else
						if choice == "on" then
							if Users[b][3] then
								return utf_format(lang.msg_feeds_already_enabled or "%s, feeds are already enabled for you and will be sent in %s", user:nick(), t[Users[b][2]]), private
							else
								Users[b][3] = t[choice]
								save = true

							end
						elseif choice == "off" then
							if not Users[b][3] then
								return utf_format(lang.msg_feeds_already_disabled_set or "%s, feeds are already disabled for you and will be sent in %s when enabled.", user:nick(), t[Users[b][2]]), private
							else
								Users[b][3] = t[choice][2]
								save = true

							end
						else
							if Users[b][2] == choice then
								return utf_format(lang.msg_feeds_already_set_type or "%s, feeds are already set for %s and are currently %s", user:nick(), t[choice], tab[tostring(Users[b][3])]), private
							else
								Users[b][2] = choice
								save = true
							end
						end
					end
					if save then
						SaveFile(UserFile,Users,"Users")
					end
					return utf_format(lang.msg_feeds_current or "Feeds are currently %s current message type: %s", tab[tostring(Users[b][3])], t[Users[b][2]]), private
				else
					return utf_format(lang.msg_feeds_error_selection or "**Error in selection. Usage: %s%s <on/off/p/m>", cmd_text, cmd2), private
				end
			else
				return utf_format(lang.msg_feeds_usage_selection or "Error in selection. Usage: %s%s <on/off/p/m>", cmd_text, cmd2), private
			end
		else
			return (lang.desc_feeds or "Set your RSS feed option"),
			(lang.ucmd_feeds_input or " %[line:on=enabled, off= disabled, m=main, p=pm]"),
			(lang.ucmd_feeds_input or " %[line:on=enabled, off= disabled, m=main, p=pm]")
		end
	end,
	{ level = 10 } --min level to use this command
	},
	lastfeed = {function(user,data,cmd2,data2,private)
        if not user then
            return (lang.desc_lastfeed or "Show Last feeds of <Feed number>"),"",""
        end
		if not data then
			return (lang.msg_lastfeed_usage or "Usage: [+!#]rss lastfeed <Feed number>"), private
		end
		local n = data
		if n then
			n = tonumber(n)
		end
		if not n then
			return utf_format(lang.msg_err_invalid_feed_number or "Error! '%s' is not a valid feed number.", data), private
		end

		if n and n > 0 then
			if Feeds[n] then
				local Old = util_loadtable(Feeds[n].filepath)
				if Old and next(Old) then
					local reply,plural,cnt = "","s",#Old
					if cnt == 1 then plural = "" end
					for key,val in ipairs(Old) do
						for i,v in ipairs(val) do reply = reply.."\t"..v.."\n" end
						reply = reply.."\n"
					end
					if reply ~= "" then
						local PM = private
						if not PM then
							PM = tSettings.msgToPM
							local u = ChkUsers(user:nick())
							if u and Users[u][2] then
								if Users[u][2] == "p" then
									PM = true
								elseif Users[u][2] == "m" then
									PM = false
								end
							end
						end
						return "\n\n\t[ "..tostring(cnt).." ] "..(lang.label_cached_feed or "Cached feed")..
						plural.." from: "..Feeds[n].url.."\n\n"..reply.."\n", PM
					end
				else
					return (lang.msg_lastfeed_no_cache or "There are no cached feeds at this time."), private
				end
			else
				return utf_format(lang.msg_err_invalid_feed_number or "Error! '%s' is not a valid feed number.", tostring(n)), private
			end
		else
			return utf_format(lang.msg_err_invalid_feed_number or "Error! '%s' is not a valid feed number.", tostring(n)), private
		end
	end,
	{ level = 10 } --min level to use this command
	},
	listfeeds = {function(user,data,cmd2,data2,private)
		if user then
			if next(Feeds) then
				local reply = ""
				local u = ChkUsers(user:nick())
				for i,v in ipairs(Feeds) do
					local ismuted = ""
					if v.force == false then
						if u and Users[u][4] and Users[u][4][i] then
							ismuted = (lang.msg_listfeeds_muted or " (muted)")
						end
					end
					reply = reply.."\t"..utf_format("[%-2s]    ",i)..v.tag..ismuted.."\n"
				end
				if reply ~= "" then
					local PM = private
					if not PM then
						PM = tSettings.msgToPM
						if u and Users[u][2] then
							if Users[u][2] == "p" then
								PM = true
							elseif Users[u][2] == "m" then
								PM = false
							end
						end
					end
					return (lang.msg_listfeeds_header or "Listing enabled feeds:\n\n")..reply, PM
				end
			else
				return (lang.msg_listfeeds_empty or "Error, There are no feeds set in script."), private
			end
		else
			return (lang.desc_listfeeds or "List Enabled Feeds"),"",""
		end
	end,
	{ level = 10 } --min level to use this command
	},
	listusers = {function(user,data,cmd2,data2,private)
		if user then
			local r = "-"
			local reply,t,c = "\n\n\t"..display_name..(lang.label_listusers_active or " Active Users").."\n\n\t"..string_rep(r,50).."\r\n"..
			"\t"..(lang.label_listusers_nickname or "Nickname").."\t\t"..(lang.label_listusers_msgtype or "Message Type").."\t"..(lang.label_listusers_status or "Status").."\r\n\t"..string_rep(r,50).."\r\n",{},""
			local tab = {["true"] = (lang.val_enabled or "enabled"),["false"] = (lang.val_disabled or "disabled"),
			["m"] = (lang.val_main_chat or "main chat      "),["p"] = (lang.val_pm or "private message")}
			for i,v in ipairs(Users) do
				push(t,"\t"..utf_format("%-30s",v[1]).."\t"..
				tab[v[2]].."\t"..tab[tostring(v[3])].."\r\n")
			end
			table_sort(t, function(a,b)return a < b end)
			c = table.concat(t,"")
			if utf_len(c) > 0 then
				local PM = private
				if not PM then
					PM = tSettings.msgToPM
					local u = ChkUsers(user:nick())
					if u and Users[u][2] then
						if Users[u][2] == "p" then
							PM = true
						elseif Users[u][2] == "m" then
							PM = false
						end
					end
				end
				return reply..c.."\n\t"..string_rep(r,50).."\r\n\r\n", PM
			end
		else
			return (lang.desc_listusers or "List Active Feed Users"),"",""
		end
	end,
	{ level = 10 } --min level to use this command
	},
	feedhelp = {function(user,data,cmd2,data2,private)
		if user then
			local reply,t,c = "\n\n\t"..display_name..(lang.label_feedhelp_header_a or " Command Help").."\n\n\t"..(lang.label_feedhelp_header_b or "Command")..
			"\t\t"..(lang.label_feedhelp_header_c or "Description").."\r\n\t"..string_rep("-",50).."\r\n",{},""
			for i,v in ipairs(Order) do
				local desc,args = FwCmds[v][1]()
				if user:level() >= FwCmds[v][2]["level"] then
					push(t,"\t"..cmd_text..v.."\t"..desc.."\r\n")
				end
			end
			if not t then
				return msg_denied, private
			end
			table_sort(t, function(a,b)return a < b end)
			for i,v in ipairs(t) do
				c = c..v
			end
			if utf_len(c) > 0 then
				local PM = private
				if not PM then
					PM = tSettings.msgToPM
					local u = ChkUsers(user:nick())
					if u and Users[u][2] then
						if Users[u][2] == "p" then
							PM = true
						elseif Users[u][2] == "m" then
							PM = false
						end
					end
				end
				return reply..c.."\n\t"..string_rep("-",50).."\r\n\r\n", PM
			end
		else
			return display_name..(lang.desc_feedhelp or " Help"),"",""
		end
	end,
	{ level = 10 } --min level to use this command

	},
	addfeed = {function(user,data,cmd2,data2,private)
		if user then
			if (not data) or (not data2) then
				return (lang.msg_addfeed_usage or "Usage: [+!#]rss addfeed <Url> <Tag>"), private
			end
			for i,v in ipairs(Feeds) do
				if v.url == data then
					return utf_format(lang.msg_addfeed_dup_url or "Feed with url %s already exists.", data), private
				end
				if v.tag == data2 then
					return utf_format(lang.msg_addfeed_dup_tag or "Feed with tag %s already exists.", data2), private
				end
			end
			local host = data2 or utf_gsub(utf_gsub(data, "^[hftps:]+[/]+", ""), "/.*$", "") or "unavailable"
			local newFeed = { url=data, tag=data2, force=false, filepath = Path..utf_gsub(utf_gsub(data, "^[hftps:]+[/]+", ""), "[%c%p]", "_")..".tbl" }
			if host and host ~= "" then newFeed.host = host end
			push(Feeds, newFeed)
			SaveFeed()
			if not fileExists(newFeed.filepath) then
				local Old = {}
				SaveFile(newFeed.filepath,Old,"Old")
			end
			for i,v in ipairs(Users) do
				if v[4] then
					push(v[4], false)
				else
					local mute = { }
					for i=1, #Feeds do
						push(mute, false)
					end
					v[4] = mute
				end
			end
			SaveFile(UserFile,Users,"Users")
			return (lang.msg_addfeed_ok or "New feed added."), private
		else
			return (lang.desc_addfeed or "Add new RSS feed <Url> <Tag>"),
			"",
			""
		end
	end,
	{ level = 60 } --min level to use this command

	},
	forcefeed = {function(user,data,cmd2,data2,private)
		if user then
			if not data then
				return (lang.msg_forcefeed_usage or "Usage: [+!#]rss forcefeed <Feed number>"), private
			end
			local n = data
			if n then
				n = tonumber(n)
			end
			if not n then
				return utf_format(lang.msg_err_invalid_feed_number or "Error! '%s' is not a valid feed number.", data), private
			end

			if n and n > 0 then
				if Feeds[n] then
					local reply
					local tab = {["true"] = (lang.val_enabled or "enabled"),["false"] = (lang.val_disabled or "disabled")}
					Feeds[n].force = not Feeds[n].force
					reply = utf_format(lang.msg_forcefeed_set or "ForceFeed is now %s for %s (%s).", tab[tostring(Feeds[n].force)], Feeds[n].tag, tostring(n))
					SaveFeed()
					return reply, private
				else
					return utf_format(lang.msg_err_invalid_feed_number or "Error! '%s' is not a valid feed number.", tostring(n)), private
				end
			else
				return utf_format(lang.msg_err_invalid_feed_number or "Error! '%s' is not a valid feed number.", tostring(n)), private
			end
		else
			return (lang.desc_forcefeed or "Toggle force feed on <Feed number>"),
			"",
			""
		end
	end,
	{ level = 60 } --min level to use this command

	},
	delfeed = {function(user,data,cmd2,data2,private)
		if user then
			if not data then
				return (lang.msg_delfeed_usage or "Usage: [+!#]rss delfeed <Feed number>"), private
			end
			local n = data
			if n then
				n = tonumber(n)
			end
			if not n or n < 1 then
				return utf_format(lang.msg_err_invalid_feed_number or "Error! '%s' is not a valid feed number.", data), private
			end

			if Feeds[n] then
				local del = pop(Feeds, n)
				SaveFeed()
				if del and del.filepath and fileExists(del.filepath) then
					delete(del.filepath)
				end
				if StartFeed == n then
					StartFeed = 1
				elseif StartFeed > n then
					StartFeed = StartFeed - 1
				end
				for i,v in ipairs(Users) do
					if v[4] then
						pop(v[4], n)
					else
						local mute = { }
						for i=1, #Feeds do
							push(mute, false)
						end
						v[4] = mute
					end
				end
				SaveFile(UserFile,Users,"Users")

				return utf_format(lang.msg_delfeed_ok or "%s (%s) is now deleted.", del.tag, tostring(n)), private
			else
				return utf_format(lang.msg_err_invalid_feed_number or "Error! '%s' is not a valid feed number.", tostring(n)), private
			end
		else
			return (lang.desc_delfeed or "Delete feed <Feed number>"),
			"",
			""
		end
	end,
	{ level = 60 } --min level to use this command

	},
	refresh = {function(user,data,cmd2,data2,private)
		if user then
			if not data then
				return (lang.msg_refresh_usage or "Usage: [+!#]rss refresh <Minutes>"), private
			end
			local n = data
			if n then
				n = tonumber(n)
			end
			if not n or n < 2 then
				return utf_format(lang.msg_err_invalid_minutes or "Error! '%s' is not a valid number of minutes.", data), private
			end
			tSettings.Refresh = n
			SaveFile(SettingsFile, tSettings, "tSettings")
			return utf_format(lang.msg_refresh_set or "Refresh time is now %s minutes.", tostring(n)), private
		else
			return (lang.desc_refresh or "Set feed refresh time <Minutes>"),
			"",
			""
		end
	end,
	{ level = 60 } --min level to use this command

	},
	getfeed = {function(user,data,cmd2,data2,private)
		if user then
			local n = data
			if n then
				n = tonumber(n)
			end
			if n then
				if Feeds[n] then
					TriggerGetFeed(n)
				else
					return utf_format(lang.msg_err_invalid_feed_number or "Error! '%s' is not a valid feed number.", tostring(n)), private
				end
			else
				TriggerGetFeed()
			end
			return nil
		else
			if tSettings.allFeedsAtOnce then
				return (lang.desc_getfeed_all or "Get all feeds now."),
				"",
				""
			else
				return (lang.desc_getfeed_next or "Get next feed now."),
				"",
				""
			end
		end
	end,
	{ level = 60 } --min level to use this command

	},
	mutefeed = {function(user,data,cmd2,data2,private)
		if user then
			if not data then
				return (lang.msg_mutefeed_usage or "Usage: [+!#]rss mutefeed <Feed number>"), private
			end
			local n = data
			if n then
				n = tonumber(n)
			end
			if not n then
				return utf_format(lang.msg_err_invalid_feed_number or "Error! '%s' is not a valid feed number.", data), private
			end

			if n and n > 0 then
				if Feeds[n] then
					if Feeds[n].force then
						return utf_format(lang.msg_mutefeed_forced or "Feed %s (%s) is forced and can't be muted.", Feeds[n].tag, tostring(n)), private
					end
					local u = ChkUsers(user:nick())
					if u then
						local tab = {["true"] = (lang.val_muted or "muted"),["false"] = (lang.val_showing or "showing")}
						if Users[u][4] == nil then
							local mute = { }
							for i=1, #Feeds do
								push(mute, i == n)
							end
							Users[u][4] = mute
						else
							Users[u][4][n] = not Users[u][4][n]
						end
						local reply = utf_format(lang.msg_mutefeed_set or "Feed %s (%s) is now %s.", Feeds[n].tag, tostring(n), tab[tostring(Users[u][4][n])])
						SaveFile(UserFile,Users,"Users")
						return reply, private
					else
						return (lang.msg_mutefeed_setup or "Set feed settings first."), private
					end
				else
					return utf_format(lang.msg_err_invalid_feed_number or "Error! '%s' is not a valid feed number.", tostring(n)), private
				end
			else
				return utf_format(lang.msg_err_invalid_feed_number or "Error! '%s' is not a valid feed number.", tostring(n)), private
			end
		else
			return (lang.desc_mutefeed or "Mute/Unmute a Feed <Feed number>"),"",""
		end
	end,
	{ level = 10 } --min level to use this command
	},
	maxfeeds = {function(user,data,cmd2,data2,private)
		if user then
			if not data then
				return (lang.msg_maxfeeds_usage or "Usage: [+!#]rss maxfeeds <Number of Feeds>"), private
			end
			local n = data
			if n then
				n = tonumber(n)
			end
			if not n or n < 1 then
				return utf_format(lang.msg_err_invalid_feed_count or "Error! '%s' is not a valid number of feeds.", data), private
			end
			tSettings.MaxFeeds = n
			if n > tSettings.MaxCache then
				tSettings.MaxCache = n
			end
			SaveFile(SettingsFile, tSettings, "tSettings")
			return utf_format(lang.msg_maxfeeds_set or "Max feeds is now %s.", tostring(n)), private
		else
			return (lang.desc_maxfeeds or "Set max feeds to show <Number of Feeds>"),
			"",
			""
		end
	end,
	{ level = 60 } --min level to use this command

	},
	maxcache = {function(user,data,cmd2,data2,private)
		if user then
			if not data then
				return (lang.msg_maxcache_usage or "Usage: [+!#]rss maxcache <Number of Feeds>"), private
			end
			local n = data
			if n then
				n = tonumber(n)
			end
			if not n or n < 1 then
				return utf_format(lang.msg_err_invalid_feed_count or "Error! '%s' is not a valid number of feeds.", data), private
			end
			tSettings.MaxCache = n
			if n < tSettings.MaxFeeds then
				tSettings.MaxFeeds = n
			end
			SaveFile(SettingsFile, tSettings, "tSettings")
			return utf_format(lang.msg_maxcache_set or "Max cache is now %s.", tostring(n)), private
		else
			return (lang.desc_maxcache or "Set max feeds to cache <Number of Feeds>"),
			"",
			""
		end
	end,
	{ level = 60 } --min level to use this command

	},
	maxwidth = {function(user,data,cmd2,data2,private)
		if user then
			if not data then
				return (lang.msg_maxwidth_usage or "Usage: [+!#]rss maxwidth <Number of Characters>"), private
			end
			local n = data
			if n then
				n = tonumber(n)
			end
			if not n or n < 1 then
				return utf_format(lang.msg_err_invalid_char_count or "Error! '%s' is not a valid number of characters.", data), private
			end
			tSettings.MaxWidth = n
			SaveFile(SettingsFile, tSettings, "tSettings")
			return utf_format(lang.msg_maxwidth_set or "Max width is now %s characters.", tostring(n)), private
		else
			return (lang.desc_maxwidth or "Set max characters to show <Number of Characters>"),
			"",
			""
		end
	end,
	{ level = 60 } --min level to use this command

	},	focefeedpm = {function(user,data,cmd2,data2,private)
		if user then
			local tab = {["true"] = (lang.val_pm_short or "PM"),["false"] = (lang.val_main_short or "Main")}
			tSettings.ForceFeedPM = not tSettings.ForceFeedPM
			SaveFile(SettingsFile, tSettings, "tSettings")
			return utf_format(lang.msg_focefeedpm_set or "Forced feeds are now showing in %s.", tab[ tostring(tSettings.ForceFeedPM) ]), private
		else
			return (lang.desc_focefeedpm or "Toggle forced feeds to PM or Main"),
			"",
			""
		end
	end,
	{ level = 60 } --min level to use this command

	},
	msgtopm = {function(user,data,cmd2,data2,private)
		if user then
			local tab = {["true"] = (lang.val_pm_short or "PM"),["false"] = (lang.val_main_short or "Main")}
			tSettings.msgToPM = not tSettings.msgToPM
			SaveFile(SettingsFile, tSettings, "tSettings")
			return utf_format(lang.msg_msgtopm_set or "Messages are now showing in %s.", tab[ tostring(tSettings.ForceFeedPM) ]), private
		else
			return (lang.desc_msgtopm or "Toggle messages to PM or Main"),
			"",
			""
		end
	end,
	{ level = 60 } --min level to use this command

	},
	simple = {function(user,data,cmd2,data2,private)
		if user then
			local tab = {["true"] = (lang.val_on_short or "on"),["false"] = (lang.val_off_short or "off")}
			tSettings.Simple = not tSettings.Simple
			SaveFile(SettingsFile, tSettings, "tSettings")
			return utf_format(lang.msg_simple_set or "Simple layout in now %s.", tab[ tostring(tSettings.Simple) ]), private
		else
			return (lang.desc_simple or "Toggle simple feed layout"),
			"",
			""
		end
	end,
	{ level = 60 } --min level to use this command

	},
	settings = {function(user,data,cmd2,data2,private)
		if user then
			local reply,c = "\n\n\t"..display_name..(lang.label_settings_header or " Settings").."\n\n\t"..(lang.label_settings_setting or "Setting:").."  "..
			(lang.label_settings_value or "Value").."\r\n\t"..string_rep("-",50).."\r\n",""
			for k,v in pairs(tSettings) do
				c = c.."\t"..k..":  "..tostring(v).."\r\n"
			end
			if utf_len(c) > 0 then
				local PM = private
				if not PM then
					PM = tSettings.msgToPM
					local u = ChkUsers(user:nick())
					if u and Users[u][2] then
						if Users[u][2] == "p" then
							PM = true
						elseif Users[u][2] == "m" then
							PM = false
						end
					end
				end
				return reply..c.."\n\t"..string_rep("-",50).."\r\n\r\n", PM
			end
		else
			return display_name..(lang.desc_settings or " Settings"),"",""
		end
	end,
	{ level = 60 } --min level to use this command

	},
}

SaveFile = function(fileN,table, tablename )
	util_savetable(table, tablename, fileN)
end

SaveFeed = function()
	local tmp = {}
	for i,v in ipairs(Feeds) do
		push(tmp, { url=v.url, tag=v.tag, force=v.force })
	end
	SaveFile(FeedsFile,tmp,"Feeds")
end

local cmdRSS = function( user, command, parameters, private )
	local user_level = user:level()
	if user_level < minlevel then
		user:reply( msg_denied, Bot )
		return PROCESSED
	end
	
	if not parameters then
		if private then
			user:reply(msg_usage, Bot, Bot )
		else
			user:reply(msg_usage, Bot )
		end
		return PROCESSED
	end

	local subCmd = utf_match( parameters, "^(%S+)" )
	local data = utf_match( parameters, "^%a+ (%S+)" )
	local data2 = utf_match( parameters, "^%a+ %S+%s(%S+)" )

	if subCmd and FwCmds[subCmd] then
		if user:level() >= FwCmds[subCmd][2]["level"] then
			local msg, PM = FwCmds[subCmd][1](user,data,subCmd,data2,private)
			if msg and utf_len(msg) > 0 then
				if PM then
					user:reply(msg, Bot, Bot )
				else
					user:reply(msg, Bot )
				end
			end
		else
			if private then
				user:reply( msg_denied, Bot, Bot )
			else
				user:reply( msg_denied, Bot )
			end
			return PROCESSED
		end
	else
		if private then
			user:reply(msg_usage, Bot, Bot )
		else
			user:reply(msg_usage, Bot )
		end
		return PROCESSED
	end

	return PROCESSED
end

local oncmdRSS = function( user, command, parameters )
	return cmdRSS( user, command, parameters, false )
end

hub.setlistener( "onPrivateMessage", {},
	function( user, targetuser, adccmd, msg )
		if msg then
			if targetuser == Bot then
				local cmd
				if utf_match( msg, "^[+!#](%S+)" ) == "rss" then
					cmd = utf_match( msg, "^[+!#]%S+%s(.+)" )
				else
					cmd = utf_match( msg, "^[+!#](.+)" )
				end
				return cmdRSS(user, nil, cmd, true)
			end
		end
		return nil
	end
)

TriggerGetFeed = function(n)
	StartTime = os_time()
	if #Feeds > 0 then
		if n and n > 0 and n <= #Feeds then
			GetFeed(n)
		else
			if tSettings.allFeedsAtOnce then
				for n,v in ipairs(Feeds) do
					GetFeed(n)
				end
			else
				if StartFeed > #Feeds then StartFeed = 1 end
				GetFeed(StartFeed)
				StartFeed = StartFeed + 1
			end
		end
	end
end

hub.setlistener( "onTimer", {},
	function()
		if StartTime and (os_time() - StartTime) >= tSettings.Refresh*60 then
			TriggerGetFeed()
		end
		return nil
	end
)

local checkValue = function(value, default, valueType)
	if type(value) ~= valueType or value == nil then
		return default, true
	else
		return value, false
	end
end

local checkSettings = function(tbl)
	local save = false
	tbl.Refresh, save = checkValue(tbl.Refresh, tSettings.Refresh, "number")
	tbl.allFeedsAtOnce, save = checkValue(tbl.allFeedsAtOnce, tSettings.allFeedsAtOnce, "boolean")
	tbl.MaxFeeds, save = checkValue(tbl.MaxFeeds, tSettings.MaxFeeds, "number")
	tbl.MaxCache, save = checkValue(tbl.MaxCache, tSettings.MaxCache, "number")
	tbl.MaxWidth, save = checkValue(tbl.MaxWidth, tSettings.MaxWidth, "number")
	tbl.ForceFeedPM, save = checkValue(tbl.ForceFeedPM, tSettings.ForceFeedPM, "boolean")
	tbl.GetFeedAtStart, save = checkValue(tbl.GetFeedAtStart, tSettings.GetFeedAtStart, "boolean")
	tbl.TagFilter, save = checkValue(tbl.TagFilter, tSettings.TagFilter, "boolean")
	tbl.Simple, save = checkValue(tbl.Simple, tSettings.Simple, "boolean")
	tbl.msgToPM, save = checkValue(tbl.msgToPM, tSettings.msgToPM, "boolean")
	if tbl.MaxFeeds > tbl.MaxCache then
		tbl.MaxFeeds = tbl.MaxCache
		save = true
	end
	if not tbl.Refresh or tbl.Refresh < 2 then
		tbl.Refresh = 2
		save = true
	end
	
	return tbl, save
end

hub.setlistener( "onStart", { },
	function( )
		StartTime = os_time()
		Bot = hub.regbot( { nick=BotName, desc=BotDescription, client = function( bot, cmd ) return true end } )
		local save
		if not fileExists(SettingsFile) then
			tSettings.Refresh = math.max(tSettings.Refresh,2)
			tSettings.MaxFeeds = math.min(tSettings.MaxFeeds,tSettings.MaxCache)
			SaveFile(SettingsFile, tSettings, "tSettings")
		else
			local temp = util_loadtable( SettingsFile )
			tSettings, save = checkSettings(temp)
			if save then
				SaveFile(SettingsFile, tSettings, "tSettings")
			end
		end
		if StartFeed > #Feeds then StartFeed = 1 end
		TimeOut = math.min(TimeOut,60)

		for i,v in ipairs(Feeds) do
			local host = Feeds[i].tag or utf_gsub(utf_gsub(Feeds[i].url, "^[hftps:]+[/]+", ""), "/.*$", "") or "unavailable"
			Feeds[i].filepath = Path..utf_gsub(utf_gsub(Feeds[i].url, "^[hftps:]+[/]+", ""), "[%c%p]", "_")..".tbl"
			if host and host ~= "" then Feeds[i].host = host end
		end
		for n,v in ipairs(Feeds) do
			if not fileExists(v.filepath) then
				local Old = {}
				SaveFile(v.filepath,Old,"Old")
			end
		end

		save = false
		for i,v in ipairs(Users) do
			if v[4] == nil then
				local mute = { }
				for i=1, #Feeds do
					push(mute, false)
				end
				v[4] = mute
				save = true
			end
		end
		if save then
			SaveFile(UserFile,Users,"Users")
		end

		ucmd = hub.import "etc_usercommands"    -- add usercommand
		if ucmd then
			local _in_feeds   = "%[line:"..(lang.ucmd_input_feeds       or " on/off/m/p").."]"
			local _in_fnum    = "%[line:"..(lang.ucmd_input_feed_number or " Feed Number ").."]"
			local _in_url     = "%[line:"..(lang.ucmd_input_url         or " Url ").."]"
			local _in_tag     = "%[line:"..(lang.ucmd_input_tag         or " Tag ").."]"
			local _in_mins    = "%[line:"..(lang.ucmd_input_minutes     or " Number of Minutes ").."]"
			local _in_nfeeds  = "%[line:"..(lang.ucmd_input_num_feeds   or " Number of Feeds ").."]"
			local _in_nchars  = "%[line:"..(lang.ucmd_input_num_chars   or " Number of Characters ").."]"
			local _in_get_pfx = lang.ucmd_input_getfeed_prefix or " Feed Number, empy for "
			ucmd.add( ucmd_menu_help, cmd, {"feedhelp" }, { "CT1" }, FwCmds["feedhelp"][2]["level"] )
			ucmd.add( ucmd_menu_feeds, cmd, {"feeds", _in_feeds }, { "CT1" }, FwCmds["feeds"][2]["level"] )
			ucmd.add( ucmd_menu_lastfeed, cmd, {"lastfeed", _in_fnum }, { "CT1" }, FwCmds["lastfeed"][2]["level"] )
			ucmd.add( ucmd_menu_listusers, cmd, {"listusers" }, { "CT1" }, FwCmds["listusers"][2]["level"] )
			ucmd.add( ucmd_menu_listfeeds, cmd, {"listfeeds" }, { "CT1" }, FwCmds["listfeeds"][2]["level"] )
			ucmd.add( ucmd_menu_addfeed, cmd, {"addfeed", _in_url, _in_tag }, { "CT1" }, FwCmds["addfeed"][2]["level"] )
			ucmd.add( ucmd_menu_forcefeed, cmd, {"forcefeed", _in_fnum }, { "CT1" }, FwCmds["forcefeed"][2]["level"] )
			ucmd.add( ucmd_menu_deletefeed, cmd, {"delfeed", _in_fnum }, { "CT1" }, FwCmds["delfeed"][2]["level"] )
			local AllNext = (lang.label_get_next_feed or "next feed")
			if tSettings.allFeedsAtOnce then
				AllNext = (lang.label_get_all_feeds or "all feeds")
			end
			ucmd.add( ucmd_menu_getfeed, cmd, {"getfeed", "%[line:".._in_get_pfx..AllNext.." ]" }, { "CT1" }, FwCmds["getfeed"][2]["level"] )
			ucmd.add( ucmd_menu_mutefeed, cmd, {"mutefeed", _in_fnum }, { "CT1" }, FwCmds["mutefeed"][2]["level"] )
			--Settings
			ucmd.add( ucmd_menu_refresh, cmd, {"refresh", _in_mins }, { "CT1" }, FwCmds["refresh"][2]["level"] )
			ucmd.add( ucmd_menu_maxfeeds, cmd, {"maxfeeds", _in_nfeeds }, { "CT1" }, FwCmds["maxfeeds"][2]["level"] )
			ucmd.add( ucmd_menu_maxcache, cmd, {"maxcache", _in_nfeeds }, { "CT1" }, FwCmds["maxcache"][2]["level"] )
			ucmd.add( ucmd_menu_maxwidth, cmd, {"maxwidth", _in_nchars }, { "CT1" }, FwCmds["maxwidth"][2]["level"] )
			ucmd.add( ucmd_menu_focefeedpm, cmd, {"focefeedpm" }, { "CT1" }, FwCmds["focefeedpm"][2]["level"] )
			ucmd.add( ucmd_menu_msgtopm, cmd, {"msgtopm" }, { "CT1" }, FwCmds["msgtopm"][2]["level"] )
			ucmd.add( ucmd_menu_simple, cmd, {"simple" }, { "CT1" }, FwCmds["simple"][2]["level"] )
			ucmd.add( ucmd_menu_settings, cmd, {"settings" }, { "CT1" }, FwCmds["settings"][2]["level"] )
		end
		hubcmd = hub_import( "etc_hubcommands" )    -- add hubcommand
		assert( hubcmd )
		assert( hubcmd.add( cmd, oncmdRSS ) )

		if tSettings.GetFeedAtStart and #Feeds > 0 then
			if tSettings.allFeedsAtOnce then
				for n,v in ipairs(Feeds) do
					GetFeed(n)
				end
			else
				GetFeed(StartFeed)
			end
		end
		return nil
	end
)

hub_debug( "** Loaded " .. scriptname .. " " .. scriptversion .. " **" )
# Upstream `luadch/scripts` open-issue dump

Snapshot of all open issues on https://github.com/luadch/scripts as of
2026-05-05. Used during the import pass to map known bugs to the
scripts being ported. Detailed triage (which to fix during import,
which to file fresh against this repo, which to mark wontfix) is
done in the relevant import PRs.

---

## #41: cmd_pm2offliners.lua - should the settings really be in the core/cfg.lua file?

Why is the settings for `cmd_pm2offliners.lua` moved here?

https://github.com/luadch/luadch/blob/f048b4b330b3bc708d9163d4f03b7fec229f6655/core/cfg.lua#L1644

If the hubowner want to change the min level he need to edit this file and is that something you recommend him to do?

Files in the core folder are not files you should edit manual.

---

## #40: etc_requests.lua - When delete a request make it possible to announce it in main/pm

When deleting a request it will only be visible to the OP that has deleted the request.

If a user requests an invalid request, it should be possible to announce the reason for deleting the request in main or maybe even to the user that has requested it, to let the user know it was an invalid request.

---

## #39: ptx_freshstuff - add a separator

When new stuff get announced it can sometimes be hard to see what is new if new stuff get sent to a PM window.

So, it would be very helpful if there could be a separator between the announces to make it easier to see the latest announced stuff.

The separator should not be added between every stuff it announce. If nothing new has been announced for 10 minutes a separator should be added with date and time. This make it much easier to see the latest stuff that have been announced.

---

## #38: etc_requests.lua - Showing min level when it is using true/false

If i run `+help` the hub will show available command.

The request script will show:
Description:	a script to request / fill releases
Min. Level:	20

But it doesn't have a min level anymore because it is using true/false
    [ 0 ]  = false, -- unreg
    [ 10 ] = false, -- guest
    [ 20 ] = true, -- reg
    [ 30 ] = true, -- vip
    [ 40 ] = true, -- svip
    [ 50 ] = true, -- server
    [ 55 ] = false,  -- sbot
    [ 60 ] = true, -- operator
    [ 70 ] = true, -- supervisor
    [ 80 ] = true, -- admin
    [ 100 ] = true, -- hubowner



---

## #36: Missing [CHAT]Requests opt-out functionality (pulsar's etc_requests.lua)

As of today, the latest build of [etc_requests.lua (v0.8)](https://github.com/luadch/scripts/blob/master/zip/etc_requests_v0.8%20(multi).7z) does not seem to include the ability for users to opt-out of receiving [CHAT]Requests bot activity, despite the changelog mentioning "chat is optional (opt out)".
It would be very helpful if the script allowed users to simply control their participation via commands like +reqchatoff, +reqchaton and control their opt-in/out status via right-click menu too.

I've seen pulsar active on this repo and I hope he will consider implementing this functionality:

---

## #35: ptx_RSSFeedWatch issues

when set to hide links when post rss feed, scritp stop posting new feeds.

when this set to - false

	[2] = {name="link", label="Link", tabs=2, show=**false**, },

---

## #34: Prevent Level XX to login until Hubowner allows it

When testing and doing stuff with Luadch you sometimes don't want users to login until you are finished.

So, before i shutdown/restart the hub i run a command that will only allow a certain level to login after the restart:
`+lockhub 80`

When the hub is up and running again as it should, i can let all the users in again:
`+unlock`

---

## #30: cmd_pm2offliners.lua - no minlevel or oplevel

When cmd_pm2offliners.lua was removed from cfg.tbl it is no longer possible to set any restrictions.
```
    cmd_pm2offliners_minlevel = 60,  -- min level to use this command? (integer)
    cmd_pm2offliners_oplevel = 100,  -- min level to delete the message database? (integer)
    cmd_pm2offliners_delay = 7,  -- how many seconds after login before send? (integer)
    cmd_pm2offliners_advanced_rc = false,  -- warning: this feature adds a complete list of all regusers to the rightclick, this could brings problems in bigger (60+) hubs!
```

---

## #28: Add search flood protection

I have seen that other hubsoft's have a protection against search flood, but Luadch has nothing. A user can search how often they want.

AirDC even has an option for it `Minimum search interval`, so you can match the search interval against the hubsoft.

If the hub has 10 seconds between a search you set `Minimum search interval` to 10, to avoid getting warnings.

---

## #26: etc_ccpmblocker.lua - doesn't block all users from using CCPM

It seems that not all users get blocked with this script. It is not working to 100 percent. I have tried to find the reason, but so far i haven't found out when and why. 

When i test to connect to both active and passive users it seems that there is a higher success rate to connect with CCPM if the user is connected as a passive user.

In a hub with 300-400 users i was able to established CCPM to 12 to 15 users, most of them was connected in passive mode.

I know that only one hub that allows CCPM is enough to established a CCPM connection. We only had one common hub.

---

## #22: Load categories on timer - WhenAndWhatToShow and one additional question

I get  "Command incomplete" as a response when I try to enter "all" for the parameter:
["12:34"] = "all",

I'm no coder or so, but I did find some entries about this command:
`elseif FreshStuff.WhenAndWhatToShow[ os.date( "%H:%N" ) ] == "all" then`
`FreshStuff.Broadcast( FreshStuff.MsgAll, botname() )`
On line  703-704, I think.

What happens from there I don't know.
Did find a line that was remarked, but at the time writing this, I don't remember which one.
I did remove this remark,  but no change.

And, one additional question, since there's no documentation about this script to speak of, but how do I issue a command, like "!prunerel", preferably in the same area as the timing for releases? Have I missed any such function in the script file?

Thanks.

---

## #25: spamprotection.lua - spam protection for main and PM

Luadch doesn't have any spam protection in main or PM. Users can send how many lines and chars they want. They can also send the same message over and over again (there are working scripts to stop repeated messages), but if you create a new script why not include this too :)

---

## #24: opchat, regchat history incorrect

Hi,

It seems in opchat and regchat scripts the message gets written to history log before checking permission. so the history does not show correct output.

---

## #29: Can't send offline PM even if the user is offline

Something is wrong with the `PM to Offliner`. Even if the user is offline i can't send any messages. I only get this message: `User is already online.` It takes a long time (hours?) before i can send an offline PM to a user that recently has been online.

This `PM to Offliner` should need an update so if the user is online (for real) it should send it as a PM. It sometimes happen that the user you write to will connect before you send the message and if that happens you have to type the whole message again :(

To get it to work again i need to do a `+reload`. This is the only work-a-round i have found.

---

## #19: etc_onlinecounter_v1.4 (english)

Hello, i'm newbie and have a question about this script. When is updating Total online time? For a few days I see that the Session time at "etc_onlinecounter.tbl" is updated, but the Total time is 0 constant:

[ "SessionTime" ] = 562,
[ "TotalTime" ] = 0,

When i use RC ... [command] +onlinecounter toponline i recive this in main chat:
[09:03:09] <[BOT]HubSecurity> *** Error: Only 0 users in table, 1 is too high!
When I use an RC on a username, it always tells me this:

[2019-06-02 09:15] <[BOT]HubSecurity> 

	========================================
			Stats:
	--------------------------------------------------------------------------------
	- Nick: Jetion
	- Total uptime: 0 minutes

I stop the Hub, deleted (and then put them back in their original first state at the same place) and started from the scratch both files: "etc_onlinecounter.tbl" and "usr_uptime.tbl", but the result is the same. I can not understand, am I wrong in the settings or elsewhere is the problem? Sorry, my question may be stupid, but I would be grateful if anyone could explain me in more detail about this script and how to use it. 
Thanks in advance!




---

## #18: ptx_freshstuff - delete release by name

This script need to be able to delete a release by name and not only by ID#.

---

## #5: etc_mainecho.lua - trigger when the output is from the hub bot

This script will trigger not only from the users, it will trigger when it is from the hub bot too. Could it be fixed?

---

## #33: make it possible to schedule a restart

Make it possible to schedule a restart. So it is possible to schedule it once, every day, week, month or year.

---

## #1: etc_eventannouncer.lua - attempt to concatenate local 's'

I only have one announce date and this happens when that date has past. I get into a loop and i get this in the error log every second
```
scripts.lua: script error: ././scripts/etc_eventannouncer.lua:166: attempt to concatenate local 's' (a nil value) (listener: onTimer; script: 'etc_eventannouncer.lua')
```

---


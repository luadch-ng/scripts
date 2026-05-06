# luadch/scripts upstream-issue triage sweep

Working notes from the post-import upstream-issue triage. The 19 open
issues at <https://github.com/luadch/scripts/issues> as of 2026-05-05
were mapped to specific imported plugins during the import phase
(see [`IMPORT_NOTES.md`](IMPORT_NOTES.md)). This doc tracks how each
mapped issue is handled in this fork.

Analogous to the two
[`luadch-ng/luadch` interlude triage docs](https://github.com/luadch-ng/luadch/blob/master/docs/phases/INTERLUDE_UPSTREAM_TRIAGE_2.md):
read before starting another triage round so we don't re-discover
already-decided items.

## Status legend

- **Fixed**: PR merged in this repo, original-repo issue closeable
- **Won't fix**: design / out-of-scope decision recorded
- **Already addressed**: caught during import or by hub-side work
- **Deferred**: real bug, but needs more design / clean repro

## Triage status

**All 19 mapped upstream issues triaged.** See per-plugin sections
below for the per-issue disposition. Roll-up:

| Plugin | Issue(s) | Disposition |
|---|---|---|
| etc_EventAnnouncer | #1 | Fixed (PR #13) |
| cmd_pm2offliners | #29, #30, #41 | Already addressed (PR #14) |
| etc_mainecho | #5 | Fixed defensively (PR #15) |
| etc_onlinecounter | #19 | Fixed (PR #16) |
| etc_requests | #38 | Fixed (PR #17) |
| etc_requests | #40 | Already addressed + feature deferred (PR #17) |
| etc_requests | #36 | Feature deferred (PR #17) |
| ptx_freshstuff | #22, #18, #39 | Fixed (PR #18) |
| etc_ccpmblocker | #26 | Won't fix - protocol limit (PR #19) |

The five general / unmapped upstream issues from the import-pass
([#28 search flood, #34 level-XX login gate, #33 schedule restart,
#25 spam protection, #24 opchat history]) belong to hub-core scope
or are feature requests that don't have a single home plugin; not
addressed in this sweep.

---

## cmd_pm2offliners

All three open upstream issues are **already addressed** by the
luadch-ng modernisation; no script-side code change needed. Doc-only
triage entry.

### luadch/scripts#29 - Can't send offline PM even if the user is offline

**Status:** Already addressed (hub-side reliability).

**Symptom (upstream):** "User is already online." reply on `+pm add`
even when the user is offline. Workaround: `+reload`. Hours-long
delay before working again.

**Root cause (upstream):** The script gates the add via
`profile.is_online == 0` (`cmd_pm2offliners.lua:170`). The upstream
hub didn't reliably clear `profile.is_online` on every disconnect
path - particularly abnormal TCP disconnects could leave the flag
stuck at 1 indefinitely. `+reload` rebuilt `_regusers` from disk,
zeroing the flag.

**Why already addressed in luadch-ng v3.1.x:** Our hub clears
`profile.is_online = 0` synchronously at the canonical disconnect
path (`core/hub.lua:1296`) alongside `_usernicks[nick] = nil`
(`core/hub.lua:1051`). Both run as part of the same disconnect
function so they stay in sync. Abnormal TCP disconnects detected by
the socket layer in `core/server.lua` propagate to the same
disconnect function, so the "stuck flag" upstream symptom can't
recur. No script change needed; the `profile.is_online == 0` check
is reliable here.

### luadch/scripts#30 - cmd_pm2offliners.lua - no minlevel or oplevel

**Status:** Already addressed (Phase 6c-1 cfg layout).

**Symptom (upstream):** "When cmd_pm2offliners.lua was removed from
cfg.tbl it is no longer possible to set any restrictions." The four
settings (`cmd_pm2offliners_minlevel`, `_oplevel`, `_delay`,
`_advanced_rc`) had no defaults in the upstream layout.

**Why already addressed in luadch-ng v3.1.x:** Phase 6c-1
(luadch-ng/luadch PR #41) extracted all `_defaultsettings` out of
`core/cfg.lua` into a dedicated `core/cfg_defaults.lua`. The four
`cmd_pm2offliners_*` keys ship there with sane defaults (minlevel=30,
oplevel=100, delay=7, advanced_rc=false). `cfg.get(key)` falls back to
`_defaultsettings[key][1]` when the operator's `cfg/cfg.tbl` doesn't
override - same convention as every other cfg-aware plugin. Operators
who want different values add the keys to `cfg/cfg.tbl`; no
core-file edits required.

### luadch/scripts#41 - settings really be in core/cfg.lua?

**Status:** Already addressed (Phase 6c-1 cfg layout).

**Symptom (upstream):** "Files in the core folder are not files you
should edit manual." The upstream luadch had the cmd_pm2offliners
defaults inlined in `core/cfg.lua`, which is core code; operators
who wanted different values had to edit core or guess the cfg.tbl
overrides.

**Why already addressed in luadch-ng v3.1.x:** Same layout fix as #30
above. Defaults live in `core/cfg_defaults.lua` (still core, still
not user-editable - that's correct), but operator overrides go in
`cfg/cfg.tbl` (user-editable), which is the standard luadch-ng
convention. The upstream criticism ("must edit core") doesn't apply
to our layout.

---

## etc_mainecho

### luadch/scripts#5 - trigger when the output is from the hub bot

**Status:** Fixed defensively in luadch-ng/scripts PR #15.

**Symptom (upstream):** Trigger bot fires not only on user messages
but also on hub-bot output. Example: hub-bot says something in main
chat that contains a configured trigger keyword -> the trigger bot
echoes it.

**Why already mostly addressed in v3.1.x:** In our hub bots
broadcast via `hub.broadcast()` (`core/hub.lua:1120`) which calls
`sendToAll` directly without firing the `onBroadcast` listener. So
our `onBroadcast` listener never receives bot-sourced messages in
the first place. The upstream symptom shouldn't repro on a stock
v3.1.x hub.

**Fix anyway:** Added a one-line `if user:isbot() then return nil
end` guard at the top of the listener. Cost: one line. Benefit:
matches operator expectation that bots-don't-trigger is an
invariant, and guards against future hub-side changes that might
re-introduce bot broadcasts firing the listener.

---

## etc_requests

### luadch/scripts#38 - +help shows misleading "Min Level: 20"

**Status:** Fixed in luadch-ng/scripts PR #17.

**Symptom (upstream):** `+help` for the request script shows
"Min. Level: 20", but the script's `minlevel` table uses true/false
per level with gaps. Example: `[55] = false` (sbot) excludes that
level, but `+help` claims everyone 20+ is allowed.

**Root cause:** `util.getlowestlevel(minlevel)` returns just the
lowest TRUE-keyed level (here 20). The string "Min Level: N" then
implies an inclusive lower bound, which is wrong when there are
false-gaps above N.

**Fix (PR #17):** Append the actual list of permitted levels to
`help_desc` at script load. Walks the `minlevel` table, collects
levels keyed `true`, sorts, formats with level names from
`cfg.get("levels")` where available, appends as
`"  |  allowed levels: 20 reg, 30 vip, 40 svip, 50 server, 60
operator, 70 supervisor, 80 admin, 100 hubowner"`.

Same family of fix as the cmd_mass / luadch/luadch#217 change in
[`luadch-ng/luadch`'s Interlude 2](https://github.com/luadch-ng/luadch/blob/master/docs/phases/INTERLUDE_UPSTREAM_TRIAGE_2.md).

### luadch/scripts#40 - When delete a request make it possible to announce in main/pm

**Status:** Already addressed (mostly) + deferred (additional ask).

**Symptom (upstream):** "When deleting a request it will only be
visible to the OP that has deleted the request."

**Why already addressed:** v0.8 of etc_requests added a
`hub.broadcast( msg_deleted_by, ... )` at the delete path
(handle_releases, around line 661). All hub users see the deletion
announcement now. The upstream symptom predates the v0.8 rewrite.

**Deferred:** The additional ask ("announce the reason for deleting")
would require extending `+request del` syntax to accept a reason
argument. That conflicts with `check_spaces=false` setups (where
release names can contain spaces, making "del rel reason" unparseable
without a delimiter). Filed as feature work, not part of this triage
sweep.

### luadch/scripts#36 - Missing [CHAT]Requests opt-out functionality

**Status:** Deferred as feature request.

**Symptom (upstream):** "the latest build... does not seem to include
the ability for users to opt-out of receiving [CHAT]Requests bot
activity, despite the changelog mentioning 'chat is optional (opt
out)'."

**Triage:** The upstream changelog "chat is optional (opt out)"
referred to the script-wide `activate_chat` cfg toggle (operator-
level, not per-user). The user requesting this issue wants per-user
opt-out via `+reqchatoff` / `+reqchaton`-style commands.

**Why deferred:** Implementing per-user opt-out requires:
- A new state file (e.g. `etc_requests_optoutusers.tbl`).
- New commands `+request reqchatoff / reqchaton` and
  `+reqchatoff / +reqchaton` aliases.
- Integration in `feed()` so chat broadcasts skip opted-out users.
- Right-click menu entries for opt-in/-out toggle.

Approximately 50-80 lines of new code plus state-handling glue.
Outside the scope of a triage sweep; logged as a deliverable feature
that an operator can pick up later.

---

## ptx_freshstuff

### luadch/scripts#22 - "Command incomplete" on `WhenAndWhatToShow["HH:MM"] = "all"`

**Status:** Fixed in luadch-ng/scripts PR #18.

**Symptom (upstream):** Setting `WhenAndWhatToShow["12:34"] = "all"` in
the script's settings makes the timer at that minute broadcast the
literal string "Command incomplete." instead of the all-releases
list.

**Root cause:** `FreshStuff.ShowRel(tab)` had a stub else-branch:

```lua
if tab == FreshStuff.NewestStuff then
    -- ...build MsgNew properly...
    FreshStuff.MsgNew = utf_format( msg_showrel_07, newest, Msg )
else
    FreshStuff.MsgAll = msg_error_03  -- "Command incomplete."
end
```

When `tab` is `FreshStuff.AllStuff` (the all-list path), `MsgAll`
gets set to the error placeholder instead of being built. The timer
then broadcasts that placeholder.

**Fix (PR #18):** Build `MsgAll` in the else-branch the same way
`MsgNew` is built in the if-branch - iterate AllStuff capped at
MaxShow, group by category, format with `msg_showrel_*`, store as
`MsgAll`. The "all" timer trigger now actually broadcasts the
release list.

(The second sub-question in the upstream issue - "how do I trigger
!prunerel from timing" - is a documentation request. The
`auto_remove` cfg already supports daily prune; the issue reporter
just hadn't found it. No code change.)

### luadch/scripts#18 - delete release by name

**Status:** Fixed in luadch-ng/scripts PR #18.

**Symptom (upstream):** `+delrel <name>` rejects with the syntax
error message; only `+delrel <ID#>` works.

**Root cause:** `FreshStuff.DelCrap` gates on
`tonumber(what) ~= nil` and falls through to the syntax-error reply
otherwise.

**Fix (PR #18):** Added a non-numeric branch that falls through to
a full-title match against AllStuff. Multiple matches all get
deleted (defensive, since add-path normally prevents duplicates).
Empty result reports "Release not found".

### luadch/scripts#39 - add a separator between announces (10-min idle)

**Status:** Fixed in luadch-ng/scripts PR #18.

**Symptom (upstream):** When new releases get announced via PM,
it's hard to see what's new vs what's stale. Operator request:
add a separator with date/time before each announce, but only if
the previous announce was more than 10 minutes ago.

**Fix (PR #18):** Added a module-level `last_announce_time`
timestamp and a `separator_idle_seconds` constant (default 600 =
10 minutes). Both `AddCrap` and `AddCrapAnnounce` now check
`now - last_announce_time >= separator_idle_seconds` before the
add-broadcast, and prepend a separator broadcast if so. Updates
`last_announce_time` after. Operators can edit the lang string
`msg_separator` (contains `%s` for the timestamp) and the script
constant `separator_idle_seconds`.

---

## etc_onlinecounter

### luadch/scripts#19 - TotalTime stuck at 0 for fresh registrations

**Status:** Fixed in luadch-ng/scripts PR #16.

**Symptom (upstream):** New users register, log in, sit in the hub
for hours; `+onlinecounter myhubtime` reports `Total uptime: 0
minutes`. `etc_onlinecounter.tbl` shows `SessionTime` ticking up but
`TotalTime` constant at 0. `+onlinecounter toponline` says
"Only 0 users in table".

**Root cause:** A misplaced safe-month gate plus a slate-wiping
rollover branch.

1. **Per-minute accumulator gate.** New-user records (created in
   `onLogin` and `onStart`) ship with `FreeMonth = 1` (a 1-month
   grace period). The per-second `onTimer` handler accumulates
   `SessionTime` always but gates `TotalTime` accumulation behind:
   ```lua
   if not v.FreeMonth or v.FreeMonth <= 0 or v.TotalTime < 0 then
       if not FreeMonth or v.TotalTime < 0 then
           ...accumulate...
       end
   end
   ```
   For a fresh user (`FreeMonth = 1, TotalTime = 0`) the outer guard
   is false, so `TotalTime` stays at 0 for the entire first month.

2. **Month-rollover slate wipe.** When the safe-month branch fires
   at month rollover, it does `v.FreeMonth = v.FreeMonth - 1` (good)
   AND `v.TotalTime = 0` (bad - if accumulation had been allowed,
   this would wipe the user's month-1 progress).

The combination: month 1 = no accumulation; rollover decrements
FreeMonth and sets TotalTime = 0; month 2 starts at 0 with FreeMonth
= 0; if the user doesn't earn `iTUT*60` minutes in month 2, the
month 3 rollover deducts and they go negative -> blocked.

**Fix (PR #16):**
- **Always accumulate per-minute** when online, subject to the
  `MaxTime` cap. Drop the safe-status gate from the accumulator.
  Safe-month semantics belong at month-rollover, not on per-minute
  ticks.
- **Don't wipe TotalTime in the safe-month rollover branch.** Just
  decrement `FreeMonth` and let the user keep what they earned.
  iTUT*60 deduction stays suppressed for safe users (that's the
  actual safe-month semantic).

After the fix: a fresh user accumulates real minutes throughout
their grace month; at next rollover FreeMonth--, no deduction, full
TotalTime preserved. Subsequent months: standard deduction logic.

---

## etc_ccpmblocker

### luadch/scripts#26 - doesn't block all users from using CCPM

**Status:** Won't fix (protocol-level limitation).

**Symptom (upstream):** With `etc_ccpmblocker` enabled in a hub of
300-400 users, the issue reporter could still establish CCPM with
12-15 of them (~4%) - mostly with users in passive mode. Even when
both clients only had this one hub in common.

**Why won't fix:** What the script can do, it already does. The
upstream complaint is a protocol-level limit, not a missing fix.

**What the script does today:**

- On `onConnect` / `onInf`, strips the `CCPM` token from the user's
  `SU` (Supports) field before the BINF is broadcast to others. This
  removes the "CCPM is available" hint other clients use to decide
  whether to negotiate.
- For pairs of users at or above `op_level` who interact (PM,
  search-result, CTM, RCM), sends each user a forged BINF re-adding
  CCPM only between the two of them. This is the operator-pair
  bypass.

**Why CCPM can still establish anyway:**

CCPM is a **peer-to-peer feature**, established over a direct TCP
connection between two clients. The hub only sees / forwards the
ADC negotiation messages; the actual data flows peer-to-peer.

The hub cannot prevent CCPM 100% because:

- Clients **cache** CCPM key material and peer-known capabilities
  across sessions. Once two clients have done CCPM with each other
  in any context, they can retry the direct connection without
  needing fresh `SU=CCPM` advertising.
- Clients can speculatively attempt CCPM even without the
  advertising flag, particularly with peers they've talked to before.
- The hub can drop the `CCPM` flag from BINF, but it cannot stop two
  cooperating clients from opening a TCP socket to each other if
  they already have each other's connection details from prior
  sessions.

A "100% CCPM block" would require:

- Intercepting `CTM` / `RCM` connection-setup messages that match
  CCPM's token pattern and dropping them.
- Possibly tracking peer-pair known-capabilities and rewriting
  responses.

That's protocol-level work that doesn't fit a plugin script and
overlaps with hub-core surface ([`luadch-ng/luadch`](https://github.com/luadch-ng/luadch)
itself). The issue reporter even acknowledges:

> I know that only one hub that allows CCPM is enough to established
> a CCPM connection.

The 4% residual success rate they observed is consistent with
clients reusing cached CCPM state from outside this hub's view.

**Disposition:** Audit-only entry. The script's BINF-flag manipulation
is the realistic best-effort defence; closing the residual hole
requires deeper hub-protocol intervention not in scope for a plugin.

---

## etc_EventAnnouncer

### luadch/scripts#1 - attempt to concatenate local 's' (a nil value)

**Status:** Fixed in luadch-ng/scripts PR #13.

**Symptom (upstream):** When an announce date has past, the `onTimer`
listener crashes every second:

```
scripts.lua: script error: ././scripts/etc_eventannouncer.lua:166:
attempt to concatenate local 's' (a nil value)
(listener: onTimer; script: 'etc_eventannouncer.lua')
```

**Root cause:** Two compounding issues at the announce-rendering path.

1. `epochTable()` rolls a past announce to next year only when
   `dest_d < cur_day` (strict `<`). On the announce day itself the
   condition is false, so `epoch_time` is computed as
   `{year=cur_year, month=dest_m, day=dest_d, hour=0, sec=1}` -
   midnight + 1 second of the announce day. As soon as the wallclock
   passes 00:00:01, the value is in the past and
   `tonumber(k) - os_time()` is negative.

2. `util.formatseconds()` returns `nil, errstr` on a negative input.
   The caller `local d, h, m, s = util_formatseconds(...)` swallows
   the error string and leaves `s` (and the rest) as nil. The next
   line concatenates `s` and crashes.

**Fix (PR #13):**
- Change the rollover condition from `<` to `<=`. Today's announce
  rolls to next year as soon as midnight passes, instead of staying
  in-the-past for the rest of the day.
- Add a defensive `if diff > 0 then ... end` guard around the
  formatseconds + concatenation block so any future edge case can't
  re-trigger the crash.
- While there, fix a latent display bug at the same call site: the
  upstream `local d, h, m, s = util_formatseconds(t)` used the
  no-arg 5-return variant, so the values pulled into d/h/m/s were
  actually Y/D/H/M (off-by-one). Switched to the 4-return D/H/M/S
  variant via `util_formatseconds(diff, true)`.

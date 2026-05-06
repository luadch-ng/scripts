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

## Plugins not yet triaged

The following imported plugins have open upstream issues that haven't
been triaged here yet:

- etc_onlinecounter: #19
- etc_requests: #36, #38, #40
- ptx_freshstuff: #18, #22, #39

Plus one upstream issue against an imported plugin that is audit-only:

- etc_ccpmblocker: #26 (passive-mode CCPM ~85% success rate is a
  protocol-level limitation, not a code bug; will be recorded as
  Won't-fix when its turn comes)

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

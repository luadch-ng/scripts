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

- cmd_pm2offliners: #29, #30, #41
- etc_mainecho: #5
- etc_onlinecounter: #19
- etc_requests: #36, #38, #40
- ptx_freshstuff: #18, #22, #39

Plus one upstream issue against an imported plugin that is audit-only:

- etc_ccpmblocker: #26 (passive-mode CCPM ~85% success rate is a
  protocol-level limitation, not a code bug; will be recorded as
  Won't-fix when its turn comes)

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

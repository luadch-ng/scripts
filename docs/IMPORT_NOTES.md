# luadch/scripts -> luadch-ng/scripts triage

Working notes from the initial import pass over the upstream
[`luadch/scripts`](https://github.com/luadch/scripts) repository
(snapshot taken 2026-05-05; upstream dead since 2022-08).

Strategy: **maximum inclusion**. A script is dropped only if its
function is genuinely replaced by a core hub feature already in
[`luadch-ng/luadch`](https://github.com/luadch-ng/luadch) or in the
v3.1.x active backlog, or if it is fundamentally broken in a way that
would require a complete rewrite (not just a Lua-5.4 syntax migration).

## Summary

- 34 total distinct script families
- 29 T1 (drop-in audit, low-risk migration)
- 4 T2 (works after non-trivial Lua-5.4 fix)
- 1 Deferred (etc_txtsend - blocked on bundled `lfs` C library; see entry below)
- 0 Drop (replaced by core / fundamentally broken)
- 19 upstream issues mapped to specific scripts

**Major findings**: No setfenv/getfenv/loadstring/unpack/module calls detected. No os.execute/io.popen/debug.* calls detected. No problematic os.difftime(arg1) 1-arg calls (all are 2-arg). Lua 5.1 → 5.4 migration should be low-risk for this codebase.

## Per-script triage

### bot_advanced_chat — v0.5

**Function:** Advanced chat room with history, member management, PM-to-OP forwarding.

**Tier:** T1.

**Lua-5.4 issues:** None spotted.

**Sandbox issues:** None.

**Overlap with core backlog:** —.

**Upstream issues touching this:** —.

**Notes:** Uses util_savetable/util_loadtable for persistence. Multi-feature chat with language support. Ready for direct import.

---

### cmd_mainclear — v0.02

**Function:** Sends empty lines to main chat to clear display.

**Tier:** T1.

**Lua-5.4 issues:** None spotted.

**Sandbox issues:** None.

**Overlap with core backlog:** —.

**Upstream issues touching this:** —.

**Notes:** Very simple (59 lines), German-only. Safe import.

---

### cmd_pm2offliners — v0.8

**Function:** Send PM to offline users; receives confirmation when they log in.

**Tier:** T1.

**Lua-5.4 issues:** None spotted (os.difftime calls: all 2-arg format).

**Sandbox issues:** None.

**Overlap with core backlog:** Partial with #78, but complementary.

**Upstream issues touching this:** #41 (settings in cfg.tbl), #29 (delivery bug), #30 (minlevel/oplevel settings).

**Notes:** v0.8 rewritten; incompatible with < v0.8 databases. Issues relate to settings management and a delivery logic bug. Ready for import.

---

### etc_EventAnnouncer — v0.4

**Function:** Announces scheduled events at configurable rotation intervals.

**Tier:** T1.

**Lua-5.4 issues:** None spotted (os.difftime: 2-arg format).

**Sandbox issues:** None.

**Overlap with core backlog:** —.

**Upstream issues touching this:** #1 (nil concatenation on expired date).

**Notes:** Ready for import; issue #1 is a fixable logic bug.

---

### etc_NewPasswords — v0.4 (multi3)

**Function:** Allows users to change passwords (regged user feature).

**Tier:** T1.

**Lua-5.4 issues:** None spotted.

**Sandbox issues:** None.

**Overlap with core backlog:** —.

**Upstream issues touching this:** —.

**Notes:** Multi-language support. Safe import.

---

### etc_banner_mod — v0.3 (multi3)

**Function:** Displays configurable banner/MOTD on user login.

**Tier:** T1.

**Lua-5.4 issues:** None spotted.

**Sandbox issues:** None.

**Overlap with core backlog:** —.

**Upstream issues touching this:** —.

**Notes:** Simple and safe.

---

### etc_blackboard — v0.2

**Function:** Shared note/bulletin board with add/delete/show commands.

**Tier:** T1.

**Lua-5.4 issues:** None spotted.

**Sandbox issues:** None.

**Overlap with core backlog:** —.

**Upstream issues touching this:** —.

**Notes:** Chat-based with persistence. Ready to import.

---

### etc_ccpmblocker2.0 — v2.0

**Function:** Controls CCPM (client-to-client PM) feature; enables only for ops+.

**Tier:** T1.

**Lua-5.4 issues:** None spotted.

**Sandbox issues:** None.

**Overlap with core backlog:** Partial with #81, but complementary.

**Upstream issues touching this:** #26 (success rate ~85% due to passive-mode protocol limitation).

**Notes:** Issue #26 is protocol-level, not a code bug. Safe import.

---

### etc_client_su_check — v0.2

**Function:** Warns/blocks users with invalid or missing SU (Supports Upgrade) features.

**Tier:** T1.

**Lua-5.4 issues:** None spotted.

**Sandbox issues:** None.

**Overlap with core backlog:** Partial with #81, but distinct.

**Upstream issues touching this:** —.

**Notes:** Ready to import.

---

### etc_clientblocker — v0.1

**Function:** Blocks client connections by pattern (DC++ 0.7xx, AirDC++ 2.xx, etc.).

**Tier:** T1.

**Lua-5.4 issues:** None spotted.

**Sandbox issues:** None.

**Overlap with core backlog:** Overlaps with #81 (client blocklist), still valuable standalone.

**Upstream issues touching this:** —.

**Notes:** Safe import.

---

### etc_hide_announcer — v0.01

**Function:** Blocks user announcements from public visibility.

**Tier:** T1.

**Lua-5.4 issues:** None spotted.

**Sandbox issues:** None.

**Overlap with core backlog:** —.

**Upstream issues touching this:** —.

**Notes:** Very simple (67 lines). Safe import.

---

### etc_hubportier — v0.1

**Function:** Limits concurrent connections per user/IP (basic rate limiting).

**Tier:** T1.

**Lua-5.4 issues:** None spotted.

**Sandbox issues:** None.

**Overlap with core backlog:** Partial with #80, but basic (connection-count only, not message-flood).

**Upstream issues touching this:** —.

**Notes:** Uses weak tables for session tracking. Safe import.

---

### etc_levelcheck — v0.1

**Function:** Reports user level in PM (debug/admin tool).

**Tier:** T1.

**Lua-5.4 issues:** None spotted.

**Sandbox issues:** None.

**Overlap with core backlog:** —.

**Upstream issues touching this:** —.

**Notes:** Tiny (64 lines). Safe import.

---

### etc_mainecho — v0.3

**Function:** Repeats/echoes main chat messages.

**Tier:** T1.

**Lua-5.4 issues:** None spotted.

**Sandbox issues:** None.

**Overlap with core backlog:** —.

**Upstream issues touching this:** #5 (triggers on hub bot messages as well as user messages).

**Notes:** Issue #5 is a usability bug. Ready to import.

---

### etc_maxhubs_announcer — v0.2

**Function:** Announces users' max-hub counts on login.

**Tier:** T1.

**Lua-5.4 issues:** None spotted.

**Sandbox issues:** None.

**Overlap with core backlog:** —.

**Upstream issues touching this:** —.

**Notes:** German-only. Safe import.

---

### etc_messenger — v0.4

**Function:** Bot-like PM messaging system with queue/delivery.

**Tier:** T1.

**Lua-5.4 issues:** None spotted.

**Sandbox issues:** None.

**Overlap with core backlog:** Complementary to #84.

**Upstream issues touching this:** —.

**Notes:** English version. Ready to import.

---

### etc_noadvertise — v0.7

**Function:** Checks/blocks forbidden strings in main/PM; configurable filter lists.

**Tier:** T1.

**Lua-5.4 issues:** None spotted.

**Sandbox issues:** None.

**Overlap with core backlog:** Partial with #78, but distinct (keyword filtering).

**Upstream issues touching this:** —.

**Notes:** Complex (515 lines), multi-language, database-driven. Privacy-conscious. Ready to import.

---

### etc_onlinecounter — v1.4

**Function:** Tracks user online time; blocks search/download if below threshold; rankings.

**Tier:** T2.

**Lua-5.4 issues:** None spotted.

**Sandbox issues:** None.

**Overlap with core backlog:** Partial with #80, but distinct (per-user time-accounting).

**Upstream issues touching this:** #19 (TotalTime stuck at 0; logic bug).

**Notes:** Large (857 lines), complex state machine. Needs testing post-import. T2 due to complexity.

---

### etc_openhubs_announcer — v0.2

**Function:** Announces count of open hubs users are in.

**Tier:** T1.

**Lua-5.4 issues:** None spotted.

**Sandbox issues:** None.

**Overlap with core backlog:** —.

**Upstream issues touching this:** —.

**Notes:** German-only. Safe import.

---

### etc_requests — v0.8

**Function:** Release request system; users request content, others fulfill. Chat + main commands.

**Tier:** T2.

**Lua-5.4 issues:** None spotted.

**Sandbox issues:** None.

**Overlap with core backlog:** —.

**Upstream issues touching this:** #40 (delete should announce), #38 (min-level display bug), #36 (missing opt-out).

**Notes:** Largest complex script (1032 lines). v0.8 rewritten, incompatible with < v0.8 DB. Issues are feature/display requests. T2 due to size and complexity.

---

### etc_sslonly — v0.2

**Function:** Disconnects users without SSL/TLS; warns team + others.

**Tier:** T1.

**Lua-5.4 issues:** None spotted.

**Sandbox issues:** None.

**Overlap with core backlog:** Overlaps with #77 (TLS-only), but distinct.

**Upstream issues touching this:** —.

**Notes:** German-only. Ready to import.

---

### etc_txtsend — v0.4 (multi) (win32 only)

**Function:** Sends text files to users on request.

**Tier:** Deferred (re-classed from T1).

**Lua-5.4 issues:** None spotted.

**Sandbox issues:** **Requires `lfs` (LuaFileSystem)** via `require "lfs"`
(uses `lfs.dir()` to enumerate the available text-file directory at
runtime). luadch-ng v3.1.x does not bundle `lfs`; the plugin
silently fails to load until `lfs` is provided.

**Overlap with core backlog:** —.

**Upstream issues touching this:** —.

**Notes:** Deferred from the user-info import batch. Three options to
re-import: (a) bundle `lfs` in the hub build (CMakeLists.txt change,
multi-PR Phase-8+ scope); (b) refactor the plugin to read a
hand-maintained file list instead of `lfs.dir`-discovery; (c) ship the
plugin as-is with an operator-side `lfs` install requirement. None
chosen yet; no operator demand observed.

---

### etc_wunschbrett — v0.2

**Function:** Wishlist/forum system (post requests, users can comment/vote).

**Tier:** T1.

**Lua-5.4 issues:** None spotted.

**Sandbox issues:** None.

**Overlap with core backlog:** —.

**Upstream issues touching this:** —.

**Notes:** Chat-based, persistent. Safe import.

---

### ptx_Poll_Bot — v.3.0

**Function:** Polling/voting system; create polls, vote, see results.

**Tier:** T1.

**Lua-5.4 issues:** None spotted.

**Sandbox issues:** None.

**Overlap with core backlog:** —.

**Upstream issues touching this:** —.

**Notes:** Large (654 lines), English-only. Exports voting module. Safe import.

---

### ptx_RSSFeedWatch — v0.11

**Function:** Watches RSS/Atom feeds; posts new items to hub.

**Tier:** T2.

**Lua-5.4 issues:** None spotted.

**Sandbox issues:** Uses socket operations (http); verify sandbox allows socket.* API.

**Overlap with core backlog:** —.

**Upstream issues touching this:** #35 (hide-links setting breaks feed posting).

**Notes:** Largest (1453 lines). v0.11 recent improvements. Needs socket API access verification. T2 due to complexity and external I/O.

---

### ptx_anti_dl — v2.0

**Function:** Anti-download protection; blocks users matching profiles from search/download.

**Tier:** T1.

**Lua-5.4 issues:** None spotted.

**Sandbox issues:** None.

**Overlap with core backlog:** Complementary to #78/#81.

**Upstream issues touching this:** —.

**Notes:** English-only. API2-compliant. Ready to import.

---

### ptx_freshstuff — v0.11 (multi3)

**Function:** Release announce bot; category-based, scheduled broadcasts, rankings.

**Tier:** T2.

**Lua-5.4 issues:** None spotted.

**Sandbox issues:** None.

**Overlap with core backlog:** —.

**Upstream issues touching this:** #39 (add separator), #22 (timer loading), #18 (delete by name).

**Notes:** Complex (1279 lines), multi-language. v0.11 recent improvements. Issues are feature requests. T2 due to complexity.

---

### ptx_rotatingtopic — v0.1

**Function:** Rotates MOTD/topic at configurable intervals.

**Tier:** T1.

**Lua-5.4 issues:** None spotted.

**Sandbox issues:** None.

**Overlap with core backlog:** —.

**Upstream issues touching this:** —.

**Notes:** English-only. Safe import.

---

### ptx_tagCheck — v0.1

**Function:** Validates file tags (release metadata); blocks invalid.

**Tier:** T1.

**Lua-5.4 issues:** None spotted.

**Sandbox issues:** None.

**Overlap with core backlog:** —.

**Upstream issues touching this:** —.

**Notes:** English-only. Safe import.

---

### ptx_tagcheck — v2.3 (multi3)

**Function:** Alternative tag-check script (separate from ptx_tagCheck).

**Tier:** T1.

**Lua-5.4 issues:** None spotted.

**Sandbox issues:** None.

**Overlap with core backlog:** —.

**Upstream issues touching this:** —.

**Notes:** Multi-language. Similar to v0.1; both can coexist. Safe import.

---

### ptx_tophubbers — v0.1

**Function:** Ranks/announces top hub users by activity.

**Tier:** T1.

**Lua-5.4 issues:** None spotted.

**Sandbox issues:** None.

**Overlap with core backlog:** —.

**Upstream issues touching this:** —.

**Notes:** German-only. Safe import.

---

### usr_nick_prefix_mod — v0.3 (multi3)

**Function:** Allows admins to add custom prefixes to user nicks (cosmetic).

**Tier:** T1.

**Lua-5.4 issues:** None spotted.

**Sandbox issues:** None.

**Overlap with core backlog:** —.

**Upstream issues touching this:** —.

**Notes:** Integrates with etc_onlinecounter. Ready to import.

---

### usr_speedinfo — v0.03

**Function:** Displays user's speed/connection info on query.

**Tier:** T1.

**Lua-5.4 issues:** None spotted.

**Sandbox issues:** None.

**Overlap with core backlog:** —.

**Upstream issues touching this:** —.

**Notes:** English-only. Safe import.

---

## Upstream issues without a clear script mapping

- #28: Add search flood protection (core feature, not script)
- #34: Prevent Level XX login until allowed (core feature)
- #33: Schedule restart (core feature)
- #25: Spam protection for main/PM (potential script, none in repo)
- #24: opchat/regchat history incorrect (relates to chat scripts or core, unclear mapping)

---

## Tier Breakdown

- **T1 (30 scripts):** All ready for direct import with minimal risk.
- **T2 (4 scripts):** etc_onlinecounter, etc_requests, ptx_RSSFeedWatch, ptx_freshstuff. Ready for import but prioritize testing.
- **Drop (0):** None dropped.


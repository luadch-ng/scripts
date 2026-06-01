# CLAUDE.md

Context for Claude Code (and any AI assistant) working on the
`luadch-ng/scripts` repo. Read this before making changes - it
captures the working agreement, layout, and per-plugin conventions
that span sessions.

User communication is in **German**; all written artifacts (this file,
code, comments, commits, PRs, issues) stay in **English** so other
contributors can read them.

This file inlines the working-agreement rules from the parent
`luadch-ng/luadch` repo's CLAUDE.md. Keep the two in sync when rules
change upstream.

---

## 1. Working agreement (non-negotiable)

### 1a. Per-change discipline (every PR, no size exemption)

1. **Security and consistency come first.** Plugins run inside a
   restricted sandbox but receive every BMSG / DMSG / PM and have
   access to user state, file I/O via the sandbox shims, and
   listener registration. Treat any change touching user-input
   parsing, file I/O, listener registration, or sandbox boundaries
   as security-sensitive. Grep for similar patterns across plugins
   and fix everywhere - divergent code paths are a defect.
2. **No spaghetti.** Prefer small, focused functions. Plugins stay
   in their own per-plugin subdir (see §3).
3. **Deep-dive before implementation.** Read the existing plugin and
   the hub's relevant subsystem before writing code.
4. **An issue/plan is a hypothesis, not ground truth.** Verify
   against the current source.
5. **Verify every assumption** before building on it.
6. **Mandatory two-pass pre-merge review.** Before any merge -
   regardless of how small the diff - run: (a) an independent
   reviewer (subagent / fresh perspective) and (b) a maintainer-side
   spot-check. Covers security, new bugs, breaking behaviour,
   consistency. Past reviews on this repo caught: silent key-
   mismatch bugs (etc_blackboard, etc_wunschbrett, ptx_freshstuff -
   `lang.X` source ref vs lang-file key drift), a runtime-crash
   format string (etc_onlinecounter DE templates would crash
   `string.format` on multi-`%i` + interleaved plural args), and
   gendered DE wording.
7. **Regression tests**: this repo has **no CI / no smoke harness /
   no unit tests**. Validation is at hub-install time. For non-
   trivial plugin changes: install on a test hub + verify in chat.
   For lang changes: `lua54.exe` loadfile check on the lang files +
   verify structure-parity (`en` keys == `de` keys) using the
   script in the i18n memory record.
8. **Small reviewable PRs.** One logical change per PR. Multi-plugin
   PRs are fine for mechanical cleanups (cap at ~10-12 plugins per
   PR - the tractable limit for one review pass).
9. **No wall of text.** Chat / PR body / issue text: minimal,
   technical, complete. Detail in code + memory, not in summaries.

### 1b. No phase model

Unlike the hub's CLAUDE.md, this repo has no formal phase model -
plugin work is per-issue / per-arc, not gated by phases. The per-PR
review gate in §1a.6 is the only gate. When a multi-PR arc is in
flight (e.g. the closed `#31` i18n cleanup with 7 PRs), the tracker
issue holds the arc's scope; PRs reference it with `Part of #N`.

When uncertain whether a change fits the active arc, stop and ask
the maintainer.

---

## 2. Project overview

`luadch-ng/scripts` is the **curated companion plugin repo** for the
[`luadch-ng/luadch`](https://github.com/luadch-ng/luadch) ADC hub.
Plugins drop in to add commands, listeners, RC menus, automation.

- **Status:** active. 31 plugins as of 2026-05-30.
- **License:** GPL-3.0.
- **No CI.** No smoke harness, no unit tests, no GitHub Actions.
  Live-test at hub-install time.

Recent arc: the `#31` i18n cleanup closed 2026-05-30 with 7 PRs
(`#32`-`#38`), migrating all 31 plugins to a uniform `cfg.loadlanguage`
pattern. See the auto-memory `project-31-scripts-i18n` for the 10
durable patterns from that arc.

---

## 3. Per-plugin layout

Every plugin lives in its OWN folder under `scripts/`. Never flat.

```
scripts/<plugin_name>/
  <plugin_name>.lua          Plugin source. The local `scriptname`
                             MUST match the folder name (cfg.loadlanguage
                             resolves scripts/<scriptname>/lang/
                             <scriptname>.lang.<X>).
  lang/                      Lang files (per the i18n convention)
    <plugin_name>.lang.de    German strings
    <plugin_name>.lang.en    English strings
  <data subdir>              Plugin-specific runtime template files,
                             if any. Subdir name varies by upstream
                             convention - common forms are `data/`
                             (e.g. ptx_poll_bot) or a short-name
                             folder (e.g. ptx_tophubbers/tophubbers).
                             Hub-runtime data lives at
                             scripts/data/<plugin>_*.tbl (separate
                             from per-plugin template dir).
```

Reference plugins (recently migrated, good consolidation pattern):
- `scripts/ptx_tophubbers/` - simple Bucket-C i18n migration.
- `scripts/ptx_poll_bot/` - nested-table lang structure +
  embedded-bugfix combo (`tLang.value` -> `tLang[value]` flat-key
  trap, hardcoded English in OldPoll).
- `scripts/etc_onlinecounter/` - the `(s)` / `(e)` / `(n)` static
  pseudo-plural pattern that survives multi-language
  `string.format`.

---

## 4. The i18n contract (the most important plugin-side convention)

The `cfg.loadlanguage` lang-system is the project standard.

### 4a. Standard pattern at the script top

```lua
local scriptname = "<plugin_name>"   -- MUST match dir name
local scriptversion = "X.Y"

local scriptlang = cfg.get( "language" )
local lang, err = cfg.loadlanguage( scriptlang, scriptname )
lang = lang or {}
err = err and hub.debug( err )

local msg_X = lang.msg_X or "<English default fallback>"
```

### 4b. Source-vs-lang-file consistency

A typo in the source (`lang.ucmd_who`) vs the lang file key
(`ucmd_which`) is a **silent bug** - the `or "<fallback>"` masks
it, English defaults forever. Validate after every change:

```
lua54 -e "
local en = dofile([[scripts/<plugin>/lang/<plugin>.lang.en]])
local de = dofile([[scripts/<plugin>/lang/<plugin>.lang.de]])
local f = io.open([[scripts/<plugin>/<plugin>.lua]]); local src = f:read('*a'); f:close()
local refs = {}; for k in src:gmatch('lang%.([%w_]+)') do refs[k] = true end
for k in pairs(refs) do
  if en[k] == nil then print('MISSING en:', k) end
  if de[k] == nil then print('MISSING de:', k) end
end
for k in pairs(en) do if not refs[k] then print('UNUSED en:', k) end end
"
```

When the repo gets a smoke harness this check should be lifted to a
generic all-plugins pass.

### 4c. DC jargon stays English in DE lang files

DO NOT germanize: Hub, Slot, Share, OP, Kick, Ban, Nick, PM,
Mainchat, Client, Tag, CID, SID, Userlist, Reg, Login, Bot, Flag,
Search, MOTD, CTM, RCM, TLS, ZLIF, ZOF, HSUP, BLOM, OSNR. Plus
plugin-specific feature names if they are DC-protocol-adjacent. Ask
the maintainer if unsure.

This is uniform across the project ([[feedback-i18n-terminology]] in
the auto-memory).

### 4d. Multi-language format strings

EN can use `"%i year%s"` with a `plural(n)` helper that returns
`"s"` or `""`. **DE cannot** - German plurals are irregular and
interleaving the suffix arg into multi-`%i` formats causes
`string.format` to crash on the second `%i` (number expected, got
string).

Use static `"(s)"` / `"(e)"` / `"(n)"` pseudo-plural form in
**both** EN and DE, and drop the `plural()` helper entirely:

```lua
fmt_duration = "%i year(s), %i month(s), %i day(s)"  -- EN
fmt_duration = "%i Jahr(e), %i Monat(e), %i Tag(e)"  -- DE
```

Slight EN regression ("1 year(s)" instead of "1 year") is the
agreed trade-off for cross-locale safety. See the
`etc_onlinecounter` v1.6 reviewer-blocker for the lesson.

### 4e. Source-fallback drift

When fixing a typo in a lang file, ALSO grep for `lang\.<key> or`
in the plugin source and update the inline English fallback.
Otherwise the typo ships when lang load fails.

### 4f. Pragmatic-partial i18n for very large plugins

Acceptable. Cover user-visible chat strings + ucmd labels first;
structural display layouts (column tables) can stay English-
structured if column-width-aware. Document scope in the version-
bump header comment.

---

## 5. Sandbox + plugin-activation gotchas

- A plugin in `scripts/<name>/` is NOT loaded automatically. It
  must be **whitelisted in the hub's `cfg/cfg.tbl`** under the
  `scripts` key. Without that whitelist, drop-in plugins silently
  do not load.
- The plugin sandbox provides `cfg`, `hub`, `utf`, `util`, plus
  `util_http` (for HTTP endpoints) and `http_client` (for outbound
  HTTP). NO `use`. `hub.debug` is gated on the hub's `log_scripts`
  config.
- Listener-chain order is the order plugins appear in `cfg.scripts`.

For deeper sandbox notes (export-table shallow-copy, stale rebinds,
SANDBOX_GLOBALS whitelist), see the auto-memory entries
`reference-plugin-listener-quirks`, `reference-lua-plugin-exports`,
`project-206-sandbox`.

---

## 6. Conventions for changes

- **Commit style**: match `git log` - concise, imperative, optional
  `fix #NNN` trailer.
- **PR scope**: one issue per PR, except for tightly coupled
  mechanical cleanups (e.g. multi-plugin i18n migrations).
- **Lua style**: match the file you're editing. Plugins inherited
  from upstream may use 4-space, 2-space, or tab indent - preserve
  per-file. Don't reformat unrelated lines.
- **Comments**: explain *why*, not *what*. Don't restate code.
- **No drive-by refactors**. If you spot something during an
  unrelated change, open an issue or note it in the version-bump
  comment - do not fix inline.
- **No em-dashes anywhere.** Use `-` in all written output: chat,
  commits, PRs, issues, docs.

### Tooling gotchas

- **Pin `gh` to the repo**: `gh ... --repo luadch-ng/scripts`. The
  checkout may have multiple remotes; bare `gh` can default to the
  wrong one.
- **Multi-tier tracker issues**: never use `Closes #N` if the
  tracker has multiple subtasks - GitHub auto-closes the whole
  tracker on squash-merge. Use `Part of #N`. (The `#31` i18n arc was
  managed correctly because of this rule.)
- **Local Lua-syntax check** before push:
  ```
  C:\lua-5.4.8_Win64_bin\lua54.exe -e "local f, e = loadfile([[scripts/<plugin>/<plugin>.lua]]); print(f and 'OK' or e)"
  ```
  Faster than going through review for a syntax bug.

---

## 7. External state & memory

- **GitHub issues**: backlog at https://github.com/luadch-ng/scripts/issues.
  Recent: `#31` i18n arc CLOSED 2026-05-30 (7 PRs `#32`-`#38`).
- **Auto-memory** relevant to this repo:
  - `project-31-scripts-i18n` - the closed i18n arc + 10 durable
    patterns (silent key-mismatch, source-fallback drift, multi-%i
    crash, scriptname-rename-for-cfg.loadlanguage, etc.).
  - `feedback-i18n-terminology` - the don't-germanize-DC-terms rule.
  - `reference-scripts-repo` - cross-repo interactions snapshot.
  - `feedback-scripts-per-plugin-layout` - per-plugin subdir
    convention.
  - `feedback-scripts-validation-via-cfg-tbl` - cfg.tbl whitelist
    requirement.
  - `reference-plugin-listener-quirks` - sandbox + listener-chain
    details.

---

## 8. Cross-repo interactions

This repo interacts with:

- **`luadch-ng/luadch`** (the hub). Plugins here assume the hub's
  plugin API contract. When the hub changes the contract (rare;
  major version), plugins may need updates. Some plugins also
  consume the hub's HTTP API endpoints (`util_http`, `http_client`)
  - see hub's `docs/HTTP_API.md`.
- **`luadch-ng/announcer`** - separate companion (the OSNR scene-
  release announcer). Orthogonal to this repo.

Plugins should NEVER be checked into the hub's repo. Plugins live
here. The hub bundles only the first-boot minimum it needs.

# luadch-ng/scripts

Optional plugin scripts for the modernised
[`luadch-ng/luadch`](https://github.com/luadch-ng/luadch) DC++ ADC hub.
Each script extends hub functionality - chat tools, mod commands,
filtering, announcements, share policy, and so on.

This repository is curated and audited. Scripts originate from the
upstream [`luadch/scripts`](https://github.com/luadch/scripts) repo
(dead since 2022-08); we re-import only the highest version of each
script, audit it for Lua 5.4 compatibility, fix bugs that were tracked
upstream, and add a provenance header preserving the original-author
credit.

## Layout

The `scripts/` tree in this repo mirrors a hub's `scripts/` tree, so
paths line up 1:1:

- `scripts/<name>.lua` - main script
- `scripts/lang/<name>.lang.<lang>` - language file(s) for that script
- `scripts/data/<name>_<...>.tbl` - persistent state files (some scripts
  use `scripts/<name>/...` instead; see per-script docs)

## Installing a script

The simplest install is wholesale: copy everything from
`repo/scripts/` into your hub's `scripts/` directory, preserving
relative paths. To install just one script, copy its `.lua` file plus
any companion files under `scripts/lang/`, `scripts/data/`, or
`scripts/<scriptname>/` paths that the script references.

Restart the hub or run `+reload` after copying. Scripts are not
auto-loaded by core; operators opt in script by script.

## Compatibility

Targets the [`luadch-ng/luadch`](https://github.com/luadch-ng/luadch)
v3.1.x line. Scripts run inside the modernised plugin sandbox (Lua 5.4,
empty `_ENV`, hub / cfg / util API). They may not work on the upstream
`luadch/luadch` (Lua 5.1 era) without backporting.

## Tiers

Each script carries an implicit tier from the import triage. See
[`docs/IMPORT_NOTES.md`](docs/IMPORT_NOTES.md) for the full per-script
notes:

- **T1**: low-risk drop-in port. Lua-5.4-clean by audit, smoke-loads
  in the modernised hub.
- **T2**: same audit, but additional manual testing recommended due to
  size / complexity / external I/O.

## Contributing

Bug fixes welcome. Material feature changes to an upstream-derived
script should be discussed in an issue first - the goal here is "working
ports of upstream scripts", not divergent rewrites. New plugins (not
derived from upstream) are welcome under their own filenames and
authorship.

## License

GPLv3, same as the parent project. Each imported script preserves its
original-author credit in the file header. See [`LICENSE`](LICENSE).

## Credits

All conceptual credit to **blastbeat**, **pulsar**, **Sopor**,
**ptokax**, and the other named authors of the upstream
`luadch/scripts` plugins. This repo modernises and curates their work.

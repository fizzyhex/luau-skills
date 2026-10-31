---
name: core-rokit
description: |
    Use when installing, adding, pinning, or updating Roblox/Luau CLI tools with
    rokit (rokit.toml), or when a tool is "not found" in a project
---

# Rokit

Rokit is the toolchain manager for Roblox projects. It pins GitHub-released
binaries per project in `rokit.toml`, and it also reads legacy `aftman.toml`
and `foreman.toml`.

## rokit.toml

```toml
[tools]
rojo = "rojo-rbx/rojo@7.7.1"
wally = "UpliftGames/wally@0.3.2"
wally-package-types = "JohnnyMorganz/wally-package-types@1.7.0"
stylua = "JohnnyMorganz/StyLua@2.6.0"
selene = "Kampfkarren/selene@0.32.0"
luau-lsp = "JohnnyMorganz/luau-lsp@1.70.1"
lune = "lune-org/lune@0.11.1"
darklua = "seaofvoices/darklua@0.19.0"
```

The key is the command name (alias). The value is `owner/repo@version`, where
the version is the release tag without the leading `v`.

## Commands

```sh
rokit init                         # create rokit.toml in the current dir
rokit add rojo-rbx/rojo            # add latest + install (writes rokit.toml)
rokit add rojo-rbx/rojo@7.7.1      # pin a version
rokit add JohnnyMorganz/StyLua stylua   # custom alias (second arg)
rokit add --global lune-org/lune   # user-wide tool, not in the project
rokit install                      # install everything in the nearest manifest
rokit install --no-trust-check     # CI: skip interactive trust prompts
rokit update                       # bump all tools to latest (edits manifest)
rokit update --check               # only report available updates
rokit update stylua                # bump one tool
rokit list                         # show installed tools
rokit trust owner/repo             # pre-trust a tool
rokit authenticate github --token <PAT>  # raise GitHub API rate limits
rokit self-update
```

## Key points

- Tools resolve against the **nearest manifest up the directory tree** from the
  current directory. If you run `stylua` from a scratch directory outside the
  project, it fails with "binary not found" or "Failed to find tool ... in any
  project manifest file".
- The first install of a new tool asks for trust interactively. In automation,
  use `rokit install --no-trust-check` or run `rokit trust` first.
- Commit `rokit.toml`. To change tool versions, use `rokit add`/`rokit update`
  rather than editing the file by hand, so the binaries actually get
  installed.
- Rokit installs Rokit itself: `rokit self-install`, or the install script
  from the rokit README.

<!--
Source references:
- https://github.com/rojo-rbx/rokit
- rokit 1.2.0 `--help` output
-->

# Working with nix profiles

A grab-bag of patterns and workflow tips for day-to-day use of this repo. See [usage.md](usage.md) for the full command reference.

## Flake reference forms

`nix profile add <thing>` interprets `<thing>` as a flake reference. The form you pass determines where Nix looks:

| Form | Example | Resolves to |
|---|---|---|
| Bare name | `nebula` | Registry lookup (`nix registry list`). Fails if the name is not registered. |
| `.` | `.` | The flake in the current working directory. |
| Relative path | `./profiles/nebula` | The flake at that path, relative to cwd. |
| Absolute path | `/home/.../profiles/nebula` | The flake at that path. |
| `path:` prefix | `path:./profiles/nebula` | Same as relative path but explicit. |
| `github:` | `github:zettlrobert/nix-profiles?dir=profiles/nebula` | Fetched from GitHub. |
| `git+https:` | `git+https://example.com/repo` | Generic git URL. |

A common mistake: running `nix profile add nebula` from inside `profiles/nebula/`. That tries the registry, not the current directory. Use `nix profile add .` instead.

If you want the shorthand to work, register it once:

```bash
nix registry add nebula path:/abs/path/to/profiles/nebula
```

Then `nix profile add nebula` resolves through the registry.

## Inspect a flake before adding it

```bash
# what packages does it expose?
nix flake show ./profiles/<host>

# what are its inputs and lock state?
nix flake metadata ./profiles/<host>

# evaluate the derivation without building (catches eval errors fast)
nix eval ./profiles/<host>#packages.x86_64-linux.default.drvPath
```

## Try a tool without installing

`nix shell` drops you into a subshell with the package on `PATH`. Nothing is added to your profile:

```bash
nix shell nixpkgs#fd          # one tool from current nixpkgs
nix shell ./packages/freecad-mcp
```

`nix run` runs a flake's default executable once:

```bash
nix run nixpkgs#hello
```

Both leave no trace after exit (until garbage collection clears the store paths).

## Add a new package to your setup

Three placements depending on scope:

1. **Everywhere** — add it to `packages/core-packages/flake.nix` in the `corePackages` list. Every profile picks it up on next `nix flake update`.
2. **One host only** — add it directly to that profile's `flake.nix` paths (e.g. `profiles/midgard/flake.nix`).
3. **Custom build / not in nixpkgs** — create `packages/<name>/flake.nix` as a standalone flake (see `packages/freecad-mcp/flake.nix` for the pattern), then reference it as a flake input from core or a profile (see [structure.md](structure.md)).

Always test with `nix eval` or `nix shell` before committing.

## Multiple independent profiles

By default `nix profile` writes to `~/.local/state/nix/profiles/profile`. You can keep separate profiles side by side with `--profile`:

```bash
nix profile add --profile ~/.local/state/nix/profiles/work ./profiles/fara
nix profile add --profile ~/.local/state/nix/profiles/personal ./profiles/midgard
```

Activate one in a shell:

```bash
export PATH=~/.local/state/nix/profiles/work/bin:$PATH
```

Useful when you want a host-wide baseline plus a project-scoped overlay without mixing them.

## Resolving package conflicts

If two packages in a profile expose the same binary name, `nix profile add` fails with a "files conflict" error. Override with `--priority` (lower number wins):

```bash
nix profile add --priority 4 ./packages/<pkg>
```

Default priority is 5. Reinstall the loser with a higher priority if you want it second-place but still in the closure.

## Lock and pin discipline

- After running `nix flake update` in `packages/core-packages` or a profile, commit the updated `flake.lock`. Without that, other machines (and yggdrasil) won't see the same pin.
- Bump `core` first, then each profile. The `nixpkgs.follows` directive means profile locks only catch up to core's pin when you run `nix flake update` *inside the profile*.
- For reproducibility on a new machine, install with an explicit revision:
  ```bash
  nix profile add github:zettlrobert/nix-profiles?rev=<sha>&dir=profiles/midgard
  ```

## Verifying after upgrade

```bash
nix profile diff-closures            # what changed in the last upgrade
nix profile history                  # generation list with dates
which <tool>                         # confirm Nix's symlink wins on PATH
<tool> --version                     # confirm the bumped version
```

If something broke: `nix profile rollback` reverts in one command.

## When to use what

| You want to … | Use |
|---|---|
| Try a tool once | `nix run` |
| Try a tool for the duration of a shell | `nix shell` |
| Install a tool you'll use every day | `nix profile add ./packages/<pkg>` |
| Install a host's full baseline | `nix profile add ./profiles/<host>` |
| Pin a one-off project's tools | `flake.nix` + `direnv` + `nix develop` (not covered here) |
| Replace home-manager | This repo + GNU Stow dotfiles in `zettlrobert/configurations` |

## Gotchas worth remembering

- **Bare names hit the registry**, not the filesystem. Use `.` or a path.
- **`nix flake update` does not rebuild your profile.** It only bumps the lockfile. Run `nix profile upgrade --all` afterwards.
- **Path inputs evaluate at the path's current state.** If you edit a flake under `packages/`, every dependent profile sees the change on next eval — even without a lock bump. Commit changes before relying on reproducibility elsewhere.
- **`nix profile remove --all` is a clean slate.** Useful when a profile gets crusty after many upgrades. You lose generation history.
- **macOS PATH ordering.** Apple's `/usr/bin` ships old versions of `git`, `python`, etc. Make sure `~/.nix-profile/bin` is ahead in your shell rc.

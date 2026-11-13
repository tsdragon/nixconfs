# Tal's NixOS Configurations

This repository contains the flake-based NixOS and Home Manager configuration for `tal-pc`.

## Layout

- `flake.nix`: flake inputs and outputs.
- `hosts/tal-pc/`: host-specific NixOS and Home Manager entry points.
- `modules/system/`: reusable NixOS modules for base settings, users, desktop, bundles, and services.
- `modules/home-manager/`: reusable Home Manager modules for base user setup, apps, bundles, and themes.
- `overlays/`: local package overrides.
- `secrets/`: sops-nix encrypted secrets plus local-only secret-adjacent configuration.

## Entry Points

- NixOS: `.#tal-pc`
- Home Manager: `.#tal@tal-pc`

## Common Commands

Build and switch the system:

```bash
nh os switch --ask --hostname tal-pc .
```

Switch the Home Manager profile:

```bash
nh home switch --ask --configuration 'tal@tal-pc' .
```

Update inputs and rebuild:

```bash
nix flake update
nh os switch --ask --hostname tal-pc .
nh home switch --ask --configuration 'tal@tal-pc' .
```

NH shows build progress and generation differences, then asks before activation.
Run it as the normal user; it requests elevation for system activation itself.
The Zsh aliases `nrs` and `hms` use these commands from any directory, and
`full_upgrade` updates the inputs before running both. Existing Nix garbage
collection is unchanged; NH's automatic cleanup is not enabled.

Before NH is installed, or if you don't wish to use NH, use:

```bash
nix flake update
sudo nixos-rebuild switch --flake .#tal-pc
home-manager switch --flake .#tal@tal-pc
```

Evaluate checks without building:

```bash
nix flake check --no-build
```

## Workaround Tracking

Temporary fixes and compatibility shims use `WORKAROUND(YYYY-MM-DD)`, where
the date is the last review date. Find everything due for periodic re-testing
with:

```bash
rg -n 'WORKAROUND\(' --glob '*.nix'
```

When reviewing a marker, remove the workaround if it is no longer needed or
update the date after confirming that the underlying issue still exists.

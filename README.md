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
sudo nixos-rebuild switch --flake .#tal-pc
```

Switch the Home Manager profile:

```bash
home-manager switch --flake .#tal@tal-pc
```

Update inputs and rebuild:

```bash
nix flake update
sudo nixos-rebuild switch --flake .#tal-pc
home-manager switch --flake .#tal@tal-pc
```

Evaluate checks without building:

```bash
nix flake check --no-build
```

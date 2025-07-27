# Tal's NixOS Configurations

This repository contains the NixOS configurations for multiple systems managed using flakes. It is structured to provide modular and reusable configurations for both system-level and user-level setups.

## Repository Structure

### Hosts
The `hosts/` directory contains configurations specific to individual machines:
- **nixos-vm**: Configuration for a virtual machine running NixOS.
- **tal-laptop**: Configuration for Tal's laptop.
- **tal-pc**: Configuration for Tal's desktop PC.

Each host directory includes:
- `configuration.nix`: Main system configuration.
- `hardware-configuration.nix`: Hardware-specific settings. Typically automatically generated on install.
- `home.nix`: User-specific Home Manager configuration.

### Modules
The `modules/` directory contains reusable NixOS and Home Manager modules:
- **home-manager/**: Modules for user-level configurations, including apps, themes, and bundles.
- **system/**: Modules for system-level configurations, including services, desktops, and hardware.

#### Home Manager Modules
- **apps/**: Configurations for individual applications (e.g., Firefox, Git, Zsh).
- **base/**: Base configurations for Home Manager (e.g., identity, NAS integration).
- **bundles/**: Grouped configurations for specific use cases (e.g., 3D modeling, messaging).
- **themes/**: Theme configurations (e.g., Kvantum themes).

#### System Modules
- **base/**: Base system configurations (e.g., default settings, NVIDIA drivers).
- **bundles/**: Grouped configurations for specific use cases (e.g., gaming, general desktop).
- **desktops/**: Desktop environment configurations (e.g., GNOME, Plasma).
- **services/**: Service configurations (e.g., Cockpit, ProtonMail Bridge).
- **users/**: User setup and user-specific system configurations.

### Secrets
The `secrets/` directory contains encrypted secrets managed using sops-nix. Secrets can be
 integrated into both system and user configurations.

### Flake Configuration
The `flake.nix` file defines the flake inputs and outputs, including:
- NixOS configurations for each host.
- Home Manager configurations for each user.
- Custom packages and utilities.

## Usage

### Building and Switching Configurations
To build and switch to a configuration:
```bash
nixos-rebuild switch --flake .#<hostname>
```

### Updating Configurations
To update the flake inputs and rebuild:
```bash
nix flake update
nixos-rebuild switch --flake .#<hostname>
```

### Home Manager
To switch to a Home Manager configuration:
```bash
home-manager switch --flake .#<username>@<hostname>
```
#!/bin/bash

# Simple NixOS Manager Setup using Flakes
# Run with: sudo bash setup.sh

set -e  # Exit on any error

if [ "$EUID" -ne 0 ]; then 
    echo "Please run with sudo: sudo bash setup.sh"
    exit 1
fi

echo "=== NixOS Manager Quick Setup ==="

# Enable flakes if not already enabled
echo "Enabling flakes..."
mkdir -p /etc/nix
cat > /etc/nix/nix.conf << EOF
experimental-features = nix-command flakes
EOF

# Generate hardware config if missing
if [ ! -f "/etc/nixos/hardware-configuration.nix" ]; then
    echo "Generating hardware configuration..."
    nixos-generate-config --root /
fi

# Create flake.nix
echo "Creating flake.nix..."
cat > /etc/nixos/flake.nix << 'EOF'
{
  description = "NixOS Manager";
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  outputs = { nixpkgs, ... }: {
    nixosConfigurations.manager = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [ ./configuration.nix ];
    };
  };
}
EOF

# Create minimal configuration.nix
echo "Creating configuration.nix..."
cat > /etc/nixos/configuration.nix << 'EOF'
{ pkgs, ... }: {
  imports = [ ./hardware-configuration.nix ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking = {
    hostName = "nixos-manager";
    networkmanager.enable = true;
    firewall.allowedTCPPorts = [ 22 ];
    firewall.trustedInterfaces = [ "tailscale0" ];
  };

  time.timeZone = "Australia/Sydney";
  i18n.defaultLocale = "en_AU.UTF-8";

  users.users.admin = {
    isNormalUser = true;
    extraGroups = [ "networkmanager" "wheel" ];
    initialPassword = "changeme";
  };

  environment.systemPackages = with pkgs; [
    wget curl vim git htop tailscale
  ];

  services.tailscale.enable = true;
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = true;
      PermitRootLogin = "yes";
    };
  };

  nixpkgs.config.allowUnfree = true;
  system.stateVersion = "25.05";
}
EOF

echo "Building and applying configuration..."
cd /etc/nixos

# Build and switch
nixos-rebuild switch --flake .#manager

echo ""
echo "=== Setup Complete! ==="
echo ""
echo "Services started:"
echo "- SSH (port 22)"
echo "- Tailscale (run 'tailscale up' to connect)"
echo ""
echo "User created:"
echo "- Username: admin"
echo "- Password: changeme (change this!)"
echo ""
echo "Quick commands:"
echo "- Connect Tailscale: tailscale up"
echo "- Get Tailscale IP: tailscale ip"
echo "- Change password: passwd admin"
echo "- Edit config: vim /etc/nixos/configuration.nix"
echo "- Apply changes: nixos-rebuild switch --flake .#manager"
echo ""
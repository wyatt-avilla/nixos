{ config, pkgs, ... }:
{
  imports = [
    ./hardware-configuration.nix
    ./sops.nix
    ./ssh.nix
    ./syncthing.nix
  ];

  nixpkgs.config.allowUnfree = true;
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  boot.loader = {
    systemd-boot.enable = true;
    efi.canTouchEfiVariables = true;
  };

  networking.hostName = "barachiel";
  networking.networkmanager.enable = true;

  time.timeZone = "America/Los_Angeles";

  i18n.defaultLocale = "en_US.UTF-8";

  i18n.extraLocaleSettings = {
    LC_ADDRESS = "en_US.UTF-8";
    LC_IDENTIFICATION = "en_US.UTF-8";
    LC_MEASUREMENT = "en_US.UTF-8";
    LC_MONETARY = "en_US.UTF-8";
    LC_NAME = "en_US.UTF-8";
    LC_NUMERIC = "en_US.UTF-8";
    LC_PAPER = "en_US.UTF-8";
    LC_TELEPHONE = "en_US.UTF-8";
    LC_TIME = "en_US.UTF-8";
  };

  services = {
    btrfs.autoScrub.enable = true;
    xserver.xkb = {
      layout = "us";
      variant = "";
    };
  };

  users.users.wyatt = {
    isNormalUser = true;
    description = "Wyatt Avilla";
    extraGroups = [
      "networkmanager"
      "wheel"
    ];
    packages = with pkgs; [ ];
  };

  environment.systemPackages = with pkgs; [
    vim
    wget
    git
  ];

  system.stateVersion = "24.11";
}

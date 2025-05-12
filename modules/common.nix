{
  inputs,
  config,
  pkgs,
  ...
}:
{
  imports = [ ./syncthing.nix ];

  nixpkgs.config.allowUnfree = true;
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  boot.tmp.cleanOnBoot = true;

  networking = {
    networkmanager.enable = true;
    firewall.allowedTCPPorts = [ 57621 ]; # spotify local files
    firewall.allowedUDPPorts = [ 5353 ]; # spotify cast
  };

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

  users.users.wyatt = {
    isNormalUser = true;
    description = "Wyatt Avilla";
    extraGroups = [
      "networkmanager"
      "wheel"
      "dialout"
    ];
    shell = pkgs.zsh;
    packages = with pkgs; [ ];
  };

  programs.hyprland = {
    enable = true;
    withUWSM = true;
    package = inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.hyprland;
    portalPackage =
      inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.xdg-desktop-portal-hyprland;
  };

  environment.systemPackages = with pkgs; [
    wget
    git
    home-manager
  ];

  programs.zsh.enable = true;

  security.doas = {
    enable = true;
    extraRules = [
      {
        keepEnv = true;
        groups = [ "wheel" ];
        noPass = true;
      }
    ];
  };
}

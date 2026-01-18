{
  users.users.wyatt.extraGroups = [ "docker" ];

  virtualisation.docker = {
    enable = true;
    rootless = {
      enable = true;
      setSocketVariable = true;
    };
  };
}

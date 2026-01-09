{ config, ... }:
let
  sshUser = "wyatt";
in
{
  sops.secrets.desktop-ssh-key = {
    mode = "0400";
  };

  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "no";
      PasswordAuthentication = false;
    };
  };

  users.users.${sshUser}.openssh.authorizedKeys.keyFiles = [
    config.sops.secrets.desktop-ssh-key.path
  ];
}

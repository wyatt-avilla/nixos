{
  sops.secrets.desktop-ssh-key = {
    path = "/etc/ssh/authorized_keys.d/wyatt";
    mode = "0444";
  };

  services.openssh = {
    enable = true;
    authorizedKeysFiles = [ "/etc/ssh/authorized_keys.d/%u" ];
    settings = {
      PermitRootLogin = "no";
      PasswordAuthentication = false;
    };
  };
}

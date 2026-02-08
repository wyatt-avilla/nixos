{
  lib,
  inputs,
  config,
  ...
}:
let
  inherit (config.variables) domain;
  clientSecretFile = "/etc/oauth2-proxy/client-secret";
  cookieSecretFile = "/etc/oauth2-proxy/cookie-secret";
  user = config.systemd.services.oauth2-proxy.serviceConfig.User;
in
{
  options.variables = {
    authAddress = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1:4180";
    };
  };

  config = {
    services.oauth2-proxy = {
      enable = true;

      provider = "google";

      clientID = inputs.nix-secrets.nixosModules.plainSecrets.vps.oauth2-client-id;

      email.addresses = lib.strings.concatLines [
        inputs.nix-secrets.nixosModules.plainSecrets.email.personal
      ];

      httpAddress = config.variables.authAddress;

      setXauthrequest = true;

      clientSecret = null;
      cookie.secret = null;

      extraConfig = {
        client-secret-file = clientSecretFile;
        cookie-secret-file = cookieSecretFile;

        redirect-url = "https://auth.${domain}/oauth2/callback";

        whitelist-domain = ".${domain}";

        cookie-domain = ".${domain}";
        cookie-secure = "true";

        cookie-expire = "${toString (7 * 24)}h";
        cookie-refresh = "1h";
      };
    };

    systemd.services =
      (config.secrets.mkCopyService {
        name = "oauth2-proxy-copy-client-secret";
        source = "${config.variables.secretsDirectory}/oauth2-client-secret";
        dest = clientSecretFile;
        inherit user;
        mode = "400";
      })
      // (config.secrets.mkCopyService {
        name = "oauth2-proxy-copy-cookie-secret";
        source = "${config.variables.secretsDirectory}/oauth2-cookie-secret";
        dest = cookieSecretFile;
        inherit user;
        mode = "400";
      });
  };
}

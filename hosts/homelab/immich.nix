{ inputs, config, ... }:
let
  user = "immich";
  clientSecretFile = "/etc/immich/oauth-client-secret";
in
{
  services.immich = {
    enable = true;
    openFirewall = true;
    accelerationDevices = null;
    mediaLocation = "${config.storageDir}/immich";
    host = config.variables.homelab.wireguard.ip;
    inherit user;
    inherit (config.variables.immich) port;

    settings = {
      server.externalDomain = "https://immich.${config.variables.domain}";

      passwordLogin.enabled = false;

      oauth = {
        enabled = true;
        issuerUrl = "https://accounts.google.com";
        clientId = inputs.nix-secrets.nixosModules.plainSecrets.vps.oauth2-client-id;
        clientSecret._secret = clientSecretFile;
        scope = "openid profile email";
        signingAlgorithm = "RS256";
        storageLabelClaim = "preferred_username";
        storageQuotaClaim = "immich_quota";
        defaultStorageQuota = 0;
        buttonText = "Sign in with Google";
        autoRegister = true;
        autoLaunch = true;
        mobileOverrideEnabled = true;
        mobileRedirectUri = "https://immich.${config.variables.domain}/api/oauth/mobile-redirect";
      };
    };
  };

  users.users.immich.extraGroups = [
    "video"
    "render"
  ];

  systemd.services = config.secrets.mkCopyService {
    name = "immich-oauth2-copy-client-secret";
    source = "${config.variables.secretsDirectory}/oauth2-client-secret";
    dest = clientSecretFile;
    inherit user;
    mode = "400";
  };
}

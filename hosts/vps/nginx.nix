{ inputs, config, ... }:
let
  inherit (config.variables) domain;
  proxyPass = "http://${config.variables.authAddress}";
in
{
  services.nginx = {
    enable = true;
    recommendedProxySettings = true;
    recommendedTlsSettings = true;
    recommendedOptimisation = true;
    recommendedGzipSettings = true;

    virtualHosts = {
      "auth.${domain}" = {
        enableACME = true;
        forceSSL = true;

        locations."/" = {
          inherit proxyPass;
          extraConfig = ''
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Scheme $scheme;
            proxy_set_header X-Auth-Request-Redirect $request_uri;
          '';
        };
      };

      "filebrowser.${domain}" = {
        enableACME = true;
        forceSSL = true;

        locations."/" = {
          proxyPass = "http://${config.variables.homelab.wireguard.ip}:8789";
          extraConfig = ''
            auth_request /oauth2/auth;
            error_page 401 = /oauth2/sign_in;

            auth_request_set $user $upstream_http_x_auth_request_user;
            auth_request_set $email $upstream_http_x_auth_request_email;
            proxy_set_header X-User $user;
            proxy_set_header X-Email $email;

            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;

            client_max_body_size 50G;
          '';
        };

        locations."/oauth2/" = {
          inherit proxyPass;
          extraConfig = ''
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Scheme $scheme;
            proxy_set_header X-Auth-Request-Redirect $request_uri;
          '';
        };
      };
    };
  };

  security.acme = {
    acceptTerms = true;
    defaults.email = inputs.nix-secrets.nixosModules.plainSecrets.personalEmail;
  };
}

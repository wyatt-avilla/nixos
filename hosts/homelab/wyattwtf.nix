{ inputs, config, ... }:
let
  lastfmApiKeyPath = "/var/lib/wyattwtf/lastfm-api-key";
  goodreadsRssUrlPath = "/var/lib/wyattwtf/goodreads-rss-url";

  inherit (config.services.wyattwtf) user group;
in
{
  imports = [ inputs.wyattwtf.nixosModules.wyattwtf ];

  services.wyattwtf = {
    enable = true;

    inherit lastfmApiKeyPath goodreadsRssUrlPath;
    letterboxdRssUrl = "https://letterboxd.com/wyattwtf/rss/";
  };

  systemd.services =
    (config.secrets.mkCopyService {
      name = "wyattwtf-lastfm-api-key";
      source = "${config.variables.secretsDirectory}/lastfm-api-key";
      dest = lastfmApiKeyPath;
      inherit user group;
      consumerService = config.systemd.services.wyattwtf;
    })
    // (config.secrets.mkCopyService {
      name = "wyattwtf-goodreads-rss-url";
      source = "${config.variables.secretsDirectory}/goodreads-rss-url";
      dest = goodreadsRssUrlPath;
      inherit user group;
      consumerService = config.systemd.services.wyattwtf;
    });
}

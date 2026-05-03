{ inputs, config, ... }:
{
  imports = [ inputs.wyattwtf.nixosModules.wyattwtf ];

  services.wyattwtf = {
    enable = true;

    lastfmApiKeyPath = "${config.variables.secretsDirectory}/lastfm-api-key";
    goodreadsRssUrlPath = "${config.variables.secretsDirectory}/goodreads-rss-url";
    letterboxdRssUrl = "https://letterboxd.com/wyattwtf/rss/";
  };
}

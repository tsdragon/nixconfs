{
  pkgs,
  inputs,
  config,
  ...
}: let
  # Instantiate firefox-addons through its overlay against the current pkgs.
  # This keeps addon builds aligned with this config (including allowUnfree).
  firefoxAddons = (inputs.firefox-addons.overlays.default pkgs pkgs)."firefox-addons";

  secrets = import ../../../secrets/location.nix;
in {
  programs.zen-browser = {
    enable = true;
    setAsDefaultBrowser = false;

    profiles = {
      ${config.home.username} = {
        isDefault = true;
        path = "myprofile";

        extensions.packages = with firefoxAddons; [
          bitwarden
          ublock-origin
          sponsorblock
          clearurls
          youtube-high-definition
          youtube-shorts-block
          #darkreader
          betterttv
          multi-account-containers
        ];

        search = {
          engines = {
            "Nix Packages" = {
              urls = [
                {
                  template = "https://search.nixos.org/packages";
                  params = [
                    {
                      name = "type";
                      value = "packages";
                    }
                    {
                      name = "channel";
                      value = "26.05";
                    }
                    {
                      name = "query";
                      value = "{searchTerms}";
                    }
                  ];
                }
              ];
              icon = "${pkgs.nixos-icons}/share/icons/hicolor/scalable/apps/nix-snowflake.svg";
              definedAliases = ["@n"];
            };
          };

          force = true;
        };

        settings = {
          "extensions.autoDisableScopes" = 0;
          "extensions.enabledScopes" = 15;
          "browser.disableResetPrompt" = true;
          "browser.download.panel.shown" = true;
          "browser.newtabpage.activity-stream.showSponsoredTopSites" = false;
          "browser.shell.checkDefaultBrowser" = false;
          "browser.shell.defaultBrowserCheckCount" = 1;

          "dom.security.https_only_mode" = true;

          "privacy.trackingprotection.enabled" = true;

          # WORKAROUND(2026-06-10): Keep site dark-mode detection working with
          # tracking protection.
          "privacy.resistFingerprinting" = false;
          "layout.css.prefers-color-scheme.content-override" = 0;
          "signon.rememberSignons" = false;

          # Accurate geolocation on desktop
          "geo.enabled" = true;
          "geo.provider.network.url" = secrets.myLocation;
          "geo.provider.testing" = true;
          "geo.provider.use_geoclue" = false;
        };
      };
    };
  };
}

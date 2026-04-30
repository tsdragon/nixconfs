{
  pkgs,
  inputs,
  config,
  ...
}: let
  # Instantiate firefox-addons through its overlay against the current pkgs.
  # This keeps addon builds aligned with this config (including allowUnfree).
  firefoxAddons = (inputs.firefox-addons.overlays.default pkgs pkgs)."firefox-addons";
  bitwardenWidget = "_446900e4-71c2-419f-a6a7-df9c091e268b_-browser-action";
  toolbarState = builtins.toJSON {
    placements = {
      "widget-overflow-fixed-list" = [];
      "nav-bar" = [
        "back-button"
        "forward-button"
        "stop-reload-button"
        "home-button"
        "urlbar-container"
        "downloads-button"
        "library-button"
        bitwardenWidget
        "unified-extensions-button"
      ];
      "toolbar-menubar" = ["menubar-items"];
      "TabsToolbar" = ["tabbrowser-tabs" "new-tab-button" "alltabs-button"];
      "PersonalToolbar" = ["import-button" "personal-bookmarks"];
    };
    seen = [
      "save-to-pocket-button"
      "developer-button"
      bitwardenWidget
    ];
    dirtyAreaCache = [
      "nav-bar"
      "PersonalToolbar"
      "toolbar-menubar"
      "TabsToolbar"
      "widget-overflow-fixed-list"
    ];
    currentVersion = 23;
    newElementCount = 1;
  };

  secrets = import ../../../secrets/location.nix;
in {
  programs.firefox = {
    enable = true;
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

        search.engines = {
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
                    value = "25.11";
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

        search.force = true;

        settings = {
          "extensions.autoDisableScopes" = 0;
          "extensions.enabledScopes" = 15;
          "browser.disableResetPrompt" = true;
          "browser.download.panel.shown" = true;
          "browser.newtabpage.activity-stream.showSponsoredTopSites" = false;
          "browser.shell.checkDefaultBrowser" = false;
          "browser.shell.defaultBrowserCheckCount" = 1;
          #"browser.startup.homepage" = "https://start.duckduckgo.com";

          "browser.uiCustomization.state" = toolbarState;
          "dom.security.https_only_mode" = true;
          #"identity.fxaccounts.enabled" = false;

          "privacy.trackingprotection.enabled" = true;

          #fix dark mode after enabling tracking protection
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

  #myHomeManager.impermanence = {
  #  directories = [
  #    ".mozilla"
  #    ".cache/mozilla"
  #  ];
  #
  #  # We want to preserve only these handful of files in the `myprofile` directory:
  #  persistence = {
  #    # Cookies:
  #    ".mozilla/firefox/myprofile/cookies.sqlite" = { };
  #    ".mozilla/firefox/myprofile/key4.db" = { };
  #
  #    # History & bookmarks:
  #    ".mozilla/firefox/myprofile/places.sqlite" = { };
  #
  #    # If you want to keep saved logins:
  #    ".mozilla/firefox/myprofile/logins.json" = { };
  #
  #    # If you want to keep extension settings:
  #    ".mozilla/firefox/myprofile/storage/default/moz-extension+++*" = { directory = true; };
  #
  #    # If you want to restore tabs, also preserve sessionstore:
  #    # ".mozilla/firefox/myprofile/sessionstore.jsonlz4" = { };
  #    # ".mozilla/firefox/myprofile/sessionstore-backups" = { directory = true; };
  #  };
  #};
}

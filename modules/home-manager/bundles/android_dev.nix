{
  config,
  pkgs,
  lib,
  ...
}: let
  androidPkgs = pkgs.androidenv.androidPkgs;
  # Use a writable SDK path so Gradle can install missing components.
  useNixSdk = false;
  hasSdk = androidPkgs ? androidsdk;
  sdkRoot =
    if useNixSdk && hasSdk
    then "${androidPkgs.androidsdk}/libexec/android-sdk"
    else "${config.home.homeDirectory}/Android/Sdk";

  androidSdkPackages =
    lib.optionals (useNixSdk && hasSdk) [androidPkgs.androidsdk]
    ++ lib.optionals (!useNixSdk) (lib.optionals (androidPkgs ? "cmdline-tools-latest") [
      androidPkgs."cmdline-tools-latest"
    ])
    ++ lib.optionals (!useNixSdk) (lib.optionals (androidPkgs ? "platform-tools") [
      androidPkgs."platform-tools"
    ]);
in {
  nixpkgs.config.android_sdk.accept_license = true;

  home.packages = with pkgs;
    [
      jdk17
      gradle
      kotlin
      cmake
      ninja
    ]
    ++ androidSdkPackages;

  home.sessionVariables = {
    ANDROID_SDK_ROOT = lib.mkDefault sdkRoot;
    ANDROID_HOME = lib.mkDefault sdkRoot;
    JAVA_HOME = "${pkgs.jdk17}";
  };

  home.sessionPath = [
    "$ANDROID_SDK_ROOT/platform-tools"
    "$ANDROID_SDK_ROOT/cmdline-tools/latest/bin"
    "$ANDROID_SDK_ROOT/emulator"
  ];
}

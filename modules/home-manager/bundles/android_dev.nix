{ config, pkgs, lib, ... }:

let
  androidPkgs = pkgs.androidenv.androidPkgs;
  hasSdk = androidPkgs ? androidsdk;
  sdkRoot =
    if hasSdk
    then "${androidPkgs.androidsdk}/libexec/android-sdk"
    else "${config.home.homeDirectory}/Android/Sdk";

  androidSdkPackages =
    lib.optionals hasSdk [ androidPkgs.androidsdk ]
    ++ lib.optionals (!hasSdk) (lib.optionals (androidPkgs ? "cmdline-tools-latest") [
      androidPkgs."cmdline-tools-latest"
    ])
    ++ lib.optionals (!hasSdk) (lib.optionals (androidPkgs ? "platform-tools") [
      androidPkgs."platform-tools"
    ]);
in
{
  home.packages = with pkgs; [
    jdk17
    gradle
    kotlin
    cmake
    ninja
  ] ++ androidSdkPackages;

  home.sessionVariables = {
    ANDROID_SDK_ROOT = sdkRoot;
    ANDROID_HOME = sdkRoot;
    JAVA_HOME = "${pkgs.jdk17}";
  };

  home.sessionPath = [
    "$ANDROID_SDK_ROOT/platform-tools"
    "$ANDROID_SDK_ROOT/cmdline-tools/latest/bin"
    "$ANDROID_SDK_ROOT/emulator"
  ];
}

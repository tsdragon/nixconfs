{ lib, pkgs, ... }:

let
  ai-file-sorter = pkgs.stdenv.mkDerivation (finalAttrs: {
    pname = "ai-file-sorter";
    version = "1.4.0";

    src = pkgs.fetchFromGitHub {
      owner = "hyperfield";
      repo = "ai-file-sorter";
      rev = "v${finalAttrs.version}";
      fetchSubmodules = true;
      hash = "sha256-tFqalxQ4B9i2OPtrpwBPqhhhLkXaDO6zW0x812i9yIs=";
    };

    sourceRoot = "source/app";

    nativeBuildInputs = [
      pkgs.cmake
      pkgs.ninja
      pkgs.pkg-config
      pkgs.git
      pkgs.copyDesktopItems
      pkgs.qt6.wrapQtAppsHook
    ];

    buildInputs = [
      pkgs.curl
      pkgs.fmt
      pkgs.gettext
      pkgs.jsoncpp
      pkgs.openblas
      pkgs.openssl
      pkgs.qt6.qtbase
      pkgs.qt6.qttools
      pkgs.spdlog
      pkgs.sqlite
      pkgs.xorg.libX11
    ];

    desktopItems = [
      (pkgs.makeDesktopItem {
        name = "aifilesorter";
        exec = "aifilesorter";
        icon = "aifilesorter";
        desktopName = "AI File Sorter";
        comment = "AI-powered file organization desktop app";
        categories = [ "Office" "Utility" ];
      })
    ];

    postPatch = ''
      substituteInPlace CMakeLists.txt \
        --replace-fail '
# JsonCpp may not ship a CMake config on some distros (e.g. Ubuntu). Try
# config mode first, then fall back to pkg-config.
find_package(JsonCpp CONFIG QUIET)
if(NOT JsonCpp_FOUND)
    find_package(PkgConfig REQUIRED)
    pkg_check_modules(JSONCPP REQUIRED jsoncpp)
    add_library(JsonCpp::JsonCpp INTERFACE IMPORTED)
    target_include_directories(JsonCpp::JsonCpp INTERFACE ''${JSONCPP_INCLUDE_DIRS})
    target_link_directories(JsonCpp::JsonCpp INTERFACE ''${JSONCPP_LIBRARY_DIRS})
    target_link_libraries(JsonCpp::JsonCpp INTERFACE ''${JSONCPP_LINK_LIBRARIES})
else()
    if(NOT TARGET JsonCpp::JsonCpp)
        add_library(JsonCpp::JsonCpp INTERFACE IMPORTED)
    endif()
endif()
find_package(fmt REQUIRED CONFIG)
' '
find_package(PkgConfig REQUIRED)
pkg_check_modules(JSONCPP REQUIRED jsoncpp)
include_directories(''${JSONCPP_INCLUDE_DIRS})
add_library(JsonCpp::JsonCpp INTERFACE IMPORTED)
target_include_directories(JsonCpp::JsonCpp INTERFACE ''${JSONCPP_INCLUDE_DIRS})
target_link_directories(JsonCpp::JsonCpp INTERFACE ''${JSONCPP_LIBRARY_DIRS})
target_link_libraries(JsonCpp::JsonCpp INTERFACE ''${JSONCPP_LINK_LIBRARIES})
find_package(fmt REQUIRED CONFIG)
'
    '';

    postConfigure = ''
      substituteInPlace ../lib/ConsistencyPassService.cpp \
        --replace-fail '<jsoncpp/json/json.h>' '<json/json.h>'
      substituteInPlace ../lib/LLMClient.cpp \
        --replace-fail '<jsoncpp/json/json.h>' '<json/json.h>'
      substituteInPlace ../lib/Updater.cpp \
        --replace-fail '<jsoncpp/json/json.h>' '<json/json.h>'
    '';

    cmakeFlags = [
      "-DAI_FILE_SORTER_BUILD_TESTS=OFF"
      "-DGGML_CCACHE=OFF"
    ];

    installPhase = ''
      runHook preInstall
      mkdir -p $out/bin
      mkdir -p $out/share/icons/hicolor/256x256/apps
      cp aifilesorter $out/bin/aifilesorter
      cp ../resources/images/app_icon_256.png $out/share/icons/hicolor/256x256/apps/aifilesorter.png
      runHook postInstall
    '';

    meta = with lib; {
      description = "AI-powered desktop app for organizing files";
      homepage = "https://github.com/hyperfield/ai-file-sorter";
      license = licenses.agpl3Only;
      mainProgram = "aifilesorter";
      platforms = platforms.linux;
    };
  });
in {
  home.packages = [ ai-file-sorter ];
}

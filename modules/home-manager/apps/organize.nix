{ lib, pkgs, ... }:

let
  pythonPackages = pkgs.python3Packages.overrideScope (
    final: prev: {
      simplematch = final.buildPythonPackage rec {
        pname = "simplematch";
        version = "1.4";
        pyproject = true;

        src = pkgs.fetchPypi {
          inherit pname version;
          hash = "sha256-VadyeLPQaGyzjj/+WjJqX1nCmV8bofoaT2iHLBfK9Ms=";
        };

        build-system = [
          final.poetry-core
        ];

        pythonImportsCheck = [ "simplematch" ];

        meta = with lib; {
          description = "Minimal, super readable string pattern matcher";
          homepage = "https://pypi.org/project/simplematch/";
          license = licenses.mit;
        };
      };
    }
  );

  organize-tool = pythonPackages.buildPythonApplication rec {
    pname = "organize-tool";
    version = "3.3.0";
    pyproject = true;

    src = pkgs.fetchPypi {
      inherit pname version;
      hash = "sha256-A0/c+f/rI9IbSV4DhmUnjlifoE3HwMCgGko7MKBsU58=";
    };

    build-system = [
      pythonPackages.setuptools
    ];

    dependencies = [
      pythonPackages.arrow
      pythonPackages."docopt-ng"
      pythonPackages.docx2txt
      pythonPackages.exifread
      pythonPackages.jinja2
      pythonPackages.natsort
      pythonPackages."pdfminer-six"
      pythonPackages.platformdirs
      pythonPackages.pydantic
      pythonPackages.pyyaml
      pythonPackages.rich
      pythonPackages.send2trash
      pythonPackages.simplematch
    ];

    pythonImportsCheck = [ "organize" ];

    meta = with lib; {
      description = "File management automation tool";
      homepage = "https://github.com/tfeldmann/organize";
      changelog = "https://tfeldmann.github.io/organize/changelog/";
      license = licenses.mit;
      mainProgram = "organize";
      platforms = platforms.linux ++ platforms.darwin;
    };
  };
in {
  home.packages = [ organize-tool ];
}

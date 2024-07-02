{ python3
, fetchFromGitHub
, path
, ...
}:
let
  poetryPath = "${path}/pkgs/tools/package-management/poetry";
  python = python3.override {
    packageOverrides = self: super: let
      resolvedPlugins = plugins self;
    in resolvedPlugins // {
      poetry = (self.callPackage "${poetryPath}/unwrapped.nix" {}).overridePythonAttrs (old: rec {
        version = "1.3.2";
        src = fetchFromGitHub {
          owner = "python-poetry";
          repo = "poetry";
          rev = "refs/tags/v${version}";
          hash = "sha256-12EiEGI9Vkb6EUY/W2KWeLigxWra1Be4ozvi8njBpEU=";
        };
        disabledTests = old.disabledTests ++ [
          "test_builder_setup_generation_runs_with_pip_editable"
        ];
      });
      poetry-core = super.poetry-core.overridePythonAttrs (old: rec {
        version = "1.4.0";
        src = fetchFromGitHub {
          owner = "python-poetry";
          repo = "poetry-core";
          rev = version;
          hash = "sha256-SCzs2v0LIgx3vBYTavPqc7uwAQdWsdmkbDyHgIjOxrk=";
        };
      });
      poetry-plugin-export = resolvedPlugins.poetry-plugin-export.overridePythonAttrs (old: rec {
        version = "1.2.0";
        src = fetchFromGitHub {
          owner = "python-poetry";
          repo = "poetry-plugin-export";
          rev = "refs/tags/${version}";
          hash = "sha256-xrAGjHFYRT6n+r/16b0xyoI7+1Q1Hsw3lEK92UabIqo=";
        };
      });
      # version override required by poetry and its plugins
      cachecontrol = super.cachecontrol.overridePythonAttrs (old: rec {
        version = "0.12.11";
        src = fetchFromGitHub {
          owner = "ionrock";
          repo = "cachecontrol";
          rev = "refs/tags/v${version}";
          hash = "sha256-uUPIQz/n347Q9G7NDOGuB760B/KxOglUxiS/rYjt5Po=";
        };
        nativeBuildInputs = old.nativeBuildInputs ++ [
          self.setuptools
        ];
        doCheck = false;
      });
      dulwich = super.dulwich.overridePythonAttrs (old: rec {
        version = "0.20.50";
        src = self.fetchPypi {
          inherit (old) pname;
          inherit version;
          hash = "sha256-UKlBeWssZ1vjm+co1UDBa1t853654bP4VWUOzmgy0r4=";
        };
      });
      keyring = super.keyring.overridePythonAttrs (old: rec {
        version = "23.11.0";
        src = fetchFromGitHub {
          owner = "jaraco";
          repo = "keyring";
          rev = "refs/tags/v${version}";
          hash = "sha256-gig1q6eN2tFEGPlM1xeQqF7qdf3FUHn9YETQXuz+q/Y=";
        };
        nativeBuildInputs = [ self.setuptools-scm ];
        SETUPTOOLS_SCM_PRETEND_VERSION = version;
      });
      platformdirs = super.platformdirs.overridePythonAttrs (old: rec {
        version = "2.6.2";
        src = fetchFromGitHub {
          owner = "platformdirs";
          repo = "platformdirs";
          rev = "refs/tags/${version}";
          hash = "sha256-yGpDAwn8Kt6vF2K2zbAs8+fowhYQmvsm/87WJofuhME=";
        };
        SETUPTOOLS_SCM_PRETEND_VERSION = version;
      });
      # newer version of pluggy broke virtualenv
      # https://github.com/NixOS/nixpkgs/pull/240480#issuecomment-1636693741
      pluggy = super.pluggy.overridePythonAttrs (old: rec {
        version = "1.0.0";
        src = fetchFromGitHub {
          owner = "pytest-dev";
          repo = "pluggy";
          rev = "refs/tags/${version}";
          hash = "sha256-X72JvAj9pN2JF9RzIfO8q955sOlblNMYF8VgOIwBcUY=";
        };
      });
      requests-toolbelt = super.requests-toolbelt.overridePythonAttrs (old: rec {
        version = "0.10.1";
        src = self.fetchPypi {
          inherit version;
          pname = "requests-toolbelt";
          hash = "sha256-YuCff/XMvakncqKfOUpJw61ssYHVaLEzdiayq7Yopj0=";
        };
      });
      virtualenv = super.virtualenv.overridePythonAttrs (old: rec {
        # v20.22.0 requires platformdirs 3.x
        version = "20.21.1";
        src = fetchFromGitHub {
          owner = "pypa";
          repo = "virtualenv";
          rev = "refs/tags/${version}";
          hash = "sha256-zlzYXjVn99sAGub4CQ2JUaIfBFR1nz3W+UbownBu92o=";
        };
        SETUPTOOLS_SCM_PRETEND_VERSION = version;
      });
      yapf = super.yapf.overridePythonAttrs (old: rec {
        # v0.40.0 requires platformdirs 3.x
        version = "0.32.0";
        src = self.fetchPypi {
          inherit version;
          pname = "yapf";
          hash = "sha256-o/UIXTfvfj4ATEup+bPkDFT/GQHNER8FFFrjE6fGfRs=";
        };
      });
    };
  };

  plugins = ps: with ps; {
    poetry-audit-plugin = callPackage "${poetryPath}/plugins/poetry-audit-plugin.nix" { };
    poetry-plugin-export = callPackage "${poetryPath}/plugins/poetry-plugin-export.nix" { };
    poetry-plugin-up = callPackage "${poetryPath}/plugins/poetry-plugin-up.nix" { };
  };

  # selector is a function mapping pythonPackages to a list of plugins
  # e.g. poetry.withPlugins (ps: with ps; [ poetry-plugin-up ])
  withPlugins = selector: let
    selected = selector (plugins python.pkgs);
  in python.pkgs.toPythonApplication (python.pkgs.poetry.overridePythonAttrs (old: {
    propagatedBuildInputs = old.propagatedBuildInputs ++ selected;

    # save some build time when adding plugins by disabling tests
    doCheck = selected == [ ];

    # Propagating dependencies leaks them through $PYTHONPATH which causes issues
    # when used in nix-shell.
    postFixup = ''
      rm $out/nix-support/propagated-build-inputs
    '';

    passthru = {
      plugins = plugins python.pkgs;
      inherit withPlugins python;
    };
  }));
in withPlugins (ps: [ ])

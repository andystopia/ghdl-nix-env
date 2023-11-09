{
  description = "Download GHDL v3.0.0 MacOS11-llvm, or MacOS11-mcode, collect deps, fix-up llvm path, and create a devshell";
  inputs = {
    fenix = {
      url = "github:nix-community/fenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixpkgs.url = "nixpkgs/nixos-unstable";
  };

  outputs = {
    self,
    nixpkgs,
    fenix,
  }: let
    supportedSystems = ["x86_64-darwin" "aarch64-darwin"];
    forAllSystems = nixpkgs.lib.genAttrs supportedSystems;

    # unfortunately, due to a lack of arm builds,
    # and my inability to create them, this software
    # needs to be run under Rosetta. So even, though,
    # we "support" ARM machines, we don't support ARM builds.
    pkgsFor = forAllSystems (system: import nixpkgs {system = "x86_64-darwin";});
  in rec {
    packages = forAllSystems (
      system: let
        pkgs = pkgsFor.${system};

        legacyPkgs = nixpkgs.legacyPackages.${system};
        toolchain = fenix.packages.${system}.minimal.toolchain;

        basePkgs = with pkgs; [
          gtkwave # we want to be able to view the generated vcd files
          zlib # for some reason -lz is passed to the linker by ghdl
          (python39.withPackages (ps: with ps; [tkinter])) # python wants tkinter for vcd_movie
        ];       
      in  {
        # we download the ghdl package, and it should work
        # with just a couple inputs
        ghdl-llvm = pkgs.stdenvNoCC.mkDerivation {
          # we will need to edit the library
          # search path for VHDL.
          nativeBuildInputs = with pkgs; [
            llvmPackages_15.bintools
          ];

          # we will need to have libllvm
          # as a dependency
          buildInputs = with pkgs; [
            llvmPackages_15.libllvm
          ];

          name = "ghdl";
          src = builtins.fetchurl {
            url = "https://github.com/ghdl/ghdl/releases/download/v3.0.0/ghdl-macos-11-llvm.tgz";
            sha256 = "sha256-y4xq0+Z2Pnw0bM7hEdr3YUFsfVSsBwT4olYGQfw8LYU=";
          };
          phases = ["unpackPhase" "installPhase"];
          unpackPhase = "mkdir extract && tar -xzvf $src -C extract";
          installPhase = ''
            # first fix the path of the downloaded binary to be what we'd expect
            llvm-install-name-tool -change /usr/local/opt/llvm/lib/libLLVM.dylib $(llvm-config --libdir --link-shared)/libLLVM.dylib extract/bin/ghdl1-llvm
            # and move it to the output where we can execute it
            cp -R extract/ $out
          '';
        };

        # include my ghdl based build tool
        gb =
          (legacyPkgs.makeRustPlatform {
            cargo = toolchain;
            rustc = toolchain;
          })
          .buildRustPackage rec {
            nativeBuildInputs = with pkgs; [llvmPackages_15.bintools];
            buildInputs = [packages.ghdl-llvm];
            pname = "gb";
            version = "0.1.0";

            src = pkgs.lib.cleanSource (pkgs.fetchFromGitHub {
              owner = "andystopia";
              repo = "gb";
              rev = "e9f6ba61daf08e11f847cd31c61e658b0a395d72";
              hash = "sha256-FJUEantrz4+6cWsSPy42no2ktXzs+yVKxiYt1Fh4rG4=";
              fetchSubmodules = true;
            });

            cargoLock.lockFile = "${src}/Cargo.lock";
            cargoLock.allowBuiltinFetchGit = true;
          };

        ghdl-mcode = pkgs.stdenvNoCC.mkDerivation {
          src = builtins.fetchurl {
            url = "https://github.com/ghdl/ghdl/releases/download/v0.36/ghdl-0.36-macosx-mcode.tgz";
            sha256 = "sha256:0qxbav1jbr6lnh7v4ldxv32s473c1lsq4b37x8k4vwp39n0s0sf4";
          };

          name = "ghdl-mcode";
          phases = ["unpackPhase" "installPhase"];

          unpackPhase = "mkdir extract && tar -xzvf $src -C extract";
          installPhase = ''
            cp -R extract/ $out
          '';
        };
      }
    );
    devShells = forAllSystems (
      system: let
        pkgs = pkgsFor.${system};

        basePkgs = with pkgs; [
          gtkwave # we want to be able to view the generated vcd files
          zlib # for some reason -lz is passed to the linker by ghdl
          (python39.withPackages (ps: with ps; [tkinter])) # python wants tkinter for vcd_movie
        ];
        # ghdl expects to have clang 15 at runtime
        stdenv = pkgs.llvmPackages_15.stdenv;

        shellHook = ''
          # make the prompt pretty :)
          eval "$(starship init bash)"
        '';
        # toolchain = fenixPkgs.default.toolchain;
      in {
        # create a bare bones devshell
        default = stdenv.mkDerivation {
          name = "ghdl-devshell";
          buildInputs = basePkgs;
        };
        # create a nicer dev environment shell
        nice-llvm = stdenv.mkDerivation {
          name = "ghdl-devshell-fancy-llvm";
          buildInputs =
            basePkgs
            ++ (with pkgs; [
              starship # I like a nice bash prompt
              just # A simple command runner
            ])
            ++
            # and of course, we need to include our ghdl binary
            [packages.ghdl-llvm];
          inherit shellHook;
        };

        nice-mcode = stdenv.mkDerivation {
          name = "ghdl-devshell-mcode";
          buildInputs =
            basePkgs
            ++ (with pkgs; [
              starship # I like a nice bash prompt
              just # A simple command runner
            ])
            ++
            # and of course, we need to include our ghdl binary
            [packages.${system}.ghdl-mcode];

          inherit shellHook;
        };
        all = stdenv.mkDerivation {
          name = "ghdl-devshell-all";
          buildInputs =
            basePkgs
            ++ (with pkgs; [
              starship # I like a nice bash prompt
              just # A simple command runner
            ])
            ++ [packages.gb packages.ghdl-mcode];

          shellHook = ''
            # make the prompt pretty :)
            eval "$(starship init bash)"
          '';
        };
      }
    );

    formatter = forAllSystems (
      system:
        pkgsFor.${system}.alejandra
    );
  };
}

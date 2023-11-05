{
  description = "Download GHDL v3.0.0 MacOS11-llvm, collect deps, fix-up llvm path, and create a devshell";
  inputs = {
    nixpkgs.url = "nixpkgs/nixos-23.05";
  };

  outputs = { self, nixpkgs }:
	   	let
				supportedSystems = ["x86_64-darwin" "aarch64-darwin"];
				forAllSystems = nixpkgs.lib.genAttrs supportedSystems;

				
				# unfortunately, due to a lack of arm builds,
				# and my inability to create them, this software
				# needs to be run under Rosetta. So even, though, 
				# we "support" ARM machines, we don't support ARM builds.
				pkgsFor = forAllSystems (system: import nixpkgs { system = "x86_64-darwin"; });
    	in rec {

		    packages = forAllSystems(system:
					let 
						pkgs = pkgsFor.${system};
					in
					{
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
				});



				# This is the same devshell for x86 as well, so just change the arch

				devShells = forAllSystems(system: 
					let 
            pkgs = pkgsFor.${system};
            # add our base set of dependencies here
            basePkgs = with pkgs; [
									gtkwave # we want to be able to view the generated vcd files
									zlib # for some reason -lz is passed to the linker by ghdl
									(python39.withPackages(ps: with ps; [ tkinter ])) # python wants tkinter for vcd_movie
            ] ++ # and of course, we need to include our ghdl binary
						[packages.${system}.ghdl-llvm];


						# ghdl expects to have clang 15 at runtime
						stdenv = pkgs.llvmPackages_15.stdenv;
       
					in {
						# create a bare bones devshell
						default = stdenv.mkDerivation {
							name = "ghdl-devshell";
		          buildInputs = basePkgs;
  	        };
						# create a nicer dev environment shell
						nice = stdenv.mkDerivation { 
							name = "ghdl-devshell-fancy";
							buildInputs = basePkgs ++ (with pkgs; [
								starship # I like a nice bash prompt
								just     # A simple command runner
							]);

							
							shellHook = ''
									# make the prompt pretty :)
									eval "$(starship init bash)"
							'';
		 				};
  				}
				);
     };
}

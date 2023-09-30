{
  description = "A flake which downloads GHDL v3.0.0 MacOS11-llvm, installs LLVM and sets the path correctly so that ghdl can compile";
  inputs = {
    nixpkgs.url = "nixpkgs/nixos-23.05";
  };

  outputs = { self, nixpkgs, flake-utils}:
	   	let
      	pkgs = nixpkgs.legacyPackages.x86_64-darwin;
    	in rec {
		    packages = {
		      myghdl = pkgs.stdenv.mkDerivation {

						name = "ghdl";
						src = builtins.fetchurl {
							url = "https://github.com/ghdl/ghdl/releases/download/v3.0.0/ghdl-macos-11-llvm.tgz";
							sha256 = "sha256-y4xq0+Z2Pnw0bM7hEdr3YUFsfVSsBwT4olYGQfw8LYU=";
						};
						phases = ["unpackPhase" "installPhase"];
						unpackPhase = "mkdir extract && tar -xzvf $src -C extract";
						installPhase = "ls extract/ && cp -R extract/ $out";
		     		};
				};



				# This is the same devshell for x86 as well, so just change the arch
        devShell.aarch64-darwin = pkgs.mkShell {
          name = "ghdl-devshell";
          buildInputs = [ 
						packages.myghdl # use the GHDL that we just unpacked from the website
						pkgs.llvmPackages_15.libllvm # `ghdl --version` says that it wants llvm 15.0.
						pkgs.llvmPackages_15.libclang # maybe we need clang too
						pkgs.gtkwave # we want to be able to view the generated vcd files
						pkgs.starship # I like a nice bash prompt
						pkgs.just # A simple command runner
					];  # Add any additional development tools or dependencies here
					shellHook = ''
							# make the prompt pretty :)
							eval "$(starship init bash)"

							# for ~some~ reason a broken clang 11 seems to get installed
							# too, we don't want this to lead the path, so let's just 
							# stick with the same versino of clang as llvm.
							export PATH="${pkgs.llvmPackages_15.libclang}/bin:$PATH"
							# set the path for clang
							export LIBCLANG_PATH="${pkgs.llvmPackages_15.libclang}/lib"
							# make sure ghdl can find llvm
							export DYLD_LIBRARY_PATH="$(llvm-config --libdir --link-shared)";
					'';
        };
		 };
}

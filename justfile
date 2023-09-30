build:
	git add flake.nix
	nix build .#ghdl --debug
shell:
	git add flake.nix
	nix develop
{
  nixConfig = {
    abort-on-warn = true;
    allow-import-from-derivation = false;
  };

  inputs = {
    files.url = "github:sini/files";

    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };

    git-hooks = {
      url = "github:cachix/git-hooks.nix";
      flake = false;
    };

    import-tree = {
      url = "github:vic/import-tree";
      flake = false;
    };

    make-shell = {
      url = "github:nicknovitski/make-shell";
      flake = false;
    };

    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    systems.url = "github:nix-systems/default";

    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      flake = false;
    };

    with-inputs = {
      url = "github:denful/with-inputs";
      flake = false;
    };
  };

  outputs = inputs: import ./outputs.nix inputs;
}

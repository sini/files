{
  inputs = {
    files.url = "github:sini/files";

    dag.url = "github:denful/dag";

    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };

    import-tree = {
      url = "github:vic/import-tree";
      flake = false;
    };

    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  };

  outputs =
    inputs: inputs.flake-parts.lib.mkFlake { inherit inputs; } ((import inputs.import-tree) ./modules);
}

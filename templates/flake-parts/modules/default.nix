{ inputs, ... }:
{
  imports = [
    inputs.files.flakeModule
    (inputs.treefmt-nix + "/flake-module.nix")
  ];

  systems = [
    "x86_64-linux"
    "aarch64-linux"
    "aarch64-darwin"
    "x86_64-darwin"
  ];
}

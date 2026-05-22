{
  outputs = _: {
    module = ./module.nix;
    flakeModule = ./flake-module.nix;
    flakeModules.default = ./flake-module.nix;
  };
}

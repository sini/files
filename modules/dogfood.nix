{ projectRoot, ... }:
{
  imports = [ ../flake-module.nix ];

  perSystem = psArgs: {
    treefmt = { inherit projectRoot; };
    files.root = projectRoot;
    make-shells.default.packages = [ psArgs.config.files.writer.drv ];
  };
}

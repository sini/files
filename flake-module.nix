# flake-parts wrapper around module.nix.
# Sets `self`-based defaults and wires treefmt to config.formatter.
{
  flake-parts-lib,
  lib,
  self,
  ...
}:
{
  options.perSystem = flake-parts-lib.mkPerSystemOption (
    { config, options, ... }:
    {
      imports = [ ./module.nix ];
      config = {
        files.root = lib.mkDefault self;
        files.treefmt.package = lib.mkIf (config.files.treefmt.enable && options.formatter.isDefined) (
          lib.mkDefault config.formatter
        );
        checks = config.files.checks;
        apps = lib.mkIf config.files.generateApp {
          ${config.files.writer.exeFilename} = {
            type = "app";
            program = lib.getExe config.files.writer.drv;
          };
          ${config.files.diff.exeFilename} = {
            type = "app";
            program = lib.getExe config.files.diff.drv;
          };
        };
      };
    }
  );
}

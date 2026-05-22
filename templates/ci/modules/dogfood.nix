{ inputs, ... }:
{
  perSystem =
    { config, ... }:
    {
      files.root = inputs.files;
      files.generateApp = true;
      files.treefmt.enable = true;
      make-shells.default.packages = [ config.files.writer.drv ];
    };
}

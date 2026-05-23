{ inputs, ... }:
{
  perSystem =
    { config, ... }:
    {
      files = {
        root = inputs.files;
        generateApp = true;
        treefmt.enable = true;
      };
      make-shells.default.packages = [ config.files.writer.drv ];
    };
}

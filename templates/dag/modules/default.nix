{
  lib,
  inputs,
  ...
}:
{
  imports = [ inputs.files.flakeModule ];

  options.flake.readme = lib.mkOption {
    type = lib.types.lazyAttrsOf lib.types.unspecified;
    default = { };
  };

  config = {
    _module.args.dag = inputs.dag.lib { inherit lib; };

    systems = [
      "x86_64-linux"
      "aarch64-linux"
      "aarch64-darwin"
      "x86_64-darwin"
    ];
  };
}

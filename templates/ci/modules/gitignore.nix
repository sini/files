{ lib, config, ... }:
{
  options.gitignore = lib.mkOption {
    type = lib.types.lines;
    apply =
      text:
      lib.pipe text [
        (lib.splitString "\n")
        lib.naturalSort
        (lib.concatStringsSep "\n")
      ];
  };
  config = {
    gitignore = ''
      .worktrees
      result
    '';
    perSystem =
      { pkgs, ... }:
      {
        files.files = [
          {
            path = ".gitignore";
            drv = pkgs.writeText ".gitignore" config.gitignore;
          }
        ];
      };
  };
}

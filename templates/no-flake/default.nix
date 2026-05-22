# No-flake usage: import files/module.nix directly with evalModules.
# Run: nix-build -A writer && ./result/bin/write-files
# Check: nix-build -A checks
{
  pkgs ? import <nixpkgs> { },
  files ? fetchGit {
    url = "https://github.com/sini/files";
    ref = "main";
  },
  root ? ./.,
}:
let
  eval = pkgs.lib.evalModules {
    modules = [
      (files + "/module.nix")
      {
        config._module.args = {
          inherit pkgs;
        };
        config.files.root = root;

        # --- files.file attrset API ---
        config.files.file.".gitignore".text = ''
          result
        '';

        config.files.file."README.md".text = ''
          # no-flake demo
          Uses `import` and `evalModules` — no flake required.
        '';

        # --- files.files list API ---
        config.files.files = [
          {
            path = "data/version.txt";
            drv = pkgs.writeText "version.txt" "0.1.0";
          }
        ];
      }
    ];
  };
in
{
  inherit (eval.config.files) checks;
  writer = eval.config.files.writer.drv;
}

# Vanilla flake using files via evalModules — no flake-parts dependency.
{
  inputs = {
    files.url = "github:sini/files";
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  };

  outputs =
    {
      self,
      files,
      nixpkgs,
      ...
    }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
      eval = pkgs.lib.evalModules {
        modules = [
          files.module
          {
            config._module.args = {
              inherit pkgs;
            };
            config.files.root = self;

            # --- files.file attrset API ---
            config.files.file.".gitignore".text = ''
              result
              .direnv
            '';

            config.files.file."README.md".text = ''
              # bare-flake demo
              Uses `evalModules` with `files.module` directly.
            '';

            config.files.file."scripts/hello.sh" = {
              text = ''
                #!/bin/sh
                echo "hello from bare flake!"
              '';
              executable = true;
            };

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
      checks.${system} = eval.config.files.checks;
      packages.${system}.write-files = eval.config.files.writer.drv;
      apps.${system}.write-files = {
        type = "app";
        program = pkgs.lib.getExe eval.config.files.writer.drv;
      };
    };
}

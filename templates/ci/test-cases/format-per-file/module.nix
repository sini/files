# Test that per-file format function transforms content
{
  perSystem =
    psArgs@{ pkgs, ... }:
    {
      files.file."upper.txt" = {
        text = "hello world";
        format =
          name: drv:
          pkgs.runCommand "upper-${name}" { } ''
            tr '[:lower:]' '[:upper:]' < ${drv} > $out
          '';
      };

      packages = {
        write-files = psArgs.config.files.writer.drv;
        default = pkgs.writeShellApplication {
          name = "script";
          text = ''
            nix run .#write-files
            git add --intent-to-add .
            nix flake check
            # verify content was uppercased by the formatter
            grep -q "HELLO WORLD" upper.txt
            declare out
            touch "$out"
          '';
        };
      };
    };
}

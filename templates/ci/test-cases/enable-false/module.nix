# Test that enable = false suppresses a file
{
  perSystem =
    psArgs@{ pkgs, ... }:
    {
      files.file."should-exist.txt".text = "yes";
      files.file."should-not-exist.txt" = {
        text = "no";
        enable = false;
      };

      packages = {
        write-files = psArgs.config.files.writer.drv;
        default = pkgs.writeShellApplication {
          name = "script";
          text = ''
            nix run .#write-files
            git add --intent-to-add .
            nix flake check
            # verify disabled file was not written
            ! test -f should-not-exist.txt
            declare out
            touch "$out"
          '';
        };
      };
    };
}

# Test that executable = true sets the execute bit
{
  perSystem =
    psArgs@{ pkgs, ... }:
    {
      files.file."run.sh" = {
        text = ''
          #!/bin/sh
          echo "hello"
        '';
        executable = true;
      };

      packages = {
        write-files = psArgs.config.files.writer.drv;
        default = pkgs.writeShellApplication {
          name = "script";
          text = ''
            nix run .#write-files
            git add --intent-to-add .
            # verify file is executable
            test -x run.sh
            declare out
            touch "$out"
          '';
        };
      };
    };
}

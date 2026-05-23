# Test that diff app detects stale files and reports up-to-date
{
  perSystem =
    psArgs@{ pkgs, ... }:
    {
      files.file."tracked.txt".text = "correct content";

      packages = {
        write-files = psArgs.config.files.writer.drv;
        diff-files = psArgs.config.files.diff.drv;
        default = pkgs.writeShellApplication {
          name = "script";
          text = ''
            # diff should fail when file is missing
            if nix run .#diff-files; then
              echo "diff should have failed on missing file"
              exit 1
            fi

            # write the file
            nix run .#write-files
            git add --intent-to-add .

            # diff should succeed when up to date
            nix run .#diff-files

            declare out
            touch "$out"
          '';
        };
      };
    };
}

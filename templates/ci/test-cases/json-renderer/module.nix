# Test that files.file.*.json serializes Nix values to JSON
{
  perSystem =
    psArgs@{ pkgs, ... }:
    {
      files.file."config.json".json = {
        version = 1;
        enabled = true;
      };

      packages = {
        write-files = psArgs.config.files.writer.drv;
        default = pkgs.writeShellApplication {
          name = "script";
          runtimeInputs = [ pkgs.jq ];
          text = ''
            nix run .#write-files
            git add --intent-to-add .
            nix flake check
            # verify JSON content
            test "$(jq .version config.json)" = "1"
            test "$(jq .enabled config.json)" = "true"
            declare out
            touch "$out"
          '';
        };
      };
    };
}

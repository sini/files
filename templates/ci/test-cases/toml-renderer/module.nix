# Test that files.file.*.toml serializes Nix values to TOML
{
  perSystem =
    psArgs@{ pkgs, ... }:
    {
      files.file."config.toml".toml = {
        database.host = "localhost";
        database.port = 5432;
      };

      packages = {
        write-files = psArgs.config.files.writer.drv;
        default = pkgs.writeShellApplication {
          name = "script";
          text = ''
            nix run .#write-files
            git add --intent-to-add .
            nix flake check
            # verify TOML content
            grep -q 'host = "localhost"' config.toml
            grep -q 'port = 5432' config.toml
            declare out
            touch "$out"
          '';
        };
      };
    };
}

# Test that files.file.*.yaml serializes Nix values to YAML
{
  perSystem =
    psArgs@{ pkgs, ... }:
    {
      files.file."config.yaml".yaml = {
        version = "3";
        services.app.image = "myapp:latest";
      };

      packages = {
        write-files = psArgs.config.files.writer.drv;
        default = pkgs.writeShellApplication {
          name = "script";
          text = ''
            nix run .#write-files
            git add --intent-to-add .
            nix flake check
            # verify YAML content
            grep -q "version:" config.yaml
            grep -q "image:" config.yaml
            declare out
            touch "$out"
          '';
        };
      };
    };
}

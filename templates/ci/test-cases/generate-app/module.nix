# Test that generateApp exposes writer and diff as flake apps
{
  perSystem =
    { pkgs, ... }:
    {
      files.generateApp = true;
      files.file."test.txt".text = "generated";

      packages.default = pkgs.writeShellApplication {
        name = "script";
        text = ''
          # verify both apps are available via generateApp
          nix run .#write-files
          git add --intent-to-add .
          nix run .#diff-files
          nix flake check
          declare out
          touch "$out"
        '';
      };
    };
}

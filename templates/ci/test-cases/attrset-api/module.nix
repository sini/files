# Test that files.file attrset API works (text and source)
{
  perSystem =
    psArgs@{ pkgs, ... }:
    {
      files.file."hello.txt".text = "hello world";
      files.file."from-source.txt".source = pkgs.writeText "src" "from source";

      packages = {
        write-files = psArgs.config.files.writer.drv;
        default = pkgs.writeShellApplication {
          name = "script";
          text = ''
            nix run .#write-files
            git add --intent-to-add .
            nix flake check
            # verify content
            grep -q "hello world" hello.txt
            grep -q "from source" from-source.txt
            declare out
            touch "$out"
          '';
        };
      };
    };
}

# Usage section — ordered after install, before footer.
{ dag, ... }:
{
  flake.readme.usage = dag.entryBetween [ "footer" ] [ "body" ] ''
    ## Usage

    ```nix
    imports = [ inputs.my-project.flakeModule ];
    ```
  '';
}

# Installation section — ordered after the body marker, before usage.
{ dag, ... }:
{
  flake.readme.install = dag.entryBetween [ "usage" ] [ "body" ] ''
    ## Installation

    ```nix
    inputs.my-project.url = "github:example/my-project";
    ```
  '';
}

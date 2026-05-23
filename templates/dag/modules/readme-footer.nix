# Footer — ordered last via entryAfter.
{ dag, ... }:
{
  flake.readme.footer = dag.entryAfter [ "body" ] ''
    ## License

    MIT
  '';
}

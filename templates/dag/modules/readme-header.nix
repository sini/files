# Each module contributes a section to the README.
# dag.entryAnywhere / entryBefore / entryAfter control ordering.
{ dag, ... }:
{
  flake.readme.title = dag.entryBefore [ "badges" ] ''
    # My Project

    A demo showing how multiple modules can compose a single file
    with consistent layout using [dag](https://github.com/theutz/dag)
    and [files](https://github.com/sini/files).
  '';

  flake.readme.badges = dag.entryBefore [ "body" ] ''
    ![status](https://img.shields.io/badge/status-demo-blue)
  '';
}

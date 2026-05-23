# Wire the dag-composed README into files for writing and checking.
{ dag, config, ... }:
{
  perSystem = {
    files.generateApp = true;

    # dag.render topologically sorts the entries and joins them
    files.file."README.md".text = dag.render {
      entries = config.flake.readme;
      separator = "\n";
    };
  };
}

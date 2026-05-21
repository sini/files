{
  flake-parts-lib,
  lib,
  self,
  ...
}:
{
  options.perSystem = flake-parts-lib.mkPerSystemOption (
    psArgs@{ pkgs, ... }:
    let
      cfg = psArgs.config.files;
    in
    {
      options = {
        files = {
          root = lib.mkOption {
            type = lib.types.path;
            default = self;
            defaultText = lib.literalExpression "self";
            description = ''
              Root directory that file paths are relative to.

              Used by checks to compare derivation output against existing
              files. Defaults to `self`, which is correct when the flake is
              at the repository root.

              For multi-flake repositories, this should be `self` (the
              sub-flake source), which is the default.
            '';
          };

          relativeRoot = lib.mkOption {
            type = lib.types.str;
            default = "";
            description = ''
              Path from the Git top-level to the directory file paths are
              relative to. Used by the writer at runtime.

              Empty (default) means files are relative to the Git root.
              For a sub-flake at `templates/my-app`, set this to
              `"templates/my-app"` so the writer puts files in the right place.
            '';
            example = "templates/my-app";
          };

          gitToplevel = lib.mkOption {
            type = lib.types.path;
            default = cfg.root;
            defaultText = lib.literalExpression "config.files.root";
            visible = false;
            description = "Deprecated alias for `root`.";
          };

          file = lib.mkOption {
            description = ''
              Attrset of files to be written and checked for.
              The attribute name is the file path relative to Git top-level.
              Use slashes for subdirectories (e.g. "diagrams/overview.md").
            '';
            default = { };
            example = lib.literalExpression ''
              {
                "README.md".text = "# My Project";
                ".gitignore".source = ./gitignore;
                "docs/guide.md".text = "...";
              }
            '';
            type = lib.types.attrsOf (
              lib.types.submodule (
                { name, config, ... }:
                {
                  options = {
                    text = lib.mkOption {
                      type = lib.types.nullOr lib.types.lines;
                      default = null;
                      description = ''
                        Text content of the file.
                        Sets `source` automatically via `pkgs.writeText`.
                      '';
                    };
                    source = lib.mkOption {
                      type = lib.types.path;
                      description = ''
                        Path or derivation to use as the file content.
                        Set automatically when `text` is provided.
                      '';
                    };
                  };
                  config.source = lib.mkIf (config.text != null) (pkgs.writeText name config.text);
                }
              )
            );
          };

          files = lib.mkOption {
            description = ''
              Files to be written and checked for.
            '';
            default = [ ];
            example =
              lib.literalExpression
                # nix
                ''
                  [
                    {
                      path = "README.md";
                      drv =
                        pkgs.writeText "README.md"
                          # markdown
                          '''
                            # Practical Project

                            Clear documentation
                          ''';
                    }
                    {
                      path = ".gitignore";
                      drv = pkgs.writeText "gitignore" '''
                        result
                      ''';
                    }
                  ]
                '';
            type = lib.types.listOf (
              lib.types.submodule {
                imports = [
                  (lib.mkAliasOptionModule [ "path_" ] [ "path" ])
                ];
                options = {
                  path = lib.mkOption {
                    type = lib.types.str;
                    description = ''
                      File path relative to Git top-level.
                    '';
                    example = lib.literalExpression ''".github/workflows/check.yaml"'';
                  };
                  drv = lib.mkOption {
                    description = ''
                      Provide the file as a derivation.
                      The out path is expected to be a file.
                      Directory out path not supported;
                      pull request welcome!
                    '';
                    type = lib.types.package;
                    example =
                      lib.literalExpression
                        # nix
                        ''
                          pkgs.writers.writeJSON "gh-actions-workflow-check.yaml" {
                            on.push = { };
                            jobs.check = {
                              runs-on = "ubuntu-latest";
                              steps = [
                                { uses = "actions/checkout@v4"; }
                                { uses = "DeterminateSystems/nix-installer-action@main"; }
                                { uses = "DeterminateSystems/magic-nix-cache-action@main"; }
                                { run = "nix flake check"; }
                              ];
                            };
                          }
                        '';
                  };
                };
              }
            );
          };

          writer = {
            exeFilename = lib.mkOption {
              type = lib.types.singleLineStr;
              default = "write-files";
              description = ''
                The writer executable filename.
              '';
              example = lib.literalExpression ''"files-write"'';
            };
            drv = lib.mkOption {
              description = ''
                Provides an executable
                that writes each configured file's contents to its path.
                Missing parent directories are created.

                Consider including this in the project's development shell.
              '';
              type = lib.types.package;
              readOnly = true;
            };
          };
        };
      };

      config = {
        files.files = lib.mapAttrsToList (name: { source, ... }: {
          path = name;
          drv = source;
        }) cfg.file;

        files.writer.drv = pkgs.writeShellApplication {
          name = psArgs.config.files.writer.exeFilename;
          runtimeInputs = [ pkgs.gitMinimal ];
          text =
            let
              preamble = ''
                cd "$(git rev-parse --show-toplevel)"
              '' + lib.optionalString (cfg.relativeRoot != "") ''
                cd ${lib.escapeShellArg cfg.relativeRoot}
              '';
            in
            lib.pipe cfg.files [
              (map (
                { path, drv, ... }:
                ''
                  dir=$(dirname ${path})
                  mkdir -p "$dir"
                  cat ${drv} > ${lib.escapeShellArg path}
                ''
              ))
              (lib.concat [ preamble ])
              lib.concatLines
            ];
        };

        checks = lib.pipe cfg.files [
          (map (
            { path, drv, ... }:
            {
              name = "files/${path}";
              value =
                pkgs.runCommand "flake-file-check"
                  {
                    nativeBuildInputs = [ pkgs.difftastic ];
                    toplevel = cfg.root;
                  }
                  ''
                    existing="$toplevel/${path}"
                    if [ ! -f "$existing" ]; then
                      echo "files: ${path} not found — run the file writer first"
                      exit 1
                    fi
                    difft --exit-code --display inline ${drv} "$existing"
                    touch $out
                  '';
            }
          ))
          lib.listToAttrs
        ];
      };
    }
  );
}

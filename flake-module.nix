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
      imports = [
        (lib.mkAliasOptionModule [ "files" "gitToplevel" ] [ "files" "root" ])
      ];
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

          formatters = lib.mkOption {
            type = lib.types.attrsOf (lib.types.functionTo (lib.types.functionTo lib.types.package));
            default = { };
            description = ''
              Global formatters keyed by file extension. Each formatter is a
              function `name: source: derivation` — it receives the filename
              and source derivation, and returns a formatted derivation.
              Applied automatically to `files.file` entries whose extension
              matches. Per-file `format` overrides these.
            '';
            example = lib.literalExpression ''
              {
                nix = name: drv:
                  pkgs.runCommand "nixfmt-''${name}" { nativeBuildInputs = [ pkgs.nixfmt-rfc-style ]; } '''
                    nixfmt < ''${drv} > $out
                  ''';
                json = name: drv:
                  pkgs.runCommand "jqfmt-''${name}" { nativeBuildInputs = [ pkgs.jq ]; } '''
                    jq . < ''${drv} > $out
                  ''';
              }
            '';
          };

          treefmt = {
            enable = lib.mkEnableOption ''
              automatic formatting of `files.file` entries using treefmt.

              When enabled, all `files.file` entries are piped through
              `treefmt --stdin` which uses filename matching to select the
              correct formatter. Works with treefmt-nix or any treefmt
              wrapper set as `formatter`.

              Requires a treefmt wrapper (e.g. from treefmt-nix) to be
              available as `config.formatter`
            '';

            package = lib.mkOption {
              type = lib.types.package;
              defaultText = lib.literalExpression "config.formatter";
              description = ''
                The treefmt wrapper to use. Defaults to the flake's
                default formatter (`nix fmt`). Override to use a
                different treefmt configuration.
              '';
            };
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
                    format = lib.mkOption {
                      type = lib.types.nullOr (lib.types.functionTo (lib.types.functionTo lib.types.package));
                      default = null;
                      description = ''
                        Per-file formatter. A function `name: source: derivation`
                        that receives the filename and source derivation, and
                        returns a formatted derivation. Overrides the global
                        formatter and treefmt for this file.

                        Set to `null` (default) to use treefmt or the global
                        formatter if one matches, or no formatting.
                      '';
                      example = lib.literalExpression ''
                        name: drv: pkgs.runCommand "fmt-''${name}" {
                          nativeBuildInputs = [ pkgs.nixfmt-rfc-style ];
                        } '''
                          nixfmt < ''${drv} > $out
                        '''
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
        files.treefmt.package = lib.mkIf
          (cfg.treefmt.enable && psArgs.options.formatter.isDefined)
          (lib.mkDefault psArgs.config.formatter);

        files.files =
          let
            extOf = name:
              let parts = lib.splitString "." name;
              in if builtins.length parts > 1 then lib.last parts else "";

            treefmtFormat = name: drv:
              let
                safeName = builtins.replaceStrings [ "/" ] [ "-" ] name;
              in
              pkgs.runCommand "treefmt-${safeName}" {} ''
                # sentinel: treefmt wrapper uses --tree-root-file=flake.nix
                # to find the project root; --stdin still needs a rooted dir
                touch flake.nix
                ${lib.getExe cfg.treefmt.package} --no-cache --stdin \
                  ${lib.escapeShellArg name} < ${drv} > $out
              '';

            applyFormat = name: { source, format, ... }:
              let
                ext = extOf name;
                formatter =
                  if format != null then format
                  else if cfg.formatters ? ${ext} then cfg.formatters.${ext}
                  else if cfg.treefmt.enable then treefmtFormat
                  else null;
              in
              {
                path = name;
                drv = if formatter != null then formatter name source else source;
              };
          in
          lib.mapAttrsToList applyFormat cfg.file;

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
                  dir=$(dirname ${lib.escapeShellArg path})
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

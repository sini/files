# Framework-agnostic files module.
# Used directly by vanilla flakes, or wrapped by flake-module.nix for flake-parts.
{ pkgs, lib, config, ... }:
let
  cfg = config.files;
in
{
  imports = [
    (lib.mkAliasOptionModule [ "files" "gitToplevel" ] [ "files" "root" ])
  ];
  options = {
    files = {
      root = lib.mkOption {
        type = lib.types.path;
        description = ''
          Root directory that file paths are relative to.
          Used by checks to compare derivation output against existing files.
          Set to `self` in your flake outputs.
        '';
        example = lib.literalExpression "self";
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
          }
        '';
      };

      treefmt = {
        enable = lib.mkEnableOption ''
          automatic formatting of `files.file` entries using treefmt.

          When enabled, all `files.file` entries are piped through
          `treefmt --stdin` which uses filename matching to select the
          correct formatter
        '';

        package = lib.mkOption {
          type = lib.types.package;
          description = ''
            The treefmt wrapper to use. Must be set explicitly when
            `treefmt.enable` is true (e.g. to `config.formatter` in
            flake-parts, or a manually built treefmt wrapper).
          '';
        };
      };

      file = lib.mkOption {
        description = ''
          Attrset of files to be written and checked for.
          The attribute name is the file path relative to the project root.
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
          Files to be written and checked for (list API).
        '';
        default = [ ];
        type = lib.types.listOf (
          lib.types.submodule {
            imports = [
              (lib.mkAliasOptionModule [ "path_" ] [ "path" ])
            ];
            options = {
              path = lib.mkOption {
                type = lib.types.str;
                description = "File path relative to project root.";
              };
              drv = lib.mkOption {
                type = lib.types.package;
                description = "Derivation whose output is the file content.";
              };
            };
          }
        );
      };

      checks = lib.mkOption {
        type = lib.types.attrsOf lib.types.package;
        readOnly = true;
        description = "Per-file check derivations.";
      };

      writer = {
        exeFilename = lib.mkOption {
          type = lib.types.singleLineStr;
          default = "write-files";
          description = "The writer executable filename.";
        };
        drv = lib.mkOption {
          description = "The writer executable derivation (read-only).";
          type = lib.types.package;
          readOnly = true;
        };
      };
    };
  };

  config = {
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
      name = cfg.writer.exeFilename;
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

    files.checks = lib.pipe cfg.files [
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
                existing="$toplevel/"${lib.escapeShellArg path}
                if [ ! -f "$existing" ]; then
                  echo "files: ${lib.escapeShellArg path} not found — run the file writer first"
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

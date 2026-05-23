# files

[![Nix Flake Check](https://github.com/sini/files/actions/workflows/check.yaml/badge.svg)](https://github.com/sini/files/actions/workflows/check.yaml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)

A [flake-parts](https://flake.parts) module for managing in-repository
generated files. Declare file contents in Nix, write them with one command,
and verify they stay in sync via `nix flake check`.

This project is an independent, hard fork of
[mightyiam/files](https://github.com/mightyiam/files). It is maintained entirely
separately and has no affiliation with, nor is it endorsed by, the original
author.

## Table of Contents

- [Motivation](#motivation)
- [What this fork adds](#what-this-fork-adds)
- [Templates](#templates)
- [Quick start](#quick-start)
- [With treefmt](#with-treefmt)
- [With derivation sources](#with-derivation-sources)
- [In a monorepo](#in-a-monorepo)
- [API reference](#api-reference)
  - [`files.file`](#filesfile)
  - [`files.treefmt`](#filestreefmt)
  - [`files.formatters`](#filesformatters)
  - [Formatter priority](#formatter-priority)
  - [`files.files` (list API)](#filesfiles-list-api)
  - [Other options](#other-options)
- [Without flake-parts](#without-flake-parts)

## Motivation

The upstream project made several decisions that don't align with how we use
it across [den](https://github.com/denful/den)'s template ecosystem:

- **Removed flake export** — upstream deliberately dropped
  `flakeModules.default`, requiring consumers to use `flake = false` and raw
  path imports. We need proper flake consumption for composability with other
  flake-parts modules.
- **Adopted experimental Nix features** — the `|>` pipe operator requires
  `extra-experimental-features = [ "pipe-operators" ]` in every consuming
  flake's `nixConfig`. This created additional user friction.
- **Renamed `path_` to `path` without alias** — a breaking change with no
  migration path or notification for existing consumers.
- **No convenience API** — the list-of-`{path, drv}` interface requires
  boilerplate for the common case of writing text or copying a file. NixOS has
  had `environment.etc`-style attrset APIs for years.
- **No multi-flake support** — the writer hardcoded
  `git rev-parse --show-toplevel` with no way to target a subdirectory,
  making it unusable in monorepos.
- **Eager eval breaks `--no-build`** — `lib.readFile` at evaluation time
  means `nix flake check --no-build` fails when managed files haven't been
  written yet, which is the normal state for fresh clones.
- **No formatting pipeline** — generated files often need to pass through
  formatters (nixfmt, prettier, jq) to match project style, but there was
  no way to post-process file content before writing.

## What this fork adds

- **Works with and without flake-parts** — `flakeModule` for flake-parts,
  `module` for vanilla flakes via `evalModules`
- **`files.file` convenience API** — `environment.etc`-style attrset with
  `text`, `source`, `json`, `toml`, and `yaml` options
- **Structured data renderers** — `json`, `toml`, and `yaml` options
  serialize Nix values directly, no `pkgs.writers.*` boilerplate
- **Diff preview** — `nix run .#diff-files` shows what would change
  without writing; `--verbose` for full diffs
- **[treefmt-nix](https://github.com/numtide/treefmt-nix) integration** —
  `files.treefmt.enable` formats all entries through `nix fmt`
- **Formatters** — global `files.formatters` by extension and per-file
  `format` for custom post-processing
- **onChange hooks** — run shell commands after writing, with optional
  `runtimeInputs` for extra packages on the writer's PATH
- **Multi-flake repo support** — `relativeRoot` for monorepo sub-flakes
- **Lazy checks** — `nix flake check --no-build` works on fresh clones
- **Backwards compatibility** — `path_` and `gitToplevel` aliases
- **Stable Nix syntax** - The experimental `|>` operator is replaced with
  `lib.pipe`, so you don't need to enable `pipe-operators` in your nixConfig.

## Templates

Working examples live in [`templates/`](templates/):

- [`flake-parts`](templates/flake-parts/) — flake-parts + import-tree with treefmt, global formatters, per-file overrides, onChange hooks, and both APIs
- [`bare-flake`](templates/bare-flake/) — vanilla flake using `evalModules`, no flake-parts dependency
- [`no-flake`](templates/no-flake/) — pure `default.nix` with `import`, no flake infrastructure

## Quick start

```nix
# flake.nix
{
  inputs = {
    files.url = "github:sini/files";
    flake-parts.url = "github:hercules-ci/flake-parts";
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
  };

  outputs = inputs: inputs.flake-parts.lib.mkFlake { inherit inputs; } {
    systems = [ "x86_64-linux" "aarch64-linux" "aarch64-darwin" "x86_64-darwin" ];
    imports = [ inputs.files.flakeModule ];

    perSystem = { ... }: {
      files.generateApp = true;

      files.file.".gitignore".text = ''
        result
        .direnv
      '';

      files.file."README.md".text = ''
        # My Project
        Generated by Nix.
      '';
    };
  };
}
```

```sh
nix run .#write-files       # write files to disk
nix run .#diff-files        # preview what would change
nix run .#diff-files -- -v  # preview with full diffs
nix flake check             # verify they match
```

## With treefmt

Format generated files automatically using your project's
[treefmt-nix](https://github.com/numtide/treefmt-nix) configuration.
treefmt's own include/exclude rules apply — files that don't match any
formatter pass through unchanged.

```nix
{
  inputs = {
    files.url = "github:sini/files";
    flake-parts.url = "github:hercules-ci/flake-parts";
    treefmt-nix.url = "github:numtide/treefmt-nix";
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
  };

  outputs = inputs: inputs.flake-parts.lib.mkFlake { inherit inputs; } {
    systems = [ "x86_64-linux" ];
    imports = [
      inputs.files.flakeModule
      inputs.treefmt-nix.flakeModule
    ];

    perSystem = { config, pkgs, ... }: {
      treefmt.programs.nixfmt.enable = true;
      treefmt.programs.prettier.enable = true;

      files.treefmt.enable = true;

      # nixfmt formats this automatically
      files.file."config.nix".text = "{foo=1;bar=2;}";

      # prettier formats this automatically
      files.file."README.md".text = "# Hello    World";

      # no formatter matches .txt — passes through unchanged
      files.file."LICENSE".text = "MIT";

    };
  };
}
```

## With derivation sources

Use `source` for files built from derivations, repo paths, or structured
data:

```nix
perSystem = { config, pkgs, ... }: {
  # from structured Nix data
  files.file.".github/workflows/ci.yaml".source =
    pkgs.writers.writeYAML "ci.yaml" {
      on.push = { };
      jobs.check = {
        runs-on = "ubuntu-latest";
        steps = [
          { uses = "actions/checkout@v4"; }
          { run = "nix flake check"; }
        ];
      };
    };

  # from a file in the repo
  files.file."LICENSE".source = ./LICENSE.src;

  packages.write-files = config.files.writer.drv;
};
```

## In a monorepo

For sub-flakes that aren't at the git root, set `relativeRoot` so the
writer puts files in the right directory:

```nix
# packages/my-app/flake.nix
perSystem = { config, ... }: {
  files.relativeRoot = "packages/my-app";
  files.file."README.md".text = "# My App";
  packages.write-files = config.files.writer.drv;
};
```

## API reference

All options live under `perSystem.files`.

### `files.file`

Attrset of files to manage. The attribute name is the file path relative to
the project root. Use slashes for subdirectories.

| Option       | Type                                 | Default | Description                                                                     |
| ------------ | ------------------------------------ | ------- | ------------------------------------------------------------------------------- |
| `enable`     | `bool`                               | `true`  | Set `false` to suppress this file.                                              |
| `text`       | `nullOr lines`                       | `null`  | Inline text content. Sets `source` automatically.                               |
| `json`       | `nullOr anything`                    | `null`  | JSON value to serialize. Sets `source` automatically.                           |
| `toml`       | `nullOr anything`                    | `null`  | TOML value to serialize. Sets `source` automatically.                           |
| `yaml`       | `nullOr anything`                    | `null`  | YAML value to serialize. Sets `source` automatically.                           |
| `source`     | `path`                               | —       | Path or derivation for the file content.                                        |
| `executable` | `bool`                               | `false` | `chmod +x` after writing.                                                       |
| `onChange`   | `str` or `{ runtimeInputs, script }` | `""`    | Shell commands run after all files are written. Runs under `set -euo pipefail`. |
| `format`     | `nullOr (name -> drv -> drv)`        | `null`  | Per-file formatter. Overrides all other formatters.                             |

```nix
perSystem = { config, pkgs, ... }: {
  files.file."scripts/deploy.sh" = {
    text = ''
      #!/bin/sh
      echo "deploying..."
    '';
    executable = true;
  };

  # onChange as a plain string
  files.file."flake.nix".text = "{}";
  files.file."flake.nix".onChange = "echo 'flake updated'";

  # onChange with runtimeInputs — packages are added to the writer's PATH
  files.file.".envrc" = {
    text = "use flake";
    onChange = {
      runtimeInputs = [ pkgs.direnv ];
      script = "direnv reload";
    };
  };

  # structured data — no pkgs.writers.* boilerplate
  files.file."data/config.json".json = { version = 1; debug = false; };
  files.file."data/settings.toml".toml = { database.host = "localhost"; };
  files.file."data/compose.yaml".yaml = {
    version = "3";
    services.app.image = "myapp:latest";
  };

  # disable a file defined by a shared module
  files.file."docs/internal.md".enable = false;

  packages.write-files = config.files.writer.drv;
};
```

### `files.treefmt`

| Option    | Type      | Default            | Description                       |
| --------- | --------- | ------------------ | --------------------------------- |
| `enable`  | `bool`    | `false`            | Format entries through `nix fmt`. |
| `package` | `package` | `config.formatter` | Treefmt wrapper to use.           |

### `files.formatters`

Global formatters keyed by file extension. Signature: `name: source: derivation`.
Per-file `format` overrides these. These override treefmt.

```nix
files.formatters.json = name: drv:
  pkgs.runCommand "jqfmt-${name}" { nativeBuildInputs = [ pkgs.jq ]; } ''
    jq --sort-keys . < ${drv} > $out
  '';
```

### Formatter priority

1. Per-file `format` (highest)
2. Global `formatters` by extension
3. `treefmt` (if enabled)
4. No formatting (passthrough)

### `files.files` (list API)

The original list-based API. `files.file` entries merge into this list
automatically. Both APIs can be used together. The formatting pipeline
(treefmt, global formatters, per-file `format`) applies to both APIs.

| Option       | Type                          | Default | Description                                          |
| ------------ | ----------------------------- | ------- | ---------------------------------------------------- |
| `path`       | `str`                         | —       | File path relative to project root.                  |
| `drv`        | `package`                     | —       | Derivation whose output is the file content.         |
| `executable` | `bool`                        | `false` | `chmod +x` after writing.                            |
| `format`     | `nullOr (name -> drv -> drv)` | `null`  | Per-file formatter. Overrides all other formatters.  |
| `onChange`   | `{ runtimeInputs, script }`   | `{}`    | Shell commands run after writing if content changed. |

```nix
files.files = [
  {
    path = "README.md";
    drv = pkgs.writeText "README.md" "# Hello";
  }
  {
    path = "data/config.json";
    drv = pkgs.writers.writeJSON "config.json" { version = 1; };
    # per-file formatter works in both APIs
    format = name: drv:
      pkgs.runCommand "jqfmt-${name}" { nativeBuildInputs = [ pkgs.jq ]; } ''
        jq --sort-keys . < ${drv} > $out
      '';
  }
];
```

### Other options

| Option               | Type              | Default         | Description                                                                                           |
| -------------------- | ----------------- | --------------- | ----------------------------------------------------------------------------------------------------- |
| `root`               | `path`            | —               | Root for check comparisons. Auto-set to `self` via flake-parts; set `root = self;` in vanilla flakes. |
| `relativeRoot`       | `str`             | `""`            | Subdir from git root for the writer.                                                                  |
| `generateApp`        | `bool`            | `false`         | Expose writer and diff as `nix run .#write-files` / `nix run .#diff-files`.                           |
| `writer.exeFilename` | `singleLineStr`   | `"write-files"` | Writer executable name.                                                                               |
| `writer.drv`         | `package`         | _(computed)_    | The writer derivation (read-only).                                                                    |
| `diff.exeFilename`   | `singleLineStr`   | `"diff-files"`  | Diff executable name.                                                                                 |
| `diff.drv`           | `package`         | _(computed)_    | The diff derivation (read-only). Shows what would change without writing.                             |
| `checks`             | `attrsOf package` | _(computed)_    | Per-file check derivations (read-only).                                                               |

## Without flake-parts

Use `files.module` directly with `evalModules` — no flake-parts dependency:

```nix
{
  inputs = {
    files.url = "github:sini/files";
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
  };

  outputs = { self, files, nixpkgs, ... }:
  let
    pkgs = nixpkgs.legacyPackages.x86_64-linux;
    eval = pkgs.lib.evalModules {
      modules = [
        files.module
        {
          config._module.args = { inherit pkgs; };
          config.files.root = self;
          config.files.file."README.md".text = "# Hello";
          config.files.file.".gitignore".text = "result";
        }
      ];
    };
  in {
    checks.x86_64-linux = eval.config.files.checks;
    packages.x86_64-linux.write-files = eval.config.files.writer.drv;
  };
}
```

For usage without any flake infrastructure, see
[`templates/no-flake`](templates/no-flake/default.nix).

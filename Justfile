help:
  just -l

fmt *args:
  "$(nix build ./templates/ci#formatter.$(nix eval --impure --expr builtins.currentSystem) --no-link --print-out-paths)/bin/treefmt" {{args}}

ci:
  just fmt --ci --no-cache
  cd templates/ci && nix flake --accept-flake-config check --override-input files ../.. --print-build-logs --keep-going

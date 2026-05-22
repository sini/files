let
  lock = builtins.fromJSON (builtins.readFile ./templates/ci/flake.lock);
  nixpkgsLocked = lock.nodes.nixpkgs.locked;
  nixpkgs = fetchTarball {
    url = "https://github.com/${nixpkgsLocked.owner}/${nixpkgsLocked.repo}/archive/${nixpkgsLocked.rev}.tar.gz";
    sha256 = nixpkgsLocked.narHash;
  };
in
{
  pkgs ? import nixpkgs { },
  ...
}:
pkgs.mkShell {
  buildInputs = [
    pkgs.just
  ];
}

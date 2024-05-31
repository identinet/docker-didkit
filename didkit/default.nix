{ pkgs ? import <nixpkgs> { } }:
let manifest = (pkgs.lib.importTOML ./didkit/cli/Cargo.toml).package;
in
pkgs.rustPlatform.buildRustPackage rec {
  pname = manifest.name;
  version = manifest.version;
  cargoLock.lockFile = ./Cargo.lock;
  src = pkgs.lib.cleanSource ./.;
  nativeBuildInputs = with pkgs; [
    rustc
    rust-analyzer
    cargo
    clippy
    rustfmt
  ];
  meta = with pkgs.lib; {
    description = "Core library for Verifiable Credentials and Decentralized Identifiers.";
    homepage = "https://github.com/ideninet/didkit";
    license = with licenses; [ asl20 ];
    maintainers = with maintainers; [ jceb ];
  };
}

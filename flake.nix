{
  description = "NetEase POPO for NixOS";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };
    in
    {
      packages.${system} = {
        popo = pkgs.callPackage ./package.nix { };
        default = self.packages.${system}.popo;
      };
    };
}

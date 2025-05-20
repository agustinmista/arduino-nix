{ libraryIndex, pkgs }:
let
  lib = pkgs.callPackage ./lib.nix { };

  librariesByName = builtins.groupBy ({ name, ... }: name) libraryIndex.libraries;

  libraries = builtins.mapAttrs (
    name: versions:
    builtins.listToAttrs (
      builtins.map (
        {
          version,
          url,
          checksum,
          ...
        }:
        {
          name = version;
          value = lib.mkLibrary name version url checksum;
        }
      ) versions
    )
  ) librariesByName;
in
libraries

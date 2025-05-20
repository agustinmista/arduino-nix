{
  stdenv,
  packageIndex,
  pkgs,
}:
let
  lib = pkgs.callPackage ./lib.nix { };

  tools = builtins.listToAttrs (
    builtins.map (
      { name, tools, ... }:
      {
        inherit name;
        value = builtins.mapAttrs (
          _: versions:
          builtins.listToAttrs (
            builtins.map (
              {
                name,
                version,
                systems,
                ...
              }:
              {
                name = version;
                value =
                  let
                    system = lib.selectSystem stdenv.hostPlatform.system systems;
                  in
                  if system == null then
                    throw "Unsupported platform ${stdenv.hostPlatform.system}"
                  else
                    lib.mkTool name version system.url system.checksum;
              }
            ) versions
          )
        ) (builtins.groupBy ({ name, ... }: name) tools);
      }
    ) packageIndex.packages
  );

  platforms = builtins.listToAttrs (
    builtins.map (
      { name, platforms, ... }:
      {
        inherit name;
        value = builtins.mapAttrs (
          arch: versions:
          builtins.listToAttrs (
            builtins.map (
              {
                version,
                url,
                checksum,
                toolsDependencies ? [ ],
                ...
              }:
              {
                name = version;
                value = lib.mkPlatform name version url checksum arch toolsDependencies;
              }
            ) versions
          )
        ) (builtins.groupBy ({ arch, ... }: arch) platforms);
      }
    ) packageIndex.packages
  );
in
{
  inherit tools platforms;
}

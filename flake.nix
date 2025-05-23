{
  description = "Wrapper for arduino-cli";

  outputs =
    { ... }:
    {
      mkArduinoPackageOverlay =
        packageIndexFile:
        (self: super: {
          arduinoPackages = self.lib.recursiveUpdate (super.arduinoPackages or { }) (
            self.callPackage ./packages.nix {
              packageIndex = builtins.fromJSON (builtins.readFile packageIndexFile);
            }
          );
        });

      mkArduinoLibraryOverlay =
        libraryIndexFile:
        (self: super: {
          arduinoLibraries = self.lib.recursiveUpdate (super.arduinoLibraries or { }) (
            self.callPackage ./libraries.nix {
              libraryIndex = builtins.fromJSON (builtins.readFile libraryIndexFile);
            }
          );
        });

      overlay = (self: super: { wrapArduinoCLI = self.callPackage ./wrap-arduino-cli.nix { }; });

      # Expose helper to select package
      latestVersion = (import ./lib.nix { lib = null; }).latestVersion;
    };
}

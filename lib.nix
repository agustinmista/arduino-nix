{
  pkgs,
  pkgsBuildHost,
  lib,
  arduinoPackages,
  ...
}:
rec {
  alt = a: b: if a == null then b else a;

  latestVersion =
    attrs:
    let
      sortedVersions = builtins.sort (a: b: (builtins.compareVersions a.version b.version) == 1) (
        builtins.attrValues (builtins.mapAttrs (version: value: { inherit version value; }) attrs)
      );
    in
    (builtins.head sortedVersions).value;

  # From tools.go in arduino-cli
  #	regexpLinuxArm   = regexp.MustCompile("arm.*-linux-gnueabihf")
  #	regexpLinuxArm64 = regexp.MustCompile("(aarch64|arm64)-linux-gnu")
  #	regexpLinux64    = regexp.MustCompile("x86_64-.*linux-gnu")
  #	regexpLinux32    = regexp.MustCompile("i[3456]86-.*linux-gnu")
  #	regexpWindows32  = regexp.MustCompile("i[3456]86-.*(mingw32|cygwin)")
  #	regexpWindows64  = regexp.MustCompile("(amd64|x86_64)-.*(mingw32|cygwin)")
  #	regexpMac64      = regexp.MustCompile("x86_64-apple-darwin.*")
  #	regexpMac32      = regexp.MustCompile("i[3456]86-apple-darwin.*")
  #	regexpMacArm64   = regexp.MustCompile("arm64-apple-darwin.*")
  #	regexpFreeBSDArm = regexp.MustCompile("arm.*-freebsd[0-9]*")
  #	regexpFreeBSD32  = regexp.MustCompile("i?[3456]86-freebsd[0-9]*")
  #	regexpFreeBSD64  = regexp.MustCompile("amd64-freebsd[0-9]*")

  selectSystem =
    system: systems:
    if system == "aarch64-darwin" then
      alt (lib.findFirst (
        { host, ... }: builtins.match "arm64-apple-darwin.*" host != null
      ) null systems) (selectSystem "x86_64-darwin" systems)
    else if system == "x86_64-darwin" then
      alt (lib.findFirst (
        { host, ... }: builtins.match "x86_64-apple-darwin.*" host != null
      ) null systems) (selectSystem "i686-darwin" systems)
    else if system == "i686-darwin" then
      lib.findFirst ({ host, ... }: builtins.match "i[3456]86-apple-darwin.*" host != null) null systems
    else if system == "aarch64-linux" then
      # tools.go uses regexp.MatchString which will also return true for substring matches, so we add a .* to the regex
      lib.findFirst (
        { host, ... }: builtins.match "(aarch64|arm64)-linux-gnu.*" host != null
      ) null systems
    else if system == "x86_64-linux" then
      # also add a .* to the regex here though it is not necessary in the current dataset (March 2024)
      lib.findFirst ({ host, ... }: builtins.match "x86_64-.*linux-gnu.*" host != null) null systems
    else
      null;

  convertHash =
    hash:
    let
      m = builtins.match "(SHA-256|SHA-1|MD5):(.*)" hash;
      algo = builtins.elemAt m 0;
      h = builtins.elemAt m 1;
    in
    if m == null then
      throw "Unsupported hash format ${hash}"
    else if algo == "SHA-256" then
      { sha256 = h; }
    else if algo == "SHA-1" then
      { sha1 = h; }
    else
      { md5 = h; };

  mkLibrary =
    name: version: url: checksum:
    pkgs.stdenv.mkDerivation {
      pname = name;
      inherit version;

      installPhase = ''
        runHook preInstall

        mkdir -p "$out/libraries/$pname"
        cp -R * "$out/libraries/$pname/"

        runHook postInstall
      '';
      nativeBuildInputs = [ pkgs.unzip ];
      src = builtins.fetchurl ({ inherit url; } // convertHash checksum);
    };

  mkTool =
    name: version: url: checksum:
    pkgs.stdenv.mkDerivation {
      pname = "${name}-${name}";
      inherit version;

      # Tools are installed in $platform_name/tools/$name/$version
      dirName = "packages/${name}/tools/${name}/${version}";

      installPhase = ''
        mkdir -p "$out/$dirName"
        cp -R * "$out/$dirName/"
      '';
      nativeBuildInputs = [ pkgs.unzip ];
      src = builtins.fetchurl ({ inherit url; } // convertHash checksum);
    };

  mkPlatform =
    name: version: url: checksum: arch: toolsDependencies:
    pkgs.stdenv.mkDerivation {
      pname = "${name}-${arch}";
      inherit version;

      # Platform are installed in $platform_name/hardware/$architecture/$version
      dirName = "packages/${name}/hardware/${arch}/${version}";

      toolsDependencies = builtins.map (
        {
          packager,
          name,
          version,
        }:
        arduinoPackages.tools.${packager}.${name}.${version}
      ) toolsDependencies;

      passAsFile = [ "toolsDependencies" ];
      installPhase = ''
        runHook preInstall

        mkdir -p "$out/$dirName"
        cp -R * "$out/$dirName/"

        for i in $(cat $toolsDependenciesPath); do
          ${pkgsBuildHost.xorg.lndir}/bin/lndir -silent $i $out
        done

        runHook postInstall
      '';
      nativeBuildInputs = [ pkgs.unzip ];
      src = builtins.fetchurl ({ inherit url; } // convertHash checksum);
    };
}

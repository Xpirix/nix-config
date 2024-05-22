{pkgs ? import <nixpkgs> {}}:
pkgs.stdenv.mkDerivation rec {
  pname = "kartoza-plymouth";
  version = "0.0.2";

  src = ./src;

  buildInputs = [
    pkgs.git
  ];

  #do nothing since we have src in this folder
  unpackPhase = ''
    cp -r ${src}/* .  # Copy all contents from the src directory to the build directory
  '';

  configurePhase = ''
    mkdir -p $out/share/plymouth/themes/kartoza
  '';

  buildPhase = ''
  '';

  installPhase = ''
    cp -r kartoza/kartoza-synfig-bootsplash.0.png $out/share/plymouth/themes/kartoza
    cp kartoza/kartoza.script $out/share/plymouth/themes/kartoza
    cat kartoza/kartoza.plymouth | sed  "s@\/usr\/@$out\/@" > $out/share/plymouth/themes/kartoza/kartoza.plymouth
  '';

  # Make it easy to get to the source dir when you run
  # nix develop .#kartoza-plymouth
  shellHook = ''
    export SRC_DIR=$src
    echo "Source directory is set to: $SRC_DIR"
  '';
}

{
  description = "Kartoza NixOS Flakes";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-23.11";
    unstable.url = "https://github.com/nixos/nixpkgs/tarball/nixpkgs-unstable";
    home-manager.url = "github:nix-community/home-manager/release-23.11";
    # See https://github.com/nix-community/nixos-generators?tab=readme-ov-file#using-in-a-flake
    nixos-generators = {
      url = "github:nix-community/nixos-generators";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = {
    self,
    home-manager,
    nixpkgs,
    unstable,
    nixos-generators,
  } @ inputs: let
    system = "x86_64-linux";
    # See https://github.com/mcdonc/.nixconfig/blob/86254905e2d13fc42292ac47fd13310d0c778935/videos/oldpkgs/script.rst
    # And the implementations referenced from software/unstable-apps.nix
    overlay-unstable = final: prev: {
      unstable = import unstable {
        inherit system;
        config.allowUnfree = true;
        config.permittedInsecurePackages = [
          "qtwebkit-5.212.0-alpha4"
        ];
      };
    };
    pkgs = import nixpkgs {
      inherit system;
    };
    specialArgs = inputs // {inherit system;};
    shared-modules = [
      home-manager.nixosModules.home-manager
      {
        home-manager = {
          useGlobalPkgs = true;
          useUserPackages = true;
          extraSpecialArgs = specialArgs;
        };
      }
    ];

    py = pkgs.python3Packages;
    pyOveride = py.override {
      packageOverrides = self: super: {
        pyqt5 = super.pyqt5.override {
          withLocation = true;
          withSerialPort = true;
        };
      };
    };
    # This is used for creating ISO images, see iso section below
    isoBase = {
      isoImage.squashfsCompression = "gzip -Xcompression-level 1";
      systemd.services.sshd.wantedBy = nixpkgs.lib.mkForce ["multi-user.target"];
      users.users.root.openssh.authorizedKeys.keys = [
        (builtins.readFile ./users/public-keys/id_ed25519_tim.pub)
      ];
    };
  in {
    ######################################################
    ##
    ## Package Definitions. See
    ## https://determinate.systems/posts/nix-run/
    ## For a basic introduction
    ##
    ######################################################
    #
    # Default package - utilities to help you prepare for setting up a new machine.
    #
    # Run with
    # "nix run"
    # or
    # nix run github:timlinux/nix-config
    # or
    # nix run github:timlinux/nix-config#default
    #
    # to include in a config do:
    #
    # {pkgs, ...}: {
    #   nixpkgs.overlays = [(import ../../packages)];
    #    environment.systemPackages = with pkgs; [
    #      qgis-latest
    #   ];
    # }
    packages.x86_64-linux.default = pkgs.callPackage ./packages/utils {};
    packages.x86_64-linux.qgis-python-shell = pkgs.callPackage ./packages/qgis-python-shell {};
    packages.x86_64-linux.setup-zfs-machine = pkgs.callPackage ./packages/setup-zfs-machine {};
    packages.x86_64-linux.qgis = pkgs.callPackage ./packages/qgis {};
    packages.x86_64-linux.tilemaker = pkgs.callPackage ./packages/tilemaker {};
    packages.x86_64-linux.gverify = pkgs.callPackage ./packages/gverify {};
    packages.x86_64-linux.itk4 = pkgs.callPackage ./packages/itk4 {};
    packages.x86_64-linux.otb = pkgs.callPackage ./packages/otb {self = self;};
    packages.x86_64-linux.distrobox = pkgs.callPackage ./packages/distrobox {};
    packages.x86_64-linux.kartoza-plymouth = pkgs.callPackage ./packages/kartoza-plymouth {};
    packages.x86_64-linux.whitebox-tools = pkgs.callPackage ./packages/whitebox-tools {};
    # Example of how to deploy a simple script
    packages.x86_64-linux.runme = pkgs.writeScriptBin "runme" ''
      echo "Tim nix-config default package"
    '';
    # WIP
    packages.x86_64-linux.iso = nixos-generators.nixosGenerate {
      system = "x86_64-linux";
      modules = [
        # you can include your own nixos configuration here, i.e.
        #./hosts/iso-gnome.nix
      ];
      format = "vmware";

      # optional arguments:
      # explicit nixpkgs and lib:
      # pkgs = nixpkgs.legacyPackages.x86_64-linux;
      # lib = nixpkgs.legacyPackages.x86_64-linux.lib;
      # additional arguments to pass to modules:
      # specialArgs = { myExtraArg = "foobar"; };

      # you can also define your own custom formats
      # customFormats = { "myFormat" = <myFormatModule>; ... };
      # format = "myFormat";
    };

    ######################################################
    ##
    ## Configurations for each host we manage
    ##
    ######################################################
    nixosConfigurations = {
      # Live iso Generation
      # Please read: https://nixos.wiki/wiki/Creating_a_NixOS_live_CD
      # To build:
      # nix build .#nixosConfigurations.live.config.system.build.isoImage
      # To run:
      # qemu-system-x86_64 -enable-kvm -m 8096 -cdrom result/iso/nixos-*.iso
      live = nixpkgs.lib.nixosSystem {
        specialArgs = specialArgs;
        system = system;
        modules =
          [
            ({
              config,
              pkgs,
              ...
            }: {nixpkgs.overlays = [overlay-unstable];})
            "${nixpkgs}/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix"
            isoBase
          ]
          ++ shared-modules
          ++ [./hosts/iso-gnome.nix];
      };
      # Tim's p14s thinkpad - love this machine!
      crest = nixpkgs.lib.nixosSystem {
        specialArgs = specialArgs;
        system = system;
        modules =
          [
            ({
              config,
              pkgs,
              ...
            }: {nixpkgs.overlays = [overlay-unstable];})
          ]
          ++ shared-modules
          ++ [./hosts/crest.nix];
      };
      # Tim Tuxedo desktop box
      waterfall = nixpkgs.lib.nixosSystem {
        specialArgs = specialArgs;
        system = system;
        modules =
          [
            ({
              config,
              pkgs,
              ...
            }: {nixpkgs.overlays = [overlay-unstable];})
          ]
          ++ shared-modules
          ++ [./hosts/waterfall.nix];
      };
      # Tim headless box
      valley = nixpkgs.lib.nixosSystem {
        specialArgs = specialArgs;
        system = system;
        modules =
          [
            ({
              config,
              pkgs,
              ...
            }: {nixpkgs.overlays = [overlay-unstable];})
          ]
          ++ shared-modules
          ++ [./hosts/valley.nix];
      };
      # Vicky laptop
      lagoon = nixpkgs.lib.nixosSystem {
        specialArgs = specialArgs;
        system = system;
        modules =
          [
            ({
              config,
              pkgs,
              ...
            }: {nixpkgs.overlays = [overlay-unstable];})
          ]
          ++ shared-modules
          ++ [./hosts/lagoon.nix];
      };
      # Virtman manual testbed
      rock = nixpkgs.lib.nixosSystem {
        specialArgs = specialArgs;
        system = system;
        modules =
          [
            ({
              config,
              pkgs,
              ...
            }: {nixpkgs.overlays = [overlay-unstable];})
          ]
          ++ shared-modules
          ++ [./hosts/rock.nix];
      };
      jeff = nixpkgs.lib.nixosSystem {
        specialArgs = specialArgs;
        system = system;
        modules =
          [
            ({
              config,
              pkgs,
              ...
            }: {nixpkgs.overlays = [overlay-unstable];})
          ]
          ++ shared-modules
          ++ [./hosts/jeff.nix];
      };
      # Dorahs's Laptop
      atoll = nixpkgs.lib.nixosSystem {
        specialArgs = specialArgs;
        system = system;
        modules =
          [
            ({
              config,
              pkgs,
              ...
            }: {nixpkgs.overlays = [overlay-unstable];})
          ]
          ++ shared-modules
          ++ [./hosts/atoll.nix];
      };
      # Eli's Laptop
      crater = nixpkgs.lib.nixosSystem {
        specialArgs = specialArgs;
        system = system;
        modules =
          [
            ({
              config,
              pkgs,
              ...
            }: {nixpkgs.overlays = [overlay-unstable];})
          ]
          ++ shared-modules
          ++ [./hosts/crater.nix];
      };
      # Automated testbed - test gnome
      # do nix run then launch from the VM menu
      test-gnome-full = nixpkgs.lib.nixosSystem {
        specialArgs = specialArgs;
        system = system;
        modules =
          [
            ({
              config,
              pkgs,
              ...
            }: {nixpkgs.overlays = [overlay-unstable];})
          ]
          ++ shared-modules
          ++ [./hosts/test-gnome-full.nix];
      };
      # Automated testbed - test gnome
      # do nix run then launch from the VM menu
      test-gnome-minimal = nixpkgs.lib.nixosSystem {
        specialArgs = specialArgs;
        system = system;
        modules =
          [
            ({
              config,
              pkgs,
              ...
            }: {nixpkgs.overlays = [overlay-unstable];})
          ]
          ++ shared-modules
          ++ [./hosts/test-gnome-minimal.nix];
      };
      # do nix run then launch from the VM menu
      # Automated testbed - test kde
      test-kde6 = unstable.lib.nixosSystem {
        specialArgs = specialArgs;
        system = system;
        modules =
          [
            ({
              config,
              pkgs,
              ...
            }: {nixpkgs.overlays = [overlay-unstable];})
          ]
          ++ shared-modules
          ++ [./hosts/test-kde6.nix];
      };
      # Automated testbed - test kde5
      test-kde5 = nixpkgs.lib.nixosSystem {
        specialArgs = specialArgs;
        system = system;
        modules =
          [
            ({
              config,
              pkgs,
              ...
            }: {nixpkgs.overlays = [overlay-unstable];})
          ]
          ++ shared-modules
          ++ [./hosts/test-kde5.nix];
      };
    };

    ######################################################
    ##
    ## Developer environments
    ##
    ######################################################

    # invoke with
    # nix develop
    # or
    # nix develop .#default
    devShells.${system}.default = with pkgs;
      mkShell {
        buildInputs = [
          cmakeCurses
          # A Python interpreter including the 'venv' module is required to bootstrap
          # the environment.
          py.python
          py.requests
          git
          virtualenv
          py.chardet
          py.debugpy
          py.future
          py.gdal
          py.jinja2
          py.matplotlib
          py.numpy
          py.owslib
          py.pandas
          py.plotly
          py.psycopg2
          py.pygments
          py.pyqt5
          #py.pyqt5_with_qtwebkit # Added by Tim for InaSAFE
          py.pyqt-builder
          py.pyqtgraph # Added by Tim for QGIS Animation workbench (should probably be standard)
          py.python-dateutil
          py.pytz
          py.pyyaml
          py.qscintilla-qt5
          py.requests
          py.setuptools
          py.sip
          py.six
          py.sqlalchemy # Added by Tim for QGIS Animation workbench
          py.urllib3

          makeWrapper
          wrapGAppsHook
          #pkgs.wrapQtAppsHook

          gcc
          cmake
          cmakeWithGui
          flex
          bison
          ninja

          draco
          exiv2
          fcgi
          geos
          gsl
          hdf5
          libspatialindex
          libspatialite
          libzip
          netcdf
          openssl
          pdal
          postgresql
          proj
          protobuf
          libsForQt5.qca-qt5
          qscintilla
          libsForQt5.qt3d
          libsForQt5.qtbase
          libsForQt5.qtkeychain
          libsForQt5.qtlocation
          libsForQt5.qtmultimedia
          libsForQt5.qtsensors
          libsForQt5.qtserialport
          #libsForQt5.qtwebkit
          libsForQt5.qtxmlpatterns
          libsForQt5.qwt
          saga # Probably not needed for build
          sqlite
          txt2tags
          zstd
          # See https://discourse.nixos.org/t/python-qt-woes/11808/2
          # Needed to give us functional qt tools in our shell
          qt5.wrapQtAppsHook
          makeWrapper
          bashInteractive
        ];

        shellHook = ''
          echo "🌳 Welcome to the QGIS development environment!"
          setQtEnvironment=$(mktemp --suffix .setQtEnvironment.sh)
          echo "shellHook: setQtEnvironment = $setQtEnvironment"
          makeWrapper "/bin/sh" "$setQtEnvironment" "''${qtWrapperArgs[@]}"
          sed "/^exec/d" -i "$setQtEnvironment"
          source "$setQtEnvironment"
        '';
      };
    # invoke with
    # nix develop .#hugo
    #devShells.${system}.hugo = with pkgs;
    #  mkShell {
    #    buildInputs = [
    #      hugo
    #    ];
    #    shellHook = ''
    #    echo "🌳 Welcome to the HUGO dev environment!"
    #    '';
    #};
  };
}

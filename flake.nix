{
  description = "Kartoza NixOS Flakes";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";
    home-manager.url = "github:nix-community/home-manager/release-24.05";
    nixos-generators = {
      url = "github:nix-community/nixos-generators";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = {
    self,
    home-manager,
    nixpkgs,
    nixos-generators,
  } @ inputs: let
    supportedSystems = [ "x86_64-linux" "aarch64-linux" ];

    # Importing packages from nixpkgs
    pkgsFor = system: import nixpkgs {
      inherit system;
    };

    # Special arguments used across packages and configurations
    specialArgsFor = system: inputs // { inherit system; };

    # Shared modules for Home Manager and other configurations
    sharedModulesFor = system: [
      home-manager.nixosModules.home-manager
      {
        home-manager = {
          useGlobalPkgs = true;
          useUserPackages = true;
          extraSpecialArgs = specialArgsFor system;
        };
      }
    ];

    # Base configuration for ISO image generation
    isoBaseFor = system: {
      isoImage.squashfsCompression = "gzip -Xcompression-level 1";
      systemd.services.sshd.wantedBy = pkgsFor system.lib.mkForce ["multi-user.target"];
      users.users.root.openssh.authorizedKeys.keys = [
        (builtins.readFile ./users/public-keys/id_ed25519_tim.pub)
      ];
    };

    # Function to create NixOS configurations for each host
    makeHostFor = system: import ./functions/make-host.nix {
      nixpkgs = nixpkgs;
      shared-modules = sharedModulesFor system;
      specialArgs = specialArgsFor system;
      inherit system;
    };
  in {
    ######################################################
    ##
    ## Package Definitions
    ##
    ######################################################

    # Default package - utilities to help you prepare for setting up a new machine.
    #
    # Run with:
    # "nix run"
    # or
    # nix run github:timlinux/nix-config
    # or
    # nix run github:timlinux/nix-config#default
    #
    # to include in a config do:
    #
    # { pkgs, ... }: {
    #   nixpkgs.overlays = [(import ../../packages)];
    #   environment.systemPackages = with pkgs; [
    #     qgis
    #   ];
    # }

    packages = {
      x86_64-linux = let pkgs = pkgsFor "x86_64-linux"; in {
        default = pkgs.callPackage ./packages/utils {};
        setup-zfs-machine = pkgs.callPackage ./packages/setup-zfs-machine {};
        qgis-custom = pkgs.qgis.overrideAttrs (oldAttrs: rec {
          pythonBuildInputs =
            oldAttrs.pythonBuildInputs
            ++ [pkgs.numpy pkgs.requests pkgs.future pkgs.matplotlib pkgs.pandas pkgs.geopandas pkgs.plotly pkgs.pyqt5_with_qtwebkit pkgs.pyqtgraph pkgs.rasterio pkgs.sqlalchemy];
        });
        tilemaker = pkgs.callPackage ./packages/tilemaker {};
        gverify = pkgs.callPackage ./packages/gverify {};
        itk4 = pkgs.callPackage ./packages/itk4 {};
        otb = pkgs.callPackage ./packages/otb { self = self; };
        distrobox = pkgs.callPackage ./packages/distrobox {};
        kartoza-plymouth = pkgs.callPackage ./packages/kartoza-plymouth {};
        kartoza-grub = pkgs.callPackage ./packages/kartoza-grub {};
        kartoza-cron = pkgs.callPackage ./packages/kartoza-cron {};
        qgis-conda = pkgs.callPackage ./packages/qgis-conda {};
        iso = nixos-generators.nixosGenerate {
          inherit pkgs;
          modules = [./installer-configuration.nix ./software/system/kartoza-plymouth.nix ./software/system/kartoza-grub.nix ./software/system/ssh.nix];
          format =
            {
              x86_64-linux = "install-iso";
              aarch64-linux = "sd-aarch64-installer";
            }
            .${system};
        };
      };

      aarch64-linux = let pkgs = pkgsFor "aarch64-linux"; in {
        default = pkgs.callPackage ./packages/utils {};
        setup-zfs-machine = pkgs.callPackage ./packages/setup-zfs-machine {};
        qgis-custom = pkgs.qgis.overrideAttrs (oldAttrs: rec {
          pythonBuildInputs =
            oldAttrs.pythonBuildInputs
            ++ [pkgs.numpy pkgs.requests pkgs.future pkgs.matplotlib pkgs.pandas pkgs.geopandas pkgs.plotly pkgs.pyqt5_with_qtwebkit pkgs.pyqtgraph pkgs.rasterio pkgs.sqlalchemy];
        });
        tilemaker = pkgs.callPackage ./packages/tilemaker {};
        gverify = pkgs.callPackage ./packages/gverify {};
        itk4 = pkgs.callPackage ./packages/itk4 {};
        otb = pkgs.callPackage ./packages/otb { self = self; };
        distrobox = pkgs.callPackage ./packages/distrobox {};
        kartoza-plymouth = pkgs.callPackage ./packages/kartoza-plymouth {};
        kartoza-grub = pkgs.callPackage ./packages/kartoza-grub {};
        kartoza-cron = pkgs.callPackage ./packages/kartoza-cron {};
        qgis-conda = pkgs.callPackage ./packages/qgis-conda {};
        iso = nixos-generators.nixosGenerate {
          inherit pkgs;
          modules = [./installer-configuration.nix ./software/system/kartoza-plymouth.nix ./software/system/kartoza-grub.nix ./software/system/ssh.nix];
          format =
            {
              x86_64-linux = "install-iso";
              aarch64-linux = "sd-aarch64-installer";
            }
            .${system};
        };
      };
    };

    ######################################################
    ##
    ## Configurations for each host we manage
    ##
    ######################################################

    nixosConfigurations = builtins.listToAttrs (map (system: {
      name = system;
      value = {
        # Live iso Generation
        # Please read: https://nixos.wiki/wiki/Creating_a_NixOS_live_CD
        # To build:
        # nix build .#nixosConfigurations.${system}.config.system.build.isoImage
        # To run:
        # qemu-system-${system} -enable-kvm -m 8096 -cdrom result/iso/nixos-*.iso
        live = pkgsFor system.lib.nixosSystem {
          specialArgs = specialArgsFor system;
          inherit system;
          modules =
            [
              "${nixpkgs}/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix"
              isoBaseFor system
            ]
            ++ sharedModulesFor system
            ++ [./hosts/iso-gnome.nix];
        };

        crest = makeHostFor system "crest"; # Tim's p14s thinkpad - love this machine!
        waterfall = makeHostFor system "waterfall"; # Tim Tuxedo desktop box
        valley = makeHostFor system "valley"; # Tim headless box
        delta = makeHostFor system "delta"; # Amy Laptop
        lagoon = makeHostFor system "lagoon"; # Vicky laptop
        plain = makeHostFor system "plain"; # Marina laptop
        rock = makeHostFor system "rock"; # Virtman manual testbed
        jeff = makeHostFor system "jeff"; # Jeff - running plasma
        atoll = makeHostFor system "atoll"; # Dorah's Laptop
        crater = makeHostFor system "crater"; # Eli's Laptop
        test-gnome-full = makeHostFor system "test-gnome-full"; # Automated testbed - test gnome
        test-gnome-minimal = makeHostFor system "test-gnome-minimal"; # Automated testbed - test gnome
        test-kde6 = makeHostFor system "test-kde6"; # Automated testbed - test kde6
        test-kde5 = makeHostFor system "test-kde5"; # Automated testbed - test kde5
      };
    }) supportedSystems);
  };
}

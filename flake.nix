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

        crest = makeHostFor system "crest";
        waterfall = makeHostFor system "waterfall";
        valley = makeHostFor system "valley";
        delta = makeHostFor system "delta";
        lagoon = makeHostFor system "lagoon";
        plain = makeHostFor system "plain";
        rock = makeHostFor system "rock";
        jeff = makeHostFor system "jeff";
        atoll = makeHostFor system "atoll";
        crater = makeHostFor system "crater";
        test-gnome-full = makeHostFor system "test-gnome-full";
        test-gnome-minimal = makeHostFor system "test-gnome-minimal";
        test-kde6 = makeHostFor system "test-kde6";
        test-kde5 = makeHostFor system "test-kde5";
      };
    }) supportedSystems);
  };
}

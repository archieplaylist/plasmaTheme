{
  description = "Mystical Blue (Jux) theme for KDE Plasma";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    plasma-manager = {
      url = "github:nix-community/plasma-manager";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };
  };

  outputs = inputs@{ self, nixpkgs, plasma-manager, ... }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
      packages = forAllSystems (system:
        let
          pkgs = import nixpkgs { inherit system; };
        in
        {
          default = pkgs.stdenvNoCC.mkDerivation {
            pname = "jux-plasma-theme";
            version = "1.0";
            src = self;
            dontUnpack = true;
            nativeBuildInputs = [ pkgs.gnutar ];

            installPhase = ''
              runHook preInstall

              mkdir -p \
                "$out/share/color-schemes" \
                "$out/share/aurorae/themes" \
                "$out/share/plasma/desktoptheme" \
                "$out/share/Kvantum" \
                "$out/share/jux-theme/rofi" \
                "$out/share/jux-theme/images" \
                "$out/share/licenses/jux-plasma-theme"

              cp ${self}/JuxTheme.colors "$out/share/color-schemes/"
              tar -xzf ${self}/JuxDeco.tar.gz -C "$out/share/aurorae/themes"
              tar -xzf ${self}/JuxPlasma.tar.gz -C "$out/share/plasma/desktoptheme"
              tar -xzf ${self}/NoMansSkyJux.tar.gz -C "$out/share/Kvantum"
              cp ${self}/rofi/config.rasi "$out/share/jux-theme/rofi/"
              cp -R ${self}/images/. "$out/share/jux-theme/images/"
              cp ${self}/LICENSE "$out/share/licenses/jux-plasma-theme/"

              runHook postInstall
            '';

            meta = {
              description = "Mystical Blue (Jux) theme assets for KDE Plasma";
              platforms = systems;
            };
          };
        });
      checks = forAllSystems (system: {
        package = packages.${system}.default;
      });
    in
    {
      packages = packages;
      checks = checks;

      nixosModules.default = { config, lib, pkgs, ... }:
        let
          cfg = config.programs.juxTheme;
          themePackage = self.packages.${pkgs.stdenv.hostPlatform.system}.default;
        in
        {
          options.programs.juxTheme.enable = lib.mkEnableOption "the Jux Plasma theme package";

          config = lib.mkIf cfg.enable {
            environment.systemPackages = [ themePackage ];
          };
        };

      homeManagerModules.default = { config, lib, pkgs, ... }:
        let
          cfg = config.programs.juxTheme;
          themePackage = self.packages.${pkgs.stdenv.hostPlatform.system}.default;
        in
        {
          imports = [ plasma-manager.homeModules.plasma-manager ];

          options.programs.juxTheme = {
            enable = lib.mkEnableOption "the Jux Plasma theme";
            rofi.enable = lib.mkEnableOption "the bundled Rofi configuration and Nerd Font";
          };

          config = lib.mkIf cfg.enable {
            home.packages = [ themePackage ]
              ++ lib.optionals cfg.rofi.enable [ pkgs.rofi pkgs.nerd-fonts.jetbrains-mono ];

            xdg.dataFile = {
              "color-schemes/JuxTheme.colors".source = "${themePackage}/share/color-schemes/JuxTheme.colors";
              "aurorae/themes/JuxDeco".source = "${themePackage}/share/aurorae/themes/JuxDeco";
              "plasma/desktoptheme/JuxPlasma".source = "${themePackage}/share/plasma/desktoptheme/JuxPlasma";
            } // lib.optionalAttrs cfg.rofi.enable {
              "jux-rofi-images".source = "${themePackage}/share/jux-theme/images";
            };

            xdg.configFile = {
              "Kvantum/NoMansSkyJux".source = "${themePackage}/share/Kvantum/NoMansSkyJux";
            } // lib.optionalAttrs cfg.rofi.enable {
              "rofi/config.rasi".source = "${themePackage}/share/jux-theme/rofi/config.rasi";
            };

            programs.plasma = {
              enable = true;
              workspace = {
                colorScheme = "JuxTheme";
                theme = "JuxPlasma";
                windowDecorations = {
                  library = "org.kde.kwin.aurorae";
                  theme = "__aurorae__svg__JuxDeco";
                };
              };
            };
          };
        };
    };
}
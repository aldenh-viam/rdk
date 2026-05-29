{
  description = "A Nix-flake-based Go development environment";  # from https://github.com/the-nix-way/dev-templates

  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixos-25.11";

  outputs =
    { self, ... }@inputs:

    let
      goVersion = 25; # Change this to update the whole stack

      supportedSystems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];
      forEachSupportedSystem =
        f:
        inputs.nixpkgs.lib.genAttrs supportedSystems (
          system:
          f {
            pkgs = import inputs.nixpkgs {
              inherit system;
              overlays = [ inputs.self.overlays.default ];
            };
          }
        );
    in
    {
      overlays.default = final: prev: {
        go = final."go_1_${toString goVersion}";
      };

      devShells = forEachSupportedSystem (
        { pkgs }:
        {
          default = pkgs.mkShell {
            hardeningDisable = [ "fortify" ];
            packages = with pkgs; [
              go
              gotools
              golangci-lint
              gopls
              gops
              delve

              pkg-config
              x264
              nlopt
              ffmpeg

              python3 # for module_generate_test

              gnuplot
              graphviz
            ];
          };
        }
      );

      packages = forEachSupportedSystem (
        { pkgs }:
        let 
            vendorHash = "sha256-ehLi+IhDlvsdhhj3CTHCNVgDJ6kaAHpEj3Nlzw33p6g=";
        in
        {
          default = pkgs.buildGoModule {
            pname = "rdk";
            version = "dynamic";
            meta.mainProgram = "server";
            src = ./.;
            vendorHash = vendorHash;

            doCheck = false;
            env.CGO_ENABLED = 1;
            subPackages = [ "web/cmd/server" ];

            nativeBuildInputs = with pkgs; [
              pkg-config
            ];
            buildInputs = with pkgs; [
              x264
              nlopt
            ];
            ldflags = [ "-s" "-w" ];
          };
          semi-static = pkgs.buildGoModule {
            pname = "rdk";
            version = "semi-static";
            meta.mainProgram = "server";
            src = ./.;
            vendorHash = vendorHash;

            doCheck = false;
            env.CGO_ENABLED = 1;
            subPackages = [ "web/cmd/server" ];

            nativeBuildInputs = with pkgs; [
              pkg-config
              # upx
            ];
            buildInputs = with pkgs; [
              pkgsStatic.x264
              # remove workaround to build with clang instead of gcc because https://github.com/NixOS/nixpkgs/issues/177129
              # disable tests because https://github.com/NixOS/nixpkgs/blob/6d41bc27aaf7b6a3ba6b169db3bd5d6159cfaa47/pkgs/by-name/nl/nlopt/package.nix#L29-L33
              ((pkgsStatic.nlopt.overrideAttrs (oldAttrs: {
                doCheck = false;
              })).override { clangStdenv = stdenv; })
            ];
            ldflags = [ "-s" "-w" ];
            NIX_LDFLAGS = if pkgs.stdenv.isDarwin
              then "-lc++"
              else "-lstdc++";
            postFixup = ''
              cp $out/bin/server $out/bin/server-fhs
              patchelf --set-interpreter /lib64/ld-linux-x86-64.so.2 $out/bin/server-fhs
              # upx --best --lzma $out/bin/server-fhs
            '';
          };
          cli = pkgs.buildGoModule {
            pname = "viam-cli";
            version = "0.0.0";
            meta.mainProgram = "viam";
            src = ./.;
            vendorHash = vendorHash;

            doCheck = false;
            env.CGO_ENABLED = 0;
            subPackages = [ "cli/viam" ];

            tags = [
              "osusergo"
              "netgo"
              "no_cgo"
            ];
            ldflags = [ "-s" "-w" ];
          };
        }
    );
    };
}



{
  description = "Nais debug image";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    bombon = {
      url = "github:nikstur/bombon";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs:
    inputs.flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import inputs.nixpkgs { inherit system; };
        image-contents = pkgs.buildEnv {
          name = "packages";
          paths =
            let
              extra = pkgs.writeShellScriptBin "go" ''
                #!/bin/sh
                adventure
              '';
              motd = pkgs.writeTextDir "/home/nais/README" ''
                Nais debug shell.
                If you'd like some additional tool or have comments:
                https://github.com/nais/debug/issues

                You have an unsettling feeling that you’ve been here before.
                You see you have curl and openssl, there's a heap of binaries in /bin.
                There's a door to the west

              '';
              profile = pkgs.writeTextDir "/etc/bashrc" ''
                if [ -f /etc/motd ]; then
                  cat /etc/motd
                fi
              '';

              networkTools = with pkgs; [
                curlFull
                dnsutils
                iana-etc
                inetutils
                iproute2
                lsof
                netcat
                nmap
                openssl
                socat
                tcpdump
                wget
              ];
              shellTools = with pkgs; [
                bashInteractive
                bsdgames
                coreutils
                extra
                gnugrep
                gnused
                gnutar
                guile
                htop
                jq
                man-pages
                mg
                motd
                procps
                profile
                ripgrep
                su
                unzip
                util-linux
                vim
                which
                yq
                zip
                zulu
              ];
              persistenceTools = with pkgs; [
                litecli
                pgcli
                redis
              ];
              binaryTools = with pkgs; [ strace ];
              dockerEnv = with pkgs; [
                dockerTools.usrBinEnv
                dockerTools.binSh
                dockerTools.caCertificates
                dockerTools.shadowSetup
              ];
              kafkaTools = [ pkgs.kcat ];
            in
            shellTools ++ binaryTools ++ dockerEnv ++ kafkaTools ++ networkTools ++ persistenceTools;

          pathsToLink = [
            "/bin"
            "/etc"
            "/home/nais"
          ];
        };
        sbom = inputs.bombon.lib.${system}.buildBom image-contents { };
        image = pkgs.dockerTools.buildImage {
          name = "europe-north1-docker.pkg.dev/nais-io/nais/images/debug";
          tag = "latest";

          runAsRoot = ''
            ${pkgs.dockerTools.shadowSetup}
            groupadd -r nais
            groupadd -g 65535 nobody
            useradd -r -g nais -G nobody -u 1069 -d /home/nais -m nais
            chown nais:nais /home/nais
            chmod +w /home/nais
          '';
          copyToRoot = image-contents;
          config = {
            Workingdir = "/home/nais";
            Cmd = [ "bash" ];
            User = "1069";
            Labels.SBOM = pkgs.lib.readFile "${sbom}";
          };
        };
      in
      {
        devShells.default = pkgs.mkShellNoCC {
          inputsFrom = [ image ];
          packages = [ pkgs.sbomnix ];
        };
        formatter = inputs.treefmt-nix.lib.mkWrapper pkgs {
          projectRootFile = "flake.nix";
          programs = {
            prettier.enable = true;
            statix.enable = true;
            nixfmt.enable = true;
            deadnix.enable = true;
          };
          settings.global.excludes = [
            "*.md"
            "*.lock"
            "LICENSE"
          ];
        };
        packages = {
          inherit image sbom;
          default = image;
        };
      }
    );
}

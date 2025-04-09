{
  description = "Nais debug image";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, ... }@inputs:
    inputs.flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import inputs.nixpkgs { inherit system; };
        inherit (pkgs) lib;

        dockerTag = if lib.hasAttr "rev" self then
          "${builtins.toString self.revCount}-${self.shortRev}"
        else
          "gitDirty";
        # Compile workspace code (including 3rd party dependencies)
      in {
        packages = rec {
          default = image;
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
            copyToRoot = pkgs.buildEnv {
              name = "packages";
              paths = let
                extra = (pkgs.writeShellScriptBin "go" ''
                  #!/bin/sh
                  adventure
                '');
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
                persistenceTools = with pkgs; [ redis ];
                binaryTools = with pkgs; [ strace ];
                dockerEnv = with pkgs; [
                  dockerTools.usrBinEnv
                  dockerTools.binSh
                  dockerTools.caCertificates
                ];
                kafkaTools = [ pkgs.kcat ];
              in shellTools ++ binaryTools ++ dockerEnv ++ kafkaTools
              ++ networkTools ++ persistenceTools;

              pathsToLink = [ "/bin" "/etc" "/home/nais" ];
            };
            config = {
              Workingdir = "/home/nais";
              Cmd = [ "bash" ];
              User = "1069";
            };
          };
        };

        formatter = pkgs.nixfmt-rfc-style;
      });
}

{ }:
let
  pkgs = import (builtins.fetchTarball {
    name = "release-19.09";
    url = https://github.com/nixos/nixpkgs/archive/64a3ccb852d4f34abb015503affd845ef03cc0d9.tar.gz;
    sha256 = "0jigsyxlwl5hmsls4bqib0rva41biki6mwnswgmigwq41v6q7k94";
  }) { inherit config; };

  tendermint = pkgs.callPackage ./tendermint.nix {};

  packages = {
    hs-abci-extra = ./hs-abci-extra;
    hs-abci-sdk = ./hs-abci-sdk;
    hs-abci-server = ./hs-abci-server;
    hs-abci-test-utils = ./hs-abci-test-utils;
    hs-abci-types = ./hs-abci-types;
    hs-iavl-client = ./hs-iavl-client;
    hs-tendermint-client = ./hs-tendermint-client;
    nameservice = ./hs-abci-docs/nameservice;
    simple-storage = ./hs-abci-docs/simple-storage;
  };

  repos = {
    avl-auth = pkgs.fetchFromGitHub {
      owner  = "oscoin";
      repo   = "avl-auth";
      rev    = "dfc468845a82cdd7d759943b20853999bc026505";
      sha256 = "005j98hmzzh9ybd8wb073i47nwvv1hfh844vv4kflba3m8d75d80";
    };
    http2-client-grpc = pkgs.fetchFromGitHub {
      owner  = "lucasdicioccio";
      repo   = "http2-client-grpc";
      rev    = "6a1aacfc18e312ef57552133f13dd1024c178706";
      sha256 = "0zqzxd6x3hlhhhq24pybjy18m0r66d9rddl9f2zk4g5k5g0zl906";
    };
    tasty = pkgs.fetchFromGitHub {
      owner  = "feuerbach";
      repo   = "tasty";
      rev    = "dfc4618845a82cdd7d759943b20853999bc026505";
      sha256 = "005j98hmzzh9ybd8wb073i47nwvv1hfh844vv4kflba3m8d75d80";
    };
  };

  repoPackages = {
    inherit (repos) avl-auth http2-client-grpc;
  };

  extra-build-inputs = with pkgs; {
    hs-abci-sdk = [protobuf];
    hs-abci-types = [protobuf];
    hs-iavl-client = [protobuf];
    simple-storage = [protobuf];
    hs-tendermint-client = [tendermint];
  };

  addBuildInputs = inputs: { buildInputs ? [], ... }: { buildInputs = inputs ++ buildInputs; };

  hackageOverrides = self: super: {
/*
    containers = self.callHackageDirect {
      pkg = "containers";
      ver = "0.5.11";
      sha256 = "0smqaj57hkz5ldv5mr636lw6kxxsfn1yq0mbf8cy2c4417d6hyhm";
    } {};
*/
    polysemy = self.callHackageDirect {
      pkg = "polysemy";
      ver = "1.2.3.0";
      sha256 = "1smqaj57hkz5ldv5mr636lw6kxxsfn1yq0mbf8cy2c4417d6hyhm";
    } {};

    /*
    Failures:
      test/DoctestSpec.hs:9:47:
      1) Doctest, Error messages, should pass the doctest
           uncaught exception: ExitCode
           ExitFailure 1
    */
    polysemy-plugin = self.callHackageDirect {
      pkg = "polysemy-plugin";
      ver = "0.2.4.0";
      sha256 = "1bjngyns49j76hgvw3220l9sns554jkqqc9y00dc3pfnik7hva56";
    } {};

    polysemy-zoo = self.callHackageDirect {
      pkg = "polysemy-zoo";
      ver = "0.6.0.0";
      sha256 = "1p0qd1zgnvx7l5m6bjhy9qn6dqdyyfz6c1zb79jggp4lrmjplp7j";
    } {};

    prometheus = self.callHackageDirect {
      pkg = "prometheus";
      ver = "2.1.3";
      sha256 = "04w3cm6r6dh284mg1lpzj4sl6d30ap3idkkdjzck3vcy5p788554";
    } {};

    proto3-suite = self.callHackageDirect {
      pkg = "proto3-suite";
      ver = "0.4.0.0";
      sha256 = "1s2n9h28j8rk9h041pkl4snkrx1ir7d9f3zwnj25an2xmhg5l0fj";
    } {};

    proto3-wire = self.callHackageDirect {
      pkg = "proto3-wire";
      ver = "1.1.0";
      sha256 = "0z8ifpl9vxngd2qaqj6bgg68z52m5i1shhd6j072g3mfdmiin0kv";
    } {};

    #    tasty = pkgs.haskell.lib.dontCheck (self.callCabal2nix "tasty" repos.tasty {});
    #    tasty = pkgs.haskell.lib.addBuildTool (self.callCabal2nix "tasty" repos.tasty {}) (pkgs.haskell.lib.dontCheck super.tasty);
    # tasty = self.callCabal2nix "tasty" repos.tasty {};
/*
    tasty = pkgs.haskell.lib.dontCheck (self.callHackageDirect {
      pkg = "tasty";
      ver = "1.1.0.3";
      sha256 = "1s2n9h28j8rk9h041pkl4snkrx1ir7d9f3zwnj25an2xmhg5l4fj";
    } {});
*/
  };

  localOverrides = self: super:
    builtins.mapAttrs (name: path: (self.callCabal2nix name path {})) packages;

  repoOverrides = self: super:
    builtins.mapAttrs (name: path: (self.callCabal2nix name path {})) repoPackages;

  overrides = self: super:
    let allOverrides =
          hackageOverrides self super
          // repoOverrides self super
          // localOverrides self super;
    in
      builtins.mapAttrs (name: pkg: pkg.overrideAttrs (addBuildInputs (extra-build-inputs.${name} or []))) allOverrides;

  config = {
    packageOverrides = pkgs: {
      haskellPackages = pkgs.haskellPackages.override {
        overrides = pkgs.lib.foldr pkgs.lib.composeExtensions (_: _: {}) [
          overrides
          (self: super: {
            # https://github.com/haskell-haskey/xxhash-ffi/issues/2
            avl-auth = pkgs.haskell.lib.dontCheck super.avl-auth;

            hs-tendermint-client = pkgs.lib.overrideDerivation super.hs-tendermint-client (drv: {
              checkPhase = ''
                tendermint init --home $TMPDIR
                tendermint node --home $TMPDIR --proxy_app=kvstore &
                sleep 3
                '' + drv.checkPhase;
            });
           #                 abci-cli kvstore &
# --rpc.laddr tcp://localhost:26657 --proxy_app=tcp://0.0.0.0:26658 &
#--proxy_app=tcp://kvstore:26658
            hs-abci-sdk = pkgs.haskell.lib.dontCheck super.hs-abci-sdk;
#            hs-tendermint-client = pkgs.haskell.lib.dontCheck super.hs-tendermint-client;
            hs-iavl-client = pkgs.haskell.lib.dontCheck super.hs-iavl-client;
            simple-storage = pkgs.haskell.lib.dontCheck super.simple-storage;
            nameservice = pkgs.haskell.lib.dontCheck super.nameservice;

            proto3-suite = pkgs.haskell.lib.dontCheck super.proto3-suite;

            bloodhound = pkgs.haskell.lib.doJailbreak (pkgs.haskell.lib.unmarkBroken super.bloodhound);
            katip-elasticsearch = pkgs.haskell.lib.dontCheck (pkgs.haskell.lib.unmarkBroken super.katip-elasticsearch);

#            tasty = pkgs.haskell.lib.addBuildTool super.tasty (pkgs.haskell.lib.dontCheck super.tasty);

/*
            tasty = pkgs.haskell.lib.addBuildTool super.tasty
              (if pkgs.buildPlatform != pkgs.hostPlatform
               then self.buildHaskellPackages.tasty
               else pkgs.haskell.lib.dontCheck super.tasty);
*/
            # bootstrapping: tasty depends on a tasty for tests
            #tasty = pkgs.haskell.lib.dontCheck super.tasty;
            #pkgs.haskell.lib.addBuildTool super.tasty (pkgs.haskell.lib.dontCheck super.tasty);
            /*
            tasty = addBuildTool super.tasty
              (if pkgs.buildPlatform != pkgs.hostPlatform
               then self.buildHaskellPackages.tasty
               else dontCheck super.tasty);
            */
          })
        ];
      };
    };
  };

in {
  inherit pkgs overrides;
  inherit tendermint;

  packages = {
    inherit (pkgs.haskellPackages)
      hs-abci-extra
      hs-abci-sdk
      hs-abci-server
      hs-abci-test-utils
      hs-abci-types
      hs-iavl-client
      hs-tendermint-client
      nameservice
      simple-storage
    ;
  };
}

# Definition of the `haskellProjects.${name}` submodule's `config`
project@{ name, lib, pkgs, ... }:
let
  inherit (lib)
    types;

  packageSubmodule = import ./package.nix { inherit project lib pkgs; };

  # Merge the list of attrset of modules.
  mergeModuleAttrs =
    lib.zipAttrsWith (k: vs: { imports = vs; });

  tracePackages = k: x:
    project.config.log.traceDebug "${k} ${builtins.toJSON x}" x;
in
{
  options = {
    packages = lib.mkOption {
      type = types.lazyAttrsOf types.deferredModule;
      default = { };
      apply = packages:
        let
          packages' =
            # Merge user-provided 'packages' with 'defaults.packages'. 
            #
            # Note that the user can override the latter too if they wish.
            mergeModuleAttrs
              [ project.config.defaults.packages packages ];
        in
        tracePackages "${name}.packages:apply" (
          lib.mapAttrs
            (name: v:
              (lib.evalModules {
                modules = [ packageSubmodule v ];
                specialArgs = { inherit name pkgs; };
              }).config
            )
            packages');

      description = ''
        Additional packages to add to `basePackages`.

        Local packages are added automatically (see `config.defaults.packages`):

        You can also override the source for existing packages here.
      '';
    };

    packagesOverlay = lib.mkOption {
      type = import ../../../types/haskell-overlay-type.nix { inherit lib; };
      description = ''
        The Haskell overlay computed from `packages` modules.
      '';
      internal = true;
      default = self: _super:
        let
          inherit (project.config) log;
          build-haskell-package = import ../../../build-haskell-package.nix {
            inherit pkgs lib self log;
          };
          getOrMkPackage = name: cfg:
            if lib.types.path.check cfg.source
            then
              (build-haskell-package name cfg.source cfg.cabal2NixFile)
            else
              log.traceDebug "${name}.callHackage ${cfg.source}"
                (self.callHackage name cfg.source { });
        in
        lib.mapAttrs getOrMkPackage project.config.packages;
    };
  };
}

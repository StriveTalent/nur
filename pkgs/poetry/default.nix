self:
let
  versions = {
    poetry_1_3 = ./1_3.nix;
  };
in
self.lib.mapAttrs' (name: path:
  self.lib.nameValuePair name (import path self)
) versions

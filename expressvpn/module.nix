{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.expressvpn;
in
{
  disabledModules = [ "services/networking/expressvpn.nix" ];

  options.services.expressvpn = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable the ExpressVPN 14.x daemon and CLI/GUI.";
    };

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.callPackage ./package.nix { };
      description = "ExpressVPN package to use.";
    };
  };

  config = lib.mkIf cfg.enable {
    boot.kernelModules = [ "tun" ];

    environment.systemPackages = [ cfg.package ];

    users.groups.expressvpn = { };
    users.groups.expressvpnhnsd = { };

    systemd.tmpfiles.rules = [
      "d  /opt/expressvpn         0755 root root - -"
      "L+ /opt/expressvpn/bin     - - - - ${cfg.package}/bin"
      "L+ /opt/expressvpn/lib     - - - - ${cfg.package}/lib"
      "L+ /opt/expressvpn/plugins - - - - ${cfg.package}/plugins"
      "L+ /opt/expressvpn/qml     - - - - ${cfg.package}/qml"
      "L+ /opt/expressvpn/share   - - - - ${cfg.package}/share"
      "d  /opt/expressvpn/etc     0750 root expressvpn - -"
      "d  /opt/expressvpn/var     0750 root expressvpn - -"
      "d  /var/lib/expressvpn     0750 root expressvpn - -"
    ];

    systemd.services.expressvpn = {
      description = "ExpressVPN daemon";
      after = [
        "network.target"
        "network-online.target"
      ];
      wants = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];
      path = with pkgs; [
        iproute2
        iptables
        systemd
        procps
        psmisc
      ];
      serviceConfig = {
        ExecStart = "${cfg.package}/bin/expressvpn-daemon";
        Restart = "always";
        RestartSec = 5;
      };
      environment.LD_LIBRARY_PATH = "${cfg.package}/lib";
    };
  };
}

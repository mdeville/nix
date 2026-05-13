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

    users = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [ "alice" ];
      description = ''
        Users to add to the `expressvpn` group, which is required to
        traverse `/opt/expressvpn/var` and connect to the daemon's
        control socket at `/opt/expressvpn/var/daemon.sock`.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    boot.kernelModules = [ "tun" ];

    environment.systemPackages = [ cfg.package ];

    users.groups.expressvpn.members = cfg.users;
    users.groups.expressvpnhnsd = { };

    # The vendor daemon authorises Unix-socket peers by reading
    # `readlink("/proc/<peer>/exe")` and matching against an allowlist
    # rooted at `/opt/expressvpn/bin/...`. To make that resolve correctly
    # for binaries shipped in the Nix store we expose the real ELFs at
    # /opt/expressvpn/bin via a bind mount (see `systemd.mounts` below);
    # /opt/expressvpn/bin must therefore be a real directory, not a
    # symlink, so it can serve as a mount point.
    systemd.tmpfiles.rules = [
      "d  /opt/expressvpn         0755 root root - -"
      "d  /opt/expressvpn/bin     0755 root root - -"
      "L+ /opt/expressvpn/lib     - - - - ${cfg.package}/lib"
      "L+ /opt/expressvpn/plugins - - - - ${cfg.package}/plugins"
      "L+ /opt/expressvpn/qml     - - - - ${cfg.package}/qml"
      "L+ /opt/expressvpn/share   - - - - ${cfg.package}/share"
      "d  /opt/expressvpn/etc     0750 root expressvpn - -"
      "d  /opt/expressvpn/var     0750 root expressvpn - -"
      "d  /var/lib/expressvpn     0750 root expressvpn - -"
    ];

    systemd.mounts = [
      {
        description = "ExpressVPN bin (FHS layout for daemon peer-exe authz)";
        what = "${cfg.package}/libexec/expressvpn";
        where = "/opt/expressvpn/bin";
        type = "none";
        options = "bind,ro";
        wantedBy = [ "local-fs.target" ];
      }
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
      unitConfig.RequiresMountsFor = "/opt/expressvpn/bin";
      serviceConfig = {
        ExecStart = "/opt/expressvpn/bin/expressvpn-daemon";
        Restart = "always";
        RestartSec = 5;
        BindReadOnlyPaths = [
          "${pkgs.bash}/bin/bash:/bin/bash"
          "${pkgs.iproute2}/bin/ip:/sbin/ip"
        ];
      };
      environment.LD_LIBRARY_PATH = "${cfg.package}/lib";
    };
  };
}

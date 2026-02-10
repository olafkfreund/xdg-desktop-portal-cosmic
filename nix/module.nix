{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.xdg-desktop-portal-cosmic;
in
{
  options.services.xdg-desktop-portal-cosmic = {
    enable = mkEnableOption "XDG Desktop Portal backend for COSMIC desktop environment";

    package = mkPackageOption pkgs "xdg-desktop-portal-cosmic" {
      default = [ "xdg-desktop-portal-cosmic" ];
      example = literalExpression ''
        pkgs.xdg-desktop-portal-cosmic
      '';
    };

    remoteDesktop = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = ''
          Whether to enable the RemoteDesktop portal interface.

          This allows RDP clients to inject keyboard and mouse input
          via the EIS (Emulated Input Server) protocol.
        '';
      };
    };
  };

  config = mkIf cfg.enable {
    # Ensure xdg-desktop-portal is enabled
    xdg.portal = {
      enable = true;
      extraPortals = [ cfg.package ];
      configPackages = [ cfg.package ];
    };

    # The portal binary and data files (D-Bus service, portal descriptor,
    # systemd user service, portals.conf) are installed by the package
    # into standard XDG locations via the Makefile install target.
    environment.systemPackages = [ cfg.package ];

    # Ensure PipeWire is available for ScreenCast/RemoteDesktop
    services.pipewire.enable = mkDefault true;

    # D-Bus activation: the portal service file references the binary
    # in libexec; the package installs it at the correct path.
    services.dbus.packages = [ cfg.package ];

    # Runtime dependencies: ensure libei is available for EIS input injection
    environment.sessionVariables = mkIf cfg.remoteDesktop.enable {
      # libei needs to be discoverable for the RemoteDesktop portal
    };

    # Systemd hardening for the portal user service
    systemd.user.services.xdg-desktop-portal-cosmic = {
      serviceConfig = {
        NoNewPrivileges = true;
        ProtectSystem = "strict";
        ProtectHome = "read-only";
        PrivateTmp = true;
        ProtectKernelTunables = true;
        ProtectControlGroups = true;
        ProtectKernelModules = true;
        ProtectKernelLogs = true;
        RestrictSUIDSGID = true;
        RestrictNamespaces = true;
        LockPersonality = true;
        RestrictRealtime = true;
        SystemCallArchitectures = "native";
      };
    };
  };
}

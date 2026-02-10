{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.xdg-desktop-portal-cosmic;
in
{
  options.services.xdg-desktop-portal-cosmic = {
    enable = mkEnableOption "XDG Desktop Portal backend for COSMIC desktop environment (user-level)";

    package = mkPackageOption pkgs "xdg-desktop-portal-cosmic" {
      default = [ "xdg-desktop-portal-cosmic" ];
      example = literalExpression ''
        pkgs.xdg-desktop-portal-cosmic
      '';
    };
  };

  config = mkIf cfg.enable {
    home.packages = [ cfg.package ];

    # Install the portal descriptor and portals.conf into the user's
    # XDG data directories so xdg-desktop-portal discovers this backend.
    xdg.dataFile = {
      "xdg-desktop-portal/portals/cosmic.portal".source =
        "${cfg.package}/share/xdg-desktop-portal/portals/cosmic.portal";

      "xdg-desktop-portal/cosmic-portals.conf".source =
        "${cfg.package}/share/xdg-desktop-portal/cosmic-portals.conf";
    };

    # Register the D-Bus user service for activation
    xdg.dataFile."dbus-1/services/org.freedesktop.impl.portal.desktop.cosmic.service".source =
      "${cfg.package}/share/dbus-1/services/org.freedesktop.impl.portal.desktop.cosmic.service";

    # Register the systemd user service
    systemd.user.services.xdg-desktop-portal-cosmic = {
      Unit = {
        Description = "Portal service (COSMIC implementation)";
        PartOf = [ "graphical-session.target" ];
      };
      Service = {
        Type = "dbus";
        BusName = "org.freedesktop.impl.portal.desktop.cosmic";
        ExecStart = "${cfg.package}/libexec/xdg-desktop-portal-cosmic";
      };
    };
  };
}

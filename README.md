# xdg-desktop-portal-cosmic

XDG Desktop Portal backend for the [COSMIC Desktop Environment](https://github.com/pop-os/cosmic-epoch). Provides native implementations of the freedesktop portal interfaces, allowing sandboxed and non-sandboxed applications to interact with the desktop in a standard way.

This is a fork of [pop-os/xdg-desktop-portal-cosmic](https://github.com/pop-os/xdg-desktop-portal-cosmic) with added **RemoteDesktop portal** support for remote input injection via the EIS (Emulated Input Server) protocol.

## Portal Interfaces

| Interface | Description |
|-----------|-------------|
| `org.freedesktop.impl.portal.Access` | Permission dialogs and access control |
| `org.freedesktop.impl.portal.FileChooser` | Native file chooser dialogs |
| `org.freedesktop.impl.portal.Screenshot` | Screen capture and color picking |
| `org.freedesktop.impl.portal.Settings` | Desktop appearance and settings |
| `org.freedesktop.impl.portal.ScreenCast` | Screen sharing via PipeWire |
| `org.freedesktop.impl.portal.RemoteDesktop` | Remote keyboard/mouse input injection via EIS |

## RemoteDesktop Portal

The `RemoteDesktop` portal allows RDP clients (and other remote desktop tools) to inject keyboard and mouse input into COSMIC sessions. It works alongside the `ScreenCast` portal to provide full remote desktop functionality.

### How it works

1. A client (e.g., [cosmic-rdp-server](https://github.com/olafkfreund/cosmic-rdp-server)) calls `CreateSession` to create a portal session
2. `SelectDevices` specifies which input devices are needed (keyboard, pointer, touchscreen)
3. `SelectSources` specifies which screens to share (monitors, windows)
4. `Start` shows a consent dialog to the user and creates a UNIX socket pair for EIS
5. The server-side socket is forwarded to the compositor via D-Bus (`com.system76.CosmicComp.RemoteDesktop.AcceptEisSocket`)
6. `ConnectToEIS` returns the client-side socket to the caller for sending input events

### Requirements

The RemoteDesktop portal requires:
- **COSMIC compositor** with EIS receiver support (see [cosmic-comp-rdp](https://github.com/olafkfreund/cosmic-comp-rdp))
- **libei** for the EIS protocol
- **PipeWire** for screen capture streams

## Building

### Using Nix (recommended)

```bash
nix develop              # Enter dev shell with all dependencies
make                     # Build release binary

# Or build directly with Nix
nix build
```

### Using Cargo (requires system libraries)

Ensure the following development headers are installed: PipeWire, libei, Wayland, libxkbcommon, GLib, fontconfig, freetype, Mesa, Vulkan, D-Bus.

```bash
cargo build --release
```

### Build commands (Makefile)

```bash
make                     # Build release binary
make DEBUG=1             # Build debug binary
make install             # Install to /usr/libexec with D-Bus and systemd files
make prefix=/opt install # Install with custom prefix
make clean               # Clean build artifacts
```

### Installed files

The `make install` target installs:
- `$(libexecdir)/xdg-desktop-portal-cosmic` - portal binary
- `$(datadir)/dbus-1/services/org.freedesktop.impl.portal.desktop.cosmic.service` - D-Bus activation
- `$(libdir)/systemd/user/org.freedesktop.impl.portal.desktop.cosmic.service` - systemd user service
- `$(datadir)/xdg-desktop-portal/portals/cosmic.portal` - portal descriptor
- `$(datadir)/xdg-desktop-portal/cosmic-portals.conf` - portal configuration

## NixOS Module

The flake provides a NixOS module for declarative installation.

### Basic setup

```nix
{
  inputs.xdg-desktop-portal-cosmic.url = "github:olafkfreund/xdg-desktop-portal-cosmic";

  outputs = { self, nixpkgs, xdg-desktop-portal-cosmic, ... }: {
    nixosConfigurations.myhost = nixpkgs.lib.nixosSystem {
      modules = [
        xdg-desktop-portal-cosmic.nixosModules.default
        {
          nixpkgs.overlays = [ xdg-desktop-portal-cosmic.overlays.default ];

          services.xdg-desktop-portal-cosmic = {
            enable = true;
            remoteDesktop.enable = true;  # enabled by default
          };
        }
      ];
    };
  };
}
```

### Module options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `enable` | bool | `false` | Enable the COSMIC portal backend |
| `package` | package | `pkgs.xdg-desktop-portal-cosmic` | Portal package to use |
| `remoteDesktop.enable` | bool | `true` | Enable the RemoteDesktop portal interface |

The module automatically:
- Enables `xdg.portal` with this backend
- Enables PipeWire for ScreenCast/RemoteDesktop
- Registers D-Bus activation files

## Home Manager Module

For user-level installation without system-wide changes.

```nix
{
  inputs.xdg-desktop-portal-cosmic.url = "github:olafkfreund/xdg-desktop-portal-cosmic";

  outputs = { self, nixpkgs, home-manager, xdg-desktop-portal-cosmic, ... }: {
    homeConfigurations."user" = home-manager.lib.homeManagerConfiguration {
      modules = [
        xdg-desktop-portal-cosmic.homeManagerModules.default
        {
          nixpkgs.overlays = [ xdg-desktop-portal-cosmic.overlays.default ];

          services.xdg-desktop-portal-cosmic = {
            enable = true;
          };
        }
      ];
    };
  };
}
```

The Home Manager module installs:
- Portal binary and package
- Portal descriptor and configuration to `~/.local/share/xdg-desktop-portal/`
- D-Bus service file to `~/.local/share/dbus-1/services/`
- systemd user service for D-Bus activation

## Related Projects

| Project | Description |
|---------|-------------|
| [cosmic-rdp-server](https://github.com/olafkfreund/cosmic-rdp-server) | RDP server that uses the RemoteDesktop portal for input injection |
| [cosmic-comp-rdp](https://github.com/olafkfreund/cosmic-comp-rdp) | COSMIC compositor fork with EIS receiver for accepting input from the portal |
| [cosmic-epoch](https://github.com/pop-os/cosmic-epoch) | COSMIC Desktop Environment |

## Architecture

```
RDP Client  -->  cosmic-rdp-server  -->  Portal (RemoteDesktop)  -->  Compositor (EIS)
                                    -->  Portal (ScreenCast)     -->  PipeWire streams
```

The portal acts as the security boundary:
- Shows a consent dialog before allowing remote access
- Creates EIS socket pairs for secure input injection
- Manages per-session device permissions (keyboard, pointer, touchscreen)
- Reuses the existing ScreenCast infrastructure for screen sharing

## License

GPL-3.0-or-later

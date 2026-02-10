# xdg-desktop-portal-cosmic

XDG Desktop Portal backend for the [COSMIC Desktop Environment](https://github.com/pop-os/cosmic-epoch). Provides native implementations of the freedesktop portal interfaces, allowing sandboxed and non-sandboxed applications to interact with the desktop in a standard way.

This is a fork of [pop-os/xdg-desktop-portal-cosmic](https://github.com/pop-os/xdg-desktop-portal-cosmic) with added **RemoteDesktop portal** support for remote input injection via the EIS (Emulated Input Server) protocol.

Part of the [COSMIC Remote Desktop stack](#full-remote-desktop-stack) - works together with [cosmic-rdp-server](https://github.com/olafkfreund/cosmic-rdp-server) (RDP daemon) and [cosmic-comp-rdp](https://github.com/olafkfreund/cosmic-comp-rdp) (compositor).

## Portal Interfaces

| Interface | Description |
|-----------|-------------|
| `org.freedesktop.impl.portal.Access` | Permission dialogs and access control |
| `org.freedesktop.impl.portal.FileChooser` | Native file chooser dialogs |
| `org.freedesktop.impl.portal.Screenshot` | Screen capture and color picking |
| `org.freedesktop.impl.portal.Settings` | Desktop appearance and settings |
| `org.freedesktop.impl.portal.ScreenCast` | Screen sharing via PipeWire |
| `org.freedesktop.impl.portal.RemoteDesktop` | Remote keyboard/mouse/touch input injection via EIS |

## RemoteDesktop Portal

The `RemoteDesktop` portal allows RDP clients (and other remote desktop tools) to inject keyboard, mouse, and touch input into COSMIC sessions. It works alongside the `ScreenCast` portal to provide full remote desktop functionality.

### How it works

```
cosmic-rdp-server                 xdg-desktop-portal-cosmic              cosmic-comp-rdp
       |                                    |                                    |
       |  CreateSession()                   |                                    |
       |----------------------------------->|                                    |
       |                                    |                                    |
       |  SelectDevices(keyboard, pointer)  |                                    |
       |----------------------------------->|                                    |
       |                                    |                                    |
       |  SelectSources(monitors)           |                                    |
       |----------------------------------->|                                    |
       |                                    |                                    |
       |  Start()                           |                                    |
       |----------------------------------->|                                    |
       |                          Show consent dialog                            |
       |                          Create UNIX socket pair                        |
       |                                    |                                    |
       |                                    |  AcceptEisSocket(server_fd)        |
       |                                    |----------------------------------->|
       |                                    |                                    |
       |                                    |                    EIS handshake + seat creation
       |                                    |                                    |
       |  ConnectToEIS() -> client_fd       |                                    |
       |<-----------------------------------|                                    |
       |                                    |                                    |
       |  Send input via EIS protocol  -----|---(through socket pair)----------->|
       |                                    |                    Inject into Smithay
```

1. A client (e.g., [cosmic-rdp-server](https://github.com/olafkfreund/cosmic-rdp-server)) calls `CreateSession` to create a portal session
2. `SelectDevices` specifies which input devices are needed (keyboard, pointer, touchscreen)
3. `SelectSources` specifies which screens to share (monitors, windows)
4. `Start` shows a consent dialog to the user and creates a UNIX socket pair for EIS
5. The server-side socket is forwarded to the compositor via D-Bus (`com.system76.CosmicComp.RemoteDesktop.AcceptEisSocket`)
6. `ConnectToEIS` returns the client-side socket to the caller for sending input events

### Security model

The portal acts as the security boundary for remote desktop access:

- **Consent dialog:** Users must explicitly approve each remote desktop session before input injection or screen sharing begins
- **Per-session isolation:** Each session gets its own UNIX socket pair; sessions cannot interfere with each other
- **Device permissions:** The caller must declare which device types it needs (keyboard, pointer, touchscreen); only approved types are forwarded
- **Session lifecycle:** Sessions are cleaned up when the portal session ends or the client disconnects

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

Install the required development headers for your distribution:

**Fedora/RHEL:**
```bash
sudo dnf install pipewire-devel libei-devel wayland-devel libxkbcommon-devel \
  glib2-devel fontconfig-devel freetype-devel mesa-libGL-devel mesa-libEGL-devel \
  vulkan-loader-devel dbus-devel gbm-devel clang-devel
```

**Debian/Ubuntu:**
```bash
sudo apt install libpipewire-0.3-dev libei-dev libwayland-dev libxkbcommon-dev \
  libglib2.0-dev libfontconfig-dev libfreetype-dev libgl-dev libegl-dev \
  libvulkan-dev libdbus-1-dev libgbm-dev clang
```

**Arch Linux:**
```bash
sudo pacman -S pipewire libei wayland libxkbcommon glib2 fontconfig freetype2 \
  mesa vulkan-icd-loader dbus clang
```

Then build:
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
- Icons in `$(datadir)/icons/hicolor/`

### Building an AUR package (Arch Linux)

Create a `PKGBUILD`:

```bash
# Maintainer: Your Name <you@example.com>
pkgname=xdg-desktop-portal-cosmic-rdp
pkgver=0.1.0
pkgrel=1
pkgdesc="XDG Desktop Portal backend for COSMIC with RemoteDesktop support"
arch=('x86_64' 'aarch64')
url="https://github.com/olafkfreund/xdg-desktop-portal-cosmic"
license=('GPL-3.0-or-later')
depends=('pipewire' 'libei' 'wayland' 'libxkbcommon' 'glib2' 'dbus' 'mesa')
makedepends=('cargo' 'clang' 'pkg-config')
provides=('xdg-desktop-portal-cosmic')
conflicts=('xdg-desktop-portal-cosmic')
source=("$pkgname-$pkgver.tar.gz::$url/archive/v$pkgver.tar.gz")
sha256sums=('SKIP')

prepare() {
  cd "xdg-desktop-portal-cosmic-$pkgver"
  export RUSTUP_TOOLCHAIN=stable
  cargo fetch --locked --target "$(rustc -vV | sed -n 's/host: //p')"
}

build() {
  cd "xdg-desktop-portal-cosmic-$pkgver"
  export RUSTUP_TOOLCHAIN=stable
  make
}

package() {
  cd "xdg-desktop-portal-cosmic-$pkgver"
  make DESTDIR="$pkgdir" install
}
```

Build and install:
```bash
makepkg -si
```

### Building a Debian package

Create the `debian/` directory structure:

```bash
mkdir -p debian/source
```

**`debian/control`:**
```
Source: xdg-desktop-portal-cosmic
Section: x11
Priority: optional
Maintainer: Your Name <you@example.com>
Build-Depends: debhelper-compat (= 13), cargo, rustc,
 clang, pkg-config, libpipewire-0.3-dev, libei-dev,
 libwayland-dev, libxkbcommon-dev, libglib2.0-dev,
 libfontconfig-dev, libfreetype-dev, libgl-dev, libegl-dev,
 libvulkan-dev, libdbus-1-dev, libgbm-dev
Standards-Version: 4.7.0
Homepage: https://github.com/olafkfreund/xdg-desktop-portal-cosmic

Package: xdg-desktop-portal-cosmic
Architecture: any
Depends: ${shlibs:Depends}, ${misc:Depends}, pipewire, xdg-desktop-portal
Provides: xdg-desktop-portal-backend
Description: XDG Desktop Portal backend for COSMIC with RemoteDesktop
 Provides native COSMIC implementations of the freedesktop portal
 interfaces including ScreenCast, RemoteDesktop (EIS-based input
 injection), FileChooser, Screenshot, Settings, and Access.
```

**`debian/rules`:**
```makefile
#!/usr/bin/make -f
%:
	dh $@

override_dh_auto_build:
	make

override_dh_auto_install:
	make DESTDIR=debian/xdg-desktop-portal-cosmic install
```

**`debian/changelog`:**
```
xdg-desktop-portal-cosmic (0.1.0-1) unstable; urgency=medium

  * Initial release with RemoteDesktop portal support.

 -- Your Name <you@example.com>  Mon, 10 Feb 2026 00:00:00 +0000
```

**`debian/source/format`:**
```
3.0 (quilt)
```

Build the package:
```bash
dpkg-buildpackage -us -uc -b
```

## Installation

### NixOS Module

The flake provides a NixOS module for declarative installation.

#### Basic setup

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

#### NixOS module options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `enable` | bool | `false` | Enable the COSMIC portal backend |
| `package` | package | `pkgs.xdg-desktop-portal-cosmic` | Portal package to use |
| `remoteDesktop.enable` | bool | `true` | Enable the RemoteDesktop portal interface |

The module automatically:
- Enables `xdg.portal` with this backend
- Enables PipeWire for ScreenCast/RemoteDesktop
- Registers D-Bus activation files

### Home Manager Module

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

### Manual installation

After building:
```bash
sudo make install
```

This installs the binary, D-Bus service files, systemd unit, and portal descriptors.

## Full Remote Desktop Stack

For a complete remote desktop setup, you need all three components:

```
                                    +-----------------------+
                                    |  cosmic-comp-rdp      |
                                    |  (compositor + EIS)   |
                                    +-----------^-----------+
                                                |
                                    AcceptEisSocket(fd)
                                                |
+------------+     +-------------------+     +--+--------------------------+
| RDP Client | --> | cosmic-rdp-server | --> | xdg-desktop-portal-cosmic   |
| (mstsc,    |     | (RDP daemon)      |     | (this repo)                 |
| FreeRDP,   | <-- | RDP protocol,     | <-- | RemoteDesktop + ScreenCast  |
| Remmina)   |     | TLS, auth         |     | consent dialog, EIS sockets |
+------------+     +-------------------+     +-----------------------------+
```

| Component | Repository | Purpose |
|-----------|-----------|---------|
| [cosmic-rdp-server](https://github.com/olafkfreund/cosmic-rdp-server) | RDP daemon | RDP protocol server, capture + input orchestration |
| [xdg-desktop-portal-cosmic](https://github.com/olafkfreund/xdg-desktop-portal-cosmic) | This repo | RemoteDesktop + ScreenCast portal interfaces, consent dialog |
| [cosmic-comp-rdp](https://github.com/olafkfreund/cosmic-comp-rdp) | Compositor fork | EIS receiver for input injection |

### NixOS example (all three components)

```nix
{
  inputs = {
    cosmic-rdp-server.url = "github:olafkfreund/cosmic-rdp-server";
    xdg-desktop-portal-cosmic.url = "github:olafkfreund/xdg-desktop-portal-cosmic";
    cosmic-comp.url = "github:olafkfreund/cosmic-comp-rdp";
  };

  outputs = { self, nixpkgs, cosmic-rdp-server, xdg-desktop-portal-cosmic, cosmic-comp, ... }: {
    nixosConfigurations.myhost = nixpkgs.lib.nixosSystem {
      modules = [
        cosmic-rdp-server.nixosModules.default
        xdg-desktop-portal-cosmic.nixosModules.default
        cosmic-comp.nixosModules.default
        {
          nixpkgs.overlays = [
            cosmic-rdp-server.overlays.default
            xdg-desktop-portal-cosmic.overlays.default
            cosmic-comp.overlays.default
          ];

          # Compositor with EIS support
          services.cosmic-comp.enable = true;

          # Portal with RemoteDesktop interface (this repo)
          services.xdg-desktop-portal-cosmic.enable = true;

          # RDP server
          services.cosmic-rdp-server = {
            enable = true;
            openFirewall = true;
            settings.bind = "0.0.0.0:3389";
          };
        }
      ];
    };
  };
}
```

### Component compatibility

All three repositories use compatible dependency versions:

| Dependency | cosmic-rdp-server | xdg-desktop-portal-cosmic | cosmic-comp-rdp |
|------------|-------------------|---------------------------|-----------------|
| reis (libei) | 0.5 | 0.5 | 0.5 |
| zbus (D-Bus) | 5.x | 5.x | 5.x |
| ashpd (portals) | 0.12 | 0.12 | - |
| pipewire | 0.8 | git (freedesktop) | - |

D-Bus interface chain:
- RDP server calls portal `org.freedesktop.impl.portal.RemoteDesktop` with `ConnectToEIS`
- Portal calls compositor `com.system76.CosmicComp.RemoteDesktop.AcceptEisSocket(fd)`
- Compositor creates EIS seat and begins receiving input events

## Related Projects

| Project | Description |
|---------|-------------|
| [cosmic-rdp-server](https://github.com/olafkfreund/cosmic-rdp-server) | RDP server that uses the RemoteDesktop portal for input injection |
| [cosmic-comp-rdp](https://github.com/olafkfreund/cosmic-comp-rdp) | COSMIC compositor fork with EIS receiver for accepting input from the portal |
| [cosmic-epoch](https://github.com/pop-os/cosmic-epoch) | COSMIC Desktop Environment |
| [xdg-desktop-portal-cosmic](https://github.com/pop-os/xdg-desktop-portal-cosmic) | Upstream COSMIC portal (without RemoteDesktop) |

## License

GPL-3.0-or-later

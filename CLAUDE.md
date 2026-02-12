# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

XDG Desktop Portal backend for the COSMIC Desktop Environment. Implements the `org.freedesktop.impl.portal.desktop.cosmic` DBus service, providing system integration for sandboxed applications (file chooser, screenshots, screen sharing, remote desktop with input injection, access dialogs, appearance settings).

## Build Commands

This project uses **Makefile** (not `just` like other COSMIC projects):

```bash
make                    # Release build
make DEBUG=1            # Debug build
make clean              # Clean target/
make distclean          # Clean target/, .cargo, vendor
sudo make install       # Install binary, DBus/systemd services, portal config, icons
make VENDOR=1           # Build with vendored dependencies (offline)
```

Under the hood, the Makefile runs `cargo build --release --bin xdg-desktop-portal-cosmic`.

### Nix

```bash
nix build               # Build with Nix (crane + fenix toolchain)
nix develop              # Dev shell with pipewire, libxkbcommon, libglvnd
```

Build deps: `pkg-config`, `bindgenHook`. Runtime deps: `pipewire`, `libxkbcommon`, `libglvnd`.

### Running Examples

```bash
cargo run --example screencast -- [--source output|window|virtual] [--encoder vaapi|nvenc]
cargo run --example file_chooser
```

## Architecture

### No Main Window Pattern

The app runs as a headless Iced/libcosmic application (`no_main_window(true)`) that creates transient windows on demand when portal requests arrive via DBus. The `view()` method is `unimplemented!()` — only `view_window()` is used.

### Event Flow

```
DBus request arrives
  → subscription.rs (establishes zbus connection, registers all portal interfaces)
  → tokio::mpsc channel → subscription::Event
  → app.rs (CosmicPortal::update dispatches by Msg variant)
  → Portal module creates/manages a window for the specific dialog
  → Response sent back through the DBus request's oneshot channel
```

### Key Modules

| Module | Purpose |
|--------|---------|
| `main.rs` | DBus types (`PortalResponse`, `Request`, `Session`, `Settings`), entry point |
| `app.rs` | `CosmicPortal` — the Iced app struct, message routing, output tracking |
| `subscription.rs` | DBus connection lifecycle, portal interface registration, config watching |
| `screenshot.rs` | Screenshot capture via Wayland screencopy, PNG encoding, clipboard/file save |
| `screencast.rs` | ScreenCast DBus interface — session creation, source selection |
| `screencast_thread.rs` | PipeWire stream setup, DMA-buf/SHM frame capture, video streaming |
| `screencast_dialog.rs` | Screen share source selection UI |
| `remotedesktop.rs` | RemoteDesktop DBus interface — session, device selection, EIS input forwarding |
| `remotedesktop_dialog.rs` | Remote desktop consent dialog UI with device/screen selection |
| `file_chooser.rs` | File open/save dialogs using `cosmic-files` |
| `access.rs` | Permission request dialogs |
| `wayland/mod.rs` | `WaylandHelper` — shared Wayland state (outputs, toplevels, screencopy, GBM) |
| `widget/` | Custom Iced widgets for screenshot UI, rectangle selection, output selection |

### Workspace

- **`cosmic-portal-config/`** — Config types crate (`com.system76.CosmicPortal`, version 1). Defines `Config`, `Screenshot`, `ImageSaveLocation`, `Choice`, `Rect`. Uses `cosmic-config` for persistence.

### DBus Interfaces Implemented

Registered at `/org/freedesktop/portal/desktop`:
- `org.freedesktop.impl.portal.Access` — permission dialogs
- `org.freedesktop.impl.portal.FileChooser` — file open/save
- `org.freedesktop.impl.portal.Screenshot` — screen capture
- `org.freedesktop.impl.portal.ScreenCast` — screen sharing (PipeWire)
- `org.freedesktop.impl.portal.RemoteDesktop` — remote control with EIS input injection (keyboard, pointer, touchscreen)
- `org.freedesktop.impl.portal.Settings` — appearance (color-scheme, accent-color, contrast)

### RemoteDesktop & EIS

The RemoteDesktop portal extends ScreenCast sessions with input injection via EIS (Emulated Input Server). The `ConnectToEIS` method creates a Unix socket pair: the server-side fd is forwarded to `com.system76.CosmicComp.RemoteDesktop` via DBus, and the client-side fd is returned to the requesting application. The consent dialog is always shown (restore data is never used to skip it) to prevent unauthorized remote control. Device types (keyboard, pointer, touchscreen) are selected during `SelectDevices` and displayed in the consent dialog.

### Cancellation Pattern

Portal requests use `Request::run()` which wraps the task in `futures::future::abortable()`. The DBus `Request.Close()` method triggers the abort handle, and the `on_cancel` callback cleans up state.

### Thread Safety

`WaylandHelper` wraps an `Arc<WaylandHelperInner>` with `Mutex` for shared state (outputs, toplevels, DMA-buf). The screencasting thread runs separately and communicates via PipeWire's event loop.

## Key Dependencies

- **libcosmic** (pop-os) — Iced-based GUI framework. Note: `a11y` feature is disabled (crashes file chooser)
- **zbus 5** — Async DBus (tokio backend)
- **pipewire-rs** (freedesktop.org) — PipeWire stream management for screencasting
- **cosmic-files** (pop-os) — File chooser dialog UI with GVFS support
- **cosmic-client-toolkit / cosmic-protocols** (pop-os) — Wayland screencopy, DMA-buf, output/toplevel info
- **gbm** — GPU buffer management for zero-copy screen capture
- **reis** — EIS (Emulated Input Server) protocol client for remote desktop input injection

## i18n

Uses Fluent via `i18n-embed`. Source strings in `i18n/en/xdg_desktop_portal_cosmic.ftl`. The `fl!()` macro provides compile-time checked translations. 80+ languages supported, managed through Weblate.

## Portal Configuration Files

- `data/cosmic.portal` — registers interfaces and `UseIn=COSMIC`
- `data/cosmic-portals.conf` — portal preference order (cosmic, then gtk fallback)
- `data/dbus-1/*.service.in` — DBus activation service (uses `@libexecdir@` placeholder)
- `data/*.service.in` — systemd user service

## Release Profile

```toml
opt-level = 3
lto = "thin"
panic = "abort"     # Reduces binary size significantly
```

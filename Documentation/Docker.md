---
sidebar_label: Docker
---

# Star Wars: Battlefront Docker Container

This Docker container runs a Star Wars: Battlefront (2004) dedicated server. It is built on the WINE image. The game has no separate server program, so the container runs the game's own `Battlefront.exe /autonet dedicated` headless under Wine. The container doesn't download the game, so you provide the files.

## Quick Start

```yaml
services:
  battlefront:
    image: lancommander/starwarsbattlefront:latest
    container_name: battlefront

    ports:
      - 3658:3658/udp
      - 3657:3657/udp

    volumes:
      - "/data/Servers/Star Wars Battlefront/Conquest:/config"

    environment:
      SWBF_SERVER_NAME: "My Battlefront Server"

    user: root
    cap_add:
      - SYS_ADMIN
    security_opt:
      - apparmor:unconfined

    restart: unless-stopped
```

Copy the game folder (the one with `GameData/Battlefront.exe`) into `Server/` before the first start. You can instead set `SWBF_ARCHIVE_URL` to a zip of it.

Use the GOG/Steam release (v1.3.7.4, with `Galaxy.dll` next to `Battlefront.exe`), and give players the same build. The 2004 CD release (1.2) is a different network version.

## How It Starts

1. `PostInitialization/10-InitializeWinePrefix.ps1` (from the WINE image) creates the Wine prefix in `/config/wineprefix`.
2. `PostInitializeWinePrefix/20-InstallD3DX9.ps1` copies Microsoft's `d3dx9_43.dll` (cached in the image) into the prefix and sets a `native` DLL override for it. A marker file, `wineprefix/.lancommander-d3dx9_43`, records that the install is done. Delete it to reinstall.
3. `PostInitialization/20-InstallBattlefront.ps1` checks for `Server/GameData/Battlefront.exe`. If it's missing and `SWBF_ARCHIVE_URL` is set, the hook downloads the archive to `/config`, extracts `GameData/` (without `Movies/`) into `Server/`, and remounts the overlay.
4. `START_EXE` (`/usr/local/bin/swbf-server`) checks the map codes in `SWBF_MAPS`. It then runs `wine-run Battlefront.exe /norender /nosound /lan /autonet dedicated /gamename <name> ... <maps>` from `GameData/`.

The game writes nothing to stdout and keeps no log file, so `docker logs` only shows the command line (passwords masked) and the rotation size:

```
Starting: Battlefront.exe /norender /nosound /lan /autonet dedicated /gamename LANCommander SWBF /playerlimit 32 ... /adminpw ****   bes2r 400 400 tat3c hot1i
Rotation: 3 map(s)
```

### Why these flags

- `/autonet dedicated` makes the game host without a local player.
- `/norender` skips drawing frames, so the server needs no display. Idle use is about 5% of a core instead of over 100% when rendering under Xvfb. In this mode the game hands D3DX a stub device. Wine's builtin `D3DXCheckTextureRequirements` crashes on that device (page fault in `d3dx9_43`), so the native DLL is installed.
- `/lan` hosts on the LAN. Without it, the GOG/Steam build hosts through GOG Galaxy lobbies and opens no UDP ports at all.
- `/nosound` because there's no sound device. ALSA "cannot find card" messages are harmless.

## Configuration Options

### Ports

- **3658/udp**: Game. Clients connect here and the server pings each one about once a second.
- **3657/udp**: LAN browser. A client broadcasts a 13-byte query to 255.255.255.255:3657 and the server replies by broadcast.

Neither port can be changed; the game has no port option. Only one server can run per IP address.

To check that the server is up, send the query `00 ff ff 00 00 ca f7 cf 0e 04 10 00 00` to UDP 3657 on the server's IP, from a socket bound to port 3657. The reply is bit-packed. Read LSB-first, starting 6 bits in, it holds a length-prefixed server name (`\x0bHello World`) and later the player limit.

### Environment Variables

See the [README](../README.md#environment-variables) for the table, the rotation format and the map codes.

Other `Battlefront.exe` options that can go in `SWBF_EXTRA_ARGS`: `/randomize`, `/heroes`, `/noai`, `/bandwidth`, `/nowait`. They have not been tested in this image.

### Hooks

| Hook | When |
|------|------|
| `PreInstallBattlefront` / `PostInstallBattlefront` | Around the game file check/download |
| `PreInitializeWinePrefix` / `PostInitializeWinePrefix` | Around Wine prefix creation (WINE image) |

Put `.ps1` scripts in `config/Scripts/Hooks/<HookName>/`.

## Troubleshooting

- **The container exits with an `SWBF_MAPS:` message.** A map code is unknown, has the wrong era letter (each map exists only in the eras listed in the README), or its level isn't installed. Battlefront itself would crash on it without binding a port.
- **`Unhandled page fault on read access to 00000000 at address 7865xxxx`.** That address is in Wine's builtin `d3dx9_43`, so the native DLL isn't being used. Delete `wineprefix/.lancommander-d3dx9_43` and restart.
- **The server runs but no UDP ports are open.** `/lan` is missing from the command line, which can only happen with a custom `START_EXE`. Without it the game hosts through GOG Galaxy.
- **Clients don't see the server in the LAN list.** Discovery is a broadcast on 3657, which Docker port mapping doesn't forward. Use macvlan/ipvlan or host networking. Also check the client runs the same game build (GOG/Steam 1.3.7).
- **`docker stop` waits out its 10-second timeout.** The base image's entrypoint doesn't pass SIGTERM on to the server, so Docker kills it at the timeout. The game keeps no state, so nothing is lost. (The launcher traps SIGTERM and runs `wineserver -k` for when the signal does reach it.)
- **Edits to `Overlay/` from the host while the container runs don't show up.** OverlayFS caches the upper directory. Restart the container, or edit through `Merged/` inside it (`docker exec`).

# Star Wars: Battlefront Server (Docker)

This repository provides a Dockerized **Star Wars: Battlefront** (2004) dedicated server. The game has no separate or Linux server: `Battlefront.exe` hosts one itself with `/autonet dedicated`, so the image runs the game's own executable headless under Wine.
The image builds on [`lancommander/wine`](https://github.com/LANCommander/LANCommander.Servers.WINE). It supports file overlaying using OverlayFS.

---

## Features

- Runs `Battlefront.exe /norender /nosound /lan /autonet dedicated` under Wine with no display. Idle use is about 5% of a core and 180 MB.
- A native `d3dx9_43.dll` is installed into the Wine prefix automatically. Wine's builtin one crashes in `/norender` mode.
- Server name, passwords, bots, difficulty and the map rotation come from environment variables. Map codes are checked against the installed maps before the game starts.
- Hosts on the LAN, where the in-game LAN browser finds it. It doesn't use GOG Galaxy or GameSpy.
- Supports file overlaying using OverlayFS (no file copying required)

## Docker Compose Example

```yaml
services:
  battlefront:
    image: lancommander/starwarsbattlefront:latest
    container_name: battlefront

    ports:
      - "3658:3658/udp"
      - "3657:3657/udp"

    volumes:
      - ./config:/config

    environment:
      SWBF_SERVER_NAME: "My Battlefront Server"
      SWBF_ADMIN_PASSWORD: "change-me"
      SWBF_MAPS: "bes2r 400 400; bes2a 400 400; tat2i; hot1i"

    user: root
    cap_add:
      - SYS_ADMIN
    security_opt:
      - apparmor:unconfined

    restart: unless-stopped
```

The LAN browser works by broadcast, which doesn't cross Docker port mapping. Give the container its own LAN address (macvlan/ipvlan, or `network_mode: host`) so clients can find it. Behind port mapping, clients can't discover it in the LAN browser.

---

## Game Files

Star Wars: Battlefront is retail software with no public download. Provide the game folder (the one that holds `GameData/Battlefront.exe`):

- copy it to `config/Server/`, **or**
- set `SWBF_ARCHIVE_URL` to a zip of it (`GameData/` at the zip root or inside one top-level folder, e.g. a LANCommander archive). It is downloaded and extracted on first start, if `Server/GameData/Battlefront.exe` doesn't exist yet. Only `GameData/` is extracted, without its cutscenes. `file://` URLs work.

The image is built and tested with the **GOG/Steam release (v1.3.7.4)**, the one that ships `Galaxy.dll`. Clients must run the same build as the server: the 2004 CD release (1.2) and its separate dedicated server can't play with it.

## Directory Layout (Host)

```text
.
└── config/
    ├── Server/            # Star Wars: Battlefront install
    │   └── GameData/      #   Battlefront.exe, Data/_LVL_PC/, AddOn/
    ├── Overlay/           # Your files, layered on top of Server/ (e.g. mod maps in GameData/AddOn/)
    ├── Merged/            # Overlayfs merged view (auto-created, the server runs here)
    ├── wineprefix/        # Wine prefix with native d3dx9_43 (auto-created)
    └── Scripts/
        └── Hooks/         # PowerShell scripts run at container lifecycle hooks
```

---

## Environment Variables

These are in addition to the [WINE image's variables](https://github.com/LANCommander/LANCommander.Servers.WINE#environment).

| Variable | Description | Default |
|----------|-------------|---------|
| `SWBF_SERVER_NAME` | Server name in the LAN browser (`/gamename`) | `Star Wars Battlefront Server` |
| `SWBF_PASSWORD` | Join password (`/password`); empty for none | |
| `SWBF_ADMIN_PASSWORD` | In-game admin password (`/adminpw`); empty for none | |
| `SWBF_MAX_PLAYERS` | Player limit (`/playerlimit`), up to 32 | `32` |
| `SWBF_MIN_PLAYERS` | Players needed before a match starts (`/playercount`) | `1` |
| `SWBF_BOTS` | AI units per team (`/bots`) | `8` |
| `SWBF_DIFFICULTY` | AI difficulty (`/difficulty`): 1 easy, 2 medium, 3 hard | `2` |
| `SWBF_TEAM_DAMAGE` | Friendly fire. `false` passes `/noteamdamage`. | `true` |
| `SWBF_AUTO_AIM` | Aim assist. `false` passes `/noaim`. | `true` |
| `SWBF_SIDE_SELECT` | Let players choose their side (`/sideselect`) | `false` |
| `SWBF_SPAWN_INVINCIBILITY` | Seconds of spawn invincibility (`/spawn`) | `5` |
| `SWBF_TPS` | Server simulation rate (`/tps`). The game's own default is 20. | `30` |
| `SWBF_THROTTLE` | Upload bandwidth limit in kbit/s (`/throttle`) | `2048` |
| `SWBF_MAPS` | Map rotation, see below | 10 maps, see below |
| `SWBF_EXTRA_ARGS` | Raw arguments added before the map list (for example `/randomize`) | |
| `SWBF_ARCHIVE_URL` | Zip of the game folder, used if `Server/GameData/Battlefront.exe` is missing | |
| `WINE_XVFB` | The server needs no display, so the image turns Xvfb off | `false` |

An empty variable leaves its flag off the command line, so the game uses its own default.

### Map rotation

`SWBF_MAPS` is a `;`-separated list of `map` or `map tickets1 tickets2` entries. The two numbers are the reinforcement counts for each side; without them the map uses its own. The default is `bes2r; bes2a; tat2r; tat2i; nab2c; hot1i; kas2c; yav1i; geo1r; end1a`.

A code is the world, its number and an era letter: `r` (Republic) or `c` (CIS) for the Clone Wars, `i` (Empire) or `a` (Alliance) for the Galactic Civil War. Each map exists only in the eras listed:

| Map | Codes |
|-----|-------|
| Bespin: Platforms | `bes1r`, `bes1a` |
| Bespin: Cloud City | `bes2r`, `bes2a` |
| Endor: Bunker | `end1a` |
| Geonosis: Spire | `geo1r` |
| Hoth: Echo Base | `hot1i` |
| Kamino: Tipoca City | `kam1c` |
| Kashyyyk: Islands | `kas1c`, `kas1i` |
| Kashyyyk: Docks | `kas2c`, `kas2i` |
| Naboo: Plains | `nab1c`, `nab1i` |
| Naboo: Theed | `nab2c`, `nab2a` |
| Rhen Var: Harbor | `rhn1r`, `rhn1i` |
| Rhen Var: Citadel | `rhn2c`, `rhn2a` |
| Tatooine: Dune Sea | `tat1r`, `tat1i` |
| Tatooine: Mos Eisley | `tat2r`, `tat2i` |
| Tatooine: Jabba's Palace (add-on) | `tat3c`, `tat3a` |
| Yavin 4: Temple | `yav1c`, `yav1i` |
| Yavin 4: Arena | `yav2r`, `yav2i` |

Battlefront crashes on a map it doesn't have, so the launcher refuses unknown codes. Mod maps work if their level file is in `GameData/AddOn/` (put them in `Overlay/GameData/AddOn/`); clients need the same mod.

See [Documentation/Docker.md](Documentation/Docker.md) for more detail.

---

## Building

The image is built `FROM lancommander/wine:latest` by default. To build against a local base image:

```bash
docker build --build-arg BASE_IMAGE=lancommander/wine:local -t lancommander/starwarsbattlefront:local .
```

The DirectX June 2010 redistributable is downloaded at build time and verified by sha256, and only its 32-bit `d3dx9_43.dll` (also sha256-checked) is kept. See `DIRECTX_REDIST_URL`, `DIRECTX_REDIST_SHA256` and `D3DX9_43_SHA256` in the Dockerfile.

---

## License

Star Wars: Battlefront, Wine and the DirectX redistributable are distributed under their respective licenses.
This repository contains only Docker build logic and helper scripts licensed under MIT.

# syntax=docker/dockerfile:1.7

# Override to build against a locally built base, e.g. lancommander/wine:local
ARG BASE_IMAGE=lancommander/wine:latest
FROM ${BASE_IMAGE}

LABEL org.opencontainers.image.title="Star Wars: Battlefront Game Server" \
      org.opencontainers.image.description="Dedicated server for Star Wars: Battlefront (2004), running Battlefront.exe /autonet dedicated under Wine" \
      app.lancommander.server.kind="game" \
      app.lancommander.server.game.title="Star Wars: Battlefront" \
      app.lancommander.server.external-id.hq="bcef3c2d-f9d9-42b7-be81-9789d5d73f07" \
      app.lancommander.server.external-id.igdb="141" \
      app.lancommander.server.external-id.steam="1058020" \
      app.lancommander.server.external-id.gog="1668107107"

# Native d3dx9_43.dll from the DirectX June 2010 redist. With /norender the game hands D3DX a stub
# device, and Wine's builtin D3DXCheckTextureRequirements crashes on it (page fault in d3dx9_43).
# Only the 32-bit DLL is kept; the 100 MB redist is not. Microsoft's own URL is gone; this is the
# mirror winetricks pins, checked against the same sha256.
ARG DIRECTX_REDIST_URL="https://files.holarse-linuxgaming.de/mirrors/microsoft/directx_Jun2010_redist.exe"
ARG DIRECTX_REDIST_SHA256="8746ee1a84a083a90e37899d71d50d5c7c015e69688a466aa80447f011780c0d"
ARG D3DX9_43_SHA256="0b28546be22c71834501f7d7185ede5d79742457331c7ee09efc14490dd64f5f"

# ----------------------------
# Server settings
#   - The game files are not downloadable; put a Star Wars: Battlefront install (the folder that
#     holds GameData/) in /config/Server, or set SWBF_ARCHIVE_URL to a zip of one
#   - The game is built for the GOG/Steam release (1.3.7); clients must run the same build
#   - SWBF_MAPS: semicolon-separated "map [tickets1 tickets2]" entries, e.g. "bes2r 400 400; tat2i"
# ----------------------------
ENV SWBF_ARCHIVE_URL="" \
    SWBF_SERVER_NAME="Star Wars Battlefront Server" \
    SWBF_PASSWORD="" \
    SWBF_ADMIN_PASSWORD="" \
    SWBF_MAX_PLAYERS="32" \
    SWBF_MIN_PLAYERS="1" \
    SWBF_BOTS="8" \
    SWBF_DIFFICULTY="2" \
    SWBF_TEAM_DAMAGE="true" \
    SWBF_AUTO_AIM="true" \
    SWBF_SIDE_SELECT="false" \
    SWBF_SPAWN_INVINCIBILITY="5" \
    SWBF_TPS="30" \
    SWBF_THROTTLE="2048" \
    SWBF_MAPS="bes2r; bes2a; tat2r; tat2i; nab2c; hot1i; kas2c; yav1i; geo1r; end1a" \
    SWBF_EXTRA_ARGS="" \
    WINE_XVFB="false" \
    START_EXE="/usr/local/bin/swbf-server" \
    START_ARGS=""

RUN set -eux; \
    tmp="$(mktemp -d)"; \
    curl -fsSL --retry 3 "${DIRECTX_REDIST_URL}" -o "${tmp}/redist.exe"; \
    echo "${DIRECTX_REDIST_SHA256}  ${tmp}/redist.exe" | sha256sum -c -; \
    cabextract -q -d "${tmp}" -F 'Jun2010_d3dx9_43_x86.cab' "${tmp}/redist.exe"; \
    mkdir -p /opt/d3dx9; \
    cabextract -q -d /opt/d3dx9 -F 'd3dx9_43.dll' "${tmp}/Jun2010_d3dx9_43_x86.cab"; \
    echo "${D3DX9_43_SHA256}  /opt/d3dx9/d3dx9_43.dll" | sha256sum -c -; \
    rm -rf "${tmp}"

COPY Scripts/swbf-server /usr/local/bin/swbf-server
RUN chmod +x /usr/local/bin/swbf-server

COPY Hooks/ "${BASE_HOOKS}/"

# 3658/udp: game (fixed, the game has no port option)
# 3657/udp: LAN server browser (clients broadcast a query, the server answers by broadcast)
EXPOSE 3658/udp 3657/udp

WORKDIR /config
ENTRYPOINT ["/usr/local/bin/entrypoint.ps1"]

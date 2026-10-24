# Workshop shell image. Versions mirror versions.env (checked by scripts/check-versions.sh);
# docker-compose passes them as build args. The data bundle is NOT baked in: postCreateCommand
# runs scripts/get-bundle.sh (or use the prebuilt ghcr image workflow).
FROM mcr.microsoft.com/devcontainers/base:ubuntu-24.04

ARG DUCKDB_VERSION=2.0.0
ARG JAVA_VERSION=21
ARG NODE_VERSION=22
ARG PMTILES_VERSION=1.31.2
ARG PLANETILER_VERSION=0.10.2
ARG OSMIUM_VERSION=1.19
ARG TARGETARCH

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates curl gnupg unzip zip jq python3 python3-pip python3-venv osmium-tool \
    && rm -rf /var/lib/apt/lists/*

# Temurin (Adoptium apt repo)
RUN curl -fsSL https://packages.adoptium.net/artifactory/api/gpg/key/public | gpg --dearmor -o /usr/share/keyrings/adoptium.gpg \
 && echo "deb [signed-by=/usr/share/keyrings/adoptium.gpg] https://packages.adoptium.net/artifactory/deb noble main" > /etc/apt/sources.list.d/adoptium.list \
 && apt-get update && apt-get install -y --no-install-recommends temurin-${JAVA_VERSION}-jdk \
 && rm -rf /var/lib/apt/lists/*

# Node (NodeSource)
RUN curl -fsSL https://deb.nodesource.com/setup_${NODE_VERSION}.x | bash - \
 && apt-get install -y --no-install-recommends nodejs && rm -rf /var/lib/apt/lists/*

# DuckDB CLI (pinned release zip) + pre-install the spatial extension for the vscode user
RUN DA="${TARGETARCH:-$(dpkg --print-architecture)}" \
 && case "$DA" in amd64|arm64) ;; *) echo "unsupported arch $DA" >&2; exit 1 ;; esac \
 && curl -fsSL "https://github.com/duckdb/duckdb/releases/download/v${DUCKDB_VERSION}/duckdb-cli-linux-${DA}.tar.gz" | tar -xz -C /usr/local/bin duckdb \
 && chmod +x /usr/local/bin/duckdb && duckdb --version
USER vscode
RUN duckdb -c "INSTALL spatial; INSTALL httpfs;"
USER root

# go-pmtiles (Go binary; NOT the pip/conda "pmtiles" package)
RUN case "${TARGETARCH:-$(dpkg --print-architecture)}" in \
      amd64) PA=x86_64 ;; arm64) PA=arm64 ;; *) echo "unsupported arch" >&2; exit 1 ;; esac \
 && curl -fsSL "https://github.com/protomaps/go-pmtiles/releases/download/v${PMTILES_VERSION}/go-pmtiles_${PMTILES_VERSION}_Linux_${PA}.tar.gz" | tar -xz -C /usr/local/bin pmtiles \
 && pmtiles --help >/dev/null

# Planetiler fat jar; linked into 01-tiles/ at postCreate (the repo mount hides anything we put there)
RUN curl -fsSL -o /opt/planetiler.jar "https://github.com/onthegomap/planetiler/releases/download/v${PLANETILER_VERSION}/planetiler.jar"

# uv
RUN curl -LsSf https://astral.sh/uv/install.sh | env UV_INSTALL_DIR=/usr/local/bin UV_NO_MODIFY_PATH=1 sh

USER vscode

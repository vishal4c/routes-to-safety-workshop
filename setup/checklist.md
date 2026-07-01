# Setup checklist — do this ~1 week before the workshop

The session goes straight into building, so please complete setup ahead of time.
Budget a few minutes if you already have Java and Docker; ~30 minutes on a clean machine.
An office-hours channel is open the week before if you get stuck.

> **Placeholder** — exact versions and download links are pinned before the session.
> See [`../.tool-versions`](../.tool-versions) for the pinned runtimes.

## What you need

| Tool | Why | Notes |
|---|---|---|
| **DuckDB** (+ `spatial` extension) | Module `00-data` — extract & query | Single binary; `INSTALL spatial; LOAD spatial;` |
| **Java (JDK 21+)** | Module `01-tiles` — Planetiler | Temurin recommended |
| **Node.js 20+** | Modules `02-web`, `03-routing` | Serves the map page; runs the routing demo |
| **Docker + Docker Compose** | Module `03-routing` — OSRM | For the pre-built routing graph |
| A modern browser | Module `02-web` — MapLibre GL JS | Chrome/Firefox/Safari/Edge |

## macOS

```bash
# Homebrew
brew install duckdb node
brew install --cask temurin        # JDK 21
brew install --cask docker         # then launch Docker Desktop once
```

## Windows

- DuckDB: download the CLI from duckdb.org and add it to PATH.
- Java: install Temurin JDK 21 (adoptium.net).
- Node.js: install the 20.x LTS from nodejs.org.
- Docker: install Docker Desktop (WSL2 backend recommended).

## Linux

```bash
# DuckDB: download the CLI binary from duckdb.org and put it on PATH
sudo apt-get install -y openjdk-21-jdk nodejs npm docker.io docker-compose-plugin
# add yourself to the docker group, then re-login:
sudo usermod -aG docker "$USER"
```

## Verify

```bash
duckdb  < setup/hello-geo.sql   # prints an OK row (see setup/hello-geo.sql)
java -version                   # 21.x
node -v                         # v20.x
docker run --rm hello-world     # Docker works
```

## Get the data bundle

The tiny pre-clipped inputs and the pre-built fallback artifacts (basemap PMTiles, OSRM graph)
are distributed as a release asset (link in the office-hours message). Download it into
[`../data-bundle/`](../data-bundle/) before the session.

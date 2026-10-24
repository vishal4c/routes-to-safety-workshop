#!/usr/bin/env python3
"""Routes to Safety — environment check. Python 3.9+, standard library only.

Run from the repo root:  python3 setup/check_setup.py   (Windows Git Bash: python setup/check_setup.py)
Prints green/red per tool, which tier you are on, and the exact next command. Exit 0 = ready, 1 = something required is red.
"""
import json
import os
import platform
import re
import shutil
import subprocess
import sys
import tempfile
import urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if os.path.isfile(os.path.join(os.getcwd(), "versions.env")):
    ROOT = os.getcwd()  # run from the repo root
USE_COLOR = sys.stdout.isatty() and os.environ.get("NO_COLOR") is None
if os.name == "nt" and USE_COLOR:
    os.system("")  # enable ANSI on Windows 10+ terminals


def c(code, s):
    return "\033[%sm%s\033[0m" % (code, s) if USE_COLOR else s


GREEN, RED, YELLOW, GREY = (lambda s: c("32", s)), (lambda s: c("31;1", s)), (lambda s: c("33", s)), (lambda s: c("90", s))
results = []  # (name, status 'ok'|'fail'|'warn'|'skip', detail, required)


def add(name, status, detail, required=True):
    results.append((name, status, detail, required))
    mark = {"ok": GREEN("  OK  "), "fail": RED(" FAIL "), "warn": YELLOW(" WARN "), "skip": GREY(" -    ")}[status]
    print("[%s] %-22s %s" % (mark, name, detail))


def run(cmd, timeout=25):
    try:
        p = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, universal_newlines=True, timeout=timeout)
        return p.returncode, p.stdout.strip()
    except Exception as e:  # noqa: BLE001
        return 1, str(e)


def read_pins():
    pins = {}
    try:
        with open(os.path.join(ROOT, "versions.env")) as f:
            for line in f:
                m = re.match(r"^([A-Z_]+)=(.*)$", line.strip())
                if m:
                    pins[m.group(1)] = m.group(2)
    except OSError:
        pass
    return pins


def vtuple(s):
    return tuple(int(x) for x in re.findall(r"\d+", s)[:3])


PINS = read_pins()
OS = {"Darwin": "mac", "Windows": "windows", "Linux": "linux"}.get(platform.system(), "linux")
INSTALL = {
    "duckdb": {"mac": "brew install duckdb", "windows": "winget install DuckDB.cli", "linux": "see setup/README.md (DuckDB release tarball)"},
    "java": {"mac": "brew install --cask temurin@21", "windows": "winget install EclipseAdoptium.Temurin.21.JDK", "linux": "sudo apt install temurin-21-jdk (Adoptium repo, see setup/README.md)"},
    "node": {"mac": "brew install node@22", "windows": "winget install OpenJS.NodeJS.LTS", "linux": "see setup/README.md (NodeSource 22)"},
    "pmtiles": {"mac": "brew install pmtiles", "windows": "download go-pmtiles_%s_Windows_x86_64.zip (setup/README.md)" % PINS.get("PMTILES_VERSION", "1.31.2"), "linux": "download go-pmtiles tar.gz (setup/README.md)"},
}


def check_python():
    v = sys.version_info
    add("python", "ok" if v >= (3, 9) else "fail", "%d.%d.%d" % v[:3] + ("" if v >= (3, 9) else "  (need 3.9+)"))


def check_duckdb():
    exe = shutil.which("duckdb")
    if not exe:
        add("duckdb", "fail", "not found → " + INSTALL["duckdb"][OS])
        return
    rc, out = run([exe, "--version"])
    m = re.search(r"v?(\d+\.\d+\.\d+)", out)
    if rc != 0 or not m:
        add("duckdb", "fail", "could not read version: " + out[:80])
        return
    ver = m.group(1)
    if vtuple(ver) < (2, 0, 0):
        add("duckdb", "fail", "v%s is too old, need >= 2.0.0 → %s" % (ver, INSTALL["duckdb"][OS]))
        return
    rc, out = run([exe, "-csv", "-noheader", "-c", "INSTALL spatial; LOAD spatial; SELECT ST_AsText(ST_Point(1,2));"], timeout=120)
    if rc == 0 and "POINT" in out:
        add("duckdb", "ok", "v%s, spatial extension loads" % ver)
    else:
        add("duckdb", "fail", "v%s but spatial failed to load (needs internet once): %s" % (ver, out.splitlines()[-1][:100] if out else ""))


def check_java():
    exe = shutil.which("java")
    if not exe:
        add("java 21", "fail", "not found → " + INSTALL["java"][OS])
        return
    _, out = run([exe, "-version"])
    m = re.search(r'version "(\d+)', out)
    major = int(m.group(1)) if m else 0
    if major == 21:
        add("java 21", "ok", out.splitlines()[0] if out else "21")
    elif major > 21:
        add("java 21", "warn", "Java %d found (21 expected; should work)" % major, required=False)
    else:
        add("java 21", "fail", "Java %s found, need 21 → %s" % (major or "?", INSTALL["java"][OS]))


def check_node():
    exe = shutil.which("node")
    if not exe:
        add("node >= 20", "fail", "not found → " + INSTALL["node"][OS])
        return
    _, out = run([exe, "--version"])
    ok = vtuple(out) >= (20, 0, 0) if re.search(r"\d", out) else False
    add("node >= 20", "ok" if ok else "fail", out + ("" if ok else " → " + INSTALL["node"][OS]))


def check_pmtiles():
    exe = shutil.which("pmtiles")
    if not exe:
        add("pmtiles (go-pmtiles)", "fail", "not found → " + INSTALL["pmtiles"][OS])
        return
    rc, out = run([exe, "--help"])
    # go-pmtiles prints subcommands like 'extract', 'show', 'serve'; the Python 'pmtiles' package has 'pmtiles-show' etc.
    if "extract" in out and ("serve" in out or "show" in out):
        _, v = run([exe, "version"])
        add("pmtiles (go-pmtiles)", "ok", "%s (%s)" % (exe, v.splitlines()[0][:40] if v else "version n/a"))
    else:
        add("pmtiles (go-pmtiles)", "fail", "%s is not the go-pmtiles CLI (conda/pip package?) → %s" % (exe, INSTALL["pmtiles"][OS]))


CONTAINER = {"cli": None, "compose": None}


def check_container():
    for cli in ("docker", "finch", "podman", "nerdctl"):
        exe = shutil.which(cli)
        if not exe:
            continue
        rc, out = run([exe, "compose", "version"] if cli != "podman" else [exe, "compose", "version"])
        if rc == 0:
            CONTAINER["cli"], CONTAINER["compose"] = cli, "%s compose" % cli
            add("container runtime", "ok", "%s → use `%s compose up`" % (cli, cli), required=False)
            rc2, _ = run([exe, "info"], timeout=20) if cli in ("docker", "podman", "nerdctl") else run([exe, "vm", "status"], timeout=20)
            if rc2 != 0:
                hint = "`finch vm init` (or `finch vm start`)" if cli == "finch" else "start Docker Desktop / OrbStack / Colima / `podman machine start`"
                add("  runtime running?", "warn", "daemon not reachable → " + hint, required=False)
            return
    if shutil.which("docker") or shutil.which("finch") or shutil.which("podman") or shutil.which("nerdctl"):
        add("container runtime", "warn", "CLI found but no `compose` subcommand — install the compose plugin or use Finch", required=False)
    else:
        add("container runtime", "skip", "inside the workshop container — osrm + caddy run beside it" if IN_WORKSHOP_CONTAINER else "none found (fine for tier 3; recommended: Finch — see setup/README.md)", required=False)


def http_ok(url, timeout=3):
    try:
        with urllib.request.urlopen(url, timeout=timeout) as r:
            return r.status, r.read(4000).decode("utf-8", "replace")
    except Exception:  # noqa: BLE001
        return None, ""


IN_WORKSHOP_CONTAINER = os.environ.get("WORKSHOP_CONTAINER") == "1"   # set by docker-compose.yml for the `workshop` service
WEB_URL = os.environ.get("WEB_URL", "http://localhost:8080")              # inside the compose network: http://caddy:8080


def check_osrm():
    path = "/nearest/v1/driving/-121.08,38.90"
    candidates = [("same-origin :8080/osrm", "http://localhost:8080/osrm"), ("localhost:5000", "http://localhost:5000")]
    if os.environ.get("OSRM_URL"):
        candidates.insert(0, ("$OSRM_URL = " + os.environ["OSRM_URL"], os.environ["OSRM_URL"].rstrip("/")))
    for label, base in candidates:
        st, body = http_ok(base + path)
        if st == 200 and '"Ok"' in body:
            add("OSRM routing", "ok", "reachable via " + label, required=False)
            return True
    add("OSRM routing", "skip", "not reachable — no routing on this tier (Phases 0–3b are fine; Phase 3c needs tier 1 or 2)", required=False)
    return False


def check_web():
    st, _ = http_ok(WEB_URL + "/data/shelters.geojson")
    if st == 200:
        add("web server :8080", "ok", "%s/ serves the repo%s" % (WEB_URL, " (open http://localhost:8080/ on your laptop)" if IN_WORKSHOP_CONTAINER else ""), required=False)
        return True
    add("web server :8080", "skip", "not running yet", required=False)
    return False


def path(*p):
    return os.path.join(ROOT, *p)


def check_data():
    missing_bundle = False
    for rel, req in (("data/overture/segments.parquet", True), ("data/shelters.geojson", True)):
        fp = path(*rel.split("/"))
        if os.path.isfile(fp):
            add(rel, "ok", "%.1f MB" % (os.path.getsize(fp) / 1e6))
        else:
            add(rel, "fail", "missing — are you in the repo root? try `git pull` / re-clone with `git clone --depth 1`")
    fp = path("data", "prebuilt", "evac.pmtiles")
    if os.path.isfile(fp):
        add("data/prebuilt/evac.pmtiles", "ok", "%.1f MB" % (os.path.getsize(fp) / 1e6), required=False)
    else:
        add("data/prebuilt/evac.pmtiles", "skip", "optional (fallback tiles) — run scripts/get-bundle.sh", required=False)
        missing_bundle = True
    dp = path("data", "osrm")
    if os.path.isdir(dp) and any(f.startswith("study-area.osrm") for f in os.listdir(dp)):
        add("data/osrm/", "ok", "routing graph present", required=False)
    else:
        add("data/osrm/", "skip", "optional (needed for local routing) — run scripts/get-bundle.sh", required=False)
        missing_bundle = True
    return missing_bundle


def check_disk():
    free = shutil.disk_usage(tempfile.gettempdir() if not os.path.isdir(ROOT) else ROOT).free / 1e9
    add("free disk", "ok" if free >= 2 else "fail", "%.1f GB free%s" % (free, "" if free >= 2 else " — need >= 2 GB"))


def main():
    print("Routes to Safety — setup check  (%s, repo: %s)\n" % (platform.platform(), ROOT))
    check_python()
    check_duckdb()
    check_java()
    check_node()
    check_pmtiles()
    check_container()
    osrm = check_osrm()
    web = check_web()
    missing_bundle = check_data()
    check_disk()

    required_fail = [r for r in results if r[1] == "fail" and r[3]]
    print()
    in_codespaces = os.environ.get("CODESPACES") == "true"
    if in_codespaces:
        tier, why = "1 (Codespaces)", "CODESPACES=true"
    elif IN_WORKSHOP_CONTAINER:
        tier, why = "2 (local containers)", "inside the workshop container from docker-compose.yml"
    elif CONTAINER["cli"] and (osrm or os.path.isdir(path("data", "osrm"))):
        tier, why = "2 (local containers)", "%s found" % CONTAINER["cli"]
    elif not required_fail:
        tier, why = "3 (native, no routing)", "tools on PATH, no container runtime or OSRM"
    else:
        tier, why = "not ready", "required tools missing"
    print("Tier I think you are on: %s  [%s]" % (tier, why))

    # exact next command
    if required_fail:
        first = required_fail[0]
        print(RED("Next: fix the red line '%s' above, then re-run: python3 setup/check_setup.py" % first[0].strip()))
        print("      Red for more than 10 minutes? Switch tier: Codespaces link on the slide, or the Pages site.")
    elif missing_bundle and not in_codespaces:
        print("Next: " + ("bash scripts/get-bundle.sh" if OS != "windows" else "bash scripts/get-bundle.sh   (PowerShell: powershell -ExecutionPolicy Bypass -File scripts\\get-bundle.ps1)"))
        print("      (run scripts/get-bundle.sh — adds prebuilt tiles and the routing graph)")
    elif tier.startswith("2") and IN_WORKSHOP_CONTAINER:
        print("Next: duckdb -c \".read setup/hello-geo.sql\"      map: http://localhost:8080/02-web/ on your laptop")
    elif tier.startswith("2") and not web:
        print("Next: %s up -d      then open http://localhost:8080/" % CONTAINER["compose"])
    elif tier.startswith("3") and not web:
        print("Next: npx serve -l 8080 .      then:  duckdb -c \".read setup/hello-geo.sql\"")
    else:
        print("Next: duckdb -c \".read setup/hello-geo.sql\"")
    if in_codespaces:
        print("      Open the map from the Ports tab → globe icon on port 8080 (never forward port 5000).")
    if not osrm and not required_fail:
        print("      No routing on this tier: pair with a neighbour for Phase 3c, or use tier 1/2.")
    print("\nResult: %s" % (GREEN("ALL REQUIRED CHECKS PASSED") if not required_fail else RED("%d REQUIRED CHECK(S) FAILED" % len(required_fail))))
    return 1 if required_fail else 0


if __name__ == "__main__":
    sys.exit(main())

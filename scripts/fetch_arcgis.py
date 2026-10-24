#!/usr/bin/env python3
"""Page through an ArcGIS FeatureServer layer query and write one GeoJSON FeatureCollection.
Usage: fetch_arcgis.py <layer_url> <out.geojson> --bbox W,S,E,N | --where "<sql>"  [--fields a,b,c]
Asserts WGS84 lon/lat on output (the FHSZ source is EPSG:2226 feet; f=geojson makes the server reproject)."""
import json, sys, urllib.parse, urllib.request, argparse
ap = argparse.ArgumentParser(); ap.add_argument("url"); ap.add_argument("out")
ap.add_argument("--bbox"); ap.add_argument("--where", default="1=1"); ap.add_argument("--fields", default="*")
a = ap.parse_args()
feats, offset, page = [], 0, 1000
while True:
    q = {"where": a.where, "outFields": a.fields, "outSR": 4326, "f": "geojson",
         "resultOffset": offset, "resultRecordCount": page, "returnGeometry": "true"}
    if a.bbox:
        q.update({"geometry": a.bbox, "geometryType": "esriGeometryEnvelope", "inSR": 4326, "spatialRel": "esriSpatialRelIntersects"})
    url = a.url.rstrip("/") + "/query?" + urllib.parse.urlencode(q)
    with urllib.request.urlopen(url, timeout=120) as r:
        d = json.load(r)
    if "error" in d: sys.exit(f"ArcGIS error: {d['error']}")
    got = d.get("features", []); feats += got
    print(f"  offset {offset}: +{len(got)} (total {len(feats)})", file=sys.stderr)
    if not got or not d.get("properties", {}).get("exceededTransferLimit", False) and len(got) < page: break
    offset += len(got)
for f in feats:  # CRS assertion: first coordinate must be lon/lat in California
    c = f["geometry"]["coordinates"]
    while isinstance(c[0], list): c = c[0]
    assert -125 < c[0] < -114 and 32 < c[1] < 43, f"not WGS84: {c}"
json.dump({"type": "FeatureCollection", "features": feats}, open(a.out, "w"))
print(f"{a.out}: {len(feats)} features", file=sys.stderr)

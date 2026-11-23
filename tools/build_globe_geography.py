#!/usr/bin/env python3
"""Build compact, gzip-compressed Natural Earth country and Admin-1 data for Godot.

Downloads pinned Natural Earth 5.1.1 archives, extracts only geometry and the
small set of fields needed by the globe, and writes deterministic JSON.GZ files.
Requires pyshp (pinned in the GitHub Actions workflow).
"""
from __future__ import annotations

import argparse
import gzip
import io
import json
import math
import urllib.request
import zipfile
from pathlib import Path

SOURCES = {
    "countries_50m": (
        "https://naciscdn.org/naturalearth/50m/cultural/ne_50m_admin_0_countries.zip",
        "ne_50m_admin_0_countries",
        "Natural Earth 1:50m Admin 0 Countries v5.1.1",
        "country",
    ),
    "countries_10m": (
        "https://naciscdn.org/naturalearth/10m/cultural/ne_10m_admin_0_countries.zip",
        "ne_10m_admin_0_countries",
        "Natural Earth 1:10m Admin 0 Countries v5.1.1",
        "country",
    ),
    "states_10m": (
        "https://naciscdn.org/naturalearth/10m/cultural/ne_10m_admin_1_states_provinces.zip",
        "ne_10m_admin_1_states_provinces",
        "Natural Earth 1:10m Admin 1 States and Provinces v5.1.1",
        "state",
    ),
}


def value(record: dict, *keys: str, default=None):
    lowered = {str(key).lower(): val for key, val in record.items()}
    for key in keys:
        result = lowered.get(key.lower())
        if result not in (None, "", "-99", -99):
            return result
    return default


def rounded(value_: float) -> float:
    number = float(value_)
    return round(number, 4) if math.isfinite(number) else 0.0


def convert_archive(archive_bytes: bytes, stem: str, source: str, kind: str, continent_by_code: dict | None = None) -> dict:
    import shapefile

    with zipfile.ZipFile(io.BytesIO(archive_bytes)) as archive:
        members = {Path(name).name.lower(): name for name in archive.namelist()}
        def member(extension: str) -> bytes:
            key = (stem + extension).lower()
            if key not in members:
                raise RuntimeError(f"Missing {key} in Natural Earth archive")
            return archive.read(members[key])

        reader = shapefile.Reader(
            shp=io.BytesIO(member(".shp")),
            shx=io.BytesIO(member(".shx")),
            dbf=io.BytesIO(member(".dbf")),
            encoding="utf-8",
        )
        fields = [field[0] for field in reader.fields[1:]]
        features = []
        for shape_record in reader.iterShapeRecords():
            record = dict(zip(fields, shape_record.record))
            shape = shape_record.shape
            if not shape.points or not shape.parts:
                continue
            part_starts = list(shape.parts) + [len(shape.points)]
            rings = []
            for index in range(len(part_starts) - 1):
                points = shape.points[part_starts[index]:part_starts[index + 1]]
                if len(points) < 4:
                    continue
                rings.append([[rounded(point[0]), rounded(point[1])] for point in points])
            if not rings:
                continue

            if kind == "country":
                name = value(record, "ADMIN", "NAME", "NAME_EN", default="Unknown")
                longitude = value(record, "LABEL_X", "LONGITUDE", default=0.0)
                latitude = value(record, "LABEL_Y", "LATITUDE", default=0.0)
                code = value(record, "ADM0_A3", "SOV_A3", default="")
                rank = value(record, "LABELRANK", default=5)
                feature = {
                    "n": str(name), "c": str(code),
                    "x": rounded(longitude), "y": rounded(latitude),
                    "rank": int(rank), "continent": str(value(record, "CONTINENT", default="Other")), "r": rings,
                }
            else:
                name = value(record, "name", "name_en", "admin", default="Unknown")
                longitude = value(record, "longitude", default=0.0)
                latitude = value(record, "latitude", default=0.0)
                code = value(record, "adm0_a3", default="")
                admin = value(record, "admin", default="")
                feature = {
                    "n": str(name), "a": str(admin), "c": str(code),
                    "x": rounded(longitude), "y": rounded(latitude),
                    "continent": (continent_by_code or {}).get(str(code), str(value(record, "continent", default="Other"))),
                    "r": rings,
                }
            features.append(feature)
        reader.close()

    return {"source": source, "features": features}


def write_compressed(path: Path, payload: dict) -> None:
    encoded = json.dumps(payload, ensure_ascii=False, separators=(",", ":")).encode("utf-8")
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("wb") as raw:
        with gzip.GzipFile(fileobj=raw, mode="wb", compresslevel=9, mtime=0) as compressed:
            compressed.write(encoded)
    print(f"{path}: {len(payload['features'])} features, {path.stat().st_size:,} compressed bytes")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", type=Path, default=Path("assets/globe"))
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)

    country_outputs = {
        "countries_50m": "natural_earth_countries_50m.json.gz",
        "countries_10m": "natural_earth_countries_10m.json.gz",
    }
    country_payloads = {}
    for key in ("countries_50m", "countries_10m"):
        url, stem, source, kind = SOURCES[key]
        print(f"Downloading {source}...")
        request = urllib.request.Request(url, headers={"User-Agent": "DigitalWorld-Globe-DataBuilder/1.0"})
        with urllib.request.urlopen(request, timeout=90) as response:
            archive = response.read()
        payload = convert_archive(archive, stem, source, kind)
        minimum = 250 if key == "countries_10m" else 170
        if len(payload["features"]) < minimum:
            raise RuntimeError(f"{key} returned only {len(payload['features'])} features; expected at least {minimum}")
        country_payloads[key] = payload
        write_compressed(args.output / country_outputs[key], payload)

    continent_by_code = {
        str(feature.get("c", "")): str(feature.get("continent", "Other"))
        for feature in country_payloads["countries_10m"]["features"]
        if feature.get("c")
    }
    url, stem, source, kind = SOURCES["states_10m"]
    print(f"Downloading {source}...")
    request = urllib.request.Request(url, headers={"User-Agent": "DigitalWorld-Globe-DataBuilder/1.0"})
    with urllib.request.urlopen(request, timeout=90) as response:
        archive = response.read()
    states = convert_archive(archive, stem, source, kind, continent_by_code)
    if len(states["features"]) < 4000:
        raise RuntimeError(f"states_10m returned only {len(states['features'])} features; expected at least 4000")

    grouped = {}
    for feature in states["features"]:
        continent = str(feature.get("continent", "Other")).strip().lower().replace(" ", "_")
        if continent not in {"africa", "asia", "europe", "north_america", "south_america", "oceania", "antarctica"}:
            continent = "other"
        grouped.setdefault(continent, []).append(feature)

    old_combined = args.output / "natural_earth_states_10m.json.gz"
    if old_combined.exists():
        old_combined.unlink()
    total = 0
    for continent, features in sorted(grouped.items()):
        payload = {
            "source": source + " — " + continent.replace("_", " ").title(),
            "features": features,
        }
        total += len(features)
        write_compressed(args.output / f"natural_earth_states_10m_{continent}.json.gz", payload)
    if total != len(states["features"]):
        raise RuntimeError("State/province continent partition lost features")
    print(f"Partitioned all {total} Admin-1 features into {len(grouped)} continent files.")


if __name__ == "__main__":
    main()

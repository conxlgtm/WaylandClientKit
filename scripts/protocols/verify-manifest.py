#!/usr/bin/env python3
import json
import pathlib
import sys


ROOT = pathlib.Path(__file__).resolve().parents[2]
MANIFEST = ROOT / "protocols" / "manifest.json"

REQUIRED_FIELDS = {
    "name",
    "localPath",
    "upstreamProject",
    "upstreamVersion",
    "vendoredFromPackage",
    "vendoredFromPath",
    "sha256",
    "swiftWaylandTier",
    "apiExposure",
    "testStrategy",
    "notes",
}

TIERS = {
    "required",
    "optionalFoundation",
    "previewFoundation",
    "privateGenerationDependency",
    "outOfScope",
}

API_EXPOSURES = {
    "public",
    "publicCapability",
    "preview",
    "internal",
    "none",
}

TEST_STRATEGIES = {
    "unit-and-live",
    "unit-and-live-when-advertised",
    "generation-only",
}


def main() -> int:
    with MANIFEST.open(encoding="utf-8") as handle:
        payload = json.load(handle)

    protocols = payload.get("protocols")
    if not isinstance(protocols, list):
        print("protocols/manifest.json must contain a protocols array")
        return 1

    failed = False
    seen_names: set[str] = set()

    for index, protocol in enumerate(protocols):
        name = protocol.get("name", f"entry {index}")
        if name in seen_names:
            print(f"Duplicate protocol manifest entry: {name}")
            failed = True
        seen_names.add(name)

        missing = sorted(REQUIRED_FIELDS - protocol.keys())
        if missing:
            print(f"{name} missing fields: {', '.join(missing)}")
            failed = True

        if protocol.get("swiftWaylandTier") not in TIERS:
            print(f"{name} has invalid swiftWaylandTier: {protocol.get('swiftWaylandTier')}")
            failed = True
        if protocol.get("apiExposure") not in API_EXPOSURES:
            print(f"{name} has invalid apiExposure: {protocol.get('apiExposure')}")
            failed = True
        if protocol.get("testStrategy") not in TEST_STRATEGIES:
            print(f"{name} has invalid testStrategy: {protocol.get('testStrategy')}")
            failed = True

        local_path = protocol.get("localPath")
        if isinstance(local_path, str) and not (ROOT / local_path).is_file():
            print(f"{name} localPath does not exist: {local_path}")
            failed = True

    if failed:
        return 1

    print("Protocol manifest metadata is complete.")
    return 0


if __name__ == "__main__":
    sys.exit(main())

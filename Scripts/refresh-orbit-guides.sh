#!/bin/bash
#
# Refresh the bundled Orbit guides corpus.
#
# LilJustin ships with a snapshot of the live Orbit guides export so it
# can ground answers in actual guide content offline. When new guides
# go live or existing guides get edited, run this script to pull the
# latest payload and commit the result.
#
# Source of truth:
#   https://get.yourorbit.team/api/guides/export
#
# Output:
#   LilAgents/orbit-guides.json — bundled into the .app at build time,
#                                 read by OrbitGuidesCorpus.swift
#
# Usage:
#   ./Scripts/refresh-orbit-guides.sh
#
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEST="$REPO_ROOT/LilAgents/orbit-guides.json"
URL="https://get.yourorbit.team/api/guides/export"

echo "Fetching $URL"
TMP="$(mktemp)"
curl -fsSL "$URL" -o "$TMP"

# Sanity check: payload must be JSON with a non-zero `count` field.
COUNT="$(python3 -c "import json,sys; d=json.load(open('$TMP')); print(d.get('count', 0))")"
if [[ "$COUNT" -lt 50 ]]; then
  echo "ERROR: export returned only $COUNT guides — refusing to overwrite. Inspect $TMP." >&2
  exit 1
fi

mv "$TMP" "$DEST"
SIZE_KB="$(du -k "$DEST" | cut -f1)"
echo "Wrote $DEST — $COUNT guides, ${SIZE_KB} KB"
echo
echo "Next: commit the change and tag a release."
